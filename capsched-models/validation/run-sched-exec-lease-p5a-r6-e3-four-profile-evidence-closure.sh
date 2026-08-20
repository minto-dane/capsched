#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
PRIMARY_DIR="$WORKSPACE_DIR/linux"
CANDIDATE_DIR="$WORKSPACE_DIR/build/DomainLeaseLinux.volume/worktrees/p5a-r6-e3-correctness-prototype"
PATCH_QUEUE_DIR="$WORKSPACE_DIR/linux-patches"
SOURCE_RUN_ID=20260726T-p5a-r6-e3-four-profile-r1
CANONICAL_SOURCE_DIR="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r6-e3-four-profile-diagnostic-matrix/$SOURCE_RUN_ID"
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
	OUT_ROOT="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r6-e3-four-profile-evidence-closure-test"
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
	OUT_ROOT="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r6-e3-four-profile-evidence-closure"
fi

OUT_DIR="$OUT_ROOT/$RUN_ID"
INPUT_DIR="$OUT_DIR/inputs"
EVIDENCE_DIR="$INPUT_DIR/four-profile-evidence"

SOURCE_RESULT_SHA=bede4cbf4c5021eba080d0bd557f9e97529153e21da731ee729340ca8c2691be
PROFILE_RESULTS_SHA=9142a2a0ff800efbf2e9f5b5231575b6c6c47d26e14ca535265f81221e802b71
SOURCE_ARTIFACT_MANIFEST_SHA=151c877301d3f59d171fc30bf449044990e46892860c8f9d2eb4f3467b0b4ecc
SOURCE_ARTIFACT_COUNT=60
SOURCE_ARTIFACT_BYTES=2659341
SOURCE_RUNNER_SHA=4b27719906ac0078ffed06af1931eff590bd05024bfbc736b3ddc0f860a4119d
HARDENING_LIB_SHA=4548753bc2acaa7497aef9e9ff070d9952f9b5ee20631c6116590067eab9ccc6
WARNING_CLASSIFIER_SHA=8adcff74f0395f5ec219343c0cb5b1f179efee2292ab853d4fc7e410467dc23a
PLAN_SHA=36f5d2b0423d1a4f6de05e08ac4166e098bb7e7680ce81758b361187dc0e8d22
SOURCE_GATE_SHA=88376403879ecc2b0a059791ba59a5bd71addd493e9c8052c2742f877f9e7f25
E2_COMMIT=66e2fd20fc85012d7dc03649fcf4c7af583cbb94
E3_COMMIT=99287291f1c8e0d6c1b3ea86d121508c5547f424
E3_TREE=2b863b57dfe3f03609ad1a73c965874f71056e8f
E3_DIFF_SHA=2ed265756c1cee52252bedc6cbfb3d651eed136be9dca98992496ee80ebfb715
PRIMARY_COMMIT=5e1ca3037e34823d1ba0cdd1dc04161fac170280
PATCH_QUEUE_COMMIT=16bb080da472ffabbbafd2698073eca633fb0602
SUITE=sched_exec_lease_r6_correctness
REQUIRED_CASES=55
REQUIRED_RECEIPTS=55

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
	[ "$(file_sha "$file")" = "$expected" ] ||
		die "$label hash changed"
}

verify_recorded_hash()
{
	local result=$1 field=$2 file=$3 label=$4 expected

	expected=$(jq -er "$field" "$result") ||
		die "$label hash field missing"
	verify_hash "$file" "$expected" "$label"
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

for command in awk chmod cmp cp diff find git grep jq mkdir mv sed \
	sha256sum sort stat tr wc xargs; do
	command -v "$command" >/dev/null 2>&1 ||
		die "missing command: $command"
done
[ -d "$SOURCE_DIR" ] || die 'four-profile evidence directory missing'
[ ! -L "$SOURCE_DIR" ] ||
	die 'four-profile evidence root is a symlink'
[ -z "$(find "$SOURCE_DIR" -type l -print -quit)" ] ||
	die 'four-profile evidence contains a symlink'
[ -z "$(find "$SOURCE_DIR" ! -type f ! -type d -print -quit)" ] ||
	die 'four-profile evidence contains a non-regular object'
[ "$(find "$SOURCE_DIR" -type f | wc -l | tr -d ' ')" = \
	"$SOURCE_ARTIFACT_COUNT" ] ||
	die 'four-profile artifact count changed'
source_bytes=$(find "$SOURCE_DIR" -type f -printf '%s\n' |
	awk '{sum += $1} END {printf "%.0f\n", sum}')
[ "$source_bytes" = "$SOURCE_ARTIFACT_BYTES" ] ||
	die "four-profile artifact byte count changed: $source_bytes"
if [ -e "$OUT_DIR" ] || [ -L "$OUT_DIR" ]; then
	die "run output already exists: $OUT_DIR"
fi

mkdir -p "$OUT_ROOT"
mkdir "$OUT_DIR" "$INPUT_DIR" "$EVIDENCE_DIR"
chmod 0700 "$OUT_DIR" "$INPUT_DIR"
runner_initial_sha=$(file_sha "$RUNNER_SOURCE")
cp -- "$RUNNER_SOURCE" "$INPUT_DIR/closure-runner.sh"
chmod 0444 "$INPUT_DIR/closure-runner.sh"

progress '5% sealing and race-checking all 60 retained artifacts'
tree_manifest "$SOURCE_DIR" > "$OUT_DIR/source-artifacts-before.sha256"
[ "$(file_sha "$OUT_DIR/source-artifacts-before.sha256")" = \
	"$SOURCE_ARTIFACT_MANIFEST_SHA" ] ||
	die 'canonical artifact manifest changed'
cp -a -- "$SOURCE_DIR/." "$EVIDENCE_DIR/"
tree_manifest "$SOURCE_DIR" > "$OUT_DIR/source-artifacts-after.sha256"
tree_manifest "$EVIDENCE_DIR" > "$OUT_DIR/snapshot-artifacts.sha256"
diff -u "$OUT_DIR/source-artifacts-before.sha256" \
	"$OUT_DIR/source-artifacts-after.sha256" \
	> "$OUT_DIR/source-artifacts-race.diff" ||
	die 'source evidence changed while snapshotting'
diff -u "$OUT_DIR/source-artifacts-before.sha256" \
	"$OUT_DIR/snapshot-artifacts.sha256" \
	> "$OUT_DIR/source-vs-snapshot.diff" ||
	die 'evidence snapshot differs from source'
[ -z "$(find "$EVIDENCE_DIR" -type l -print -quit)" ] ||
	die 'evidence snapshot contains a symlink'
[ -z "$(find "$EVIDENCE_DIR" ! -type f ! -type d -print -quit)" ] ||
	die 'evidence snapshot contains a non-regular object'
[ "$(find "$EVIDENCE_DIR" -type f | wc -l | tr -d ' ')" = \
	"$SOURCE_ARTIFACT_COUNT" ] ||
	die 'snapshot artifact count changed'
snapshot_bytes=$(find "$EVIDENCE_DIR" -type f -printf '%s\n' |
	awk '{sum += $1} END {printf "%.0f\n", sum}')
[ "$snapshot_bytes" = "$SOURCE_ARTIFACT_BYTES" ] ||
	die "snapshot artifact byte count changed: $snapshot_bytes"
chmod -R a-w "$EVIDENCE_DIR"

RESULT="$EVIDENCE_DIR/result.json"
verify_hash "$RESULT" "$SOURCE_RESULT_SHA" 'four-profile matrix result'
[ "$(awk '{print $1}' "$EVIDENCE_DIR/result.sha256")" = \
	"$SOURCE_RESULT_SHA" ] || die 'four-profile result seal changed'
verify_hash "$EVIDENCE_DIR/profile-results.json" "$PROFILE_RESULTS_SHA" \
	'profile-results array'

if [ "$CLOSURE_TEST_MODE" = 1 ]; then
	progress '100% closure preflight fixture passed; no result was published'
	printf 'preflight_manifest_sha256=%s\n' \
		"$SOURCE_ARTIFACT_MANIFEST_SHA"
	exit 0
fi

progress '15% validating immutable inputs, matrix contract, and claim boundary'
verify_hash "$EVIDENCE_DIR/inputs/runner.sh" "$SOURCE_RUNNER_SHA" \
	'four-profile runner snapshot'
verify_hash "$EVIDENCE_DIR/inputs/immutable-evidence-inputs.sh" \
	"$HARDENING_LIB_SHA" 'immutable-input helper snapshot'
verify_hash "$EVIDENCE_DIR/inputs/kernel-warning-classifier.sh" \
	"$WARNING_CLASSIFIER_SHA" 'warning-classifier snapshot'
verify_hash "$EVIDENCE_DIR/inputs/plan.json" "$PLAN_SHA" \
	'R6-E3 evidence plan snapshot'
verify_hash "$EVIDENCE_DIR/inputs/source-gate-result.json" \
	"$SOURCE_GATE_SHA" 'source-gate result snapshot'
verify_hash "$EVIDENCE_DIR/e3-source.diff" "$E3_DIFF_SHA" \
	'retained E3 source diff'
verify_hash "$EVIDENCE_DIR/expected-cases.txt" \
	b8e84a49adc790275612194237c764397002eb3005cd6460aba0410424c45a03 \
	'expected case order'
verify_hash "$EVIDENCE_DIR/expected-receipt-cases.json" \
	0eaf1ea5052209e541b21907af45be084435c61da36b8c01e3608d0803fb7c96 \
	'expected receipt case set'

jq -e '
  .schema_version == 1 and
  .id ==
    "sched-exec-lease-p5a-r6-e3-four-profile-diagnostic-matrix-result-v1" and
  .run_id == "20260726T-p5a-r6-e3-four-profile-r1" and
  .status ==
    "passed_four_profile_matrix_awaiting_independent_closure" and
  .candidate_commit ==
    "99287291f1c8e0d6c1b3ea86d121508c5547f424" and
  .candidate_parent ==
    "66e2fd20fc85012d7dc03649fcf4c7af583cbb94" and
  .candidate_tree ==
    "2b863b57dfe3f03609ad1a73c965874f71056e8f" and
  .candidate_diff_sha256 ==
    "2ed265756c1cee52252bedc6cbfb3d651eed136be9dca98992496ee80ebfb715" and
  .source_gate_sha256 ==
    "88376403879ecc2b0a059791ba59a5bd71addd493e9c8052c2742f877f9e7f25" and
  .plan_sha256 ==
    "36f5d2b0423d1a4f6de05e08ac4166e098bb7e7680ce81758b361187dc0e8d22" and
  .runner_sha256 ==
    "4b27719906ac0078ffed06af1931eff590bd05024bfbc736b3ddc0f860a4119d" and
  .architectures == ["arm64","x86_64"] and
  .diagnostic_profiles == [
    "arm64_standard_debug_lockdep_hotplug_faults",
    "x86_64_standard_debug_lockdep_hotplug_faults",
    "arm64_generic_kasan_lockdep",
    "x86_64_kcsan_lockdep"
  ] and
  .passed_cases_per_profile == 55 and .total_passed_cases == 220 and
  .receipts_per_profile == 55 and .total_receipts == 220 and
  .case_failures == 0 and .case_skips == 0 and
  .case_timeouts == 0 and .warning_reports == 0 and
  .warning_classifier_selftest_passed == true and
  .build_clock_skew_retries == 0 and
  .fresh_build_output_per_profile == true and
  .sequential_build_retirement == true and
  .virtual_synthetic_protocol_only == true and
  .profile_results_sha256 ==
    "9142a2a0ff800efbf2e9f5b5231575b6c6c47d26e14ca535265f81221e802b71" and
  (.results | length) == 4 and
  .four_profile_matrix_passed == true and
  .independent_matrix_closure_pending == true and
  .r6_e3_source_accepted == false and
  .r6_e3_correctness_accepted == false and
  .live_scheduler_attachment == false and
  .runtime_behavior_approved == false and
  .production_protection == false and .deployment_ready == false and
  .multi_node_ready == false and .multi_cluster_ready == false and
  .datacenter_ready == false
' "$RESULT" >/dev/null || die 'four-profile result semantics changed'

jq -e '
  .status == "passed_source_gate_awaiting_four_profile_diagnostic_matrix" and
  .candidate_commit ==
    "99287291f1c8e0d6c1b3ea86d121508c5547f424" and
  .deterministic_case_families == 55 and
  .allocation_fault_sites == 3 and
  .stress_repetitions == 4096 and
  .independent_oracle_leaves == 64 and
  .strict_checkpatch == {errors:0,warnings:0,checks:0} and
  .w1_compiler_diagnostics == 0 and
  .diagnostic_matrix_may_start == true and
  .r6_e3_source_accepted == false and
  .r6_e3_correctness_accepted == false and
  .production_protection == false
' "$EVIDENCE_DIR/inputs/source-gate-result.json" >/dev/null ||
	die 'source-gate semantics changed'

jq -e '
  .status == "r6_e3_source_free_pre_source_plan" and
  .configuration.name == "SCHED_EXEC_LEASE_R6_KUNIT_TEST" and
  .configuration.default_enabled == false and
  .configuration.suite == "sched_exec_lease_r6_correctness" and
  (.required_case_families | length) == 55 and
  .race_control.hard_case_timeout_seconds == 15 and
  .race_control.stress_repetitions_per_diagnostic_profile == 4096 and
  .race_control.timing_only_sleep_is_proof == false and
  .race_control.skip_or_expected_failure_allowed == false and
  .build_and_boot_matrix.diagnostic_boots == [
    "arm64_standard_debug_lockdep_hotplug_faults",
    "x86_64_standard_debug_lockdep_hotplug_faults",
    "arm64_generic_kasan_lockdep",
    "x86_64_kcsan_lockdep"
  ] and
  .build_and_boot_matrix.every_case_and_receipt_required == true and
  .build_and_boot_matrix.zero_fail_skip_timeout_or_warning == true and
  .authorization_after_pass.disposable_e3_source_draft_may_start == true and
  .authorization_after_pass.e3_source_or_correctness_accepted == false and
  .authorization_after_pass.e4_plan_or_source_may_start == false and
  .authorization_after_pass.primary_linux_or_patch_queue_change == false
' "$EVIDENCE_DIR/inputs/plan.json" >/dev/null ||
	die 'R6-E3 plan semantics changed'

jq -r '.required_case_families[]' \
	"$EVIDENCE_DIR/inputs/plan.json" > "$OUT_DIR/plan-cases.txt"
diff -u "$EVIDENCE_DIR/expected-cases.txt" "$OUT_DIR/plan-cases.txt" \
	> "$OUT_DIR/plan-vs-cases.diff" ||
	die 'expected case order differs from plan'
jq -R -s 'split("\n") | map(select(length > 0)) | sort' \
	"$OUT_DIR/plan-cases.txt" > "$OUT_DIR/plan-receipt-cases.json"
cmp "$EVIDENCE_DIR/expected-receipt-cases.json" \
	"$OUT_DIR/plan-receipt-cases.json" ||
	die 'expected receipt case set differs from plan'

# The warning classifier snapshot is immutable for the rest of the closure.
# shellcheck disable=SC1091
source "$EVIDENCE_DIR/inputs/kernel-warning-classifier.sh"

progress '30% independently auditing configs, logs, ELF records, and consoles'
: > "$OUT_DIR/compiler-diagnostic-scan.txt"
: > "$OUT_DIR/clock-skew-scan.txt"
: > "$OUT_DIR/kernel-warning-scan.txt"
index=0
while IFS='|' read -r label arch profile child_sha; do
	child="$EVIDENCE_DIR/$label-result.json"
	verify_hash "$child" "$child_sha" "$label child result"
	jq -e --arg label "$label" --arg arch "$arch" --arg profile "$profile" '
	  .schema_version == 1 and .status == "passed" and
	  .boot == $label and .architecture == $arch and
	  .profile == $profile and .cases_passed == 55 and
	  .case_failures == 0 and .case_skips == 0 and
	  .case_timeouts == 0 and .receipts == 55 and
	  .warning_reports == 0 and
	  (.config_sha256 | test("^[0-9a-f]{64}$")) and
	  (.exec_lease_object_sha256 | test("^[0-9a-f]{64}$")) and
	  (.kernel_image_sha256 | test("^[0-9a-f]{64}$")) and
	  (.console_sha256 | test("^[0-9a-f]{64}$")) and
	  (.ktap_sha256 | test("^[0-9a-f]{64}$")) and
	  (.receipts_sha256 | test("^[0-9a-f]{64}$")) and
	  .fresh_build_output == true and
	  .build_output_retired_after_seal == true and
	  .virtual_synthetic_protocol_only == true
	' "$child" >/dev/null || die "$label child result semantics changed"
	jq -e --argjson index "$index" --slurpfile child "$child" \
		'.results[$index] == $child[0]' "$RESULT" >/dev/null ||
		die "$label differs from parent result"
	jq -e --argjson index "$index" --slurpfile child "$child" \
		'.[$index] == $child[0]' "$EVIDENCE_DIR/profile-results.json" \
		>/dev/null || die "$label differs from profile-results"

	verify_recorded_hash "$child" '.config_sha256' \
		"$EVIDENCE_DIR/$label.config" "$label config"
	verify_recorded_hash "$child" '.console_sha256' \
		"$EVIDENCE_DIR/$label-console.log" "$label console"
	verify_recorded_hash "$child" '.ktap_sha256' \
		"$EVIDENCE_DIR/$label-ktap.log" "$label KTAP"
	verify_recorded_hash "$child" '.receipts_sha256' \
		"$EVIDENCE_DIR/$label-receipts.jsonl" "$label receipts"

	if grep -Ehn \
		':[0-9]+(:[0-9]+)?: (fatal )?(warning|error):' \
		"$EVIDENCE_DIR/$label-build.log" \
		>> "$OUT_DIR/compiler-diagnostic-scan.txt"; then
		die "$label compiler diagnostic found"
	fi
	if grep -Eihn \
		'Clock skew detected|modification time .* in the future' \
		"$EVIDENCE_DIR/$label-defconfig.log" \
		"$EVIDENCE_DIR/$label-olddefconfig.log" \
		"$EVIDENCE_DIR/$label-build.log" \
		>> "$OUT_DIR/clock-skew-scan.txt"; then
		die "$label clock skew found"
	fi

	config="$EVIDENCE_DIR/$label.config"
	for required in \
		CONFIG_SCHED_EXEC_LEASE=y \
		CONFIG_SCHED_EXEC_LEASE_LAYOUT_PROBE=y \
		CONFIG_SCHED_EXEC_LEASE_R6_LAYOUT_PROBE=y \
		CONFIG_SCHED_EXEC_LEASE_R6_KUNIT_TEST=y \
		CONFIG_KUNIT=y CONFIG_KUNIT_AUTORUN_ENABLED=y \
		CONFIG_HOTPLUG_CPU=y CONFIG_PROVE_LOCKING=y \
		CONFIG_DEBUG_OBJECTS_WORK=y \
		CONFIG_DEBUG_OBJECTS_RCU_HEAD=y CONFIG_PROVE_RCU=y \
		CONFIG_DEBUG_IRQFLAGS=y CONFIG_WQ_WATCHDOG=y; do
		grep -Fxq "$required" "$config" ||
			die "$label missing $required"
	done
	grep -Fxq '# CONFIG_KUNIT_ALL_TESTS is not set' "$config" ||
		die "$label KUNIT_ALL_TESTS enabled"
	grep -Fxq '# CONFIG_MODULES is not set' "$config" ||
		die "$label modules enabled"
	grep -Fxq "CONFIG_KUNIT_DEFAULT_FILTER_GLOB=\"$SUITE\"" \
		"$config" || die "$label suite filter changed"
	grep -Fxq 'CONFIG_KUNIT_DEFAULT_TIMEOUT=15' "$config" ||
		die "$label KUnit timeout changed"
	case "$profile" in
	standard)
		for required in CONFIG_FAULT_INJECTION=y \
			CONFIG_FAULT_INJECTION_DEBUG_FS=y CONFIG_FAILSLAB=y \
			CONFIG_FAIL_PAGE_ALLOC=y; do
			grep -Fxq "$required" "$config" ||
				die "$label missing $required"
		done
		! grep -Eq '^CONFIG_(KASAN|KCSAN)=(y|m)$' "$config" ||
			die "$label sanitizer unexpectedly enabled"
		;;
	kasan)
		for required in CONFIG_KASAN=y CONFIG_KASAN_GENERIC=y \
			CONFIG_KASAN_INLINE=y; do
			grep -Fxq "$required" "$config" ||
				die "$label missing $required"
		done
		! grep -Eq \
			'^CONFIG_(FAULT_INJECTION|FAILSLAB|FAIL_PAGE_ALLOC|KCSAN)=(y|m)$' \
			"$config" || die "$label incompatible profile option enabled"
		;;
	kcsan)
		grep -Fxq 'CONFIG_KCSAN=y' "$config" ||
			die "$label KCSAN missing"
		grep -Fxq 'CONFIG_KCSAN_STRICT=y' "$config" ||
			die "$label strict KCSAN missing"
		! grep -Eq \
			'^CONFIG_(FAULT_INJECTION|FAILSLAB|FAIL_PAGE_ALLOC|KASAN)=(y|m)$' \
			"$config" || die "$label incompatible profile option enabled"
		;;
	*) die "$label unknown profile" ;;
	esac

	readelf_file="$EVIDENCE_DIR/$label-exec-lease-readelf.txt"
	grep -Fq 'Class:                             ELF64' "$readelf_file" ||
		die "$label object class changed"
	grep -Fq \
		'Data:                              2'"'"'s complement, little endian' \
		"$readelf_file" || die "$label object endian changed"
	grep -Fq 'Type:                              REL (Relocatable file)' \
		"$readelf_file" || die "$label object type changed"
	if [ "$arch" = arm64 ]; then
		grep -Fq 'Machine:                           AArch64' \
			"$readelf_file" || die "$label object architecture changed"
	else
		grep -Fq \
			'Machine:                           Advanced Micro Devices X86-64' \
			"$readelf_file" ||
			die "$label object architecture changed"
	fi

	console="$EVIDENCE_DIR/$label-console.log"
	grep -Fq 'Linux version 7.1.0-14079-g99287291f1c8' "$console" ||
		die "$label candidate kernel identity missing"
	grep -Fq \
		"kunit.filter_glob=$SUITE kunit.timeout=15 kunit_shutdown=poweroff panic=1 oops=panic panic_on_warn=1" \
		"$console" || die "$label kernel command line changed"

	ktap="$EVIDENCE_DIR/$label-ktap.log"
	grep -Fq "# Subtest: $SUITE" "$ktap" ||
		die "$label suite start missing"
	[ "$(grep -Ec \
		"^[[:space:]]*ok [0-9]+( -)? $SUITE([[:space:]]|$)" \
		"$ktap")" = 1 ] || die "$label suite pass cardinality changed"
	! grep -Eq '^[[:space:]]*not ok [0-9]+' "$ktap" ||
		die "$label KTAP failure found"
	! grep -Fq '# SKIP' "$ktap" || die "$label KTAP skip found"
	sed -n -E \
		's/^[[:space:]]*ok [0-9]+( -)? ([a-z0-9_]+).*/\2/p' \
		"$ktap" | grep -v '^sched_exec_' \
		> "$OUT_DIR/$label-cases.txt"
	[ "$(wc -l < "$OUT_DIR/$label-cases.txt" | tr -d ' ')" = \
		"$REQUIRED_CASES" ] ||
		die "$label KTAP case count changed"
	diff -u "$EVIDENCE_DIR/expected-cases.txt" \
		"$OUT_DIR/$label-cases.txt" > "$OUT_DIR/$label-cases.diff" ||
		die "$label KTAP case set/order changed"

	receipts="$EVIDENCE_DIR/$label-receipts.jsonl"
	grep -o 'R6_RECEIPT {.*}' "$console" |
		sed 's/^R6_RECEIPT //' \
		> "$OUT_DIR/$label-console-receipts.jsonl"
	cmp "$receipts" "$OUT_DIR/$label-console-receipts.jsonl" ||
		die "$label console/receipt ledger mismatch"
	[ "$(wc -l < "$receipts" | tr -d ' ')" = \
		"$REQUIRED_RECEIPTS" ] ||
		die "$label receipt count changed"
	while IFS= read -r receipt; do
		printf '%s\n' "$receipt" | jq -e '
		  (.case | type == "string" and length > 0) and
		  (.scenario | type == "number" and . >= 0) and
		  .oracle_leaves == 64 and .cleanup == "drained"
		' >/dev/null || die "$label malformed receipt"
	done < "$receipts"
	jq -s 'map(.case) | sort' "$receipts" \
		> "$OUT_DIR/$label-receipt-cases.json"
	cmp "$EVIDENCE_DIR/expected-receipt-cases.json" \
		"$OUT_DIR/$label-receipt-cases.json" ||
		die "$label receipt case set changed"
	[ "$(jq -s '[.[].case] | unique | length' "$receipts")" = \
		"$REQUIRED_RECEIPTS" ] ||
		die "$label duplicate receipt case"

	capsched_collect_kernel_warning_reports "$console" \
		"$OUT_DIR/$label-warning-reports.txt" ||
		die "$label warning classification failed"
	[ ! -s "$OUT_DIR/$label-warning-reports.txt" ] || {
		cat "$OUT_DIR/$label-warning-reports.txt" \
			>> "$OUT_DIR/kernel-warning-scan.txt"
		die "$label kernel warning report found"
	}
	[ ! -s "$EVIDENCE_DIR/$label-warning-reports.txt" ] ||
		die "$label retained warning report is nonempty"
	index=$((index + 1))
done <<'PROFILE_SPECS'
arm64-standard-debug|arm64|standard|a8f099bd2af42b227409f693c040ebb6d8a9597c55c443de8c0d299257746c09
x86_64-standard-debug|x86_64|standard|f07f3d5be11329c8556072f4eb739ac40ba6f58d23526964607ba22cb00c00c0
arm64-generic-kasan|arm64|kasan|98456b72aabc52c0eca2b539c3423158542dc6aead7c9c5e263f651d2e28007a
x86_64-kcsan|x86_64|kcsan|6a50983beac7ee0cff07549ed406deb3a6a779e3bb6c58992deeee0375205030
PROFILE_SPECS
[ "$index" = 4 ] || die 'profile specification count changed'

progress '75% checking retired build boundary and repository identities'
[ -z "$(find "$EVIDENCE_DIR" -type f \( -name '*.o' -o \
	-name Image -o -name bzImage \) -print -quit)" ] ||
	die 'unexpected build binary retained in evidence'
[ "$(git -C "$PRIMARY_DIR" rev-parse HEAD)" = "$PRIMARY_COMMIT" ] ||
	die 'primary Linux moved'
[ -z "$(git -C "$PRIMARY_DIR" status --porcelain \
	--untracked-files=no)" ] || die 'primary Linux checkout is dirty'
[ "$(git -C "$CANDIDATE_DIR" rev-parse HEAD)" = "$E3_COMMIT" ] ||
	die 'candidate worktree moved'
[ "$(git -C "$CANDIDATE_DIR" rev-parse HEAD^)" = "$E2_COMMIT" ] ||
	die 'candidate parent moved'
[ "$(git -C "$CANDIDATE_DIR" rev-parse HEAD^^)" = \
	"$PRIMARY_COMMIT" ] || die 'E2 parent is not the primary commit'
[ "$(git -C "$CANDIDATE_DIR" rev-parse 'HEAD^{tree}')" = "$E3_TREE" ] ||
	die 'candidate tree moved'
[ "$(git -C "$CANDIDATE_DIR" rev-parse \
	refs/remotes/fork/codex/p5a-r6-e3-correctness-prototype)" = \
	"$E3_COMMIT" ] || die 'fork candidate ref moved'
[ -z "$(git -C "$CANDIDATE_DIR" status --porcelain \
	--untracked-files=no)" ] || die 'candidate worktree is dirty'
git -C "$CANDIDATE_DIR" diff --binary "$E2_COMMIT..$E3_COMMIT" \
	> "$OUT_DIR/recomputed-e3-source.diff"
[ "$(file_sha "$OUT_DIR/recomputed-e3-source.diff")" = "$E3_DIFF_SHA" ] ||
	die 'candidate diff changed'
cmp "$OUT_DIR/recomputed-e3-source.diff" \
	"$EVIDENCE_DIR/e3-source.diff" ||
	die 'retained candidate diff differs from Git'
[ "$(git -C "$CANDIDATE_DIR" diff --name-only \
	"$E2_COMMIT..$E3_COMMIT" | sort | tr '\n' ' ')" = \
	'init/Kconfig kernel/sched/exec_lease.c ' ] ||
	die 'candidate escaped exact two-file boundary'
[ "$(git -C "$PATCH_QUEUE_DIR" rev-parse HEAD)" = \
	"$PATCH_QUEUE_COMMIT" ] || die 'patch queue moved'
[ -z "$(git -C "$PATCH_QUEUE_DIR" status --porcelain)" ] ||
	die 'patch queue is dirty'
[ ! -e \
	"/var/tmp/linux-cap-builds/p5a-r6-e3-four-profile/$SOURCE_RUN_ID" ] ||
	die 'run-owned kernel build scratch leaked'

progress '90% rechecking immutable evidence and sealing R6-E3 claim boundary'
[ "$(file_sha "$RUNNER_SOURCE")" = "$runner_initial_sha" ] ||
	die 'closure runner changed during audit'
[ "$(file_sha "$INPUT_DIR/closure-runner.sh")" = \
	"$runner_initial_sha" ] || die 'closure runner snapshot changed'
tree_manifest "$SOURCE_DIR" > "$OUT_DIR/source-artifacts-final.sha256"
diff -u "$OUT_DIR/source-artifacts-before.sha256" \
	"$OUT_DIR/source-artifacts-final.sha256" \
	> "$OUT_DIR/source-artifacts-final.diff" ||
	die 'source evidence changed during closure'
[ -z "$(find "$SOURCE_DIR" -type l -print -quit)" ] ||
	die 'source evidence gained a symlink during closure'
[ -z "$(find "$SOURCE_DIR" ! -type f ! -type d -print -quit)" ] ||
	die 'source evidence gained a non-regular object during closure'
[ "$(find "$SOURCE_DIR" -type f | wc -l | tr -d ' ')" = \
	"$SOURCE_ARTIFACT_COUNT" ] ||
	die 'source artifact count changed during closure'
final_source_bytes=$(find "$SOURCE_DIR" -type f -printf '%s\n' |
	awk '{sum += $1} END {printf "%.0f\n", sum}')
[ "$final_source_bytes" = "$SOURCE_ARTIFACT_BYTES" ] ||
	die "source artifact byte count changed during closure: $final_source_bytes"
snapshot_manifest_sha=$(file_sha "$OUT_DIR/snapshot-artifacts.sha256")
[ "$snapshot_manifest_sha" = "$SOURCE_ARTIFACT_MANIFEST_SHA" ] ||
	die 'snapshot manifest seal changed'

jq -n \
	--arg run_id "$RUN_ID" --arg source_run_id "$SOURCE_RUN_ID" \
	--arg source_result_sha "$SOURCE_RESULT_SHA" \
	--arg profile_results_sha "$PROFILE_RESULTS_SHA" \
	--arg source_manifest_sha "$SOURCE_ARTIFACT_MANIFEST_SHA" \
	--arg closure_runner_sha "$runner_initial_sha" \
	--arg warning_classifier_sha "$WARNING_CLASSIFIER_SHA" \
	--arg candidate "$E3_COMMIT" --arg parent "$E2_COMMIT" \
	--arg tree "$E3_TREE" --arg diff_sha "$E3_DIFF_SHA" \
	--argjson artifact_count "$SOURCE_ARTIFACT_COUNT" \
	--argjson artifact_bytes "$SOURCE_ARTIFACT_BYTES" \
	'{schema_version:1,
	  id:"sched-exec-lease-p5a-r6-e3-four-profile-evidence-closure-result-v1",
	  run_id:$run_id,
	  status:"passed_independent_four_profile_evidence_closure",
	  source_run_id:$source_run_id,
	  source_result_sha256:$source_result_sha,
	  profile_results_sha256:$profile_results_sha,
	  source_artifact_manifest_sha256:$source_manifest_sha,
	  source_artifact_count:$artifact_count,
	  source_artifact_bytes:$artifact_bytes,
	  closure_runner_sha256:$closure_runner_sha,
	  kernel_warning_classifier_sha256:$warning_classifier_sha,
	  all_source_artifacts_snapshotted_read_only:true,
	  source_artifact_race_check_passed:true,
	  candidate_commit:$candidate,candidate_parent:$parent,
	  candidate_tree:$tree,candidate_diff_sha256:$diff_sha,
	  architectures:["arm64","x86_64"],
	  diagnostic_profiles:["standard","standard","kasan","kcsan"],
	  fresh_builds_recorded:4,qemu_boots_audited:4,configs_audited:4,
	  build_logs_audited:4,retained_exec_lease_elf_headers_audited:4,
	  retired_exec_lease_objects_hash_records_audited:4,
	  retired_kernel_image_hash_records_audited:4,
	  retired_kernel_images_or_objects_claimed_as_retained:false,
	  ktap_suites_passed:4,cases_passed_per_profile:55,
	  total_cases_passed:220,receipt_ledgers_audited:4,
	  receipts_per_profile:55,total_receipts:220,
	  stress_repetitions_per_profile:4096,
	  oracle_leaves_per_receipt:64,
	  compiler_diagnostics:0,clock_skew_warnings:0,
	  kernel_warning_reports:0,case_failures:0,case_skips:0,
	  case_timeouts:0,build_output_retirement_verified:true,
	  four_profile_matrix_passed:true,
	  independent_artifact_closure_passed:true,
	  virtual_synthetic_protocol_evidence_complete:true,
	  r6_e3_diagnostic_evidence_complete:true,
	  r6_e3_source_accepted:false,r6_e3_correctness_accepted:false,
	  e4_plan_or_source_may_start:false,
	  primary_linux_may_change:false,patch_queue_may_change:false,
	  live_scheduler_attachment:false,runtime_behavior_approved:false,
	  runtime_denial_correctness:false,monitor_delivery_or_enforcement:false,
	  bounded_wall_clock_latency_claim:false,performance_claim:false,
	  bare_metal_validated:false,production_protection:false,
	  deployment_ready:false,multi_node_ready:false,
	  multi_cluster_ready:false,datacenter_ready:false}' \
	> "$OUT_DIR/result.json.pending"
jq -e '
  .status == "passed_independent_four_profile_evidence_closure" and
  .source_artifact_count == 60 and
  .source_artifact_bytes == 2659341 and
  .fresh_builds_recorded == 4 and .qemu_boots_audited == 4 and
  .configs_audited == 4 and .total_cases_passed == 220 and
  .total_receipts == 220 and .compiler_diagnostics == 0 and
  .clock_skew_warnings == 0 and .kernel_warning_reports == 0 and
  .case_failures == 0 and .case_skips == 0 and
  .case_timeouts == 0 and
  .independent_artifact_closure_passed == true and
  .virtual_synthetic_protocol_evidence_complete == true and
  .r6_e3_diagnostic_evidence_complete == true and
  .r6_e3_source_accepted == false and
  .r6_e3_correctness_accepted == false and
  .e4_plan_or_source_may_start == false and
  .production_protection == false and .datacenter_ready == false
' "$OUT_DIR/result.json.pending" >/dev/null
mv "$OUT_DIR/result.json.pending" "$OUT_DIR/result.json"
jq -S 'del(.run_id)' "$OUT_DIR/result.json" \
	> "$OUT_DIR/result.normalized.json"
sha256sum "$OUT_DIR/result.normalized.json" \
	> "$OUT_DIR/result.normalized.sha256"
sha256sum "$OUT_DIR/result.json" > "$OUT_DIR/result.sha256"
chmod -R a-w "$INPUT_DIR"
progress '100% independent four-profile evidence closure passed'
printf 'result=%s\n' "$OUT_DIR/result.json"
printf 'sha256=%s\n' "$(awk '{print $1}' "$OUT_DIR/result.sha256")"
printf 'normalized_sha256=%s\n' \
	"$(awk '{print $1}' "$OUT_DIR/result.normalized.sha256")"
