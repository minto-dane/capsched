#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
LINUX_DIR=${DOMAINLEASE_LINUX_DIR:-"$WORKSPACE_DIR/linux"}
PATCH_DIR="$WORKSPACE_DIR/linux-patches"
CONFIG="$CAPSCHED_DIR/capsched-models/analysis/sched-exec-lease-p5a-r4-e1-dispatch-lifetime-evidence-plan-v1.json"
MODEL_DIR="$CAPSCHED_DIR/capsched-models/formal/0136-p5a-r4-e1-dispatch-lifetime-evidence-plan-model"
MODEL=P5AR4E1DispatchLifetimeEvidencePlan.tla
SAFE_CFG=P5AR4E1DispatchLifetimeEvidencePlanSafe.cfg
TLA_JAR=${TLA_JAR:-"$WORKSPACE_DIR/build/tools/tla/tla2tools.jar"}
R4_RESULT="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r4-generation-fenced-coalesced-pull-recovery/20260716T-p5a-r4-generation-fenced-coalesced-pull-recovery-r1/result.json"
RUN_ID=${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
OUT_DIR="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r4-e1-dispatch-lifetime-evidence-plan/$RUN_ID"
PROGRESS_FILE=${PROGRESS_FILE:-}

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

for command_name in awk git grep java jq sed sha256sum; do
	command -v "$command_name" >/dev/null 2>&1 \
		|| die "missing command: $command_name"
done

[ -f "$TLA_JAR" ] || die "missing TLA jar: $TLA_JAR"
[ -f "$R4_RESULT" ] || die "missing canonical R4 result: $R4_RESULT"
mkdir -p "$OUT_DIR/generated-unsafe-configs"
progress '5% validating frozen R4 input and R4-E1 contract'
jq empty "$CONFIG"

jq -e '
  .status == "r4_e1_pre_source_plan_exact_disposable_e2_only" and
  .source_basis.primary_linux_commit == "5e1ca3037e34823d1ba0cdd1dc04161fac170280" and
  .source_basis.primary_linux_tree == "54f685aad94f28f0027cbba18cf5e29aadce234a" and
  .source_basis.r3_rejected_source_is_parent == false and
  .source_basis.balance_callback_is_post_rq_lock == false and
  .source_basis.mm_cid_irq_work_to_work_is_selected_precedent == true and
  .admission_and_storage.b_max_per_rq == 64 and
  .admission_and_storage.outer_bucket_layers == 1 and
  .admission_and_storage.inner_feature_layers == 1 and
  .admission_and_storage.max_outer_red_black_height == 12 and
  .admission_and_storage.dirty_nodes_per_rq_max == 64 and
  .admission_and_storage.recovery_owners_per_rq == 1 and
  .admission_and_storage.dispatch_irq_work_per_rq == 1 and
  .admission_and_storage.notifier_owners_per_active_bucket == 1 and
  .admission_and_storage.slot_and_projection_before_first_runnable == true and
  .admission_and_storage.slot_65_fails_closed == true and
  .admission_and_storage.overflow_evict_merge_alias_or_fallback == false and
  .admission_and_storage.notifier_jobs_bounded_by_total_admitted_projections == true and
  .admission_and_storage.active_rq_index_is_cpumask_var == true and
  .admission_and_storage.cpu_projection_map_is_sparse == true and
  .admission_and_storage.dense_nr_cpu_ids_pointer_or_projection_array == false and
  .admission_and_storage.allocation_under_rq_or_membership_lock == false and
  .private_representation.bucket_key_max_bytes == 64 and
  .private_representation.bucket_control_with_notifier_max_bytes == 384 and
  .private_representation.projection_with_dirty_node_max_bytes == 960 and
  .private_representation.rq_state_with_bridge_owner_max_bytes == 576 and
  .private_representation.worst_active_private_bytes_per_rq == 62016 and
  .private_representation.worst_active_private_bytes_limit_per_rq == 65536 and
  ((.admission_and_storage.b_max_per_rq * .private_representation.projection_with_dirty_node_max_bytes + .private_representation.rq_state_with_bridge_owner_max_bytes) == .private_representation.worst_active_private_bytes_per_rq) and
  .private_representation.private_object_max_alignment == 64 and
  .private_representation.projection_embeds_inner_cfs_rq == true and
  .private_representation.projection_embeds_outer_sched_entity == true and
  .private_representation.projection_embeds_intrusive_dirty_node == true and
  .private_representation.rq_state_embeds_private_outer_cfs_rq == true and
  .private_representation.rq_state_embeds_exactly_one_irq_work == true and
  .private_representation.rq_state_embeds_exactly_one_work_struct == true and
  .private_representation.rq_state_embeds_bounded_dirty_head == true and
  .private_representation.ordinary_sched_entity_delta_bytes == 0 and
  .private_representation.ordinary_cfs_rq_delta_bytes == 0 and
  .private_representation.ordinary_rq_delta_bytes == 0 and
  .private_representation.ordinary_task_struct_delta_bytes == 0 and
  .e2_boundary.direct_child_of_primary == true and
  .e2_boundary.allowed_files == ["init/Kconfig","kernel/sched/exec_lease.c"] and
  .e2_boundary.config == "SCHED_EXEC_LEASE_R4_LAYOUT_PROBE" and
  .e2_boundary.config_default_n == true and
  .e2_boundary.config_depends_on == ["SCHED_EXEC_LEASE","SCHED_EXEC_LEASE_LAYOUT_PROBE","DEBUG_KERNEL","SMP","FAIR_GROUP_SCHED","IRQ_WORK"] and
  .e2_boundary.private_types_and_object_local_probes_only == true and
  .e2_boundary.constructors_or_callsites == false and
  .e2_boundary.callback_or_workqueue_allocation == false and
  .e2_boundary.cpuhp_registration == false and
  .e2_boundary.static_key == false and
  .e2_boundary.exported_symbol == false and
  .e2_boundary.trace_or_file_or_user_abi == false and
  .e2_boundary.monitor_or_policy_call == false and
  .e2_boundary.public_or_scheduler_header_change == false and
  .e2_boundary.primary_linux_change == false and
  .e2_boundary.patch_queue_change == false and
  .e2_boundary.arm64_architecture_local_build == true and
  .e2_boundary.x86_64_architecture_local_build == true and
  .e2_boundary.existing_expanded_probe_values_preserved == 51 and
  .e2_boundary.disabled_new_symbols_and_relocations_absent == true and
  .dispatch_bridge.queue_balance_callback_rejected_as_post_lock == true and
  .dispatch_bridge.do_balance_callbacks_runs_with_rq_lock == true and
  .dispatch_bridge.rq_locked_state_record_then_irq_work == true and
  .dispatch_bridge.kick_requires_local_irqs_disabled == true and
  .dispatch_bridge.preallocated_hard_irq_work_per_rq == 1 and
  .dispatch_bridge.irq_work_pending_claim_coalesces == true and
  .dispatch_bridge.irq_work_false_keeps_durable_state == true and
  .dispatch_bridge.irq_callback_runs_after_pending_clear_and_full_barrier == true and
  .dispatch_bridge.irq_callback_dispatch_only == true and
  .dispatch_bridge.irq_callback_unconditionally_queues_recovery_work == true and
  .dispatch_bridge.irq_callback_takes_rq_or_membership_lock == false and
  .dispatch_bridge.irq_callback_repairs_or_allocates_or_waits == false and
  .dispatch_bridge.workqueue_flags == ["WQ_UNBOUND","WQ_HIGHPRI","WQ_MEM_RECLAIM"] and
  .dispatch_bridge.queue_work_on_target_cpu == false and
  .dispatch_bridge.one_recovery_work_struct_per_rq == true and
  .dispatch_bridge.queue_false_requires_same_live_owner == true and
  .dispatch_bridge.queue_false_drops_dirty_or_lifetime_ref == false and
  .publisher_and_notifier.publication_critical_section_o1 == true and
  .publisher_and_notifier.one_notifier_ownership_reference == true and
  .publisher_and_notifier.queue_work_after_publication_lock_release == true and
  .publisher_and_notifier.publisher_rq_mask_walk_or_rq_lock_or_ref_loop == false and
  .publisher_and_notifier.one_projection_visit_per_invocation == true and
  .publisher_and_notifier.cursor_api == "cpumask_next" and
  .publisher_and_notifier.membership_lock_released_before_rq_lock == true and
  .publisher_and_notifier.generation_change_restarts == true and
  .publisher_and_notifier.membership_sequence_change_restarts == true and
  .publisher_and_notifier.publisher_clear_handshake_serialized == true and
  .publisher_and_notifier.late_insert_self_handshake_and_kick == true and
  .publisher_and_notifier.stable_window_notification_visit_bound == "at_most_2_times_A" and
  .publisher_and_notifier.bound_is_logical_not_wall_clock == true and
  .recovery.dirty_depth_max == 64 and
  .recovery.desired_generation_latest_wins == true and
  .recovery.duplicates_do_not_grow_depth == true and
  .recovery.one_owner_per_rq == true and
  .recovery.one_projection_per_worker_quantum == true and
  .recovery.nested_lock_order == "rq_then_one_membership" and
  .recovery.two_rq_or_two_membership_locks == false and
  .recovery.final_state_and_acquire_generation_recheck == true and
  .recovery.raced_projection_remains_dirty_or_blocked == true and
  .recovery.worker_requeue_after_all_scheduler_locks == true and
  .recovery.concurrent_insert_always_kicks_irq_bridge == true and
  .current_and_migration.picker_fence_stops_current == false and
  .current_and_migration.current_stop_request_separate == true and
  .current_and_migration.resched_curr_under_rq_lock == true and
  .current_and_migration.later_current_change_or_revalidation_observation_required == true and
  .current_and_migration.resched_is_monitor_interrupt_or_completion_receipt == false and
  .current_and_migration.migration_order == "remove_neutral_add" and
  .current_and_migration.simultaneous_source_destination_contribution == false and
  .current_and_migration.destination_capacity_failure_fails_closed == true and
  .hotplug_and_lifetime.two_phase_hotplug == true and
  .hotplug_and_lifetime.rq_locked_offline_seam == "rq_offline_fair" and
  .hotplug_and_lifetime.sleepable_drain_seam == "CPUHP_AP_ONLINE_DYN_teardown" and
  .hotplug_and_lifetime.offline_source_state_order == "CPUHP_AP_ACTIVE_then_CPUHP_AP_ONLINE_DYN_then_CPUHP_AP_WORKQUEUE_ONLINE" and
  .hotplug_and_lifetime.drain_occurs_after_sched_deactivate_and_before_workqueue_offline == true and
  .hotplug_and_lifetime.offline_clears_accepting_first == true and
  .hotplug_and_lifetime.offline_disarms_new_dirty_ownership_and_kicks == true and
  .hotplug_and_lifetime.residual_projection_bound == 64 and
  .hotplug_and_lifetime.residual_nonzero_forgotten == false and
  .hotplug_and_lifetime.irq_work_sync_before_cancel_work_sync == true and
  .hotplug_and_lifetime.sync_and_cancel_outside_scheduler_locks == true and
  .hotplug_and_lifetime.no_racing_enqueue_before_cancel == true and
  .hotplug_and_lifetime.rcu_grace_before_free == true and
  .hotplug_and_lifetime.generation_wrap_reuse == false and
  .e3_gate.requires_e2_dual_arch_closure == true and
  .e3_gate.separate_plan_required == true and
  .e3_gate.independent_oracle == true and
  .e3_gate.b_max_cases == [0,1,63,64,65] and
  (.e3_gate.required_diagnostics | length) == 9 and
  .e4_gate.requires_e3_correctness_closure == true and
  .e4_gate.minimum_samples_per_cell == 10000 and
  .e4_gate.one_projection_p99_limit_ns == 5000 and
  .e4_gate.one_projection_p999_limit_ns == 25000 and
  .e4_gate.one_projection_max_limit_ns == 50000 and
  .e4_gate.normalized_base_slice_ns == 700000 and
  .e4_gate.base_slice_is_budget == false and
  .e4_gate.global_last_settlement_threshold == false and
  .e4_gate.warning_allowed == false and
  .cross_path.ordinary_cfs_test_scope_only == true and
  .cross_path.future_behavior_gate_requires_integration_or_exclusion == true and
  (.source_anchors | length) == 42 and
  (.future_absence_checks | length) == 8 and
  (.formal.liveness_properties | length) == 3 and
  (.formal.unsafe_faults | length) == 60 and
  .formal.unsafe_expected_counterexamples == 60 and
  .authorization_after_pass.r4_e2_disposable_worktree_may_be_created == true and
  .authorization_after_pass.r4_e2_exact_two_file_layout_draft_may_be_created == true and
  .authorization_after_pass.r4_e3_source_may_be_created == false and
  .authorization_after_pass.r4_e4_source_may_be_created == false and
  .authorization_after_pass.r4_behavior_source_may_be_created == false and
  .authorization_after_pass.primary_linux_may_change == false and
  .authorization_after_pass.patch_queue_may_change == false and
  (.safety_flags | all(.[]; . == false))
' "$CONFIG" >/dev/null

expected_r4_sha=$(jq -r '.source_basis.r4_result_sha256' "$CONFIG")
actual_r4_sha=$(sha256sum "$R4_RESULT" | awk '{print $1}')
[ "$actual_r4_sha" = "$expected_r4_sha" ] \
	|| die "R4 result hash mismatch: expected=$expected_r4_sha actual=$actual_r4_sha"

jq -e '
  .status == "passed_generation_fenced_coalesced_pull_recovery_architecture_only" and
  .linux_commit == "5e1ca3037e34823d1ba0cdd1dc04161fac170280" and
  .linux_tree == "54f685aad94f28f0027cbba18cf5e29aadce234a" and
  .source_anchor_failures == 0 and
  .future_absence_check_failures == 0 and
  .safe_passed == true and
  .liveness_properties_checked == 2 and
  .unsafe_expected_counterexamples == 47 and
  .r4_e1_evidence_plan_may_be_drafted == true and
  .disposable_linux_source_may_be_created == false
' "$R4_RESULT" >/dev/null

expected_commit=$(jq -r '.source_basis.primary_linux_commit' "$CONFIG")
expected_tree=$(jq -r '.source_basis.primary_linux_tree' "$CONFIG")
actual_commit=$(git -C "$LINUX_DIR" rev-parse --verify HEAD)
actual_tree=$(git -C "$LINUX_DIR" rev-parse --verify 'HEAD^{tree}')
[ "$actual_commit" = "$expected_commit" ] \
	|| die "Linux commit mismatch: expected=$expected_commit actual=$actual_commit"
[ "$actual_tree" = "$expected_tree" ] \
	|| die "Linux tree mismatch: expected=$expected_tree actual=$actual_tree"
[ -z "$(git -C "$LINUX_DIR" status --porcelain --untracked-files=no)" ] \
	|| die 'Linux tracked working tree is dirty'

expected_patch=$(jq -r '.source_basis.patch_queue_commit' "$CONFIG")
actual_patch=$(git -C "$PATCH_DIR" rev-parse --verify HEAD)
[ "$actual_patch" = "$expected_patch" ] \
	|| die "patch queue commit mismatch: expected=$expected_patch actual=$actual_patch"

progress '15% checking Linux dispatch, hotplug, and lifetime anchors'
anchor_ledger="$OUT_DIR/source-anchors.tsv"
printf 'id\tstatus\tpath\tpattern\n' > "$anchor_ledger"
while IFS= read -r row; do
	id=$(printf '%s\n' "$row" | jq -r '.id')
	relative_path=$(printf '%s\n' "$row" | jq -r '.path')
	pattern=$(printf '%s\n' "$row" | jq -r '.pattern')
	file="$WORKSPACE_DIR/$relative_path"
	if [ -f "$file" ] && grep -Fq "$pattern" "$file"; then
		status=ok
	else
		status=missing
	fi
	printf '%s\t%s\t%s\t%s\n' "$id" "$status" "$relative_path" "$pattern" \
		>> "$anchor_ledger"
done < <(jq -c '.source_anchors[]' "$CONFIG")

anchor_count=$(jq '.source_anchors | length' "$CONFIG")
anchor_failures=$(awk -F '\t' 'NR > 1 && $2 != "ok" {c++} END {print c+0}' "$anchor_ledger")
[ "$anchor_count" = 42 ] || die "unexpected source anchor count: $anchor_count"
[ "$anchor_failures" = 0 ] || die "source anchor failures: $anchor_failures"

workqueue_state_line=$(grep -n -m1 'CPUHP_AP_WORKQUEUE_ONLINE,' \
	"$LINUX_DIR/include/linux/cpuhotplug.h" | cut -d: -f1)
dynamic_state_line=$(grep -n -m1 'CPUHP_AP_ONLINE_DYN,' \
	"$LINUX_DIR/include/linux/cpuhotplug.h" | cut -d: -f1)
active_state_line=$(grep -n -m1 'CPUHP_AP_ACTIVE,' \
	"$LINUX_DIR/include/linux/cpuhotplug.h" | cut -d: -f1)
[ "$workqueue_state_line" -lt "$dynamic_state_line" ] \
	|| die 'CPUHP workqueue state no longer precedes dynamic online state'
[ "$dynamic_state_line" -lt "$active_state_line" ] \
	|| die 'CPUHP dynamic online state no longer precedes scheduler active state'
printf 'ascending=%s<%s<%s offline=%s_then_%s_then_%s\n' \
	"$workqueue_state_line" "$dynamic_state_line" "$active_state_line" \
	"CPUHP_AP_ACTIVE" "CPUHP_AP_ONLINE_DYN" "CPUHP_AP_WORKQUEUE_ONLINE" \
	> "$OUT_DIR/hotplug-state-order.txt"

absence_ledger="$OUT_DIR/future-absence-checks.tsv"
printf 'id\tstatus\tpattern\n' > "$absence_ledger"
while IFS= read -r row; do
	id=$(printf '%s\n' "$row" | jq -r '.id')
	pattern=$(printf '%s\n' "$row" | jq -r '.pattern')
	if git -C "$LINUX_DIR" grep -Fq "$pattern" -- \
		include/linux init/Kconfig kernel/sched; then
		status=unexpected-present
	else
		status=absent
	fi
	printf '%s\t%s\t%s\n' "$id" "$status" "$pattern" >> "$absence_ledger"
done < <(jq -c '.future_absence_checks[]' "$CONFIG")

absence_count=$(jq '.future_absence_checks | length' "$CONFIG")
absence_failures=$(awk -F '\t' 'NR > 1 && $2 != "absent" {c++} END {print c+0}' "$absence_ledger")
[ "$absence_count" = 8 ] || die "unexpected absence count: $absence_count"
[ "$absence_failures" = 0 ] || die "future absence failures: $absence_failures"

progress '25% checking safe dispatch, restart, and offline liveness model'
(
	cd "$MODEL_DIR"
	java -XX:+UseParallelGC -cp "$TLA_JAR" tlc2.TLC -deadlock \
		-metadir "$OUT_DIR/tlc-safe-states" \
		-config "$SAFE_CFG" "$MODEL"
) > "$OUT_DIR/tlc-safe.log" 2>&1
grep -q 'Model checking completed. No error has been found' "$OUT_DIR/tlc-safe.log" \
	|| die 'safe TLC model did not pass'
grep -q 'Checking 3 branches of temporal properties' "$OUT_DIR/tlc-safe.log" \
	|| die 'three safe TLC liveness properties were not checked'

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
	name="P5AR4E1DispatchLifetimeEvidencePlanUnsafe${fault}"
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
		percent=$((25 + (unsafe_expected * 70 / fault_count)))
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

jq -n \
	--arg run_id "$RUN_ID" \
	--arg linux_commit "$actual_commit" \
	--arg linux_tree "$actual_tree" \
	--arg patch_queue_commit "$actual_patch" \
	--arg r4_result "$R4_RESULT" \
	--arg r4_result_sha256 "$actual_r4_sha" \
	--arg config "$CONFIG" \
	--arg model_dir "$MODEL_DIR" \
	--argjson source_anchor_count "$anchor_count" \
	--argjson source_anchor_failures "$anchor_failures" \
	--argjson future_absence_check_count "$absence_count" \
	--argjson future_absence_check_failures "$absence_failures" \
	--argjson safe_states_generated "$safe_states" \
	--argjson safe_distinct_states "$safe_distinct" \
	--argjson safe_depth "$safe_depth" \
	--argjson unsafe_expected_counterexamples "$unsafe_expected" \
	'{
	  schema_version: 1,
	  run_id: $run_id,
	  status: "passed_r4_e1_dispatch_lifetime_plan_only",
	  linux_commit: $linux_commit,
	  linux_tree: $linux_tree,
	  patch_queue_commit: $patch_queue_commit,
	  r4_result: $r4_result,
	  r4_result_sha256: $r4_result_sha256,
	  config: $config,
	  model_dir: $model_dir,
	  source_anchor_count: $source_anchor_count,
	  source_anchor_failures: $source_anchor_failures,
	  future_absence_check_count: $future_absence_check_count,
	  future_absence_check_failures: $future_absence_check_failures,
	  b_max_per_rq: 64,
	  worst_active_private_bytes_per_rq: 62016,
	  worst_active_private_bytes_limit_per_rq: 65536,
	  allowed_e2_files: ["init/Kconfig", "kernel/sched/exec_lease.c"],
	  selected_post_lock_bridge: "rq_locked_irq_work_then_unbound_workqueue",
	  balance_callback_rejected_as_post_lock: true,
	  notifier_visit_bound: "at_most_2_times_A_after_stable_window",
	  one_projection_per_recovery_quantum: true,
	  hotplug_drain: "rq_locked_disarm_then_sleepable_irq_sync_cancel_rcu",
	  hotplug_state_order_verified: "CPUHP_AP_ACTIVE_then_CPUHP_AP_ONLINE_DYN_then_CPUHP_AP_WORKQUEUE_ONLINE",
	  safe_passed: true,
	  liveness_properties_checked: 3,
	  safe_states_generated: $safe_states_generated,
	  safe_distinct_states: $safe_distinct_states,
	  safe_depth: $safe_depth,
	  unsafe_expected_counterexamples: $unsafe_expected_counterexamples,
	  r4_e2_disposable_worktree_may_be_created: true,
	  r4_e2_exact_two_file_layout_draft_may_be_created: true,
	  r4_e3_source_may_be_created: false,
	  r4_e4_source_may_be_created: false,
	  behavior_patch_approved: false,
	  primary_linux_change_approved: false,
	  patch_queue_change_approved: false,
	  runtime_behavior_approved: false,
	  production_protection: false,
	  bounded_wall_clock_latency_claim: false,
	  performance_claim: false,
	  cost_claim: false,
	  deployment_ready: false,
	  datacenter_ready: false
	}' > "$OUT_DIR/result.json"

progress '100% passed; R4-E1 dispatch and lifetime plan complete'
cat "$OUT_DIR/result.json"
