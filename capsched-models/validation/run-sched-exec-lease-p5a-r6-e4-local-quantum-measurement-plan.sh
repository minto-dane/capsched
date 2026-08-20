#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
PRIMARY_DIR="$WORKSPACE_DIR/linux"
CANDIDATE_DIR="$WORKSPACE_DIR/build/DomainLeaseLinux.volume/worktrees/p5a-r6-e3-correctness-prototype"
PATCH_QUEUE_DIR="$WORKSPACE_DIR/linux-patches"

CANONICAL_CONFIG="$CAPSCHED_DIR/capsched-models/analysis/sched-exec-lease-p5a-r6-e4-local-quantum-measurement-plan-v1.json"
PLAN="$CAPSCHED_DIR/capsched-models/analysis/0183-sched-exec-lease-p5a-r6-e4-local-quantum-measurement-plan.md"
THREAT_MODEL="$CAPSCHED_DIR/capsched-models/assurance/linux-cap-repository-threat-model.md"
E1_CONTRACT="$CAPSCHED_DIR/capsched-models/analysis/sched-exec-lease-p5a-r6-e1-domain-forest-evidence-plan-v1.json"
E3_PLAN="$CAPSCHED_DIR/capsched-models/analysis/sched-exec-lease-p5a-r6-e3-correctness-concurrency-evidence-plan-v1.json"
E3_IMPLEMENTATION="$CAPSCHED_DIR/capsched-models/implementation/sched-exec-lease-p5a-r6-e3-domain-forest-correctness-prototype-v1.json"
POST_AUTH_CONFIG="$CAPSCHED_DIR/capsched-models/analysis/sched-exec-lease-p5a-r6-post-e3-authorization-threat-boundary-v1.json"
POST_AUTH_NOTE="$CAPSCHED_DIR/capsched-models/validation/0282-sched-exec-lease-p5a-r6-post-e3-authorization-threat-boundary.md"
CLAIM_LEDGER="$CAPSCHED_DIR/capsched-models/analysis/implementation-claim-ledger-gate-v1.json"
RUNTIME_CHARGE="$CAPSCHED_DIR/capsched-models/analysis/runtime-charge-subject-v1.json"
RUNTIME_VALIDATION="$CAPSCHED_DIR/capsched-models/validation/0107-runtime-charge-subject-tlc.md"
SOURCE_GATE="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r6-e3-correctness-source-gate/20260726T-p5a-r6-e3-source-gate-r1/result.json"
FOUR_PROFILE="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r6-e3-four-profile-diagnostic-matrix/20260726T-p5a-r6-e3-four-profile-r1/result.json"
CLOSURE_R1="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r6-e3-four-profile-evidence-closure/20260726T-p5a-r6-e3-four-profile-closure-r1/result.json"
CLOSURE_R2="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r6-e3-four-profile-evidence-closure/20260726T-p5a-r6-e3-four-profile-closure-r2/result.json"
AUTH_R1="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r6-post-e3-authorization-threat-boundary/20260726T-p5a-r6-post-e3-authorization-r1/result.json"
AUTH_R2="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r6-post-e3-authorization-threat-boundary/20260726T-p5a-r6-post-e3-authorization-r2/result.json"

MODEL_DIR="$CAPSCHED_DIR/capsched-models/formal/0146-p5a-r6-e4-local-quantum-measurement-plan-model"
MODEL=P5AR6E4LocalQuantumMeasurementPlan.tla
SAFE_CFG=P5AR6E4LocalQuantumMeasurementPlanSafe.cfg
TLA_JAR=${TLA_JAR:-"$WORKSPACE_DIR/build/tools/tla/tla2tools.jar"}

RUN_ID=${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
PROGRESS_FILE=${PROGRESS_FILE:-}
PLAN_TEST_MODE=${PLAN_TEST_MODE:-0}
CONFIG_OVERRIDE=${CONFIG_OVERRIDE:-}
TEST_CONFIG_SHA=${TEST_CONFIG_SHA:-}
OFFLINE_TEST_MODE=${OFFLINE_TEST_MODE:-0}
PREFLIGHT_ONLY=${PREFLIGHT_ONLY:-0}

CONFIG_SHA=8c3838e38568c780fb1e02c6ffc839de66b121af564bea47d45c289858667dc3
PLAN_SHA=e4c10f61e97a98ca76567ba0df23ca3542462187070384d8ce27cd578e3be2f7
THREAT_MODEL_SHA=262f609a04b1da7b87562b48e42e9674e91151ed8ccdaaef3bc88596795e997d
E1_CONTRACT_SHA=7a019076c860ea24ed7c397bb9ccd7feeebd8b0cdeaa6ed6210d8ba1bc13f401
E3_PLAN_SHA=36f5d2b0423d1a4f6de05e08ac4166e098bb7e7680ce81758b361187dc0e8d22
E3_IMPLEMENTATION_SHA=7d58755a4fa825e70ede8b4c25563fea0369f3799da5afeb1ecc8d8ab15d5954
POST_AUTH_CONFIG_SHA=2d9bad93604051f6d6bbf90f0cec619cc237e311235ce3fa1e2ffbab56d10e03
POST_AUTH_NOTE_SHA=133fffbd416022872919c748f026dfb5f8e52eb106aac70fd8b9b795e9a1ebda
CLAIM_LEDGER_SHA=d957db92654459c9298d252bdae0a92ef7de5b85918c24bcf4cc083c324e5adb
RUNTIME_CHARGE_SHA=d1dff5ebb6721575bf0c26c60d913eb5a9a5d95c179fba71969e3b7cb2d11065
RUNTIME_VALIDATION_SHA=be3e6159da5cccdd5996bb5d434f81e492aae37963d4af8f193d541e58de1f38
SOURCE_GATE_SHA=88376403879ecc2b0a059791ba59a5bd71addd493e9c8052c2742f877f9e7f25
FOUR_PROFILE_SHA=bede4cbf4c5021eba080d0bd557f9e97529153e21da731ee729340ca8c2691be
CLOSURE_R1_SHA=0dce94b2ddf3448727bf936611704e33637f9114e8668cf1311aa1274775239a
CLOSURE_R2_SHA=964a16b0636d7f02850b851dd1530e9c08cc6c9e0c495c6b6a3ba78a1856a514
CLOSURE_NORMALIZED_SHA=3aebe14122f4b678c56351ee07f6a0ad475f708156c3657032232b9a76c761f7
AUTH_R1_SHA=7fe89e294603a5fc1b33b03d55087b8f0619db862d5a24ec5f0fa3b201119fb6
AUTH_R2_SHA=d8b420d729ae75243328eae183210b410daf812780cfd420a7b0f43a0f481c4b
AUTH_NORMALIZED_SHA=4104da3da3ad8f76b160d45f3ffe371aa70d2c2c0d06663194989d77999e3920
FORMAL_MANIFEST_SHA=f9e65914e00df5886fed41f70b058cc475588564482fdb22b361cdb158c01e0d

ROOT_BASIS=25e925f5364b967e4a7a9d44787e9c0a9ca6cf5b
CAPSCHED_BASIS=9718f42f919ff70eeef81d125de193a8cfda9ba8
PRIMARY_COMMIT=5e1ca3037e34823d1ba0cdd1dc04161fac170280
PATCH_QUEUE_COMMIT=16bb080da472ffabbbafd2698073eca633fb0602
PATCH_QUEUE_SERIES_BLOB=298567f8e0bd18168222da4e64da32750b9ea818
CANDIDATE_PARENT=66e2fd20fc85012d7dc03649fcf4c7af583cbb94
CANDIDATE_COMMIT=99287291f1c8e0d6c1b3ea86d121508c5547f424
CANDIDATE_TREE=2b863b57dfe3f03609ad1a73c965874f71056e8f
CANDIDATE_DIFF_SHA=2ed265756c1cee52252bedc6cbfb3d651eed136be9dca98992496ee80ebfb715
PREVIOUS_UPSTREAM=3dab139d4795f688e4f243e40c7474df00d329d9
CURRENT_UPSTREAM=f5098b6bae761e346ebcd9da7f95622c04733cff
UPSTREAM_ADVANCE=108
CANDIDATE_MERGE_BASE=4edcdefd4083ae04b1a5656f4be6cd83ae919ef4
CANDIDATE_MERGE_TREE=2c227949b04877f404dd8beff0012fdcf05c39b2
EMPTY_SHA=e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
MERGE_BASE_TOUCHED_DIFF_SHA=2bf818b0a62bcb092a7a15c302a43bf6def37eb56f00d956aacd72de6a72e952
PRIVATE_KCONFIG_BLOCK_SHA=93bd31e2477cd4c0ac499ffc50fbd2000b79918ec7047a02b57cd19eea6b089a

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

for command_name in awk basename chmod cmp cp find git grep java jq mkdir \
	mv nproc sed sha256sum sort tail tr wc xargs; do
	command -v "$command_name" >/dev/null 2>&1 ||
		die "missing command: $command_name"
done
capsched_validate_run_id "$RUN_ID" || die 'invalid RUN_ID'
if [ ! -f "$TLA_JAR" ] || [ -L "$TLA_JAR" ]; then
	die "missing or unsafe TLA jar: $TLA_JAR"
fi

case "$PLAN_TEST_MODE:$PREFLIGHT_ONLY" in
	0:0|1:1) ;;
	*) die 'test mode and preflight mode must be enabled together' ;;
esac
if [ "$PLAN_TEST_MODE" = 1 ]; then
	[ -n "$CONFIG_OVERRIDE" ] || die 'test mode requires CONFIG_OVERRIDE'
	[ -n "$TEST_CONFIG_SHA" ] || die 'test mode requires TEST_CONFIG_SHA'
	[ "$OFFLINE_TEST_MODE" = 1 ] ||
		die 'test mode requires OFFLINE_TEST_MODE=1'
	CONFIG_SOURCE=$CONFIG_OVERRIDE
	EXPECTED_CONFIG_SHA=$TEST_CONFIG_SHA
	OUT_ROOT="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r6-e4-local-quantum-measurement-plan-test"
else
	[ -z "$CONFIG_OVERRIDE" ] || die 'CONFIG_OVERRIDE is restricted to test mode'
	[ -z "$TEST_CONFIG_SHA" ] || die 'TEST_CONFIG_SHA is restricted to test mode'
	[ "$OFFLINE_TEST_MODE" = 0 ] || die 'offline mode is restricted to tests'
	CONFIG_SOURCE=$CANONICAL_CONFIG
	EXPECTED_CONFIG_SHA=$CONFIG_SHA
	OUT_ROOT="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r6-e4-local-quantum-measurement-plan"
fi
if [ ! -f "$CONFIG_SOURCE" ] || [ -L "$CONFIG_SOURCE" ]; then
	die 'config must be a regular non-symlink file'
fi

capsched_create_fresh_run_dir "$OUT_ROOT" "$RUN_ID" ||
	die 'run output already exists or is unsafe'
OUT_DIR="$OUT_ROOT/$RUN_ID"
mkdir "$OUT_DIR/inputs" "$OUT_DIR/formal" "$OUT_DIR/generated-unsafe-configs" \
	"$OUT_DIR/git"

progress '4% snapshotting plan, threat model, and immutable evidence'
snapshot "$CONFIG_SOURCE" "$EXPECTED_CONFIG_SHA" "$OUT_DIR/inputs/config.json"
snapshot "$PLAN" "$PLAN_SHA" "$OUT_DIR/inputs/plan.md"
snapshot "$THREAT_MODEL" "$THREAT_MODEL_SHA" "$OUT_DIR/inputs/threat-model.md"
snapshot "$E1_CONTRACT" "$E1_CONTRACT_SHA" "$OUT_DIR/inputs/e1-contract.json"
snapshot "$E3_PLAN" "$E3_PLAN_SHA" "$OUT_DIR/inputs/e3-plan.json"
snapshot "$E3_IMPLEMENTATION" "$E3_IMPLEMENTATION_SHA" "$OUT_DIR/inputs/e3-implementation.json"
snapshot "$POST_AUTH_CONFIG" "$POST_AUTH_CONFIG_SHA" "$OUT_DIR/inputs/post-auth-config.json"
snapshot "$POST_AUTH_NOTE" "$POST_AUTH_NOTE_SHA" "$OUT_DIR/inputs/post-auth-note.md"
snapshot "$CLAIM_LEDGER" "$CLAIM_LEDGER_SHA" "$OUT_DIR/inputs/claim-ledger.json"
snapshot "$RUNTIME_CHARGE" "$RUNTIME_CHARGE_SHA" "$OUT_DIR/inputs/runtime-charge.json"
snapshot "$RUNTIME_VALIDATION" "$RUNTIME_VALIDATION_SHA" "$OUT_DIR/inputs/runtime-validation.md"
snapshot "$SOURCE_GATE" "$SOURCE_GATE_SHA" "$OUT_DIR/inputs/source-gate.json"
snapshot "$FOUR_PROFILE" "$FOUR_PROFILE_SHA" "$OUT_DIR/inputs/four-profile.json"
snapshot "$CLOSURE_R1" "$CLOSURE_R1_SHA" "$OUT_DIR/inputs/closure-r1.json"
snapshot "$CLOSURE_R2" "$CLOSURE_R2_SHA" "$OUT_DIR/inputs/closure-r2.json"
snapshot "$AUTH_R1" "$AUTH_R1_SHA" "$OUT_DIR/inputs/auth-r1.json"
snapshot "$AUTH_R2" "$AUTH_R2_SHA" "$OUT_DIR/inputs/auth-r2.json"
CONFIG="$OUT_DIR/inputs/config.json"
for input_json in "$CONFIG" "$OUT_DIR/inputs/e1-contract.json" \
	"$OUT_DIR/inputs/e3-plan.json" "$OUT_DIR/inputs/e3-implementation.json" \
	"$OUT_DIR/inputs/post-auth-config.json" "$OUT_DIR/inputs/claim-ledger.json" \
	"$OUT_DIR/inputs/runtime-charge.json" "$OUT_DIR/inputs/source-gate.json" \
	"$OUT_DIR/inputs/four-profile.json" "$OUT_DIR/inputs/closure-r1.json" \
	"$OUT_DIR/inputs/closure-r2.json" "$OUT_DIR/inputs/auth-r1.json" \
	"$OUT_DIR/inputs/auth-r2.json"; do
	jq empty "$input_json"
done

progress '12% validating the exact 855-cell rejection contract'
jq -e '
  .schema_version == 1 and
  .status == "r6_e4_source_free_local_quantum_measurement_pre_source_plan" and
  .prerequisite.root_commit == "25e925f5364b967e4a7a9d44787e9c0a9ca6cf5b" and
  .prerequisite.capsched_commit == "9718f42f919ff70eeef81d125de193a8cfda9ba8" and
  .prerequisite.threat_model_sha256 == "262f609a04b1da7b87562b48e42e9674e91151ed8ccdaaef3bc88596795e997d" and
  .prerequisite.threat_model_version == "25e925f5364b967e4a7a9d44787e9c0a9ca6cf5b" and
  .prerequisite.r6_e1_contract_sha256 == "7a019076c860ea24ed7c397bb9ccd7feeebd8b0cdeaa6ed6210d8ba1bc13f401" and
  .prerequisite.r6_e3_plan_sha256 == "36f5d2b0423d1a4f6de05e08ac4166e098bb7e7680ce81758b361187dc0e8d22" and
  .prerequisite.r6_e3_implementation_sha256 == "7d58755a4fa825e70ede8b4c25563fea0369f3799da5afeb1ecc8d8ab15d5954" and
  .prerequisite.r6_e3_source_gate_sha256 == "88376403879ecc2b0a059791ba59a5bd71addd493e9c8052c2742f877f9e7f25" and
  .prerequisite.r6_e3_four_profile_sha256 == "bede4cbf4c5021eba080d0bd557f9e97529153e21da731ee729340ca8c2691be" and
  .prerequisite.r6_e3_profile_results_sha256 == "9142a2a0ff800efbf2e9f5b5231575b6c6c47d26e14ca535265f81221e802b71" and
  .prerequisite.r6_e3_closure_normalized_sha256 == "3aebe14122f4b678c56351ee07f6a0ad475f708156c3657032232b9a76c761f7" and
  .prerequisite.post_e3_authorization_config_sha256 == "2d9bad93604051f6d6bbf90f0cec619cc237e311235ce3fa1e2ffbab56d10e03" and
  .prerequisite.post_e3_authorization_normalized_sha256 == "4104da3da3ad8f76b160d45f3ffe371aa70d2c2c0d06663194989d77999e3920" and
  .prerequisite.exact_r6_e3_source_accepted == true and
  .prerequisite.exact_r6_e3_synthetic_correctness_accepted == true and
  .prerequisite.r6_e4_plan_drafting_authorized == true and
  .prerequisite.r6_e4_plan_already_accepted == false and
  .prerequisite.r6_e4_source_already_authorized == false and
  .source.future_parent == "99287291f1c8e0d6c1b3ea86d121508c5547f424" and
  .source.direct_child_required == true and
  .source.allowed_files == ["init/Kconfig","kernel/sched/exec_lease.c"] and
  (.source.frozen_files | length) == 7 and
  .source.e2_private_values_preserved == 49 and
  .source.existing_expanded_values_preserved == 51 and
  .source.e3_case_families_preserved == 55 and
  .source.e3_stress_repetitions_preserved == 4096 and
  .source.e3_oracle_and_receipts_preserved == true and
  .source.measurement_only_brackets_allowed == true and
  .source.cheaper_timing_substitute_allowed == false and
  .source.shared_helper_if_extracted_required == true and
  .source.e3_matrix_rerun_after_helper_change_required == true and
  .source.ordinary_structure_growth_bytes == 0 and
  .source.primary_linux_change_allowed == false and
  .source.patch_queue_change_allowed == false and
  .upstream_drift_freshness.current_observed_commit == "f5098b6bae761e346ebcd9da7f95622c04733cff" and
  .upstream_drift_freshness.advanced_commit_count == 108 and
  .upstream_drift_freshness.touched_paths_since_previous == [] and
  .upstream_drift_freshness.touched_paths_since_merge_base == ["init/Kconfig"] and
  .upstream_drift_freshness.merge_tree_clean == true and
  .upstream_drift_freshness.previously_classified_init_kconfig_drift_still_unrelated == true and
  .upstream_drift_freshness.private_exec_lease_absent_upstream == true and
  .upstream_drift_freshness.global_upstream_freshness_claim == false and
  .configuration.name == "SCHED_EXEC_LEASE_R6_MEASURE_KUNIT_TEST" and
  .configuration.type == "bool" and .configuration.default_enabled == false and
  .configuration.depends_on == ["SCHED_EXEC_LEASE_R6_KUNIT_TEST","KUNIT=y"] and
  .configuration.same_translation_unit == "kernel/sched/exec_lease.c" and
  .configuration.suite_name == "sched_exec_lease_r6_measure" and
  ([.configuration.selected_by_ordinary_lease,.configuration.selected_by_layout_probe,
    .configuration.selected_by_e3_test,.configuration.selected_by_kunit_all_tests] | all(. == false)) and
  .configuration.disabled_symbols_relocations_strings_initcalls_timestamp_or_rows == 0 and
  .fixture.exact_e3_private_types == true and
  .fixture.existing_e3_helpers_unchanged_or_shared == true and
  .fixture.real_raw_spinlocks == true and
  .fixture.real_rcu_refcounts_cpumasks == true and
  .fixture.synthetic_scheduler_inputs == true and
  .fixture.all_storage_preallocated == true and
  .fixture.quiescent_reset_after_every_pair == true and
  .fixture.untimed_oracle_and_operation_count_per_cell == true and
  ([.fixture.registered_with_live_scheduler,
    .fixture.live_rq_cfs_rq_task_group_or_cgroup_attachment,
    .fixture.ordinary_scheduler_state_modified,
    .fixture.monitor_policy_budget_or_authority_decision] | all(. == false)) and
  .common_measurement.clock == "local_clock" and
  .common_measurement.single_pinned_vcpu == true and
  .common_measurement.local_irq_state_recorded == true and
  .common_measurement.exact_operation_locks_required == true and
  .common_measurement.paired_empty_control == true and
  .common_measurement.same_lock_irq_timestamp_barrier_shell_in_control == true and
  .common_measurement.alternating_pair_order == true and
  .common_measurement.additional_formula == "max(treatment_ns-control_ns,0)" and
  .common_measurement.negative_difference_wrap_allowed == false and
  .common_measurement.minimum_warmup_pairs_per_cell == 256 and
  .common_measurement.measured_pairs_per_cell == 10000 and
  .common_measurement.statistics == ["minimum","p50","p95","p99","p999","maximum"] and
  .common_measurement.nearest_rank_documented == true and
  .common_measurement.allocation_free_sort_print_trace_assert_sleep_reschedule_topology_policy_monitor_inside_local_interval == false and
  .common_measurement.clock_regression_allowed == false and
  .common_measurement.observed_vcpu_migration_allowed == false and
  .common_measurement.exact_raw_treatment_control_additional_rows_required == true and
  .common_measurement.deterministic_lossless_compression_after_hash_and_closure_allowed == true and
  .common_measurement.rounding_aggregation_or_raw_row_discard_allowed == false and
  .thresholds == {
    ordinary_additional_p99_limit_ns:5000,
    ordinary_additional_p999_limit_ns:25000,
    ordinary_additional_max_limit_ns:50000,
    offline_locked_additional_p99_limit_ns:25000,
    offline_locked_additional_p999_limit_ns:40000,
    offline_locked_additional_max_limit_ns:50000,
    normalized_base_slice_ns:700000,
    sample_may_reach_base_slice:false,
    current_observation_p99_limit_ns:10000000,
    current_observation_max_limit_ns:100000000,
    offline_sleepable_drain_p99_limit_ns:10000000,
    offline_sleepable_drain_max_limit_ns:100000000,
    availability_calibration_is_runtime_slo:false,
    base_slice_is_budget_or_deadline:false
  } and
  (.mask_patterns | length) == 9 and (.mask_patterns | unique | length) == 9 and
  .families.descriptor_publication.active_slots == [0,1,8,32,64] and
  .families.descriptor_publication.publication_burst == [1,64,4096] and
  .families.descriptor_publication.cell_count == 135 and
  .families.descriptor_publication.descriptor_pointer_publications_per_treatment == 1 and
  .families.descriptor_publication.slot_task_tree_cgroup_rq_history_visits == 0 and
  .families.descriptor_publication.allocation_wait_retry_or_grace_inside_interval == false and
  .families.leaf_six_ancestors.active_slots == [1,8,32,64] and
  .families.leaf_six_ancestors.slot_position == [0,1,31,62,63] and
  (.families.leaf_six_ancestors.transition | length) == 4 and
  .families.leaf_six_ancestors.cell_count == 80 and
  .families.leaf_six_ancestors.leaf_recomputes == 1 and
  .families.leaf_six_ancestors.ancestor_recomputes_max == 6 and
  .families.leaf_six_ancestors.unique_nodes_max == 7 and
  .families.leaf_six_ancestors.sibling_or_inner_task_scan_allowed == false and
  .families.aggregate_127.active_slots == [0,1,8,32,64] and
  .families.aggregate_127.allowed_mask_patterns == 9 and
  .families.aggregate_127.cell_count == 45 and
  .families.aggregate_127.unique_node_visits_max == 127 and
  .families.aggregate_127.slot_local_task_queue_entry_allowed == false and
  .families.candidate_127.active_slots == [0,1,8,32,64] and
  .families.candidate_127.allowed_mask_patterns == 9 and
  .families.candidate_127.current_slot == ["none",0,31,63] and
  .families.candidate_127.cell_count == 180 and
  .families.candidate_127.unique_node_visits_max == 127 and
  .families.candidate_127.stable_slot_id_tie_break == true and
  .families.candidate_127.denied_or_ineligible_return_allowed == false and
  .families.complete_query_254.cell_count == 45 and
  .families.complete_query_254.aggregate_invocations == 1 and
  .families.complete_query_254.candidate_invocations == 1 and
  .families.complete_query_254.combined_unique_node_visits_max == 254 and
  .families.complete_query_254.logarithmic_arbitrary_mask_claim == false and
  .families.mask_reconcile_64.newly_allowed_bits == [0,1,8,32,63,64] and
  .families.mask_reconcile_64.active_slots == [0,1,8,32,64] and
  (.families.mask_reconcile_64.placement_pattern | length) == 4 and
  .families.mask_reconcile_64.cell_count == 120 and
  .families.mask_reconcile_64.slot_visits_exact == 64 and
  .families.mask_reconcile_64.only_newly_allowed_may_clamp_and_update == true and
  .families.mask_reconcile_64.task_cgroup_arbitrary_rq_or_history_scan_allowed == false and
  .families.slot_local_handoff_final_task_check.inner_task_count == [1,8,64,4096] and
  .families.slot_local_handoff_final_task_check.descendant_cgroup_depth == [0,1,4,8] and
  (.families.slot_local_handoff_final_task_check.final_check_outcome | length) == 6 and
  .families.slot_local_handoff_final_task_check.cell_count == 96 and
  .families.slot_local_handoff_final_task_check.ordinary_linux_eevdf_pick_inside_additional_interval == false and
  .families.slot_local_handoff_final_task_check.ordinary_linux_eevdf_is_unchanged_baseline == true and
  .families.slot_local_handoff_final_task_check.pick_eevdf_latency_or_improvement_claim == false and
  .families.slot_local_handoff_final_task_check.exact_final_descriptor_generation_domain_slot_root_mask_cpu_online_accepting_check == true and
  .families.slot_local_handoff_final_task_check.inner_count_or_depth_may_change_authorization_work_count == false and
  .families.revoked_current_request_observation.current_slot == [0,31,63] and
  (.families.revoked_current_request_observation.observation_outcome | length) == 2 and
  .families.revoked_current_request_observation.publication_burst == [1,64,4096] and
  (.families.revoked_current_request_observation.allowed_mask_class | length) == 3 and
  .families.revoked_current_request_observation.cell_count == 54 and
  .families.revoked_current_request_observation.request_issue_under_one_synthetic_rq_lock == true and
  .families.revoked_current_request_observation.later_distinct_observation_required == true and
  .families.revoked_current_request_observation.request_observation_sequences_strictly_ordered == true and
  .families.revoked_current_request_observation.request_is_monitor_interrupt_completion_or_revocation_guarantee == false and
  .families.offline_visibility_and_drain.active_slots == [0,1,8,32,64] and
  .families.offline_visibility_and_drain.current_slot == ["none",0,31,63] and
  (.families.offline_visibility_and_drain.ownership_state | length) == 5 and
  .families.offline_visibility_and_drain.cell_count == 100 and
  .families.offline_visibility_and_drain.clears_accepting_and_visibility_first == true and
  .families.offline_visibility_and_drain.sleepable_wait_inside_locked_interval == false and
  .families.offline_visibility_and_drain.sleepable_drain_outside_scheduler_locks == true and
  .families.offline_visibility_and_drain.terminal_zero_contributions_readers_refs_transitions_current_required == true and
  .families.offline_visibility_and_drain.rcu_unpublish_grace_before_free == true and
  ([.families[] | .cell_count] | add) == 855 and
  .matrix == {
    descriptor_publication_cells:135,
    leaf_six_ancestors_cells:80,
    aggregate_cells:45,
    candidate_cells:180,
    complete_query_cells:45,
    mask_reconcile_cells:120,
    slot_local_handoff_final_check_cells:96,
    revoked_current_cells:54,
    offline_cells:100,
    total_cells:855,
    measured_pairs_per_cell:10000,
    total_measured_pairs:8550000,
    all_cells_required:true,
    range_reduction_after_failure_allowed:false
  } and
  .diagnostics.architectures == ["arm64","x86_64"] and
  .diagnostics.arm64_runs_first == true and
  .diagnostics.x86_64_runs_only_after_arm64_pass == true and
  .diagnostics.same_source_identity_required == true and
  .diagnostics.disabled_enabled_and_release_builds_per_architecture == true and
  .diagnostics.e3_four_profile_regression_after_shared_helper_change_required == true and
  .diagnostics.sanitizers_and_lockdep_are_separate_diagnostics_not_timing == true and
  .diagnostics.warning_reports_allowed == 0 and
  .diagnostics.sequential_build_retirement_after_seal == true and
  .diagnostics.virtual_result_supports_bare_metal_claim == false and
  .classification.valid_results == ["passed_virtual_r6_e4_local_quantum_compatibility","rejected_r6_e4_local_quantum_measurement"] and
  .classification.invalid_result == "harness_failed" and
  .classification.threshold_failure_is_valid_negative_evidence == true and
  .classification.missing_reduced_malformed_mutated_or_warning_evidence_is_harness_failure == true and
  .classification.complete_arm64_rejection_stops_r6_and_x86_64 == true and
  .classification.passed_arm64_authorizes_only_same_source_x86_64 == true and
  .classification.two_architecture_same_source_and_two_independent_closures_required_for_virtual_compatibility == true and
  .classification.post_e4_review_required == true and
  .classification.r6_behavior_source_authorized == false and
  .classification.global_settlement_or_continuous_publication_liveness_claim == false and
  .separate_runtime_budget_boundary.runtime_budget_hook_allowed == false and
  .separate_runtime_budget_boundary.runtime_coverage == false and
  .separate_runtime_budget_boundary.satisfied_by_measurement_plan == false and
  .formal.manifest_sha256 == "f9e65914e00df5886fed41f70b058cc475588564482fdb22b361cdb158c01e0d" and
  .formal.safe_expected_states == 14 and .formal.safe_expected_distinct_states == 14 and
  .formal.safe_expected_depth == 14 and
  (.formal.unsafe_safety_faults | length) == 82 and
  (.formal.unsafe_safety_faults | unique | length) == 82 and
  (.formal.unsafe_liveness_faults | length) == 2 and
  (.formal.unsafe_liveness_faults | unique | length) == 2 and
  .authorization_after_plan_pass.r6_e4_plan_accepted == true and
  .authorization_after_plan_pass.exact_disposable_e4_source_draft_may_start == true and
  .authorization_after_plan_pass.e4_measurement_may_start_before_source_gate == false and
  .authorization_after_plan_pass.e4_source_or_measurement_accepted == false and
  .authorization_after_plan_pass.r6_behavior_source_may_be_created == false and
  .authorization_after_plan_pass.live_scheduler_attachment_allowed == false and
  .authorization_after_plan_pass.primary_linux_may_change == false and
  .authorization_after_plan_pass.patch_queue_may_change == false and
  (.source_anchors | length) == 24 and (.source_anchors | map(.id) | unique | length) == 24 and
  (.future_absence_checks | length) == 8 and
  (.future_absence_checks | map(.id) | unique | length) == 8 and
  all(.safety_flags[]; . == false)
' "$CONFIG" >/dev/null || die 'R6-E4 plan contract changed'

progress '25% checking exact claim-ledger and closed post-E3 authorization'
jq -S '.required_claim_ledger_row_fields | sort' \
	"$OUT_DIR/inputs/claim-ledger.json" > "$OUT_DIR/required-ledger-keys.json"
jq -S '.claim_ledger_row | keys | sort' "$CONFIG" \
	> "$OUT_DIR/actual-ledger-keys.json"
cmp "$OUT_DIR/required-ledger-keys.json" "$OUT_DIR/actual-ledger-keys.json" \
	>/dev/null || die 'claim-ledger row does not contain exactly 14 fields'
jq -e '
  .claim_ledger_row.proposal_id ==
    "sched-exec-lease-p5a-r6-e4-local-quantum-measurement-plan-v1" and
  .claim_ledger_row.slice_id == "P5A-R6-E4" and
  .claim_ledger_row.behavior_mode ==
    "default_off_same_translation_unit_virtual_synthetic_measurement_only" and
  (.claim_ledger_row.supported_claims | length) == 1 and
  (.claim_ledger_row.forbidden_claims | length) == 7 and
  (.claim_ledger_row.open_gaps | length) == 7 and
  (.claim_ledger_row.required_validation_before_review | length) == 4 and
  (.claim_ledger_row.required_validation_before_acceptance | length) == 4 and
  .claim_ledger_row.upstream_drift_freshness.upstream_commit ==
    "f5098b6bae761e346ebcd9da7f95622c04733cff" and
  .claim_ledger_row.upstream_drift_freshness.touched_paths_since_previous == [] and
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
for auth in "$OUT_DIR/inputs/auth-r1.json" "$OUT_DIR/inputs/auth-r2.json"; do
	jq -e '
    .status == "passed_scoped_r6_e3_synthetic_acceptance_and_r6_e4_plan_draft_authorization" and
    .candidate_commit == "99287291f1c8e0d6c1b3ea86d121508c5547f424" and
    .source_gate_passed == true and .four_profile_matrix_passed == true and
    .independent_closure_passed_twice == true and
    .total_cases_passed == 220 and .total_receipts == 220 and
    .failures_skips_timeouts_warnings == 0 and
    .exact_r6_e3_source_accepted == true and
    .exact_r6_e3_synthetic_correctness_accepted == true and
    .r6_e4_source_free_plan_may_be_drafted == true and
    .r6_e4_plan_accepted == false and .r6_e4_source_may_be_created == false and
    .live_scheduler_attachment == false and .runtime_behavior_approved == false and
    .monitor_verified == false and .production_protection == false and
    .multi_cluster_ready == false and .datacenter_ready == false
  ' "$auth" >/dev/null
done
normalized_auth_r1=$(jq -S 'del(.run_id)' "$OUT_DIR/inputs/auth-r1.json" |
	sha256sum | awk '{print $1}')
normalized_auth_r2=$(jq -S 'del(.run_id)' "$OUT_DIR/inputs/auth-r2.json" |
	sha256sum | awk '{print $1}')
[ "$normalized_auth_r1" = "$AUTH_NORMALIZED_SHA" ] ||
	die 'post-E3 authorization r1 normalized hash changed'
[ "$normalized_auth_r2" = "$AUTH_NORMALIZED_SHA" ] ||
	die 'post-E3 authorization r2 normalized hash changed'
normalized_closure_r1=$(jq -S 'del(.run_id)' "$OUT_DIR/inputs/closure-r1.json" |
	sha256sum | awk '{print $1}')
normalized_closure_r2=$(jq -S 'del(.run_id)' "$OUT_DIR/inputs/closure-r2.json" |
	sha256sum | awk '{print $1}')
[ "$normalized_closure_r1" = "$CLOSURE_NORMALIZED_SHA" ] ||
	die 'E3 closure r1 normalized hash changed'
[ "$normalized_closure_r2" = "$CLOSURE_NORMALIZED_SHA" ] ||
	die 'E3 closure r2 normalized hash changed'

progress '35% verifying immutable Git identity and pre-source absence'
git -C "$WORKSPACE_DIR" merge-base --is-ancestor "$ROOT_BASIS" HEAD ||
	die 'root prerequisite commit is not an ancestor'
git -C "$CAPSCHED_DIR" merge-base --is-ancestor "$CAPSCHED_BASIS" HEAD ||
	die 'capsched prerequisite commit is not an ancestor'
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
	die 'R6-E3 candidate worktree moved'
[ -z "$(git -C "$CANDIDATE_DIR" status --porcelain=v1)" ] ||
	die 'R6-E3 candidate worktree is dirty'
[ "$(git -C "$PRIMARY_DIR" rev-parse "$CANDIDATE_COMMIT^")" = \
	"$CANDIDATE_PARENT" ] || die 'candidate parent moved'
[ "$(git -C "$PRIMARY_DIR" rev-parse "$CANDIDATE_COMMIT^{tree}")" = \
	"$CANDIDATE_TREE" ] || die 'candidate tree moved'
[ "$(git -C "$PRIMARY_DIR" rev-parse \
	refs/remotes/fork/codex/p5a-r6-e3-correctness-prototype)" = \
	"$CANDIDATE_COMMIT" ] || die 'local fork candidate tracking ref moved'
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
	die 'candidate scope moved'

printf 'id\tstatus\ttree\tpath\tpattern\n' > "$OUT_DIR/source-anchors.tsv"
while IFS=$'\t' read -r anchor_id tree_name file_path pattern; do
	case "$tree_name" in
		candidate) commit=$CANDIDATE_COMMIT ;;
		primary) commit=$PRIMARY_COMMIT ;;
		*) die "unknown source-anchor tree: $tree_name" ;;
	esac
	if git -C "$PRIMARY_DIR" grep -Fq "$pattern" "$commit" -- "$file_path"; then
		status=ok
	else
		status=missing
	fi
	printf '%s\t%s\t%s\t%s\t%s\n' "$anchor_id" "$status" "$tree_name" \
		"$file_path" "$pattern" >> "$OUT_DIR/source-anchors.tsv"
done < <(jq -r '.source_anchors[] | [.id,.tree,.path,.pattern] | @tsv' "$CONFIG")
anchor_failures=$(awk -F '\t' \
	'NR > 1 && $2 != "ok" {n++} END {print n+0}' \
	"$OUT_DIR/source-anchors.tsv")
[ "$anchor_failures" = 0 ] || die "source anchor failures: $anchor_failures"

printf 'id\tstatus\tpattern\n' > "$OUT_DIR/future-absence.tsv"
while IFS=$'\t' read -r absence_id pattern; do
	if git -C "$PRIMARY_DIR" grep -Fq "$pattern" "$CANDIDATE_COMMIT" -- \
		init/Kconfig kernel/sched/exec_lease.c; then
		status=unexpected-present
	else
		status=absent
	fi
	printf '%s\t%s\t%s\n' "$absence_id" "$status" "$pattern" \
		>> "$OUT_DIR/future-absence.tsv"
done < <(jq -r '.future_absence_checks[] | [.id,.pattern] | @tsv' "$CONFIG")
absence_failures=$(awk -F '\t' \
	'NR > 1 && $2 != "absent" {n++} END {print n+0}' \
	"$OUT_DIR/future-absence.tsv")
[ "$absence_failures" = 0 ] ||
	die "future E4 source is already present: $absence_failures patterns"

progress '48% recomputing current upstream drift and clean merge tree'
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
	> "$OUT_DIR/git/touched-since-previous.txt"
[ ! -s "$OUT_DIR/git/touched-since-previous.txt" ] ||
	die 'candidate paths changed since the post-E3 observation'
git -C "$PRIMARY_DIR" diff "$PREVIOUS_UPSTREAM" "$CURRENT_UPSTREAM" -- \
	init/Kconfig kernel/sched/exec_lease.c \
	> "$OUT_DIR/git/touched-since-previous.diff"
[ "$(capsched_sha256_file "$OUT_DIR/git/touched-since-previous.diff")" = \
	"$EMPTY_SHA" ] || die 'empty touched-path diff hash changed'
git -C "$PRIMARY_DIR" diff --name-only "$CANDIDATE_MERGE_BASE" \
	"$CURRENT_UPSTREAM" -- init/Kconfig kernel/sched/exec_lease.c \
	> "$OUT_DIR/git/touched-since-merge-base.txt"
printf '%s\n' init/Kconfig > "$OUT_DIR/git/expected-touched-since-merge-base.txt"
cmp "$OUT_DIR/git/expected-touched-since-merge-base.txt" \
	"$OUT_DIR/git/touched-since-merge-base.txt" >/dev/null ||
	die 'merge-base touched-path set moved'
git -C "$PRIMARY_DIR" diff "$CANDIDATE_MERGE_BASE" "$CURRENT_UPSTREAM" -- \
	init/Kconfig kernel/sched/exec_lease.c \
	> "$OUT_DIR/git/touched-since-merge-base.diff"
[ "$(capsched_sha256_file "$OUT_DIR/git/touched-since-merge-base.diff")" = \
	"$MERGE_BASE_TOUCHED_DIFF_SHA" ] || die 'classified Kconfig drift moved'
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
	progress '100% exact R6-E4 plan preflight passed'
	jq -n --arg run_id "$RUN_ID" '
	  {
	    schema_version:1,
	    id:"sched-exec-lease-p5a-r6-e4-local-quantum-measurement-plan-result-v1",
	    run_id:$run_id,
	    status:"passed_preflight_only",
	    formal_execution_omitted:true
	  }
	' > "$OUT_DIR/result.json"
	sha256sum "$OUT_DIR/result.json" > "$OUT_DIR/result.sha256"
	exit 0
fi

progress '60% snapshotting and executing the safe formal plan'
(
	cd "$MODEL_DIR"
	find . -maxdepth 1 -type f -print0 | sort -z | xargs -0 sha256sum
) > "$OUT_DIR/formal-source-manifest.sha256"
[ "$(capsched_sha256_file "$OUT_DIR/formal-source-manifest.sha256")" = \
	"$FORMAL_MANIFEST_SHA" ] || die 'formal source manifest moved'
while read -r expected file_path; do
	name=${file_path#./}
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
	die 'safe formal plan failed'
}
grep -q 'Checking 2 branches of temporal properties' "$OUT_DIR/tlc-safe.log" ||
	die 'safe temporal properties were not checked'
safe_states=$(sed -n 's/^\([0-9][0-9]*\) states generated.*/\1/p' \
	"$OUT_DIR/tlc-safe.log" | tail -1)
safe_distinct=$(sed -n \
	's/^[0-9][0-9]* states generated, \([0-9][0-9]*\) distinct states found.*/\1/p' \
	"$OUT_DIR/tlc-safe.log" | tail -1)
safe_depth=$(sed -n \
	's/^The depth of the complete state graph search is \([0-9][0-9]*\).*/\1/p' \
	"$OUT_DIR/tlc-safe.log" | tail -1)
[ "$safe_states" = 14 ] || die "unexpected safe states: $safe_states"
[ "$safe_distinct" = 14 ] || die "unexpected safe distinct states: $safe_distinct"
[ "$safe_depth" = 14 ] || die "unexpected safe depth: $safe_depth"

progress '70% reproducing 82 independent safety counterexamples'
tlc_parallel_jobs=${TLC_PARALLEL_JOBS:-$(nproc)}
case "$tlc_parallel_jobs" in
	''|*[!0-9]*) die 'TLC_PARALLEL_JOBS must be a positive integer' ;;
esac
[ "$tlc_parallel_jobs" -ge 1 ] ||
	die 'TLC_PARALLEL_JOBS must be a positive integer'
[ "$tlc_parallel_jobs" -le 6 ] || tlc_parallel_jobs=6

run_safety_fault()
{
	local fault=$1
	local cfg="$OUT_DIR/generated-unsafe-configs/safety-$fault.cfg"
	local log="$OUT_DIR/tlc-safety-$fault.log"
	local status_file="$OUT_DIR/status-safety-$fault"
	local java_tmp="$OUT_DIR/java-tmp-safety-$fault"

	mkdir "$java_tmp"
	printf '%s\n' \
		'SPECIFICATION Spec' \
		"CONSTANT Fault = \"$fault\"" \
		'CHECK_DEADLOCK FALSE' \
		'INVARIANT TypeOK' \
		'INVARIANT MeasurementPlanSafety' > "$cfg"
	if (
		cd "$OUT_DIR/formal"
		java -Xmx256m -XX:+UseParallelGC \
			-Djava.io.tmpdir="$java_tmp" -cp "$TLA_JAR" tlc2.TLC \
			-metadir "$OUT_DIR/states-safety-$fault" \
			-config "$cfg" "$MODEL"
	) > "$log" 2>&1; then
		printf 'unexpected-pass\n' > "$status_file"
	elif grep -Eq \
		'Invariant (TypeOK|MeasurementPlanSafety) is violated' "$log"; then
		printf 'expected-counterexample\n' > "$status_file"
	else
		printf 'unexpected-failure\n' > "$status_file"
	fi
}

safety_pids=()
while IFS= read -r fault; do
	run_safety_fault "$fault" &
	safety_pids+=("$!")
	if [ "${#safety_pids[@]}" -ge "$tlc_parallel_jobs" ]; then
		wait "${safety_pids[0]}"
		safety_pids=("${safety_pids[@]:1}")
	fi
done < <(jq -r '.formal.unsafe_safety_faults[]' "$CONFIG")
for pid in "${safety_pids[@]}"; do
	wait "$pid"
done
safety_expected=0
safety_failures=0
while IFS= read -r fault; do
	status=$(<"$OUT_DIR/status-safety-$fault")
	case "$status" in
		expected-counterexample)
			safety_expected=$((safety_expected + 1))
			;;
		*)
			printf 'unexpected safety result for %s: %s\n' \
				"$fault" "$status" >&2
			tail -40 "$OUT_DIR/tlc-safety-$fault.log" >&2
			safety_failures=$((safety_failures + 1))
			;;
	esac
done < <(jq -r '.formal.unsafe_safety_faults[]' "$CONFIG")
[ "$safety_failures" = 0 ] ||
	die "unsafe safety TLC failures: $safety_failures"
[ "$safety_expected" = 82 ] ||
	die "unsafe safety counterexample count changed: $safety_expected"

progress '88% reproducing two independent liveness counterexamples'
liveness_expected=0
while IFS= read -r fault; do
	cfg="$OUT_DIR/generated-unsafe-configs/liveness-$fault.cfg"
	log="$OUT_DIR/tlc-liveness-$fault.log"
	java_tmp="$OUT_DIR/java-tmp-liveness-$fault"
	mkdir "$java_tmp"
	printf '%s\n' \
		'SPECIFICATION Spec' \
		"CONSTANT Fault = \"$fault\"" \
		'CHECK_DEADLOCK FALSE' \
		'INVARIANT TypeOK' \
		'INVARIANT MeasurementPlanSafety' \
		'PROPERTY CurrentObservationProgress' \
		'PROPERTY OfflineDrainProgress' > "$cfg"
	if (
		cd "$OUT_DIR/formal"
		java -Xmx256m -XX:+UseParallelGC \
			-Djava.io.tmpdir="$java_tmp" -cp "$TLA_JAR" tlc2.TLC \
			-metadir "$OUT_DIR/states-liveness-$fault" \
			-config "$cfg" "$MODEL"
	) > "$log" 2>&1; then
		die "unsafe liveness fault unexpectedly passed: $fault"
	fi
	grep -q 'Temporal properties were violated' "$log" || {
		tail -80 "$log" >&2
		die "unsafe liveness fault failed unexpectedly: $fault"
	}
	liveness_expected=$((liveness_expected + 1))
done < <(jq -r '.formal.unsafe_liveness_faults[]' "$CONFIG")
[ "$liveness_expected" = 2 ] ||
	die "unsafe liveness counterexample count changed: $liveness_expected"

progress '96% publishing only scoped plan acceptance and source-draft authorization'
runner_sha=$(capsched_sha256_file "${BASH_SOURCE[0]}")
tla_jar_sha=$(capsched_sha256_file "$TLA_JAR")
jq -S -n \
	--arg run_id "$RUN_ID" --arg runner_sha "$runner_sha" \
	--arg tla_jar_sha "$tla_jar_sha" \
	--arg candidate "$CANDIDATE_COMMIT" --arg upstream "$CURRENT_UPSTREAM" \
	--arg merge_tree "$CANDIDATE_MERGE_TREE" \
	--argjson safe_states "$safe_states" \
	--argjson safe_distinct "$safe_distinct" \
	--argjson safe_depth "$safe_depth" \
	--argjson safety_faults "$safety_expected" \
	--argjson liveness_faults "$liveness_expected" \
	--argjson parallel_jobs "$tlc_parallel_jobs" '
{
  schema_version:1,
  id:"sched-exec-lease-p5a-r6-e4-local-quantum-measurement-plan-result-v1",
  run_id:$run_id,
  status:"passed_r6_e4_local_quantum_measurement_plan",
  runner_sha256:$runner_sha,
  contract_sha256:"8c3838e38568c780fb1e02c6ffc839de66b121af564bea47d45c289858667dc3",
  plan_sha256:"e4c10f61e97a98ca76567ba0df23ca3542462187070384d8ce27cd578e3be2f7",
  threat_model_sha256:"262f609a04b1da7b87562b48e42e9674e91151ed8ccdaaef3bc88596795e997d",
  formal_manifest_sha256:"f9e65914e00df5886fed41f70b058cc475588564482fdb22b361cdb158c01e0d",
  tla_jar_sha256:$tla_jar_sha,
  candidate_commit:$candidate,
  current_upstream_commit:$upstream,
  candidate_merge_tree:$merge_tree,
  upstream_advance_commits:108,
  upstream_touched_paths_since_previous:[],
  global_upstream_freshness_claim:false,
  source_anchor_count:24,
  source_anchor_failures:0,
  future_absence_check_count:8,
  future_absence_failures:0,
  matrix_cells:855,
  measured_pairs_per_cell:10000,
  total_measured_pairs:8550000,
  ordinary_additional_p99_limit_ns:5000,
  ordinary_additional_p999_limit_ns:25000,
  ordinary_additional_max_limit_ns:50000,
  offline_locked_additional_p99_limit_ns:25000,
  offline_locked_additional_p999_limit_ns:40000,
  offline_locked_additional_max_limit_ns:50000,
  normalized_base_slice_ns:700000,
  safe_states_generated:$safe_states,
  safe_distinct_states:$safe_distinct,
  safe_depth:$safe_depth,
  liveness_properties_checked:2,
  unsafe_safety_counterexamples:$safety_faults,
  unsafe_liveness_counterexamples:$liveness_faults,
  tlc_parallel_jobs:$parallel_jobs,
  r6_e4_plan_accepted:true,
  exact_disposable_e4_source_draft_may_start:true,
  e4_measurement_may_start_before_source_gate:false,
  e4_source_or_measurement_accepted:false,
  r6_behavior_source_may_be_created:false,
  live_scheduler_attachment:false,
  primary_linux_may_change:false,
  patch_queue_may_change:false,
  runtime_scheduler_hook_approved:false,
  runtime_behavior_approved:false,
  runtime_denial_correctness:false,
  runtime_coverage:false,
  runtime_budget_conflated:false,
  async_service_boundary_validated:false,
  memoryview_or_tlb_validated:false,
  device_dma_iommu_validated:false,
  monitor_verified:false,
  cluster_authority_validated:false,
  flat_cfs_equivalence:false,
  bare_metal_validated:false,
  bounded_wall_clock_latency_claim:false,
  performance_claim:false,
  cost_claim:false,
  production_protection:false,
  deployment_ready:false,
  multi_node_ready:false,
  multi_cluster_ready:false,
  datacenter_ready:false
}' > "$OUT_DIR/result.json"
jq empty "$OUT_DIR/result.json"
sha256sum "$OUT_DIR/result.json" > "$OUT_DIR/result.sha256"
progress '100% R6-E4 plan accepted; exact disposable source draft only'
