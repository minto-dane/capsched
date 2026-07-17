#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
E3_DIR="$WORKSPACE_DIR/build/DomainLeaseLinux.volume/worktrees/p5a-r2-e3-rebuild-prototype"
E4_DIR="$WORKSPACE_DIR/build/DomainLeaseLinux.volume/worktrees/p5a-r2-e4-lock-hold"
CONFIG="$CAPSCHED_DIR/capsched-models/implementation/sched-exec-lease-p5a-r2-e4-disposable-lock-hold-measurement-v1.json"
ATTEMPT_RESULT="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r2-e4-arm64-lock-hold-measurement/20260714T-p5a-r2-e4-arm64/result.json"
RUN_ID=${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
OUT_DIR="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r2-e4-lock-hold-source-gate-r2/$RUN_ID"
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
progress '5% exact corrected identity and failed-attempt preservation'
jq empty "$CONFIG"

parent=$(jq -r '.source.parent_commit' "$CONFIG")
commit=$(jq -r '.source.candidate_commit' "$CONFIG")
tree=$(jq -r '.source.candidate_tree' "$CONFIG")
diff_sha=$(jq -r '.source.diff_sha256' "$CONFIG")
[ "$parent" = d1d5e78da8484c91eae70f22399c6901da680ea0 ] || die 'parent metadata moved'
[ "$commit" = f6ad4e454778c52bcdaaecf684c148a3a8dae857 ] || die 'corrected commit metadata moved'
[ "$tree" = 265e6357627490e51084979382ef34b2cfcc0cb8 ] || die 'corrected tree metadata moved'
[ "$diff_sha" = 3f52a2b2724bd795466ab1f344bf3d02fde7ee6a39bfde0945f7f8cf6ab8e3a3 ] || die 'corrected diff metadata moved'
[ "$(git -C "$E3_DIR" rev-parse HEAD)" = "$parent" ] || die 'E3 moved'
[ "$(git -C "$E4_DIR" rev-parse HEAD)" = "$commit" ] || die 'corrected E4 moved'
[ "$(git -C "$E4_DIR" rev-parse HEAD^)" = "$parent" ] || die 'corrected E4 is not a direct E3 child'
[ "$(git -C "$E4_DIR" rev-parse 'HEAD^{tree}')" = "$tree" ] || die 'corrected E4 tree mismatch'
[ -z "$(git -C "$E4_DIR" status --porcelain --untracked-files=no)" ] || die 'corrected E4 dirty'
[ "$(sha256sum "$ATTEMPT_RESULT" | awk '{print $1}')" = 12370a90745e94edd56a50ecf378c2bd7397d0dfd50805d579309b51bed4ee97 ] || die 'attempt-1 result hash mismatch'
jq -e '.status == "harness_failed" and .qemu.result_rows == 0 and .architecture_measurement_valid == false and .this_failure_is_threshold_evidence == false' "$ATTEMPT_RESULT" >/dev/null

git -C "$E4_DIR" diff "$parent..$commit" > "$OUT_DIR/e4-corrected-source.diff"
[ "$(sha256sum "$OUT_DIR/e4-corrected-source.diff" | awk '{print $1}')" = "$diff_sha" ] || die 'corrected full diff mismatch'
git -C "$E4_DIR" diff --name-only "$parent..$commit" > "$OUT_DIR/changed-files.txt"
[ "$(sed -n '1p' "$OUT_DIR/changed-files.txt")" = init/Kconfig ] || die 'first changed file mismatch'
[ "$(sed -n '2p' "$OUT_DIR/changed-files.txt")" = kernel/sched/fair.c ] || die 'second changed file mismatch'
[ "$(wc -l < "$OUT_DIR/changed-files.txt" | tr -d ' ')" = 2 ] || die 'corrected E4 changed more than two files'
[ "$(git -C "$E4_DIR" diff --numstat "$parent..$commit" | awk '{a+=$1; d+=$2} END {print a, d}')" = '362 0' ] || die 'corrected full delta mismatch'

git -C "$E4_DIR" diff dc3618e2bc56d3ede9b8d1378099c7b9ad15e08f.."$commit" > "$OUT_DIR/correction-only.diff"
[ "$(sha256sum "$OUT_DIR/correction-only.diff" | awk '{print $1}')" = 22cb55c3a8a9841122820a467712c015ba761961676898160f941157fc3414ed ] || die 'correction-only diff mismatch'
[ "$(git -C "$E4_DIR" diff --name-only dc3618e2bc56d3ede9b8d1378099c7b9ad15e08f.."$commit")" = kernel/sched/fair.c ] || die 'correction escaped fair.c'
[ "$(git -C "$E4_DIR" diff --numstat dc3618e2bc56d3ede9b8d1378099c7b9ad15e08f.."$commit" | awk '{print $1, $2}')" = '10 4' ] || die 'correction-only delta mismatch'

jq -e '
  .status == "corrected_source_gate_passed_arm64_remeasurement_pending" and
  .source.insertions == 362 and .source.deletions == 0 and
  .gate.base_slice_ns == 700000 and
  .gate.base_slice_semantics == "normalized_sysctl_sched_base_slice_fixed_threshold_basis" and
  .gate.runtime_scaled_base_slice_recorded_separately == true and
  .gate.runtime_scaling_may_not_relax_thresholds == true and
  .gate.additional_p99_limit_ns == 25000 and .gate.additional_max_limit_ns == 50000 and
  .matrix.cell_count == 35 and .matrix.warmup_pairs_per_cell == 256 and .matrix.measured_pairs_per_cell == 10000 and
  .arm64_attempt_1.status == "harness_failed" and .arm64_attempt_1.measurement_rows == 0 and .arm64_attempt_1.valid_threshold_evidence == false and
  .source_correction.correction_diff_sha256 == "22cb55c3a8a9841122820a467712c015ba761961676898160f941157fc3414ed" and
  .source_correction.matrix_unchanged == true and .source_correction.samples_unchanged == true and .source_correction.thresholds_unchanged == true and
  .authorization_after_source_gate.arm64_measurement_may_be_launched == true and
  .authorization_after_source_gate.e4_measurement_accepted == false and .authorization_after_source_gate.full_locked_rebuild_approved == false and
  .source_correction.corrected_source_gate_required == false and
  .controlled_corrected_source_gate.result_sha256 == "956007be42687193c9d3eeb29e5e0be80dcaeba16d22436c71e06a017a870adc" and
  .controlled_corrected_source_gate.status == "passed_e4_corrected_source_gate" and
  .controlled_corrected_source_gate.arm64_measurement_may_be_relaunched == true and
  .controlled_corrected_source_gate.x86_64_measurement_may_be_launched == false and
  (.safety_flags | all(.[]; . == false))
' "$CONFIG" >/dev/null

progress '30% normalized/runtime base-slice semantics and unchanged interval'
source_file="$E4_DIR/kernel/sched/fair.c"
grep -Fq '#define SCHED_EXEC_MEASURE_BASE_SLICE_NS 700000U' "$source_file" || die 'fixed normalized baseline missing'
grep -Fq 'normalized_base_slice = READ_ONCE(normalized_sysctl_sched_base_slice);' "$source_file" || die 'normalized base-slice read missing'
grep -Fq 'runtime_base_slice = READ_ONCE(sysctl_sched_base_slice);' "$source_file" || die 'runtime base-slice record missing'
grep -Fq 'KUNIT_ASSERT_EQ(test, normalized_base_slice,' "$source_file" || die 'normalized baseline assertion missing'
grep -Fq 'runtime_base_slice_ns=%u tunable_scaling=%u online_cpus=%u' "$source_file" || die 'runtime scaling metadata missing'
if grep -Fq 'KUNIT_ASSERT_EQ(test, READ_ONCE(sysctl_sched_base_slice), 700000U)' "$source_file"; then die 'invalid runtime assertion remains'; fi

sed -n '/^static u64 sched_exec_measure_once(/,/^}/p' "$source_file" > "$OUT_DIR/measured-interval.txt"
for required in 'local_irq_save(flags);' 'start = local_clock();' 'raw_spin_rq_lock(&fixture->rq);' 'ret = sched_exec_rebuild_rq_test' 'barrier();' 'raw_spin_rq_unlock(&fixture->rq);' 'end = local_clock();' 'local_irq_restore(flags);'; do
	grep -Fq "$required" "$OUT_DIR/measured-interval.txt" || die "measured interval missing: $required"
done
if grep -Eq '\b(kmalloc|kzalloc|kvalloc|kvzalloc|kfree|kvfree|sort|printk|pr_|trace_|schedule|cond_resched|msleep|usleep|wait_event|policy|monitor|rb_add|rb_erase)\b' "$OUT_DIR/measured-interval.txt"; then die 'forbidden operation entered measured interval'; fi
grep -Fq '#define SCHED_EXEC_MEASURE_SAMPLES 10000U' "$source_file" || die 'samples changed'
grep -Fq '#define SCHED_EXEC_MEASURE_WARMUPS 256U' "$source_file" || die 'warmups changed'
grep -Fq '#define SCHED_EXEC_MEASURE_CELL_COUNT 35U' "$source_file" || die 'matrix changed'
grep -Fq 'static const unsigned int queue_sizes[] = { 0, 1, 8, 64, 256, 1024, 4096 };' "$source_file" || die 'queue sizes changed'
grep -Fq 'static const unsigned int depths[] = { 0, 1, 4, 16, 64 };' "$source_file" || die 'depths changed'

progress '55% strict checkpatch and E4-enabled arm64 fair.o rebuild'
set +e
git -C "$E4_DIR" diff "$parent..$commit" | "$E4_DIR/scripts/checkpatch.pl" --strict --no-tree - > "$OUT_DIR/checkpatch.log" 2>&1
checkpatch_rc=$?
set -e
[ "$checkpatch_rc" = 0 ] || die 'strict checkpatch failed'
grep -Fq 'total: 0 errors, 0 warnings, 0 checks' "$OUT_DIR/checkpatch.log" || die 'strict checkpatch summary mismatch'
for config_line in 'CONFIG_FAIR_GROUP_SCHED=y' 'CONFIG_KUNIT=y' 'CONFIG_SCHED_EXEC_LEASE_REBUILD_KUNIT_TEST=y' 'CONFIG_SCHED_EXEC_LEASE_REBUILD_MEASURE_KUNIT_TEST=y'; do
	grep -Fxq "$config_line" "$BUILD_OUT/.config" || die "build config missing: $config_line"
done
rm -f "$BUILD_OUT/kernel/sched/fair.o"
set +e
make -C "$E4_DIR" O="$BUILD_OUT" ARCH=arm64 -j"$JOBS" kernel/sched/fair.o > "$OUT_DIR/build.log" 2>&1
build_rc=$?
set -e
[ "$build_rc" = 0 ] || die 'corrected fair.o build failed'
if grep -Eqi '(^|[^[:alpha:]])(warning|error):' "$OUT_DIR/build.log"; then die 'compiler warning or error found'; fi
object="$BUILD_OUT/kernel/sched/fair.o"
nm --defined-only "$object" > "$OUT_DIR/fair-symbols.txt"
for symbol in sched_exec_measure_once sched_exec_measure_cell sched_exec_rebuild_measure_matrix_test sched_exec_rebuild_measure_test_suite; do
	grep -Fq " $symbol" "$OUT_DIR/fair-symbols.txt" || die "object symbol missing: $symbol"
done
objdump -d "$object" | "$E4_DIR/scripts/checkstack.pl" arm64 0 > "$OUT_DIR/checkstack.txt"
timed_stack=$(awk '/sched_exec_measure_once / {sub(/^.*:/, ""); gsub(/[[:space:]]/, ""); print}' "$OUT_DIR/checkstack.txt")
cell_stack=$(awk '/sched_exec_measure_cell / {sub(/^.*:/, ""); gsub(/[[:space:]]/, ""); print}' "$OUT_DIR/checkstack.txt")
matrix_stack=$(awk '/sched_exec_rebuild_measure_matrix_test / {sub(/^.*:/, ""); gsub(/[[:space:]]/, ""); print}' "$OUT_DIR/checkstack.txt")
[ "$timed_stack" = 96 ] || die "timed helper stack moved: $timed_stack"
[ "$cell_stack" = 384 ] || die "cell stack moved: $cell_stack"
if [ -z "$matrix_stack" ] || [ "$matrix_stack" -gt 256 ]; then
	die "matrix stack too large: ${matrix_stack:-missing}"
fi

progress '90% hashing corrected evidence and preserving non-claims'
object_sha=$(sha256sum "$object" | awk '{print $1}')
config_sha=$(sha256sum "$BUILD_OUT/.config" | awk '{print $1}')
attempt_sha=$(sha256sum "$ATTEMPT_RESULT" | awk '{print $1}')
jq -n \
	--arg run_id "$RUN_ID" --arg source_commit "$commit" --arg source_tree "$tree" --arg source_diff_sha256 "$diff_sha" \
	--arg correction_diff_sha256 22cb55c3a8a9841122820a467712c015ba761961676898160f941157fc3414ed \
	--arg attempt_1_result_sha256 "$attempt_sha" --arg object "$object" --arg object_sha256 "$object_sha" \
	--arg config "$BUILD_OUT/.config" --arg config_sha256 "$config_sha" \
	--argjson timed_stack_bytes "$timed_stack" --argjson cell_stack_bytes "$cell_stack" --argjson matrix_stack_bytes "$matrix_stack" \
	'{schema_version:1,run_id:$run_id,status:"passed_e4_corrected_source_gate",parent_commit:"d1d5e78da8484c91eae70f22399c6901da680ea0",source_commit:$source_commit,source_tree:$source_tree,source_diff_sha256:$source_diff_sha256,correction_diff_sha256:$correction_diff_sha256,attempt_1_result_sha256:$attempt_1_result_sha256,changed_files:["init/Kconfig","kernel/sched/fair.c"],insertions:362,deletions:0,strict_checkpatch:{errors:0,warnings:0,checks:0},base_slice:{fixed_normalized_ns:700000,normalized_asserted:true,runtime_scaled_value_recorded:true,tunable_scaling_recorded:true,online_cpus_recorded:true,runtime_scaling_may_relax_thresholds:false},matrix:{cells:35,warmup_pairs_per_cell:256,measured_pairs_per_cell:10000},gate:{additional_p99_limit_ns:25000,additional_max_limit_ns:50000,thresholds_unchanged:true},measured_interval_unchanged:true,forbidden_measured_interval_operations_absent:true,targeted_compile:{object:$object,object_sha256:$object_sha256,config:$config,config_sha256:$config_sha256,compiler_warnings:0,timed_helper_stack_bytes:$timed_stack_bytes,cell_driver_stack_bytes:$cell_stack_bytes,matrix_case_stack_bytes:$matrix_stack_bytes},arm64_measurement_may_be_relaunched:true,x86_64_measurement_may_be_launched:false,e4_measurement_accepted:false,full_locked_rebuild_approved:false,production_layout_accepted:false,runtime_behavior_approved:false,production_protection:false,latency_claim:false,performance_claim:false,cost_claim:false,deployment_ready:false,datacenter_ready:false}' \
	> "$OUT_DIR/result.json"
progress '100% passed; corrected exact E4 source may relaunch arm64 measurement only'
cat "$OUT_DIR/result.json"
