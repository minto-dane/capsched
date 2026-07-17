#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
PRIMARY_DIR="$WORKSPACE_DIR/linux"
E3_DIR="$WORKSPACE_DIR/build/DomainLeaseLinux.volume/worktrees/p5a-r2-e3-rebuild-prototype"
E4_DIR="$WORKSPACE_DIR/build/DomainLeaseLinux.volume/worktrees/p5a-r2-e4-lock-hold"
PATCH_QUEUE_DIR="$WORKSPACE_DIR/linux-patches"
CONFIG="$CAPSCHED_DIR/capsched-models/implementation/sched-exec-lease-p5a-r2-e4-disposable-lock-hold-measurement-v1.json"
RUN_ID=${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
OUT_DIR="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r2-e4-lock-hold-source-gate/$RUN_ID"
BUILD_OUT=${BUILD_OUT:-"$WORKSPACE_DIR/build/DomainLeaseLinux.volume/builds/arm64-current/e4-lock-hold-syntax"}
PROGRESS_FILE=${PROGRESS_FILE:-"$OUT_DIR/progress"}
JOBS=${JOBS:-4}

die() { printf 'error: %s\n' "$*" >&2; exit 1; }
progress()
{
	printf '%s\n' "$*" > "$PROGRESS_FILE"
	printf '[progress] %s\n' "$*"
}

for cmd in awk cmp git grep jq make nm objdump perl sed sha256sum wc; do
	command -v "$cmd" >/dev/null 2>&1 || die "missing command: $cmd"
done

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"
progress '5% exact source, prerequisite, and frozen-boundary gates'
jq empty "$CONFIG"

expected_parent=$(jq -r '.source.parent_commit' "$CONFIG")
expected_commit=$(jq -r '.source.candidate_commit' "$CONFIG")
expected_tree=$(jq -r '.source.candidate_tree' "$CONFIG")
expected_diff=$(jq -r '.source.diff_sha256' "$CONFIG")
expected_primary=$(jq -r '.frozen_boundary.primary_linux_commit' "$CONFIG")

[ "$(git -C "$PRIMARY_DIR" rev-parse HEAD)" = "$expected_primary" ] || die 'primary Linux moved'
[ "$(git -C "$E3_DIR" rev-parse HEAD)" = "$expected_parent" ] || die 'E3 parent moved'
[ "$(git -C "$E4_DIR" rev-parse HEAD)" = "$expected_commit" ] || die 'E4 source moved'
[ "$(git -C "$E4_DIR" rev-parse HEAD^)" = "$expected_parent" ] || die 'E4 is not a direct E3 child'
[ "$(git -C "$E4_DIR" rev-parse 'HEAD^{tree}')" = "$expected_tree" ] || die 'E4 tree mismatch'
[ -z "$(git -C "$PRIMARY_DIR" status --porcelain --untracked-files=no)" ] || die 'primary Linux dirty'
[ -z "$(git -C "$E3_DIR" status --porcelain --untracked-files=no)" ] || die 'E3 parent dirty'
[ -z "$(git -C "$E4_DIR" status --porcelain --untracked-files=no)" ] || die 'E4 source dirty'
[ "$(tail -n 1 "$PATCH_QUEUE_DIR/patches/capsched-linux-l0/series")" = \
	'0014-sched-exec_lease-Expand-build-only-layout-probe.patch' ] || die 'patch queue moved'

plan_result="$WORKSPACE_DIR/$(jq -r '.prerequisite.plan_result' "$CONFIG")"
e3_result="$WORKSPACE_DIR/$(jq -r '.prerequisite.e3_result' "$CONFIG")"
[ "$(sha256sum "$plan_result" | awk '{print $1}')" = \
	"$(jq -r '.prerequisite.plan_result_sha256' "$CONFIG")" ] || die 'E4 plan result hash mismatch'
[ "$(sha256sum "$e3_result" | awk '{print $1}')" = \
	"$(jq -r '.prerequisite.e3_result_sha256' "$CONFIG")" ] || die 'E3 result hash mismatch'
jq -e '.status == "passed_e4_plan_only" and .e4_arm64_measurement_may_be_launched_after_source_gate == false' "$plan_result" >/dev/null
jq -e '.status == "passed_e3_rebuild_prototype" and .e3_rebuild_correctness_accepted_for_synthetic_fixtures == true' "$e3_result" >/dev/null

git -C "$E4_DIR" diff "$expected_parent..$expected_commit" > "$OUT_DIR/e4-source.diff"
diff_hash=$(sha256sum "$OUT_DIR/e4-source.diff" | awk '{print $1}')
[ "$diff_hash" = "$expected_diff" ] || die 'E4 diff hash mismatch'
git -C "$E4_DIR" diff --name-only "$expected_parent..$expected_commit" > "$OUT_DIR/changed-files.txt"
[ "$(sed -n '1p' "$OUT_DIR/changed-files.txt")" = 'init/Kconfig' ] || die 'first changed file mismatch'
[ "$(sed -n '2p' "$OUT_DIR/changed-files.txt")" = 'kernel/sched/fair.c' ] || die 'second changed file mismatch'
[ "$(wc -l < "$OUT_DIR/changed-files.txt" | tr -d ' ')" = 2 ] || die 'E4 changed more than two files'
[ "$(git -C "$E4_DIR" diff --numstat "$expected_parent..$expected_commit" | awk '{a+=$1; d+=$2} END {print a, d}')" = '356 0' ] || die 'E4 delta mismatch'

for frozen in include/linux/sched.h kernel/sched/sched.h kernel/sched/exec_lease_layout_probe.c kernel/sched/Makefile; do
	cmp "$E3_DIR/$frozen" "$E4_DIR/$frozen" >/dev/null || die "frozen file changed: $frozen"
done

jq -e '
  .status == "disposable_source_draft_targeted_compile_passed_unaccepted" and
  .source.allowed_files == ["init/Kconfig","kernel/sched/fair.c"] and
  .source.insertions == 356 and .source.deletions == 0 and
  ([.source.strict_checkpatch_errors,.source.strict_checkpatch_warnings,.source.strict_checkpatch_checks] | all(. == 0)) and
  .configuration.name == "SCHED_EXEC_LEASE_REBUILD_MEASURE_KUNIT_TEST" and
  .configuration.default_enabled == false and
  .configuration.depends_on == "SCHED_EXEC_LEASE_REBUILD_KUNIT_TEST && KUNIT=y" and
  .configuration.same_translation_unit == "kernel/sched/fair.c" and
  .configuration.suite_name == "sched_exec_lease_rebuild_measure" and
  ([.fixture.real_rq_cfs_rq_sched_entity_structures,.fixture.real_rb_and_bottom_up_iterators,.fixture.allocation_before_measurement,.fixture.o1_container_leaf_callback,.fixture.untimed_correctness_and_visit_check_per_cell] | all(. == true)) and
  .fixture.registered_with_live_scheduler == false and .fixture.topology_mutation_during_samples == false and .fixture.generation_race_rate_ppm == 0 and
  .interval.clock == "local_clock" and
  ([.interval.local_irq_save_restore,.interval.raw_spin_rq_lock_unlock,.interval.clock_boundaries_outside_lock_inside_irq_disabled,.interval.paired_empty_control,.interval.alternating_pair_order,.interval.sort_and_report_after_irq_restore] | all(. == true)) and
  .interval.additional_formula == "max(rebuild_ns-control_ns,0)" and
  .matrix.runnable_entities == [0,1,8,64,256,1024,4096] and
  .matrix.hierarchy_depths == [0,1,4,16,64] and .matrix.cell_count == 35 and
  .matrix.warmup_pairs_per_cell == 256 and .matrix.measured_pairs_per_cell == 10000 and .matrix.result_rows_required == 35 and
  .matrix.arrays == ["control","rebuild","additional"] and .matrix.statistics == ["minimum","p50","p95","p99","p999","maximum"] and
  .gate.base_slice_ns == 700000 and .gate.additional_p99_limit_ns == 25000 and .gate.additional_max_limit_ns == 50000 and
  .gate.sample_may_reach_base_slice == false and .gate.warning_count_allowed == 0 and
  .gate.threshold_breach_classification == "rejected_full_locked_rebuild" and .gate.threshold_breach_is_valid_negative_evidence == true and
  .gate.malformed_or_missing_evidence_classification == "harness_failed" and
  .targeted_compile.architecture == "arm64" and .targeted_compile.e4_config_enabled == true and .targeted_compile.compiler_warnings == 0 and .targeted_compile.passed == true and
  .authorization_after_source_gate.arm64_measurement_may_be_launched == true and .authorization_after_source_gate.e4_measurement_accepted == false and .authorization_after_source_gate.full_locked_rebuild_approved == false and
  (.safety_flags | all(.[]; . == false))
' "$CONFIG" >/dev/null

progress '25% Kconfig, isolation, matrix, and measured-interval source gates'
kconfig_block="$OUT_DIR/kconfig-block.txt"
awk '
  /^config SCHED_EXEC_LEASE_REBUILD_MEASURE_KUNIT_TEST$/ { active=1 }
  active && /^config / && $2 != "SCHED_EXEC_LEASE_REBUILD_MEASURE_KUNIT_TEST" { exit }
  active { print }
' "$E4_DIR/init/Kconfig" > "$kconfig_block"
grep -Fxq 'config SCHED_EXEC_LEASE_REBUILD_MEASURE_KUNIT_TEST' "$kconfig_block" || die 'missing E4 config'
grep -Fq $'\tdepends on SCHED_EXEC_LEASE_REBUILD_KUNIT_TEST && KUNIT=y' "$kconfig_block" || die 'wrong E4 dependency'
grep -Fq $'\tdefault n' "$kconfig_block" || die 'E4 config is not default n'
if grep -Fq 'default KUNIT_ALL_TESTS' "$kconfig_block"; then die 'KUNIT_ALL_TESTS selects E4'; fi

source_file="$E4_DIR/kernel/sched/fair.c"
grep -Fq '#define SCHED_EXEC_MEASURE_SAMPLES 10000U' "$source_file" || die 'sample count moved'
grep -Fq '#define SCHED_EXEC_MEASURE_WARMUPS 256U' "$source_file" || die 'warmup count moved'
grep -Fq '#define SCHED_EXEC_MEASURE_CELL_COUNT 35U' "$source_file" || die 'cell count moved'
grep -Fq 'static const unsigned int queue_sizes[] = { 0, 1, 8, 64, 256, 1024, 4096 };' "$source_file" || die 'queue matrix moved'
grep -Fq 'static const unsigned int depths[] = { 0, 1, 4, 16, 64 };' "$source_file" || die 'depth matrix moved'
grep -Fq '.name = "sched_exec_lease_rebuild_measure"' "$source_file" || die 'suite name moved'
grep -Fq 'KUNIT_CASE_SLOW(sched_exec_rebuild_measure_matrix_test)' "$source_file" || die 'slow measurement case missing'
grep -Fq 'E4_META cells=%u samples=%u warmups=%u base_slice_ns=%u p99_limit_ns=25000 max_limit_ns=50000 clock=local_clock' "$source_file" || die 'metadata contract moved'
grep -Fq 'E4_RESULT q=%u d=%u n=%u w=%u race_ppm=0' "$source_file" || die 'result row contract moved'

if git -C "$E4_DIR" grep -l 'sched_exec_measure\|sched_exec_lease_rebuild_measure\|E4_RESULT' HEAD -- \
	':(exclude)init/Kconfig' ':(exclude)kernel/sched/fair.c' | grep -q .; then
	die 'E4 symbol escaped the two-file boundary'
fi
if git -C "$E4_DIR" grep -Eq 'EXPORT_SYMBOL.*sched_exec_(measure|rebuild_measure)|sched_exec_measure_(publish|fanout|worker)' HEAD -- .; then
	die 'E4 export, publisher, fanout, or worker found'
fi

sed -n '/sched_exec_measure_leaf_summary(/,/^}/p' "$source_file" > "$OUT_DIR/leaf-callback.txt"
grep -Fq 'container_of(se, struct sched_exec_measure_leaf, se)' "$OUT_DIR/leaf-callback.txt" || die 'O(1) leaf callback missing'
if grep -Eq '\b(for|while|list_for_each|rb_.*for_each)\b' "$OUT_DIR/leaf-callback.txt"; then die 'leaf callback is not O(1)'; fi

sed -n '/^static u64 sched_exec_measure_once(/,/^}/p' "$source_file" > "$OUT_DIR/measured-interval.txt"
for required in 'local_irq_save(flags);' 'start = local_clock();' 'raw_spin_rq_lock(&fixture->rq);' 'ret = sched_exec_rebuild_rq_test' 'barrier();' 'raw_spin_rq_unlock(&fixture->rq);' 'end = local_clock();' 'local_irq_restore(flags);'; do
	grep -Fq "$required" "$OUT_DIR/measured-interval.txt" || die "measured interval missing: $required"
done
if grep -Eq '\b(kmalloc|kzalloc|kvalloc|kvzalloc|kfree|kvfree|sort|printk|pr_|trace_|schedule|cond_resched|msleep|usleep|wait_event|policy|monitor|rb_add|rb_erase)\b' "$OUT_DIR/measured-interval.txt"; then
	die 'forbidden operation in measured interval'
fi
awk '
  /local_irq_save\(flags\)/ { irq_on=NR }
  /start = local_clock\(\)/ { start=NR }
  /raw_spin_rq_lock/ { lock=NR }
  /raw_spin_rq_unlock/ { unlock=NR }
  /end = local_clock\(\)/ { end=NR }
  /local_irq_restore\(flags\)/ { irq_off=NR }
  END { exit !(irq_on < start && start < lock && lock < unlock && unlock < end && end < irq_off) }
' "$OUT_DIR/measured-interval.txt" || die 'measured interval ordering moved'

grep -Fq 'additional[i] = rebuild[i] > control[i] ?' "$source_file" || die 'saturating additional formula missing'
grep -Fq 'if (i & 1)' "$source_file" || die 'alternating pair order missing'
grep -Fq 'fixture->ctx.leaf_visits != nr_leaves' "$source_file" || die 'untimed exact visit check missing'
grep -Fq 'sort(samples, count, sizeof(*samples)' "$source_file" || die 'statistics sort missing'

progress '50% strict patch style and E4-enabled arm64 object rebuild'
set +e
git -C "$E4_DIR" diff "$expected_parent..$expected_commit" | \
	"$E4_DIR/scripts/checkpatch.pl" --strict --no-tree - > "$OUT_DIR/checkpatch.log" 2>&1
checkpatch_rc=$?
set -e
[ "$checkpatch_rc" = 0 ] || die 'strict checkpatch failed'
grep -Fq 'total: 0 errors, 0 warnings, 0 checks' "$OUT_DIR/checkpatch.log" || die 'strict checkpatch summary mismatch'

[ -f "$BUILD_OUT/.config" ] || die "missing configured build output: $BUILD_OUT"
for config_line in \
	'CONFIG_FAIR_GROUP_SCHED=y' \
	'CONFIG_KUNIT=y' \
	'CONFIG_SCHED_EXEC_LEASE_REBUILD_KUNIT_TEST=y' \
	'CONFIG_SCHED_EXEC_LEASE_REBUILD_MEASURE_KUNIT_TEST=y'; do
	grep -Fxq "$config_line" "$BUILD_OUT/.config" || die "build config missing: $config_line"
done
rm -f "$BUILD_OUT/kernel/sched/fair.o"
set +e
make -C "$E4_DIR" O="$BUILD_OUT" ARCH=arm64 -j"$JOBS" kernel/sched/fair.o > "$OUT_DIR/build.log" 2>&1
build_rc=$?
set -e
[ "$build_rc" = 0 ] || die 'E4-enabled arm64 fair.o build failed'
if grep -Eqi '(^|[^[:alpha:]])(warning|error):' "$OUT_DIR/build.log"; then die 'compiler warning or error found'; fi

object="$BUILD_OUT/kernel/sched/fair.o"
[ -s "$object" ] || die 'E4 fair.o missing'
nm --defined-only "$object" > "$OUT_DIR/fair-symbols.txt"
for symbol in sched_exec_measure_once sched_exec_measure_cell sched_exec_rebuild_measure_matrix_test sched_exec_rebuild_measure_test_suite; do
	grep -Fq " $symbol" "$OUT_DIR/fair-symbols.txt" || die "E4 object symbol missing: $symbol"
done

objdump -d "$object" | "$E4_DIR/scripts/checkstack.pl" arm64 0 > "$OUT_DIR/checkstack.txt"
timed_stack=$(awk '/sched_exec_measure_once / {print $NF}' "$OUT_DIR/checkstack.txt")
cell_stack=$(awk '/sched_exec_measure_cell / {print $NF}' "$OUT_DIR/checkstack.txt")
if [ -z "$timed_stack" ] || [ "$timed_stack" -gt 128 ]; then
	die "timed helper stack too large: ${timed_stack:-missing}"
fi
if [ -z "$cell_stack" ] || [ "$cell_stack" -gt 512 ]; then
	die "cell driver stack too large: ${cell_stack:-missing}"
fi

progress '90% hashing controlled source/object evidence and preserving non-claims'
object_sha=$(sha256sum "$object" | awk '{print $1}')
config_sha=$(sha256sum "$BUILD_OUT/.config" | awk '{print $1}')
plan_sha=$(sha256sum "$plan_result" | awk '{print $1}')
e3_sha=$(sha256sum "$e3_result" | awk '{print $1}')

jq -n \
	--arg run_id "$RUN_ID" --arg parent_commit "$expected_parent" --arg source_commit "$expected_commit" \
	--arg source_tree "$expected_tree" --arg source_diff_sha256 "$diff_hash" --arg primary_commit "$expected_primary" \
	--arg plan_result_sha256 "$plan_sha" --arg e3_result_sha256 "$e3_sha" \
	--arg object "$object" --arg object_sha256 "$object_sha" --arg config "$BUILD_OUT/.config" --arg config_sha256 "$config_sha" \
	--argjson timed_stack_bytes "$timed_stack" --argjson cell_stack_bytes "$cell_stack" \
	'{schema_version:1,run_id:$run_id,status:"passed_e4_source_gate",architecture:"arm64",parent_commit:$parent_commit,source_commit:$source_commit,source_tree:$source_tree,source_diff_sha256:$source_diff_sha256,primary_linux_commit:$primary_commit,patch_queue_tail:"0014-sched-exec_lease-Expand-build-only-layout-probe.patch",plan_result_sha256:$plan_result_sha256,e3_result_sha256:$e3_result_sha256,changed_files:["init/Kconfig","kernel/sched/fair.c"],insertions:356,deletions:0,strict_checkpatch:{errors:0,warnings:0,checks:0},source_isolation_passed:true,frozen_e2_fields_probe_e3_rebuild_makefile:true,default_off_boundary_passed:true,real_fixture_private_to_kunit:true,o1_leaf_callback_passed:true,measured_interval_source_order_passed:true,forbidden_measured_interval_operations_absent:true,matrix:{queue_sizes:[0,1,8,64,256,1024,4096],depths:[0,1,4,16,64],cells:35,warmup_pairs_per_cell:256,measured_pairs_per_cell:10000,result_rows_required:35},gate:{base_slice_ns:700000,additional_p99_limit_ns:25000,additional_max_limit_ns:50000,warning_count_allowed:0},targeted_compile:{object:$object,object_sha256:$object_sha256,config:$config,config_sha256:$config_sha256,compiler_warnings:0,timed_helper_stack_bytes:$timed_stack_bytes,cell_driver_stack_bytes:$cell_stack_bytes,enabled_symbols_present:true},arm64_measurement_may_be_launched:true,x86_64_measurement_may_be_launched:false,e4_measurement_accepted:false,full_locked_rebuild_approved:false,production_layout_accepted:false,hot_field_approved:false,primary_linux_change_approved:false,patch_queue_change_approved:false,real_picker_fence_approved:false,real_publisher_approved:false,real_fanout_approved:false,runtime_behavior_approved:false,runtime_denial_correctness:false,production_protection:false,latency_claim:false,performance_claim:false,cost_claim:false,deployment_ready:false,datacenter_ready:false}' \
	> "$OUT_DIR/result.json"

progress '100% passed; exact E4 source may launch arm64 measurement only'
cat "$OUT_DIR/result.json"
