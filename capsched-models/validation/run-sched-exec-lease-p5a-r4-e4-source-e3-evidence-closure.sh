#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
LINUX_DIR="$WORKSPACE_DIR/build/DomainLeaseLinux.volume/linux"
PATCH_QUEUE_DIR="$WORKSPACE_DIR/linux-patches"
SOURCE_RUN_ID=20260721T-p5a-r4-e4-coalesced-owner-source-e3-regression-r5
CANONICAL_COMBINED_DIR="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r4-e4-source-and-e3-regression/$SOURCE_RUN_ID"
CANONICAL_SOURCE_DIR="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r4-e4-local-quantum-source-gate/$SOURCE_RUN_ID-source"
CANONICAL_CONFIG_DIR="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r4-e4-e3-six-profile-regression/$SOURCE_RUN_ID-config-smoke"
CANONICAL_REGRESSION_DIR="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r4-e4-e3-six-profile-regression/$SOURCE_RUN_ID-e3-regression"
RUNNER_SOURCE=${BASH_SOURCE[0]}
RUN_ID=${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
PROGRESS_FILE=${PROGRESS_FILE:-}
CLOSURE_TEST_MODE=${CLOSURE_TEST_MODE:-0}
PREFLIGHT_ONLY=${PREFLIGHT_ONLY:-0}
SOURCE_BUNDLE_OVERRIDE=${SOURCE_BUNDLE_OVERRIDE:-}

if [ "$CLOSURE_TEST_MODE" = 1 ]; then
	[ "$PREFLIGHT_ONLY" = 1 ] || { printf 'error: test mode requires PREFLIGHT_ONLY=1\n' >&2; exit 1; }
	[ -n "$SOURCE_BUNDLE_OVERRIDE" ] || { printf 'error: test mode requires SOURCE_BUNDLE_OVERRIDE\n' >&2; exit 1; }
	COMBINED_DIR="$SOURCE_BUNDLE_OVERRIDE/combined"
	SOURCE_DIR="$SOURCE_BUNDLE_OVERRIDE/source"
	CONFIG_DIR="$SOURCE_BUNDLE_OVERRIDE/config"
	REGRESSION_DIR="$SOURCE_BUNDLE_OVERRIDE/regression"
	OUT_ROOT="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r4-e4-source-e3-evidence-closure-test"
else
	[ "$PREFLIGHT_ONLY" = 0 ] || { printf 'error: PREFLIGHT_ONLY is restricted to test mode\n' >&2; exit 1; }
	[ -z "$SOURCE_BUNDLE_OVERRIDE" ] || { printf 'error: SOURCE_BUNDLE_OVERRIDE is restricted to test mode\n' >&2; exit 1; }
	COMBINED_DIR=$CANONICAL_COMBINED_DIR
	SOURCE_DIR=$CANONICAL_SOURCE_DIR
	CONFIG_DIR=$CANONICAL_CONFIG_DIR
	REGRESSION_DIR=$CANONICAL_REGRESSION_DIR
	OUT_ROOT="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r4-e4-source-e3-evidence-closure"
fi

OUT_DIR="$OUT_ROOT/$RUN_ID"
INPUT_DIR="$OUT_DIR/inputs"
COMBINED_EVIDENCE="$INPUT_DIR/combined"
SOURCE_EVIDENCE="$INPUT_DIR/source"
CONFIG_EVIDENCE="$INPUT_DIR/config"
REGRESSION_EVIDENCE="$INPUT_DIR/regression"

# Fresh r5 producer roots, enumerated only after its detached wrapper exited 0.
EVIDENCE_SEAL_FINALIZED=1
COMBINED_RESULT_SHA=6a77daf360696e012abd239d489cb55900c005946c053a7163297b12dc8b3777
SOURCE_RESULT_SHA=24be737d935dbd4f7ecca7ccbf1dd2f6cea678c9dd3cc76146af5b2a32418989
CONFIG_RESULT_SHA=6c0be87fa2390affc44c51b9e059e98228ead1055990cd1bfd4bda90090a267a
REGRESSION_RESULT_SHA=fd55860285824aa4fe946f35cea30f50493b908be1e9ee2f85eaedf735369a00
BOOT_RESULTS_SHA=1749d60e17bf59baa1906a684efea7868e5a339eadd5335de40972ce18059c7f
COMBINED_MANIFEST_SHA=47b73ec0e95dd0520e9c610a321c2a8da39c6946ebdf9fec1339445e3b51cc43
SOURCE_MANIFEST_SHA=b60775da8d511fc6463ebe8f4ae44e03b072ef5f3f9f26da3acd51a9a11ab941
CONFIG_MANIFEST_SHA=7abbdecea1ca38a67396aef811f89f57ce94a2fa8e61d079142d1ee18f2ebb3f
REGRESSION_MANIFEST_SHA=94b9d20788d770a8713b29a8a0f64e25bff31533485eb116a26553127879b54a
SOURCE_INTERNAL_MANIFEST_SHA=1980773c25ef61e860dd93cf0f594c2f4cfb7a0c78cc01d202a488aa727f94d9
COMBINED_COUNT=2
SOURCE_COUNT=82
CONFIG_COUNT=53
REGRESSION_COUNT=133
COMBINED_BYTES=2033
SOURCE_BYTES=5070721
CONFIG_BYTES=1665227
REGRESSION_BYTES=4133405
SOURCE_RUNNER_SHA=b5815d21564480f51570c62008a680bacbefbda4a29514633264b80ede4dbcff
REGRESSION_RUNNER_SHA=16ae06b59823080cfcb127551dec6d59d0eb50509d4b312930728d18039a31a6
COMBINED_RUNNER_SHA=b6a779044ad4547dba2849cd62e34f57a814fe74f05fd10875e8be8b39f1101c
WARNING_CLASSIFIER_SHA=8adcff74f0395f5ec219343c0cb5b1f179efee2292ab853d4fc7e410467dc23a
HARDENING_LIB_SHA=4548753bc2acaa7497aef9e9ff070d9952f9b5ee20631c6116590067eab9ccc6
PLAN_SHA=f9c9103b4eae2177309dd8e0134601fe3cf1eb08061986265627dcd9d8fd6677
PRIMARY_COMMIT=5e1ca3037e34823d1ba0cdd1dc04161fac170280
PATCH_QUEUE_COMMIT=16bb080da472ffabbbafd2698073eca633fb0602
CANDIDATE_PARENT=da9ce9159b3450c28c8faf8dceac671fb7bfeba2
CANDIDATE_COMMIT=82d91805f8e145d2403057f656e590e4bcae12f1
CANDIDATE_TREE=44d9a2125eac6eac4c8c25f38fb6a5eae3a5bd4f
CANDIDATE_DIFF_SHA=a7cb42fe5fc6f346ba8ea009097fa15433050e79e3255d64467d7b8ad636aeb9
SUITE=sched_exec_lease_r4_concurrency

die()
{
	printf 'error: %s\n' "$*" >&2
	exit 1
}

progress()
{
	printf '[progress] %s\n' "$*"
	if [ -n "$PROGRESS_FILE" ]; then
		printf '%s\n' "$*" > "$PROGRESS_FILE"
	fi
}

file_sha()
{
	sha256sum "$1" | awk '{print $1}'
}

tree_manifest()
{
	local root=$1
	(
		cd "$root"
		find . -type f -print0 | sort -z | xargs -0 sha256sum
	)
}

tree_bytes()
{
	find "$1" -type f -printf '%s\n' | awk '{sum += $1} END {printf "%.0f\n", sum}'
}

verify_hash()
{
	local file=$1 expected=$2 label=$3
	[ -f "$file" ] || die "$label missing"
	[ ! -L "$file" ] || die "$label is a symlink"
	[ "$(file_sha "$file")" = "$expected" ] || die "$label hash changed"
}

verify_recorded_hash()
{
	local result=$1 field=$2 file=$3 label=$4 expected
	expected=$(jq -er "$field" "$result") || die "$label hash field missing"
	verify_hash "$file" "$expected" "$label"
}

snapshot_root()
{
	local label=$1 source=$2 destination=$3 expected_count=$4 expected_bytes=$5 expected_manifest=$6
	local before="$OUT_DIR/$label-before.sha256"
	local after="$OUT_DIR/$label-after.sha256"
	local snapshot="$OUT_DIR/$label-snapshot.sha256"

	[ -d "$source" ] || die "$label evidence root missing"
	[ ! -L "$source" ] || die "$label evidence root is a symlink"
	[ -z "$(find "$source" -type l -print -quit)" ] || die "$label evidence contains a symlink"
	[ -z "$(find "$source" ! -type f ! -type d -print -quit)" ] || die "$label evidence contains a non-regular object"
	[ "$(find "$source" -type f | wc -l | tr -d ' ')" = "$expected_count" ] || die "$label artifact count changed"
	[ "$(tree_bytes "$source")" = "$expected_bytes" ] || die "$label artifact byte count changed"
	tree_manifest "$source" > "$before"
	[ "$(file_sha "$before")" = "$expected_manifest" ] || die "$label artifact manifest changed"
	cp -a -- "$source/." "$destination/"
	tree_manifest "$source" > "$after"
	tree_manifest "$destination" > "$snapshot"
	diff -u "$before" "$after" > "$OUT_DIR/$label-race.diff" || die "$label evidence changed while snapshotting"
	diff -u "$before" "$snapshot" > "$OUT_DIR/$label-snapshot.diff" || die "$label snapshot differs"
	[ -z "$(find "$destination" -type l -print -quit)" ] || die "$label snapshot contains a symlink"
	[ "$(find "$destination" -type f | wc -l | tr -d ' ')" = "$expected_count" ] || die "$label snapshot count changed"
	[ "$(tree_bytes "$destination")" = "$expected_bytes" ] || die "$label snapshot bytes changed"
	chmod -R a-w "$destination"
}

case "$RUN_ID" in
	[A-Za-z0-9]*) ;;
	*) die 'RUN_ID must begin with an alphanumeric character' ;;
esac
case "$RUN_ID" in
	*[!A-Za-z0-9._-]*|.|..) die 'RUN_ID contains an unsafe component' ;;
esac
case "$CLOSURE_TEST_MODE:$PREFLIGHT_ONLY" in
	0:0|1:1) ;;
	*) die 'invalid closure mode' ;;
esac
[ "$EVIDENCE_SEAL_FINALIZED" = 1 ] || die 'fresh r4 evidence seal is not finalized'
for command in awk chmod cmp cp diff find git grep jq mkdir mv sed sha256sum sort stat strings tr wc xargs; do
	command -v "$command" >/dev/null 2>&1 || die "missing command: $command"
done
if [ -e "$OUT_DIR" ] || [ -L "$OUT_DIR" ]; then
	die "run output already exists: $OUT_DIR"
fi
mkdir -p "$OUT_ROOT"
mkdir "$OUT_DIR" "$INPUT_DIR" "$COMBINED_EVIDENCE" "$SOURCE_EVIDENCE" "$CONFIG_EVIDENCE" "$REGRESSION_EVIDENCE"
chmod 0700 "$OUT_DIR" "$INPUT_DIR"
runner_initial_sha=$(file_sha "$RUNNER_SOURCE")
cp -- "$RUNNER_SOURCE" "$INPUT_DIR/closure-runner.sh"
chmod 0444 "$INPUT_DIR/closure-runner.sh"

total_artifacts=$((COMBINED_COUNT + SOURCE_COUNT + CONFIG_COUNT + REGRESSION_COUNT))
total_bytes=$((COMBINED_BYTES + SOURCE_BYTES + CONFIG_BYTES + REGRESSION_BYTES))
progress "5% snapshotting and race-checking all $total_artifacts retained artifacts"
snapshot_root combined "$COMBINED_DIR" "$COMBINED_EVIDENCE" "$COMBINED_COUNT" "$COMBINED_BYTES" "$COMBINED_MANIFEST_SHA"
snapshot_root source "$SOURCE_DIR" "$SOURCE_EVIDENCE" "$SOURCE_COUNT" "$SOURCE_BYTES" "$SOURCE_MANIFEST_SHA"
snapshot_root config "$CONFIG_DIR" "$CONFIG_EVIDENCE" "$CONFIG_COUNT" "$CONFIG_BYTES" "$CONFIG_MANIFEST_SHA"
snapshot_root regression "$REGRESSION_DIR" "$REGRESSION_EVIDENCE" "$REGRESSION_COUNT" "$REGRESSION_BYTES" "$REGRESSION_MANIFEST_SHA"

COMBINED_RESULT="$COMBINED_EVIDENCE/result.json"
SOURCE_RESULT="$SOURCE_EVIDENCE/result.json"
CONFIG_RESULT="$CONFIG_EVIDENCE/config-smoke-result.json"
REGRESSION_RESULT="$REGRESSION_EVIDENCE/result.json"
verify_hash "$COMBINED_RESULT" "$COMBINED_RESULT_SHA" 'combined result'
verify_hash "$SOURCE_RESULT" "$SOURCE_RESULT_SHA" 'source result'
verify_hash "$CONFIG_RESULT" "$CONFIG_RESULT_SHA" 'config-smoke result'
verify_hash "$REGRESSION_RESULT" "$REGRESSION_RESULT_SHA" 'E3 regression result'
verify_hash "$REGRESSION_EVIDENCE/boot-results.json" "$BOOT_RESULTS_SHA" 'boot-results array'
[ "$(awk '{print $1}' "$COMBINED_EVIDENCE/result.sha256")" = "$COMBINED_RESULT_SHA" ] || die 'combined result seal changed'
[ "$(awk '{print $1}' "$SOURCE_EVIDENCE/result.sha256")" = "$SOURCE_RESULT_SHA" ] || die 'source result seal changed'
[ "$(awk '{print $1}' "$REGRESSION_EVIDENCE/result.sha256")" = "$REGRESSION_RESULT_SHA" ] || die 'regression result seal changed'

progress '15% auditing combined linkage and exact six-object source evidence'
verify_hash "$SCRIPT_DIR/run-sched-exec-lease-p5a-r4-e4-local-quantum-source-gate.sh" "$SOURCE_RUNNER_SHA" 'current source runner'
verify_hash "$SCRIPT_DIR/run-sched-exec-lease-p5a-r4-e4-source-and-e3-regression.sh" "$COMBINED_RUNNER_SHA" 'current combined runner'
jq -e --arg run_id "$SOURCE_RUN_ID" --arg candidate "$CANDIDATE_COMMIT" \
	--arg source_sha "$SOURCE_RESULT_SHA" --arg config_sha "$CONFIG_RESULT_SHA" \
	--arg regression_sha "$REGRESSION_RESULT_SHA" '
  .schema_version == 1 and
  .id == "sched-exec-lease-p5a-r4-e4-source-and-e3-regression-result-v1" and
  .run_id == $run_id and
  .status == "passed_source_and_six_profile_e3_regression_awaiting_independent_closure" and
  .candidate_commit == $candidate and
  .source_gate_result_sha256 == $source_sha and
  .config_smoke_result_sha256 == $config_sha and
  .e3_regression_result_sha256 == $regression_sha and
  .fresh_source_objects == 6 and .e3_profiles == 6 and
  .e3_cases_passed == 216 and .e3_receipts == 216 and
  .vcpu_migration_observation_enforced == true and
  .irq_preempt_state_recorded == true and
  .independent_closure_required == true and .timing_measurement_may_start == false and
  .r4_e4_source_accepted == false and .real_scheduler_attachment == false and
  .runtime_behavior_approved == false and .production_protection == false and
  .deployment_ready == false and .multi_cluster_ready == false and .datacenter_ready == false
' "$COMBINED_RESULT" >/dev/null
jq -e --arg run_id "$SOURCE_RUN_ID-source" --arg candidate "$CANDIDATE_COMMIT" \
	--arg parent "$CANDIDATE_PARENT" --arg tree "$CANDIDATE_TREE" \
	--arg diff_sha "$CANDIDATE_DIFF_SHA" --arg primary "$PRIMARY_COMMIT" \
	--arg patch_queue "$PATCH_QUEUE_COMMIT" '
  .schema_version == 1 and
  .id == "sched-exec-lease-p5a-r4-e4-local-quantum-source-gate-result-v1" and
  .run_id == $run_id and
  .status == "passed_source_and_object_gate_awaiting_six_profile_e3_regression" and
  .candidate_commit == $candidate and .candidate_parent == $parent and
  .candidate_tree == $tree and .candidate_diff_sha256 == $diff_sha and
  .primary_commit == $primary and .patch_queue_commit == $patch_queue and
  .allowed_files == ["init/Kconfig","kernel/sched/exec_lease.c"] and
  .strict_checkpatch == {errors:0,warnings:0,checks:0} and
  .architectures == ["arm64","x86_64"] and
  .fresh_modes_per_architecture == ["exact_e3_parent","e4_measure_off","e4_measure_on"] and
  .fresh_objects == 6 and .w1_compiler_diagnostics == 0 and
  .clock_skew_retries == 0 and .final_clock_skew_warnings == 0 and
  .disabled_e4_artifacts == 0 and .e3_cases_byte_preserved == 36 and
  .e4_measurement_cells == 682 and .artifact_count == 79 and
  .measurement_task_migration_disabled == true and
  .vcpu_migration_observation_enforced == true and
  .irq_preempt_state_recorded == true and
  .six_profile_e3_regression_required == true and .timing_measurement_may_start == false and
  .r4_e4_source_accepted == false and .production_protection == false and .datacenter_ready == false
' "$SOURCE_RESULT" >/dev/null
verify_hash "$SOURCE_EVIDENCE/artifact-manifest.sha256" "$SOURCE_INTERNAL_MANIFEST_SHA" 'source internal artifact manifest'
[ "$(wc -l < "$SOURCE_EVIDENCE/artifact-manifest.sha256" | tr -d ' ')" = 79 ] || die 'source internal manifest count changed'
while read -r expected path; do
	case "$path" in
		"$CANONICAL_SOURCE_DIR"/*) relative=${path#"$CANONICAL_SOURCE_DIR"/} ;;
		*) die 'source internal manifest path escaped canonical root' ;;
	esac
	verify_hash "$SOURCE_EVIDENCE/$relative" "$expected" "source artifact $relative"
done < "$SOURCE_EVIDENCE/artifact-manifest.sha256"
[ "$(cat "$SOURCE_EVIDENCE/changed-files.txt")" = $'init/Kconfig\nkernel/sched/exec_lease.c' ] || die 'source changed-file set changed'
[ ! -s "$SOURCE_EVIDENCE/changed-files.diff" ] || die 'source changed-file order differs'
grep -Eq '^total: 0 errors, 0 warnings, 0 checks, [0-9]+ lines checked$' \
	"$SOURCE_EVIDENCE/checkpatch.log" || die 'strict checkpatch summary changed'
! grep -Eq '^(ERROR|WARNING|CHECK):' "$SOURCE_EVIDENCE/checkpatch.log" || die 'strict checkpatch diagnostic found'
verify_hash "$SOURCE_EVIDENCE/e4-source.diff" "$CANDIDATE_DIFF_SHA" 'retained E4 source diff'
cmp "$SOURCE_EVIDENCE/e3-parent-cases.c" "$SOURCE_EVIDENCE/e4-e3-cases.c" || die 'E3 case region changed'
[ ! -s "$SOURCE_EVIDENCE/e4-cases.diff" ] || die 'E4 planned/actual case diff is nonempty'
cmp "$SOURCE_EVIDENCE/expected-e4-cases.txt" "$SOURCE_EVIDENCE/actual-e4-cases.txt" || die 'E4 case list changed'
[ "$(wc -l < "$SOURCE_EVIDENCE/actual-e4-cases.txt" | tr -d ' ')" = 7 ] || die 'E4 family count changed'
grep -Fq 'config SCHED_EXEC_LEASE_R4_MEASURE_KUNIT_TEST' "$SOURCE_EVIDENCE/e4-kconfig.txt" || die 'E4 config missing'
grep -Fq 'default n' "$SOURCE_EVIDENCE/e4-kconfig.txt" || die 'E4 config is not default-off'

# Timing r4 exposed an invalid synthetic diagnostic after false queue returns.
# Preserve the correction independently of the producer's source gate: false
# proves coalesced ownership at the queue operation, while a later state read
# may legitimately observe that owner after it has completed.
for helper in kick_locked dispatch_one queue_notifier; do
	file="$SOURCE_EVIDENCE/$helper.c"
	[ -s "$file" ] || die "coalesced-owner helper evidence missing: $helper"
	! grep -Fq 'protocol_errors++' "$file" ||
		die "post-return coalesced-owner diagnostic returned: $helper"
done
grep -Fq 'False itself proves a live coalesced irq-work owner.' \
	"$SOURCE_EVIDENCE/kick_locked.c" || die 'irq-work false ownership proof changed'
grep -Fq 'The coalesced owner completed before this diagnostic read.' \
	"$SOURCE_EVIDENCE/dispatch_one.c" || die 'workqueue completion-race classification changed'
grep -Fq 'False itself proves a live coalesced notifier owner.' \
	"$SOURCE_EVIDENCE/queue_notifier.c" || die 'notifier false ownership proof changed'

# Independently re-audit the plan-to-source observability contract.  The hard
# IRQ observations are deliberately checked in their shared dispatch helper;
# all per-cell and per-family observations remain checked in the E4-only block.
hard_irq="$SOURCE_EVIDENCE/hard-irq-dispatch.c"
e4_block="$SOURCE_EVIDENCE/e4-block.c"
[ -s "$hard_irq" ] || die 'shared hard-IRQ dispatch evidence missing'
[ "$(grep -Fc 'static void sched_exec_r4_dispatch_irq(struct irq_work *work)' "$hard_irq")" = 2 ] ||
	die 'shared hard-IRQ dispatch boundary changed'
for anchor in \
	'rq->measure_irq_cpu = raw_smp_processor_id();' \
	'rq->measure_irq_irqs_disabled = irqs_disabled();' \
	'rq->measure_irq_preempt_depth = preempt_count();'; do
	[ "$(grep -Fc "$anchor" "$hard_irq")" = 1 ] ||
		die "hard-IRQ observation cardinality changed: $anchor"
done
[ "$(grep -Fc $'\tmigrate_disable();' "$e4_block")" = 1 ] || die 'per-cell migration pin cardinality changed'
[ "$(grep -Fc $'\tcell->measurement_cpu = smp_processor_id();' "$e4_block")" = 1 ] || die 'measurement CPU selection cardinality changed'
[ "$(grep -Fc $'\tmigrate_enable();' "$e4_block")" = 1 ] || die 'per-cell migration unpin cardinality changed'
[ "$(grep -Fc 'sample.cpu_migration = sample.cpu != cell->measurement_cpu;' "$e4_block")" = 7 ] || die 'seven-family CPU migration audit failed'
[ "$(grep -Fc 'sample.irqs_disabled =' "$e4_block")" = 7 ] || die 'seven-family IRQ-state audit failed'
[ "$(grep -Fc 'sample.preempt_depth =' "$e4_block")" = 7 ] || die 'seven-family preemption-state audit failed'
[ "$(grep -Fc 'if (smp_processor_id() != cell->measurement_cpu) {' "$e4_block")" = 1 ] || die 'end-of-cell migration audit changed'
for key in measurement_cpu cpu_migrations control_irqs_disabled \
	treatment_irqs_disabled control_preempt_depth treatment_preempt_depth \
	state_errors; do
	[ "$(grep -Fc "${key}=%" "$e4_block")" = 1 ] || die "result row observation changed: $key"
done
sed -n '/if (control.clock_error || treatment.clock_error ||/,/cell->harness_errors++;/p' \
	"$e4_block" > "$OUT_DIR/pair-migration-harness-branch.c"
grep -Fq 'control.cpu_migration || treatment.cpu_migration ||' \
	"$OUT_DIR/pair-migration-harness-branch.c" || die 'sample migration is not a harness error'
grep -Fq 'cell->harness_errors++;' "$OUT_DIR/pair-migration-harness-branch.c" ||
	die 'sample migration harness rejection missing'
sed -n '/} else if (cell->control_irqs_disabled != control.irqs_disabled ||/,/^\t}/p' \
	"$e4_block" > "$OUT_DIR/state-drift-harness-branch.c"
for anchor in \
	'cell->control_irqs_disabled != control.irqs_disabled ||' \
	'cell->treatment_irqs_disabled != treatment.irqs_disabled ||' \
	'cell->control_preempt_depth != control.preempt_depth ||' \
	'cell->treatment_preempt_depth != treatment.preempt_depth) {' \
	'cell->state_errors++;' 'cell->harness_errors++;'; do
	grep -Fq "$anchor" "$OUT_DIR/state-drift-harness-branch.c" ||
		die "state drift harness rejection changed: $anchor"
done
sed -n '/if (smp_processor_id() != cell->measurement_cpu) {/,/^\t}/p' \
	"$e4_block" > "$OUT_DIR/end-cell-migration-harness-branch.c"
grep -Fq 'cell->cpu_migrations++;' "$OUT_DIR/end-cell-migration-harness-branch.c" ||
	die 'end-of-cell migration count missing'
grep -Fq 'cell->harness_errors++;' "$OUT_DIR/end-cell-migration-harness-branch.c" ||
	die 'end-of-cell migration rejection missing'
[ "$(grep -Fc 'KUNIT_EXPECT_EQ(test, cell->harness_errors, 0U);' "$e4_block")" = 1 ] ||
	die 'harness-error KUnit rejection changed'
[ -z "$(find "$SOURCE_EVIDENCE" -type f -name '*.o' -print -quit)" ] || die 'source evidence retained an object'
for label in arm64-e3-parent arm64-e4-off arm64-e4-on x86_64-e3-parent x86_64-e4-off x86_64-e4-on; do
	[ ! -s "$SOURCE_EVIDENCE/$label-build-verify.log" ] || die "$label build verification log is nonempty"
	[ ! -s "$SOURCE_EVIDENCE/$label-defconfig-verify.log" ] || die "$label defconfig verification log is nonempty"
	[ ! -s "$SOURCE_EVIDENCE/$label-olddefconfig-verify.log" ] || die "$label olddefconfig verification log is nonempty"
	! grep -Eq ':[0-9]+(:[0-9]+)?: (fatal )?(warning|error):|Clock skew detected|modification time .* in the future' \
		"$SOURCE_EVIDENCE/$label-build.log" "$SOURCE_EVIDENCE/$label-defconfig.log" "$SOURCE_EVIDENCE/$label-olddefconfig.log" || die "$label diagnostic found"
	grep -Eq '^[0-9a-f]{64}[[:space:]]+/var/tmp/linux-cap-builds/p5a-r4-e4-source-gate/' \
		"$SOURCE_EVIDENCE/$label-object.sha256" || die "$label object seal changed"
	case "$label" in
		*-e3-parent|*-e4-off)
			! grep -Eq 'sched_exec_r4_measure|sched_exec_lease_r4_measure|R4_E4_(RESULT|SUMMARY)' \
				"$SOURCE_EVIDENCE/$label-nm.txt" "$SOURCE_EVIDENCE/$label-strings.txt" \
				"$SOURCE_EVIDENCE/$label-relocations.txt" || die "$label contains disabled E4 artifact"
			;;
		*-e4-on)
			grep -Fq 'sched_exec_lease_r4_measure' "$SOURCE_EVIDENCE/$label-strings.txt" || die "$label suite string missing"
			grep -Fq 'R4_E4_RESULT' "$SOURCE_EVIDENCE/$label-strings.txt" || die "$label result string missing"
			;;
	esac
done

progress '35% auditing six E4-disabled configs and immutable regression inputs'
jq -e --arg run_id "$SOURCE_RUN_ID-config-smoke" --arg runner "$REGRESSION_RUNNER_SHA" \
	--arg candidate "$CANDIDATE_COMMIT" --arg source_sha "$SOURCE_RESULT_SHA" '
  .schema_version == 1 and
  .status == "passed_e4_candidate_six_profile_e3_config_smoke_without_build_or_boot" and
  .run_id == $run_id and .runner_sha256 == $runner and
  .candidate_commit == $candidate and .source_gate_result_sha256 == $source_sha and
  .receipt_ledger_jsonl_selftest_passed == true and .kernel_warning_classifier_selftest_passed == true and
  .unknown_kcsan_messages_fail_closed == true and .full_six_profile_e3_regression_required == true and
  .configs == ["arm64_standard_debug","x86_64_standard_debug","arm64_hotplug_fault_injection","x86_64_hotplug_fault_injection","arm64_generic_kasan","x86_64_kcsan"] and
  .clock_skew_retries == 0 and .builds_started == 0 and .boots_started == 0 and
  .e4_measurement_suite_enabled == false and .timing_measurement_may_start == false and
  .r4_e4_source_accepted == false and .production_protection == false and .datacenter_ready == false
' "$CONFIG_RESULT" >/dev/null
verify_hash "$CONFIG_EVIDENCE/inputs/runner.sh" "$REGRESSION_RUNNER_SHA" 'config runner snapshot'
verify_hash "$CONFIG_EVIDENCE/inputs/kernel-warning-classifier.sh" "$WARNING_CLASSIFIER_SHA" 'config warning classifier'
verify_hash "$CONFIG_EVIDENCE/inputs/plan.json" "$PLAN_SHA" 'config E3 plan'
verify_hash "$CONFIG_EVIDENCE/inputs/source-gate-result.json" "$SOURCE_RESULT_SHA" 'config source-gate input'
for label in arm64-standard-debug x86_64-standard-debug arm64-hotplug-fault-injection x86_64-hotplug-fault-injection arm64-generic-kasan x86_64-kcsan; do
	grep -Fxq 'CONFIG_SCHED_EXEC_LEASE_R4_KUNIT_TEST=y' "$CONFIG_EVIDENCE/$label.config" || die "$label E3 suite missing in config smoke"
	grep -Fxq '# CONFIG_SCHED_EXEC_LEASE_R4_MEASURE_KUNIT_TEST is not set' "$CONFIG_EVIDENCE/$label.config" || die "$label E4 measurement enabled in config smoke"
	[ ! -s "$CONFIG_EVIDENCE/$label-defconfig-verification.log" ] || die "$label config-smoke defconfig verification output"
	[ ! -s "$CONFIG_EVIDENCE/$label-olddefconfig-verification.log" ] || die "$label config-smoke olddefconfig verification output"
done

jq -e --arg run_id "$SOURCE_RUN_ID-e3-regression" --arg runner "$REGRESSION_RUNNER_SHA" \
	--arg candidate "$CANDIDATE_COMMIT" --arg parent "$CANDIDATE_PARENT" \
	--arg tree "$CANDIDATE_TREE" --arg diff_sha "$CANDIDATE_DIFF_SHA" \
	--arg source_sha "$SOURCE_RESULT_SHA" --arg plan_sha "$PLAN_SHA" \
	--arg boot_sha "$BOOT_RESULTS_SHA" '
  .schema_version == 1 and
  .id == "sched-exec-lease-p5a-r4-e4-e3-six-profile-regression-result-v1" and
  .run_id == $run_id and
  .status == "passed_six_profile_e3_regression_awaiting_independent_closure" and
  .candidate_commit == $candidate and .candidate_parent == $parent and
  .candidate_tree == $tree and .candidate_diff_sha256 == $diff_sha and
  .source_gate_result_sha256 == $source_sha and
  .receipt_ledger_jsonl_selftest_passed == true and .kernel_warning_classifier_selftest_passed == true and
  .unknown_kcsan_messages_fail_closed == true and
  .runner_sha256 == $runner and .plan_sha256 == $plan_sha and
  .architectures == ["arm64","x86_64"] and
  .profiles == ["arm64_standard_debug","x86_64_standard_debug","arm64_hotplug_fault_injection","x86_64_hotplug_fault_injection","arm64_generic_kasan","x86_64_kcsan"] and
  .suite == "sched_exec_lease_r4_concurrency" and .required_cases_per_profile == 36 and
  .passed_cases_per_profile == 36 and .total_passed_cases == 216 and
  .receipts_per_profile == 36 and .total_receipts == 216 and
  .stress_iterations_per_family_per_profile == 2048 and .allocation_fault_sites == 6 and
  .case_failures == 0 and .case_skips == 0 and .case_timeouts == 0 and .warning_reports == 0 and
  .build_clock_skew_retries == 0 and .final_build_clock_skew_warnings == 0 and
  .matrix_reduction == false and .fresh_build_output_per_profile == true and
  .sequential_build_retirement == true and .profile_results_sha256 == $boot_sha and
  (.results | length) == 6 and .six_profile_e3_regression_passed == true and
  .independent_regression_closure_pending == true and .predecessor_r4_e3_accepted == true and
  .e4_measurement_suite_enabled == false and .timing_measurement_may_start == false and
  .r4_e4_source_accepted == false and .primary_linux_changed == false and .patch_queue_changed == false and
  .real_scheduler_attachment == false and .runtime_behavior_approved == false and
  .production_protection == false and .deployment_ready == false and
  .multi_cluster_ready == false and .datacenter_ready == false
' "$REGRESSION_RESULT" >/dev/null
verify_hash "$REGRESSION_EVIDENCE/inputs/runner.sh" "$REGRESSION_RUNNER_SHA" 'regression runner snapshot'
verify_hash "$REGRESSION_EVIDENCE/inputs/immutable-evidence-inputs.sh" "$HARDENING_LIB_SHA" 'regression immutable helper'
verify_hash "$REGRESSION_EVIDENCE/inputs/kernel-warning-classifier.sh" "$WARNING_CLASSIFIER_SHA" 'regression warning classifier'
verify_hash "$REGRESSION_EVIDENCE/inputs/plan.json" "$PLAN_SHA" 'regression E3 plan'
verify_hash "$REGRESSION_EVIDENCE/inputs/source-gate-result.json" "$SOURCE_RESULT_SHA" 'regression source-gate input'
verify_hash "$REGRESSION_EVIDENCE/e3-source.diff" "$CANDIDATE_DIFF_SHA" 'regression retained E4 diff'
cmp "$REGRESSION_EVIDENCE/expected-cases.txt" "$CONFIG_EVIDENCE/expected-cases.txt" || die 'config/regression case sets differ'
[ ! -s "$REGRESSION_EVIDENCE/expected-cases.diff" ] || die 'regression expected-case diff is nonempty'

# shellcheck disable=SC1091
source "$REGRESSION_EVIDENCE/inputs/kernel-warning-classifier.sh"

progress '50% independently auditing six QEMU profiles, KTAP, receipts, seeds, and faults'
: > "$OUT_DIR/compiler-diagnostic-scan.txt"
: > "$OUT_DIR/clock-skew-scan.txt"
: > "$OUT_DIR/kernel-warning-scan.txt"
index=0
while IFS='|' read -r label arch profile child_sha memory; do
	child="$REGRESSION_EVIDENCE/$label-result.json"
	verify_hash "$child" "$child_sha" "$label child result"
	jq -e --arg label "$label" --arg arch "$arch" --arg profile "$profile" '
	  .schema_version == 1 and .status == "passed" and .boot == $label and
	  .architecture == $arch and .profile == $profile and
	  .cases_passed == 36 and .case_failures == 0 and .case_skips == 0 and .case_timeouts == 0 and
	  .receipts == 36 and .stress_families == 5 and .stress_iterations_per_family == 2048 and
	  .allocation_fault_sites == 6 and .warning_reports == 0 and
	  .fresh_build_output == true and .build_output_retired_after_seal == true and
	  .virtual_synthetic_protocol_only == true
	' "$child" >/dev/null
	jq -e --argjson index "$index" --slurpfile child "$child" '.results[$index] == $child[0]' "$REGRESSION_RESULT" >/dev/null || die "$label differs from parent result"
	jq -e --argjson index "$index" --slurpfile child "$child" '.[$index] == $child[0]' "$REGRESSION_EVIDENCE/boot-results.json" >/dev/null || die "$label differs from boot-results"
	verify_recorded_hash "$child" '.config.sha256' "$REGRESSION_EVIDENCE/$label.config" "$label config"
	verify_recorded_hash "$child" '.build_log_sha256' "$REGRESSION_EVIDENCE/$label-build.log" "$label build log"
	verify_recorded_hash "$child" '.qemu_command_sha256' "$REGRESSION_EVIDENCE/$label-qemu-command.txt" "$label QEMU command"
	verify_recorded_hash "$child" '.console_sha256' "$REGRESSION_EVIDENCE/$label-console.log" "$label console"
	verify_recorded_hash "$child" '.ktap_sha256' "$REGRESSION_EVIDENCE/$label-ktap.log" "$label KTAP"
	verify_recorded_hash "$child" '.receipts_sha256' "$REGRESSION_EVIDENCE/$label-receipts.jsonl" "$label receipts"
	verify_recorded_hash "$child" '.seed_set_sha256' "$REGRESSION_EVIDENCE/$label-seed-set.json" "$label seed set"
	verify_recorded_hash "$child" '.fault_ledger_sha256' "$REGRESSION_EVIDENCE/$label-fault-ledger.json" "$label fault ledger"
	[ ! -s "$REGRESSION_EVIDENCE/$label-defconfig-verification.log" ] || die "$label defconfig verification output"
	[ ! -s "$REGRESSION_EVIDENCE/$label-olddefconfig-verification.log" ] || die "$label olddefconfig verification output"
	[ ! -s "$REGRESSION_EVIDENCE/$label-build-verification.log" ] || die "$label build verification output"
	if grep -Ehn ':[0-9]+(:[0-9]+)?: (fatal )?(warning|error):' "$REGRESSION_EVIDENCE/$label-build.log" >> "$OUT_DIR/compiler-diagnostic-scan.txt"; then
		die "$label compiler diagnostic found"
	fi
	if grep -Eihn 'Clock skew detected|modification time .* in the future' \
		"$REGRESSION_EVIDENCE/$label-defconfig.log" "$REGRESSION_EVIDENCE/$label-olddefconfig.log" \
		"$REGRESSION_EVIDENCE/$label-build.log" >> "$OUT_DIR/clock-skew-scan.txt"; then
		die "$label clock skew found"
	fi
	config="$REGRESSION_EVIDENCE/$label.config"
	for required in CONFIG_SCHED_EXEC_LEASE=y CONFIG_SCHED_EXEC_LEASE_LAYOUT_PROBE=y \
		CONFIG_SCHED_EXEC_LEASE_R4_LAYOUT_PROBE=y CONFIG_SCHED_EXEC_LEASE_R4_KUNIT_TEST=y \
		CONFIG_KUNIT=y CONFIG_KUNIT_AUTORUN_ENABLED=y CONFIG_HOTPLUG_CPU=y \
		CONFIG_PROVE_LOCKING=y CONFIG_DEBUG_OBJECTS_WORK=y CONFIG_DEBUG_OBJECTS_RCU_HEAD=y \
		CONFIG_PROVE_RCU=y CONFIG_DEBUG_IRQFLAGS=y CONFIG_WQ_WATCHDOG=y; do
		grep -Fxq "$required" "$config" || die "$label missing $required"
	done
	grep -Fxq '# CONFIG_SCHED_EXEC_LEASE_R4_MEASURE_KUNIT_TEST is not set' "$config" || die "$label enabled E4 measurement during E3 regression"
	grep -Fxq "CONFIG_KUNIT_DEFAULT_FILTER_GLOB=\"$SUITE\"" "$config" || die "$label suite filter changed"
	readelf_file="$REGRESSION_EVIDENCE/$label-exec-lease-readelf.txt"
	grep -Fq 'Class:                             ELF64' "$readelf_file" || die "$label ELF class changed"
	grep -Fq 'Type:                              REL (Relocatable file)' "$readelf_file" || die "$label ELF type changed"
	command_file="$REGRESSION_EVIDENCE/$label-qemu-command.txt"
	grep -Fq " -smp 2 -m $memory -nic none -nographic -no-reboot " "$command_file" || die "$label QEMU isolation changed"
	grep -Fq "/var/tmp/linux-cap-builds/p5a-r4-e4-e3-regression/$SOURCE_RUN_ID-e3-regression/$label/" "$command_file" || die "$label QEMU image path changed"
	! grep -Eq '(^|[[:space:]])-net(dev)?([[:space:]]|$)|-device[[:space:]][^ ]*(virtio-net|e1000|rtl8139)|-drive[[:space:]]' "$command_file" || die "$label external I/O enabled"
	[ "$(tr -d '[:space:]' < "$REGRESSION_EVIDENCE/$label-qemu-exit-code.txt")" = 0 ] || die "$label QEMU exit changed"
	ktap="$REGRESSION_EVIDENCE/$label-ktap.log"
	grep -Fq '# Subtest: sched_exec_lease_r4_concurrency' "$ktap" || die "$label suite start missing"
	[ "$(grep -Ec "^[[:space:]]*ok [0-9]+( -)? $SUITE([[:space:]]|$)" "$ktap")" = 1 ] || die "$label suite pass cardinality changed"
	! grep -Eq '^[[:space:]]*not ok [0-9]+' "$ktap" || die "$label KTAP failure found"
	! grep -Fq '# SKIP' "$ktap" || die "$label KTAP skip found"
	sed -n -E 's/^[[:space:]]*ok [0-9]+( -)? (sched_exec_r4_test_[^ #[:space:]]*).*/\2/p' "$ktap" > "$OUT_DIR/$label-cases.txt"
	[ "$(wc -l < "$OUT_DIR/$label-cases.txt" | tr -d ' ')" = 36 ] || die "$label KTAP case count changed"
	diff -u "$REGRESSION_EVIDENCE/expected-cases.txt" "$OUT_DIR/$label-cases.txt" > "$OUT_DIR/$label-cases.diff" || die "$label KTAP case set changed"
	receipts="$REGRESSION_EVIDENCE/$label-receipts.jsonl"
	[ "$(wc -l < "$receipts" | tr -d ' ')" = 36 ] || die "$label receipt count changed"
	while IFS= read -r receipt; do
		printf '%s\n' "$receipt" | jq -e '(.case | startswith("sched_exec_r4_test_")) and (.oracle_checkpoints > 0) and .terminal_reference_equation == "bucket+projection+contribution+dirty+notifier+callback+rcu" and .cleanup_outcome == "drained"' >/dev/null || die "$label malformed receipt"
	done < "$receipts"
	jq -s 'map(.case) | sort' "$receipts" > "$OUT_DIR/$label-receipt-cases.json"
	cmp "$REGRESSION_EVIDENCE/expected-receipt-cases.json" "$OUT_DIR/$label-receipt-cases.json" || die "$label receipt case set changed"
	jq -e --arg label "$label" '.schema_version == 1 and .boot == $label and .randomized == false and .stress_iterations == 2048 and all(.stress_families[]; .iterations == 2048)' "$REGRESSION_EVIDENCE/$label-seed-set.json" >/dev/null || die "$label seed set changed"
	jq -e --arg label "$label" --arg profile "$profile" '.schema_version == 1 and .boot == $label and .profile == $profile and .deterministic_test_control_plane == true and .clean_retry_required == true and (.pre_runnable_fault_sites | length) == 6 and (.matching_receipts | length) == 3' "$REGRESSION_EVIDENCE/$label-fault-ledger.json" >/dev/null || die "$label fault ledger changed"
	capsched_collect_kernel_warning_reports "$REGRESSION_EVIDENCE/$label-console.log" "$OUT_DIR/$label-warning-reports.txt" || die "$label warning classification failed"
	[ ! -s "$OUT_DIR/$label-warning-reports.txt" ] || { cat "$OUT_DIR/$label-warning-reports.txt" >> "$OUT_DIR/kernel-warning-scan.txt"; die "$label kernel warning found"; }
	[ ! -s "$REGRESSION_EVIDENCE/$label-warning-reports.txt" ] || die "$label retained warning report is nonempty"
	index=$((index + 1))
done <<'PROFILE_SPECS'
arm64-standard-debug|arm64|standard|606c920035fe9895186a4c089c63d9221889fa570ef9631efe155f79c1fa4c19|2048
x86_64-standard-debug|x86_64|standard|817a0e1a061e9ebd457d648d0229adc6136cee1df3851438dd519000eba7e658|2048
arm64-hotplug-fault-injection|arm64|fault|0f471efd6a79e07fa91c5630eea684315f5ed8aa7241d5adf895f29137575104|2048
x86_64-hotplug-fault-injection|x86_64|fault|e9e4e6e5a47d9dfd56f04985cfc42542a24ef343780ce7c9b3eb38eca538a4bd|2048
arm64-generic-kasan|arm64|kasan|3e0e28cb37da7f8c4f00f12bdcdb38ce077d2bf4eb8964e50013a754cbbfdd52|4096
x86_64-kcsan|x86_64|kcsan|9cfe7c2c64f6490859d9e284c37a0e969f5cee4652ae696c8bf6f2c568dca52b|4096
PROFILE_SPECS
[ "$index" = 6 ] || die 'profile specification count changed'

progress '82% checking Git identities, retired scratch, and immutable originals'
[ "$(git -C "$LINUX_DIR" rev-parse HEAD)" = "$PRIMARY_COMMIT" ] || die 'primary Linux moved'
[ -z "$(git -C "$LINUX_DIR" status --porcelain --untracked-files=no)" ] || die 'primary Linux is dirty'
[ "$(git -C "$LINUX_DIR" rev-parse "$CANDIDATE_COMMIT^")" = "$CANDIDATE_PARENT" ] || die 'candidate parent moved'
[ "$(git -C "$LINUX_DIR" rev-parse "$CANDIDATE_COMMIT^{tree}")" = "$CANDIDATE_TREE" ] || die 'candidate tree moved'
[ "$(git -C "$LINUX_DIR" rev-parse refs/heads/codex/p5a-r4-e4-local-quantum-measurement)" = "$CANDIDATE_COMMIT" ] || die 'local candidate ref moved'
[ "$(git -C "$LINUX_DIR" rev-parse refs/remotes/fork/codex/p5a-r4-e4-local-quantum-measurement)" = "$CANDIDATE_COMMIT" ] || die 'fork candidate ref moved'
git -C "$LINUX_DIR" diff --binary "$CANDIDATE_PARENT..$CANDIDATE_COMMIT" > "$OUT_DIR/recomputed-e4-source.diff"
[ "$(file_sha "$OUT_DIR/recomputed-e4-source.diff")" = "$CANDIDATE_DIFF_SHA" ] || die 'candidate diff changed'
cmp "$OUT_DIR/recomputed-e4-source.diff" "$SOURCE_EVIDENCE/e4-source.diff" || die 'retained candidate diff differs from Git'
[ "$(git -C "$LINUX_DIR" diff --name-only "$CANDIDATE_PARENT..$CANDIDATE_COMMIT" | sort | tr '\n' ' ')" = 'init/Kconfig kernel/sched/exec_lease.c ' ] || die 'candidate escaped two-file boundary'
[ "$(git -C "$PATCH_QUEUE_DIR" rev-parse HEAD)" = "$PATCH_QUEUE_COMMIT" ] || die 'patch queue moved'
[ -z "$(git -C "$PATCH_QUEUE_DIR" status --porcelain)" ] || die 'patch queue is dirty'
for path in \
	"$WORKSPACE_DIR/build/DomainLeaseLinux.volume/worktrees/p5a-r4-e4-source-gate-e3-$SOURCE_RUN_ID-source" \
	"$WORKSPACE_DIR/build/DomainLeaseLinux.volume/worktrees/p5a-r4-e4-source-gate-e4-$SOURCE_RUN_ID-source" \
	"$WORKSPACE_DIR/build/DomainLeaseLinux.volume/worktrees/p5a-r4-e4-e3-regression-$SOURCE_RUN_ID-e3-regression" \
	"/var/tmp/linux-cap-builds/p5a-r4-e4-source-gate/$SOURCE_RUN_ID-source" \
	"/var/tmp/linux-cap-builds/p5a-r4-e4-e3-regression/$SOURCE_RUN_ID-e3-regression"; do
	if [ -e "$path" ] || [ -L "$path" ]; then
		die "run-owned scratch leaked: $path"
	fi
done
[ "$(file_sha "$RUNNER_SOURCE")" = "$runner_initial_sha" ] || die 'closure runner changed during audit'
[ "$(file_sha "$INPUT_DIR/closure-runner.sh")" = "$runner_initial_sha" ] || die 'closure runner snapshot changed'
for spec in \
	"combined|$COMBINED_DIR|$COMBINED_MANIFEST_SHA" \
	"source|$SOURCE_DIR|$SOURCE_MANIFEST_SHA" \
	"config|$CONFIG_DIR|$CONFIG_MANIFEST_SHA" \
	"regression|$REGRESSION_DIR|$REGRESSION_MANIFEST_SHA"; do
	IFS='|' read -r label root expected <<EOF
$spec
EOF
	tree_manifest "$root" > "$OUT_DIR/$label-final.sha256"
	[ "$(file_sha "$OUT_DIR/$label-final.sha256")" = "$expected" ] || die "$label original changed during closure"
done

if [ "$CLOSURE_TEST_MODE" = 1 ]; then
	progress '100% exact closure fixture passed; no authorization result published'
	exit 0
fi

progress '94% sealing exact virtual-synthetic source acceptance and timing authorization boundary'
jq -n \
	--arg run_id "$RUN_ID" --arg source_run_id "$SOURCE_RUN_ID" \
	--arg combined_result_sha "$COMBINED_RESULT_SHA" --arg source_result_sha "$SOURCE_RESULT_SHA" \
	--arg config_result_sha "$CONFIG_RESULT_SHA" --arg regression_result_sha "$REGRESSION_RESULT_SHA" \
	--arg combined_manifest_sha "$COMBINED_MANIFEST_SHA" --arg source_manifest_sha "$SOURCE_MANIFEST_SHA" \
	--arg config_manifest_sha "$CONFIG_MANIFEST_SHA" --arg regression_manifest_sha "$REGRESSION_MANIFEST_SHA" \
	--arg closure_runner_sha "$runner_initial_sha" --arg candidate "$CANDIDATE_COMMIT" \
	--arg parent "$CANDIDATE_PARENT" --arg tree "$CANDIDATE_TREE" --arg diff_sha "$CANDIDATE_DIFF_SHA" \
	--arg source_runner_sha "$SOURCE_RUNNER_SHA" --arg regression_runner_sha "$REGRESSION_RUNNER_SHA" \
	--arg combined_runner_sha "$COMBINED_RUNNER_SHA" \
	--argjson combined_count "$COMBINED_COUNT" --argjson source_count "$SOURCE_COUNT" \
	--argjson config_count "$CONFIG_COUNT" --argjson regression_count "$REGRESSION_COUNT" \
	--argjson total_count "$total_artifacts" --argjson combined_bytes "$COMBINED_BYTES" \
	--argjson source_bytes "$SOURCE_BYTES" --argjson config_bytes "$CONFIG_BYTES" \
	--argjson regression_bytes "$REGRESSION_BYTES" --argjson total_bytes "$total_bytes" \
	'{schema_version:2,id:"sched-exec-lease-p5a-r4-e4-source-e3-evidence-closure-result-v2",run_id:$run_id,status:"passed_independent_r4_e4_source_e3_evidence_closure",source_run_id:$source_run_id,combined_result_sha256:$combined_result_sha,source_result_sha256:$source_result_sha,config_result_sha256:$config_result_sha,e3_regression_result_sha256:$regression_result_sha,artifact_manifests_sha256:{combined:$combined_manifest_sha,source:$source_manifest_sha,config:$config_manifest_sha,regression:$regression_manifest_sha},artifact_counts:{combined:$combined_count,source:$source_count,config:$config_count,regression:$regression_count,total:$total_count},artifact_bytes:{combined:$combined_bytes,source:$source_bytes,config:$config_bytes,regression:$regression_bytes,total:$total_bytes},runner_seals_sha256:{closure:$closure_runner_sha,source:$source_runner_sha,regression:$regression_runner_sha,combined:$combined_runner_sha},all_artifacts_snapshotted_read_only:true,artifact_race_checks_passed:4,candidate_commit:$candidate,candidate_parent:$parent,candidate_tree:$tree,candidate_diff_sha256:$diff_sha,fresh_source_objects_audited:6,disabled_e4_artifacts:0,e3_profiles_audited:6,total_e3_cases:216,total_e3_receipts:216,measurement_task_migration_disabled:true,vcpu_migration_observation_enforced:true,irq_preempt_state_recorded:true,plan_to_source_observability_audited:true,compiler_diagnostics:0,clock_skew_warnings:0,kernel_warning_reports:0,case_failures:0,case_skips:0,case_timeouts:0,qemu_nonzero_exits:0,network_devices_enabled:0,run_owned_build_scratch_retired:true,run_owned_worktrees_retired:true,independent_artifact_closure_passed:true,exact_virtual_synthetic_r4_e4_source_accepted:true,r4_e4_virtual_synthetic_timing_may_start:true,measurement_result_accepted:false,real_scheduler_attachment:false,runtime_scheduler_hook_approved:false,runtime_behavior_approved:false,n136_complete:false,bare_metal_validated:false,performance_claim:false,cost_claim:false,production_protection:false,deployment_ready:false,multi_node_ready:false,multi_cluster_ready:false,datacenter_ready:false}' \
	> "$OUT_DIR/result.json.pending"
jq -e --argjson total_count "$total_artifacts" --argjson total_bytes "$total_bytes" '
  .schema_version == 2 and
  .id == "sched-exec-lease-p5a-r4-e4-source-e3-evidence-closure-result-v2" and
  .status == "passed_independent_r4_e4_source_e3_evidence_closure" and
  .artifact_counts.total == $total_count and .artifact_bytes.total == $total_bytes and
  .artifact_race_checks_passed == 4 and .fresh_source_objects_audited == 6 and
  .e3_profiles_audited == 6 and .total_e3_cases == 216 and .total_e3_receipts == 216 and
  .measurement_task_migration_disabled == true and
  .vcpu_migration_observation_enforced == true and
  .irq_preempt_state_recorded == true and .plan_to_source_observability_audited == true and
  .compiler_diagnostics == 0 and .clock_skew_warnings == 0 and
  .kernel_warning_reports == 0 and .case_failures == 0 and .case_skips == 0 and
  .case_timeouts == 0 and .qemu_nonzero_exits == 0 and
  .independent_artifact_closure_passed == true and
  .exact_virtual_synthetic_r4_e4_source_accepted == true and
  .r4_e4_virtual_synthetic_timing_may_start == true and
  .measurement_result_accepted == false and .real_scheduler_attachment == false and
  .production_protection == false and .datacenter_ready == false
' "$OUT_DIR/result.json.pending" >/dev/null
mv "$OUT_DIR/result.json.pending" "$OUT_DIR/result.json"
jq -S 'del(.run_id)' "$OUT_DIR/result.json" > "$OUT_DIR/result.normalized.json"
sha256sum "$OUT_DIR/result.normalized.json" > "$OUT_DIR/result.normalized.sha256"
sha256sum "$OUT_DIR/result.json" > "$OUT_DIR/result.sha256"
chmod -R a-w "$INPUT_DIR"
progress '100% independent R4-E4 source/E3 closure passed; exact virtual-synthetic timing may start'
printf 'result=%s\n' "$OUT_DIR/result.json"
printf 'sha256=%s\n' "$(awk '{print $1}' "$OUT_DIR/result.sha256")"
printf 'normalized_sha256=%s\n' "$(awk '{print $1}' "$OUT_DIR/result.normalized.sha256")"
