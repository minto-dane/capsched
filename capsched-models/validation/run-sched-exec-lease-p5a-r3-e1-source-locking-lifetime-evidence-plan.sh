#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
LINUX_DIR=${DOMAINLEASE_LINUX_DIR:-"$WORKSPACE_DIR/linux"}
PATCH_DIR="$WORKSPACE_DIR/linux-patches"
CONFIG="$CAPSCHED_DIR/capsched-models/analysis/sched-exec-lease-p5a-r3-e1-source-locking-lifetime-evidence-plan-v1.json"
MODEL_DIR="$CAPSCHED_DIR/capsched-models/formal/0132-p5a-r3-e1-source-locking-lifetime-evidence-plan-model"
MODEL=P5AR3E1SourceLockingLifetimeEvidencePlan.tla
SAFE_CFG=P5AR3E1SourceLockingLifetimeEvidencePlanSafe.cfg
TLA_JAR=${TLA_JAR:-"$WORKSPACE_DIR/build/tools/tla/tla2tools.jar"}
R3_RESULT="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r3-bucket-local-targeted-projection/20260715T-p5a-r3-bucket-local-plan-r2/result.json"
RUN_ID=${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
OUT_DIR="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r3-e1-source-locking-lifetime-evidence-plan/$RUN_ID"

die()
{
	printf 'error: %s\n' "$*" >&2
	exit 1
}

for command_name in awk git grep java jq sed sha256sum; do
	command -v "$command_name" >/dev/null 2>&1 \
		|| die "missing command: $command_name"
done

[ -f "$TLA_JAR" ] || die "missing TLA jar: $TLA_JAR"
[ -f "$R3_RESULT" ] || die "missing canonical R3 result: $R3_RESULT"
mkdir -p "$OUT_DIR/generated-unsafe-configs"
jq empty "$CONFIG"

jq -e '
  .status == "r3_e1_pre_source_plan_exact_disposable_e2_only" and
  (.source_basis.rejected_e4_source_is_parent == false) and
  (.admission_bound.b_max_per_rq == 64) and
  (.admission_bound.outer_bucket_layers == 1) and
  (.admission_bound.inner_feature_layers == 1) and
  (.admission_bound.max_outer_red_black_height == 12) and
  (.admission_bound.slot_required_before_first_runnable == true) and
  (.admission_bound.projection_preconstructed_before_first_runnable == true) and
  (.admission_bound.slot_65_fails_closed == true) and
  (.admission_bound.overflow_evicts_or_merges == false) and
  (.admission_bound.overflow_falls_back_to_mixed_tree == false) and
  (.private_representation.bucket_key_u64_words == 8) and
  (.private_representation.bucket_key_max_bytes == 64) and
  (.private_representation.bucket_control_max_bytes == 256) and
  (.private_representation.projection_max_bytes == 896) and
  (.private_representation.private_rq_state_max_bytes == 448) and
  (.private_representation.worst_active_private_bytes_per_rq == 57792) and
  (.private_representation.worst_active_private_bytes_limit_per_rq == 65536) and
  ((.admission_bound.b_max_per_rq * .private_representation.projection_max_bytes + .private_representation.private_rq_state_max_bytes) == .private_representation.worst_active_private_bytes_per_rq) and
  (.private_representation.projection_embeds_inner_cfs_rq == true) and
  (.private_representation.projection_embeds_one_outer_sched_entity == true) and
  (.private_representation.private_rq_state_embeds_outer_cfs_rq == true) and
  (.private_representation.active_rq_index_is_cpumask_var == true) and
  (.private_representation.projection_map_is_sparse == true) and
  (.private_representation.dense_nr_cpu_ids_projection_or_pointer_array_allowed == false) and
  (.private_representation.allocation_under_rq_or_membership_lock == false) and
  (.private_representation.ordinary_sched_entity_delta_bytes == 0) and
  (.private_representation.ordinary_cfs_rq_delta_bytes == 0) and
  (.private_representation.ordinary_rq_delta_bytes == 0) and
  (.private_representation.ordinary_task_struct_delta_bytes == 0) and
  (.e2_boundary.direct_child_of_primary == true) and
  (.e2_boundary.allowed_files == ["init/Kconfig","kernel/sched/exec_lease.c"]) and
  (.e2_boundary.config == "SCHED_EXEC_LEASE_BUCKET_LAYOUT_PROBE") and
  (.e2_boundary.config_default_n == true) and
  (.e2_boundary.config_depends_on == ["SCHED_EXEC_LEASE","SCHED_EXEC_LEASE_LAYOUT_PROBE","DEBUG_KERNEL","SMP","FAIR_GROUP_SCHED"]) and
  (.e2_boundary.probe_symbols_object_local == true) and
  (.e2_boundary.probe_symbols_in_exec_lease_object == true) and
  (.e2_boundary.constructors_or_callsites == false) and
  (.e2_boundary.static_key == false) and
  (.e2_boundary.exported_symbol == false) and
  (.e2_boundary.trace_or_user_abi == false) and
  (.e2_boundary.monitor_or_policy_call == false) and
  (.e2_boundary.public_header_change == false) and
  (.e2_boundary.primary_linux_change == false) and
  (.e2_boundary.patch_queue_change == false) and
  (.e2_boundary.arm64_architecture_local_build == true) and
  (.e2_boundary.x86_64_architecture_local_build == true) and
  (.e2_boundary.existing_expanded_probe_values_preserved == 51) and
  (.e2_boundary.disabled_new_symbols_and_relocations_absent == true) and
  (.locking.mutation_order == "rq_then_at_most_one_raw_membership_lock") and
  (.locking.publisher_membership_lock_only == true) and
  (.locking.publisher_releases_before_queue == true) and
  (.locking.publisher_takes_rq_lock == false) and
  (.locking.worker_updates_one_projection_under_one_rq_lock == true) and
  (.locking.worker_releases_rq_before_membership_settlement == true) and
  (.locking.reverse_membership_to_rq_order == false) and
  (.locking.two_membership_locks_held == false) and
  (.locking.queue_work_under_scheduler_lock == false) and
  (.locking.cancel_work_sync_under_scheduler_lock == false) and
  (.locking.allocation_or_free_under_scheduler_lock == false) and
  (.locking.hotplug_max_projection_visits == 64) and
  (.work_protocol.dedicated_workqueue == true) and
  (.work_protocol.workqueue_flags == ["WQ_UNBOUND","WQ_HIGHPRI","WQ_MEM_RECLAIM"]) and
  (.work_protocol.queue_api == "queue_work") and
  (.work_protocol.queue_work_on_used == false) and
  (.work_protocol.one_work_ownership_reference_per_projection == true) and
  (.work_protocol.desired_generation_coalesced_under_membership_lock == true) and
  (.work_protocol.refs_acquired_before_queue == true) and
  (.work_protocol.queue_false_requires_existing_live_owner == true) and
  (.work_protocol.worker_rechecks_desired_after_rq_unlock == true) and
  (.work_protocol.worker_clear_vs_republish_serialized == true) and
  (.work_protocol.requeue_outside_locks == true) and
  (.work_protocol.cpu_bound_callback_required == false) and
  (.cpu_hotplug.online_seam == "rq_online_fair under rq lock") and
  (.cpu_hotplug.offline_seam == "rq_offline_fair under rq lock") and
  (.cpu_hotplug.online_initializes_before_accepting == true) and
  (.cpu_hotplug.admission_requires_cpu_active == true) and
  (.cpu_hotplug.admission_requires_rq_online == true) and
  (.cpu_hotplug.admission_requires_private_accepting == true) and
  (.cpu_hotplug.offline_clears_accepting_first == true) and
  (.cpu_hotplug.residual_projection_visits_bounded_by_b_max == true) and
  (.cpu_hotplug.residual_nonzero_contribution_forgotten == false) and
  (.cpu_hotplug.active_bit_cleared_with_nonzero_contribution == false) and
  (.cpu_hotplug.offline_work_stranded_on_target_cpu == false) and
  (.lifetime.retiring_blocks_new_work_ownership == true) and
  (.lifetime.rcu_unpublish_before_drain == true) and
  (.lifetime.task_refs_zero_before_free == true) and
  (.lifetime.contribution_refs_zero_before_free == true) and
  (.lifetime.active_rq_mask_empty_before_free == true) and
  (.lifetime.cancel_each_sparse_projection_work == true) and
  (.lifetime.cancel_work_sync_outside_scheduler_locks == true) and
  (.lifetime.canceled_work_owner_ref_settled == true) and
  (.lifetime.no_racing_enqueue_before_cancel == true) and
  (.lifetime.projection_free_after_work_drain == true) and
  (.lifetime.bucket_free_after_rcu_grace == true) and
  (.lifetime.workqueue_destroy_after_all_bucket_drain == true) and
  (.lifetime.generation_saturation_blocks_and_replaces == true) and
  (.lifetime.generation_wrap_reuse == false) and
  (.lifetime.cancel_work_sync_is_revocation_receipt == false) and
  (.e3_gate.requires_e2_dual_arch_closure == true) and
  (.e3_gate.separate_plan_required == true) and
  (.e3_gate.b_max_cases == [0,1,63,64,65]) and
  (.e3_gate | .publish_insert_and_republish_races and .worker_clear_publisher_race and .queue_false_pending_running_case and .generation_saturation_case and .queued_delayed_current_accounting and .migration_and_capacity_failure and .hotplug_publication_work_races and .retire_worker_dequeue_rcu_races and .pending_running_requeued_cancel_cases and .pre_runnable_allocation_fault_injection) and
  (.e4_rejection.minimum_samples_per_cell == 10000) and
  (.e4_rejection.bucket_occupancy == [1,8,32,64]) and
  (.e4_rejection.inner_runnable == [0,1,64,4096]) and
  (.e4_rejection.generation_states == ["stable","raced"]) and
  (.e4_rejection.one_projection_p99_limit_ns == 5000) and
  (.e4_rejection.one_projection_p999_limit_ns == 25000) and
  (.e4_rejection.one_projection_max_limit_ns == 50000) and
  (.e4_rejection.normalized_base_slice_ns == 700000) and
  (.e4_rejection.hotplug_occupancy == [0,1,8,32,64]) and
  (.e4_rejection.hotplug_p99_limit_ns == 25000) and
  (.e4_rejection.hotplug_max_limit_ns == 50000) and
  (.e4_rejection.fanout_active_rqs == [1,2,8,32,64]) and
  (.e4_rejection.fanout_p99_limit_ns == 10000000) and
  (.e4_rejection.fanout_max_limit_ns == 100000000) and
  (.e4_rejection.fanout_is_availability_not_trust_gate == true) and
  (.e4_rejection.warning_allowed == false) and
  (.e4_rejection.virtual_result_supports_bare_metal_claim == false) and
  (.e4_rejection.range_reduction_after_failure_allowed == false) and
  (.cross_path.ordinary_cfs_test_scope_only == true) and
  (.cross_path.sched_ext_covered == false) and
  (.cross_path.core_force_idle_covered == false) and
  (.cross_path.proxy_covered == false) and
  (.cross_path.deadline_server_covered == false) and
  (.cross_path.rt_dl_covered == false) and
  (.cross_path.idle_stop_percpu_kthread_covered == false) and
  (.cross_path.monitor_delivery_covered == false) and
  (.cross_path.e5_requires_integration_or_exclusion == true) and
  (.formal.unsafe_faults | length == 36) and
  (.formal.unsafe_expected_counterexamples == 36) and
  (.authorization_after_pass.r3_e2_disposable_worktree_may_be_created == true) and
  (.authorization_after_pass.r3_e2_exact_two_file_layout_draft_may_be_created == true) and
  (.authorization_after_pass.r3_e3_source_may_be_created == false) and
  (.authorization_after_pass.r3_e4_source_may_be_created == false) and
  (.authorization_after_pass.r3_e5_behavior_may_be_created == false) and
  (.authorization_after_pass.primary_linux_may_change == false) and
  (.authorization_after_pass.patch_queue_may_change == false) and
  (.safety_flags | all(.[]; . == false))
' "$CONFIG" >/dev/null

expected_r3_sha=$(jq -r '.source_basis.r3_result_sha256' "$CONFIG")
actual_r3_sha=$(sha256sum "$R3_RESULT" | awk '{print $1}')
[ "$actual_r3_sha" = "$expected_r3_sha" ] \
	|| die "R3 result hash mismatch: expected=$expected_r3_sha actual=$actual_r3_sha"
jq -e '
  .status == "passed_bucket_local_targeted_projection_architecture_only" and
  .linux_commit == "5e1ca3037e34823d1ba0cdd1dc04161fac170280" and
  .linux_tree == "54f685aad94f28f0027cbba18cf5e29aadce234a" and
  .source_anchor_failures == 0 and
  .future_absence_check_failures == 0 and
  .safe_passed == true and
  .unsafe_expected_counterexamples == 34 and
  .r3_e1_evidence_plan_may_be_drafted == true and
  .disposable_linux_source_may_be_created == false
' "$R3_RESULT" >/dev/null

expected_commit=$(jq -r '.source_basis.primary_linux_commit' "$CONFIG")
expected_tree=$(jq -r '.source_basis.primary_linux_tree' "$CONFIG")
actual_commit=$(git -C "$LINUX_DIR" rev-parse --verify HEAD)
actual_tree=$(git -C "$LINUX_DIR" rev-parse --verify HEAD^{tree})
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
[ "$anchor_count" = 38 ] || die "unexpected source anchor count: $anchor_count"
[ "$anchor_failures" = 0 ] || die "source anchor failures: $anchor_failures"

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

(
	cd "$MODEL_DIR"
	java -cp "$TLA_JAR" tlc2.TLC -deadlock \
		-metadir "$OUT_DIR/tlc-safe-states" \
		-config "$SAFE_CFG" "$MODEL"
) > "$OUT_DIR/tlc-safe.log" 2>&1
grep -q 'Model checking completed. No error has been found' "$OUT_DIR/tlc-safe.log" \
	|| die 'safe TLC model did not pass'

safe_states=$(sed -n 's/^\([0-9][0-9]*\) states generated.*/\1/p' "$OUT_DIR/tlc-safe.log" | tail -n 1)
safe_distinct=$(sed -n 's/^[0-9][0-9]* states generated, \([0-9][0-9]*\) distinct states found.*/\1/p' "$OUT_DIR/tlc-safe.log" | tail -n 1)
safe_depth=$(sed -n 's/^The depth of the complete state graph search is \([0-9][0-9]*\).*/\1/p' "$OUT_DIR/tlc-safe.log" | tail -n 1)
safe_states=${safe_states:-0}
safe_distinct=${safe_distinct:-0}
safe_depth=${safe_depth:-0}

unsafe_expected=0
unsafe_failures=0
while IFS= read -r fault; do
	name="P5AR3E1SourceLockingLifetimeEvidencePlanUnsafe${fault}"
	cfg="$OUT_DIR/generated-unsafe-configs/$name.cfg"
	log="$OUT_DIR/tlc-$name.log"
	printf 'SPECIFICATION Spec\nCONSTANT Fault = "%s"\nINVARIANT Safety\n' \
		"$fault" > "$cfg"
	if (
		cd "$MODEL_DIR"
		java -cp "$TLA_JAR" tlc2.TLC -deadlock \
			-metadir "$OUT_DIR/states-$name" \
			-config "$cfg" "$MODEL"
	) > "$log" 2>&1; then
		printf 'unsafe fault unexpectedly passed: %s\n' "$fault" >&2
		unsafe_failures=$((unsafe_failures + 1))
	elif grep -q 'Invariant Safety is violated' "$log"; then
		unsafe_expected=$((unsafe_expected + 1))
	else
		printf 'unsafe fault failed unexpectedly: %s\n' "$fault" >&2
		tail -n 60 "$log" >&2
		unsafe_failures=$((unsafe_failures + 1))
	fi
done < <(jq -r '.formal.unsafe_faults[]' "$CONFIG")

[ "$unsafe_failures" = 0 ] || die "unsafe TLC failures: $unsafe_failures"
[ "$unsafe_expected" = 36 ] \
	|| die "unsafe counterexample count mismatch: $unsafe_expected"

jq -n \
	--arg run_id "$RUN_ID" \
	--arg linux_commit "$actual_commit" \
	--arg linux_tree "$actual_tree" \
	--arg patch_queue_commit "$actual_patch" \
	--arg r3_result_sha256 "$actual_r3_sha" \
	--arg config "$CONFIG" \
	--arg model_dir "$MODEL_DIR" \
	--arg tla_jar "$TLA_JAR" \
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
	  status: "passed_r3_e1_plan_only",
	  linux_commit: $linux_commit,
	  linux_tree: $linux_tree,
	  patch_queue_commit: $patch_queue_commit,
	  r3_result_sha256: $r3_result_sha256,
	  config: $config,
	  model_dir: $model_dir,
	  tla_jar: $tla_jar,
	  source_anchor_count: $source_anchor_count,
	  source_anchor_failures: $source_anchor_failures,
	  future_absence_check_count: $future_absence_check_count,
	  future_absence_check_failures: $future_absence_check_failures,
	  b_max_per_rq: 64,
	  max_outer_red_black_height: 12,
	  worst_active_private_bytes_per_rq: 57792,
	  worst_active_private_bytes_limit_per_rq: 65536,
	  allowed_e2_files: ["init/Kconfig", "kernel/sched/exec_lease.c"],
	  one_projection_limits_ns: {p99: 5000, p999: 25000, max: 50000},
	  hotplug_limits_ns: {p99: 25000, max: 50000},
	  fanout_limits_ns: {p99: 10000000, max: 100000000},
	  safe_passed: true,
	  safe_states_generated: $safe_states_generated,
	  safe_distinct_states: $safe_distinct_states,
	  safe_depth: $safe_depth,
	  unsafe_expected_counterexamples: $unsafe_expected_counterexamples,
	  r3_e2_disposable_worktree_may_be_created: true,
	  r3_e2_exact_two_file_layout_draft_may_be_created: true,
	  r3_e3_source_may_be_created: false,
	  r3_e4_source_may_be_created: false,
	  behavior_patch_approved: false,
	  primary_linux_change_approved: false,
	  patch_queue_change_approved: false,
	  production_protection: false,
	  performance_claim: false,
	  cost_claim: false,
	  deployment_ready: false,
	  datacenter_ready: false
	}' > "$OUT_DIR/result.json"

cat "$OUT_DIR/result.json"
