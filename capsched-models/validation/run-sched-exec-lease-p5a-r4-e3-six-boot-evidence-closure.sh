#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
LINUX_DIR="$WORKSPACE_DIR/build/DomainLeaseLinux.volume/linux"
PATCH_QUEUE_DIR="$WORKSPACE_DIR/linux-patches"
SOURCE_RUN_ID=20260718T-p5a-r4-e3-six-boot-r4
CANONICAL_SOURCE_DIR="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r4-e3-six-boot-diagnostic-matrix/$SOURCE_RUN_ID"
RUNNER_SOURCE=${BASH_SOURCE[0]}
RUN_ID=${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
PROGRESS_FILE=${PROGRESS_FILE:-}
CLOSURE_TEST_MODE=${CLOSURE_TEST_MODE:-0}
PREFLIGHT_ONLY=${PREFLIGHT_ONLY:-0}
SOURCE_DIR_OVERRIDE=${SOURCE_DIR_OVERRIDE:-}

if [ "$CLOSURE_TEST_MODE" = 1 ]; then
	[ "$PREFLIGHT_ONLY" = 1 ] || {
		printf 'error: test mode requires PREFLIGHT_ONLY=1\n' >&2
		exit 1
	}
	[ -n "$SOURCE_DIR_OVERRIDE" ] || {
		printf 'error: test mode requires SOURCE_DIR_OVERRIDE\n' >&2
		exit 1
	}
	SOURCE_DIR=$SOURCE_DIR_OVERRIDE
	OUT_ROOT="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r4-e3-six-boot-evidence-closure-test"
else
	[ "$PREFLIGHT_ONLY" = 0 ] || {
		printf 'error: PREFLIGHT_ONLY is restricted to test mode\n' >&2
		exit 1
	}
	[ -z "$SOURCE_DIR_OVERRIDE" ] || {
		printf 'error: SOURCE_DIR_OVERRIDE is restricted to test mode\n' >&2
		exit 1
	}
	SOURCE_DIR=$CANONICAL_SOURCE_DIR
	OUT_ROOT="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r4-e3-six-boot-evidence-closure"
fi

OUT_DIR="$OUT_ROOT/$RUN_ID"
INPUT_DIR="$OUT_DIR/inputs"
EVIDENCE_DIR="$INPUT_DIR/six-boot-evidence"

SOURCE_RESULT_SHA=4717052e2f546cf5faa13bfd24d90e43626e9b66f4f6d24ad07b2ed5bc7fbedd
BOOT_RESULTS_SHA=56cd095c1107607a0526703d63ae5e8e956715a6b0d81b9828c4162d1cb1407f
SOURCE_ARTIFACT_MANIFEST_SHA=c0869ceb96c8387c7e5df4642b8f42d1414420999a8d178efd62f1443e9a44f0
SOURCE_ARTIFACT_COUNT=133
SOURCE_ARTIFACT_BYTES=4156928
SOURCE_RUNNER_SHA=3c85c01a7b3edfd0887d7f19ca68b7ce9940859f59289b861c1c32e8b09e19b1
HARDENING_LIB_SHA=4548753bc2acaa7497aef9e9ff070d9952f9b5ee20631c6116590067eab9ccc6
WARNING_CLASSIFIER_SHA=8adcff74f0395f5ec219343c0cb5b1f179efee2292ab853d4fc7e410467dc23a
PLAN_SHA=f9c9103b4eae2177309dd8e0134601fe3cf1eb08061986265627dcd9d8fd6677
SOURCE_GATE_SHA=f76ea8d4aef69a89cf93be4f20dfb3ce6bfa9f25ede61cfa9b92048d775f9b24
CLOSURE_R3_SHA=f6763fbb940c42d67390cae46c20e148f86020a3c2af4431e12562c198fcf613
CLOSURE_R4_SHA=92e9918d0c04147a9b78c66744081cf165564458204a18c43501d82617318e6e
REJECTION_2_SHA=eb02c397ce25e522eab88f346913b4284649f83201805cdd14b1afbc1a9d0564
REJECTION_3_SHA=06c9f228d66a7440b6c4404e131eeef2ba31ecf94a03fa8356fa81d5ba8d815b
PRIMARY_COMMIT=5e1ca3037e34823d1ba0cdd1dc04161fac170280
PATCH_QUEUE_COMMIT=16bb080da472ffabbbafd2698073eca633fb0602
E2_COMMIT=a429fc30252ac6af94c51d96cd4ac24e72d9f83b
E3_COMMIT=da9ce9159b3450c28c8faf8dceac671fb7bfeba2
E3_TREE=58c6510c6f517004e37107786d006bb8333b79b8
E3_DIFF_SHA=096d99b527bd1b433ecd07165696830f9316d07cc67484687d95cd2c2a846f08
SUITE=sched_exec_lease_r4_concurrency
REQUIRED_CASES=36
REQUIRED_RECEIPTS=36

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

case "$RUN_ID" in
	[A-Za-z0-9]* ) ;;
	* ) die 'RUN_ID must begin with an alphanumeric character' ;;
esac
case "$RUN_ID" in
	*[!A-Za-z0-9._-]*|.|..) die 'RUN_ID contains an unsafe component' ;;
esac
case "$CLOSURE_TEST_MODE:$PREFLIGHT_ONLY" in
	0:0|1:1) ;;
	*) die 'invalid closure mode' ;;
esac

for command in awk chmod cmp cp diff find git grep jq mkdir mv sed sha256sum sort stat tr wc xargs; do
	command -v "$command" >/dev/null 2>&1 || die "missing command: $command"
done
[ -d "$SOURCE_DIR" ] || die 'six-boot evidence directory missing'
[ ! -L "$SOURCE_DIR" ] || die 'six-boot evidence root is a symlink'
[ -z "$(find "$SOURCE_DIR" -type l -print -quit)" ] || die 'six-boot evidence contains a symlink'
[ -z "$(find "$SOURCE_DIR" ! -type f ! -type d -print -quit)" ] || die 'six-boot evidence contains a non-regular object'
[ "$(find "$SOURCE_DIR" -type f | wc -l | tr -d ' ')" = "$SOURCE_ARTIFACT_COUNT" ] || die 'six-boot artifact count changed'
source_bytes=$(find "$SOURCE_DIR" -type f -printf '%s\n' | awk '{sum += $1} END {printf "%.0f\n", sum}')
[ "$source_bytes" = "$SOURCE_ARTIFACT_BYTES" ] || die "six-boot artifact byte count changed: $source_bytes"
if [ -e "$OUT_DIR" ] || [ -L "$OUT_DIR" ]; then
	die "run output already exists: $OUT_DIR"
fi

mkdir -p "$OUT_ROOT"
mkdir "$OUT_DIR" "$INPUT_DIR" "$EVIDENCE_DIR"
chmod 0700 "$OUT_DIR" "$INPUT_DIR"
runner_initial_sha=$(file_sha "$RUNNER_SOURCE")
cp -- "$RUNNER_SOURCE" "$INPUT_DIR/closure-runner.sh"
chmod 0444 "$INPUT_DIR/closure-runner.sh"

progress '5% sealing and race-checking all 133 retained artifacts'
tree_manifest "$SOURCE_DIR" > "$OUT_DIR/source-artifacts-before.sha256"
[ "$(file_sha "$OUT_DIR/source-artifacts-before.sha256")" = "$SOURCE_ARTIFACT_MANIFEST_SHA" ] || die 'canonical artifact manifest changed'
cp -a -- "$SOURCE_DIR/." "$EVIDENCE_DIR/"
tree_manifest "$SOURCE_DIR" > "$OUT_DIR/source-artifacts-after.sha256"
tree_manifest "$EVIDENCE_DIR" > "$OUT_DIR/snapshot-artifacts.sha256"
diff -u "$OUT_DIR/source-artifacts-before.sha256" "$OUT_DIR/source-artifacts-after.sha256" > "$OUT_DIR/source-artifacts-race.diff" || die 'source evidence changed while snapshotting'
diff -u "$OUT_DIR/source-artifacts-before.sha256" "$OUT_DIR/snapshot-artifacts.sha256" > "$OUT_DIR/source-vs-snapshot.diff" || die 'evidence snapshot differs from source'
[ -z "$(find "$EVIDENCE_DIR" -type l -print -quit)" ] || die 'evidence snapshot contains a symlink'
[ -z "$(find "$EVIDENCE_DIR" ! -type f ! -type d -print -quit)" ] || die 'evidence snapshot contains a non-regular object'
[ "$(find "$EVIDENCE_DIR" -type f | wc -l | tr -d ' ')" = "$SOURCE_ARTIFACT_COUNT" ] || die 'snapshot artifact count changed'
snapshot_bytes=$(find "$EVIDENCE_DIR" -type f -printf '%s\n' | awk '{sum += $1} END {printf "%.0f\n", sum}')
[ "$snapshot_bytes" = "$SOURCE_ARTIFACT_BYTES" ] || die "snapshot artifact byte count changed: $snapshot_bytes"
chmod -R a-w "$EVIDENCE_DIR"

RESULT="$EVIDENCE_DIR/result.json"
verify_hash "$RESULT" "$SOURCE_RESULT_SHA" 'six-boot matrix result'
[ "$(awk '{print $1}' "$EVIDENCE_DIR/result.sha256")" = "$SOURCE_RESULT_SHA" ] || die 'six-boot result seal changed'
verify_hash "$EVIDENCE_DIR/boot-results.json" "$BOOT_RESULTS_SHA" 'boot-results array'

if [ "$CLOSURE_TEST_MODE" = 1 ]; then
	progress '100% closure preflight fixture passed; no result was published'
	printf 'preflight_manifest_sha256=%s\n' "$SOURCE_ARTIFACT_MANIFEST_SHA"
	exit 0
fi

progress '12% validating immutable inputs, matrix contract, and negative claims'
verify_hash "$EVIDENCE_DIR/inputs/runner.sh" "$SOURCE_RUNNER_SHA" 'six-boot runner snapshot'
verify_hash "$EVIDENCE_DIR/inputs/immutable-evidence-inputs.sh" "$HARDENING_LIB_SHA" 'immutable-input helper snapshot'
verify_hash "$EVIDENCE_DIR/inputs/kernel-warning-classifier.sh" "$WARNING_CLASSIFIER_SHA" 'warning-classifier snapshot'
verify_hash "$EVIDENCE_DIR/inputs/plan.json" "$PLAN_SHA" 'R4 E3 evidence plan snapshot'
verify_hash "$EVIDENCE_DIR/inputs/source-gate-result.json" "$SOURCE_GATE_SHA" 'source-gate result snapshot'
verify_hash "$EVIDENCE_DIR/inputs/source-gate-closure-r3.json" "$CLOSURE_R3_SHA" 'source-gate closure r3 snapshot'
verify_hash "$EVIDENCE_DIR/inputs/source-gate-closure-r4.json" "$CLOSURE_R4_SHA" 'source-gate closure r4 snapshot'
verify_hash "$EVIDENCE_DIR/inputs/six-boot-attempt-2-rejection.json" "$REJECTION_2_SHA" 'attempt-2 rejection snapshot'
verify_hash "$EVIDENCE_DIR/inputs/six-boot-attempt-3-rejection.json" "$REJECTION_3_SHA" 'attempt-3 rejection snapshot'
verify_hash "$EVIDENCE_DIR/e3-source.diff" "$E3_DIFF_SHA" 'retained E3 source diff'

jq -e '
  .schema_version == 1 and
  .id == "sched-exec-lease-p5a-r4-e3-six-boot-diagnostic-matrix-result-v1" and
  .run_id == "20260718T-p5a-r4-e3-six-boot-r4" and
  .status == "passed_six_boot_diagnostic_matrix_awaiting_independent_closure" and
  .candidate_commit == "da9ce9159b3450c28c8faf8dceac671fb7bfeba2" and
  .candidate_parent == "a429fc30252ac6af94c51d96cd4ac24e72d9f83b" and
  .candidate_tree == "58c6510c6f517004e37107786d006bb8333b79b8" and
  .candidate_diff_sha256 == "096d99b527bd1b433ecd07165696830f9316d07cc67484687d95cd2c2a846f08" and
  .primary_commit == "5e1ca3037e34823d1ba0cdd1dc04161fac170280" and
  .patch_queue_commit == "16bb080da472ffabbbafd2698073eca633fb0602" and
  .source_gate_result_sha256 == "f76ea8d4aef69a89cf93be4f20dfb3ce6bfa9f25ede61cfa9b92048d775f9b24" and
  .source_gate_closure_result_sha256 == ["f6763fbb940c42d67390cae46c20e148f86020a3c2af4431e12562c198fcf613","92e9918d0c04147a9b78c66744081cf165564458204a18c43501d82617318e6e"] and
  .prior_six_boot_attempt_rejected == true and
  .prior_six_boot_attempt_2_rejected == true and
  .prior_six_boot_attempt_3_rejected == true and
  .receipt_ledger_jsonl_selftest_passed == true and
  .kernel_warning_classifier_selftest_passed == true and
  .unknown_kcsan_messages_fail_closed == true and
  .architectures == ["arm64","x86_64"] and
  .qemu_boots == ["arm64_standard_debug","x86_64_standard_debug","arm64_hotplug_fault_injection","x86_64_hotplug_fault_injection","arm64_generic_kasan","x86_64_kcsan"] and
  .suite == "sched_exec_lease_r4_concurrency" and
  .required_cases_per_boot == 36 and .passed_cases_per_boot == 36 and
  .total_passed_cases == 216 and .receipts_per_boot == 36 and .total_receipts == 216 and
  .stress_families == ["bridge","notifier","migration","hotplug","retirement"] and
  .stress_iterations_per_family_per_boot == 2048 and .allocation_fault_sites == 6 and
  .case_failures == 0 and .case_skips == 0 and .case_timeouts == 0 and .warning_reports == 0 and
  .build_clock_skew_retries == 0 and .final_build_clock_skew_warnings == 0 and
  .matrix_reduction == false and .fresh_build_output_per_boot == true and
  .sequential_build_retirement == true and
  .compiler_config_image_object_qemu_ktap_console_seed_fault_receipts_recorded == true and
  .boot_results_sha256 == "56cd095c1107607a0526703d63ae5e8e956715a6b0d81b9828c4162d1cb1407f" and
  (.results | length) == 6 and .six_boot_matrix_passed == true and
  .independent_matrix_closure_pending == true and
  .r4_e3_source_accepted == false and .r4_e3_concurrency_correctness_accepted == false and
  .primary_linux_changed == false and .patch_queue_changed == false and
  .real_scheduler_attachment == false and .runtime_scheduler_hook_approved == false and
  .runtime_behavior_approved == false and .runtime_denial_correctness == false and
  .monitor_delivery_or_enforcement == false and .cross_class_coverage == false and
  .bounded_wall_clock_latency_claim == false and .performance_claim == false and .cost_claim == false and
  .production_protection == false and .deployment_ready == false and
  .multi_node_ready == false and .multi_cluster_ready == false and .datacenter_ready == false
' "$RESULT" >/dev/null
jq -e '
  .status == "r4_e3_concurrency_diagnostic_pre_source_plan" and
  (.required_case_families | length) == 36 and
  (.capacity_and_allocation.allocation_fault_sites | length) == 6 and
  .race_control.stress_iterations_per_diagnostic_boot == 2048 and
  .build_and_boot_matrix.qemu_boots == ["arm64_standard_debug","x86_64_standard_debug","arm64_hotplug_fault_injection","x86_64_hotplug_fault_injection","arm64_generic_kasan","x86_64_kcsan"] and
  .build_and_boot_matrix.suite_filter_exact == "sched_exec_lease_r4_concurrency" and
  .build_and_boot_matrix.required_case_failures_allowed == 0 and
  .build_and_boot_matrix.required_case_skips_allowed == 0 and
  .build_and_boot_matrix.required_case_timeouts_allowed == 0 and
  .build_and_boot_matrix.warning_reports_allowed == 0 and
  .build_and_boot_matrix.virtual_result_supports_bare_metal_or_production_claim == false and
  .authorization_after_pass.r4_e3_disposable_worktree_may_be_created == true and
  .authorization_after_pass.r4_e3_exact_two_file_source_draft_may_be_created == true and
  .authorization_after_pass.r4_e3_source_accepted == false and
  .authorization_after_pass.r4_e3_concurrency_correctness_accepted == false and
  .authorization_after_pass.r4_e4_plan_may_be_drafted == false and
  .authorization_after_pass.r4_e4_source_may_be_created == false and
  .authorization_after_pass.r4_behavior_source_may_be_created == false and
  .authorization_after_pass.primary_linux_may_change == false and
  .authorization_after_pass.patch_queue_may_change == false and
  all(.safety_flags[]; . == false)
' "$EVIDENCE_DIR/inputs/plan.json" >/dev/null

diff -u <(jq -r '.required_case_families[] | "sched_exec_r4_test_" + .' "$EVIDENCE_DIR/inputs/plan.json") \
	"$EVIDENCE_DIR/expected-cases.txt" > "$OUT_DIR/plan-vs-cases.diff" || die 'expected case set/order differs from plan'
diff -u <(jq -r '.capacity_and_allocation.allocation_fault_sites[]' "$EVIDENCE_DIR/inputs/plan.json") \
	"$EVIDENCE_DIR/expected-fault-sites.txt" > "$OUT_DIR/plan-vs-fault-sites.diff" || die 'fault-site set/order differs from plan'
[ ! -s "$EVIDENCE_DIR/expected-cases.diff" ] || die 'source-vs-plan case diff is nonempty'
[ "$(wc -l < "$EVIDENCE_DIR/expected-cases.txt" | tr -d ' ')" = "$REQUIRED_CASES" ] || die 'expected case count changed'
[ "$(wc -l < "$EVIDENCE_DIR/expected-fault-sites.txt" | tr -d ' ')" = 6 ] || die 'expected fault-site count changed'

# The verified snapshot is immutable for the rest of the closure.
# shellcheck disable=SC1091
source "$EVIDENCE_DIR/inputs/kernel-warning-classifier.sh"

progress '25% independently auditing six configs, build records, QEMU commands, and ELF headers'
: > "$OUT_DIR/compiler-diagnostic-scan.txt"
: > "$OUT_DIR/clock-skew-scan.txt"
: > "$OUT_DIR/kernel-warning-scan.txt"
index=0
while IFS='|' read -r label arch profile child_sha memory; do
	child="$EVIDENCE_DIR/$label-result.json"
	verify_hash "$child" "$child_sha" "$label child result"
	jq -e --arg label "$label" --arg arch "$arch" --arg profile "$profile" '
	  .schema_version == 1 and .status == "passed" and
	  .boot == $label and .architecture == $arch and .profile == $profile and
	  .cases_passed == 36 and .case_failures == 0 and .case_skips == 0 and .case_timeouts == 0 and
	  .receipts == 36 and .stress_families == 5 and .stress_iterations_per_family == 2048 and
	  .allocation_fault_sites == 6 and .warning_reports == 0 and
	  (.compiler_sha256 | test("^[0-9a-f]{64}$")) and
	  (.config.sha256 | test("^[0-9a-f]{64}$")) and .config.size > 0 and
	  (.exec_lease_object.sha256 | test("^[0-9a-f]{64}$")) and .exec_lease_object.size > 0 and
	  (.kernel_image.sha256 | test("^[0-9a-f]{64}$")) and .kernel_image.size > 0 and
	  .fresh_build_output == true and .build_output_retired_after_seal == true and
	  .virtual_synthetic_protocol_only == true
	' "$child" >/dev/null
	jq -e --argjson index "$index" --slurpfile child "$child" '.results[$index] == $child[0]' "$RESULT" >/dev/null || die "$label differs from parent result"
	jq -e --argjson index "$index" --slurpfile child "$child" '.[$index] == $child[0]' "$EVIDENCE_DIR/boot-results.json" >/dev/null || die "$label differs from boot-results"

	verify_recorded_hash "$child" '.config.sha256' "$EVIDENCE_DIR/$label.config" "$label config"
	[ "$(stat -c %s "$EVIDENCE_DIR/$label.config")" = "$(jq -r '.config.size' "$child")" ] || die "$label config size changed"
	verify_recorded_hash "$child" '.build_log_sha256' "$EVIDENCE_DIR/$label-build.log" "$label build log"
	verify_recorded_hash "$child" '.qemu_command_sha256' "$EVIDENCE_DIR/$label-qemu-command.txt" "$label QEMU command"
	verify_recorded_hash "$child" '.console_sha256' "$EVIDENCE_DIR/$label-console.log" "$label console"
	verify_recorded_hash "$child" '.ktap_sha256' "$EVIDENCE_DIR/$label-ktap.log" "$label KTAP"
	verify_recorded_hash "$child" '.receipts_sha256' "$EVIDENCE_DIR/$label-receipts.jsonl" "$label receipts"
	verify_recorded_hash "$child" '.seed_set_sha256' "$EVIDENCE_DIR/$label-seed-set.json" "$label seed set"
	verify_recorded_hash "$child" '.fault_ledger_sha256' "$EVIDENCE_DIR/$label-fault-ledger.json" "$label fault ledger"
	if [ "$arch" = arm64 ]; then
		compiler="$EVIDENCE_DIR/arm64-compiler.txt"
		qemu_version="$EVIDENCE_DIR/qemu-aarch64-version.txt"
		machine='Machine:                           AArch64'
		qemu_prefix='qemu-system-aarch64 -machine virt,gic-version=3 -cpu cortex-a57 -accel tcg,thread=multi'
		image_path="arch/arm64/boot/Image"
		console_arg='console=ttyAMA0 earlycon=pl011,0x09000000'
	else
		compiler="$EVIDENCE_DIR/x86_64-compiler.txt"
		qemu_version="$EVIDENCE_DIR/qemu-x86_64-version.txt"
		machine='Machine:                           Advanced Micro Devices X86-64'
		qemu_prefix='qemu-system-x86_64 -machine q35,accel=tcg -cpu qemu64'
		image_path="arch/x86/boot/bzImage"
		console_arg='console=ttyS0 earlyprintk=serial'
	fi
	verify_recorded_hash "$child" '.compiler_sha256' "$compiler" "$label compiler identity"
	verify_recorded_hash "$child" '.qemu_version_sha256' "$qemu_version" "$label QEMU identity"

	for log_kind in defconfig-verification olddefconfig-verification build-verification; do
		[ ! -s "$EVIDENCE_DIR/$label-$log_kind.log" ] || die "$label unexpected $log_kind output"
	done
	if grep -Ehn ':[0-9]+(:[0-9]+)?: (fatal )?(warning|error):' "$EVIDENCE_DIR/$label-build.log" >> "$OUT_DIR/compiler-diagnostic-scan.txt"; then
		die "$label compiler diagnostic found"
	fi
	if grep -Eihn 'Clock skew detected|modification time .* in the future' \
		"$EVIDENCE_DIR/$label-defconfig.log" "$EVIDENCE_DIR/$label-olddefconfig.log" \
		"$EVIDENCE_DIR/$label-build.log" >> "$OUT_DIR/clock-skew-scan.txt"; then
		die "$label clock skew found"
	fi

	config="$EVIDENCE_DIR/$label.config"
	for required in \
		CONFIG_SCHED_EXEC_LEASE=y CONFIG_SCHED_EXEC_LEASE_LAYOUT_PROBE=y \
		CONFIG_SCHED_EXEC_LEASE_R4_LAYOUT_PROBE=y CONFIG_SCHED_EXEC_LEASE_R4_KUNIT_TEST=y \
		CONFIG_KUNIT=y CONFIG_KUNIT_AUTORUN_ENABLED=y CONFIG_HOTPLUG_CPU=y \
		CONFIG_PROVE_LOCKING=y CONFIG_DEBUG_OBJECTS_WORK=y CONFIG_DEBUG_OBJECTS_RCU_HEAD=y \
		CONFIG_PROVE_RCU=y CONFIG_DEBUG_IRQFLAGS=y CONFIG_WQ_WATCHDOG=y; do
		grep -Fxq "$required" "$config" || die "$label missing $required"
	done
	grep -Fxq '# CONFIG_KUNIT_ALL_TESTS is not set' "$config" || die "$label KUNIT_ALL_TESTS enabled"
	grep -Fxq '# CONFIG_MODULES is not set' "$config" || die "$label modules enabled"
	grep -Fxq "CONFIG_KUNIT_DEFAULT_FILTER_GLOB=\"$SUITE\"" "$config" || die "$label suite filter changed"
	case "$profile" in
		standard|fault)
			for required in CONFIG_FAULT_INJECTION=y CONFIG_FAULT_INJECTION_DEBUG_FS=y CONFIG_FAILSLAB=y CONFIG_FAIL_PAGE_ALLOC=y; do
				grep -Fxq "$required" "$config" || die "$label missing $required"
			done
			! grep -Eq '^CONFIG_(KASAN|KCSAN)=(y|m)$' "$config" || die "$label sanitizer unexpectedly enabled"
			;;
		kasan)
			for required in CONFIG_KASAN=y CONFIG_KASAN_GENERIC=y CONFIG_KASAN_INLINE=y; do
				grep -Fxq "$required" "$config" || die "$label missing $required"
			done
			! grep -Eq '^CONFIG_(FAULT_INJECTION|FAILSLAB|FAIL_PAGE_ALLOC|KCSAN)=(y|m)$' "$config" || die "$label incompatible profile option enabled"
			;;
		kcsan)
			grep -Fxq 'CONFIG_KCSAN=y' "$config" || die "$label KCSAN missing"
			grep -Fxq 'CONFIG_KCSAN_STRICT=y' "$config" || die "$label strict KCSAN missing"
			! grep -Eq '^CONFIG_(FAULT_INJECTION|FAILSLAB|FAIL_PAGE_ALLOC|KASAN)=(y|m)$' "$config" || die "$label incompatible profile option enabled"
			;;
	esac

	readelf_file="$EVIDENCE_DIR/$label-exec-lease-readelf.txt"
	grep -Fq 'Class:                             ELF64' "$readelf_file" || die "$label object class changed"
	grep -Fq 'Data:                              2'"'"'s complement, little endian' "$readelf_file" || die "$label object endian changed"
	grep -Fq 'Type:                              REL (Relocatable file)' "$readelf_file" || die "$label object type changed"
	grep -Fq "$machine" "$readelf_file" || die "$label object architecture changed"

	command_file="$EVIDENCE_DIR/$label-qemu-command.txt"
	[ "$(wc -l < "$command_file" | tr -d ' ')" = 1 ] || die "$label QEMU command is not one line"
	grep -Fq "$qemu_prefix" "$command_file" || die "$label QEMU machine changed"
	grep -Fq " -smp 2 -m $memory -nic none -nographic -no-reboot " "$command_file" || die "$label QEMU isolation changed"
	grep -Fq "/var/tmp/linux-cap-builds/p5a-r4-e3-six-boot/$SOURCE_RUN_ID/$label/$image_path" "$command_file" || die "$label kernel path changed"
	grep -Fq "$console_arg kunit.enable=1 kunit.autorun=1 kunit.filter_glob=$SUITE kunit_shutdown=poweroff panic=1 oops=panic panic_on_warn=1 rcupdate.rcu_cpu_stall_suppress=0 workqueue.watchdog_thresh=60" "$command_file" || die "$label kernel command line changed"
	! grep -Eq '(^|[[:space:]])-net(dev)?([[:space:]]|$)|-device[[:space:]][^ ]*(virtio-net|e1000|rtl8139)|-drive[[:space:]]' "$command_file" || die "$label external I/O enabled"
	[ "$(tr -d '[:space:]' < "$EVIDENCE_DIR/$label-qemu-exit-code.txt")" = 0 ] || die "$label QEMU exit changed"

	ktap="$EVIDENCE_DIR/$label-ktap.log"
	grep -Fq '# Subtest: sched_exec_lease_r4_concurrency' "$ktap" || die "$label suite start missing"
	[ "$(grep -Ec "^[[:space:]]*ok [0-9]+( -)? $SUITE([[:space:]]|$)" "$ktap")" = 1 ] || die "$label suite pass cardinality changed"
	! grep -Eq '^[[:space:]]*not ok [0-9]+' "$ktap" || die "$label KTAP failure found"
	! grep -Fq '# SKIP' "$ktap" || die "$label KTAP skip found"
	sed -n -E 's/^[[:space:]]*ok [0-9]+( -)? (sched_exec_r4_test_[^ #[:space:]]*).*/\2/p' "$ktap" > "$OUT_DIR/$label-cases.txt"
	[ "$(wc -l < "$OUT_DIR/$label-cases.txt" | tr -d ' ')" = "$REQUIRED_CASES" ] || die "$label KTAP case count changed"
	diff -u "$EVIDENCE_DIR/expected-cases.txt" "$OUT_DIR/$label-cases.txt" > "$OUT_DIR/$label-cases.diff" || die "$label KTAP case set/order changed"

	receipts="$EVIDENCE_DIR/$label-receipts.jsonl"
	grep -o 'R4_RECEIPT {.*}' "$EVIDENCE_DIR/$label-console.log" | sed 's/^R4_RECEIPT //' > "$OUT_DIR/$label-console-receipts.jsonl"
	cmp "$receipts" "$OUT_DIR/$label-console-receipts.jsonl" || die "$label console/receipt ledger mismatch"
	[ "$(wc -l < "$receipts" | tr -d ' ')" = "$REQUIRED_RECEIPTS" ] || die "$label receipt count changed"
	while IFS= read -r receipt; do
		printf '%s\n' "$receipt" | jq -e '
		  (.case | type == "string" and startswith("sched_exec_r4_test_")) and
		  (.forced_schedule | type == "string" and length > 0) and
		  (.fault_site | type == "string" and length > 0) and
		  (.oracle_checkpoints | type == "number" and . > 0) and
		  .terminal_reference_equation == "bucket+projection+contribution+dirty+notifier+callback+rcu" and
		  .cleanup_outcome == "drained"
		' >/dev/null || die "$label malformed receipt"
	done < "$receipts"
	jq -s 'map(.case) | sort' "$receipts" > "$OUT_DIR/$label-receipt-cases.json"
	cmp "$EVIDENCE_DIR/expected-receipt-cases.json" "$OUT_DIR/$label-receipt-cases.json" || die "$label receipt case set changed"
	[ "$(jq -s '[.[].case] | unique | length' "$receipts")" = "$REQUIRED_RECEIPTS" ] || die "$label duplicate receipt case"
	jq -s -e '
	  def one($name): map(select(.case == $name)) | if length == 1 then .[0] else error("receipt cardinality") end;
	  (one("sched_exec_r4_test_duplicate_irq_kick_coalesces").oracle_checkpoints == 2048) and
	  (one("sched_exec_r4_test_notifier_old_partial_final_republish_restart_bound").oracle_checkpoints == 2048) and
	  (one("sched_exec_r4_test_migration_success_remove_neutral_add").oracle_checkpoints == 2048) and
	  (one("sched_exec_r4_test_online_initializes_before_accepting").oracle_checkpoints == 2048) and
	  (one("sched_exec_r4_test_retire_vs_publisher_and_owner_clear").oracle_checkpoints == 2048)
	' "$receipts" >/dev/null || die "$label stress receipt changed"

	jq -e --arg label "$label" '
	  .schema_version == 1 and .boot == $label and .randomized == false and
	  .schedule_set == "fixed-source-order-v1" and .stress_iterations == 2048 and
	  [.stress_families[].name] == ["bridge","notifier","migration","hotplug","retirement"] and
	  all(.stress_families[]; .iterations == 2048)
	' "$EVIDENCE_DIR/$label-seed-set.json" >/dev/null || die "$label seed set changed"
	jq -s '[.[] | select(.fault_site != "none")]' "$receipts" > "$OUT_DIR/$label-expected-fault-receipts.json"
	jq '.matching_receipts' "$EVIDENCE_DIR/$label-fault-ledger.json" > "$OUT_DIR/$label-actual-fault-receipts.json"
	cmp "$OUT_DIR/$label-expected-fault-receipts.json" "$OUT_DIR/$label-actual-fault-receipts.json" || die "$label fault receipt projection changed"
	jq -e --arg label "$label" --arg profile "$profile" --slurpfile sites "$EVIDENCE_DIR/expected-fault-sites.json" '
	  .schema_version == 1 and .boot == $label and .profile == $profile and
	  .deterministic_test_control_plane == true and .clean_retry_required == true and
	  .pre_runnable_fault_sites == $sites[0] and (.pre_runnable_fault_sites | length) == 6 and
	  .kernel_fault_frameworks.globally_armed_during_early_boot == false and
	  (.matching_receipts | length) == 3 and
	  ([.matching_receipts[].case] | sort) == [
	    "sched_exec_r4_test_allocation_fault_every_pre_runnable_site_and_retry",
	    "sched_exec_r4_test_migration_destination_capacity_failure_stays_neutral",
	    "sched_exec_r4_test_reference_equation_and_cleanup_after_each_failure"
	  ] and
	  (if ($profile == "standard" or $profile == "fault") then
	     .kernel_fault_frameworks.FAULT_INJECTION == true and
	     .kernel_fault_frameworks.FAILSLAB == true and
	     .kernel_fault_frameworks.FAIL_PAGE_ALLOC == true
	   else
	     .kernel_fault_frameworks.FAULT_INJECTION == false and
	     .kernel_fault_frameworks.FAILSLAB == false and
	     .kernel_fault_frameworks.FAIL_PAGE_ALLOC == false
	   end)
	' "$EVIDENCE_DIR/$label-fault-ledger.json" >/dev/null || die "$label fault ledger changed"

	capsched_collect_kernel_warning_reports "$EVIDENCE_DIR/$label-console.log" "$OUT_DIR/$label-warning-reports.txt" || die "$label warning classification failed"
	[ ! -s "$OUT_DIR/$label-warning-reports.txt" ] || {
		cat "$OUT_DIR/$label-warning-reports.txt" >> "$OUT_DIR/kernel-warning-scan.txt"
		die "$label kernel warning report found"
	}
	[ ! -s "$EVIDENCE_DIR/$label-warning-reports.txt" ] || die "$label retained warning report is nonempty"
	index=$((index + 1))
done <<'BOOT_SPECS'
arm64-standard-debug|arm64|standard|329d672a43d772e822b52d5ddc112b66adbe1685b682d7170d6076eaca86437d|2048
x86_64-standard-debug|x86_64|standard|2fbcf21cac611e47b8ad2793f9ae7c60123b28e27869e5ca2dfd220e5d03a03a|2048
arm64-hotplug-fault-injection|arm64|fault|196479b2f42fe5d9a47a4adb0ce8ccf4045e4151bc94f352070c0c07f360e300|2048
x86_64-hotplug-fault-injection|x86_64|fault|583490e941059bae694275ef5e442cc274bace3fd925fd2454f18b0090756757|2048
arm64-generic-kasan|arm64|kasan|e805954b911c31cf4a0ee222a55a89fda2cb33504d1fe9ebcf51c31f37e1fe9b|4096
x86_64-kcsan|x86_64|kcsan|3a5c0822b986905eda92d0f15cd9e3cc69a4c264ef59aab848995a6a4a6278c5|4096
BOOT_SPECS
[ "$index" = 6 ] || die 'boot specification count changed'

progress '70% checking retired build boundary and repository identities'
[ -z "$(find "$EVIDENCE_DIR" -type f \( -name '*.o' -o -name Image -o -name bzImage \) -print -quit)" ] || die 'unexpected build binary retained in evidence'
[ "$(git -C "$LINUX_DIR" rev-parse HEAD)" = "$PRIMARY_COMMIT" ] || die 'primary Linux moved'
[ -z "$(git -C "$LINUX_DIR" status --porcelain --untracked-files=no)" ] || die 'primary Linux checkout is dirty'
[ "$(git -C "$LINUX_DIR" rev-parse "$E3_COMMIT^")" = "$E2_COMMIT" ] || die 'candidate parent moved'
[ "$(git -C "$LINUX_DIR" rev-parse "$E3_COMMIT^{tree}")" = "$E3_TREE" ] || die 'candidate tree moved'
[ "$(git -C "$LINUX_DIR" rev-parse refs/heads/codex/p5a-r4-e3-concurrency-prototype)" = "$E3_COMMIT" ] || die 'local candidate ref moved'
[ "$(git -C "$LINUX_DIR" rev-parse refs/remotes/fork/codex/p5a-r4-e3-concurrency-prototype)" = "$E3_COMMIT" ] || die 'fork candidate ref moved'
git -C "$LINUX_DIR" diff --binary "$E2_COMMIT..$E3_COMMIT" > "$OUT_DIR/recomputed-e3-source.diff"
[ "$(file_sha "$OUT_DIR/recomputed-e3-source.diff")" = "$E3_DIFF_SHA" ] || die 'candidate diff changed'
cmp "$OUT_DIR/recomputed-e3-source.diff" "$EVIDENCE_DIR/e3-source.diff" || die 'retained candidate diff differs from Git'
[ "$(git -C "$LINUX_DIR" diff --name-only "$E2_COMMIT..$E3_COMMIT" | sort | tr '\n' ' ')" = 'init/Kconfig kernel/sched/exec_lease.c ' ] || die 'candidate escaped exact two-file boundary'
[ "$(git -C "$PATCH_QUEUE_DIR" rev-parse HEAD)" = "$PATCH_QUEUE_COMMIT" ] || die 'patch queue moved'
[ -z "$(git -C "$PATCH_QUEUE_DIR" status --porcelain)" ] || die 'patch queue is dirty'
[ -z "$(find "$WORKSPACE_DIR/build/DomainLeaseLinux.volume/worktrees" -mindepth 1 -maxdepth 1 -print -quit)" ] || die 'temporary worktree leaked'
[ ! -e "/var/tmp/linux-cap-builds/p5a-r4-e3-six-boot/$SOURCE_RUN_ID" ] || die 'run-owned kernel build scratch leaked'

progress '88% rechecking immutable evidence and sealing N-135 claim boundary'
[ "$(file_sha "$RUNNER_SOURCE")" = "$runner_initial_sha" ] || die 'closure runner changed during audit'
[ "$(file_sha "$INPUT_DIR/closure-runner.sh")" = "$runner_initial_sha" ] || die 'closure runner snapshot changed'
tree_manifest "$SOURCE_DIR" > "$OUT_DIR/source-artifacts-final.sha256"
diff -u "$OUT_DIR/source-artifacts-before.sha256" "$OUT_DIR/source-artifacts-final.sha256" > "$OUT_DIR/source-artifacts-final.diff" || die 'source evidence changed during closure'
[ -z "$(find "$SOURCE_DIR" -type l -print -quit)" ] || die 'source evidence gained a symlink during closure'
[ -z "$(find "$SOURCE_DIR" ! -type f ! -type d -print -quit)" ] || die 'source evidence gained a non-regular object during closure'
[ "$(find "$SOURCE_DIR" -type f | wc -l | tr -d ' ')" = "$SOURCE_ARTIFACT_COUNT" ] || die 'source artifact count changed during closure'
final_source_bytes=$(find "$SOURCE_DIR" -type f -printf '%s\n' | awk '{sum += $1} END {printf "%.0f\n", sum}')
[ "$final_source_bytes" = "$SOURCE_ARTIFACT_BYTES" ] || die "source artifact byte count changed during closure: $final_source_bytes"
snapshot_manifest_sha=$(file_sha "$OUT_DIR/snapshot-artifacts.sha256")
[ "$snapshot_manifest_sha" = "$SOURCE_ARTIFACT_MANIFEST_SHA" ] || die 'snapshot manifest seal changed'

jq -n \
	--arg run_id "$RUN_ID" --arg source_run_id "$SOURCE_RUN_ID" \
	--arg source_result_sha "$SOURCE_RESULT_SHA" --arg boot_results_sha "$BOOT_RESULTS_SHA" \
	--arg source_manifest_sha "$SOURCE_ARTIFACT_MANIFEST_SHA" --arg closure_runner_sha "$runner_initial_sha" \
	--arg warning_classifier_sha "$WARNING_CLASSIFIER_SHA" --arg candidate "$E3_COMMIT" \
	--arg parent "$E2_COMMIT" --arg tree "$E3_TREE" --arg diff_sha "$E3_DIFF_SHA" \
	--argjson artifact_count "$SOURCE_ARTIFACT_COUNT" --argjson artifact_bytes "$SOURCE_ARTIFACT_BYTES" \
	'{schema_version:1,id:"sched-exec-lease-p5a-r4-e3-six-boot-evidence-closure-result-v1",run_id:$run_id,status:"passed_independent_six_boot_evidence_closure",source_run_id:$source_run_id,source_result_sha256:$source_result_sha,boot_results_sha256:$boot_results_sha,source_artifact_manifest_sha256:$source_manifest_sha,source_artifact_count:$artifact_count,source_artifact_bytes:$artifact_bytes,closure_runner_sha256:$closure_runner_sha,kernel_warning_classifier_sha256:$warning_classifier_sha,all_source_artifacts_snapshotted_read_only:true,source_artifact_race_check_passed:true,candidate_commit:$candidate,candidate_parent:$parent,candidate_tree:$tree,candidate_diff_sha256:$diff_sha,architectures:["arm64","x86_64"],boot_profiles:["standard","standard","fault","fault","kasan","kcsan"],fresh_builds_recorded:6,qemu_boots_audited:6,configs_audited:6,build_logs_audited:6,retained_exec_lease_elf_headers_audited:6,retired_exec_lease_objects_hash_and_size_records_audited:6,retired_kernel_images_hash_and_size_records_audited:6,retired_kernel_images_or_objects_claimed_as_retained:false,ktap_suites_passed:6,cases_passed_per_boot:36,total_cases_passed:216,receipt_ledgers_audited:6,receipts_per_boot:36,total_receipts:216,seed_sets_audited:6,fault_ledgers_audited:6,stress_iterations_per_family_per_boot:2048,compiler_diagnostics:0,clock_skew_warnings:0,kernel_warning_reports:0,case_failures:0,case_skips:0,case_timeouts:0,qemu_nonzero_exits:0,network_devices_enabled:0,build_output_retirement_verified:true,temporary_worktree_retirement_verified:true,six_boot_matrix_passed:true,independent_artifact_closure_passed:true,virtual_synthetic_protocol_evidence_complete:true,n135_complete:true,r4_e3_disposable_worktree_may_be_created:true,r4_e3_exact_two_file_source_draft_may_be_created:true,r4_e3_source_accepted:false,r4_e3_concurrency_correctness_accepted:false,r4_e4_plan_may_be_drafted:false,r4_e4_source_may_be_created:false,r4_behavior_source_may_be_created:false,primary_linux_may_change:false,patch_queue_may_change:false,real_scheduler_attachment:false,runtime_scheduler_hook_approved:false,runtime_behavior_approved:false,runtime_denial_correctness:false,monitor_delivery_or_enforcement:false,cross_class_coverage:false,bounded_wall_clock_latency_claim:false,performance_claim:false,cost_claim:false,bare_metal_validated:false,production_protection:false,deployment_ready:false,multi_node_ready:false,multi_cluster_ready:false,datacenter_ready:false}' \
	> "$OUT_DIR/result.json.pending"
jq -e '
  .status == "passed_independent_six_boot_evidence_closure" and
  .source_artifact_count == 133 and .source_artifact_bytes == 4156928 and
  .fresh_builds_recorded == 6 and .qemu_boots_audited == 6 and .configs_audited == 6 and
  .total_cases_passed == 216 and .total_receipts == 216 and
  .compiler_diagnostics == 0 and .clock_skew_warnings == 0 and .kernel_warning_reports == 0 and
  .case_failures == 0 and .case_skips == 0 and .case_timeouts == 0 and .qemu_nonzero_exits == 0 and
  .independent_artifact_closure_passed == true and .virtual_synthetic_protocol_evidence_complete == true and
  .n135_complete == true and .r4_e3_source_accepted == false and
  .r4_e3_concurrency_correctness_accepted == false and .r4_e4_plan_may_be_drafted == false and
  .production_protection == false and .datacenter_ready == false
' "$OUT_DIR/result.json.pending" >/dev/null
mv "$OUT_DIR/result.json.pending" "$OUT_DIR/result.json"
jq -S 'del(.run_id)' "$OUT_DIR/result.json" > "$OUT_DIR/result.normalized.json"
sha256sum "$OUT_DIR/result.normalized.json" > "$OUT_DIR/result.normalized.sha256"
sha256sum "$OUT_DIR/result.json" > "$OUT_DIR/result.sha256"
chmod -R a-w "$INPUT_DIR"
progress '100% independent six-boot evidence closure passed; N-135 virtual evidence complete'
printf 'result=%s\n' "$OUT_DIR/result.json"
printf 'sha256=%s\n' "$(awk '{print $1}' "$OUT_DIR/result.sha256")"
printf 'normalized_sha256=%s\n' "$(awk '{print $1}' "$OUT_DIR/result.normalized.sha256")"
