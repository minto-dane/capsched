#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
LINUX_DIR=${DOMAINLEASE_LINUX_DIR:-"$WORKSPACE_DIR/linux"}
CONFIG="$CAPSCHED_DIR/capsched-models/analysis/sched-exec-lease-p5a-r3-bucket-local-targeted-projection-v1.json"
MODEL_DIR="$CAPSCHED_DIR/capsched-models/formal/0131-p5a-r3-bucket-local-targeted-projection-model"
MODEL=P5AR3BucketLocalTargetedProjection.tla
SAFE_CFG=P5AR3BucketLocalTargetedProjectionSafe.cfg
TLA_JAR=${TLA_JAR:-"$WORKSPACE_DIR/build/tools/tla/tla2tools.jar"}
E4_RESULT="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r2-e4-arm64-lock-hold-measurement/20260714T-p5a-r2-e4-arm64-r4/result.json"
RUN_ID=${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
OUT_DIR="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r3-bucket-local-targeted-projection/$RUN_ID"

die()
{
	printf 'error: %s\n' "$*" >&2
	exit 1
}

for command_name in awk find git grep java jq sed sha256sum wc; do
	command -v "$command_name" >/dev/null 2>&1 \
		|| die "missing command: $command_name"
done

[ -f "$TLA_JAR" ] || die "missing TLA jar: $TLA_JAR"
[ -f "$E4_RESULT" ] || die "missing canonical E4 result: $E4_RESULT"
mkdir -p "$OUT_DIR/generated-unsafe-configs"
jq empty "$CONFIG"

jq -e '
  .status == "bucket_local_targeted_projection_architecture_gate_no_linux_patch" and
  (.trigger.e4_status == "rejected_full_locked_rebuild") and
  (.trigger.e4_valid_architecture_measurement == true) and
  (.trigger.full_locked_rebuild_rejected == true) and
  (.trigger.x86_64_not_launched_by_terminal_arm64_rejection == true) and
  (.alternatives.chunked_full_tree_rebuild == "rejected_as_immediate_successor") and
  (.alternatives.targeted_rq_mask_with_full_leaf_rebuild == "rejected") and
  (.alternatives.targeted_per_task_leaf_walk_in_mixed_tree == "rejected") and
  (.alternatives.bucket_local_candidate_c_projection == "selected_for_evidence_planning") and
  (.bucket_key.domain_identity_and_epoch == true) and
  (.bucket_key.sched_context_identity_and_budget_root == true) and
  (.bucket_key.execution_grant_generation_class == true) and
  (.bucket_key.memory_view_generation_projection == true) and
  (.bucket_key.cpu_placement_class == true) and
  (.bucket_key.outer_selector_configuration_generation == true) and
  (.bucket_key.raw_capability_storage == false) and
  (.bucket_key.cgroup_identity_is_authority == false) and
  (.decision.one_local_projection_generation_per_bucket == true) and
  (.decision.preallocated_per_cpu_projection == true) and
  (.decision.runnable_rq_membership_index == true) and
  (.decision.per_rq_contribution_refcount == true) and
  (.decision.targeted_active_rq_fanout == true) and
  (.decision.all_online_rq_fanout == false) and
  (.decision.one_bucket_projection_per_rq_lock_acquisition == true) and
  (.decision.leaf_rebuild_or_scan == false) and
  (.decision.single_outer_bucket_layer == true) and
  (.decision.finite_bucket_admission_bound_required_before_source == true) and
  (.decision.outer_candidate_c_preserved == true) and
  (.publication_contract.serialized_under_membership_lock == true) and
  (.publication_contract.frozen_state_before_generation == true) and
  (.publication_contract.generation_release_published == true) and
  (.publication_contract.active_rq_snapshot_under_same_lock == true) and
  (.publication_contract.each_generation_takes_fresh_active_rq_snapshot == true) and
  (.publication_contract.work_refs_acquired_before_unlock == true) and
  (.publication_contract.work_queued_after_membership_unlock == true) and
  (.publication_contract.publisher_takes_rq_lock_while_membership_locked == false) and
  (.publication_contract.generation_wrap_reuse == false) and
  (.publication_contract.generation_saturation_blocks == true) and
  (.membership_contract.lock_order == "rq_then_one_bucket_membership_lock") and
  (.membership_contract.two_bucket_membership_locks_held_together == false) and
  (.membership_contract.first_ref_sets_active_rq_bit == true) and
  (.membership_contract.last_ref_clears_active_rq_bit == true) and
  (.membership_contract.current_contribution_counted == true) and
  (.membership_contract.queued_contribution_counted == true) and
  (.membership_contract.delayed_contribution_counted == true) and
  (.membership_contract.enqueue_before_snapshot_is_in_snapshot == true) and
  (.membership_contract.enqueue_after_snapshot_observes_new_generation == true) and
  (.membership_contract.false_positive_fanout_allowed == true) and
  (.membership_contract.missed_affected_rq_allowed == false) and
  (.membership_contract.allocation_under_rq_or_membership_lock == false) and
  (.migration_contract.old_contribution_removed_before_old_rq_unlock == true) and
  (.migration_contract.neutral_migrating_interval == true) and
  (.migration_contract.destination_publish_after_cpu_affinity_cfs_bucket_activation_settled == true) and
  (.migration_contract.simultaneous_old_and_new_contribution == false) and
  (.migration_contract.destination_uses_current_generation_handshake == true) and
  (.worker_contract | all(.[]; . == true or . == false)) and
  (.worker_contract.owning_rq_lock_required == true) and
  (.worker_contract.one_projection_update == true) and
  (.worker_contract.leaf_or_hierarchy_scan == false) and
  (.worker_contract.all_bucket_loop == false) and
  (.worker_contract.allocation_or_sleep == false) and
  (.worker_contract.monitor_or_policy_call == false) and
  (.worker_contract.generation_rechecked_before_fresh == true) and
  (.worker_contract.raced_work_remains_stale_and_requeues == true) and
  (.worker_contract.partial_fresh_publication == false) and
  (.picker_contract.requires_local_fresh == true) and
  (.picker_contract.requires_local_generation_equals_acquire_bucket_generation == true) and
  (.picker_contract.requires_bucket_eligible == true) and
  (.picker_contract.requires_bucket_key_matches_selector_configuration == true) and
  (.picker_contract.final_task_local_recheck == true) and
  (.picker_contract.picker_leaf_scan == false) and
  (.picker_contract.picker_rebuild == false) and
  (.picker_contract.picker_policy_lookup == false) and
  (.picker_contract.picker_monitor_call == false) and
  (.picker_contract.fallback_bucket_minted_in_picker == false) and
  (.lifetime_contract | all(.[]; . == true)) and
  (.event_split.ordinary_budget_decrement_above_threshold_publishes == false) and
  (.event_split.eligibility_boundary_transition_publishes == true) and
  (.source_boundary.linux_files_may_change_at_this_gate | length == 0) and
  (.source_boundary.include_linux_sched_h_requires_fresh_layout_gate == true) and
  (.source_boundary.default_off_test_boundary_required == true) and
  (.source_boundary.public_or_trace_abi == false) and
  (.source_boundary.exported_symbol == false) and
  (.source_boundary.monitor_call == false) and
  (.formal.unsafe_faults | length == 34) and
  (.formal.unsafe_expected_counterexamples == 34) and
  (.implementation_decision.r3_e1_evidence_plan_may_be_drafted_after_gate == true) and
  (.implementation_decision.disposable_linux_source_may_be_created == false) and
  (.implementation_decision.linux_behavior_patch_approved == false) and
  (.implementation_decision.rejected_e2_e3_e4_line_promoted == false) and
  (.implementation_decision.full_locked_rebuild_approved == false) and
  (.implementation_decision.chunked_full_rebuild_approved == false) and
  (.safety_flags | all(.[]; . == false))
' "$CONFIG" >/dev/null

expected_e4_sha=$(jq -r '.trigger.e4_result_sha256' "$CONFIG")
actual_e4_sha=$(sha256sum "$E4_RESULT" | awk '{print $1}')
[ "$actual_e4_sha" = "$expected_e4_sha" ] \
	|| die "E4 result hash mismatch: expected=$expected_e4_sha actual=$actual_e4_sha"

jq -e '
  .status == "rejected_full_locked_rebuild" and
  .architecture == "arm64" and
  .source_commit == "f6ad4e454778c52bcdaaecf684c148a3a8dae857" and
  .source_tree == "265e6357627490e51084979382ef34b2cfcc0cb8" and
  .matrix.cells == 35 and
  .matrix.result_rows == 35 and
  .matrix.measured_pairs_per_cell == 10000 and
  .matrix.race_ppm == 0 and
  .gate.threshold_breach_count == 36 and
  .warnings.total == 0 and
  .qemu_exit_code == 0 and
  .kunit.suite_passed == true and
  .architecture_measurement_valid == true and
  .threshold_failure_is_valid_negative_evidence == true and
  .x86_64_measurement_may_be_launched == false and
  .full_locked_rebuild_approved == false
' "$E4_RESULT" >/dev/null

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
[ "$anchor_count" = 20 ] || die "unexpected source anchor count: $anchor_count"
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
[ "$absence_count" = 6 ] || die "unexpected absence check count: $absence_count"
[ "$absence_failures" = 0 ] || die "future absence check failures: $absence_failures"

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
	name="P5AR3BucketLocalTargetedProjectionUnsafe${fault}"
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
fault_count=$(jq '.formal.unsafe_faults | length' "$CONFIG")
[ "$fault_count" = 34 ] || die "unsafe fault count mismatch: $fault_count"
[ "$unsafe_expected" = 34 ] \
	|| die "unsafe counterexample count mismatch: $unsafe_expected"

jq -n \
	--arg run_id "$RUN_ID" \
	--arg linux_commit "$actual_commit" \
	--arg linux_tree "$actual_tree" \
	--arg e4_result "$E4_RESULT" \
	--arg e4_result_sha256 "$actual_e4_sha" \
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
	  status: "passed_bucket_local_targeted_projection_architecture_only",
	  linux_commit: $linux_commit,
	  linux_tree: $linux_tree,
	  e4_result: $e4_result,
	  e4_result_sha256: $e4_result_sha256,
	  config: $config,
	  model_dir: $model_dir,
	  tla_jar: $tla_jar,
	  source_anchor_count: $source_anchor_count,
	  source_anchor_failures: $source_anchor_failures,
	  future_absence_check_count: $future_absence_check_count,
	  future_absence_check_failures: $future_absence_check_failures,
	  selected_successor: "bucket_local_targeted_projection",
	  active_rq_membership_index_required: true,
	  insertion_handshake_required: true,
	  one_bucket_per_rq_lock_required: true,
	  leaf_scan_or_rebuild_allowed: false,
	  safe_passed: true,
	  safe_states_generated: $safe_states_generated,
	  safe_distinct_states: $safe_distinct_states,
	  safe_depth: $safe_depth,
	  unsafe_expected_counterexamples: $unsafe_expected_counterexamples,
	  r3_e1_evidence_plan_may_be_drafted: true,
	  disposable_linux_source_may_be_created: false,
	  linux_behavior_patch_approved: false,
	  runtime_behavior_approved: false,
	  protection_claim: false,
	  performance_claim: false,
	  cost_claim: false
	}' > "$OUT_DIR/result.json"

cat "$OUT_DIR/result.json"
