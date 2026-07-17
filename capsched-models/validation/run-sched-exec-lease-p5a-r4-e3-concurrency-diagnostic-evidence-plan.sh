#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
RUNNER="$SCRIPT_DIR/$(basename "${BASH_SOURCE[0]}")"
LINUX_DIR=${DOMAINLEASE_LINUX_DIR:-"$WORKSPACE_DIR/linux"}
PATCH_DIR="$WORKSPACE_DIR/linux-patches"
CONFIG_SOURCE=${CAPSCHED_PLAN_CONFIG:-"$CAPSCHED_DIR/capsched-models/analysis/sched-exec-lease-p5a-r4-e3-concurrency-diagnostic-evidence-plan-v1.json"}
MODEL_SOURCE_DIR="$CAPSCHED_DIR/capsched-models/formal/0137-p5a-r4-e3-concurrency-diagnostic-evidence-plan-model"
MODEL=P5AR4E3ConcurrencyDiagnosticEvidencePlan.tla
SAFE_CFG=P5AR4E3ConcurrencyDiagnosticEvidencePlanSafe.cfg
TLA_JAR_SOURCE=${TLA_JAR:-"$WORKSPACE_DIR/build/tools/tla/tla2tools.jar"}
HARDENING_LIB="$SCRIPT_DIR/lib/immutable-evidence-inputs.sh"
RUN_ID=${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
RUN_ROOT="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r4-e3-concurrency-diagnostic-evidence-plan"
OUT_DIR="$RUN_ROOT/$RUN_ID"
PROGRESS_FILE=${PROGRESS_FILE:-}
EXPECTED_CONFIG_SHA256=f9c9103b4eae2177309dd8e0134601fe3cf1eb08061986265627dcd9d8fd6677
EXPECTED_MODEL_SHA256=35b29a710a5ca87b90bb3e40da694544ed270aac5dd621de99147c6bb5ebe111
EXPECTED_SAFE_CFG_SHA256=253db7b57514f21d2054d4e3520602defd7d8c1291e456e94d7515ca0c17267a
EXPECTED_TLA_JAR_SHA256=936a262061c914694dfd669a543be24573c45d5aa0ff20a8b96b23d01e050e88
EXPECTED_HARDENING_LIB_SHA256=4548753bc2acaa7497aef9e9ff070d9952f9b5ee20631c6116590067eab9ccc6
export LC_ALL=C

die()
{
	printf 'error: %s\n' "$*" >&2
	exit 1
}

progress()
{
	[ -n "$PROGRESS_FILE" ] || return 0
	mkdir -p "$(dirname "$PROGRESS_FILE")"
	printf '%s\n' "$1" > "$PROGRESS_FILE"
}

resolve_basis_path()
{
	case "$1" in
		capsched-models/*|capsched-ai/*)
			printf '%s/%s\n' "$CAPSCHED_DIR" "$1"
			;;
		*)
			printf '%s/%s\n' "$WORKSPACE_DIR" "$1"
			;;
	esac
}

for command_name in awk chmod cp diff git grep java jq mkdir mv sed sha256sum sort tail tr wc; do
	command -v "$command_name" >/dev/null 2>&1 \
		|| die "missing command: $command_name"
done

case "$RUN_ID" in
	''|.|..|[!A-Za-z0-9]*|*[!A-Za-z0-9._-]*)
		die "invalid RUN_ID: $RUN_ID"
		;;
esac
if [ ! -f "$TLA_JAR_SOURCE" ] || [ -L "$TLA_JAR_SOURCE" ]; then
	die "missing or symlinked TLA jar: $TLA_JAR_SOURCE"
fi
if [ -L "$RUN_ROOT" ]; then
	die "run output root is symlinked: $RUN_ROOT"
fi
mkdir -p -- "$RUN_ROOT"
if [ ! -d "$RUN_ROOT" ] || [ -L "$RUN_ROOT" ]; then
	die "invalid run output root: $RUN_ROOT"
fi
mkdir -- "$OUT_DIR" 2>/dev/null \
	|| die "run output directory is not fresh: $OUT_DIR"

INPUT_DIR="$OUT_DIR/input-snapshots"
MODEL_DIR="$INPUT_DIR/model"
mkdir -- "$INPUT_DIR" "$MODEL_DIR" "$OUT_DIR/generated-unsafe-configs"
runner_sha_at_start=$(sha256sum "$RUNNER" | awk '{print $1}')

HARDENING_LIB_SNAPSHOT="$INPUT_DIR/immutable-evidence-inputs.sh"
if [ ! -f "$HARDENING_LIB" ] || [ -L "$HARDENING_LIB" ]; then
	die "missing or symlinked hardening helper: $HARDENING_LIB"
fi
cp -- "$HARDENING_LIB" "$HARDENING_LIB_SNAPSHOT.partial"
helper_sha=$(sha256sum "$HARDENING_LIB_SNAPSHOT.partial" | awk '{print $1}')
[ "$helper_sha" = "$EXPECTED_HARDENING_LIB_SHA256" ] \
	|| die "hardening helper snapshot failed exact hash binding: $helper_sha"
chmod 0444 -- "$HARDENING_LIB_SNAPSHOT.partial"
mv -- "$HARDENING_LIB_SNAPSHOT.partial" "$HARDENING_LIB_SNAPSHOT"
# shellcheck source=lib/immutable-evidence-inputs.sh
# The path is dynamic and the exact copied bytes were hash-pinned above.
# shellcheck disable=SC1091
. "$HARDENING_LIB_SNAPSHOT"

capsched_validate_run_id "$RUN_ID" || die "invalid RUN_ID after helper load: $RUN_ID"
capsched_snapshot_verified_file "$CONFIG_SOURCE" "$EXPECTED_CONFIG_SHA256" \
	"$INPUT_DIR/plan.json" \
	|| die 'plan config snapshot failed exact hash binding'
capsched_snapshot_verified_file "$MODEL_SOURCE_DIR/$MODEL" "$EXPECTED_MODEL_SHA256" \
	"$MODEL_DIR/$MODEL" \
	|| die 'TLA+ model snapshot failed exact hash binding'
capsched_snapshot_verified_file "$MODEL_SOURCE_DIR/$SAFE_CFG" "$EXPECTED_SAFE_CFG_SHA256" \
	"$MODEL_DIR/$SAFE_CFG" \
	|| die 'safe TLC config snapshot failed exact hash binding'
capsched_snapshot_verified_file "$TLA_JAR_SOURCE" "$EXPECTED_TLA_JAR_SHA256" \
	"$INPUT_DIR/tla2tools.jar" \
	|| die 'TLA jar snapshot failed exact hash binding'

CONFIG="$INPUT_DIR/plan.json"
TLA_JAR="$INPUT_DIR/tla2tools.jar"
progress '5% validating N-133 contract and frozen R4-E2 evidence'
jq empty "$CONFIG"

jq -e '
  .status == "r4_e3_concurrency_diagnostic_pre_source_plan" and
  .source_basis.primary_linux_commit == "5e1ca3037e34823d1ba0cdd1dc04161fac170280" and
  .source_basis.primary_linux_tree == "54f685aad94f28f0027cbba18cf5e29aadce234a" and
  .source_basis.e2_candidate_parent == .source_basis.primary_linux_commit and
  .source_basis.e2_candidate_commit == "a429fc30252ac6af94c51d96cd4ac24e72d9f83b" and
  .source_basis.e2_candidate_tree == "fffd419bbc05bab87ad304c1e4a3213439d62bab" and
  .source_basis.e2_candidate_diff_sha256 == "94dedc73b731c451d52b90885cd63a350a1cd562a3b1b40f856c5984b4f6cd15" and
  .source_basis.e2_contract_sha256 == "91389db1f5007e78e41b17a6ed4327e9a7d81818206c2caef20dca66c931cb1f" and
  .source_basis.e2_result_metadata_sha256 == "847f1fd423990d896be7f81652f04c9be49e74fe58c449d86ac03b3a4c959239" and
  .source_basis.e2_dual_arch_result_sha256 == "6346c3570008942fae533395ff4eb1165c3d42c6572d134c945e20fb57cbad1e" and
  .source_basis.e2_closure_result_sha256 == "fed621ee76effc554df806f40f6289d375dafe3f127427a9be73d6ff2ddcc048" and
  .source_basis.e2_post_retirement_result_sha256 == "27f5a7acc52cc3852ca049a6abc07a72bce2c4e99e7a1a2e02167548a7b3d0f6" and
  .source_basis.patch_queue_commit == "16bb080da472ffabbbafd2698073eca633fb0602" and
  .source_basis.patch_queue_series_blob == "298567f8e0bd18168222da4e64da32750b9ea818" and
  .source_basis.patch_queue_tail == "0014-sched-exec_lease-Expand-build-only-layout-probe.patch" and
  .source_basis.rejected_r3_source_is_parent == false and
  ([.source_basis.primary_linux_change_allowed,.source_basis.patch_queue_change_allowed] | all(. == false)) and
  .source_boundary.future_parent == .source_basis.e2_candidate_commit and
  .source_boundary.direct_child_required == true and
  .source_boundary.future_branch == "codex/p5a-r4-e3-concurrency-prototype" and
  .source_boundary.allowed_files == ["init/Kconfig","kernel/sched/exec_lease.c"] and
  .source_boundary.frozen_files == ["include/linux/sched.h","include/linux/sched_exec_lease.h","kernel/sched/Makefile","kernel/sched/sched.h","kernel/sched/fair.c","kernel/sched/core.c","kernel/sched/exec_lease_layout_probe.c"] and
  .source_boundary.e2_private_type_block_byte_preserved == true and
  .source_boundary.e2_private_probe_values_preserved == 58 and
  .source_boundary.existing_expanded_probe_values_preserved == 51 and
  .source_boundary.ordinary_structure_growth_bytes == {sched_entity:0,cfs_rq:0,rq:0,task_struct:0} and
  ([.source_boundary.strict_checkpatch_errors_allowed,.source_boundary.strict_checkpatch_warnings_allowed,.source_boundary.strict_checkpatch_checks_allowed] | all(. == 0)) and
  ([.source_boundary.primary_linux_change_allowed,.source_boundary.patch_queue_change_allowed,.source_boundary.e2_candidate_amend_allowed] | all(. == false)) and
  .configuration.name == "SCHED_EXEC_LEASE_R4_KUNIT_TEST" and
  .configuration.type == "bool" and
  .configuration.default_enabled == false and
  .configuration.direct_dependencies == ["SCHED_EXEC_LEASE_R4_LAYOUT_PROBE","KUNIT=y"] and
  .configuration.same_translation_unit == "kernel/sched/exec_lease.c" and
  .configuration.suite_name == "sched_exec_lease_r4_concurrency" and
  ([.configuration.selected_by_ordinary_lease,.configuration.selected_by_layout_probe,.configuration.selected_by_r4_layout_probe,.configuration.selected_by_kunit_all_tests,.configuration.makefile_change_allowed,.configuration.header_change_allowed] | all(. == false)) and
  .configuration.disabled_e3_symbols_relocations_strings_initcalls == 0 and
  .configuration.release_config_must_pin_r4_options_off == true and
  ([.prototype_scope.uses_exact_e2_private_types,.prototype_scope.real_raw_spinlocks,.prototype_scope.real_refcounts,.prototype_scope.real_cpumask_var,.prototype_scope.real_xarray,.prototype_scope.real_rcu_readers_and_callbacks,.prototype_scope.real_hard_irq_work,.prototype_scope.real_unbound_workqueue,.prototype_scope.synthetic_rq_shell,.prototype_scope.synthetic_current_and_contributions] | all(. == true)) and
  ([.prototype_scope.live_rq_or_cfs_attachment,.prototype_scope.live_task_or_task_group_attachment,.prototype_scope.live_picker_publisher_migration_hotplug_hook,.prototype_scope.real_cpuhp_registration,.prototype_scope.production_registry,.prototype_scope.capability_budget_policy_monitor_or_denial_decision,.prototype_scope.live_resched_curr_call,.prototype_scope.inner_leaf_hierarchy_bucket_or_rq_scan,.prototype_scope.export_static_key_trace_debug_user_abi] | all(. == false)) and
  .capacity_and_allocation.b_max_per_rq == 64 and
  .capacity_and_allocation.accepted_cases == [0,1,63,64] and
  .capacity_and_allocation.rejected_cases == [65] and
  .capacity_and_allocation.slot_and_projection_before_first_contribution == true and
  .capacity_and_allocation.failure_errno == "-ENOMEM" and
  .capacity_and_allocation.failure_leaves_partial_state == false and
  .capacity_and_allocation.retry_after_failure_required == true and
  .capacity_and_allocation.allocation_under_rq_or_membership_lock == false and
  .capacity_and_allocation.overflow_evict_merge_alias_or_fallback == false and
  .capacity_and_allocation.allocation_fault_sites == ["workqueue_create","bucket_control","active_rq_cpumask","rq_state_shell","projection","xarray_reserve"] and
  (.capacity_and_allocation.failure_zero_assertions | length) == 9 and
  .independent_oracle.plain_record_representation == true and
  ([.independent_oracle.shares_transition_helper,.independent_oracle.shares_refcount_helper,.independent_oracle.shares_mask_or_xarray_helper,.independent_oracle.shares_generation_or_dirty_helper,.independent_oracle.shares_notifier_migration_hotplug_or_work_helper] | all(. == false)) and
  ([.independent_oracle.checks_after_every_forced_transition,.independent_oracle.checks_cleanup_after_failed_assertion,.independent_oracle.machine_readable_case_receipts] | all(. == true)) and
  (.independent_oracle.receipt_fields | length) == 6 and
  (.independent_oracle.reference_classes | length) == 7 and
  .irq_work_bridge.kick_under_rq_lock == true and
  .irq_work_bridge.kick_with_local_irqs_disabled == true and
  .irq_work_bridge.latest_desired_generation_wins == true and
  .irq_work_bridge.unique_preallocated_dirty_node == true and
  .irq_work_bridge.dirty_reference_on_zero_to_one == true and
  .irq_work_bridge.hard_irq_work_per_rq == 1 and
  .irq_work_bridge.duplicate_irq_kick_coalesces == true and
  .irq_work_bridge.irq_false_keeps_durable_state == true and
  .irq_work_bridge.irq_callback_dispatch_only == true and
  .irq_work_bridge.irq_callback_unconditionally_queues_work == true and
  .irq_work_bridge.irq_callback_takes_scheduler_or_membership_lock == false and
  .irq_work_bridge.irq_callback_repairs_allocates_frees_waits_or_cancels == false and
  .irq_work_bridge.workqueue_flags == ["WQ_UNBOUND","WQ_HIGHPRI","WQ_MEM_RECLAIM"] and
  .irq_work_bridge.queue_work_on_target_cpu == false and
  .irq_work_bridge.recovery_owner_per_rq == 1 and
  .irq_work_bridge.queue_false_requires_pending_or_running_same_owner == true and
  .irq_work_bridge.queue_false_drops_dirty_or_lifetime_ref == false and
  .recovery.dirty_list_per_rq == 1 and
  .recovery.dirty_depth_max == 64 and
  .recovery.duplicate_dirty_node_allowed == false and
  .recovery.one_projection_per_worker_quantum == true and
  .recovery.one_target_rq_lock_per_quantum == true and
  .recovery.at_most_one_membership_lock_per_quantum == true and
  .recovery.nested_lock_order == "rq_then_one_membership" and
  .recovery.two_rq_or_two_membership_locks == false and
  .recovery.final_accepting_contribution_state_generation_recheck == true and
  .recovery.race_retains_or_reinserts_dirty_node == true and
  .recovery.worker_self_requeue_outside_scheduler_locks == true and
  .recovery.concurrent_final_empty_insert_kicks_irq == true and
  .recovery.allocation_free_wait_cancel_flush_rcu_or_monitor_under_lock == false and
  .publisher_and_notifier.publication_critical_section_o1 == true and
  .publisher_and_notifier.frozen_state_before_release_generation == true and
  .publisher_and_notifier.generation_nonwrapping == true and
  .publisher_and_notifier.notifier_owner_per_active_bucket == 1 and
  .publisher_and_notifier.queue_notifier_after_membership_unlock == true and
  .publisher_and_notifier.publisher_walks_rq_mask_or_projection_map == false and
  .publisher_and_notifier.publisher_takes_rq_lock == false and
  .publisher_and_notifier.publisher_allocates_waits_flushes_or_cancels == false and
  (.publisher_and_notifier.cursor_fields | length) == 6 and
  .publisher_and_notifier.cursor_api == "cpumask_next" and
  .publisher_and_notifier.one_projection_visit_per_invocation == true and
  .publisher_and_notifier.one_projection_ref_per_visit == true and
  .publisher_and_notifier.membership_lock_released_before_rq_lock == true and
  .publisher_and_notifier.generation_change_restarts == true and
  .publisher_and_notifier.membership_sequence_change_restarts == true and
  .publisher_and_notifier.publisher_owner_clear_handshake_serialized == true and
  .publisher_and_notifier.late_admission_acquire_generation_and_self_kick == true and
  .publisher_and_notifier.stable_window_visit_bound == "at_most_2_times_A" and
  .publisher_and_notifier.bound_is_logical_not_wall_clock == true and
  .current_and_migration.current_request_sequence_under_rq_lock == true and
  .current_and_migration.later_distinct_scheduler_observation_required == true and
  .current_and_migration.observation_requires_current_changed_or_revalidated == true and
  ([.current_and_migration.need_resched_is_completion_receipt,.current_and_migration.need_resched_is_monitor_delivery,.current_and_migration.instantaneous_revocation_claim] | all(. == false)) and
  .current_and_migration.contribution_classes == ["queued","delayed","current"] and
  .current_and_migration.migration_protocol == "remove_neutral_add" and
  .current_and_migration.source_zero_before_unlock == true and
  .current_and_migration.oracle_visible_neutral_state == true and
  .current_and_migration.destination_prepared_before_add == true and
  .current_and_migration.simultaneous_source_destination_contribution == false and
  .current_and_migration.destination_failure_remains_neutral_and_denied == true and
  .hotplug.two_phase_offline == true and
  .hotplug.rq_locked_phase_clears_accepting_first == true and
  .hotplug.rq_locked_phase_disables_new_dirty_ownership_and_kicks == true and
  .hotplug.sleepable_phase_outside_scheduler_locks == true and
  .hotplug.irq_work_sync_before_cancel_work_sync == true and
  .hotplug.racing_enqueues_disabled_before_cancel == true and
  .hotplug.canceled_owner_and_dirty_refs_settled == true and
  .hotplug.empty_dirty_list_and_zero_callback_owner_before_complete == true and
  .hotplug.online_initializes_before_accepting == true and
  .hotplug.real_cpuhp_callback_registered_by_prototype == false and
  (.hotplug.forced_offline_states | length) == 5 and
  .retirement.retiring_or_blocked_before_unpublish == true and
  .retirement.new_notifier_and_dirty_ownership_disabled_first == true and
  .retirement.rcu_unpublish_before_drain == true and
  .retirement.cancel_sync_outside_scheduler_locks == true and
  .retirement.racing_queue_sources_disabled_before_cancel == true and
  .retirement.active_mask_and_xarray_empty_before_free == true and
  .retirement.all_reference_classes_zero_before_free == true and
  .retirement.pre_unpublish_readers_exit_before_free == true and
  .retirement.rcu_grace_before_free == true and
  .retirement.generation_saturation_value == "U64_MAX" and
  .retirement.generation_saturation_state == "Blocked" and
  .retirement.generation_zero_valid == false and
  .retirement.generation_wrap_reuse == false and
  (.required_case_families | length) == 36 and
  (.required_case_families | unique | length) == 36 and
  (.required_case_families | all(test("^[A-Za-z0-9][A-Za-z0-9_]*$"))) and
  .race_control.completion_atomic_checkpoint_or_barrier_forced == true and
  .race_control.timing_sleep_as_proof == false and
  .race_control.hard_timeout_seconds == 15 and
  .race_control.stress_iterations_per_diagnostic_boot == 2048 and
  .race_control.recorded_deterministic_seed_set == true and
  (.race_control.required_stress_families | length) == 5 and
  ([.race_control.required_failure_count,.race_control.required_skip_count,.race_control.required_timeout_count] | all(. == 0)) and
  .race_control.matrix_reduction_after_failure == false and
  .build_and_boot_matrix.architectures == ["arm64","x86_64"] and
  (.build_and_boot_matrix.fresh_modes_per_architecture | length) == 4 and
  .build_and_boot_matrix.disabled_e3_symbols_relocations_strings_initcalls == 0 and
  .build_and_boot_matrix.enabled_existing_values_preserved == 51 and
  .build_and_boot_matrix.enabled_r4_private_values_preserved == 58 and
  .build_and_boot_matrix.ordinary_structure_growth_bytes == {sched_entity:0,cfs_rq:0,rq:0,task_struct:0} and
  (.build_and_boot_matrix.qemu_boots | length) == 6 and
  (.build_and_boot_matrix.standard_and_fault_options | length) == 9 and
  .build_and_boot_matrix.suite_filter_exact == "sched_exec_lease_r4_concurrency" and
  ([.build_and_boot_matrix.required_case_failures_allowed,.build_and_boot_matrix.required_case_skips_allowed,.build_and_boot_matrix.required_case_timeouts_allowed,.build_and_boot_matrix.warning_reports_allowed] | all(. == 0)) and
  .build_and_boot_matrix.record_compiler_config_image_object_qemu_ktap_console_seed_fault_receipts == true and
  .build_and_boot_matrix.virtual_result_supports_bare_metal_or_production_claim == false and
  (.warning_rejection_patterns | length) == 18 and
  (.source_anchors | length) == 48 and
  (.future_absence_checks | length) == 10 and
  (.formal.liveness_properties | length) == 4 and
  (.formal.liveness_properties | unique | length) == 4 and
  (.formal.liveness_properties | all(test("^[A-Za-z][A-Za-z0-9_]*$"))) and
  (.formal.unsafe_faults | length) == 76 and
  (.formal.unsafe_faults | unique | length) == 76 and
  (.formal.unsafe_faults | all(test("^[A-Za-z][A-Za-z0-9_]*$"))) and
  .formal.unsafe_expected_counterexamples == 76 and
  .authorization_after_pass.r4_e3_disposable_worktree_may_be_created == true and
  .authorization_after_pass.r4_e3_exact_two_file_source_draft_may_be_created == true and
  .authorization_after_pass.r4_e3_source_accepted == false and
  .authorization_after_pass.r4_e3_concurrency_correctness_accepted == false and
  .authorization_after_pass.r4_e4_plan_may_be_drafted == false and
  .authorization_after_pass.r4_e4_source_may_be_created == false and
  .authorization_after_pass.r4_behavior_source_may_be_created == false and
  .authorization_after_pass.primary_linux_may_change == false and
  .authorization_after_pass.patch_queue_may_change == false and
  (.safety_flags | all(.[]; . == false))
' "$CONFIG" >/dev/null

primary=$(jq -r '.source_basis.primary_linux_commit' "$CONFIG")
primary_tree_expected=$(jq -r '.source_basis.primary_linux_tree' "$CONFIG")
candidate=$(jq -r '.source_basis.e2_candidate_commit' "$CONFIG")
candidate_parent_expected=$(jq -r '.source_basis.e2_candidate_parent' "$CONFIG")
candidate_tree_expected=$(jq -r '.source_basis.e2_candidate_tree' "$CONFIG")
candidate_diff_expected=$(jq -r '.source_basis.e2_candidate_diff_sha256' "$CONFIG")

[ "$(git -C "$LINUX_DIR" rev-parse HEAD)" = "$primary" ] \
	|| die 'primary Linux HEAD moved'
[ "$(git -C "$LINUX_DIR" rev-parse 'HEAD^{tree}')" = "$primary_tree_expected" ] \
	|| die 'primary Linux tree moved'
[ -z "$(git -C "$LINUX_DIR" status --porcelain --untracked-files=no)" ] \
	|| die 'primary Linux tracked working tree is dirty'
[ "$(git -C "$LINUX_DIR" rev-parse "$candidate^")" = "$candidate_parent_expected" ] \
	|| die 'R4-E2 candidate parent moved'
[ "$(git -C "$LINUX_DIR" rev-parse "$candidate^{tree}")" = "$candidate_tree_expected" ] \
	|| die 'R4-E2 candidate tree moved'

git -C "$LINUX_DIR" diff --name-only "$primary..$candidate" > "$OUT_DIR/e2-delta-files.txt"
printf '%s\n' init/Kconfig kernel/sched/exec_lease.c > "$OUT_DIR/expected-e2-delta-files.txt"
diff -u "$OUT_DIR/expected-e2-delta-files.txt" "$OUT_DIR/e2-delta-files.txt" \
	> "$OUT_DIR/e2-delta-files.diff" || die 'R4-E2 escaped exact two-file scope'
git -C "$LINUX_DIR" diff "$primary..$candidate" > "$OUT_DIR/e2-candidate.diff"
candidate_diff_actual=$(sha256sum "$OUT_DIR/e2-candidate.diff" | awk '{print $1}')
[ "$candidate_diff_actual" = "$candidate_diff_expected" ] \
	|| die "R4-E2 candidate diff moved: $candidate_diff_actual"

progress '12% checking exact R4-E2 result and patch-queue hashes'
for key in e2_contract e2_result_metadata e2_dual_arch_result e2_closure_result e2_post_retirement_result; do
	relative=$(jq -r ".source_basis.$key" "$CONFIG")
	expected=$(jq -r ".source_basis.${key}_sha256" "$CONFIG")
	resolved=$(resolve_basis_path "$relative")
	snapshot="$INPUT_DIR/$key.json"
	capsched_snapshot_verified_file "$resolved" "$expected" "$snapshot" \
		|| die "$key snapshot failed exact hash binding"
done

e2_dual="$INPUT_DIR/e2_dual_arch_result.json"
e2_closure="$INPUT_DIR/e2_closure_result.json"
e2_post="$INPUT_DIR/e2_post_retirement_result.json"
e2_dual_source=$(resolve_basis_path "$(jq -r '.source_basis.e2_dual_arch_result' "$CONFIG")")
e2_closure_source=$(resolve_basis_path "$(jq -r '.source_basis.e2_closure_result' "$CONFIG")")
e2_post_source=$(resolve_basis_path "$(jq -r '.source_basis.e2_post_retirement_result' "$CONFIG")")
jq -e '
  .status == "passed" and
  .primary_linux_commit == "5e1ca3037e34823d1ba0cdd1dc04161fac170280" and
  .candidate_commit == "a429fc30252ac6af94c51d96cd4ac24e72d9f83b" and
  .candidate_tree == "fffd419bbc05bab87ad304c1e4a3213439d62bab" and
  .architectures == ["arm64","x86_64"] and
  .existing_expanded_probe_values_preserved == 51 and
  .private_probe_symbols_enabled == 58 and
  .private_symbols_relocations_and_strings_absent_when_disabled == true and
  .ordinary_scheduler_layout_delta_zero == true and
  .private_memory_envelope_passed == true and
  .dual_arch_r4_e2_complete == true and
  .r4_e3_plan_may_start == true and
  .r4_e3_source_may_start == false and
  .primary_linux_changed == false and
  .patch_queue_changed == false and
  .runtime_behavior_approved == false and
  .deployment_ready == false and
  .datacenter_ready == false
' "$e2_dual" >/dev/null

for closure in "$e2_closure" "$e2_post"; do
	jq -e '
          .status == "passed_for_r4_e3_planning_only" and
          .primary_linux_commit == "5e1ca3037e34823d1ba0cdd1dc04161fac170280" and
          .candidate_commit == "a429fc30252ac6af94c51d96cd4ac24e72d9f83b" and
          .candidate_tree == "fffd419bbc05bab87ad304c1e4a3213439d62bab" and
          .exact_direct_child == true and
          .exact_two_file_scope == true and
          .source_files_match_head == true and
          .architectures == ["arm64","x86_64"] and
          .private_disabled_symbol_count == 0 and
          .private_disabled_relocation_count == 0 and
          .private_disabled_string_count == 0 and
          .ordinary_scheduler_layout_delta == {sched_entity:0,cfs_rq:0,rq:0,task_struct:0} and
          .private_memory_envelope_passed == true and
          .dual_arch_r4_e2_complete == true and
          .r4_e3_plan_may_start == true and
          .r4_e3_source_may_start == false and
          .primary_linux_changed == false and
          .patch_queue_changed == false
	' "$closure" >/dev/null
done

patch_commit=$(git -C "$PATCH_DIR" rev-parse HEAD)
[ "$patch_commit" = "$(jq -r '.source_basis.patch_queue_commit' "$CONFIG")" ] \
	|| die 'patch queue commit moved'
series=patches/capsched-linux-l0/series
series_head=$(git -C "$PATCH_DIR" rev-parse "HEAD:$series")
series_working=$(git -C "$PATCH_DIR" hash-object "$series")
[ "$series_head" = "$(jq -r '.source_basis.patch_queue_series_blob' "$CONFIG")" ] \
	|| die 'patch queue series blob moved'
[ "$series_working" = "$series_head" ] || die 'patch queue series working content moved'
git -C "$PATCH_DIR" show "HEAD:$series" > "$INPUT_DIR/patch-series"
chmod 0444 -- "$INPUT_DIR/patch-series"
[ "$(tail -n 1 "$INPUT_DIR/patch-series")" = "$(jq -r '.source_basis.patch_queue_tail' "$CONFIG")" ] \
	|| die 'patch queue tail moved'

progress '20% hashing source basis and checking 48 Linux anchors'
source_manifest="$OUT_DIR/source-object-manifest.tsv"
printf 'ref\tpath\toid\tblob\n' > "$source_manifest"
while IFS=$'\t' read -r ref path; do
	case "$ref" in
		primary) oid=$primary ;;
		candidate) oid=$candidate ;;
		*) die "unknown source ref: $ref" ;;
	esac
	blob=$(git -C "$LINUX_DIR" rev-parse "$oid:$path")
	printf '%s\t%s\t%s\t%s\n' "$ref" "$path" "$oid" "$blob" >> "$source_manifest"
done < <(jq -r '.source_anchors[] | [.ref,.path] | @tsv' "$CONFIG" | sort -u)
source_manifest_count=$(($(wc -l < "$source_manifest") - 1))
[ "$source_manifest_count" = 12 ] || die "source object manifest count: $source_manifest_count"
source_manifest_sha=$(sha256sum "$source_manifest" | awk '{print $1}')

anchor_ledger="$OUT_DIR/source-anchors.tsv"
printf 'id\tstatus\tref\tpath\tpattern\n' > "$anchor_ledger"
while IFS= read -r row; do
	id=$(printf '%s\n' "$row" | jq -r '.id')
	ref=$(printf '%s\n' "$row" | jq -r '.ref')
	path=$(printf '%s\n' "$row" | jq -r '.path')
	pattern=$(printf '%s\n' "$row" | jq -r '.pattern')
	case "$ref" in
		primary) oid=$primary ;;
		candidate) oid=$candidate ;;
		*) die "unknown source anchor ref: $ref" ;;
	esac
	content=$(git -C "$LINUX_DIR" show "$oid:$path")
	if grep -Fq "$pattern" <<<"$content"; then
		status=ok
	else
		status=missing
	fi
	printf '%s\t%s\t%s\t%s\t%s\n' "$id" "$status" "$ref" "$path" "$pattern" \
		>> "$anchor_ledger"
done < <(jq -c '.source_anchors[]' "$CONFIG")
anchor_count=$(jq '.source_anchors | length' "$CONFIG")
anchor_failures=$(awk -F '\t' 'NR > 1 && $2 != "ok" {c++} END {print c+0}' "$anchor_ledger")
[ "$anchor_count" = 48 ] || die "source anchor count: $anchor_count"
[ "$anchor_failures" = 0 ] || die "source anchor failures: $anchor_failures"

absence_ledger="$OUT_DIR/future-absence-checks.tsv"
printf 'id\tstatus\tpattern\n' > "$absence_ledger"
while IFS= read -r row; do
	id=$(printf '%s\n' "$row" | jq -r '.id')
	pattern=$(printf '%s\n' "$row" | jq -r '.pattern')
	if git -C "$LINUX_DIR" grep -Fq "$pattern" "$candidate" -- \
		include/linux init/Kconfig kernel/sched; then
		status=unexpected-present
	else
		status=absent
	fi
	printf '%s\t%s\t%s\n' "$id" "$status" "$pattern" >> "$absence_ledger"
done < <(jq -c '.future_absence_checks[]' "$CONFIG")
absence_count=$(jq '.future_absence_checks | length' "$CONFIG")
absence_failures=$(awk -F '\t' 'NR > 1 && $2 != "absent" {c++} END {print c+0}' "$absence_ledger")
[ "$absence_count" = 10 ] || die "future absence count: $absence_count"
[ "$absence_failures" = 0 ] || die "future absence failures: $absence_failures"

git -C "$LINUX_DIR" show "$primary:include/linux/cpuhotplug.h" > "$OUT_DIR/cpuhotplug.h"
workqueue_line=$(awk '/CPUHP_AP_WORKQUEUE_ONLINE,/ {print NR; exit}' "$OUT_DIR/cpuhotplug.h")
dynamic_line=$(awk '/CPUHP_AP_ONLINE_DYN,/ {print NR; exit}' "$OUT_DIR/cpuhotplug.h")
active_line=$(awk '/CPUHP_AP_ACTIVE,/ {print NR; exit}' "$OUT_DIR/cpuhotplug.h")
[ "$workqueue_line" -lt "$dynamic_line" ] || die 'workqueue CPUHP state moved after ONLINE_DYN'
[ "$dynamic_line" -lt "$active_line" ] || die 'ONLINE_DYN CPUHP state moved after AP_ACTIVE'
printf 'ascending=%s<%s<%s offline=CPUHP_AP_ACTIVE_then_CPUHP_AP_ONLINE_DYN_then_CPUHP_AP_WORKQUEUE_ONLINE\n' \
	"$workqueue_line" "$dynamic_line" "$active_line" > "$OUT_DIR/hotplug-state-order.txt"

progress '28% checking safe bridge, notifier, observation, and drain model'
(
	cd "$MODEL_DIR"
	java -XX:+UseParallelGC -cp "$TLA_JAR" tlc2.TLC -deadlock \
		-metadir "$OUT_DIR/tlc-safe-states" \
		-config "$SAFE_CFG" "$MODEL"
) > "$OUT_DIR/tlc-safe.log" 2>&1
grep -q 'Model checking completed. No error has been found' "$OUT_DIR/tlc-safe.log" \
	|| die 'safe TLC model did not pass'
grep -q 'Checking 4 branches of temporal properties' "$OUT_DIR/tlc-safe.log" \
	|| die 'four TLC liveness properties were not checked'

safe_states=$(sed -n 's/^\([0-9][0-9]*\) states generated.*/\1/p' "$OUT_DIR/tlc-safe.log" | tail -n 1)
safe_distinct=$(sed -n 's/^[0-9][0-9]* states generated, \([0-9][0-9]*\) distinct states found.*/\1/p' "$OUT_DIR/tlc-safe.log" | tail -n 1)
safe_depth=$(sed -n 's/^The depth of the complete state graph search is \([0-9][0-9]*\).*/\1/p' "$OUT_DIR/tlc-safe.log" | tail -n 1)
safe_states=${safe_states:-0}
safe_distinct=${safe_distinct:-0}
safe_depth=${safe_depth:-0}

unsafe_expected=0
unsafe_failures=0
fault_count=$(jq '.formal.unsafe_faults | length' "$CONFIG")
while IFS= read -r fault; do
	name="P5AR4E3ConcurrencyDiagnosticEvidencePlanUnsafe${fault}"
	cfg="$OUT_DIR/generated-unsafe-configs/$name.cfg"
	log="$OUT_DIR/tlc-$name.log"
	printf 'SPECIFICATION Spec\nCONSTANT Fault = "%s"\nINVARIANT TypeOK\nINVARIANT Safety\n' \
		"$fault" > "$cfg"
	if (
		cd "$MODEL_DIR"
		java -XX:+UseParallelGC -cp "$TLA_JAR" tlc2.TLC -deadlock \
			-metadir "$OUT_DIR/states-$name" \
			-config "$cfg" "$MODEL"
	) > "$log" 2>&1; then
		printf 'unsafe fault unexpectedly passed: %s\n' "$fault" >&2
		unsafe_failures=$((unsafe_failures + 1))
	elif grep -Eq 'Invariant (TypeOK|Safety) is violated' "$log"; then
		unsafe_expected=$((unsafe_expected + 1))
		percent=$((28 + (unsafe_expected * 67 / fault_count)))
		progress "$percent% unsafe counterexamples $unsafe_expected/$fault_count"
	else
		printf 'unsafe fault failed unexpectedly: %s\n' "$fault" >&2
		tail -n 60 "$log" >&2
		unsafe_failures=$((unsafe_failures + 1))
	fi
done < <(jq -r '.formal.unsafe_faults[]' "$CONFIG")

[ "$unsafe_failures" = 0 ] || die "unsafe TLC failures: $unsafe_failures"
[ "$unsafe_expected" = "$fault_count" ] \
	|| die "unsafe counterexample mismatch: expected=$fault_count actual=$unsafe_expected"

capsched_verify_file_sha256 "$CONFIG" "$EXPECTED_CONFIG_SHA256" \
	|| die 'plan config snapshot changed during validation'
capsched_verify_file_sha256 "$MODEL_DIR/$MODEL" "$EXPECTED_MODEL_SHA256" \
	|| die 'TLA+ model snapshot changed during validation'
capsched_verify_file_sha256 "$MODEL_DIR/$SAFE_CFG" "$EXPECTED_SAFE_CFG_SHA256" \
	|| die 'safe TLC config snapshot changed during validation'
capsched_verify_file_sha256 "$TLA_JAR" "$EXPECTED_TLA_JAR_SHA256" \
	|| die 'TLA jar snapshot changed during validation'
capsched_verify_file_sha256 "$HARDENING_LIB_SNAPSHOT" "$EXPECTED_HARDENING_LIB_SHA256" \
	|| die 'hardening helper snapshot changed during validation'
for key in e2_contract e2_result_metadata e2_dual_arch_result e2_closure_result e2_post_retirement_result; do
	expected=$(jq -r ".source_basis.${key}_sha256" "$CONFIG")
	snapshot="$INPUT_DIR/$key.json"
	capsched_verify_file_sha256 "$snapshot" "$expected" \
		|| die "$key snapshot changed during validation"
done

config_sha=$(sha256sum "$CONFIG" | awk '{print $1}')
model_sha=$(sha256sum "$MODEL_DIR/$MODEL" | awk '{print $1}')
safe_cfg_sha=$(sha256sum "$MODEL_DIR/$SAFE_CFG" | awk '{print $1}')
runner_sha=$(sha256sum "$RUNNER" | awk '{print $1}')
tla_jar_sha=$(sha256sum "$TLA_JAR" | awk '{print $1}')
helper_sha_at_end=$(sha256sum "$HARDENING_LIB_SNAPSHOT" | awk '{print $1}')
helper_source_sha_at_end=$(sha256sum "$HARDENING_LIB" | awk '{print $1}')
[ "$runner_sha" = "$runner_sha_at_start" ] \
	|| die 'runner changed during validation'
[ "$helper_sha_at_end" = "$EXPECTED_HARDENING_LIB_SHA256" ] \
	|| die 'hardening helper changed during validation'
[ "$helper_source_sha_at_end" = "$EXPECTED_HARDENING_LIB_SHA256" ] \
	|| die 'hardening helper source changed during validation'
case_count=$(jq '.required_case_families | length' "$CONFIG")
fault_site_count=$(jq '.capacity_and_allocation.allocation_fault_sites | length' "$CONFIG")
qemu_boot_count=$(jq '.build_and_boot_matrix.qemu_boots | length' "$CONFIG")

RESULT_TMP="$OUT_DIR/result.json.pending"
jq -n \
	--arg run_id "$RUN_ID" \
	--arg config "$CONFIG_SOURCE" --arg config_sha "$config_sha" \
	--arg model "$MODEL_SOURCE_DIR/$MODEL" --arg model_sha "$model_sha" \
	--arg safe_config "$MODEL_SOURCE_DIR/$SAFE_CFG" --arg safe_config_sha "$safe_cfg_sha" \
	--arg runner "$RUNNER" --arg runner_sha "$runner_sha" \
	--arg hardening_lib "$HARDENING_LIB" --arg hardening_lib_sha "$helper_sha_at_end" \
	--arg tla_jar "$TLA_JAR_SOURCE" --arg tla_jar_sha "$tla_jar_sha" \
	--arg primary "$primary" --arg primary_tree "$primary_tree_expected" \
	--arg candidate "$candidate" --arg candidate_parent "$candidate_parent_expected" \
	--arg candidate_tree "$candidate_tree_expected" --arg candidate_diff "$candidate_diff_actual" \
	--arg patch_commit "$patch_commit" --arg series_blob "$series_working" \
	--arg e2_dual "$e2_dual_source" \
	--arg e2_closure "$e2_closure_source" \
	--arg e2_post "$e2_post_source" \
	--arg source_manifest "$source_manifest" --arg source_manifest_sha "$source_manifest_sha" \
	--argjson source_manifest_count "$source_manifest_count" \
	--argjson anchor_count "$anchor_count" --argjson anchor_failures "$anchor_failures" \
	--argjson absence_count "$absence_count" --argjson absence_failures "$absence_failures" \
	--argjson safe_states "$safe_states" --argjson safe_distinct "$safe_distinct" \
	--argjson safe_depth "$safe_depth" --argjson unsafe_expected "$unsafe_expected" \
	--argjson case_count "$case_count" --argjson fault_site_count "$fault_site_count" \
	--argjson qemu_boot_count "$qemu_boot_count" \
	'{
	  schema_version:1,
	  run_id:$run_id,
	  status:"passed_r4_e3_concurrency_diagnostic_plan_only",
	  config:$config,
	  config_sha256:$config_sha,
	  model:$model,
	  model_sha256:$model_sha,
	  safe_config:$safe_config,
	  safe_config_sha256:$safe_config_sha,
	  runner:$runner,
	  runner_sha256:$runner_sha,
	  hardening_helper:$hardening_lib,
	  hardening_helper_sha256:$hardening_lib_sha,
	  tla_jar:$tla_jar,
	  tla_jar_sha256:$tla_jar_sha,
	  exact_plan_sha256_bound_before_use:true,
	  hardening_helper_snapshotted_before_source:true,
	  immutable_input_snapshots_verified:true,
	  result_published_atomically:true,
	  primary_linux_commit:$primary,
	  primary_linux_tree:$primary_tree,
	  e2_candidate_commit:$candidate,
	  e2_candidate_parent:$candidate_parent,
	  e2_candidate_tree:$candidate_tree,
	  e2_candidate_diff_sha256:$candidate_diff,
	  exact_e2_direct_child:true,
	  exact_future_two_file_scope:true,
	  patch_queue_commit:$patch_commit,
	  patch_queue_series_blob:$series_blob,
	  patch_queue_tail:"0014-sched-exec_lease-Expand-build-only-layout-probe.patch",
	  e2_dual_arch_result:$e2_dual,
	  e2_dual_arch_result_sha256:"6346c3570008942fae533395ff4eb1165c3d42c6572d134c945e20fb57cbad1e",
	  e2_closure_result:$e2_closure,
	  e2_closure_result_sha256:"fed621ee76effc554df806f40f6289d375dafe3f127427a9be73d6ff2ddcc048",
	  e2_post_retirement_result:$e2_post,
	  e2_post_retirement_result_sha256:"27f5a7acc52cc3852ca049a6abc07a72bce2c4e99e7a1a2e02167548a7b3d0f6",
	  source_object_manifest:$source_manifest,
	  source_object_manifest_sha256:$source_manifest_sha,
	  source_object_count:$source_manifest_count,
	  source_anchor_count:$anchor_count,
	  source_anchor_failures:$anchor_failures,
	  future_absence_check_count:$absence_count,
	  future_absence_check_failures:$absence_failures,
	  hotplug_state_order_verified:"CPUHP_AP_ACTIVE_then_CPUHP_AP_ONLINE_DYN_then_CPUHP_AP_WORKQUEUE_ONLINE",
	  safe_passed:true,
	  liveness_properties_checked:4,
	  safe_states_generated:$safe_states,
	  safe_distinct_states:$safe_distinct,
	  safe_depth:$safe_depth,
	  unsafe_expected_counterexamples:$unsafe_expected,
	  b_max_cases:[0,1,63,64,65],
	  required_case_family_count:$case_count,
	  allocation_fault_site_count:$fault_site_count,
	  diagnostic_qemu_boot_count:$qemu_boot_count,
	  architectures:["arm64","x86_64"],
	  future_config:"SCHED_EXEC_LEASE_R4_KUNIT_TEST",
	  future_suite:"sched_exec_lease_r4_concurrency",
	  future_allowed_files:["init/Kconfig","kernel/sched/exec_lease.c"],
	  r4_e3_disposable_worktree_may_be_created:true,
	  r4_e3_exact_two_file_source_draft_may_be_created:true,
	  r4_e3_source_accepted:false,
	  r4_e3_concurrency_correctness_accepted:false,
	  r4_e4_plan_may_be_drafted:false,
	  r4_e4_source_may_be_created:false,
	  primary_linux_change_approved:false,
	  patch_queue_change_approved:false,
	  runtime_scheduler_hook_approved:false,
	  runtime_behavior_approved:false,
	  runtime_denial_correctness:false,
	  monitor_delivery_or_enforcement:false,
	  cross_class_coverage:false,
	  bounded_wall_clock_latency_claim:false,
	  performance_claim:false,
	  cost_claim:false,
	  production_protection:false,
	  deployment_ready:false,
	  multi_node_ready:false,
	  multi_cluster_ready:false,
	  datacenter_ready:false
	}' > "$RESULT_TMP"

jq empty "$RESULT_TMP"
mv -- "$RESULT_TMP" "$OUT_DIR/result.json"
progress '100% passed; N-133 R4-E3 concurrency and diagnostic plan complete'
cat "$OUT_DIR/result.json"
