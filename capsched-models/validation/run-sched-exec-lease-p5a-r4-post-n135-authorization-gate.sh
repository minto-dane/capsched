#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
PRIMARY_DIR="$WORKSPACE_DIR/linux"
PATCH_QUEUE_DIR="$WORKSPACE_DIR/linux-patches"
CANONICAL_CONFIG="$CAPSCHED_DIR/capsched-models/analysis/sched-exec-lease-p5a-r4-post-n135-authorization-gate-v1.json"
MODEL_DIR="$CAPSCHED_DIR/capsched-models/formal/0138-p5a-r4-post-n135-authorization-gate-model"
MODEL=P5AR4PostN135AuthorizationGate.tla
SAFE_CFG=P5AR4PostN135AuthorizationGateSafe.cfg
TLA_JAR=${TLA_JAR:-"$WORKSPACE_DIR/build/tools/tla/tla2tools.jar"}
RUN_ID=${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
PROGRESS_FILE=${PROGRESS_FILE:-}
AUTH_GATE_TEST_MODE=${AUTH_GATE_TEST_MODE:-0}
CONFIG_OVERRIDE=${CONFIG_OVERRIDE:-}
OFFLINE_TEST_MODE=${OFFLINE_TEST_MODE:-0}
TEST_CONFIG_SHA=${TEST_CONFIG_SHA:-}

CONFIG_SHA=99d055aa02429c510f564fd02bb8f864f42a0603fc7e0a73e09fc13fc9532203
PLAN_SHA=f9c9103b4eae2177309dd8e0134601fe3cf1eb08061986265627dcd9d8fd6677
IMPLEMENTATION_SHA=fe4add9b420870c21dca423c15f7505f1cfdc9c9360fac75605882856a782b86
CLAIM_LEDGER_SHA=d957db92654459c9298d252bdae0a92ef7de5b85918c24bcf4cc083c324e5adb
N135_VALIDATION_SHA=9c5794f123269beb71483298ed78711425868b5d9deec969ba637e7deba6390a
MATRIX_SHA=4717052e2f546cf5faa13bfd24d90e43626e9b66f4f6d24ad07b2ed5bc7fbedd
CLOSURE_R1_SHA=6d9a54ed85d742d77aeef98f53deab2634ead63d41ef1c551ca6720b4a098f89
CLOSURE_R2_SHA=86fd0cf06ddbcfd7fd88210eec196cec1650d31ca929791bf9e3bc7e7cfb26ea
CLOSURE_NORMALIZED_SHA=239bafaa191598443a2d004bd68edd949c3030849d79a5ad756a670980607e8f
RUNTIME_CHARGE_SHA=d1dff5ebb6721575bf0c26c60d913eb5a9a5d95c179fba71969e3b7cb2d11065
RUNTIME_VALIDATION_SHA=be3e6159da5cccdd5996bb5d434f81e492aae37963d4af8f193d541e58de1f38
PRIMARY_COMMIT=5e1ca3037e34823d1ba0cdd1dc04161fac170280
PATCH_QUEUE_COMMIT=16bb080da472ffabbbafd2698073eca633fb0602
CANDIDATE_PARENT=a429fc30252ac6af94c51d96cd4ac24e72d9f83b
CANDIDATE_COMMIT=da9ce9159b3450c28c8faf8dceac671fb7bfeba2
CANDIDATE_TREE=58c6510c6f517004e37107786d006bb8333b79b8
CANDIDATE_DIFF_SHA=096d99b527bd1b433ecd07165696830f9316d07cc67484687d95cd2c2a846f08
PREVIOUS_UPSTREAM=a13c140cc289c0b7b3770bce5b3ad42ab35074aa
CURRENT_UPSTREAM=1229e2e57a5c2980ccd457b9b53ea0eed5a22ab3
CANDIDATE_MERGE_BASE=4edcdefd4083ae04b1a5656f4be6cd83ae919ef4
CANDIDATE_MERGE_TREE=00025acf3c082bec136467cc51c5254eb7c52089
UNSAFE_COUNT=15
FORMAL_MANIFEST_SHA=96ce0df751c04180ac7b10ea71b07de808e8f0fc140e99a6d08c12ec95618129

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

verify_hash()
{
	local file=$1 expected=$2 label=$3

	[ -f "$file" ] || die "$label missing"
	[ ! -L "$file" ] || die "$label is a symlink"
	[ "$(file_sha "$file")" = "$expected" ] || die "$label hash changed"
}

resolve_capsched_path()
{
	printf '%s/%s\n' "$CAPSCHED_DIR" "$1"
}

resolve_workspace_path()
{
	printf '%s/%s\n' "$WORKSPACE_DIR" "$1"
}

case "$RUN_ID" in
	[A-Za-z0-9]* ) ;;
	* ) die 'RUN_ID must begin with an alphanumeric character' ;;
esac
case "$RUN_ID" in
	*[!A-Za-z0-9._-]*|.|..) die 'RUN_ID contains an unsafe component' ;;
esac

case "$AUTH_GATE_TEST_MODE:$OFFLINE_TEST_MODE" in
	0:0|1:0|1:1) ;;
	*) die 'offline mode is restricted to authorization-gate tests' ;;
esac
if [ "$AUTH_GATE_TEST_MODE" = 1 ]; then
	[ -n "$CONFIG_OVERRIDE" ] || die 'test mode requires CONFIG_OVERRIDE'
	CONFIG=$CONFIG_OVERRIDE
	if [ -n "$TEST_CONFIG_SHA" ]; then
		case "$TEST_CONFIG_SHA" in
			*[!0-9a-f]*|'') die 'TEST_CONFIG_SHA must be lowercase hexadecimal' ;;
		esac
		[ "${#TEST_CONFIG_SHA}" = 64 ] || die 'TEST_CONFIG_SHA must contain 64 characters'
		CONFIG_EXPECTED_SHA=$TEST_CONFIG_SHA
	else
		CONFIG_EXPECTED_SHA=$CONFIG_SHA
	fi
	OUT_ROOT="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r4-post-n135-authorization-gate-test"
else
	[ -z "$CONFIG_OVERRIDE" ] || die 'CONFIG_OVERRIDE is restricted to test mode'
	[ -z "$TEST_CONFIG_SHA" ] || die 'TEST_CONFIG_SHA is restricted to test mode'
	CONFIG=$CANONICAL_CONFIG
	CONFIG_EXPECTED_SHA=$CONFIG_SHA
	OUT_ROOT="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r4-post-n135-authorization-gate"
fi
OUT_DIR="$OUT_ROOT/$RUN_ID"
INPUT_DIR="$OUT_DIR/inputs"

for command_name in awk chmod cmp cp diff find git grep java jq mkdir sha256sum sort sed stat tail tr wc xargs; do
	command -v "$command_name" >/dev/null 2>&1 || die "missing command: $command_name"
done
[ -f "$TLA_JAR" ] || die "missing TLA jar: $TLA_JAR"
[ ! -L "$CONFIG" ] || die 'authorization config is a symlink'
verify_hash "$CONFIG" "$CONFIG_EXPECTED_SHA" 'authorization config'
if [ -e "$OUT_DIR" ] || [ -L "$OUT_DIR" ]; then
	die "run output already exists: $OUT_DIR"
fi
mkdir -p "$OUT_ROOT"
mkdir "$OUT_DIR" "$INPUT_DIR"
chmod 0700 "$OUT_DIR" "$INPUT_DIR"

PLAN=$(resolve_capsched_path "$(jq -er '.evidence.governing_plan' "$CONFIG")")
IMPLEMENTATION=$(resolve_capsched_path "$(jq -er '.evidence.implementation_record' "$CONFIG")")
CLAIM_LEDGER=$(resolve_capsched_path "$(jq -er '.evidence.claim_ledger_gate' "$CONFIG")")
N135_VALIDATION=$(resolve_capsched_path "$(jq -er '.evidence.n135_validation' "$CONFIG")")
MATRIX=$(resolve_workspace_path "$(jq -er '.evidence.matrix_result' "$CONFIG")")
CLOSURE_R1=$(resolve_workspace_path "$(jq -er '.evidence.closure_r1' "$CONFIG")")
CLOSURE_R2=$(resolve_workspace_path "$(jq -er '.evidence.closure_r2' "$CONFIG")")
RUNTIME_CHARGE=$(resolve_capsched_path "$(jq -er '.separate_runtime_budget_boundary.runtime_charge_subject' "$CONFIG")")
RUNTIME_VALIDATION=$(resolve_capsched_path "$(jq -er '.separate_runtime_budget_boundary.runtime_charge_validation' "$CONFIG")")

progress '5% hash-locking plan, N-135, claim ledger, and N-136 boundary'
verify_hash "$PLAN" "$PLAN_SHA" 'governing plan'
verify_hash "$IMPLEMENTATION" "$IMPLEMENTATION_SHA" 'implementation record'
verify_hash "$CLAIM_LEDGER" "$CLAIM_LEDGER_SHA" 'claim-ledger gate'
verify_hash "$N135_VALIDATION" "$N135_VALIDATION_SHA" 'N-135 validation'
verify_hash "$MATRIX" "$MATRIX_SHA" 'N-135 matrix result'
verify_hash "$CLOSURE_R1" "$CLOSURE_R1_SHA" 'N-135 closure r1'
verify_hash "$CLOSURE_R2" "$CLOSURE_R2_SHA" 'N-135 closure r2'
verify_hash "$RUNTIME_CHARGE" "$RUNTIME_CHARGE_SHA" 'runtime-charge-subject gate'
verify_hash "$RUNTIME_VALIDATION" "$RUNTIME_VALIDATION_SHA" 'runtime-charge validation'

cp -- "$CONFIG" "$INPUT_DIR/authorization-gate.json"
cp -- "$PLAN" "$INPUT_DIR/governing-plan.json"
cp -- "$IMPLEMENTATION" "$INPUT_DIR/implementation-record.json"
cp -- "$CLAIM_LEDGER" "$INPUT_DIR/claim-ledger-gate.json"
cp -- "$N135_VALIDATION" "$INPUT_DIR/n135-validation.md"
cp -- "$MATRIX" "$INPUT_DIR/n135-matrix-result.json"
cp -- "$CLOSURE_R1" "$INPUT_DIR/n135-closure-r1.json"
cp -- "$CLOSURE_R2" "$INPUT_DIR/n135-closure-r2.json"
cp -- "$RUNTIME_CHARGE" "$INPUT_DIR/runtime-charge-subject.json"
cp -- "$RUNTIME_VALIDATION" "$INPUT_DIR/runtime-charge-validation.md"
chmod -R a-w "$INPUT_DIR"

progress '15% validating exact scoped authorization and claim-ledger row'
jq -e '
  .schema_version == 1 and
  .id == "sched-exec-lease-p5a-r4-post-n135-authorization-gate-v1" and
  .status == "scoped_r4_e3_synthetic_acceptance_and_r4_e4_plan_draft_authorization" and
  .evidence.n135_complete == true and
  .evidence.virtual_synthetic_protocol_evidence_complete == true and
  .evidence.governing_plan_sha256 == "f9c9103b4eae2177309dd8e0134601fe3cf1eb08061986265627dcd9d8fd6677" and
  .evidence.implementation_record_sha256 == "fe4add9b420870c21dca423c15f7505f1cfdc9c9360fac75605882856a782b86" and
  .evidence.claim_ledger_gate_sha256 == "d957db92654459c9298d252bdae0a92ef7de5b85918c24bcf4cc083c324e5adb" and
  .evidence.n135_validation_sha256 == "9c5794f123269beb71483298ed78711425868b5d9deec969ba637e7deba6390a" and
  .evidence.matrix_result_sha256 == "4717052e2f546cf5faa13bfd24d90e43626e9b66f4f6d24ad07b2ed5bc7fbedd" and
  .evidence.closure_r1_sha256 == "6d9a54ed85d742d77aeef98f53deab2634ead63d41ef1c551ca6720b4a098f89" and
  .evidence.closure_r2_sha256 == "86fd0cf06ddbcfd7fd88210eec196cec1650d31ca929791bf9e3bc7e7cfb26ea" and
  .evidence.closure_normalized_sha256 == "239bafaa191598443a2d004bd68edd949c3030849d79a5ad756a670980607e8f" and
  .source_identity.primary_linux_commit == "5e1ca3037e34823d1ba0cdd1dc04161fac170280" and
  .source_identity.patch_queue_commit == "16bb080da472ffabbbafd2698073eca633fb0602" and
  .source_identity.candidate_parent == "a429fc30252ac6af94c51d96cd4ac24e72d9f83b" and
  .source_identity.candidate_commit == "da9ce9159b3450c28c8faf8dceac671fb7bfeba2" and
  .source_identity.candidate_tree == "58c6510c6f517004e37107786d006bb8333b79b8" and
  .source_identity.candidate_diff_sha256 == "096d99b527bd1b433ecd07165696830f9316d07cc67484687d95cd2c2a846f08" and
  .source_identity.allowed_files == ["init/Kconfig","kernel/sched/exec_lease.c"] and
  ([.source_identity.direct_e2_child,.source_identity.default_off,.source_identity.same_translation_unit,.source_identity.disposable_branch_only] | all(. == true)) and
  .implementation_scope_reopen.review_scope_explicitly_reopened == true and
  .implementation_scope_reopen.scope == "exact_existing_disposable_default_off_virtual_synthetic_candidate_only" and
  ([.implementation_scope_reopen.new_source_creation_authorized,.implementation_scope_reopen.primary_linux_integration_authorized,.implementation_scope_reopen.patch_queue_integration_authorized] | all(. == false)) and
  .upstream_drift_freshness.previous_observed_commit == "a13c140cc289c0b7b3770bce5b3ad42ab35074aa" and
  .upstream_drift_freshness.current_observed_commit == "1229e2e57a5c2980ccd457b9b53ea0eed5a22ab3" and
  .upstream_drift_freshness.previous_is_ancestor == true and
  .upstream_drift_freshness.advanced_commit_count == 495 and
  .upstream_drift_freshness.candidate_merge_base == "4edcdefd4083ae04b1a5656f4be6cd83ae919ef4" and
  .upstream_drift_freshness.candidate_merge_tree == "00025acf3c082bec136467cc51c5254eb7c52089" and
  .upstream_drift_freshness.merge_tree_clean == true and
  .upstream_drift_freshness.touched_paths == ["init/Kconfig","kernel/sched/exec_lease.c"] and
  .upstream_drift_freshness.touched_paths_changed_since_previous_observation == [] and
  .upstream_drift_freshness.touched_paths_changed_since_candidate_merge_base == [] and
  .upstream_drift_freshness.private_exec_lease_absent_upstream == true and
  .upstream_drift_freshness.touched_path_source_shape_fresh == true and
  .upstream_drift_freshness.global_upstream_freshness_claim == false and
  .claim_ledger_row.proposal_id == "sched-exec-lease-p5a-r4-e3-concurrency-prototype-v1" and
  .claim_ledger_row.slice_id == "P5A-R4-E3" and
  .claim_ledger_row.behavior_mode == "default_off_same_translation_unit_virtual_synthetic_kunit_only" and
  (.claim_ledger_row.evidence_classes_present | index("virtual_synthetic_protocol_diagnostics")) != null and
  .claim_ledger_row.supported_claims == ["exact_candidate_source_identity_accepted_for_disposable_virtual_synthetic_evidence","default_off_synthetic_protocol_concurrency_correct_for_the_recorded_six_virtual_boots","separate_r4_e4_measurement_plan_may_be_drafted"] and
  (.claim_ledger_row.forbidden_claims | length) == 8 and
  (.claim_ledger_row.open_gaps | length) == 6 and
  all(.claim_ledger_row.safety_flags[]; . == false) and
  .local_evidence_class_rule.evidence_class == "virtual_synthetic_protocol_diagnostics" and
  .local_evidence_class_rule.may_support == ["exact_default_off_synthetic_protocol_correctness_under_recorded_matrix"] and
  (.local_evidence_class_rule.must_not_support | length) == 6 and
  .authorization_after_gate_pass.r4_e3_source_accepted == true and
  .authorization_after_gate_pass.r4_e3_source_acceptance_scope == "exact_disposable_default_off_virtual_synthetic_candidate_only" and
  .authorization_after_gate_pass.r4_e3_concurrency_correctness_accepted == true and
  .authorization_after_gate_pass.r4_e3_concurrency_correctness_scope == "modeled_and_six_boot_tested_virtual_synthetic_protocol_only" and
  .authorization_after_gate_pass.r4_e4_plan_may_be_drafted == true and
  .authorization_after_gate_pass.r4_e4_plan_draft_scope == "source_free_measurement_plan_only" and
  ([.authorization_after_gate_pass.r4_e4_plan_accepted,.authorization_after_gate_pass.r4_e4_source_may_be_created,.authorization_after_gate_pass.r4_behavior_source_may_be_created,.authorization_after_gate_pass.primary_linux_may_change,.authorization_after_gate_pass.patch_queue_may_change] | all(. == false)) and
  .separate_runtime_budget_boundary.n136_satisfied_by_r4_e3_evidence == false and
  .separate_runtime_budget_boundary.runtime_budget_hook_approved == false and
  .separate_runtime_budget_boundary.runtime_coverage == false and
  .formal.model_manifest_sha256 == "96ce0df751c04180ac7b10ea71b07de808e8f0fc140e99a6d08c12ec95618129" and
  .formal.unsafe_cfg_count == 15 and .formal.unsafe_expected_counterexamples == 15 and
  all(.safety_flags[]; . == false)
' "$CONFIG" >/dev/null

jq -S '.required_claim_ledger_row_fields | sort' "$CLAIM_LEDGER" > "$OUT_DIR/required-ledger-keys.json"
jq -S '.claim_ledger_row | keys | sort' "$CONFIG" > "$OUT_DIR/actual-ledger-keys.json"
cmp "$OUT_DIR/required-ledger-keys.json" "$OUT_DIR/actual-ledger-keys.json" >/dev/null \
	|| die 'claim-ledger row keys do not exactly match the global requirement'

jq -e '
  .missing_ledger_row_reviewable == false and
  (.evidence_class_rules | map(select(.evidence_class == "model_checked")) | length) == 1 and
  (.evidence_class_rules | map(select(.evidence_class == "source_drift_fresh")) | length) == 1 and
  .claim_rules.implementation_approval_requires == ["claim_ledger_row_present","implementation_scope_explicitly_reopened","upstream_drift_freshness_for_touched_paths","required_gate_artifacts_named","unsupported_claim_safety_flags_false"] and
  (.mandatory_false_unless_proven | length) == 8 and
  all(.safety_flags[]; . == false)
' "$CLAIM_LEDGER" >/dev/null

progress '28% independently closing the N-135 evidence semantics'
jq -e '
  .status == "r4_e3_concurrency_diagnostic_pre_source_plan" and
  .authorization_after_pass.r4_e3_source_accepted == false and
  .authorization_after_pass.r4_e3_concurrency_correctness_accepted == false and
  .authorization_after_pass.r4_e4_plan_may_be_drafted == false and
  .authorization_after_pass.r4_e4_source_may_be_created == false and
  .authorization_after_pass.primary_linux_may_change == false and
  .authorization_after_pass.patch_queue_may_change == false and
  all(.safety_flags[]; . == false)
' "$PLAN" >/dev/null

jq -e '
  .status == "r4_e3_scoped_virtual_synthetic_source_and_correctness_accepted_r4_e4_plan_draft_authorized" and
  .diagnostic_matrix.completed_matrix.result_sha256 == "4717052e2f546cf5faa13bfd24d90e43626e9b66f4f6d24ad07b2ed5bc7fbedd" and
  .diagnostic_matrix.completed_matrix.builds == 6 and
  .diagnostic_matrix.completed_matrix.qemu_boots == 6 and
  .diagnostic_matrix.completed_matrix.cases_passed == 216 and
  .diagnostic_matrix.completed_matrix.receipts == 216 and
  .diagnostic_matrix.completed_matrix.case_failures == 0 and
  .diagnostic_matrix.completed_matrix.case_skips == 0 and
  .diagnostic_matrix.completed_matrix.case_timeouts == 0 and
  .diagnostic_matrix.completed_matrix.warning_reports == 0 and
  .diagnostic_matrix.independent_closure.passed_twice == true and
  .diagnostic_matrix.virtual_synthetic_protocol_evidence_complete == true and
  .diagnostic_matrix.n135_complete == true and
  .diagnostic_matrix.r4_e3_source_accepted == false and
  .diagnostic_matrix.r4_e3_concurrency_correctness_accepted == false and
  .diagnostic_matrix.r4_e4_plan_may_be_drafted == false and
  .post_n135_authorization_gate.status == "passed_twice_with_normalized_identity" and
  .post_n135_authorization_gate.exact_disposable_source_accepted == true and
  .post_n135_authorization_gate.source_acceptance_scope == "exact_disposable_default_off_virtual_synthetic_candidate_only" and
  .post_n135_authorization_gate.synthetic_concurrency_correctness_accepted == true and
  .post_n135_authorization_gate.concurrency_correctness_scope == "modeled_and_six_boot_tested_virtual_synthetic_protocol_only" and
  .post_n135_authorization_gate.r4_e4_plan_may_be_drafted == true and
  .post_n135_authorization_gate.r4_e4_plan_accepted == false and
  .post_n135_authorization_gate.r4_e4_source_may_be_created == false and
  .safety_flags.r4_e3_source_accepted == true and
  .safety_flags.r4_e3_concurrency_correctness_accepted == true and
  .safety_flags.r4_e4_plan_may_be_drafted == true and
  (.safety_flags | del(.r4_e3_source_accepted,.r4_e3_concurrency_correctness_accepted,.r4_e4_plan_may_be_drafted) | all(.[]; . == false))
' "$IMPLEMENTATION" >/dev/null

jq -e '
  .status == "passed_six_boot_diagnostic_matrix_awaiting_independent_closure" and
  .candidate_commit == "da9ce9159b3450c28c8faf8dceac671fb7bfeba2" and
  .six_boot_matrix_passed == true and
  .total_passed_cases == 216 and .total_receipts == 216 and
  .case_failures == 0 and .case_skips == 0 and .case_timeouts == 0 and
  .warning_reports == 0 and
  .r4_e3_source_accepted == false and .r4_e3_concurrency_correctness_accepted == false and
  .primary_linux_changed == false and .patch_queue_changed == false and
  .production_protection == false and .multi_cluster_ready == false and .datacenter_ready == false
' "$MATRIX" >/dev/null

for closure in "$CLOSURE_R1" "$CLOSURE_R2"; do
	jq -e '
    .status == "passed_independent_six_boot_evidence_closure" and
    .source_result_sha256 == "4717052e2f546cf5faa13bfd24d90e43626e9b66f4f6d24ad07b2ed5bc7fbedd" and
    .six_boot_matrix_passed == true and .independent_artifact_closure_passed == true and
    .virtual_synthetic_protocol_evidence_complete == true and .n135_complete == true and
    .fresh_builds_recorded == 6 and .qemu_boots_audited == 6 and
    .total_cases_passed == 216 and .total_receipts == 216 and
    .compiler_diagnostics == 0 and .clock_skew_warnings == 0 and
    .kernel_warning_reports == 0 and .case_failures == 0 and .case_skips == 0 and
    .case_timeouts == 0 and .qemu_nonzero_exits == 0 and .network_devices_enabled == 0 and
    .r4_e3_source_accepted == false and .r4_e3_concurrency_correctness_accepted == false and
    .r4_e4_plan_may_be_drafted == false and .r4_e4_source_may_be_created == false and
    .primary_linux_may_change == false and .patch_queue_may_change == false and
    .runtime_behavior_approved == false and .bare_metal_validated == false and
    .production_protection == false and .multi_cluster_ready == false and .datacenter_ready == false
  ' "$closure" >/dev/null
done
normalized_r1=$(jq -S 'del(.run_id)' "$CLOSURE_R1" | sha256sum | awk '{print $1}')
normalized_r2=$(jq -S 'del(.run_id)' "$CLOSURE_R2" | sha256sum | awk '{print $1}')
[ "$normalized_r1" = "$CLOSURE_NORMALIZED_SHA" ] || die 'closure r1 normalized hash changed'
[ "$normalized_r2" = "$CLOSURE_NORMALIZED_SHA" ] || die 'closure r2 normalized hash changed'

jq -e '
  .status == "draft_model_gate_checked" and
  .invariants[0] == "NoUnspecifiedRuntimeCharge" and
  .safety_flags.hook_approved == false and
  .safety_flags.runtime_coverage == false and
  .safety_flags.protection_claim == false and
  (.next_blocking_obligations | length) == 4 and
  all(.safety_flags[]; . == false)
' "$RUNTIME_CHARGE" >/dev/null

progress '42% verifying Git identities and fresh touched-path source shape'
[ "$(git -C "$PRIMARY_DIR" rev-parse HEAD)" = "$PRIMARY_COMMIT" ] || die 'primary Linux moved'
[ -z "$(git -C "$PRIMARY_DIR" status --porcelain=v1)" ] || die 'primary Linux is dirty'
[ "$(git -C "$PATCH_QUEUE_DIR" rev-parse HEAD)" = "$PATCH_QUEUE_COMMIT" ] || die 'patch queue moved'
[ -z "$(git -C "$PATCH_QUEUE_DIR" status --porcelain=v1)" ] || die 'patch queue is dirty'
[ "$(git -C "$PRIMARY_DIR" rev-parse "$CANDIDATE_COMMIT^")" = "$CANDIDATE_PARENT" ] || die 'candidate parent changed'
[ "$(git -C "$PRIMARY_DIR" rev-parse "$CANDIDATE_COMMIT^{tree}")" = "$CANDIDATE_TREE" ] || die 'candidate tree changed'
git -C "$PRIMARY_DIR" diff "$CANDIDATE_PARENT" "$CANDIDATE_COMMIT" -- init/Kconfig kernel/sched/exec_lease.c > "$OUT_DIR/candidate.diff"
[ "$(file_sha "$OUT_DIR/candidate.diff")" = "$CANDIDATE_DIFF_SHA" ] || die 'candidate diff changed'
git -C "$PRIMARY_DIR" diff --name-only "$CANDIDATE_PARENT" "$CANDIDATE_COMMIT" -- > "$OUT_DIR/candidate-files.txt"
printf '%s\n' init/Kconfig kernel/sched/exec_lease.c > "$OUT_DIR/expected-candidate-files.txt"
cmp "$OUT_DIR/expected-candidate-files.txt" "$OUT_DIR/candidate-files.txt" >/dev/null || die 'candidate file scope changed'

[ "$(git -C "$PRIMARY_DIR" rev-parse upstream/master)" = "$CURRENT_UPSTREAM" ] || die 'local upstream observation changed or is missing'
if [ "$OFFLINE_TEST_MODE" = 0 ]; then
	remote_tip=$(git -C "$PRIMARY_DIR" ls-remote upstream refs/heads/master | awk 'NR == 1 {print $1}')
	[ "$remote_tip" = "$CURRENT_UPSTREAM" ] || die "recorded upstream tip is stale: remote=$remote_tip"
fi
git -C "$PRIMARY_DIR" merge-base --is-ancestor "$PREVIOUS_UPSTREAM" "$CURRENT_UPSTREAM" || die 'previous upstream is not an ancestor'
advance_count=$(git -C "$PRIMARY_DIR" rev-list --count "$PREVIOUS_UPSTREAM..$CURRENT_UPSTREAM")
[ "$advance_count" = 495 ] || die "upstream advance count changed: $advance_count"
[ "$(git -C "$PRIMARY_DIR" merge-base "$CANDIDATE_COMMIT" "$CURRENT_UPSTREAM")" = "$CANDIDATE_MERGE_BASE" ] || die 'candidate merge base changed'
git -C "$PRIMARY_DIR" diff --name-only "$PREVIOUS_UPSTREAM" "$CURRENT_UPSTREAM" -- init/Kconfig kernel/sched/exec_lease.c > "$OUT_DIR/touched-since-previous.txt"
[ ! -s "$OUT_DIR/touched-since-previous.txt" ] || die 'touched paths changed since previous upstream observation'
git -C "$PRIMARY_DIR" diff --name-only "$CANDIDATE_MERGE_BASE" "$CURRENT_UPSTREAM" -- init/Kconfig kernel/sched/exec_lease.c > "$OUT_DIR/touched-since-merge-base.txt"
[ ! -s "$OUT_DIR/touched-since-merge-base.txt" ] || die 'touched paths changed since candidate merge base'
if git -C "$PRIMARY_DIR" cat-file -e "$CURRENT_UPSTREAM:kernel/sched/exec_lease.c" 2>/dev/null; then
	die 'private exec_lease source unexpectedly exists upstream'
fi
merge_tree=$(git -C "$PRIMARY_DIR" merge-tree --write-tree "$CANDIDATE_COMMIT" "$CURRENT_UPSTREAM") || die 'candidate merge-tree has conflicts'
[ "$merge_tree" = "$CANDIDATE_MERGE_TREE" ] || die 'candidate merge-tree identity changed'

progress '58% model-checking the scoped authorization transition'
model_manifest="$OUT_DIR/formal-model.sha256"
(
	cd "$MODEL_DIR"
	find . -maxdepth 1 -type f -print0 | sort -z | xargs -0 sha256sum
) > "$model_manifest"
model_manifest_sha=$(file_sha "$model_manifest")
[ "$model_manifest_sha" = "$FORMAL_MANIFEST_SHA" ] || die 'formal model manifest changed'

(
	cd "$MODEL_DIR"
	java -cp "$TLA_JAR" tlc2.TLC -deadlock -metadir "$OUT_DIR/tlc-safe-states" -config "$SAFE_CFG" "$MODEL"
) > "$OUT_DIR/tlc-safe.log" 2>&1
grep -q 'Model checking completed. No error has been found.' "$OUT_DIR/tlc-safe.log" || {
	tail -80 "$OUT_DIR/tlc-safe.log" >&2
	die 'safe authorization model did not pass'
}
state_line=$(sed -n 's/^\([0-9][0-9]*\) states generated, \([0-9][0-9]*\) distinct states found.*/\1 \2/p' "$OUT_DIR/tlc-safe.log" | tail -1)
safe_states=$(printf '%s\n' "$state_line" | awk '{print $1}')
safe_distinct=$(printf '%s\n' "$state_line" | awk '{print $2}')
safe_depth=$(sed -n 's/^The depth of the complete state graph search is \([0-9][0-9]*\).*/\1/p' "$OUT_DIR/tlc-safe.log" | tail -1)

progress '72% proving all 15 unsafe authorization paths fail closed'
unsafe_expected=0
unsafe_fail=0
for cfg in "$MODEL_DIR"/P5AR4PostN135AuthorizationGateUnsafe*.cfg; do
	name=$(basename "$cfg" .cfg)
	log="$OUT_DIR/tlc-$name.log"
	if (
		cd "$MODEL_DIR"
		java -cp "$TLA_JAR" tlc2.TLC -deadlock -metadir "$OUT_DIR/tlc-$name-states" -config "$(basename "$cfg")" "$MODEL"
	) > "$log" 2>&1; then
		printf 'unsafe config unexpectedly passed: %s\n' "$(basename "$cfg")" >&2
		unsafe_fail=$((unsafe_fail + 1))
	elif grep -q 'Invariant Safety is violated' "$log"; then
		unsafe_expected=$((unsafe_expected + 1))
	else
		printf 'unsafe config failed unexpectedly: %s\n' "$(basename "$cfg")" >&2
		tail -40 "$log" >&2
		unsafe_fail=$((unsafe_fail + 1))
	fi
done
cfg_count=$(find "$MODEL_DIR" -maxdepth 1 -name 'P5AR4PostN135AuthorizationGateUnsafe*.cfg' | wc -l | tr -d ' ')
[ "$unsafe_fail" = 0 ] || die "$unsafe_fail unsafe formal cases failed unexpectedly"
[ "$unsafe_expected" = "$UNSAFE_COUNT" ] || die "unsafe counterexample count changed: $unsafe_expected"
[ "$cfg_count" = "$UNSAFE_COUNT" ] || die "unsafe config count changed: $cfg_count"

progress '92% sealing the scoped decision and every negative claim'
runner_sha=$(file_sha "${BASH_SOURCE[0]}")
jq -n \
	--arg run_id "$RUN_ID" \
	--arg config_sha "$CONFIG_SHA" \
	--arg runner_sha "$runner_sha" \
	--arg model_manifest_sha "$model_manifest_sha" \
	--arg matrix_sha "$MATRIX_SHA" \
	--arg closure_r1_sha "$CLOSURE_R1_SHA" \
	--arg closure_r2_sha "$CLOSURE_R2_SHA" \
	--arg closure_normalized_sha "$CLOSURE_NORMALIZED_SHA" \
	--arg primary_commit "$PRIMARY_COMMIT" \
	--arg patch_queue_commit "$PATCH_QUEUE_COMMIT" \
	--arg candidate_commit "$CANDIDATE_COMMIT" \
	--arg candidate_tree "$CANDIDATE_TREE" \
	--arg candidate_diff_sha "$CANDIDATE_DIFF_SHA" \
	--arg previous_upstream "$PREVIOUS_UPSTREAM" \
	--arg current_upstream "$CURRENT_UPSTREAM" \
	--arg merge_tree "$CANDIDATE_MERGE_TREE" \
	--argjson safe_states "${safe_states:-0}" \
	--argjson safe_distinct "${safe_distinct:-0}" \
	--argjson safe_depth "${safe_depth:-0}" \
	--argjson unsafe_expected "$unsafe_expected" \
'
{
  schema_version: 1,
  id: "sched-exec-lease-p5a-r4-post-n135-authorization-gate-result-v1",
  run_id: $run_id,
  status: "passed_scoped_r4_e3_synthetic_acceptance_and_r4_e4_plan_draft_authorization",
  authorization_config_sha256: $config_sha,
  runner_sha256: $runner_sha,
  formal_model_manifest_sha256: $model_manifest_sha,
  n135_matrix_result_sha256: $matrix_sha,
  n135_closure_result_sha256: [$closure_r1_sha, $closure_r2_sha],
  n135_closure_normalized_sha256: $closure_normalized_sha,
  primary_linux_commit: $primary_commit,
  patch_queue_commit: $patch_queue_commit,
  candidate_commit: $candidate_commit,
  candidate_tree: $candidate_tree,
  candidate_diff_sha256: $candidate_diff_sha,
  previous_upstream_commit: $previous_upstream,
  current_upstream_commit: $current_upstream,
  upstream_advance_count: 495,
  touched_path_changes: 0,
  candidate_merge_tree: $merge_tree,
  candidate_merge_tree_clean: true,
  claim_ledger_row_complete: true,
  required_claim_ledger_fields: 14,
  virtual_synthetic_protocol_diagnostics_class_scoped: true,
  safe_model_passed: true,
  safe_states_generated: $safe_states,
  safe_distinct_states: $safe_distinct,
  safe_depth: $safe_depth,
  unsafe_expected_counterexamples: $unsafe_expected,
  n135_complete: true,
  exact_disposable_r4_e3_source_accepted: true,
  r4_e3_source_acceptance_scope: "exact_disposable_default_off_virtual_synthetic_candidate_only",
  r4_e3_synthetic_concurrency_correctness_accepted: true,
  r4_e3_concurrency_correctness_scope: "modeled_and_six_boot_tested_virtual_synthetic_protocol_only",
  r4_e4_plan_may_be_drafted: true,
  r4_e4_plan_draft_scope: "source_free_measurement_plan_only",
  r4_e4_plan_accepted: false,
  r4_e4_source_may_be_created: false,
  r4_behavior_source_may_be_created: false,
  primary_linux_may_change: false,
  patch_queue_may_change: false,
  real_scheduler_attachment: false,
  runtime_scheduler_hook_approved: false,
  runtime_behavior_approved: false,
  runtime_denial_correctness: false,
  runtime_coverage: false,
  n136_satisfied_by_r4_e3_evidence: false,
  monitor_delivery_or_enforcement: false,
  cross_class_coverage: false,
  bare_metal_validated: false,
  bounded_wall_clock_latency_claim: false,
  performance_claim: false,
  cost_claim: false,
  production_protection: false,
  deployment_ready: false,
  multi_node_ready: false,
  multi_cluster_ready: false,
  datacenter_ready: false
}
' > "$OUT_DIR/result.json"
jq empty "$OUT_DIR/result.json"
file_sha "$OUT_DIR/result.json" > "$OUT_DIR/result.sha256"
progress '100% scoped authorization passed; R4-E4 plan drafting only is unlocked'
cat "$OUT_DIR/result.json"
