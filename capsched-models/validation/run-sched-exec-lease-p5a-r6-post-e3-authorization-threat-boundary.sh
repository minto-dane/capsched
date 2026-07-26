#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
PRIMARY_DIR="$WORKSPACE_DIR/linux"
CANDIDATE_DIR="$WORKSPACE_DIR/build/DomainLeaseLinux.volume/worktrees/p5a-r6-e3-correctness-prototype"
PATCH_QUEUE_DIR="$WORKSPACE_DIR/linux-patches"

CANONICAL_CONFIG="$CAPSCHED_DIR/capsched-models/analysis/sched-exec-lease-p5a-r6-post-e3-authorization-threat-boundary-v1.json"
ANALYSIS_NOTE="$CAPSCHED_DIR/capsched-models/analysis/0182-sched-exec-lease-p5a-r6-post-e3-authorization-threat-boundary.md"
PLAN="$CAPSCHED_DIR/capsched-models/analysis/sched-exec-lease-p5a-r6-e3-correctness-concurrency-evidence-plan-v1.json"
IMPLEMENTATION="$CAPSCHED_DIR/capsched-models/implementation/sched-exec-lease-p5a-r6-e3-domain-forest-correctness-prototype-v1.json"
CLAIM_LEDGER="$CAPSCHED_DIR/capsched-models/analysis/implementation-claim-ledger-gate-v1.json"
RUNTIME_CHARGE="$CAPSCHED_DIR/capsched-models/analysis/runtime-charge-subject-v1.json"
RUNTIME_VALIDATION="$CAPSCHED_DIR/capsched-models/validation/0107-runtime-charge-subject-tlc.md"
SOURCE_GATE="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r6-e3-correctness-source-gate/20260726T-p5a-r6-e3-source-gate-r1/result.json"
FOUR_PROFILE="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r6-e3-four-profile-diagnostic-matrix/20260726T-p5a-r6-e3-four-profile-r1/result.json"
CLOSURE_R1="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r6-e3-four-profile-evidence-closure/20260726T-p5a-r6-e3-four-profile-closure-r1/result.json"
CLOSURE_R2="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r6-e3-four-profile-evidence-closure/20260726T-p5a-r6-e3-four-profile-closure-r2/result.json"
MODEL_DIR="$CAPSCHED_DIR/capsched-models/formal/0145-p5a-r6-post-e3-authorization-threat-boundary-model"
MODEL=P5AR6PostE3AuthorizationThreatBoundary.tla
SAFE_CFG=P5AR6PostE3AuthorizationThreatBoundarySafe.cfg

TLA_JAR=${TLA_JAR:-"$WORKSPACE_DIR/build/tools/tla/tla2tools.jar"}
RUN_ID=${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
PROGRESS_FILE=${PROGRESS_FILE:-}
AUTH_TEST_MODE=${AUTH_TEST_MODE:-0}
CONFIG_OVERRIDE=${CONFIG_OVERRIDE:-}
TEST_CONFIG_SHA=${TEST_CONFIG_SHA:-}
OFFLINE_TEST_MODE=${OFFLINE_TEST_MODE:-0}
PREFLIGHT_ONLY=${PREFLIGHT_ONLY:-0}

CONFIG_SHA=2d9bad93604051f6d6bbf90f0cec619cc237e311235ce3fa1e2ffbab56d10e03
ANALYSIS_NOTE_SHA=c590173b0c9a5461554d4c529ff0aeb1757beb744fe501be42af2bfd1c316824
PLAN_SHA=36f5d2b0423d1a4f6de05e08ac4166e098bb7e7680ce81758b361187dc0e8d22
IMPLEMENTATION_SHA=7d58755a4fa825e70ede8b4c25563fea0369f3799da5afeb1ecc8d8ab15d5954
CLAIM_LEDGER_SHA=d957db92654459c9298d252bdae0a92ef7de5b85918c24bcf4cc083c324e5adb
RUNTIME_CHARGE_SHA=d1dff5ebb6721575bf0c26c60d913eb5a9a5d95c179fba71969e3b7cb2d11065
RUNTIME_VALIDATION_SHA=be3e6159da5cccdd5996bb5d434f81e492aae37963d4af8f193d541e58de1f38
SOURCE_GATE_SHA=88376403879ecc2b0a059791ba59a5bd71addd493e9c8052c2742f877f9e7f25
FOUR_PROFILE_SHA=bede4cbf4c5021eba080d0bd557f9e97529153e21da731ee729340ca8c2691be
CLOSURE_R1_SHA=0dce94b2ddf3448727bf936611704e33637f9114e8668cf1311aa1274775239a
CLOSURE_R2_SHA=964a16b0636d7f02850b851dd1530e9c08cc6c9e0c495c6b6a3ba78a1856a514
CLOSURE_NORMALIZED_SHA=3aebe14122f4b678c56351ee07f6a0ad475f708156c3657032232b9a76c761f7
FORMAL_MANIFEST_SHA=6ea9e39bb2f0cf041ea3f8904671ecefe0811778a311a5e5a10a8244b0579c18

PRIMARY_COMMIT=5e1ca3037e34823d1ba0cdd1dc04161fac170280
PATCH_QUEUE_COMMIT=16bb080da472ffabbbafd2698073eca633fb0602
PATCH_QUEUE_SERIES_BLOB=298567f8e0bd18168222da4e64da32750b9ea818
CANDIDATE_PARENT=66e2fd20fc85012d7dc03649fcf4c7af583cbb94
CANDIDATE_COMMIT=99287291f1c8e0d6c1b3ea86d121508c5547f424
CANDIDATE_TREE=2b863b57dfe3f03609ad1a73c965874f71056e8f
CANDIDATE_DIFF_SHA=2ed265756c1cee52252bedc6cbfb3d651eed136be9dca98992496ee80ebfb715
PREVIOUS_UPSTREAM=f2ec6312bf711369561bdcb22f8a63c0b118c479
CURRENT_UPSTREAM=3dab139d4795f688e4f243e40c7474df00d329d9
UPSTREAM_ADVANCE=543
UPSTREAM_TOUCHED_DIFF_SHA=2bf818b0a62bcb092a7a15c302a43bf6def37eb56f00d956aacd72de6a72e952
CANDIDATE_MERGE_BASE=4edcdefd4083ae04b1a5656f4be6cd83ae919ef4
CANDIDATE_MERGE_TREE=e673de497ceed7f3ae446e2474a7b106a547fdff
PRIVATE_KCONFIG_BLOCK_SHA=93bd31e2477cd4c0ac499ffc50fbd2000b79918ec7047a02b57cd19eea6b089a
THREAT_MODEL_TARGET=target_sha256_00f33333870097e986c36684a58470fe51e779600219938b209ca597ae663190
THREAT_MODEL_VERSION=5e4121e614ba0745c0857f4cfbb0d4191fd4f3b6
THREAT_MODEL_SHA=c26d7710338413408f8242da7fd1e58a0805ed95b85970a7db7a44a0e1f49050

# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/immutable-evidence-inputs.sh"

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

snapshot()
{
	local source=$1 expected=$2 destination=$3

	capsched_snapshot_verified_file "$source" "$expected" "$destination" ||
		die "failed immutable snapshot: $source"
}

for command_name in awk chmod cmp cp cut find git grep jq mkdir mv sed \
	sha256sum sort tail tr wc xargs; do
	command -v "$command_name" >/dev/null 2>&1 ||
		die "missing command: $command_name"
done
capsched_validate_run_id "$RUN_ID" || die 'invalid RUN_ID'

case "$AUTH_TEST_MODE:$PREFLIGHT_ONLY" in
	0:0|1:1) ;;
	*) die 'test mode and preflight mode must be enabled together' ;;
esac
if [ "$AUTH_TEST_MODE" = 1 ]; then
	[ -n "$CONFIG_OVERRIDE" ] || die 'test mode requires CONFIG_OVERRIDE'
	[ -n "$TEST_CONFIG_SHA" ] || die 'test mode requires TEST_CONFIG_SHA'
	[ "$OFFLINE_TEST_MODE" = 1 ] ||
		die 'test mode requires OFFLINE_TEST_MODE=1'
	CONFIG_SOURCE=$CONFIG_OVERRIDE
	EXPECTED_CONFIG_SHA=$TEST_CONFIG_SHA
	OUT_ROOT="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r6-post-e3-authorization-threat-boundary-test"
else
	[ -z "$CONFIG_OVERRIDE" ] || die 'CONFIG_OVERRIDE is restricted to test mode'
	[ -z "$TEST_CONFIG_SHA" ] || die 'TEST_CONFIG_SHA is restricted to test mode'
	[ "$OFFLINE_TEST_MODE" = 0 ] || die 'offline mode is restricted to tests'
	CONFIG_SOURCE=$CANONICAL_CONFIG
	EXPECTED_CONFIG_SHA=$CONFIG_SHA
	OUT_ROOT="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r6-post-e3-authorization-threat-boundary"
fi
[ -f "$CONFIG_SOURCE" ] && [ ! -L "$CONFIG_SOURCE" ] ||
	die 'config must be a regular non-symlink file'
if [ "$PREFLIGHT_ONLY" = 0 ]; then
	command -v java >/dev/null 2>&1 || die 'missing command: java'
	[ -f "$TLA_JAR" ] && [ ! -L "$TLA_JAR" ] ||
		die "missing or unsafe TLA jar: $TLA_JAR"
fi

capsched_create_fresh_run_dir "$OUT_ROOT" "$RUN_ID" ||
	die 'run output already exists or is unsafe'
OUT_DIR="$OUT_ROOT/$RUN_ID"
mkdir "$OUT_DIR/inputs" "$OUT_DIR/git" "$OUT_DIR/formal"

progress '5% snapshotting the exact contract and closed R6-E3 evidence'
snapshot "$CONFIG_SOURCE" "$EXPECTED_CONFIG_SHA" "$OUT_DIR/inputs/config.json"
snapshot "$ANALYSIS_NOTE" "$ANALYSIS_NOTE_SHA" "$OUT_DIR/inputs/analysis.md"
snapshot "$PLAN" "$PLAN_SHA" "$OUT_DIR/inputs/plan.json"
snapshot "$IMPLEMENTATION" "$IMPLEMENTATION_SHA" "$OUT_DIR/inputs/implementation.json"
snapshot "$CLAIM_LEDGER" "$CLAIM_LEDGER_SHA" "$OUT_DIR/inputs/claim-ledger.json"
snapshot "$RUNTIME_CHARGE" "$RUNTIME_CHARGE_SHA" "$OUT_DIR/inputs/runtime-charge.json"
snapshot "$RUNTIME_VALIDATION" "$RUNTIME_VALIDATION_SHA" "$OUT_DIR/inputs/runtime-validation.md"
snapshot "$SOURCE_GATE" "$SOURCE_GATE_SHA" "$OUT_DIR/inputs/source-gate.json"
snapshot "$FOUR_PROFILE" "$FOUR_PROFILE_SHA" "$OUT_DIR/inputs/four-profile.json"
snapshot "$CLOSURE_R1" "$CLOSURE_R1_SHA" "$OUT_DIR/inputs/closure-r1.json"
snapshot "$CLOSURE_R2" "$CLOSURE_R2_SHA" "$OUT_DIR/inputs/closure-r2.json"
CONFIG="$OUT_DIR/inputs/config.json"
for input_json in "$CONFIG" "$OUT_DIR/inputs/plan.json" \
	"$OUT_DIR/inputs/implementation.json" "$OUT_DIR/inputs/claim-ledger.json" \
	"$OUT_DIR/inputs/runtime-charge.json" "$OUT_DIR/inputs/source-gate.json" \
	"$OUT_DIR/inputs/four-profile.json" "$OUT_DIR/inputs/closure-r1.json" \
	"$OUT_DIR/inputs/closure-r2.json"; do
	jq empty "$input_json"
done

progress '14% validating threat boundaries and the fail-closed authorization contract'
jq -e --arg target "$THREAT_MODEL_TARGET" \
	--arg version "$THREAT_MODEL_VERSION" --arg threat_sha "$THREAT_MODEL_SHA" '
  .schema_version == 1 and
  .status == "source_free_post_e3_authorization_contract" and
  .threat_model.target_id == $target and
  .threat_model.repository_version == $version and
  .threat_model.sha256 == $threat_sha and
  .threat_model.security_guidance_bytes == 0 and
  .threat_model.scope_classes == [
    "runtime_linux_source",
    "private_disposable_prototypes",
    "developer_and_evidence_tooling"
  ] and
  .threat_model.trust_boundaries == [
    "userspace_to_kernel",
    "kernel_task_to_domain",
    "linux_to_monitor",
    "monitor_to_hardware",
    "synchronous_to_async_worker",
    "node_to_cluster_control_plane",
    "upstream_patch_evidence_supply_chain"
  ] and
  .threat_model.claim_boundaries == [
    "scheduler",
    "async_service",
    "memoryview_tlb",
    "device_dma_iommu",
    "monitor",
    "cluster",
    "supply_chain"
  ] and
  .threat_model.monitor_currently_implemented == false and
  .r6_e3_evidence.plan_sha256 == "36f5d2b0423d1a4f6de05e08ac4166e098bb7e7680ce81758b361187dc0e8d22" and
  .r6_e3_evidence.implementation_record_sha256 == "7d58755a4fa825e70ede8b4c25563fea0369f3799da5afeb1ecc8d8ab15d5954" and
  .r6_e3_evidence.source_gate_result_sha256 == "88376403879ecc2b0a059791ba59a5bd71addd493e9c8052c2742f877f9e7f25" and
  .r6_e3_evidence.four_profile_result_sha256 == "bede4cbf4c5021eba080d0bd557f9e97529153e21da731ee729340ca8c2691be" and
  .r6_e3_evidence.profile_results_sha256 == "9142a2a0ff800efbf2e9f5b5231575b6c6c47d26e14ca535265f81221e802b71" and
  .r6_e3_evidence.closure_runner_sha256 == "5b4176a7b71b246f270a95db520ea7f5410dc25551adb75dfad9b873c387481b" and
  .r6_e3_evidence.closure_r1_result_sha256 == "0dce94b2ddf3448727bf936611704e33637f9114e8668cf1311aa1274775239a" and
  .r6_e3_evidence.closure_r2_result_sha256 == "964a16b0636d7f02850b851dd1530e9c08cc6c9e0c495c6b6a3ba78a1856a514" and
  .r6_e3_evidence.closure_normalized_sha256 == "3aebe14122f4b678c56351ee07f6a0ad475f708156c3657032232b9a76c761f7" and
  .r6_e3_evidence.architectures == ["arm64","x86_64"] and
  (.r6_e3_evidence.fresh_builds == 4 and .r6_e3_evidence.qemu_boots == 4) and
  (.r6_e3_evidence.cases_passed == 220 and .r6_e3_evidence.receipts == 220) and
  ([.r6_e3_evidence.case_failures,.r6_e3_evidence.case_skips,
    .r6_e3_evidence.case_timeouts,.r6_e3_evidence.warning_reports] | all(. == 0)) and
  .r6_e3_evidence.passed_twice == true and
  .r6_e3_evidence.virtual_synthetic_protocol_only == true and
  .source_identity.allowed_files == ["init/Kconfig","kernel/sched/exec_lease.c"] and
  .source_identity.direct_e2_child == true and
  .source_identity.config_default_off == true and
  .source_identity.same_translation_unit == true and
  .source_identity.synthetic_scheduler_inputs_only == true and
  .source_identity.live_scheduler_attachment == false and
  .source_identity.pushed_remote_exact == true and
  .frozen_boundaries.primary_linux_change_allowed == false and
  .frozen_boundaries.patch_queue_change_allowed == false and
  .upstream_drift_freshness.touched_paths == ["init/Kconfig"] and
  .upstream_drift_freshness.touched_path_drift_observed == true and
  .upstream_drift_freshness.touched_path_drift_classified ==
    "unrelated_init_kconfig_rustc_capability_probe_outside_private_sched_exec_lease_block" and
  .upstream_drift_freshness.merge_tree_clean == true and
  .upstream_drift_freshness.private_exec_lease_absent_upstream == true and
  .upstream_drift_freshness.private_source_scope_unchanged_after_merge == true and
  .upstream_drift_freshness.global_upstream_freshness_claim == false and
  .evidence_classes_present == [
    "model_checked",
    "linux_no_behavior_build",
    "patch_queue_replay",
    "source_drift_fresh",
    "virtual_synthetic_protocol_diagnostics",
    "independent_artifact_closure"
  ] and
  .separate_runtime_budget_boundary.runtime_budget_hook_allowed == false and
  .separate_runtime_budget_boundary.runtime_coverage == false and
  .separate_runtime_budget_boundary.satisfied_by_r6_e3_evidence == false and
  .formal.manifest_sha256 == "6ea9e39bb2f0cf041ea3f8904671ecefe0811778a311a5e5a10a8244b0579c18" and
  .formal.safe_expected_distinct_states == 4 and
  .formal.safe_expected_depth == 4 and
  .formal.unsafe_expected_counterexamples == 24 and
  .authorization_after_gate_pass.exact_r6_e3_source_accepted == true and
  .authorization_after_gate_pass.exact_r6_e3_synthetic_correctness_accepted == true and
  .authorization_after_gate_pass.r6_e4_source_free_plan_may_be_drafted == true and
  .authorization_after_gate_pass.r6_e4_plan_accepted == false and
  .authorization_after_gate_pass.r6_e4_source_may_be_created == false and
  .authorization_after_gate_pass.live_scheduler_attachment_allowed == false and
  .authorization_after_gate_pass.primary_linux_may_change == false and
  .authorization_after_gate_pass.patch_queue_may_change == false and
  all(.safety_flags[]; . == false)
' "$CONFIG" >/dev/null

progress '24% checking the exact claim-ledger row and separate runtime boundary'
jq -S '.required_claim_ledger_row_fields | sort' \
	"$OUT_DIR/inputs/claim-ledger.json" > "$OUT_DIR/required-ledger-keys.json"
jq -S '.claim_ledger_row | keys | sort' "$CONFIG" \
	> "$OUT_DIR/actual-ledger-keys.json"
cmp "$OUT_DIR/required-ledger-keys.json" "$OUT_DIR/actual-ledger-keys.json" \
	>/dev/null || die 'claim-ledger row does not contain exactly the 14 required fields'
jq -e '
  .claim_ledger_row.proposal_id ==
    "sched-exec-lease-p5a-r6-post-e3-authorization-threat-boundary-v1" and
  .claim_ledger_row.slice_id == "P5A-R6-POST-E3" and
  .claim_ledger_row.behavior_mode ==
    "default_off_disposable_same_translation_unit_virtual_synthetic_correctness_only" and
  (.claim_ledger_row.evidence_classes_present | length) == 6 and
  (.claim_ledger_row.supported_claims | length) == 3 and
  (.claim_ledger_row.forbidden_claims | length) == 13 and
  (.claim_ledger_row.open_gaps | length) == 7 and
  (.claim_ledger_row.required_validation_before_review | length) == 4 and
  (.claim_ledger_row.required_validation_before_acceptance | length) == 4 and
  .claim_ledger_row.upstream_drift_freshness.drift_observed_and_classified == true and
  .claim_ledger_row.upstream_drift_freshness.global_freshness_claim == false and
  all(.claim_ledger_row.safety_flags[]; . == false)
' "$CONFIG" >/dev/null
jq -e '
  .missing_ledger_row_reviewable == false and
  (.required_claim_ledger_row_fields | length) == 14 and
  (.mandatory_false_unless_proven | length) == 8 and
  all(.safety_flags[]; . == false)
' "$OUT_DIR/inputs/claim-ledger.json" >/dev/null
jq -e '
  .status == "draft_model_gate_checked" and
  .invariants[0] == "NoUnspecifiedRuntimeCharge" and
  all(.safety_flags[]; . == false)
' "$OUT_DIR/inputs/runtime-charge.json" >/dev/null

progress '34% independently re-closing source, matrix, and closure results'
jq -e '
  .status == "passed_source_gate_awaiting_four_profile_diagnostic_matrix" and
  .candidate_commit == "99287291f1c8e0d6c1b3ea86d121508c5547f424" and
  .candidate_parent == "66e2fd20fc85012d7dc03649fcf4c7af583cbb94" and
  .candidate_tree == "2b863b57dfe3f03609ad1a73c965874f71056e8f" and
  .candidate_diff_sha256 == "2ed265756c1cee52252bedc6cbfb3d651eed136be9dca98992496ee80ebfb715" and
  .architectures == ["arm64","x86_64"] and
  (.fresh_modes_per_architecture | length) == 4 and
  .disabled_e3_artifacts == 0 and .w1_compiler_diagnostics == 0 and
  .strict_checkpatch == {"errors":0,"warnings":0,"checks":0} and
  .exact_direct_e2_child == true and .exact_two_file_boundary == true and
  .config_default_off == true and .same_translation_unit == true and
  .live_scheduler_attachment == false and .runtime_behavior_approved == false and
  .r6_e3_source_accepted == false and .r6_e3_correctness_accepted == false and
  .production_protection == false and .multi_cluster_ready == false and
  .datacenter_ready == false
' "$OUT_DIR/inputs/source-gate.json" >/dev/null
jq -e '
  .status == "passed_four_profile_matrix_awaiting_independent_closure" and
  .candidate_commit == "99287291f1c8e0d6c1b3ea86d121508c5547f424" and
  .profile_results_sha256 == "9142a2a0ff800efbf2e9f5b5231575b6c6c47d26e14ca535265f81221e802b71" and
  (.diagnostic_profiles | length) == 4 and (.results | length) == 4 and
  all(.results[]; .status == "passed" and .fresh_build_output == true and
    .cases_passed == 55 and .receipts == 55 and .case_failures == 0 and
    .case_skips == 0 and .case_timeouts == 0 and .warning_reports == 0 and
    .virtual_synthetic_protocol_only == true) and
  .total_passed_cases == 220 and .total_receipts == 220 and
  .case_failures == 0 and .case_skips == 0 and .case_timeouts == 0 and
  .warning_reports == 0 and .build_clock_skew_retries == 0 and
  .four_profile_matrix_passed == true and
  .virtual_synthetic_protocol_only == true and
  .live_scheduler_attachment == false and .runtime_behavior_approved == false and
  .production_protection == false and .multi_cluster_ready == false and
  .datacenter_ready == false
' "$OUT_DIR/inputs/four-profile.json" >/dev/null
for closure in "$OUT_DIR/inputs/closure-r1.json" \
	"$OUT_DIR/inputs/closure-r2.json"; do
	jq -e '
    .status == "passed_independent_four_profile_evidence_closure" and
    .candidate_commit == "99287291f1c8e0d6c1b3ea86d121508c5547f424" and
    .closure_runner_sha256 == "5b4176a7b71b246f270a95db520ea7f5410dc25551adb75dfad9b873c387481b" and
    .source_result_sha256 == "bede4cbf4c5021eba080d0bd557f9e97529153e21da731ee729340ca8c2691be" and
    .profile_results_sha256 == "9142a2a0ff800efbf2e9f5b5231575b6c6c47d26e14ca535265f81221e802b71" and
    .source_artifact_manifest_sha256 == "151c877301d3f59d171fc30bf449044990e46892860c8f9d2eb4f3467b0b4ecc" and
    .source_artifact_count == 60 and .source_artifact_bytes == 2659341 and
    .qemu_boots_audited == 4 and .build_logs_audited == 4 and
    .ktap_suites_passed == 4 and .receipt_ledgers_audited == 4 and
    .total_cases_passed == 220 and .total_receipts == 220 and
    .case_failures == 0 and .case_skips == 0 and .case_timeouts == 0 and
    .compiler_diagnostics == 0 and .clock_skew_warnings == 0 and
    .kernel_warning_reports == 0 and
    .independent_artifact_closure_passed == true and
    .virtual_synthetic_protocol_evidence_complete == true and
    .e4_plan_or_source_may_start == false and
    .live_scheduler_attachment == false and .runtime_behavior_approved == false and
    .runtime_denial_correctness == false and .monitor_delivery_or_enforcement == false and
    .production_protection == false and .multi_cluster_ready == false and
    .datacenter_ready == false
  ' "$closure" >/dev/null
done
normalized_r1=$(jq -S 'del(.run_id)' "$OUT_DIR/inputs/closure-r1.json" |
	sha256sum | awk '{print $1}')
normalized_r2=$(jq -S 'del(.run_id)' "$OUT_DIR/inputs/closure-r2.json" |
	sha256sum | awk '{print $1}')
[ "$normalized_r1" = "$CLOSURE_NORMALIZED_SHA" ] ||
	die 'closure r1 normalized hash changed'
[ "$normalized_r2" = "$CLOSURE_NORMALIZED_SHA" ] ||
	die 'closure r2 normalized hash changed'

progress '46% verifying immutable Git identities and exact candidate scope'
[ "$(git -C "$PRIMARY_DIR" rev-parse HEAD)" = "$PRIMARY_COMMIT" ] ||
	die 'primary Linux moved'
[ -z "$(git -C "$PRIMARY_DIR" status --porcelain=v1)" ] ||
	die 'primary Linux is dirty'
[ "$(git -C "$PATCH_QUEUE_DIR" rev-parse HEAD)" = "$PATCH_QUEUE_COMMIT" ] ||
	die 'patch queue moved'
[ -z "$(git -C "$PATCH_QUEUE_DIR" status --porcelain=v1)" ] ||
	die 'patch queue is dirty'
[ "$(git -C "$PATCH_QUEUE_DIR" rev-parse HEAD:patches/capsched-linux-l0/series)" = \
	"$PATCH_QUEUE_SERIES_BLOB" ] || die 'patch queue series blob moved'
[ "$(git -C "$CANDIDATE_DIR" rev-parse HEAD)" = "$CANDIDATE_COMMIT" ] ||
	die 'candidate worktree moved'
[ -z "$(git -C "$CANDIDATE_DIR" status --porcelain=v1)" ] ||
	die 'candidate worktree is dirty'
[ "$(git -C "$PRIMARY_DIR" rev-parse "$CANDIDATE_COMMIT^")" = \
	"$CANDIDATE_PARENT" ] || die 'candidate parent moved'
[ "$(git -C "$PRIMARY_DIR" rev-parse "$CANDIDATE_COMMIT^{tree}")" = \
	"$CANDIDATE_TREE" ] || die 'candidate tree moved'
[ "$(git -C "$PRIMARY_DIR" rev-parse \
	refs/remotes/fork/codex/p5a-r6-e3-correctness-prototype)" = \
	"$CANDIDATE_COMMIT" ] || die 'local fork tracking ref moved'
git -C "$PRIMARY_DIR" diff "$CANDIDATE_PARENT" "$CANDIDATE_COMMIT" -- \
	init/Kconfig kernel/sched/exec_lease.c > "$OUT_DIR/git/candidate.diff"
[ "$(capsched_sha256_file "$OUT_DIR/git/candidate.diff")" = \
	"$CANDIDATE_DIFF_SHA" ] || die 'candidate diff moved'
git -C "$PRIMARY_DIR" diff --name-only "$CANDIDATE_PARENT" \
	"$CANDIDATE_COMMIT" -- > "$OUT_DIR/git/candidate-paths.txt"
printf '%s\n' init/Kconfig kernel/sched/exec_lease.c \
	> "$OUT_DIR/git/expected-candidate-paths.txt"
cmp "$OUT_DIR/git/expected-candidate-paths.txt" \
	"$OUT_DIR/git/candidate-paths.txt" >/dev/null ||
	die 'candidate file scope broadened'

progress '58% recomputing refreshed upstream drift and clean merge scope'
[ "$(git -C "$PRIMARY_DIR" rev-parse upstream/master)" = \
	"$CURRENT_UPSTREAM" ] || die 'local upstream observation moved'
if [ "$OFFLINE_TEST_MODE" = 0 ]; then
	remote_tip=$(git -C "$PRIMARY_DIR" ls-remote upstream refs/heads/master |
		awk 'NR == 1 {print $1}')
	[ "$remote_tip" = "$CURRENT_UPSTREAM" ] ||
		die "recorded upstream tip is stale: $remote_tip"
	fork_tip=$(git -C "$PRIMARY_DIR" ls-remote fork \
		refs/heads/codex/p5a-r6-e3-correctness-prototype |
		awk 'NR == 1 {print $1}')
	[ "$fork_tip" = "$CANDIDATE_COMMIT" ] ||
		die "pushed candidate identity moved: $fork_tip"
fi
git -C "$PRIMARY_DIR" merge-base --is-ancestor "$PREVIOUS_UPSTREAM" \
	"$CURRENT_UPSTREAM" || die 'previous upstream is not an ancestor'
[ "$(git -C "$PRIMARY_DIR" rev-list --count \
	"$PREVIOUS_UPSTREAM..$CURRENT_UPSTREAM")" = "$UPSTREAM_ADVANCE" ] ||
	die 'upstream advance count moved'
[ "$(git -C "$PRIMARY_DIR" merge-base "$CANDIDATE_COMMIT" \
	"$CURRENT_UPSTREAM")" = "$CANDIDATE_MERGE_BASE" ] ||
	die 'candidate merge base moved'
[ "$(git -C "$PRIMARY_DIR" merge-tree --write-tree "$CANDIDATE_COMMIT" \
	"$CURRENT_UPSTREAM")" = "$CANDIDATE_MERGE_TREE" ] ||
	die 'candidate merge tree moved or conflicts'
git -C "$PRIMARY_DIR" diff --name-only "$PREVIOUS_UPSTREAM" \
	"$CURRENT_UPSTREAM" -- init/Kconfig kernel/sched/exec_lease.c \
	> "$OUT_DIR/git/upstream-touched-paths.txt"
printf '%s\n' init/Kconfig > "$OUT_DIR/git/expected-upstream-touched-paths.txt"
cmp "$OUT_DIR/git/expected-upstream-touched-paths.txt" \
	"$OUT_DIR/git/upstream-touched-paths.txt" >/dev/null ||
	die 'upstream touched-path set moved or was not classified'
git -C "$PRIMARY_DIR" diff "$PREVIOUS_UPSTREAM" "$CURRENT_UPSTREAM" -- \
	init/Kconfig kernel/sched/exec_lease.c \
	> "$OUT_DIR/git/upstream-touched.diff"
[ "$(capsched_sha256_file "$OUT_DIR/git/upstream-touched.diff")" = \
	"$UPSTREAM_TOUCHED_DIFF_SHA" ] || die 'upstream touched-path diff moved'
if git -C "$PRIMARY_DIR" cat-file -e \
	"$CURRENT_UPSTREAM:kernel/sched/exec_lease.c" 2>/dev/null; then
	die 'private exec_lease source unexpectedly exists upstream'
fi
git -C "$PRIMARY_DIR" show "$CANDIDATE_COMMIT:init/Kconfig" |
	sed -n '/^config SCHED_EXEC_LEASE$/,/^config UCLAMP_TASK$/p' \
	> "$OUT_DIR/git/candidate-private-kconfig"
git -C "$PRIMARY_DIR" show "$CANDIDATE_MERGE_TREE:init/Kconfig" |
	sed -n '/^config SCHED_EXEC_LEASE$/,/^config UCLAMP_TASK$/p' \
	> "$OUT_DIR/git/merged-private-kconfig"
[ "$(capsched_sha256_file "$OUT_DIR/git/candidate-private-kconfig")" = \
	"$PRIVATE_KCONFIG_BLOCK_SHA" ] || die 'candidate private Kconfig block moved'
[ "$(capsched_sha256_file "$OUT_DIR/git/merged-private-kconfig")" = \
	"$PRIVATE_KCONFIG_BLOCK_SHA" ] || die 'merged private Kconfig block moved'
cmp "$OUT_DIR/git/candidate-private-kconfig" \
	"$OUT_DIR/git/merged-private-kconfig" >/dev/null ||
	die 'upstream drift changed the private Kconfig block'

if [ "$PREFLIGHT_ONLY" = 1 ]; then
	progress '100% preflight contract passed; formal execution intentionally omitted'
	jq -n --arg run_id "$RUN_ID" '
	  {
	    schema_version: 1,
	    id: "sched-exec-lease-p5a-r6-post-e3-authorization-threat-boundary-result-v1",
	    run_id: $run_id,
	    status: "passed_preflight_only",
	    formal_execution_omitted: true
	  }
	' > "$OUT_DIR/result.json"
	sha256sum "$OUT_DIR/result.json" > "$OUT_DIR/result.sha256"
	exit 0
fi

progress '68% snapshotting and executing the safe formal model'
(
	cd "$MODEL_DIR"
	find . -maxdepth 1 -type f -print0 | sort -z | xargs -0 sha256sum
) > "$OUT_DIR/formal-source-manifest.sha256"
[ "$(capsched_sha256_file "$OUT_DIR/formal-source-manifest.sha256")" = \
	"$FORMAL_MANIFEST_SHA" ] || die 'formal source manifest moved'
while read -r expected path; do
	name=${path#./}
	snapshot "$MODEL_DIR/$name" "$expected" "$OUT_DIR/formal/$name"
done < "$OUT_DIR/formal-source-manifest.sha256"
(
	cd "$OUT_DIR/formal"
	find . -maxdepth 1 -type f -print0 | sort -z | xargs -0 sha256sum
) > "$OUT_DIR/formal-snapshot-manifest.sha256"
cmp "$OUT_DIR/formal-source-manifest.sha256" \
	"$OUT_DIR/formal-snapshot-manifest.sha256" >/dev/null ||
	die 'formal snapshot differs from source'
(
	cd "$OUT_DIR/formal"
	java -XX:+UseParallelGC -cp "$TLA_JAR" tlc2.TLC -deadlock \
		-metadir "$OUT_DIR/tlc-safe-states" -config "$SAFE_CFG" "$MODEL"
) > "$OUT_DIR/tlc-safe.log" 2>&1
grep -q 'Model checking completed. No error has been found.' \
	"$OUT_DIR/tlc-safe.log" || {
	tail -80 "$OUT_DIR/tlc-safe.log" >&2
	die 'safe formal model failed'
}
state_line=$(sed -n \
	's/^\([0-9][0-9]*\) states generated, \([0-9][0-9]*\) distinct states found.*/\1 \2/p' \
	"$OUT_DIR/tlc-safe.log" | tail -1)
safe_states=$(printf '%s\n' "$state_line" | awk '{print $1}')
safe_distinct=$(printf '%s\n' "$state_line" | awk '{print $2}')
safe_depth=$(sed -n \
	's/^The depth of the complete state graph search is \([0-9][0-9]*\).*/\1/p' \
	"$OUT_DIR/tlc-safe.log" | tail -1)
[ "$safe_distinct" = 4 ] || die "unexpected safe distinct states: $safe_distinct"
[ "$safe_depth" = 4 ] || die "unexpected safe depth: $safe_depth"

progress '82% proving all 24 missing-prerequisite and overclaim variants fail closed'
unsafe_count=0
for unsafe_cfg in "$OUT_DIR/formal"/P5AR6PostE3AuthorizationThreatBoundaryUnsafe*.cfg; do
	unsafe_count=$((unsafe_count + 1))
	name=$(basename "$unsafe_cfg" .cfg)
	log="$OUT_DIR/tlc-unsafe-$unsafe_count-$name.log"
	if (
		cd "$OUT_DIR/formal"
		java -XX:+UseParallelGC -cp "$TLA_JAR" tlc2.TLC -deadlock \
			-metadir "$OUT_DIR/tlc-unsafe-$unsafe_count-states" \
			-config "$(basename "$unsafe_cfg")" "$MODEL"
	) > "$log" 2>&1; then
		die "unsafe formal config unexpectedly passed: $name"
	fi
	grep -q 'Invariant Safety is violated' "$log" || {
		tail -80 "$log" >&2
		die "unsafe formal config lacked the expected counterexample: $name"
	}
done
[ "$unsafe_count" = 24 ] ||
	die "unsafe formal config count changed: $unsafe_count"

progress '94% publishing the scoped authorization and every negative claim'
runner_sha=$(capsched_sha256_file "${BASH_SOURCE[0]}")
jq -n --arg run_id "$RUN_ID" --arg runner_sha "$runner_sha" \
	--arg candidate "$CANDIDATE_COMMIT" --arg upstream "$CURRENT_UPSTREAM" \
	--arg merge_tree "$CANDIDATE_MERGE_TREE" \
	--argjson safe_states "$safe_states" \
	--argjson safe_distinct "$safe_distinct" \
	--argjson safe_depth "$safe_depth" \
	--argjson unsafe_count "$unsafe_count" '
  {
    schema_version: 1,
    id: "sched-exec-lease-p5a-r6-post-e3-authorization-threat-boundary-result-v1",
    run_id: $run_id,
    status: "passed_scoped_r6_e3_synthetic_acceptance_and_r6_e4_plan_draft_authorization",
    runner_sha256: $runner_sha,
    authorization_config_sha256: "2d9bad93604051f6d6bbf90f0cec619cc237e311235ce3fa1e2ffbab56d10e03",
    threat_model_target: "target_sha256_00f33333870097e986c36684a58470fe51e779600219938b209ca597ae663190",
    threat_model_version: "5e4121e614ba0745c0857f4cfbb0d4191fd4f3b6",
    threat_model_sha256: "c26d7710338413408f8242da7fd1e58a0805ed95b85970a7db7a44a0e1f49050",
    formal_model_manifest_sha256: "6ea9e39bb2f0cf041ea3f8904671ecefe0811778a311a5e5a10a8244b0579c18",
    candidate_commit: $candidate,
    current_upstream_commit: $upstream,
    candidate_merge_tree: $merge_tree,
    upstream_advance_commits: 543,
    upstream_touched_paths: ["init/Kconfig"],
    upstream_drift_observed_and_classified: true,
    private_source_scope_unchanged_after_merge: true,
    global_upstream_freshness_claim: false,
    source_gate_passed: true,
    four_profile_matrix_passed: true,
    independent_closure_passed_twice: true,
    profiles: 4,
    fresh_builds: 4,
    virtual_boots: 4,
    total_cases_passed: 220,
    total_receipts: 220,
    failures_skips_timeouts_warnings: 0,
    formal: {
      safe_states_generated: $safe_states,
      safe_distinct_states: $safe_distinct,
      safe_depth: $safe_depth,
      unsafe_counterexamples: $unsafe_count
    },
    exact_r6_e3_source_accepted: true,
    exact_r6_e3_synthetic_correctness_accepted: true,
    r6_e4_source_free_plan_may_be_drafted: true,
    r6_e4_plan_accepted: false,
    r6_e4_source_may_be_created: false,
    live_scheduler_attachment: false,
    primary_linux_may_change: false,
    patch_queue_may_change: false,
    runtime_scheduler_hook_approved: false,
    runtime_behavior_approved: false,
    runtime_denial_correctness: false,
    runtime_coverage: false,
    runtime_budget_conflated: false,
    async_service_boundary_validated: false,
    memoryview_or_tlb_validated: false,
    device_dma_iommu_validated: false,
    monitor_verified: false,
    cluster_authority_validated: false,
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
sha256sum "$OUT_DIR/result.json" > "$OUT_DIR/result.sha256"
progress '100% scoped R6-E3 acceptance complete; only source-free R6-E4 planning authorized'
