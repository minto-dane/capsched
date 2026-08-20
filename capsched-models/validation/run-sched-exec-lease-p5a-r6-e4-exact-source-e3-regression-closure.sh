#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
PATCH_QUEUE_DIR="$WORKSPACE_DIR/linux-patches"
SOURCE_RUN_ID=20260730T-p5a-r6-e4-e3-regression-r1
CANONICAL_SOURCE_DIR="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r6-e4-exact-source-e3-regression/$SOURCE_RUN_ID"
RUNNER_SOURCE=${BASH_SOURCE[0]}
RUN_ID=${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
PROGRESS_FILE=${PROGRESS_FILE:-}
CLOSURE_TEST_MODE=${CLOSURE_TEST_MODE:-0}
PREFLIGHT_ONLY=${PREFLIGHT_ONLY:-0}
OFFLINE_TEST_MODE=${OFFLINE_TEST_MODE:-0}
SOURCE_DIR_OVERRIDE=${SOURCE_DIR_OVERRIDE:-}

SOURCE_RESULT_SHA=d4644979f3c2d186a60b21fe77e5db3fd63b9ce9b7612e971043b1adfea89f3d
PROFILE_RESULTS_SHA=0acd6dc6ae7130c58c099fe36ff94cb5ffc308c9fa01b3b5ec323a58a19bd660
SOURCE_ARTIFACT_MANIFEST_SHA=f11d08d0a4783056a27fb79a3636add0cbd1ce98871d3ee2c688cfb226b3e681
SOURCE_ARTIFACT_COUNT=72
SOURCE_ARTIFACT_BYTES=2942131
SOURCE_RUNNER_SHA=670c314a6e66bcb6e88176765920f97ba9c9807a13ffbb98e2bf6a6bcc613364
CONTRACT_SHA=ade8e74b7f7488e49a0a656b379ed5179e77509dcc68b7c7f6cac014d07dbd30
PLAN_SHA=36f5d2b0423d1a4f6de05e08ac4166e098bb7e7680ce81758b361187dc0e8d22
SOURCE_GATE_SHA=ab5b33650dafb275ffc281ca7f0828aa3db11d8ca301f82c06980399bc3404e6
HARDENING_LIB_SHA=4548753bc2acaa7497aef9e9ff070d9952f9b5ee20631c6116590067eab9ccc6
WARNING_CLASSIFIER_SHA=8adcff74f0395f5ec219343c0cb5b1f179efee2292ab853d4fc7e410467dc23a
CANDIDATE_COMMIT=d51ebdc657a1040e423735584775e66399f321f9
CANDIDATE_PARENT=99287291f1c8e0d6c1b3ea86d121508c5547f424
CANDIDATE_TREE=0847c408be82e6c9077c2edd2d00f44ccfbe18fc
CANDIDATE_DIFF_SHA=fcc00bcf8dabf4ee8d921a454b7ee871e907da5accefaab10f320f08ff4283d9
CANDIDATE_SOURCE_SHA=688248428ca550bc1c56e8547fa5f601a46f5e031222b89c715be72150a4ab3c
CANDIDATE_REMOTE=https://github.com/minto-dane/linux.git
CANDIDATE_REF=refs/heads/codex/p5a-r6-e4-local-quantum-measurement
PATCH_QUEUE_COMMIT=16bb080da472ffabbbafd2698073eca633fb0602
PATCH_QUEUE_REF=refs/heads/codex/replay-clone-portability
SUITE=sched_exec_lease_r6_correctness
MEASUREMENT_CONFIG=CONFIG_SCHED_EXEC_LEASE_R6_MEASURE_KUNIT_TEST
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
case "$CLOSURE_TEST_MODE:$PREFLIGHT_ONLY:$OFFLINE_TEST_MODE" in
	0:0:0|1:1:1) ;;
	*) die 'invalid closure mode' ;;
esac

if [ "$CLOSURE_TEST_MODE" = 1 ]; then
	[ -n "$SOURCE_DIR_OVERRIDE" ] ||
		die 'test mode requires SOURCE_DIR_OVERRIDE'
	SOURCE_DIR=$SOURCE_DIR_OVERRIDE
	OUT_ROOT="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r6-e4-exact-source-e3-regression-closure-test"
else
	[ -z "$SOURCE_DIR_OVERRIDE" ] ||
		die 'SOURCE_DIR_OVERRIDE is test-only'
	SOURCE_DIR=$CANONICAL_SOURCE_DIR
	OUT_ROOT="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r6-e4-exact-source-e3-regression-closure"
fi
OUT_DIR="$OUT_ROOT/$RUN_ID"
INPUT_DIR="$OUT_DIR/inputs"
EVIDENCE_DIR="$INPUT_DIR/exact-source-e3-regression-evidence"
GIT_AUDIT_DIR="$OUT_DIR/candidate-git-audit"

for command_name in awk chmod cmp cp diff find git grep jq mkdir mv sed \
	sha256sum sort stat tr wc xargs; do
	command -v "$command_name" >/dev/null 2>&1 ||
		die "missing command: $command_name"
done
[ -d "$SOURCE_DIR" ] || die 'exact-source E3 evidence directory missing'
[ ! -L "$SOURCE_DIR" ] || die 'evidence root is a symlink'
[ -z "$(find "$SOURCE_DIR" -type l -print -quit)" ] ||
	die 'evidence contains a symlink'
[ -z "$(find "$SOURCE_DIR" ! -type f ! -type d -print -quit)" ] ||
	die 'evidence contains a non-regular object'
[ "$(find "$SOURCE_DIR" -type f | wc -l | tr -d ' ')" = \
	"$SOURCE_ARTIFACT_COUNT" ] || die 'source artifact count changed'
source_bytes=$(find "$SOURCE_DIR" -type f -printf '%s\n' |
	awk '{sum += $1} END {printf "%.0f\n", sum}')
[ "$source_bytes" = "$SOURCE_ARTIFACT_BYTES" ] ||
	die "source artifact byte count changed: $source_bytes"
if [ -e "$OUT_DIR" ] || [ -L "$OUT_DIR" ]; then
	die "run output already exists: $OUT_DIR"
fi

mkdir -p "$OUT_ROOT"
mkdir "$OUT_DIR" "$INPUT_DIR" "$EVIDENCE_DIR"
chmod 0700 "$OUT_DIR" "$INPUT_DIR"
runner_initial_sha=$(file_sha "$RUNNER_SOURCE")
cp -- "$RUNNER_SOURCE" "$INPUT_DIR/closure-runner.sh"
chmod 0444 "$INPUT_DIR/closure-runner.sh"

progress '5% snapshotting and race-checking all 72 retained artifacts'
tree_manifest "$SOURCE_DIR" > "$OUT_DIR/source-artifacts-before.sha256"
[ "$(file_sha "$OUT_DIR/source-artifacts-before.sha256")" = \
	"$SOURCE_ARTIFACT_MANIFEST_SHA" ] || die 'canonical manifest changed'
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
	die 'snapshot differs from source evidence'
chmod -R a-w "$EVIDENCE_DIR"

RESULT="$EVIDENCE_DIR/result.json"
verify_hash "$RESULT" "$SOURCE_RESULT_SHA" 'regression result'
[ "$(awk '{print $1}' "$EVIDENCE_DIR/result.sha256")" = \
	"$SOURCE_RESULT_SHA" ] || die 'regression result seal changed'
verify_hash "$EVIDENCE_DIR/profile-results.json" "$PROFILE_RESULTS_SHA" \
	'profile-results array'

if [ "$CLOSURE_TEST_MODE" = 1 ]; then
	progress '100% closure fixture passed; no authoritative result published'
	exit 0
fi

progress '15% validating immutable inputs and regression claim boundary'
verify_hash "$EVIDENCE_DIR/inputs/runner.sh" "$SOURCE_RUNNER_SHA" \
	'regression runner snapshot'
verify_hash "$EVIDENCE_DIR/inputs/contract.json" "$CONTRACT_SHA" \
	'regression contract snapshot'
verify_hash "$EVIDENCE_DIR/inputs/e3-plan.json" "$PLAN_SHA" \
	'R6-E3 plan snapshot'
verify_hash "$EVIDENCE_DIR/inputs/source-gate-result.json" \
	"$SOURCE_GATE_SHA" 'R6-E4 source-gate snapshot'
verify_hash "$EVIDENCE_DIR/inputs/immutable-evidence-inputs.sh" \
	"$HARDENING_LIB_SHA" 'immutable-input helper snapshot'
verify_hash "$EVIDENCE_DIR/inputs/kernel-warning-classifier.sh" \
	"$WARNING_CLASSIFIER_SHA" 'warning-classifier snapshot'
verify_hash "$EVIDENCE_DIR/candidate.diff" "$CANDIDATE_DIFF_SHA" \
	'retained candidate diff'
verify_hash "$EVIDENCE_DIR/exec_lease.c" "$CANDIDATE_SOURCE_SHA" \
	'retained candidate source'
verify_hash "$EVIDENCE_DIR/expected-cases.txt" \
	b8e84a49adc790275612194237c764397002eb3005cd6460aba0410424c45a03 \
	'expected case order'
verify_hash "$EVIDENCE_DIR/expected-receipt-cases.json" \
	0eaf1ea5052209e541b21907af45be084435c61da36b8c01e3608d0803fb7c96 \
	'expected receipt set'

jq -e '
  .schema_version == 1 and
  .id ==
    "sched-exec-lease-p5a-r6-e4-exact-source-e3-regression-result-v1" and
  .run_id == "20260730T-p5a-r6-e4-e3-regression-r1" and
  .status ==
    "passed_exact_source_e3_regression_awaiting_independent_closure" and
  .candidate_commit ==
    "d51ebdc657a1040e423735584775e66399f321f9" and
  .candidate_parent ==
    "99287291f1c8e0d6c1b3ea86d121508c5547f424" and
  .candidate_tree ==
    "0847c408be82e6c9077c2edd2d00f44ccfbe18fc" and
  .candidate_diff_sha256 ==
    "fcc00bcf8dabf4ee8d921a454b7ee871e907da5accefaab10f320f08ff4283d9" and
  .source_gate_sha256 ==
    "ab5b33650dafb275ffc281ca7f0828aa3db11d8ca301f82c06980399bc3404e6" and
  .contract_sha256 ==
    "ade8e74b7f7488e49a0a656b379ed5179e77509dcc68b7c7f6cac014d07dbd30" and
  .plan_sha256 ==
    "36f5d2b0423d1a4f6de05e08ac4166e098bb7e7680ce81758b361187dc0e8d22" and
  .runner_sha256 ==
    "670c314a6e66bcb6e88176765920f97ba9c9807a13ffbb98e2bf6a6bcc613364" and
  .architectures == ["arm64","x86_64"] and
  .passed_cases_per_profile == 55 and .total_passed_cases == 220 and
  .receipts_per_profile == 55 and .total_receipts == 220 and
  .case_failures == 0 and .case_skips == 0 and
  .case_timeouts == 0 and .warning_reports == 0 and
  .measurement_config_enabled == false and
  .disabled_measurement_artifacts == 0 and
  .warning_classifier_selftest_passed == true and
  .build_clock_skew_retries == 0 and
  .fresh_build_output_per_profile == true and
  .sequential_build_retirement == true and
  .virtual_synthetic_protocol_only == true and
  .profile_results_sha256 ==
    "0acd6dc6ae7130c58c099fe36ff94cb5ffc308c9fa01b3b5ec323a58a19bd660" and
  (.results | length) == 4 and
  .e3_regression_passed_for_e4_source == true and
  .independent_matrix_closure_pending == true and
  .independent_closure_passed == false and
  .r6_e4_source_accepted == false and
  .measurement_authorized == false and
  .live_scheduler_attachment == false and
  .runtime_behavior_approved == false and
  .production_protection == false and .deployment_ready == false and
  .multi_node_ready == false and .multi_cluster_ready == false and
  .datacenter_ready == false
' "$RESULT" >/dev/null || die 'regression result semantics changed'

jq -e '
  .id == "sched-exec-lease-p5a-r6-e4-exact-source-e3-regression-v1" and
  .candidate.commit ==
    "d51ebdc657a1040e423735584775e66399f321f9" and
  .regression.measurement_must_be_disabled == true and
  .regression.cases_per_profile == 55 and
  .regression.receipts_per_profile == 55 and
  (.regression.profiles | length) == 4 and
  .regression.independent_read_only_closure_required == true and
  ([.claims[]] | all(. == false))
' "$EVIDENCE_DIR/inputs/contract.json" >/dev/null ||
	die 'regression contract semantics changed'
jq -e '
  .status == "passed_r6_e4_source_build_gate" and
  .candidate_commit ==
    "d51ebdc657a1040e423735584775e66399f321f9" and
  .e3_shared_helpers_changed == true and
  .e3_four_profile_regression_required == true and
  .e3_four_profile_regression_passed == false and
  .r6_e4_source_accepted == false and
  .measurement_authorized == false
' "$EVIDENCE_DIR/inputs/source-gate-result.json" >/dev/null ||
	die 'source-gate semantics changed'

# The warning classifier is sourced only from the sealed evidence snapshot.
# shellcheck disable=SC1091
source "$EVIDENCE_DIR/inputs/kernel-warning-classifier.sh"

progress '30% independently auditing four configs, builds, boots, and ledgers'
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
      .warning_reports == 0 and .measurement_config_enabled == false and
      .disabled_measurement_artifacts == 0 and
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
	for required in CONFIG_SCHED_EXEC_LEASE=y \
		CONFIG_SCHED_EXEC_LEASE_LAYOUT_PROBE=y \
		CONFIG_SCHED_EXEC_LEASE_R6_LAYOUT_PROBE=y \
		CONFIG_SCHED_EXEC_LEASE_R6_KUNIT_TEST=y \
		CONFIG_KUNIT=y CONFIG_KUNIT_AUTORUN_ENABLED=y \
		CONFIG_HOTPLUG_CPU=y CONFIG_PROVE_LOCKING=y \
		CONFIG_DEBUG_OBJECTS_WORK=y CONFIG_DEBUG_OBJECTS_RCU_HEAD=y \
		CONFIG_PROVE_RCU=y CONFIG_DEBUG_IRQFLAGS=y \
		CONFIG_WQ_WATCHDOG=y; do
		grep -Fxq "$required" "$config" ||
			die "$label missing $required"
	done
	grep -Fxq "# $MEASUREMENT_CONFIG is not set" "$config" ||
		die "$label enabled R6-E4 measurement"
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
	grep -Fq 'Type:                              REL (Relocatable file)' \
		"$readelf_file" || die "$label object type changed"
	if [ "$arch" = arm64 ]; then
		grep -Fq 'Machine:                           AArch64' \
			"$readelf_file" || die "$label object architecture changed"
	else
		grep -Fq \
			'Machine:                           Advanced Micro Devices X86-64' \
			"$readelf_file" || die "$label object architecture changed"
	fi
	for pattern in sched_exec_r6_measure_ sched_exec_lease_r6_measure \
		R6_E4_RAW R6_E4_RESULT R6_E4_SUMMARY; do
		! grep -Fq "$pattern" "$EVIDENCE_DIR/$label-exec-lease-nm.txt" ||
			die "$label disabled E4 symbol retained"
		! grep -Fq "$pattern" \
			"$EVIDENCE_DIR/$label-exec-lease-strings.txt" ||
			die "$label disabled E4 string retained"
	done

	console="$EVIDENCE_DIR/$label-console.log"
	grep -Fq 'Linux version 7.1.0-14080-gd51ebdc657a1' "$console" ||
		die "$label candidate kernel identity missing"
	grep -Fq \
		"kunit.filter_glob=$SUITE kunit.timeout=15 kunit_shutdown=poweroff panic=1 oops=panic panic_on_warn=1" \
		"$console" || die "$label kernel command line changed"
	! grep -Fq 'R6_E4_' "$console" ||
		die "$label emitted disabled measurement output"

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
		"$REQUIRED_CASES" ] || die "$label KTAP case count changed"
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
		"$REQUIRED_RECEIPTS" ] || die "$label receipt count changed"
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
		"$REQUIRED_RECEIPTS" ] || die "$label duplicate receipt case"

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
arm64-standard-debug|arm64|standard|834e066d630b9592d9302fcf45dfcb0a369cccef443631daf05f9df00e9e29b8
x86_64-standard-debug|x86_64|standard|27c7ad6d90958eba7e0ccaaa33e6638596d5dc47c28387deab7731f6b4b0007d
arm64-generic-kasan|arm64|kasan|a92b1bd8c71748c3453b96d352bc6d81df16034e728532cee475e9524cd97f34
x86_64-kcsan|x86_64|kcsan|4cc6f93e757df816b4dbab3d59bd59194d3a71149302f46863509035a079da1f
PROFILE_SPECS
[ "$index" = 4 ] || die 'profile specification count changed'

progress '75% reconstructing candidate identity from pushed GitHub branch'
git init -q "$GIT_AUDIT_DIR"
git -C "$GIT_AUDIT_DIR" remote add origin "$CANDIDATE_REMOTE"
git -C "$GIT_AUDIT_DIR" fetch --quiet --no-tags --depth=2 \
	--filter=blob:none origin "$CANDIDATE_REF"
[ "$(git -C "$GIT_AUDIT_DIR" rev-parse FETCH_HEAD)" = \
	"$CANDIDATE_COMMIT" ] || die 'pushed candidate branch moved'
[ "$(git -C "$GIT_AUDIT_DIR" rev-parse FETCH_HEAD^)" = \
	"$CANDIDATE_PARENT" ] || die 'pushed candidate parent moved'
[ "$(git -C "$GIT_AUDIT_DIR" rev-parse 'FETCH_HEAD^{tree}')" = \
	"$CANDIDATE_TREE" ] || die 'pushed candidate tree moved'
git -C "$GIT_AUDIT_DIR" diff --abbrev=12 --binary \
	"$CANDIDATE_PARENT..$CANDIDATE_COMMIT" -- \
	init/Kconfig kernel/sched/exec_lease.c \
	> "$OUT_DIR/recomputed-candidate.diff"
[ "$(file_sha "$OUT_DIR/recomputed-candidate.diff")" = \
	"$CANDIDATE_DIFF_SHA" ] || die 'pushed candidate diff changed'
cmp "$OUT_DIR/recomputed-candidate.diff" "$EVIDENCE_DIR/candidate.diff" ||
	die 'retained candidate diff differs from pushed Git'
git -C "$GIT_AUDIT_DIR" show \
	"$CANDIDATE_COMMIT:kernel/sched/exec_lease.c" \
	> "$OUT_DIR/recomputed-exec_lease.c"
[ "$(file_sha "$OUT_DIR/recomputed-exec_lease.c")" = \
	"$CANDIDATE_SOURCE_SHA" ] || die 'pushed candidate source changed'
cmp "$OUT_DIR/recomputed-exec_lease.c" "$EVIDENCE_DIR/exec_lease.c" ||
	die 'retained source differs from pushed Git'
git -C "$GIT_AUDIT_DIR" diff --name-only \
	"$CANDIDATE_PARENT..$CANDIDATE_COMMIT" | sort \
	> "$OUT_DIR/recomputed-changed-files.txt"
cmp "$OUT_DIR/recomputed-changed-files.txt" \
	"$EVIDENCE_DIR/expected-files.txt" ||
	die 'pushed candidate escaped exact two-file boundary'
rm -rf -- "$GIT_AUDIT_DIR"

[ "$(git -C "$PATCH_QUEUE_DIR" rev-parse HEAD)" = \
	"$PATCH_QUEUE_COMMIT" ] || die 'patch queue moved'
[ -z "$(git -C "$PATCH_QUEUE_DIR" status --porcelain)" ] ||
	die 'patch queue is dirty'
remote_patch=$(git -C "$PATCH_QUEUE_DIR" ls-remote origin \
	"$PATCH_QUEUE_REF" | awk 'NR == 1 {print $1}')
[ "$remote_patch" = "$PATCH_QUEUE_COMMIT" ] ||
	die 'pushed patch queue moved'
[ ! -e "/var/tmp/linux-cap-builds/p5a-r6-e4-exact-source-e3-regression/$SOURCE_RUN_ID" ] ||
	die 'run-owned build scratch leaked'

progress '90% rechecking immutable evidence and sealing closure result'
[ "$(file_sha "$RUNNER_SOURCE")" = "$runner_initial_sha" ] ||
	die 'closure runner changed during audit'
[ "$(file_sha "$INPUT_DIR/closure-runner.sh")" = \
	"$runner_initial_sha" ] || die 'closure runner snapshot changed'
tree_manifest "$SOURCE_DIR" > "$OUT_DIR/source-artifacts-final.sha256"
diff -u "$OUT_DIR/source-artifacts-before.sha256" \
	"$OUT_DIR/source-artifacts-final.sha256" \
	> "$OUT_DIR/source-artifacts-final.diff" ||
	die 'source evidence changed during closure'
[ "$(find "$SOURCE_DIR" -type f | wc -l | tr -d ' ')" = \
	"$SOURCE_ARTIFACT_COUNT" ] ||
	die 'source artifact count changed during closure'
final_source_bytes=$(find "$SOURCE_DIR" -type f -printf '%s\n' |
	awk '{sum += $1} END {printf "%.0f\n", sum}')
[ "$final_source_bytes" = "$SOURCE_ARTIFACT_BYTES" ] ||
	die 'source artifact bytes changed during closure'

jq -n --arg run_id "$RUN_ID" --arg source_run_id "$SOURCE_RUN_ID" \
	--arg source_result_sha "$SOURCE_RESULT_SHA" \
	--arg profile_results_sha "$PROFILE_RESULTS_SHA" \
	--arg source_manifest_sha "$SOURCE_ARTIFACT_MANIFEST_SHA" \
	--arg closure_runner_sha "$runner_initial_sha" \
	--arg candidate "$CANDIDATE_COMMIT" --arg parent "$CANDIDATE_PARENT" \
	--arg tree "$CANDIDATE_TREE" --arg diff_sha "$CANDIDATE_DIFF_SHA" \
	--argjson artifact_count "$SOURCE_ARTIFACT_COUNT" \
	--argjson artifact_bytes "$SOURCE_ARTIFACT_BYTES" \
	'{schema_version:1,
      id:"sched-exec-lease-p5a-r6-e4-exact-source-e3-regression-closure-result-v1",
      run_id:$run_id,
      status:"passed_independent_exact_source_e3_regression_closure",
      source_run_id:$source_run_id,source_result_sha256:$source_result_sha,
      profile_results_sha256:$profile_results_sha,
      source_artifact_manifest_sha256:$source_manifest_sha,
      source_artifact_count:$artifact_count,
      source_artifact_bytes:$artifact_bytes,
      closure_runner_sha256:$closure_runner_sha,
      all_source_artifacts_snapshotted_read_only:true,
      source_artifact_race_check_passed:true,
      candidate_commit:$candidate,candidate_parent:$parent,
      candidate_tree:$tree,candidate_diff_sha256:$diff_sha,
      pushed_candidate_reconstructed:true,
      architectures:["arm64","x86_64"],
      diagnostic_profiles:["standard","standard","kasan","kcsan"],
      fresh_builds_recorded:4,qemu_boots_audited:4,configs_audited:4,
      build_logs_audited:4,elf_records_audited:4,
      disabled_measurement_symbol_scans_audited:4,
      disabled_measurement_string_scans_audited:4,
      ktap_suites_passed:4,cases_passed_per_profile:55,
      total_cases_passed:220,receipt_ledgers_audited:4,
      receipts_per_profile:55,total_receipts:220,
      compiler_diagnostics:0,clock_skew_warnings:0,
      kernel_warning_reports:0,case_failures:0,case_skips:0,
      case_timeouts:0,measurement_config_enabled:false,
      disabled_measurement_artifacts:0,
      build_output_retirement_verified:true,
      exact_source_e3_regression_passed:true,
      independent_artifact_closure_passed:true,
      e3_regression_evidence_complete_for_e4_source:true,
      post_regression_authorization_required:true,
      r6_e4_source_accepted:false,measurement_authorized:false,
      live_scheduler_attachment:false,runtime_behavior_approved:false,
      runtime_denial_correctness:false,monitor_verified:false,
      bare_metal_validated:false,performance_claim:false,cost_claim:false,
      production_protection:false,deployment_ready:false,
      multi_node_ready:false,multi_cluster_ready:false,
      datacenter_ready:false}' > "$OUT_DIR/result.json.pending"
jq -e '
  .status == "passed_independent_exact_source_e3_regression_closure" and
  .source_artifact_count == 72 and .source_artifact_bytes == 2942131 and
  .fresh_builds_recorded == 4 and .qemu_boots_audited == 4 and
  .configs_audited == 4 and .total_cases_passed == 220 and
  .total_receipts == 220 and .compiler_diagnostics == 0 and
  .clock_skew_warnings == 0 and .kernel_warning_reports == 0 and
  .case_failures == 0 and .case_skips == 0 and
  .case_timeouts == 0 and .measurement_config_enabled == false and
  .disabled_measurement_artifacts == 0 and
  .pushed_candidate_reconstructed == true and
  .independent_artifact_closure_passed == true and
  .e3_regression_evidence_complete_for_e4_source == true and
  .post_regression_authorization_required == true and
  .r6_e4_source_accepted == false and
  .measurement_authorized == false and
  .production_protection == false and .datacenter_ready == false
' "$OUT_DIR/result.json.pending" >/dev/null
mv "$OUT_DIR/result.json.pending" "$OUT_DIR/result.json"
jq -S 'del(.run_id)' "$OUT_DIR/result.json" \
	> "$OUT_DIR/result.normalized.json"
sha256sum "$OUT_DIR/result.normalized.json" \
	> "$OUT_DIR/result.normalized.sha256"
sha256sum "$OUT_DIR/result.json" > "$OUT_DIR/result.sha256"
chmod -R a-w "$OUT_DIR"
progress '100% independent exact-source E3 regression closure passed'
printf 'result=%s\n' "$OUT_DIR/result.json"
printf 'sha256=%s\n' "$(awk '{print $1}' "$OUT_DIR/result.sha256")"
printf 'normalized_sha256=%s\n' \
	"$(awk '{print $1}' "$OUT_DIR/result.normalized.sha256")"
