#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
PRIMARY_DIR="$WORKSPACE_DIR/linux"
PATCH_QUEUE_DIR="$WORKSPACE_DIR/linux-patches"
CANONICAL_CONFIG="$CAPSCHED_DIR/capsched-models/analysis/sched-exec-lease-p5a-r4-e4-local-quantum-measurement-plan-v1.json"
PLAN="$CAPSCHED_DIR/capsched-models/analysis/0176-sched-exec-lease-p5a-r4-e4-local-quantum-measurement-plan.md"
POST_GATE="$CAPSCHED_DIR/capsched-models/analysis/sched-exec-lease-p5a-r4-post-n135-authorization-gate-v1.json"
POST_VALIDATION="$CAPSCHED_DIR/capsched-models/validation/0256-sched-exec-lease-p5a-r4-post-n135-authorization-gate.md"
CLAIM_LEDGER="$CAPSCHED_DIR/capsched-models/analysis/implementation-claim-ledger-gate-v1.json"
RUNTIME_CHARGE="$CAPSCHED_DIR/capsched-models/analysis/runtime-charge-subject-v1.json"
RUNTIME_VALIDATION="$CAPSCHED_DIR/capsched-models/validation/0107-runtime-charge-subject-tlc.md"
AUTH_R7="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r4-post-n135-authorization-gate/20260718T-p5a-r4-post-n135-authorization-r7/result.json"
AUTH_R8="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r4-post-n135-authorization-gate/20260718T-p5a-r4-post-n135-authorization-r8/result.json"
MODEL_DIR="$CAPSCHED_DIR/capsched-models/formal/0139-p5a-r4-e4-local-quantum-measurement-plan-model"
MODEL=P5AR4E4LocalQuantumMeasurementPlan.tla
SAFE_CFG=P5AR4E4LocalQuantumMeasurementPlanSafe.cfg
TLA_JAR=${TLA_JAR:-"$WORKSPACE_DIR/build/tools/tla/tla2tools.jar"}
RUN_ID=${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
PROGRESS_FILE=${PROGRESS_FILE:-}
PLAN_GATE_TEST_MODE=${PLAN_GATE_TEST_MODE:-0}
CONFIG_OVERRIDE=${CONFIG_OVERRIDE:-}
OFFLINE_TEST_MODE=${OFFLINE_TEST_MODE:-0}
TEST_CONFIG_SHA=${TEST_CONFIG_SHA:-}

CONFIG_SHA=63ba7b17c3d08ea1ee0cdd4b420cc3a08b21932e9f6c2fb3f31754147e5b1667
PLAN_SHA=2475726afacd716db4bab475d16a5f5db9680f0dd5bb88e14dc23da3636ed347
POST_GATE_SHA=99d055aa02429c510f564fd02bb8f864f42a0603fc7e0a73e09fc13fc9532203
POST_VALIDATION_SHA=b1877970dd600b7db6e912284016614c91723cb97c72f34ee9e7249bdeb82238
CLAIM_LEDGER_SHA=d957db92654459c9298d252bdae0a92ef7de5b85918c24bcf4cc083c324e5adb
RUNTIME_CHARGE_SHA=d1dff5ebb6721575bf0c26c60d913eb5a9a5d95c179fba71969e3b7cb2d11065
RUNTIME_VALIDATION_SHA=be3e6159da5cccdd5996bb5d434f81e492aae37963d4af8f193d541e58de1f38
AUTH_R7_SHA=160efd76ed083df880747685a861a1b920e5fa9a265a4946749f87da44e09d37
AUTH_R8_SHA=d736b698cc056bea41d671c61b5c5a9a98024327642ff79c19f6dfb42f60f905
AUTH_NORMALIZED_SHA=541d72676f97741c40ed3a50b4f524c63a9530fc9984bfc88ed6675415d1fb4f
FORMAL_MANIFEST_SHA=43d2252ed4ba3311ac598533934ec4af00fa608dfa85ccc616e47e5d288f07f4

PRIMARY_COMMIT=5e1ca3037e34823d1ba0cdd1dc04161fac170280
PATCH_QUEUE_COMMIT=16bb080da472ffabbbafd2698073eca633fb0602
PATCH_QUEUE_SERIES_BLOB=298567f8e0bd18168222da4e64da32750b9ea818
CANDIDATE_PARENT=a429fc30252ac6af94c51d96cd4ac24e72d9f83b
CANDIDATE_COMMIT=da9ce9159b3450c28c8faf8dceac671fb7bfeba2
CANDIDATE_TREE=58c6510c6f517004e37107786d006bb8333b79b8
CANDIDATE_DIFF_SHA=096d99b527bd1b433ecd07165696830f9316d07cc67484687d95cd2c2a846f08
PREVIOUS_UPSTREAM=1229e2e57a5c2980ccd457b9b53ea0eed5a22ab3
CURRENT_UPSTREAM=f2ec6312bf711369561bdcb22f8a63c0b118c479
CANDIDATE_MERGE_BASE=4edcdefd4083ae04b1a5656f4be6cd83ae919ef4
CANDIDATE_MERGE_TREE=6c5fff5aaf6bc4ba8f7452546370b6026cef9133

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

for command_name in awk cmp cp cut find git grep java jq mkdir mv sed sha256sum sort tail tr wc xargs; do
	command -v "$command_name" >/dev/null 2>&1 \
		|| die "missing command: $command_name"
done
[ -f "$TLA_JAR" ] || die "missing TLA jar: $TLA_JAR"
capsched_validate_run_id "$RUN_ID" || die 'invalid RUN_ID'

if [ -n "$CONFIG_OVERRIDE" ]; then
	[ "$PLAN_GATE_TEST_MODE" = 1 ] || die 'CONFIG_OVERRIDE requires PLAN_GATE_TEST_MODE=1'
	CONFIG_SOURCE=$CONFIG_OVERRIDE
	[ -n "$TEST_CONFIG_SHA" ] || die 'TEST_CONFIG_SHA is required with CONFIG_OVERRIDE'
	EXPECTED_CONFIG_SHA=$TEST_CONFIG_SHA
else
	CONFIG_SOURCE=$CANONICAL_CONFIG
	EXPECTED_CONFIG_SHA=$CONFIG_SHA
fi
if [ ! -f "$CONFIG_SOURCE" ] || [ -L "$CONFIG_SOURCE" ]; then
	die 'config must be a regular non-symlink file'
fi

OUT_ROOT="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r4-e4-local-quantum-measurement-plan"
capsched_create_fresh_run_dir "$OUT_ROOT" "$RUN_ID" || die 'run output already exists or is unsafe'
OUT_DIR="$OUT_ROOT/$RUN_ID"
mkdir "$OUT_DIR/inputs" "$OUT_DIR/candidate" "$OUT_DIR/generated-unsafe-configs" "$OUT_DIR/formal"

snapshot()
{
	local source=$1
	local expected=$2
	local destination=$3

	capsched_snapshot_verified_file "$source" "$expected" "$destination" \
		|| die "failed immutable snapshot: $source"
}

progress '5% snapshotting exact plan and prerequisite evidence'
snapshot "$CONFIG_SOURCE" "$EXPECTED_CONFIG_SHA" "$OUT_DIR/inputs/config.json"
snapshot "$PLAN" "$PLAN_SHA" "$OUT_DIR/inputs/plan.md"
snapshot "$POST_GATE" "$POST_GATE_SHA" "$OUT_DIR/inputs/post-gate.json"
snapshot "$POST_VALIDATION" "$POST_VALIDATION_SHA" "$OUT_DIR/inputs/post-validation.md"
snapshot "$CLAIM_LEDGER" "$CLAIM_LEDGER_SHA" "$OUT_DIR/inputs/claim-ledger.json"
snapshot "$RUNTIME_CHARGE" "$RUNTIME_CHARGE_SHA" "$OUT_DIR/inputs/runtime-charge.json"
snapshot "$RUNTIME_VALIDATION" "$RUNTIME_VALIDATION_SHA" "$OUT_DIR/inputs/runtime-validation.md"
snapshot "$AUTH_R7" "$AUTH_R7_SHA" "$OUT_DIR/inputs/authorization-r7.json"
snapshot "$AUTH_R8" "$AUTH_R8_SHA" "$OUT_DIR/inputs/authorization-r8.json"
CONFIG="$OUT_DIR/inputs/config.json"

jq empty "$CONFIG"
jq empty "$OUT_DIR/inputs/post-gate.json"
jq empty "$OUT_DIR/inputs/claim-ledger.json"
jq empty "$OUT_DIR/inputs/runtime-charge.json"

progress '12% validating the complete 682-cell rejection contract'
jq -e '
  .schema_version == 1 and
  .status == "r4_e4_source_free_local_quantum_measurement_pre_source_plan" and
  .prerequisite.n135_complete == true and
  .prerequisite.exact_disposable_r4_e3_source_accepted == true and
  .prerequisite.synthetic_concurrency_correctness_accepted == true and
  .prerequisite.r4_e4_plan_drafting_authorized == true and
  .prerequisite.r4_e4_plan_already_accepted == false and
  .prerequisite.r4_e4_source_already_authorized == false and
  .source.direct_child_required == true and
  .source.allowed_files == ["init/Kconfig","kernel/sched/exec_lease.c"] and
  (.source.frozen_files | length) == 6 and
  .source.e2_layout_values_preserved == 58 and
  .source.e3_case_families_preserved == 36 and
  .source.e3_fault_sites_preserved == 6 and
  .source.e3_stress_iterations_preserved == 2048 and
  .source.e3_oracle_and_receipts_preserved == true and
  .source.measurement_only_brackets_allowed == true and
  .source.timing_only_substitute_allowed == false and
  .source.shared_helper_if_extracted_required == true and
  .source.primary_change_allowed == false and .source.patch_queue_change_allowed == false and
  .upstream_drift_freshness.current_observed_commit == "f2ec6312bf711369561bdcb22f8a63c0b118c479" and
  .upstream_drift_freshness.previous_is_ancestor == true and
  .upstream_drift_freshness.advanced_commit_count == 22 and
  .upstream_drift_freshness.merge_tree_clean == true and
  .upstream_drift_freshness.touched_paths == ["init/Kconfig","kernel/sched/exec_lease.c"] and
  (.upstream_drift_freshness.touched_paths_changed_since_previous_observation | length) == 0 and
  (.upstream_drift_freshness.touched_paths_changed_since_candidate_merge_base | length) == 0 and
  .upstream_drift_freshness.private_exec_lease_absent_upstream == true and
  .upstream_drift_freshness.touched_path_source_shape_fresh == true and
  .upstream_drift_freshness.global_upstream_freshness_claim == false and
  .configuration.name == "SCHED_EXEC_LEASE_R4_MEASURE_KUNIT_TEST" and
  .configuration.type == "bool" and .configuration.default_enabled == false and
  .configuration.direct_dependencies == ["SCHED_EXEC_LEASE_R4_KUNIT_TEST","KUNIT=y"] and
  .configuration.same_translation_unit == "kernel/sched/exec_lease.c" and
  .configuration.suite_name == "sched_exec_lease_r4_measure" and
  ([.configuration.selected_by_ordinary_lease,.configuration.selected_by_layout_probe,.configuration.selected_by_e3_test,.configuration.selected_by_kunit_all_tests,.configuration.makefile_or_header_change_allowed] | all(. == false)) and
  .configuration.disabled_symbols_relocations_strings_initcalls_rows_required == 0 and
  ([.fixture.real_e3_private_bucket_projection_rq_state,.fixture.real_raw_spinlocks,.fixture.real_hard_irq_work,.fixture.real_unbound_highpri_reclaim_workqueue,.fixture.real_xarray_cpumask_rcu_refcount_list,.fixture.synthetic_scheduler_inputs,.fixture.all_storage_preallocated,.fixture.untimed_oracle_and_operation_count_per_cell,.fixture.quiescent_reset_after_every_pair] | all(. == true)) and
  ([.fixture.registered_with_live_scheduler,.fixture.task_cgroup_or_live_rq_attachment,.fixture.live_picker_hotplug_migration_call,.fixture.policy_monitor_admission_or_denial_decision,.fixture.ordinary_scheduler_state_modified] | all(. == false)) and
  .common_measurement.clock == "local_clock" and
  ([.common_measurement.local_irq_state_recorded,.common_measurement.exact_operation_locks_required,.common_measurement.paired_empty_control,.common_measurement.same_lock_and_timestamp_shell_in_control,.common_measurement.alternating_pair_order,.common_measurement.nearest_rank_documented,.common_measurement.sort_and_report_outside_measured_context,.common_measurement.raw_rows_required,.common_measurement.result_row_per_cell_required] | all(. == true)) and
  .common_measurement.additional_formula == "max(treatment_ns-control_ns,0)" and
  .common_measurement.negative_difference_wrap_allowed == false and
  .common_measurement.minimum_warmup_pairs_per_cell == 256 and
  .common_measurement.measured_pairs_per_cell == 10000 and
  .common_measurement.statistics == ["minimum","p50","p95","p99","p999","maximum"] and
  .common_measurement.allocation_free_sort_print_trace_assert_sleep_reschedule_topology_policy_monitor_inside_local_interval == false and
  .common_measurement.clock_regression_allowed == false and .common_measurement.observed_vcpu_migration_allowed == false and
  .local_gate.additional_p99_limit_ns == 5000 and .local_gate.additional_p999_limit_ns == 25000 and
  .local_gate.additional_max_limit_ns == 50000 and .local_gate.normalized_base_slice_ns == 700000 and
  .local_gate.sample_may_reach_base_slice == false and .local_gate.base_slice_is_budget_or_deadline == false and
  .publication.active_rq_bits == [0,1,2] and .publication.rq_bucket_occupancy == [1,8,32,64] and
  .publication.synthetic_inner_load == [0,1,64,4096] and .publication.prior_burst_length == [1,64,4096] and
  .publication.notifier_owner == ["clear","owned_restart"] and .publication.cell_count == 288 and
  ([.publication.membership_lock_critical_section_only,.publication.workqueue_queueing_outside_interval,.publication.work_count_independent_of_all_axes] | all(. == true)) and
  .publication.generation_transitions_per_treatment == 1 and .publication.active_rq_xarray_leaf_bucket_history_iteration_allowed == false and
  .picker_kick.rq_bucket_occupancy == [1,8,32,64] and .picker_kick.synthetic_inner_load == [0,1,64,4096] and
  .picker_kick.desired_generation_burst == [1,64,4096] and .picker_kick.owner_state == ["idle","dirty_irq_pending","work_running"] and
  .picker_kick.cell_count == 144 and .picker_kick.rq_lock_held_irqs_disabled == true and
  .picker_kick.latest_wins_update == true and .picker_kick.unique_dirty_insert_max == 1 and
  .picker_kick.recovery_owner_max == 1 and .picker_kick.real_hard_irq_work_queue == true and
  .picker_kick.other_projection_or_leaf_visit_allowed == false and .picker_kick.cleanup_outside_interval == true and
  .irq_dispatch.queue_work_outcome == ["queued","false_pending","false_running"] and
  .irq_dispatch.unrelated_workqueue_depth == [0,1,64] and .irq_dispatch.cell_count == 9 and
  .irq_dispatch.real_hard_irq_context == true and .irq_dispatch.dispatch_only == true and
  .irq_dispatch.scheduler_or_membership_lock_allowed == false and .irq_dispatch.allocation_repair_wait_allowed == false and
  .irq_dispatch.false_requires_same_owner_pending_or_running == true and
  .recovery.dirty_depth == [1,8,32,64] and .recovery.rq_bucket_occupancy == [1,8,32,64] and
  .recovery.contribution_class == ["queued","delayed","current"] and
  .recovery.outcome == ["settle","republished_race","blocked"] and .recovery.cell_count == 144 and
  .recovery.projection_visits_per_quantum_max == 1 and .recovery.membership_locks_per_quantum_max == 1 and
  .recovery.lock_order == "rq_then_one_membership" and .recovery.current_requests_per_quantum_max == 1 and
  .recovery.remaining_dirty_or_bucket_leaf_hierarchy_rq_scan_allowed == false and
  .recovery.logical_counts_separate_from_elapsed_time == true and
  .notifier.active_synthetic_rqs == [1,2] and .notifier.cursor_quantum == ["first","last","end_of_pass"] and
  .notifier.membership_outcome == ["stable","changed_restart"] and
  .notifier.contribution_class == ["queued","current"] and .notifier.kick_owner == ["idle","coalesced"] and
  .notifier.cell_count == 48 and .notifier.cpumask_next_per_projection_quantum_max == 1 and
  .notifier.projection_visits_per_quantum_max == 1 and .notifier.rq_locks_per_quantum_max == 1 and
  .notifier.membership_lock_released_before_rq_lock == true and .notifier.end_of_pass_bookkeeping_o1 == true and
  .notifier.final_settlement_visit_bound == "2*A" and .notifier.final_settlement_bound_is_logical_not_wall_clock == true and
  .current_stop.request_source == ["recovery","notifier"] and
  .current_stop.observation_outcome == ["current_changed","same_current_revalidated"] and
  .current_stop.owner_state == ["idle","coalesced"] and .current_stop.publication_burst == [1,64,4096] and
  .current_stop.cell_count == 24 and .current_stop.request_issue_uses_local_gate == true and
  .current_stop.later_distinct_observation_required == true and .current_stop.request_observation_sequences_strictly_ordered == true and
  .current_stop.request_to_observation_p99_limit_ns == 10000000 and .current_stop.request_to_observation_max_limit_ns == 100000000 and
  .current_stop.availability_calibration_only == true and .current_stop.real_stop_revocation_or_monitor_receipt_claim == false and
  .offline.rq_bucket_occupancy == [0,1,8,32,64] and
  .offline.callback_state == ["idle","irq_pending","work_pending","work_running","self_requeue"] and
  .offline.cell_count == 25 and .offline.clears_accepting_first == true and .offline.bounded_projection_visits_max == 64 and
  .offline.all_contribution_classes_accounted == ["queued","delayed","current"] and
  .offline.residual_retained_blocked == true and .offline.sleepable_sync_cancel_outside_scheduler_locks == true and
  .offline.locked_additional_p99_limit_ns == 25000 and .offline.locked_additional_p999_limit_ns == 40000 and
  .offline.locked_additional_max_limit_ns == 50000 and .offline.locked_sample_may_reach_base_slice == false and
  .offline.sleepable_drain_p99_limit_ns == 10000000 and .offline.sleepable_drain_max_limit_ns == 100000000 and
  .offline.terminal_empty_and_zero_ownership_required == true and .offline.live_cpuhp_or_bare_metal_bound_claim == false and
  .matrix == {"publication_cells":288,"picker_kick_cells":144,"irq_dispatch_cells":9,"recovery_cells":144,"notifier_cells":48,"current_stop_cells":24,"offline_cells":25,"total_cells":682,"measured_pairs_per_cell":10000,"total_measured_pairs":6820000,"all_cells_required":true,"range_reduction_after_failure_allowed":false} and
  .logical_bounds.bucket_projections_per_rq_max == 64 and .logical_bounds.dirty_nodes_per_rq_max == 64 and
  .logical_bounds.recovery_owners_per_rq_max == 1 and .logical_bounds.dispatch_irq_work_per_rq == 1 and
  .logical_bounds.notifier_owners_per_active_bucket_max == 1 and
  .logical_bounds.recovery_projection_visits_per_invocation_max == 1 and
  .logical_bounds.notifier_projection_visits_per_invocation_max == 1 and
  .logical_bounds.final_notifier_visits_max == "2*A" and
  .logical_bounds.publication_to_last_settlement_wall_clock_gate_present == false and
  .logical_bounds.all_rq_fanout_benchmark_present == false and
  .diagnostics.architectures == ["arm64","x86_64"] and .diagnostics.arm64_runs_first == true and
  .diagnostics.x86_64_runs_only_after_arm64_pass == true and .diagnostics.same_source_identity_required == true and
  .diagnostics.disabled_and_enabled_builds_per_architecture == true and
  .diagnostics.e3_six_profile_regression_after_helper_change_required == true and
  (.diagnostics.timing_options | length) == 6 and .diagnostics.sanitizers_are_separate_diagnostics_not_timing == true and
  .diagnostics.record_environment_compiler_config_object_image_qemu_console_ktap_raw_rows == true and
  .diagnostics.warning_reports_allowed == 0 and (.diagnostics.warning_classes | length) == 14 and
  .diagnostics.virtual_result_supports_bare_metal_claim == false and
  .classification.valid_results == ["passed_r4_e4_architecture_measurement","rejected_r4_local_quantum_measurement"] and
  .classification.invalid_result == "harness_failed" and .classification.threshold_failure_is_valid_negative_evidence == true and
  .classification.missing_reduced_malformed_mutated_evidence_is_harness_failure == true and
  .classification.complete_rejection_stops_second_architecture == true and
  .classification.two_architecture_same_source_and_independent_closure_required_for_virtual_e4_compatibility == true and
  .classification.post_e4_review_required == true and .classification.r4_behavior_source_authorized == false and
  .separate_n136_boundary.runtime_budget_hook_allowed == false and
  .separate_n136_boundary.current_or_donor_authority_inferred == false and
  .separate_n136_boundary.n136_satisfied_by_measurement_plan == false and
  .separate_n136_boundary.runtime_coverage == false and
  (.source_anchors | length) == 31 and (.future_absence_checks | length) == 6 and
  (.formal.unsafe_faults | length) == 43 and .formal.unsafe_expected_counterexamples == 43 and
  .authorization_after_plan_pass.r4_e4_plan_accepted == true and
  .authorization_after_plan_pass.e4_disposable_worktree_may_be_created == true and
  .authorization_after_plan_pass.e4_exact_two_file_source_draft_may_be_created == true and
  .authorization_after_plan_pass.e4_measurement_may_start_before_source_gate == false and
  .authorization_after_plan_pass.e4_measurement_accepted == false and
  .authorization_after_plan_pass.r4_behavior_source_may_be_created == false and
  .authorization_after_plan_pass.primary_linux_may_change == false and
  .authorization_after_plan_pass.patch_queue_may_change == false and
  all(.safety_flags[]; . == false)
' "$CONFIG" >/dev/null

progress '22% checking the mandatory claim ledger and separate N-136 boundary'
jq -S '.required_claim_ledger_row_fields | sort' "$OUT_DIR/inputs/claim-ledger.json" > "$OUT_DIR/required-ledger-keys.json"
jq -S '.claim_ledger_row | keys | sort' "$CONFIG" > "$OUT_DIR/actual-ledger-keys.json"
cmp "$OUT_DIR/required-ledger-keys.json" "$OUT_DIR/actual-ledger-keys.json" >/dev/null \
	|| die 'claim-ledger row keys do not exactly match the global requirement'
jq -e '
  .claim_ledger_row.proposal_id == "sched-exec-lease-p5a-r4-e4-local-quantum-measurement-v1" and
  .claim_ledger_row.slice_id == "P5A-R4-E4" and
  .claim_ledger_row.behavior_mode == "default_off_same_translation_unit_virtual_synthetic_measurement_only" and
  .claim_ledger_row.supported_claims == ["exact_disposable_r4_e4_measurement_source_may_be_drafted_after_plan_gate"] and
  (.claim_ledger_row.forbidden_claims | length) == 8 and
  (.claim_ledger_row.open_gaps | length) == 7 and
  (.claim_ledger_row.required_validation_before_review | length) == 3 and
  (.claim_ledger_row.required_validation_before_acceptance | length) == 4 and
  .claim_ledger_row.upstream_drift_freshness.upstream_commit == "f2ec6312bf711369561bdcb22f8a63c0b118c479" and
  all(.claim_ledger_row.safety_flags[]; . == false)
' "$CONFIG" >/dev/null
jq -e '
  .missing_ledger_row_reviewable == false and
  .claim_rules.implementation_approval_requires == ["claim_ledger_row_present","implementation_scope_explicitly_reopened","upstream_drift_freshness_for_touched_paths","required_gate_artifacts_named","unsupported_claim_safety_flags_false"] and
  (.mandatory_false_unless_proven | length) == 8 and
  all(.safety_flags[]; . == false)
' "$OUT_DIR/inputs/claim-ledger.json" >/dev/null
jq -e '
  .status == "draft_model_gate_checked" and
  .invariants[0] == "NoUnspecifiedRuntimeCharge" and
  .safety_flags.hook_approved == false and .safety_flags.runtime_coverage == false and
  .safety_flags.protection_claim == false and all(.safety_flags[]; . == false)
' "$OUT_DIR/inputs/runtime-charge.json" >/dev/null

progress '31% independently binding both post-N-135 authorization results'
for auth in "$OUT_DIR/inputs/authorization-r7.json" "$OUT_DIR/inputs/authorization-r8.json"; do
	jq -e '
    .status == "passed_scoped_r4_e3_synthetic_acceptance_and_r4_e4_plan_draft_authorization" and
    .authorization_config_sha256 == "99d055aa02429c510f564fd02bb8f864f42a0603fc7e0a73e09fc13fc9532203" and
    .formal_model_manifest_sha256 == "96ce0df751c04180ac7b10ea71b07de808e8f0fc140e99a6d08c12ec95618129" and
    .candidate_commit == "da9ce9159b3450c28c8faf8dceac671fb7bfeba2" and
    .n135_complete == true and .claim_ledger_row_complete == true and
    .exact_disposable_r4_e3_source_accepted == true and
    .r4_e3_synthetic_concurrency_correctness_accepted == true and
    .r4_e4_plan_may_be_drafted == true and
    .r4_e4_plan_accepted == false and .r4_e4_source_may_be_created == false and
    .n136_satisfied_by_r4_e3_evidence == false and .runtime_coverage == false and
    .production_protection == false and .multi_cluster_ready == false and .datacenter_ready == false
  ' "$auth" >/dev/null
done
normalized_r7=$(jq -S 'del(.run_id)' "$OUT_DIR/inputs/authorization-r7.json" | sha256sum | awk '{print $1}')
normalized_r8=$(jq -S 'del(.run_id)' "$OUT_DIR/inputs/authorization-r8.json" | sha256sum | awk '{print $1}')
[ "$normalized_r7" = "$AUTH_NORMALIZED_SHA" ] || die 'authorization r7 normalized hash changed'
[ "$normalized_r8" = "$AUTH_NORMALIZED_SHA" ] || die 'authorization r8 normalized hash changed'
jq -e '
  .status == "scoped_r4_e3_synthetic_acceptance_and_r4_e4_plan_draft_authorization" and
  .authorization_after_gate_pass.r4_e4_plan_may_be_drafted == true and
  .authorization_after_gate_pass.r4_e4_plan_accepted == false and
  .authorization_after_gate_pass.r4_e4_source_may_be_created == false and
  .separate_runtime_budget_boundary.n136_satisfied_by_r4_e3_evidence == false and
  all(.safety_flags[]; . == false)
' "$OUT_DIR/inputs/post-gate.json" >/dev/null

progress '40% verifying immutable Git identity and refreshed touched paths'
[ "$(git -C "$PRIMARY_DIR" rev-parse HEAD)" = "$PRIMARY_COMMIT" ] || die 'primary Linux moved'
[ -z "$(git -C "$PRIMARY_DIR" status --porcelain=v1)" ] || die 'primary Linux is dirty'
[ "$(git -C "$PATCH_QUEUE_DIR" rev-parse HEAD)" = "$PATCH_QUEUE_COMMIT" ] || die 'patch queue moved'
[ -z "$(git -C "$PATCH_QUEUE_DIR" status --porcelain=v1)" ] || die 'patch queue is dirty'
[ "$(git -C "$PATCH_QUEUE_DIR" rev-parse HEAD:patches/capsched-linux-l0/series)" = "$PATCH_QUEUE_SERIES_BLOB" ] || die 'patch queue series blob moved'
[ "$(git -C "$PRIMARY_DIR" rev-parse "$CANDIDATE_COMMIT^")" = "$CANDIDATE_PARENT" ] || die 'candidate parent moved'
[ "$(git -C "$PRIMARY_DIR" rev-parse "$CANDIDATE_COMMIT^{tree}")" = "$CANDIDATE_TREE" ] || die 'candidate tree moved'
git -C "$PRIMARY_DIR" diff "$CANDIDATE_PARENT" "$CANDIDATE_COMMIT" -- init/Kconfig kernel/sched/exec_lease.c > "$OUT_DIR/candidate.diff"
[ "$(capsched_sha256_file "$OUT_DIR/candidate.diff")" = "$CANDIDATE_DIFF_SHA" ] || die 'candidate diff moved'
git -C "$PRIMARY_DIR" diff --name-only "$CANDIDATE_PARENT" "$CANDIDATE_COMMIT" -- > "$OUT_DIR/candidate-files.txt"
printf '%s\n' init/Kconfig kernel/sched/exec_lease.c > "$OUT_DIR/expected-candidate-files.txt"
cmp "$OUT_DIR/expected-candidate-files.txt" "$OUT_DIR/candidate-files.txt" >/dev/null || die 'candidate scope moved'

[ "$(git -C "$PRIMARY_DIR" rev-parse upstream/master)" = "$CURRENT_UPSTREAM" ] || die 'local upstream observation moved'
if [ "$OFFLINE_TEST_MODE" = 0 ]; then
	remote_tip=$(git -C "$PRIMARY_DIR" ls-remote upstream refs/heads/master | awk 'NR == 1 {print $1}')
	[ "$remote_tip" = "$CURRENT_UPSTREAM" ] || die "recorded upstream tip is stale: $remote_tip"
fi
git -C "$PRIMARY_DIR" merge-base --is-ancestor "$PREVIOUS_UPSTREAM" "$CURRENT_UPSTREAM" || die 'previous upstream is not ancestor'
[ "$(git -C "$PRIMARY_DIR" rev-list --count "$PREVIOUS_UPSTREAM..$CURRENT_UPSTREAM")" = 22 ] || die 'upstream advance count moved'
[ "$(git -C "$PRIMARY_DIR" merge-base "$CANDIDATE_COMMIT" "$CURRENT_UPSTREAM")" = "$CANDIDATE_MERGE_BASE" ] || die 'candidate merge base moved'
git -C "$PRIMARY_DIR" diff --name-only "$PREVIOUS_UPSTREAM" "$CURRENT_UPSTREAM" -- init/Kconfig kernel/sched/exec_lease.c > "$OUT_DIR/touched-since-previous.txt"
[ ! -s "$OUT_DIR/touched-since-previous.txt" ] || die 'touched paths changed since previous observation'
git -C "$PRIMARY_DIR" diff --name-only "$CANDIDATE_MERGE_BASE" "$CURRENT_UPSTREAM" -- init/Kconfig kernel/sched/exec_lease.c > "$OUT_DIR/touched-since-merge-base.txt"
[ ! -s "$OUT_DIR/touched-since-merge-base.txt" ] || die 'touched paths changed since candidate merge base'
if git -C "$PRIMARY_DIR" cat-file -e "$CURRENT_UPSTREAM:kernel/sched/exec_lease.c" 2>/dev/null; then
	die 'private exec_lease source unexpectedly exists upstream'
fi
[ "$(git -C "$PRIMARY_DIR" merge-tree --write-tree "$CANDIDATE_COMMIT" "$CURRENT_UPSTREAM")" = "$CANDIDATE_MERGE_TREE" ] || die 'candidate merge tree moved or conflicts'

git -C "$PRIMARY_DIR" show "$CANDIDATE_COMMIT:init/Kconfig" > "$OUT_DIR/candidate/init-Kconfig"
git -C "$PRIMARY_DIR" show "$CANDIDATE_COMMIT:kernel/sched/exec_lease.c" > "$OUT_DIR/candidate/exec_lease.c"
chmod 0444 "$OUT_DIR/candidate/init-Kconfig" "$OUT_DIR/candidate/exec_lease.c"

anchor_ledger="$OUT_DIR/source-anchors.tsv"
printf 'id\tstatus\tpath\tpattern\n' > "$anchor_ledger"
while IFS='|' read -r id path pattern; do
	case "$path" in
		init/Kconfig) source_file="$OUT_DIR/candidate/init-Kconfig" ;;
		kernel/sched/exec_lease.c) source_file="$OUT_DIR/candidate/exec_lease.c" ;;
		*) die "unexpected source-anchor path: $path" ;;
	esac
	if grep -Fq "$pattern" "$source_file"; then status=ok; else status=missing; fi
	printf '%s\t%s\t%s\t%s\n' "$id" "$status" "$path" "$pattern" >> "$anchor_ledger"
done < <(jq -r '.source_anchors[] | [.id,.path,.pattern] | join("|")' "$CONFIG")
anchor_count=$(jq '.source_anchors | length' "$CONFIG")
anchor_failures=$(awk -F '\t' 'NR > 1 && $2 != "ok" {count++} END {print count+0}' "$anchor_ledger")
[ "$anchor_failures" = 0 ] || die "source-anchor failures: $anchor_failures"

absence_ledger="$OUT_DIR/future-absence.tsv"
printf 'id\tstatus\tpath\tpattern\n' > "$absence_ledger"
while IFS='|' read -r id path pattern; do
	case "$path" in
		init/Kconfig) source_file="$OUT_DIR/candidate/init-Kconfig" ;;
		kernel/sched/exec_lease.c) source_file="$OUT_DIR/candidate/exec_lease.c" ;;
		*) die "unexpected absence path: $path" ;;
	esac
	if grep -Fq "$pattern" "$source_file"; then status=present; else status=absent; fi
	printf '%s\t%s\t%s\t%s\n' "$id" "$status" "$path" "$pattern" >> "$absence_ledger"
done < <(jq -r '.future_absence_checks[] | [.id,.path,.pattern] | join("|")' "$CONFIG")
absence_failures=$(awk -F '\t' 'NR > 1 && $2 != "absent" {count++} END {print count+0}' "$absence_ledger")
[ "$absence_failures" = 0 ] || die "future-absence failures: $absence_failures"

e3_case_count=$(sed -n '/static struct kunit_case sched_exec_r4_test_cases\[\] = {/,/};/p' "$OUT_DIR/candidate/exec_lease.c" | grep -c 'KUNIT_CASE(')
[ "$e3_case_count" = 36 ] || die "E3 case count moved: $e3_case_count"

progress '56% snapshotting and checking the exact formal model'
(
	cd "$MODEL_DIR"
	find . -maxdepth 1 -type f -print0 | sort -z | xargs -0 sha256sum
) > "$OUT_DIR/formal-source-manifest.sha256"
[ "$(capsched_sha256_file "$OUT_DIR/formal-source-manifest.sha256")" = "$FORMAL_MANIFEST_SHA" ] || die 'formal source manifest moved'
while read -r expected path; do
	name=${path#./}
	snapshot "$MODEL_DIR/$name" "$expected" "$OUT_DIR/formal/$name"
done < "$OUT_DIR/formal-source-manifest.sha256"
(
	cd "$OUT_DIR/formal"
	find . -maxdepth 1 -type f -print0 | sort -z | xargs -0 sha256sum
) > "$OUT_DIR/formal-snapshot-manifest.sha256"
cmp "$OUT_DIR/formal-source-manifest.sha256" "$OUT_DIR/formal-snapshot-manifest.sha256" >/dev/null || die 'formal snapshot differs'

(
	cd "$OUT_DIR/formal"
	java -cp "$TLA_JAR" tlc2.TLC -deadlock -metadir "$OUT_DIR/tlc-safe-states" -config "$SAFE_CFG" "$MODEL"
) > "$OUT_DIR/tlc-safe.log" 2>&1
grep -q 'Model checking completed. No error has been found.' "$OUT_DIR/tlc-safe.log" || {
	tail -80 "$OUT_DIR/tlc-safe.log" >&2
	die 'safe formal model failed'
}
state_line=$(sed -n 's/^\([0-9][0-9]*\) states generated, \([0-9][0-9]*\) distinct states found.*/\1 \2/p' "$OUT_DIR/tlc-safe.log" | tail -1)
safe_states=$(printf '%s\n' "$state_line" | awk '{print $1}')
safe_distinct=$(printf '%s\n' "$state_line" | awk '{print $2}')
safe_depth=$(sed -n 's/^The depth of the complete state graph search is \([0-9][0-9]*\).*/\1/p' "$OUT_DIR/tlc-safe.log" | tail -1)

progress '70% proving all 43 unsafe plan variants fail closed'
unsafe_expected=0
unsafe_failures=0
unsafe_index=0
while IFS= read -r fault; do
	unsafe_index=$((unsafe_index + 1))
	cfg="$OUT_DIR/generated-unsafe-configs/unsafe-$unsafe_index-$fault.cfg"
	log="$OUT_DIR/tlc-unsafe-$unsafe_index-$fault.log"
	printf 'CONSTANT Fault = "%s"\n\nSPECIFICATION Spec\n\nINVARIANT Safety\n' "$fault" > "$cfg"
	if (
		cd "$OUT_DIR/formal"
		java -cp "$TLA_JAR" tlc2.TLC -deadlock -metadir "$OUT_DIR/tlc-unsafe-$unsafe_index-$fault-states" -config "$cfg" "$MODEL"
	) > "$log" 2>&1; then
		printf 'unsafe fault unexpectedly passed: %s\n' "$fault" >&2
		unsafe_failures=$((unsafe_failures + 1))
	elif grep -q 'Invariant Safety is violated' "$log"; then
		unsafe_expected=$((unsafe_expected + 1))
	else
		printf 'unsafe fault failed unexpectedly: %s\n' "$fault" >&2
		tail -40 "$log" >&2
		unsafe_failures=$((unsafe_failures + 1))
	fi
done < <(jq -r '.formal.unsafe_faults[]' "$CONFIG")
[ "$unsafe_failures" = 0 ] || die "$unsafe_failures unsafe formal cases failed unexpectedly"
[ "$unsafe_expected" = 43 ] || die "unsafe counterexample count moved: $unsafe_expected"

progress '88% sealing source-draft authorization and every negative claim'
runner_sha=$(capsched_sha256_file "${BASH_SOURCE[0]}")
jq -n \
	--arg run_id "$RUN_ID" \
	--arg config_sha "$EXPECTED_CONFIG_SHA" \
	--arg plan_sha "$PLAN_SHA" \
	--arg runner_sha "$runner_sha" \
	--arg formal_sha "$FORMAL_MANIFEST_SHA" \
	--arg auth_r7_sha "$AUTH_R7_SHA" \
	--arg auth_r8_sha "$AUTH_R8_SHA" \
	--arg auth_normalized_sha "$AUTH_NORMALIZED_SHA" \
	--arg primary "$PRIMARY_COMMIT" \
	--arg patch_queue "$PATCH_QUEUE_COMMIT" \
	--arg candidate "$CANDIDATE_COMMIT" \
	--arg candidate_tree "$CANDIDATE_TREE" \
	--arg candidate_diff "$CANDIDATE_DIFF_SHA" \
	--arg upstream "$CURRENT_UPSTREAM" \
	--arg merge_tree "$CANDIDATE_MERGE_TREE" \
	--argjson anchors "$anchor_count" \
	--argjson anchor_failures "$anchor_failures" \
	--argjson absence_failures "$absence_failures" \
	--argjson e3_cases "$e3_case_count" \
	--argjson safe_states "${safe_states:-0}" \
	--argjson safe_distinct "${safe_distinct:-0}" \
	--argjson safe_depth "${safe_depth:-0}" \
	--argjson unsafe "$unsafe_expected" \
'{
  schema_version: 1,
  id: "sched-exec-lease-p5a-r4-e4-local-quantum-measurement-plan-result-v1",
  run_id: $run_id,
  status: "passed_r4_e4_plan_only_source_draft_authorized",
  plan_config_sha256: $config_sha,
  plan_markdown_sha256: $plan_sha,
  runner_sha256: $runner_sha,
  formal_model_manifest_sha256: $formal_sha,
  post_n135_authorization_result_sha256: [$auth_r7_sha,$auth_r8_sha],
  post_n135_authorization_normalized_sha256: $auth_normalized_sha,
  primary_linux_commit: $primary,
  patch_queue_commit: $patch_queue,
  candidate_commit: $candidate,
  candidate_tree: $candidate_tree,
  candidate_diff_sha256: $candidate_diff,
  current_upstream_commit: $upstream,
  upstream_advance_count: 22,
  touched_path_changes: 0,
  candidate_merge_tree: $merge_tree,
  candidate_merge_tree_clean: true,
  claim_ledger_row_complete: true,
  required_claim_ledger_fields: 14,
  source_anchor_count: $anchors,
  source_anchor_failures: $anchor_failures,
  future_absence_failures: $absence_failures,
  preserved_e3_case_count: $e3_cases,
  safe_model_passed: true,
  safe_states_generated: $safe_states,
  safe_distinct_states: $safe_distinct,
  safe_depth: $safe_depth,
  unsafe_expected_counterexamples: $unsafe,
  matrix: {
    publication_cells: 288,
    picker_kick_cells: 144,
    irq_dispatch_cells: 9,
    recovery_cells: 144,
    notifier_cells: 48,
    current_stop_cells: 24,
    offline_cells: 25,
    total_cells: 682,
    measured_pairs_per_cell: 10000,
    total_measured_pairs: 6820000
  },
  gates_ns: {
    local: {p99:5000,p999:25000,max:50000},
    offline_locked: {p99:25000,p999:40000,max:50000},
    async_availability: {p99:10000000,max:100000000},
    normalized_base_slice: 700000
  },
  global_settlement_wall_clock_gate_present: false,
  logical_notifier_bound: "2*A",
  r4_e4_plan_accepted: true,
  e4_disposable_worktree_may_be_created: true,
  e4_exact_two_file_source_draft_may_be_created: true,
  e4_measurement_may_start_before_source_gate: false,
  e4_measurement_accepted: false,
  r4_behavior_source_may_be_created: false,
  primary_linux_may_change: false,
  patch_queue_may_change: false,
  real_scheduler_attachment: false,
  runtime_scheduler_hook_approved: false,
  runtime_behavior_approved: false,
  runtime_denial_correctness: false,
  runtime_coverage: false,
  n136_complete: false,
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
}' > "$OUT_DIR/result.json.partial"
jq empty "$OUT_DIR/result.json.partial"
chmod 0444 "$OUT_DIR/result.json.partial"
mv "$OUT_DIR/result.json.partial" "$OUT_DIR/result.json"
capsched_sha256_file "$OUT_DIR/result.json" > "$OUT_DIR/result.sha256"
progress '100% plan gate passed; exact disposable E4 source drafting only is authorized'
cat "$OUT_DIR/result.json"
