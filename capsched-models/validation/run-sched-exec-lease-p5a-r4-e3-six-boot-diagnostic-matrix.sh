#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C
export KBUILD_BUILD_TIMESTAMP='1970-01-01 00:00:00 +0000'
export KBUILD_BUILD_USER=capsched
export KBUILD_BUILD_HOST=r4-e3-diagnostic
export KBUILD_BUILD_VERSION=1

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
LINUX_DIR="$WORKSPACE_DIR/build/DomainLeaseLinux.volume/linux"
PATCH_QUEUE_DIR="$WORKSPACE_DIR/linux-patches"
PLAN_SOURCE="$CAPSCHED_DIR/capsched-models/analysis/sched-exec-lease-p5a-r4-e3-concurrency-diagnostic-evidence-plan-v1.json"
SOURCE_GATE_SOURCE="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r4-e3-concurrency-source-gate/20260717T-p5a-r4-e3-source-gate-r3/result.json"
CLOSURE_R3_SOURCE="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r4-e3-source-gate-closure/20260717T-p5a-r4-e3-source-gate-closure-r3/result.json"
CLOSURE_R4_SOURCE="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r4-e3-source-gate-closure/20260717T-p5a-r4-e3-source-gate-closure-r4/result.json"
SIX_BOOT_ATTEMPT_2_REJECTION_SOURCE="$SCRIPT_DIR/sched-exec-lease-p5a-r4-e3-six-boot-attempt-2-rejection-v1.json"
SIX_BOOT_ATTEMPT_3_REJECTION_SOURCE="$SCRIPT_DIR/sched-exec-lease-p5a-r4-e3-six-boot-attempt-3-rejection-v1.json"
HARDENING_LIB_SOURCE="$SCRIPT_DIR/lib/immutable-evidence-inputs.sh"
WARNING_CLASSIFIER_SOURCE="$SCRIPT_DIR/lib/kernel-warning-classifier.sh"
RUNNER_SOURCE=${BASH_SOURCE[0]}
RUN_ID=${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
OUT_ROOT="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r4-e3-six-boot-diagnostic-matrix"
OUT_DIR="$OUT_ROOT/$RUN_ID"
INPUT_DIR="$OUT_DIR/inputs"
BUILD_ROOT="/var/tmp/linux-cap-builds/p5a-r4-e3-six-boot/$RUN_ID"
E3_DIR="$WORKSPACE_DIR/build/DomainLeaseLinux.volume/worktrees/p5a-r4-e3-six-boot-$RUN_ID"
PROGRESS_FILE=${PROGRESS_FILE:-}
JOBS=${JOBS:-2}
BUILD_STORAGE_MIN_KIB=${BUILD_STORAGE_MIN_KIB:-6291456}
QEMU_TIMEOUT_STANDARD=${QEMU_TIMEOUT_STANDARD:-1800}
QEMU_TIMEOUT_FAULT=${QEMU_TIMEOUT_FAULT:-1800}
QEMU_TIMEOUT_SANITIZER=${QEMU_TIMEOUT_SANITIZER:-3600}

PLAN_SHA=f9c9103b4eae2177309dd8e0134601fe3cf1eb08061986265627dcd9d8fd6677
CLOSURE_R3_SHA=f6763fbb940c42d67390cae46c20e148f86020a3c2af4431e12562c198fcf613
CLOSURE_R4_SHA=92e9918d0c04147a9b78c66744081cf165564458204a18c43501d82617318e6e
SOURCE_GATE_SHA=f76ea8d4aef69a89cf93be4f20dfb3ce6bfa9f25ede61cfa9b92048d775f9b24
SIX_BOOT_ATTEMPT_1_REJECTION_SHA=c67648292f091d79e752c174f4360deee6b0a22ae696d7cbf76d5fd13cc22871
SIX_BOOT_ATTEMPT_2_REJECTION_SHA=eb02c397ce25e522eab88f346913b4284649f83201805cdd14b1afbc1a9d0564
SIX_BOOT_ATTEMPT_3_REJECTION_SHA=06c9f228d66a7440b6c4404e131eeef2ba31ecf94a03fa8356fa81d5ba8d815b
HARDENING_LIB_SHA=4548753bc2acaa7497aef9e9ff070d9952f9b5ee20631c6116590067eab9ccc6
WARNING_CLASSIFIER_SHA=8adcff74f0395f5ec219343c0cb5b1f179efee2292ab853d4fc7e410467dc23a
PRIMARY_COMMIT=5e1ca3037e34823d1ba0cdd1dc04161fac170280
PATCH_QUEUE_COMMIT=16bb080da472ffabbbafd2698073eca633fb0602
E2_COMMIT=a429fc30252ac6af94c51d96cd4ac24e72d9f83b
E3_COMMIT=da9ce9159b3450c28c8faf8dceac671fb7bfeba2
E3_TREE=58c6510c6f517004e37107786d006bb8333b79b8
E3_DIFF_SHA=096d99b527bd1b433ecd07165696830f9316d07cc67484687d95cd2c2a846f08
SUITE=sched_exec_lease_r4_concurrency
REQUIRED_CASES=36
REQUIRED_RECEIPTS=36
STRESS_ITERATIONS=2048
clock_skew_retries=0
receipt_ledger_selftest_passed=0
warning_classifier_selftest_passed=0
current_build=
active_child_pid=

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

retire_build()
{
	local build=$1

	case "$build" in
		"$BUILD_ROOT"/*) ;;
		*) die "refusing to retire build outside run root: $build" ;;
	esac
	rm -rf -- "$build"
	if [ "$current_build" = "$build" ]; then
		current_build=
	fi
}

cleanup()
{
	local rc=$?

	trap - EXIT INT TERM
	if [ -n "$active_child_pid" ] && kill -0 "$active_child_pid" 2>/dev/null; then
		kill -TERM "$active_child_pid" 2>/dev/null || true
		wait "$active_child_pid" 2>/dev/null || true
	fi
	if [ -n "$current_build" ]; then
		case "$current_build" in
			"$BUILD_ROOT"/*) rm -rf -- "$current_build" ;;
		esac
	fi
	rm -rf -- "$BUILD_ROOT"
	if git -C "$LINUX_DIR" worktree list --porcelain 2>/dev/null |
		grep -Fxq "worktree $E3_DIR"; then
		git -C "$LINUX_DIR" worktree remove --force "$E3_DIR" >/dev/null 2>&1 ||
			printf 'warning: could not retire diagnostic worktree: %s\n' "$E3_DIR" >&2
	fi
	exit "$rc"
}

handle_int()
{
	exit 130
}

handle_term()
{
	exit 143
}

case "$RUN_ID" in
	[A-Za-z0-9]* ) ;;
	* ) die 'RUN_ID must begin with an alphanumeric character' ;;
esac
case "$RUN_ID" in
	*[!A-Za-z0-9._-]*|.|..) die 'RUN_ID contains an unsafe component' ;;
esac
case "$JOBS" in
	''|*[!0-9]*) die 'JOBS must be a positive integer' ;;
esac
[ "$JOBS" -gt 0 ] || die 'JOBS must be greater than zero'
case "$BUILD_STORAGE_MIN_KIB" in
	''|*[!0-9]*) die 'BUILD_STORAGE_MIN_KIB must be a positive integer' ;;
esac
[ "$BUILD_STORAGE_MIN_KIB" -gt 0 ] || die 'BUILD_STORAGE_MIN_KIB must be greater than zero'
case "$BUILD_ROOT" in
	/var/tmp/linux-cap-builds/p5a-r4-e3-six-boot/"$RUN_ID") ;;
	*) die "unsafe build root: $BUILD_ROOT" ;;
esac

for command in awk cmp cp df diff find gcc git grep jq make mkdir mkfifo mv \
	qemu-system-aarch64 qemu-system-x86_64 readelf sed sha256sum sort stat \
	strings timeout tr uname wc xargs x86_64-linux-gnu-gcc; do
	command -v "$command" >/dev/null 2>&1 || die "missing command: $command"
done
if [ -e "$OUT_DIR" ] || [ -L "$OUT_DIR" ]; then
	die "run output already exists: $OUT_DIR"
fi
if [ -e "$BUILD_ROOT" ] || [ -L "$BUILD_ROOT" ]; then
	die "build root already exists: $BUILD_ROOT"
fi
if [ -e "$E3_DIR" ] || [ -L "$E3_DIR" ]; then
	die "diagnostic worktree already exists: $E3_DIR"
fi

mkdir -p "$OUT_ROOT" "$(dirname "$BUILD_ROOT")" "$(dirname "$E3_DIR")"
mkdir "$OUT_DIR" "$INPUT_DIR" "$BUILD_ROOT"
chmod 0700 "$OUT_DIR" "$INPUT_DIR"
trap cleanup EXIT
trap handle_int INT
trap handle_term TERM

build_storage_type=$(stat -f -c %T "$BUILD_ROOT")
[ "$build_storage_type" = ext2/ext3 ] || die "build root is not internal ext4-compatible storage: $build_storage_type"
build_storage_available_kib=$(df -Pk "$BUILD_ROOT" | awk 'NR == 2 { print $4 }')
[ "$build_storage_available_kib" -ge "$BUILD_STORAGE_MIN_KIB" ] ||
	die "internal build storage below ${BUILD_STORAGE_MIN_KIB}KiB: ${build_storage_available_kib}KiB"
{
	printf 'build_root=%s\n' "$BUILD_ROOT"
	printf 'filesystem=%s\n' "$build_storage_type"
	printf 'available_kib_at_start=%s\n' "$build_storage_available_kib"
	printf 'minimum_kib=%s\n' "$BUILD_STORAGE_MIN_KIB"
	printf 'shared_host_build_output=false\n'
	df -Pk "$BUILD_ROOT" "$OUT_DIR"
} > "$OUT_DIR/build-storage.txt"

if [ ! -f "$HARDENING_LIB_SOURCE" ] || [ -L "$HARDENING_LIB_SOURCE" ]; then
	die 'hardening helper is not a regular file'
fi
[ "$(sha256sum "$HARDENING_LIB_SOURCE" | awk '{print $1}')" = "$HARDENING_LIB_SHA" ] || die 'hardening helper changed'
cp -- "$HARDENING_LIB_SOURCE" "$INPUT_DIR/immutable-evidence-inputs.sh"
chmod 0444 "$INPUT_DIR/immutable-evidence-inputs.sh"
# The verified snapshot path is run-specific and therefore not statically resolvable.
# shellcheck disable=SC1091
source "$INPUT_DIR/immutable-evidence-inputs.sh"
capsched_verify_file_sha256 "$INPUT_DIR/immutable-evidence-inputs.sh" "$HARDENING_LIB_SHA" || die 'hardening helper snapshot mismatch'
capsched_snapshot_verified_file "$WARNING_CLASSIFIER_SOURCE" "$WARNING_CLASSIFIER_SHA" "$INPUT_DIR/kernel-warning-classifier.sh" || die 'could not snapshot warning classifier'
# shellcheck disable=SC1091
source "$INPUT_DIR/kernel-warning-classifier.sh"
capsched_verify_file_sha256 "$INPUT_DIR/kernel-warning-classifier.sh" "$WARNING_CLASSIFIER_SHA" || die 'warning classifier snapshot mismatch'
runner_initial_sha=$(capsched_sha256_file "$RUNNER_SOURCE")
capsched_snapshot_verified_file "$RUNNER_SOURCE" "$runner_initial_sha" "$INPUT_DIR/runner.sh" || die 'could not snapshot runner'
capsched_snapshot_verified_file "$PLAN_SOURCE" "$PLAN_SHA" "$INPUT_DIR/plan.json" || die 'could not snapshot plan'
capsched_snapshot_verified_file "$SOURCE_GATE_SOURCE" "$SOURCE_GATE_SHA" "$INPUT_DIR/source-gate-result.json" || die 'could not snapshot source gate'
capsched_snapshot_verified_file "$CLOSURE_R3_SOURCE" "$CLOSURE_R3_SHA" "$INPUT_DIR/source-gate-closure-r3.json" || die 'could not snapshot closure r3'
capsched_snapshot_verified_file "$CLOSURE_R4_SOURCE" "$CLOSURE_R4_SHA" "$INPUT_DIR/source-gate-closure-r4.json" || die 'could not snapshot closure r4'
capsched_snapshot_verified_file "$SIX_BOOT_ATTEMPT_2_REJECTION_SOURCE" "$SIX_BOOT_ATTEMPT_2_REJECTION_SHA" "$INPUT_DIR/six-boot-attempt-2-rejection.json" || die 'could not snapshot attempt-2 rejection'
capsched_snapshot_verified_file "$SIX_BOOT_ATTEMPT_3_REJECTION_SOURCE" "$SIX_BOOT_ATTEMPT_3_REJECTION_SHA" "$INPUT_DIR/six-boot-attempt-3-rejection.json" || die 'could not snapshot attempt-3 rejection'
PLAN="$INPUT_DIR/plan.json"
SOURCE_GATE="$INPUT_DIR/source-gate-result.json"
CLOSURE_R3="$INPUT_DIR/source-gate-closure-r3.json"
CLOSURE_R4="$INPUT_DIR/source-gate-closure-r4.json"
SIX_BOOT_ATTEMPT_2_REJECTION="$INPUT_DIR/six-boot-attempt-2-rejection.json"
SIX_BOOT_ATTEMPT_3_REJECTION="$INPUT_DIR/six-boot-attempt-3-rejection.json"

progress '2% locking N-134 closure, exact matrix, and repository identities'
jq -e '
  .status == "rejected_before_boot_seal_due_to_receipt_ledger_serializer_type_error" and
  .run.run_id == "20260717T-p5a-r4-e3-six-boot-r2" and
  .run.runner_sha256 == "184d8a0f898466474f1dc11fae7b4fa6f90b33decce78549f76173201e4d2964" and
  .run.runner_exit_code == 5 and
  .locked_inputs.candidate_commit == "da9ce9159b3450c28c8faf8dceac671fb7bfeba2" and
  .locked_inputs.source_gate_result_sha256 == "f76ea8d4aef69a89cf93be4f20dfb3ce6bfa9f25ede61cfa9b92048d775f9b24" and
  .arm64_standard_debug.qemu_exit_code == 0 and
  .arm64_standard_debug.required_cases_passed == 36 and
  .arm64_standard_debug.case_failures == 0 and
  .arm64_standard_debug.case_skips == 0 and
  .arm64_standard_debug.receipts == 36 and
  .failure.corrected_read_only_replay_passed == true and
  .failure.corrected_replay_matching_receipts == 3 and
  .matrix_accounting.boot_results_sealed == 0 and
  .matrix_accounting.arm64_standard_debug_credited == false and
  .matrix_accounting.matrix_passed == false and
  .matrix_accounting.full_fresh_retry_required == true and
  .safety_flags.r4_e3_source_accepted == false and
  .safety_flags.production_protection == false and
  .safety_flags.datacenter_ready == false
' "$SIX_BOOT_ATTEMPT_2_REJECTION" >/dev/null
jq -e '
  .status == "rejected_before_matrix_seal_due_to_case_insensitive_kcsan_lifecycle_false_positive" and
  .run.run_id == "20260717T-p5a-r4-e3-six-boot-r3" and
  .run.runner_sha256 == "0fd64ef6aa75330b18a87934fde4ad32978ff077ef9189891bb6ae45920ddb06" and
  .run.runner_exit_code == 1 and
  .locked_inputs.candidate_commit == "da9ce9159b3450c28c8faf8dceac671fb7bfeba2" and
  .sealed_boot_results.count == 5 and
  .sealed_boot_results.all_required_cases_passed_per_boot == 36 and
  .sealed_boot_results.total_failures == 0 and
  .sealed_boot_results.total_skips == 0 and
  .sealed_boot_results.total_timeouts == 0 and
  .sealed_boot_results.total_warning_reports == 0 and
  .x86_64_kcsan_unsealed_boot.qemu_exit_code == 0 and
  .x86_64_kcsan_unsealed_boot.required_cases_passed == 36 and
  .x86_64_kcsan_unsealed_boot.case_failures == 0 and
  .x86_64_kcsan_unsealed_boot.case_skips == 0 and
  .x86_64_kcsan_unsealed_boot.receipts == 36 and
  .x86_64_kcsan_unsealed_boot.unique_receipt_cases == 36 and
  .x86_64_kcsan_unsealed_boot.malformed_receipts == 0 and
  .x86_64_kcsan_unsealed_boot.boot_result_sealed == false and
  .failure.matched_line_count == 3 and
  .failure.actual_kcsan_report_headers == 0 and
  .failure.actual_unknown_origin_reports == 0 and
  .failure.actual_value_change_reports == 0 and
  .failure.actual_kcsan_report_footers == 0 and
  .failure.classification == "evidence_runner_false_positive_not_a_detected_kernel_data_race" and
  .matrix_accounting.builds_started == 6 and
  .matrix_accounting.boots_started == 6 and
  .matrix_accounting.boot_results_sealed == 5 and
  .matrix_accounting.x86_64_kcsan_credited == false and
  .matrix_accounting.sealed_boot_results_credited_to_future_retry == false and
  .matrix_accounting.matrix_passed == false and
  .matrix_accounting.full_fresh_retry_required == true and
  .safety_flags.r4_e3_source_accepted == false and
  .safety_flags.production_protection == false and
  .safety_flags.datacenter_ready == false
' "$SIX_BOOT_ATTEMPT_3_REJECTION" >/dev/null
jq -e '
  .status == "passed_source_gate_awaiting_six_boot_diagnostic_matrix" and
  .candidate_commit == "da9ce9159b3450c28c8faf8dceac671fb7bfeba2" and
  .candidate_parent == "a429fc30252ac6af94c51d96cd4ac24e72d9f83b" and
  .candidate_tree == "58c6510c6f517004e37107786d006bb8333b79b8" and
  .candidate_diff_sha256 == "096d99b527bd1b433ecd07165696830f9316d07cc67484687d95cd2c2a846f08" and
  .strict_checkpatch == {errors:0,warnings:0,checks:0} and
  .architectures == ["arm64","x86_64"] and
  .fresh_modes_per_architecture == ["exact_e2_parent","e3_all_r4_options_off","e3_r4_layout_on_test_off","e3_r4_kunit_test_on"] and
  .w1_compiler_diagnostics == 0 and
  .clock_skew_retries == 2 and
  .final_clock_skew_warnings == 0 and
  .disabled_e3_symbols_relocations_strings_initcalls == 0 and
  .e2_private_layout_and_58_probes_preserved == true and
  .existing_expanded_51_values_preserved == true and
  .diagnostic_matrix_may_start == true and
  .r4_e3_source_accepted == false and
  .r4_e3_concurrency_correctness_accepted == false and
  .production_protection == false and
  .deployment_ready == false and
  .multi_cluster_ready == false and
  .datacenter_ready == false
' "$SOURCE_GATE" >/dev/null
for closure in "$CLOSURE_R3" "$CLOSURE_R4"; do
	jq -e '
	  .status == "passed_corrected_r4_e3_source_gate_closure_authorizing_full_six_boot_retry" and
	  .source_gate_result_sha256 == "f76ea8d4aef69a89cf93be4f20dfb3ce6bfa9f25ede61cfa9b92048d775f9b24" and
	  .six_boot_attempt_1_rejection_sha256 == "c67648292f091d79e752c174f4360deee6b0a22ae696d7cbf76d5fd13cc22871" and
	  .candidate_commit == "da9ce9159b3450c28c8faf8dceac671fb7bfeba2" and
	  .candidate_parent == "a429fc30252ac6af94c51d96cd4ac24e72d9f83b" and
	  .candidate_tree == "58c6510c6f517004e37107786d006bb8333b79b8" and
	  .artifact_count == 105 and
	  .clock_skew_retries == 2 and .final_clock_skew_warnings == 0 and
	  .prior_six_boot_attempt_rejected == true and
	  .prior_six_boot_matrix_passed == false and
	  .n134_complete == true and
	  .six_boot_diagnostic_matrix_may_start == true and
	  .full_six_boot_retry_required == true and
	  .r4_e3_source_accepted == false and
	  .r4_e3_concurrency_correctness_accepted == false and
	  .production_protection == false and
	  .deployment_ready == false and
	  .multi_cluster_ready == false and
	  .datacenter_ready == false
	' "$closure" >/dev/null
done
[ "$(jq -r '.artifact_snapshot_manifest_sha256' "$CLOSURE_R3")" = "$(jq -r '.artifact_snapshot_manifest_sha256' "$CLOSURE_R4")" ] || die 'closure artifact manifests disagree'
jq -e '
  .status == "r4_e3_concurrency_diagnostic_pre_source_plan" and
  .source_boundary.future_parent == "a429fc30252ac6af94c51d96cd4ac24e72d9f83b" and
  .source_boundary.allowed_files == ["init/Kconfig","kernel/sched/exec_lease.c"] and
  .configuration.name == "SCHED_EXEC_LEASE_R4_KUNIT_TEST" and
  .configuration.default_enabled == false and
  .configuration.suite_name == "sched_exec_lease_r4_concurrency" and
  (.required_case_families | length) == 36 and
  (.capacity_and_allocation.allocation_fault_sites | length) == 6 and
  .race_control.hard_timeout_seconds == 15 and
  .race_control.stress_iterations_per_diagnostic_boot == 2048 and
  .race_control.required_stress_families == ["bridge","notifier","migration","hotplug","retirement"] and
  .race_control.matrix_reduction_after_failure == false and
  .build_and_boot_matrix.qemu_boots == ["arm64_standard_debug","x86_64_standard_debug","arm64_hotplug_fault_injection","x86_64_hotplug_fault_injection","arm64_generic_kasan","x86_64_kcsan"] and
  .build_and_boot_matrix.suite_filter_exact == "sched_exec_lease_r4_concurrency" and
  .build_and_boot_matrix.required_case_failures_allowed == 0 and
  .build_and_boot_matrix.required_case_skips_allowed == 0 and
  .build_and_boot_matrix.required_case_timeouts_allowed == 0 and
  .build_and_boot_matrix.warning_reports_allowed == 0 and
  .build_and_boot_matrix.virtual_result_supports_bare_metal_or_production_claim == false and
  .authorization_after_pass.r4_e3_source_accepted == false and
  .authorization_after_pass.r4_e3_concurrency_correctness_accepted == false and
  .safety_flags.runtime_scheduler_hook_approved == false and
  .safety_flags.production_protection == false and
  .safety_flags.deployment_ready == false and
  .safety_flags.datacenter_ready == false
' "$PLAN" >/dev/null

[ "$(git -C "$LINUX_DIR" rev-parse HEAD)" = "$PRIMARY_COMMIT" ] || die 'primary Linux moved'
[ -z "$(git -C "$LINUX_DIR" status --porcelain --untracked-files=no)" ] || die 'primary Linux checkout is dirty'
[ "$(git -C "$LINUX_DIR" rev-parse "$E3_COMMIT^")" = "$E2_COMMIT" ] || die 'E3 candidate parent moved'
[ "$(git -C "$LINUX_DIR" rev-parse "$E3_COMMIT^{tree}")" = "$E3_TREE" ] || die 'E3 candidate tree moved'
[ "$(git -C "$LINUX_DIR" rev-parse refs/heads/codex/p5a-r4-e3-concurrency-prototype)" = "$E3_COMMIT" ] || die 'local E3 ref moved'
[ "$(git -C "$LINUX_DIR" rev-parse refs/remotes/fork/codex/p5a-r4-e3-concurrency-prototype)" = "$E3_COMMIT" ] || die 'fork E3 ref moved'
[ "$(git -C "$PATCH_QUEUE_DIR" rev-parse HEAD)" = "$PATCH_QUEUE_COMMIT" ] || die 'patch queue moved'
[ -z "$(git -C "$PATCH_QUEUE_DIR" status --porcelain)" ] || die 'patch queue is dirty'

git -C "$LINUX_DIR" worktree add --detach "$E3_DIR" "$E3_COMMIT" > "$OUT_DIR/e3-worktree-add.log" 2>&1
[ "$(git -C "$E3_DIR" rev-parse HEAD)" = "$E3_COMMIT" ] || die 'diagnostic worktree commit mismatch'
[ "$(git -C "$E3_DIR" rev-parse 'HEAD^{tree}')" = "$E3_TREE" ] || die 'diagnostic worktree tree mismatch'
git -C "$E3_DIR" diff --binary "$E2_COMMIT..$E3_COMMIT" > "$OUT_DIR/e3-source.diff"
[ "$(sha256sum "$OUT_DIR/e3-source.diff" | awk '{print $1}')" = "$E3_DIFF_SHA" ] || die 'diagnostic source diff changed'

SOURCE="$E3_DIR/kernel/sched/exec_lease.c"
sed -n '/^static struct kunit_case sched_exec_r4_test_cases\[\]/,/^};/p' "$SOURCE" |
	sed -n 's/^[[:space:]]*KUNIT_CASE(\([^)]*\)).*/\1/p' > "$OUT_DIR/expected-cases.txt"
[ "$(wc -l < "$OUT_DIR/expected-cases.txt" | tr -d ' ')" = "$REQUIRED_CASES" ] || die 'expected case count changed'
diff -u <(jq -r '.required_case_families[] | "sched_exec_r4_test_" + .' "$PLAN") \
	"$OUT_DIR/expected-cases.txt" > "$OUT_DIR/expected-cases.diff" || die 'source cases differ from plan'
jq -R -s 'split("\n") | map(select(length > 0)) | sort' "$OUT_DIR/expected-cases.txt" > "$OUT_DIR/expected-receipt-cases.json"
jq -r '.capacity_and_allocation.allocation_fault_sites[]' "$PLAN" > "$OUT_DIR/expected-fault-sites.txt"
jq '.capacity_and_allocation.allocation_fault_sites' "$PLAN" > "$OUT_DIR/expected-fault-sites.json"

gcc --version > "$OUT_DIR/arm64-compiler.txt"
x86_64-linux-gnu-gcc --version > "$OUT_DIR/x86_64-compiler.txt"
qemu-system-aarch64 --version > "$OUT_DIR/qemu-aarch64-version.txt"
qemu-system-x86_64 --version > "$OUT_DIR/qemu-x86_64-version.txt"
uname -a > "$OUT_DIR/build-host.txt"

has_compiler_diagnostic()
{
	grep -Eq ':[0-9]+(:[0-9]+)?: (fatal )?(warning|error):' "$1"
}

has_clock_skew()
{
	grep -Eiq 'Clock skew detected|modification time .* in the future' "$1"
}

run_make_step()
{
	local label=$1 log=$2 verification_log=$3
	shift 3

	"$@" > "$log" 2>&1
	! has_compiler_diagnostic "$log" || die "$label compiler diagnostic"
	: > "$verification_log"
	if has_clock_skew "$log"; then
		clock_skew_retries=$((clock_skew_retries + 1))
		progress "verifying $label after shared-filesystem clock skew"
		"$@" > "$verification_log" 2>&1
		! has_compiler_diagnostic "$verification_log" || die "$label verification compiler diagnostic"
		! has_clock_skew "$verification_log" || die "$label persistent clock skew"
	fi
}

configure_boot()
{
	local arch=$1 cross=$2 profile=$3 out=$4 label=$5 required

	mkdir "$out"
	run_make_step "$label defconfig" "$OUT_DIR/$label-defconfig.log" "$OUT_DIR/$label-defconfig-verification.log" \
		make -C "$E3_DIR" O="$out" ARCH="$arch" CROSS_COMPILE="$cross" defconfig
	"$E3_DIR/scripts/config" --file "$out/.config" \
		-e EXPERT -e SMP -e SYSFS -e DEBUG_FS \
		-e CGROUPS -e CGROUP_SCHED -e FAIR_GROUP_SCHED \
		-e SCHED_EXEC_LEASE -e DEBUG_KERNEL -e SCHED_EXEC_LEASE_LAYOUT_PROBE \
		-e SCHED_EXEC_LEASE_R4_LAYOUT_PROBE -e KUNIT -d KUNIT_ALL_TESTS \
		-e KUNIT_AUTORUN_ENABLED -e SCHED_EXEC_LEASE_R4_KUNIT_TEST \
		--set-str KUNIT_DEFAULT_FILTER_GLOB "$SUITE" \
		--set-val KUNIT_DEFAULT_TIMEOUT 3600 \
		-e HOTPLUG_CPU -e PROVE_LOCKING -e DEBUG_OBJECTS \
		-e DEBUG_OBJECTS_WORK -e DEBUG_OBJECTS_RCU_HEAD -e PROVE_RCU \
		-e DEBUG_IRQFLAGS -e WQ_WATCHDOG -e DEBUG_INFO_NONE -d MODULES
	case "$profile" in
		standard|fault)
			"$E3_DIR/scripts/config" --file "$out/.config" \
				-e FAULT_INJECTION -e FAULT_INJECTION_DEBUG_FS \
				-e FAILSLAB -e FAIL_PAGE_ALLOC -d KASAN -d KCSAN
			;;
		kasan)
			"$E3_DIR/scripts/config" --file "$out/.config" \
				-d FAULT_INJECTION -d FAILSLAB -d FAIL_PAGE_ALLOC \
				-e KASAN -e KASAN_GENERIC -e KASAN_INLINE -d KCSAN
			;;
		kcsan)
			"$E3_DIR/scripts/config" --file "$out/.config" \
				-d FAULT_INJECTION -d FAILSLAB -d FAIL_PAGE_ALLOC \
				-d KASAN -e KCSAN -e KCSAN_STRICT
			;;
		*) die "unknown diagnostic profile: $profile" ;;
	esac
	run_make_step "$label olddefconfig" "$OUT_DIR/$label-olddefconfig.log" "$OUT_DIR/$label-olddefconfig-verification.log" \
		make -C "$E3_DIR" O="$out" ARCH="$arch" CROSS_COMPILE="$cross" olddefconfig
	for required in \
		CONFIG_SCHED_EXEC_LEASE_R4_LAYOUT_PROBE=y \
		CONFIG_SCHED_EXEC_LEASE_R4_KUNIT_TEST=y \
		CONFIG_KUNIT=y \
		CONFIG_KUNIT_AUTORUN_ENABLED=y \
		CONFIG_HOTPLUG_CPU=y \
		CONFIG_PROVE_LOCKING=y \
		CONFIG_DEBUG_OBJECTS_WORK=y \
		CONFIG_DEBUG_OBJECTS_RCU_HEAD=y \
		CONFIG_PROVE_RCU=y \
		CONFIG_DEBUG_IRQFLAGS=y \
		CONFIG_WQ_WATCHDOG=y; do
		grep -Fxq "$required" "$out/.config" || die "$label missing $required"
	done
	grep -Fxq '# CONFIG_KUNIT_ALL_TESTS is not set' "$out/.config" || die "$label KUNIT_ALL_TESTS enabled"
	grep -Fxq '# CONFIG_MODULES is not set' "$out/.config" || die "$label modules enabled"
	grep -Fxq "CONFIG_KUNIT_DEFAULT_FILTER_GLOB=\"$SUITE\"" "$out/.config" || die "$label filter changed"
	case "$profile" in
		standard|fault)
			for required in CONFIG_FAULT_INJECTION=y CONFIG_FAULT_INJECTION_DEBUG_FS=y CONFIG_FAILSLAB=y CONFIG_FAIL_PAGE_ALLOC=y; do
				grep -Fxq "$required" "$out/.config" || die "$label missing $required"
			done
			! grep -Eq '^CONFIG_KASAN=(y|m)$' "$out/.config" || die "$label KASAN unexpectedly enabled"
			! grep -Eq '^CONFIG_KCSAN=(y|m)$' "$out/.config" || die "$label KCSAN unexpectedly enabled"
			;;
		kasan)
			grep -Fxq 'CONFIG_KASAN=y' "$out/.config" || die "$label KASAN missing"
			grep -Fxq 'CONFIG_KASAN_GENERIC=y' "$out/.config" || die "$label generic KASAN missing"
			grep -Fxq 'CONFIG_KASAN_INLINE=y' "$out/.config" || die "$label inline KASAN missing"
			! grep -Eq '^CONFIG_KCSAN=(y|m)$' "$out/.config" || die "$label KCSAN unexpectedly enabled"
			;;
		kcsan)
			grep -Fxq 'CONFIG_KCSAN=y' "$out/.config" || die "$label KCSAN missing"
			grep -Fxq 'CONFIG_KCSAN_STRICT=y' "$out/.config" || die "$label strict KCSAN missing"
			! grep -Eq '^CONFIG_KASAN=(y|m)$' "$out/.config" || die "$label KASAN unexpectedly enabled"
			;;
	esac
	cp "$out/.config" "$OUT_DIR/$label.config"
}

build_image()
{
	local arch=$1 cross=$2 target=$3 out=$4 label=$5 base=$6 span=$7
	local log="$OUT_DIR/$label-build.log" verification_log="$OUT_DIR/$label-build-verification.log"
	local fifo="$OUT_DIR/$label-build.fifo" steps=0 percent make_pid make_rc

	rm -f "$fifo"
	mkfifo "$fifo"
	set +e
	make -C "$E3_DIR" O="$out" ARCH="$arch" CROSS_COMPILE="$cross" -j"$JOBS" "$target" > "$fifo" 2>&1 &
	make_pid=$!
	active_child_pid=$make_pid
	set -e
	: > "$log"
	while IFS= read -r line; do
		printf '%s\n' "$line" >> "$log"
		case "$line" in
			*'  CC  '*|*'  AS  '*|*'  LD  '*|*'  AR  '*|*'  HOSTCC  '*|*'  HOSTLD  '*)
				steps=$((steps + 1))
				if [ $((steps % 100)) -eq 0 ]; then
					percent=$((base + steps / 300))
					[ "$percent" -le $((base + span - 1)) ] || percent=$((base + span - 1))
					progress "$percent% building $label ($steps compiler/link steps)"
				fi
				;;
		esac
	done < "$fifo"
	set +e
	wait "$make_pid"
	make_rc=$?
	set -e
	active_child_pid=
	rm -f "$fifo"
	[ "$make_rc" = 0 ] || die "$label image build failed: $make_rc"
	! has_compiler_diagnostic "$log" || die "$label compiler diagnostic"
	: > "$verification_log"
	if has_clock_skew "$log"; then
		clock_skew_retries=$((clock_skew_retries + 1))
		progress "verifying $label image after shared-filesystem clock skew"
		make -C "$E3_DIR" O="$out" ARCH="$arch" CROSS_COMPILE="$cross" -j"$JOBS" "$target" > "$verification_log" 2>&1
		! has_compiler_diagnostic "$verification_log" || die "$label verification compiler diagnostic"
		! has_clock_skew "$verification_log" || die "$label persistent image-build clock skew"
	fi
}

write_seed_and_fault_ledgers()
{
	local label=$1 profile=$2 receipts=$3

	jq -n --arg boot "$label" --argjson stress "$STRESS_ITERATIONS" \
		'{schema_version:1,boot:$boot,randomized:false,schedule_set:"fixed-source-order-v1",stress_iterations:$stress,stress_families:[{name:"bridge",case:"sched_exec_r4_test_duplicate_irq_kick_coalesces",iterations:$stress},{name:"notifier",case:"sched_exec_r4_test_notifier_old_partial_final_republish_restart_bound",iterations:$stress},{name:"migration",case:"sched_exec_r4_test_migration_success_remove_neutral_add",iterations:$stress},{name:"hotplug",case:"sched_exec_r4_test_online_initializes_before_accepting",iterations:$stress},{name:"retirement",case:"sched_exec_r4_test_retire_vs_publisher_and_owner_clear",iterations:$stress}]}' \
		> "$OUT_DIR/$label-seed-set.json"
	jq -s -e --argjson stress "$STRESS_ITERATIONS" '
	  def receipt($name): map(select(.case == $name)) | if length == 1 then .[0] else error("receipt cardinality") end;
	  (receipt("sched_exec_r4_test_duplicate_irq_kick_coalesces").oracle_checkpoints == $stress) and
	  (receipt("sched_exec_r4_test_notifier_old_partial_final_republish_restart_bound").oracle_checkpoints == $stress) and
	  (receipt("sched_exec_r4_test_migration_success_remove_neutral_add").oracle_checkpoints == $stress) and
	  (receipt("sched_exec_r4_test_online_initializes_before_accepting").oracle_checkpoints == $stress) and
	  (receipt("sched_exec_r4_test_retire_vs_publisher_and_owner_clear").oracle_checkpoints == $stress)
	' "$receipts" >/dev/null || die "$label missing a required 2048 stress receipt"
	jq -s -e '
	  def receipt($name): map(select(.case == $name)) | if length == 1 then .[0] else error("receipt cardinality") end;
	  (receipt("sched_exec_r4_test_allocation_fault_every_pre_runnable_site_and_retry").fault_site == "all-six") and
	  (receipt("sched_exec_r4_test_allocation_fault_every_pre_runnable_site_and_retry").forced_schedule == "inject-fail-clean-retry") and
	  (receipt("sched_exec_r4_test_reference_equation_and_cleanup_after_each_failure").fault_site == "all-six") and
	  (receipt("sched_exec_r4_test_reference_equation_and_cleanup_after_each_failure").cleanup_outcome == "drained")
	' "$receipts" >/dev/null || die "$label fault receipts changed"
	jq -n --arg boot "$label" --arg profile "$profile" \
		--slurpfile fault_sites "$OUT_DIR/expected-fault-sites.json" \
		--slurpfile receipts "$receipts" \
		'{schema_version:1,boot:$boot,profile:$profile,kernel_fault_frameworks:{FAULT_INJECTION:($profile == "standard" or $profile == "fault"),FAILSLAB:($profile == "standard" or $profile == "fault"),FAIL_PAGE_ALLOC:($profile == "standard" or $profile == "fault"),globally_armed_during_early_boot:false},deterministic_test_control_plane:true,pre_runnable_fault_sites:$fault_sites[0],clean_retry_required:true,matching_receipts:[$receipts[] | select(.fault_site != "none")]}' \
		> "$OUT_DIR/$label-fault-ledger.json"
	jq -e --slurpfile expected "$OUT_DIR/expected-fault-sites.json" \
		'.pre_runnable_fault_sites == $expected[0] and
		 (.pre_runnable_fault_sites | length) == 6 and
		 .clean_retry_required == true and
		 (.matching_receipts | length) == 3 and
		 all(.matching_receipts[];
		   type == "object" and
		   (.case | type == "string") and
		   (.fault_site | type == "string") and .fault_site != "none") and
		 ([.matching_receipts[].case] | sort) == [
		   "sched_exec_r4_test_allocation_fault_every_pre_runnable_site_and_retry",
		   "sched_exec_r4_test_migration_destination_capacity_failure_stays_neutral",
		   "sched_exec_r4_test_reference_equation_and_cleanup_after_each_failure"
		 ]' \
		"$OUT_DIR/$label-fault-ledger.json" >/dev/null || die "$label fault-site ledger changed"
}

receipt_ledger_selftest()
{
	local label=receipt-ledger-selftest
	local fixture="$OUT_DIR/$label-receipts.jsonl"

	jq -nc --argjson stress "$STRESS_ITERATIONS" '[
	  {case:"sched_exec_r4_test_duplicate_irq_kick_coalesces",forced_schedule:"selftest",fault_site:"none",oracle_checkpoints:$stress,cleanup_outcome:"drained"},
	  {case:"sched_exec_r4_test_notifier_old_partial_final_republish_restart_bound",forced_schedule:"selftest",fault_site:"none",oracle_checkpoints:$stress,cleanup_outcome:"drained"},
	  {case:"sched_exec_r4_test_migration_success_remove_neutral_add",forced_schedule:"selftest",fault_site:"none",oracle_checkpoints:$stress,cleanup_outcome:"drained"},
	  {case:"sched_exec_r4_test_online_initializes_before_accepting",forced_schedule:"selftest",fault_site:"none",oracle_checkpoints:$stress,cleanup_outcome:"drained"},
	  {case:"sched_exec_r4_test_retire_vs_publisher_and_owner_clear",forced_schedule:"selftest",fault_site:"none",oracle_checkpoints:$stress,cleanup_outcome:"drained"},
	  {case:"sched_exec_r4_test_allocation_fault_every_pre_runnable_site_and_retry",forced_schedule:"inject-fail-clean-retry",fault_site:"all-six",oracle_checkpoints:12,cleanup_outcome:"drained"},
	  {case:"sched_exec_r4_test_migration_destination_capacity_failure_stays_neutral",forced_schedule:"selftest",fault_site:"capacity",oracle_checkpoints:4,cleanup_outcome:"drained"},
	  {case:"sched_exec_r4_test_reference_equation_and_cleanup_after_each_failure",forced_schedule:"selftest",fault_site:"all-six",oracle_checkpoints:9,cleanup_outcome:"drained"}
	][]' > "$fixture"
	write_seed_and_fault_ledgers "$label" standard "$fixture"
	jq -e '
	  .boot == "receipt-ledger-selftest" and
	  (.matching_receipts | length) == 3 and
	  all(.matching_receipts[]; type == "object")
	' "$OUT_DIR/$label-fault-ledger.json" >/dev/null || die 'receipt-ledger self-test changed'
	rm -f "$fixture" "$OUT_DIR/$label-seed-set.json" "$OUT_DIR/$label-fault-ledger.json"
	receipt_ledger_selftest_passed=1
}

warning_classifier_selftest()
{
	local root="$OUT_DIR/kernel-warning-classifier-selftest"
	local benign="$root/benign.log" race="$root/race.log" fail_closed="$root/fail-closed.log"
	local benign_report="$root/benign.report" race_report="$root/race.report"
	local fail_closed_report="$root/fail-closed.report"

	mkdir "$root"
	printf '%s\n' \
		'[    3.106630] kcsan: enabled early' \
		'[    3.107595] kcsan: strict mode configured' \
		'[    3.835736] kcsan: selftest: 3/3 tests passed' \
		> "$benign"
	capsched_collect_kernel_warning_reports "$benign" "$benign_report" || die 'warning-classifier benign fixture failed'
	[ ! -s "$benign_report" ] || die 'warning-classifier rejected normal KCSAN lifecycle lines'

	printf '%s\n' \
		'BUG: KCSAN: data-race in test_kernel_read / test_kernel_write' \
		'race at unknown origin, with read to 0x1 of 8 bytes by task 1 on cpu 0:' \
		'value changed: 0x0000000000000001 -> 0x0000000000000002' \
		'Reported by Kernel Concurrency Sanitizer on:' \
		> "$race"
	capsched_collect_kernel_warning_reports "$race" "$race_report" || die 'warning-classifier KCSAN report fixture failed'
	[ "$(wc -l < "$race_report" | tr -d ' ')" = 4 ] || die 'warning-classifier missed a KCSAN report signature'
	grep -Fq 'BUG: KCSAN: data-race' "$race_report" || die 'warning-classifier missed KCSAN report header'
	grep -Fq 'Reported by Kernel Concurrency Sanitizer on:' "$race_report" || die 'warning-classifier missed KCSAN report footer'

	printf '%s\n' 'WARNING: suspicious state' 'kcsan: report lost' > "$fail_closed"
	capsched_collect_kernel_warning_reports "$fail_closed" "$fail_closed_report" || die 'warning-classifier fail-closed fixture failed'
	[ "$(wc -l < "$fail_closed_report" | tr -d ' ')" = 2 ] || die 'warning-classifier did not reject generic and unknown KCSAN diagnostics'

	rm -rf -- "$root"
	warning_classifier_selftest_passed=1
}

normalize_and_validate()
{
	local label=$1 profile=$2 serial=$3 ktap=$4 receipts=$5 line case_count

	tr -d '\r' < "$serial" | sed -E 's/^\[[^]]+\][[:space:]]*//' > "$ktap"
	grep -Fq '# Subtest: sched_exec_lease_r4_concurrency' "$ktap" || die "$label suite did not start"
	grep -Eq "^[[:space:]]*ok [0-9]+( -)? $SUITE([[:space:]]|$)" "$ktap" || die "$label suite did not pass"
	! grep -Eq '^[[:space:]]*not ok [0-9]+' "$ktap" || die "$label KUnit failure"
	! grep -Fq '# SKIP' "$ktap" || die "$label required case skipped"
	case_count=$(grep -Ec '^[[:space:]]*ok [0-9]+( -)? sched_exec_r4_test_.*([[:space:]]|$)' "$ktap" || true)
	[ "$case_count" = "$REQUIRED_CASES" ] || die "$label KUnit case count: $case_count"
	while IFS= read -r line; do
		grep -Eq "^[[:space:]]*ok [0-9]+( -)? ${line}([[:space:]]|$)" "$ktap" || die "$label missing case: $line"
	done < "$OUT_DIR/expected-cases.txt"
	grep -o 'R4_RECEIPT {.*}' "$serial" | sed 's/^R4_RECEIPT //' > "$receipts"
	[ "$(wc -l < "$receipts" | tr -d ' ')" = "$REQUIRED_RECEIPTS" ] || die "$label receipt count changed"
	while IFS= read -r line; do
		printf '%s\n' "$line" | jq -e '
		  (.case | type == "string" and length > 0) and
		  (.forced_schedule | type == "string" and length > 0) and
		  (.fault_site | type == "string" and length > 0) and
		  (.oracle_checkpoints | type == "number" and . > 0) and
		  .terminal_reference_equation == "bucket+projection+contribution+dirty+notifier+callback+rcu" and
		  .cleanup_outcome == "drained"
		' >/dev/null || die "$label malformed receipt"
	done < "$receipts"
	jq -s 'map(.case) | sort' "$receipts" > "$OUT_DIR/$label-receipt-cases.json"
	cmp "$OUT_DIR/expected-receipt-cases.json" "$OUT_DIR/$label-receipt-cases.json" || die "$label receipt case set changed"
	write_seed_and_fault_ledgers "$label" "$profile" "$receipts"
	capsched_collect_kernel_warning_reports "$serial" "$OUT_DIR/$label-warning-reports.txt" || die "$label warning classifier failed"
	[ ! -s "$OUT_DIR/$label-warning-reports.txt" ] || die "$label diagnostic warning report"
}

run_qemu()
{
	local arch=$1 label=$2 profile=$3 out=$4 timeout_seconds=$5 memory=$6 progress_percent=$7
	local image serial="$OUT_DIR/$label-console.log" ktap="$OUT_DIR/$label-ktap.log"
	local receipts="$OUT_DIR/$label-receipts.jsonl" command_file="$OUT_DIR/$label-qemu-command.txt"
	local qemu_pid qemu_rc elapsed=0
	local append="kunit.enable=1 kunit.autorun=1 kunit.filter_glob=$SUITE kunit_shutdown=poweroff panic=1 oops=panic panic_on_warn=1 rcupdate.rcu_cpu_stall_suppress=0 workqueue.watchdog_thresh=60"

	case "$arch" in
		arm64)
			image="$out/arch/arm64/boot/Image"
			printf '%s\n' "qemu-system-aarch64 -machine virt,gic-version=3 -cpu cortex-a57 -accel tcg,thread=multi -smp 2 -m $memory -nic none -nographic -no-reboot -kernel $image -append 'console=ttyAMA0 earlycon=pl011,0x09000000 $append'" > "$command_file"
			set +e
			timeout --signal=TERM "$timeout_seconds" qemu-system-aarch64 \
				-machine virt,gic-version=3 -cpu cortex-a57 -accel tcg,thread=multi \
				-smp 2 -m "$memory" -nic none -nographic -no-reboot -kernel "$image" \
				-append "console=ttyAMA0 earlycon=pl011,0x09000000 $append" > "$serial" 2>&1 &
			qemu_pid=$!
			active_child_pid=$qemu_pid
			set -e
			;;
		x86_64)
			image="$out/arch/x86/boot/bzImage"
			printf '%s\n' "qemu-system-x86_64 -machine q35,accel=tcg -cpu qemu64 -smp 2 -m $memory -nic none -nographic -no-reboot -kernel $image -append 'console=ttyS0 earlyprintk=serial $append'" > "$command_file"
			set +e
			timeout --signal=TERM "$timeout_seconds" qemu-system-x86_64 \
				-machine q35,accel=tcg -cpu qemu64 -smp 2 -m "$memory" \
				-nic none -nographic -no-reboot -kernel "$image" \
				-append "console=ttyS0 earlyprintk=serial $append" > "$serial" 2>&1 &
			qemu_pid=$!
			active_child_pid=$qemu_pid
			set -e
			;;
		*) die "unknown QEMU architecture: $arch" ;;
	esac
	while kill -0 "$qemu_pid" 2>/dev/null; do
		sleep 15
		elapsed=$((elapsed + 15))
		if kill -0 "$qemu_pid" 2>/dev/null; then
			progress "$progress_percent% booting $label (${elapsed}s elapsed)"
		fi
	done
	set +e
	wait "$qemu_pid"
	qemu_rc=$?
	set -e
	active_child_pid=
	printf '%s\n' "$qemu_rc" > "$OUT_DIR/$label-qemu-exit-code.txt"
	[ "$qemu_rc" = 0 ] || die "$label QEMU exit: $qemu_rc"
	normalize_and_validate "$label" "$profile" "$serial" "$ktap" "$receipts"
}

seal_boot_result()
{
	local label=$1 arch=$2 profile=$3 out=$4 image object
	local config_sha object_sha image_sha config_size object_size image_size
	local compiler_file qemu_file

	case "$arch" in
		arm64)
			image="$out/arch/arm64/boot/Image"
			compiler_file="$OUT_DIR/arm64-compiler.txt"
			qemu_file="$OUT_DIR/qemu-aarch64-version.txt"
			;;
		x86_64)
			image="$out/arch/x86/boot/bzImage"
			compiler_file="$OUT_DIR/x86_64-compiler.txt"
			qemu_file="$OUT_DIR/qemu-x86_64-version.txt"
			;;
	esac
	object="$out/kernel/sched/exec_lease.o"
	[ -s "$out/.config" ] || die "$label config missing"
	[ -s "$object" ] || die "$label exec_lease object missing"
	[ -s "$image" ] || die "$label kernel image missing"
	readelf -h "$object" > "$OUT_DIR/$label-exec-lease-readelf.txt" || die "$label exec_lease object is not ELF"
	config_sha=$(sha256sum "$out/.config" | awk '{print $1}')
	object_sha=$(sha256sum "$object" | awk '{print $1}')
	image_sha=$(sha256sum "$image" | awk '{print $1}')
	config_size=$(stat -c %s "$out/.config")
	object_size=$(stat -c %s "$object")
	image_size=$(stat -c %s "$image")
	jq -n --arg boot "$label" --arg arch "$arch" --arg profile "$profile" \
		--arg config_sha "$config_sha" --arg object_sha "$object_sha" --arg image_sha "$image_sha" \
		--arg compiler_sha "$(sha256sum "$compiler_file" | awk '{print $1}')" \
		--arg qemu_sha "$(sha256sum "$qemu_file" | awk '{print $1}')" \
		--arg build_log_sha "$(sha256sum "$OUT_DIR/$label-build.log" | awk '{print $1}')" \
		--arg qemu_command_sha "$(sha256sum "$OUT_DIR/$label-qemu-command.txt" | awk '{print $1}')" \
		--arg console_sha "$(sha256sum "$OUT_DIR/$label-console.log" | awk '{print $1}')" \
		--arg ktap_sha "$(sha256sum "$OUT_DIR/$label-ktap.log" | awk '{print $1}')" \
		--arg receipts_sha "$(sha256sum "$OUT_DIR/$label-receipts.jsonl" | awk '{print $1}')" \
		--arg seed_sha "$(sha256sum "$OUT_DIR/$label-seed-set.json" | awk '{print $1}')" \
		--arg fault_sha "$(sha256sum "$OUT_DIR/$label-fault-ledger.json" | awk '{print $1}')" \
		--argjson config_size "$config_size" --argjson object_size "$object_size" --argjson image_size "$image_size" \
		'{schema_version:1,status:"passed",boot:$boot,architecture:$arch,profile:$profile,cases_passed:36,case_failures:0,case_skips:0,case_timeouts:0,receipts:36,stress_families:5,stress_iterations_per_family:2048,allocation_fault_sites:6,warning_reports:0,compiler_sha256:$compiler_sha,config:{sha256:$config_sha,size:$config_size},exec_lease_object:{sha256:$object_sha,size:$object_size},kernel_image:{sha256:$image_sha,size:$image_size},build_log_sha256:$build_log_sha,qemu_version_sha256:$qemu_sha,qemu_command_sha256:$qemu_command_sha,console_sha256:$console_sha,ktap_sha256:$ktap_sha,receipts_sha256:$receipts_sha,seed_set_sha256:$seed_sha,fault_ledger_sha256:$fault_sha,fresh_build_output:true,build_output_retired_after_seal:true,virtual_synthetic_protocol_only:true}' \
		> "$OUT_DIR/$label-result.json.pending"
	jq -e '.status == "passed" and .cases_passed == 36 and .receipts == 36 and .warning_reports == 0 and .fresh_build_output == true and .virtual_synthetic_protocol_only == true' "$OUT_DIR/$label-result.json.pending" >/dev/null
	mv "$OUT_DIR/$label-result.json.pending" "$OUT_DIR/$label-result.json"
}

run_boot()
{
	local label=$1 arch=$2 cross=$3 profile=$4 target=$5 timeout_seconds=$6 memory=$7 build_base=$8 build_span=$9 boot_percent=${10}
	local out="$BUILD_ROOT/$label"

	current_build=$out
	progress "$build_base% configuring $label"
	configure_boot "$arch" "$cross" "$profile" "$out" "$label"
	progress "$build_base% building $label fresh kernel image"
	build_image "$arch" "$cross" "$target" "$out" "$label" "$build_base" "$build_span"
	progress "$boot_percent% booting $label exact KUnit suite"
	run_qemu "$arch" "$label" "$profile" "$out" "$timeout_seconds" "$memory" "$boot_percent"
	seal_boot_result "$label" "$arch" "$profile" "$out"
	retire_build "$out"
	progress "$boot_percent% sealed $label evidence and retired fresh build output"
}

progress '3% validating receipt-ledger JSONL serializer before any build'
receipt_ledger_selftest
progress '4% validating fail-closed KCSAN and kernel-warning classification before any build'
warning_classifier_selftest

if [ "${CONFIG_SMOKE_ONLY:-0}" = 1 ]; then
	progress '5% config-smoke arm64 standard debug'
	current_build="$BUILD_ROOT/arm64-standard-debug"
	configure_boot arm64 '' standard "$current_build" arm64-standard-debug
	retire_build "$current_build"
	progress '20% config-smoke x86_64 standard debug'
	current_build="$BUILD_ROOT/x86_64-standard-debug"
	configure_boot x86_64 x86_64-linux-gnu- standard "$current_build" x86_64-standard-debug
	retire_build "$current_build"
	progress '35% config-smoke arm64 hotplug/fault'
	current_build="$BUILD_ROOT/arm64-hotplug-fault-injection"
	configure_boot arm64 '' fault "$current_build" arm64-hotplug-fault-injection
	retire_build "$current_build"
	progress '50% config-smoke x86_64 hotplug/fault'
	current_build="$BUILD_ROOT/x86_64-hotplug-fault-injection"
	configure_boot x86_64 x86_64-linux-gnu- fault "$current_build" x86_64-hotplug-fault-injection
	retire_build "$current_build"
	progress '65% config-smoke arm64 generic KASAN'
	current_build="$BUILD_ROOT/arm64-generic-kasan"
	configure_boot arm64 '' kasan "$current_build" arm64-generic-kasan
	retire_build "$current_build"
	progress '80% config-smoke x86_64 KCSAN'
	current_build="$BUILD_ROOT/x86_64-kcsan"
	configure_boot x86_64 x86_64-linux-gnu- kcsan "$current_build" x86_64-kcsan
	retire_build "$current_build"
	capsched_verify_file_sha256 "$RUNNER_SOURCE" "$runner_initial_sha" || die 'runner changed during config smoke'
	capsched_verify_file_sha256 "$INPUT_DIR/kernel-warning-classifier.sh" "$WARNING_CLASSIFIER_SHA" || die 'warning classifier changed during config smoke'
	capsched_verify_file_sha256 "$SOURCE_GATE" "$SOURCE_GATE_SHA" || die 'source gate snapshot changed during config smoke'
	capsched_verify_file_sha256 "$SIX_BOOT_ATTEMPT_2_REJECTION" "$SIX_BOOT_ATTEMPT_2_REJECTION_SHA" || die 'attempt-2 rejection snapshot changed during config smoke'
	capsched_verify_file_sha256 "$SIX_BOOT_ATTEMPT_3_REJECTION" "$SIX_BOOT_ATTEMPT_3_REJECTION_SHA" || die 'attempt-3 rejection snapshot changed during config smoke'
	jq -n --arg run_id "$RUN_ID" --arg runner_sha "$runner_initial_sha" --arg classifier_sha "$WARNING_CLASSIFIER_SHA" --arg candidate "$E3_COMMIT" --arg source_gate_sha "$SOURCE_GATE_SHA" --arg closure_r3_sha "$CLOSURE_R3_SHA" --arg closure_r4_sha "$CLOSURE_R4_SHA" --arg rejection_sha "$SIX_BOOT_ATTEMPT_1_REJECTION_SHA" --arg rejection_2_sha "$SIX_BOOT_ATTEMPT_2_REJECTION_SHA" --arg rejection_3_sha "$SIX_BOOT_ATTEMPT_3_REJECTION_SHA" --argjson retries "$clock_skew_retries" --argjson ledger_selftest "$receipt_ledger_selftest_passed" --argjson classifier_selftest "$warning_classifier_selftest_passed" \
		'{schema_version:1,status:"passed_warning_classifier_hardened_six_config_smoke_without_build_or_boot",run_id:$run_id,runner_sha256:$runner_sha,kernel_warning_classifier_sha256:$classifier_sha,candidate_commit:$candidate,source_gate_result_sha256:$source_gate_sha,source_gate_closure_result_sha256:[$closure_r3_sha,$closure_r4_sha],prior_six_boot_attempt_rejection_sha256:$rejection_sha,prior_six_boot_attempt_2_rejection_sha256:$rejection_2_sha,prior_six_boot_attempt_3_rejection_sha256:$rejection_3_sha,prior_six_boot_attempt_rejected:true,prior_six_boot_attempt_2_rejected:true,prior_six_boot_attempt_3_rejected:true,receipt_ledger_jsonl_selftest_passed:($ledger_selftest == 1),kernel_warning_classifier_selftest_passed:($classifier_selftest == 1),unknown_kcsan_messages_fail_closed:true,full_six_boot_retry_required:true,configs:["arm64_standard_debug","x86_64_standard_debug","arm64_hotplug_fault_injection","x86_64_hotplug_fault_injection","arm64_generic_kasan","x86_64_kcsan"],clock_skew_retries:$retries,builds_started:0,boots_started:0,matrix_passed:false,r4_e3_source_accepted:false,production_protection:false,datacenter_ready:false}' > "$OUT_DIR/config-smoke-result.json"
	progress '100% all six diagnostic configs resolved; no build or boot started'
	exit 0
fi

run_boot arm64-standard-debug arm64 '' standard Image "$QEMU_TIMEOUT_STANDARD" 2048 5 12 18
run_boot x86_64-standard-debug x86_64 x86_64-linux-gnu- standard bzImage "$QEMU_TIMEOUT_STANDARD" 2048 20 12 33
run_boot arm64-hotplug-fault-injection arm64 '' fault Image "$QEMU_TIMEOUT_FAULT" 2048 35 12 48
run_boot x86_64-hotplug-fault-injection x86_64 x86_64-linux-gnu- fault bzImage "$QEMU_TIMEOUT_FAULT" 2048 50 12 63
run_boot arm64-generic-kasan arm64 '' kasan Image "$QEMU_TIMEOUT_SANITIZER" 4096 65 13 79
run_boot x86_64-kcsan x86_64 x86_64-linux-gnu- kcsan bzImage "$QEMU_TIMEOUT_SANITIZER" 4096 81 13 95

progress '97% sealing complete six-boot matrix result and negative claims'
capsched_verify_file_sha256 "$RUNNER_SOURCE" "$runner_initial_sha" || die 'runner changed during matrix'
capsched_verify_file_sha256 "$INPUT_DIR/runner.sh" "$runner_initial_sha" || die 'runner snapshot changed'
capsched_verify_file_sha256 "$INPUT_DIR/kernel-warning-classifier.sh" "$WARNING_CLASSIFIER_SHA" || die 'warning classifier snapshot changed'
capsched_verify_file_sha256 "$PLAN" "$PLAN_SHA" || die 'plan snapshot changed'
capsched_verify_file_sha256 "$SOURCE_GATE" "$SOURCE_GATE_SHA" || die 'source gate snapshot changed'
capsched_verify_file_sha256 "$CLOSURE_R3" "$CLOSURE_R3_SHA" || die 'closure r3 snapshot changed'
capsched_verify_file_sha256 "$CLOSURE_R4" "$CLOSURE_R4_SHA" || die 'closure r4 snapshot changed'
capsched_verify_file_sha256 "$SIX_BOOT_ATTEMPT_2_REJECTION" "$SIX_BOOT_ATTEMPT_2_REJECTION_SHA" || die 'attempt-2 rejection snapshot changed'
capsched_verify_file_sha256 "$SIX_BOOT_ATTEMPT_3_REJECTION" "$SIX_BOOT_ATTEMPT_3_REJECTION_SHA" || die 'attempt-3 rejection snapshot changed'
[ -z "$(git -C "$E3_DIR" status --porcelain --untracked-files=no)" ] || die 'source worktree changed during matrix'
[ -z "$(find "$BUILD_ROOT" -mindepth 1 -maxdepth 1 -print -quit)" ] || die 'fresh build output was not retired'

boot_results_json="$OUT_DIR/boot-results.json"
jq -s '.' \
	"$OUT_DIR/arm64-standard-debug-result.json" \
	"$OUT_DIR/x86_64-standard-debug-result.json" \
	"$OUT_DIR/arm64-hotplug-fault-injection-result.json" \
	"$OUT_DIR/x86_64-hotplug-fault-injection-result.json" \
	"$OUT_DIR/arm64-generic-kasan-result.json" \
	"$OUT_DIR/x86_64-kcsan-result.json" > "$boot_results_json"
jq -e 'length == 6 and all(.status == "passed") and all(.cases_passed == 36) and all(.receipts == 36) and all(.case_failures == 0) and all(.case_skips == 0) and all(.case_timeouts == 0) and all(.warning_reports == 0)' "$boot_results_json" >/dev/null

jq -n \
	--arg run_id "$RUN_ID" --arg candidate "$E3_COMMIT" --arg parent "$E2_COMMIT" --arg tree "$E3_TREE" --arg diff_sha "$E3_DIFF_SHA" \
	--arg primary "$PRIMARY_COMMIT" --arg patch_queue "$PATCH_QUEUE_COMMIT" --arg source_gate_sha "$SOURCE_GATE_SHA" \
	--arg closure_r3_sha "$CLOSURE_R3_SHA" --arg closure_r4_sha "$CLOSURE_R4_SHA" --arg rejection_sha "$SIX_BOOT_ATTEMPT_1_REJECTION_SHA" --arg rejection_2_sha "$SIX_BOOT_ATTEMPT_2_REJECTION_SHA" --arg rejection_3_sha "$SIX_BOOT_ATTEMPT_3_REJECTION_SHA" \
	--arg runner "$INPUT_DIR/runner.sh" --arg runner_sha "$runner_initial_sha" --arg classifier_sha "$WARNING_CLASSIFIER_SHA" --arg plan "$PLAN" --arg plan_sha "$PLAN_SHA" \
	--arg source_gate "$SOURCE_GATE" \
	--arg boot_results "$boot_results_json" --arg boot_results_sha "$(sha256sum "$boot_results_json" | awk '{print $1}')" \
	--slurpfile results "$boot_results_json" --argjson clock_skew_retries "$clock_skew_retries" --argjson ledger_selftest "$receipt_ledger_selftest_passed" --argjson classifier_selftest "$warning_classifier_selftest_passed" \
	'{schema_version:1,id:"sched-exec-lease-p5a-r4-e3-six-boot-diagnostic-matrix-result-v1",run_id:$run_id,status:"passed_six_boot_diagnostic_matrix_awaiting_independent_closure",candidate_commit:$candidate,candidate_parent:$parent,candidate_tree:$tree,candidate_diff_sha256:$diff_sha,primary_commit:$primary,patch_queue_commit:$patch_queue,source_gate_result:$source_gate,source_gate_result_sha256:$source_gate_sha,source_gate_closure_result_sha256:[$closure_r3_sha,$closure_r4_sha],prior_six_boot_attempt_rejection_sha256:$rejection_sha,prior_six_boot_attempt_2_rejection_sha256:$rejection_2_sha,prior_six_boot_attempt_3_rejection_sha256:$rejection_3_sha,prior_six_boot_attempt_rejected:true,prior_six_boot_attempt_2_rejected:true,prior_six_boot_attempt_3_rejected:true,receipt_ledger_jsonl_selftest_passed:($ledger_selftest == 1),kernel_warning_classifier_sha256:$classifier_sha,kernel_warning_classifier_selftest_passed:($classifier_selftest == 1),unknown_kcsan_messages_fail_closed:true,full_six_boot_retry_completed:true,runner:$runner,runner_sha256:$runner_sha,plan:$plan,plan_sha256:$plan_sha,architectures:["arm64","x86_64"],qemu_boots:["arm64_standard_debug","x86_64_standard_debug","arm64_hotplug_fault_injection","x86_64_hotplug_fault_injection","arm64_generic_kasan","x86_64_kcsan"],suite:"sched_exec_lease_r4_concurrency",required_cases_per_boot:36,passed_cases_per_boot:36,total_passed_cases:216,receipts_per_boot:36,total_receipts:216,stress_families:["bridge","notifier","migration","hotplug","retirement"],stress_iterations_per_family_per_boot:2048,allocation_fault_sites:6,case_failures:0,case_skips:0,case_timeouts:0,warning_reports:0,build_clock_skew_retries:$clock_skew_retries,final_build_clock_skew_warnings:0,matrix_reduction:false,fresh_build_output_per_boot:true,sequential_build_retirement:true,compiler_config_image_object_qemu_ktap_console_seed_fault_receipts_recorded:true,boot_results:$boot_results,boot_results_sha256:$boot_results_sha,results:$results[0],six_boot_matrix_passed:true,independent_matrix_closure_pending:true,r4_e3_source_accepted:false,r4_e3_concurrency_correctness_accepted:false,primary_linux_changed:false,patch_queue_changed:false,real_scheduler_attachment:false,runtime_scheduler_hook_approved:false,runtime_behavior_approved:false,runtime_denial_correctness:false,monitor_delivery_or_enforcement:false,cross_class_coverage:false,bounded_wall_clock_latency_claim:false,performance_claim:false,cost_claim:false,production_protection:false,deployment_ready:false,multi_node_ready:false,multi_cluster_ready:false,datacenter_ready:false}' > "$OUT_DIR/result.json.pending"
	jq -e '.status == "passed_six_boot_diagnostic_matrix_awaiting_independent_closure" and .prior_six_boot_attempt_2_rejected == true and .prior_six_boot_attempt_3_rejected == true and .receipt_ledger_jsonl_selftest_passed == true and .kernel_warning_classifier_selftest_passed == true and .unknown_kcsan_messages_fail_closed == true and .qemu_boots == ["arm64_standard_debug","x86_64_standard_debug","arm64_hotplug_fault_injection","x86_64_hotplug_fault_injection","arm64_generic_kasan","x86_64_kcsan"] and .total_passed_cases == 216 and .total_receipts == 216 and .case_failures == 0 and .case_skips == 0 and .case_timeouts == 0 and .warning_reports == 0 and .six_boot_matrix_passed == true and .independent_matrix_closure_pending == true and .r4_e3_source_accepted == false and .production_protection == false and .datacenter_ready == false' "$OUT_DIR/result.json.pending" >/dev/null
mv "$OUT_DIR/result.json.pending" "$OUT_DIR/result.json"
sha256sum "$OUT_DIR/result.json" > "$OUT_DIR/result.sha256"
progress '100% exact six-boot diagnostic matrix passed; independent closure still required'
printf 'result=%s\n' "$OUT_DIR/result.json"
printf 'sha256=%s\n' "$(awk '{print $1}' "$OUT_DIR/result.sha256")"
