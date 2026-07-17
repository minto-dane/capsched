#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
LINUX_DIR=${DOMAINLEASE_LINUX_DIR:-"$WORKSPACE_DIR/linux"}
CONFIG="$CAPSCHED_DIR/capsched-models/analysis/sched-exec-lease-p5a-r4-generation-fenced-coalesced-pull-recovery-v1.json"
MODEL_DIR="$CAPSCHED_DIR/capsched-models/formal/0135-p5a-r4-generation-fenced-coalesced-pull-recovery-model"
MODEL=P5AR4GenerationFencedCoalescedPullRecovery.tla
SAFE_CFG=P5AR4GenerationFencedCoalescedPullRecoverySafe.cfg
TLA_JAR=${TLA_JAR:-"$WORKSPACE_DIR/build/tools/tla/tla2tools.jar"}
R3_RESULT="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r3-e4-bucket-measurement/20260716T-p5a-r3-e4-arm64-measurement-r1/result.json"
RUN_ID=${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
OUT_DIR="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r4-generation-fenced-coalesced-pull-recovery/$RUN_ID"
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
[ -f "$R3_RESULT" ] || die "missing canonical R3 result: $R3_RESULT"
mkdir -p "$OUT_DIR/generated-unsafe-configs"
progress '5% validating frozen R3 trigger and R4 contract'
jq empty "$CONFIG"

jq -e '
  .status == "generation_fenced_coalesced_pull_recovery_architecture_gate_no_linux_patch" and
  .trigger.status == "rejected_r3_bucket_measurement" and
  .trigger.rejected_cells == 19 and
  .trigger.threshold_breaches == 26 and
  .trigger.valid_negative_evidence == true and
  .trigger.r3_generation_mismatch_already_prevented_trust == true and
  .trigger.r3_fanout_gate_was_availability_only == true and
  .trigger.r3_fanout_was_trust_authority == false and
  .trigger.x86_64_and_e5_stopped == true and
  .decision.name == "generation_fenced_coalesced_pull_recovery" and
  .decision.authority_publication_critical_section_o1 == true and
  .decision.picker_generation_fence_o1 == true and
  .decision.mismatch_fails_closed == true and
  .decision.one_preallocated_bucket_notifier == true and
  .decision.one_preallocated_recovery_owner_per_rq == true and
  .decision.one_dirty_node_per_projection == true and
  .decision.latest_desired_generation_coalesces == true and
  .decision.queue_depth_depends_on_distinct_admitted_projections_not_publications == true and
  .decision.one_projection_per_rq_lock_quantum == true and
  .decision.global_last_settlement_acceptance_required == false and
  .decision.notification_or_completion_is_authority == false and
  .publication_contract.frozen_state_before_generation == true and
  .publication_contract.generation_release_published == true and
  .publication_contract.generation_wrap_reuse == false and
  .publication_contract.generation_saturation_blocks == true and
  .publication_contract.rq_mask_walk_in_authority_critical_section == false and
  .publication_contract.rq_lock_in_authority_critical_section == false and
  .publication_contract.per_rq_reference_loop_in_authority_critical_section == false and
  .publication_contract.allocation_sleep_flush_cancel_or_wait == false and
  .publication_contract.one_idempotent_notifier_kick_allowed == true and
  .publication_contract.publisher_waits_for_recovery == false and
  .picker_contract.requires_local_fresh == true and
  .picker_contract.requires_local_generation_equals_acquire_published_generation == true and
  .picker_contract.requires_bucket_eligible == true and
  .picker_contract.requires_selector_key_match == true and
  .picker_contract.requires_final_task_local_recheck == true and
  .picker_contract.mismatch_records_at_most_one_preallocated_kick == true and
  .picker_contract.post_lock_dispatch_seam_must_be_source_mapped == true and
  .picker_contract.repair_or_leaf_scan == false and
  .picker_contract.all_bucket_scan == false and
  .picker_contract.allocation_policy_monitor_or_wait == false and
  .picker_contract.fallback_authority_minted == false and
  .recovery_contract.dirty_queue_intrusive_and_preallocated == true and
  .recovery_contract.dirty_queue_bound_is_b_max == true and
  .recovery_contract.duplicate_generation_queue_growth == false and
  .recovery_contract.owner_depth_per_rq_at_most_one == true and
  .recovery_contract.desired_generation_monotonic_to_latest == true and
  .recovery_contract.one_projection_per_quantum == true and
  .recovery_contract.one_owning_rq_lock == true and
  .recovery_contract.at_most_one_bucket_membership_lock == true and
  .recovery_contract.lock_order == "rq_then_one_bucket_membership_lock" and
  .recovery_contract.inner_leaf_or_hierarchy_scan == false and
  .recovery_contract.final_generation_and_state_recheck == true and
  .recovery_contract.raced_work_remains_dirty_or_blocked == true and
  .recovery_contract.caller_waits_for_recovery == false and
  .notifier_contract.one_preallocated_owner_per_bucket == true and
  .notifier_contract.repeated_publications_coalesce == true and
  .notifier_contract.bounded_quanta_outside_publication_critical_section == true and
  .notifier_contract.active_and_current_membership_only == true and
  .notifier_contract.restart_after_final_generation_change == true and
  .notifier_contract.accelerates_availability_only == true and
  .notifier_contract.may_request_resched_for_ineligible_current_under_rq_lock == true and
  .notifier_contract.waits_for_last_settlement == false and
  .notifier_contract.makes_projection_trusted == false and
  .liveness_contract.unconditional_under_infinite_publication == false and
  .liveness_contract.stable_window_required == true and
  .liveness_contract.weak_fair_notifier_and_rq_owners_required == true and
  .liveness_contract.stable_membership_required == true and
  .liveness_contract.finite_active_rq_count_required == true and
  .liveness_contract.finite_b_max_required == true and
  .liveness_contract.logical_work_bound_only == true and
  .liveness_contract.wall_clock_deadline_claim == false and
  .liveness_contract.continuous_publication_may_remain_fail_closed == true and
  .liveness_contract.queue_depth_remains_bounded_during_continuous_publication == true and
  .current_execution_contract.picker_fence_alone_stops_current == false and
  .current_execution_contract.current_stop_request_is_separate_from_projection_recovery == true and
  .current_execution_contract.resched_curr_requires_rq_lock == true and
  .current_execution_contract.stop_request_eventual_under_stable_window == true and
  .current_execution_contract.instantaneous_linux_revoke_claim == false and
  .current_execution_contract.monitor_interrupt_and_completion_receipt_required_for_protection == true and
  .race_contract.enqueue_current_generation_handshake == true and
  .race_contract.dequeue_current_delayed_accounting_under_rq_lock == true and
  .race_contract.old_migration_contribution_removed_before_old_rq_unlock == true and
  .race_contract.simultaneous_source_destination_contribution == false and
  .race_contract.destination_handshake_after_placement_settles == true and
  .race_contract.final_membership_recheck_before_fresh == true and
  .race_contract.offline_clears_accepting_before_drain == true and
  .race_contract.offline_drain_bounded_by_b_max == true and
  .race_contract.flush_or_cancel_under_rq_lock == false and
  .race_contract.explicit_task_projection_dirty_notifier_recovery_callback_refs == true and
  .race_contract.rcu_grace_before_free == true and
  (.source_anchors | length) == 16 and
  (.future_absence_checks | length) == 6 and
  (.formal.liveness_properties | length) == 2 and
  (.formal.unsafe_faults | length) == 47 and
  .formal.unsafe_expected_counterexamples == 47 and
  .implementation_decision.r4_e1_evidence_plan_may_be_drafted_after_gate == true and
  .implementation_decision.disposable_linux_source_may_be_created == false and
  .implementation_decision.linux_behavior_patch_approved == false and
  .implementation_decision.r3_source_promoted == false and
  .implementation_decision.r4_source_approved == false and
  (.safety_flags | all(.[]; . == false))
' "$CONFIG" >/dev/null

expected_r3_sha=$(jq -r '.trigger.result_sha256' "$CONFIG")
actual_r3_sha=$(sha256sum "$R3_RESULT" | awk '{print $1}')
[ "$actual_r3_sha" = "$expected_r3_sha" ] \
	|| die "R3 result hash mismatch: expected=$expected_r3_sha actual=$actual_r3_sha"

jq -e '
  .status == "rejected_r3_bucket_measurement" and
  .architecture == "arm64" and
  .source_commit == "f20c62a2ad5aec4347dc7c8c4d81e3f7fa1f3da1" and
  .source_tree == "61541cb0c8aedef941e534c73effdea1f6b3d938" and
  .matrix.total_cells == 42 and
  .matrix.result_rows == 42 and
  .matrix.measured_pairs_per_cell == 10000 and
  .rejected_cell_count == 19 and
  .threshold_breach_count == 26 and
  .warnings.total == 0 and
  .qemu_exit_code == 0 and
  .kunit.suite_passed == true and
  .architecture_measurement_valid == true and
  .threshold_failure_is_valid_negative_evidence == true and
  .x86_64_measurement_may_start == false and
  .e5_plan_may_start == false
' "$R3_RESULT" >/dev/null

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

progress '15% checking current Linux anchors and future absences'
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
[ "$anchor_failures" = 0 ] || die "source anchor failures: $anchor_failures"

absence_ledger="$OUT_DIR/future-absence-checks.tsv"
printf 'id\tstatus\tpath\tpattern\n' > "$absence_ledger"
while IFS= read -r row; do
	id=$(printf '%s\n' "$row" | jq -r '.id')
	pattern=$(printf '%s\n' "$row" | jq -r '.pattern')
	if git -C "$LINUX_DIR" grep -Fq "$pattern" -- \
		include/linux/sched.h include/linux/sched_exec_lease.h \
		kernel/sched init/Kconfig; then
		status=unexpected-present
	else
		status=absent
	fi
	printf '%s\t%s\tlinux scoped scheduler paths\t%s\n' "$id" "$status" "$pattern" \
		>> "$absence_ledger"
done < <(jq -c '.future_absence_checks[]' "$CONFIG")

absence_count=$(jq '.future_absence_checks | length' "$CONFIG")
absence_failures=$(awk -F '\t' 'NR > 1 && $2 != "absent" {c++} END {print c+0}' "$absence_ledger")
[ "$absence_failures" = 0 ] || die "future absence failures: $absence_failures"

progress '25% checking safe safety and liveness model'
(
	cd "$MODEL_DIR"
	java -XX:+UseParallelGC -cp "$TLA_JAR" tlc2.TLC -deadlock \
		-metadir "$OUT_DIR/tlc-safe-states" \
		-config "$SAFE_CFG" "$MODEL"
) > "$OUT_DIR/tlc-safe.log" 2>&1
grep -q 'Model checking completed. No error has been found' "$OUT_DIR/tlc-safe.log" \
	|| die 'safe TLC model did not pass'
grep -q 'Checking 2 branches of temporal properties' "$OUT_DIR/tlc-safe.log" \
	|| die 'safe TLC liveness properties were not checked'

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
	name="P5AR4GenerationFencedCoalescedPullRecoveryUnsafe${fault}"
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
	--arg r3_result "$R3_RESULT" \
	--arg r3_result_sha256 "$actual_r3_sha" \
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
	  status: "passed_generation_fenced_coalesced_pull_recovery_architecture_only",
	  linux_commit: $linux_commit,
	  linux_tree: $linux_tree,
	  r3_result: $r3_result,
	  r3_result_sha256: $r3_result_sha256,
	  config: $config,
	  model_dir: $model_dir,
	  source_anchor_count: $source_anchor_count,
	  source_anchor_failures: $source_anchor_failures,
	  future_absence_check_count: $future_absence_check_count,
	  future_absence_check_failures: $future_absence_check_failures,
	  selected_successor: "generation_fenced_coalesced_pull_recovery",
	  r3_fanout_correctly_classified_as_availability_only: true,
	  authority_publication_critical_section_o1: true,
	  picker_mismatch_untrusted: true,
	  one_notifier_and_one_owner_per_rq: true,
	  newest_generation_coalesces: true,
	  stable_window_required: true,
	  notification_logical_bound: "at_most_2_times_active_rq_count",
	  recovery_logical_bound: "at_most_b_max_per_rq",
	  current_stop_request_separate: true,
	  safe_passed: true,
	  liveness_properties_checked: 2,
	  safe_states_generated: $safe_states_generated,
	  safe_distinct_states: $safe_distinct_states,
	  safe_depth: $safe_depth,
	  unsafe_expected_counterexamples: $unsafe_expected_counterexamples,
	  r4_e1_evidence_plan_may_be_drafted: true,
	  disposable_linux_source_may_be_created: false,
	  linux_behavior_patch_approved: false,
	  runtime_behavior_approved: false,
	  protection_claim: false,
	  bounded_wall_clock_latency_claim: false,
	  performance_claim: false,
	  cost_claim: false
	}' > "$OUT_DIR/result.json"

progress '100% passed; R4 architecture and liveness gate complete'
cat "$OUT_DIR/result.json"
