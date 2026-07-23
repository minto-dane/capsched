#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
LINUX_DIR=${DOMAINLEASE_LINUX_DIR:-"$WORKSPACE_DIR/linux"}
CANONICAL_CONFIG="$CAPSCHED_DIR/capsched-models/analysis/sched-exec-lease-p5a-r6-sealed-masked-domain-forest-v1.json"
MODEL_DIR="$CAPSCHED_DIR/capsched-models/formal/0142-p5a-r6-sealed-masked-domain-forest-model"
MODEL=P5AR6SealedMaskedDomainForest.tla
SAFE_CFG=P5AR6SealedMaskedDomainForestSafe.cfg
TLA_JAR=${TLA_JAR:-"$WORKSPACE_DIR/build/tools/tla/tla2tools.jar"}
RUN_ID=${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
PROGRESS_FILE=${PROGRESS_FILE:-}
TEST_MODE=${TEST_MODE:-0}
CONTRACT_ONLY=${CONTRACT_ONLY:-0}
CONFIG_OVERRIDE=${CONFIG_OVERRIDE:-}

if [ "$TEST_MODE" = 1 ]; then
	[ "$CONTRACT_ONLY" = 1 ] ||
		{ printf 'error: TEST_MODE requires CONTRACT_ONLY=1\n' >&2; exit 1; }
	[ -n "$CONFIG_OVERRIDE" ] ||
		{ printf 'error: TEST_MODE requires CONFIG_OVERRIDE\n' >&2; exit 1; }
	CONFIG=$CONFIG_OVERRIDE
else
	[ "$CONTRACT_ONLY" = 0 ] ||
		{ printf 'error: CONTRACT_ONLY is restricted to TEST_MODE\n' >&2; exit 1; }
	[ -z "$CONFIG_OVERRIDE" ] ||
		{ printf 'error: CONFIG_OVERRIDE is restricted to TEST_MODE\n' >&2; exit 1; }
	CONFIG=$CANONICAL_CONFIG
fi

R5_RESULT="$WORKSPACE_DIR/$(jq -r '.trigger.result' "$CONFIG")"
OUT_ROOT="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r6-sealed-masked-domain-forest"
OUT_DIR="$OUT_ROOT/$RUN_ID"

die()
{
	printf 'error: %s\n' "$*" >&2
	exit 1
}

progress()
{
	printf '[progress] %s\n' "$*"
	if [ -n "$PROGRESS_FILE" ]; then
		mkdir -p "$(dirname "$PROGRESS_FILE")"
		printf '%s\n' "$*" > "$PROGRESS_FILE"
	fi
}

file_sha()
{
	sha256sum "$1" | awk '{print $1}'
}

case "$RUN_ID" in
	[A-Za-z0-9]*) ;;
	*) die 'RUN_ID must begin with an alphanumeric character' ;;
esac
case "$RUN_ID" in
	*[!A-Za-z0-9._-]*|.|..) die 'RUN_ID contains an unsafe component' ;;
esac
case "$TEST_MODE:$CONTRACT_ONLY" in
	0:0|1:1) ;;
	*) die 'invalid runner mode' ;;
esac
for command in awk chmod git grep java jq mkdir sed sha256sum tail; do
	command -v "$command" >/dev/null 2>&1 || die "missing command: $command"
done
[ -f "$CONFIG" ] || die "missing config: $CONFIG"

progress '5% validating exact R6 architecture contract'
jq empty "$CONFIG"
jq -e '
  .schema_version == 1 and
  .status == "sealed_masked_domain_forest_architecture_gate_no_linux_patch" and
  .trigger.result_sha256 == "6fee1f3f3d68cbc816321b2759de71b1a35e64f8d207425fcfe5d0d86b7fe0a5" and
  .trigger.r5_rejected_before_layout == true and
  .trigger.r5_rejected_before_source == true and
  .trigger.immutable_receipt_retained_as_ingredient == true and
  .trigger.immutable_selector_view_retained == false and
  .candidate_comparison.flat_generation_augmentation.selected == false and
  .candidate_comparison.cgroup_task_group_authority.selected == false and
  .candidate_comparison.sealed_masked_domain_forest.selected == true and
  .candidate_comparison.exactly_one_selected == true and
  .authority_plane.b_max == 64 and
  .authority_plane.allowed_mask_bits == 64 and
  .authority_plane.generation_non_reused == true and
  .authority_plane.generation_saturation_blocks == true and
  .authority_plane.slot_map_digest_frozen == true and
  .authority_plane.receipt_sealed_before_use == true and
  .authority_plane.publication_constant_work == true and
  .authority_plane.publication_walks_rqs_tasks_or_queues == false and
  .authority_plane.publication_allocates_queues_waits_flushes_cancels_or_repairs_selector == false and
  .authority_plane.cgroup_task_group_weight_vruntime_deadline_or_topology_is_authority == false and
  .selector_plane.one_dynamic_eevdf_queue_per_active_slot_per_rq == true and
  .selector_plane.fixed_top_leaves == 64 and
  .selector_plane.fixed_top_depth == 6 and
  .selector_plane.top_subtree_slot_masks_static == true and
  .selector_plane.top_scheduling_summaries_mutable_under_rq_lock == true and
  .selector_plane.slot_queue_state_mutable_under_rq_lock == true and
  .selector_plane.changed_slot_updates_one_leaf_and_at_most_six_ancestors == true and
  .selector_plane.picker_intersects_static_subtree_mask_with_sealed_allowed_mask == true and
  .selector_plane.masked_query_fixed_bounded == true and
  .selector_plane.masked_query_worst_case_nodes == 127 and
  .selector_plane.masked_query_logarithmic_claimed == false and
  .selector_plane.masked_query_independent_of_nr_running == true and
  .selector_plane.picker_requires_live_summary_eligibility == true and
  .selector_plane.slot_local_picker_uses_dynamic_eevdf == true and
  .selector_plane.final_task_local_authority_check == true and
  .selector_plane.flat_task_tree_variable_fallback == false and
  .selector_plane.immutable_copy_of_dynamic_selector_state == false and
  .task_lifetime.storage_allocated_before_admission == true and
  .task_lifetime.allocation_failure_state == "Blocked" and
  .task_lifetime.one_slot_and_rq_contribution_per_task == true and
  .task_lifetime.enqueue_revalidates_generation_digest_and_slot == true and
  .task_lifetime.migration_remove_neutral_add == true and
  .task_lifetime.simultaneous_source_destination_contribution == false and
  .task_lifetime.slot_reuse_after_zero_contributors_refs_retirement_and_rcu == true and
  .task_lifetime.offline_stops_admission_before_visibility_removal == true and
  .task_lifetime.sleepable_teardown_drains_work_refs_and_rcu == true and
  .task_lifetime.current_stop_distributor_separate == true and
  .fairness_boundary.two_level_domain_then_task_fairness_explicit == true and
  .fairness_boundary.flat_cfs_equivalence_claimed == false and
  .fairness_boundary.monitor_weight_receipt_required == true and
  .fairness_boundary.lag_deadline_weight_sleeper_throttle_idle_capacity_proof_deferred == true and
  .fairness_boundary.performance_claim == false and
  (.source_anchors | length) == 16 and
  (.future_absence_checks | length) == 6 and
  (.formal.unsafe_safety_faults | length) == 13 and
  (.formal.unsafe_liveness_faults | length) == 2 and
  .formal.safe_liveness_properties == 2 and
  .next_gate.r6_e1_source_free_plan_may_start_after_validation == true and
  .next_gate.r6_layout_or_source_may_start == false and
  .next_gate.primary_linux_or_patch_queue_change == false and
  .claims.r6_architecture_selected == true and
  (.claims | [
    .r6_source_approved,.real_scheduler_attachment,.runtime_behavior_approved,
    .flat_cfs_fairness_equivalent,.bare_metal_validated,.performance_claim,
    .cost_claim,.monitor_verified,.production_protection,.deployment_ready,
    .multi_node_ready,.multi_cluster_ready,.datacenter_ready
  ] | all(. == false))
' "$CONFIG" >/dev/null || die 'R6 architecture contract changed'

if [ "$CONTRACT_ONLY" = 1 ]; then
	progress '100% exact R6 contract accepted in test mode'
	exit 0
fi

[ ! -e "$OUT_DIR" ] || die "output already exists: $OUT_DIR"
for file in "$TLA_JAR" "$R5_RESULT" "$MODEL_DIR/$MODEL" \
	"$MODEL_DIR/$SAFE_CFG"; do
	[ -f "$file" ] || die "missing canonical input: $file"
	[ ! -L "$file" ] || die "canonical input is a symlink: $file"
done
mkdir -p "$OUT_DIR/generated-unsafe-configs"
chmod 0700 "$OUT_DIR"

progress '14% revalidating exact R5 rejection trigger'
[ "$(file_sha "$R5_RESULT")" = "$(jq -r '.trigger.result_sha256' "$CONFIG")" ] ||
	die 'R5 E1 rejection result hash changed'
jq -e '
  .status == "passed_r5_e1_selector_coherence_rejection_before_source" and
  .source_anchor_count == 18 and .source_anchor_failures == 0 and
  .ordinary_eevdf_mutation_with_stable_authority_generation == true and
  .immutable_selector_view_becomes_stale == true and
  .safe_fail_closed_passed == true and
  .stale_trust_safety_counterexample == true and
  .allowed_progress_liveness_counterexample == true and
  .r5_e1_feasible == false and
  .r5_rejected_before_layout == true and .r5_rejected_before_source == true and
  .successor_analysis_may_start == true and .successor_selected == false and
  .r5_source_approved == false and .r6_source_approved == false
' "$R5_RESULT" >/dev/null || die 'R5 E1 rejection semantics changed'

progress '24% checking hierarchy mechanisms and future-source absence'
expected_commit=$(jq -r '.source_basis.primary_linux_commit' "$CONFIG")
expected_tree=$(jq -r '.source_basis.primary_linux_tree' "$CONFIG")
actual_commit=$(git -C "$LINUX_DIR" rev-parse --verify HEAD)
actual_tree=$(git -C "$LINUX_DIR" rev-parse --verify 'HEAD^{tree}')
[ "$actual_commit" = "$expected_commit" ] ||
	die "Linux commit mismatch: expected=$expected_commit actual=$actual_commit"
[ "$actual_tree" = "$expected_tree" ] ||
	die "Linux tree mismatch: expected=$expected_tree actual=$actual_tree"
[ -z "$(git -C "$LINUX_DIR" status --porcelain --untracked-files=no)" ] ||
	die 'Linux tracked working tree is dirty'

printf 'id\tstatus\tpath\tpattern\n' > "$OUT_DIR/source-anchors.tsv"
while IFS= read -r row; do
	anchor_id=$(printf '%s\n' "$row" | jq -r '.id')
	anchor_path=$(printf '%s\n' "$row" | jq -r '.path')
	anchor_pattern=$(printf '%s\n' "$row" | jq -r '.pattern')
	if grep -Fq "$anchor_pattern" "$WORKSPACE_DIR/$anchor_path"; then
		anchor_status=ok
	else
		anchor_status=missing
	fi
	printf '%s\t%s\t%s\t%s\n' \
		"$anchor_id" "$anchor_status" "$anchor_path" "$anchor_pattern" \
		>> "$OUT_DIR/source-anchors.tsv"
done < <(jq -c '.source_anchors[]' "$CONFIG")
anchor_count=$(jq '.source_anchors | length' "$CONFIG")
anchor_failures=$(awk -F '\t' \
	'NR > 1 && $2 != "ok" {n++} END {print n+0}' \
	"$OUT_DIR/source-anchors.tsv")
[ "$anchor_failures" = 0 ] || die "source anchor failures: $anchor_failures"

printf 'id\tstatus\tpattern\n' > "$OUT_DIR/future-absence.tsv"
while IFS= read -r row; do
	absence_id=$(printf '%s\n' "$row" | jq -r '.id')
	absence_pattern=$(printf '%s\n' "$row" | jq -r '.pattern')
	if git -C "$LINUX_DIR" grep -Fq "$absence_pattern" -- \
		include/linux/sched.h include/linux/sched_exec_lease.h \
		kernel/sched init/Kconfig; then
		absence_status=unexpected-present
	else
		absence_status=absent
	fi
	printf '%s\t%s\t%s\n' \
		"$absence_id" "$absence_status" "$absence_pattern" \
		>> "$OUT_DIR/future-absence.tsv"
done < <(jq -c '.future_absence_checks[]' "$CONFIG")
absence_count=$(jq '.future_absence_checks | length' "$CONFIG")
absence_failures=$(awk -F '\t' \
	'NR > 1 && $2 != "absent" {n++} END {print n+0}' \
	"$OUT_DIR/future-absence.tsv")
[ "$absence_failures" = 0 ] ||
	die "future-source absence failures: $absence_failures"

progress '36% checking separated authority/selector safety and liveness'
(
	cd "$MODEL_DIR"
	java -XX:+UseParallelGC -cp "$TLA_JAR" tlc2.TLC \
		-metadir "$OUT_DIR/tlc-safe-states" -config "$SAFE_CFG" "$MODEL"
) > "$OUT_DIR/tlc-safe.log" 2>&1
grep -q 'Model checking completed. No error has been found' \
	"$OUT_DIR/tlc-safe.log" || die 'safe R6 model did not pass'
grep -q 'Checking 2 branches of temporal properties' "$OUT_DIR/tlc-safe.log" ||
	die 'safe R6 liveness properties were not checked'
safe_states=$(sed -n 's/^\([0-9][0-9]*\) states generated.*/\1/p' \
	"$OUT_DIR/tlc-safe.log" | tail -n 1)
safe_distinct=$(sed -n \
	's/^[0-9][0-9]* states generated, \([0-9][0-9]*\) distinct states found.*/\1/p' \
	"$OUT_DIR/tlc-safe.log" | tail -n 1)
safe_depth=$(sed -n \
	's/^The depth of the complete state graph search is \([0-9][0-9]*\).*/\1/p' \
	"$OUT_DIR/tlc-safe.log" | tail -n 1)
[ "${safe_states:-0}" = 5 ] || die 'unexpected safe state count'
[ "${safe_distinct:-0}" = 5 ] || die 'unexpected safe distinct-state count'
[ "${safe_depth:-0}" = 5 ] || die 'unexpected safe search depth'

safety_fault_count=$(jq '.formal.unsafe_safety_faults | length' "$CONFIG")
safety_expected=0
safety_failures=0
while IFS= read -r fault; do
	cfg="$OUT_DIR/generated-unsafe-configs/safety-$fault.cfg"
	log="$OUT_DIR/tlc-safety-$fault.log"
	printf '%s\n' \
		'SPECIFICATION Spec' \
		"CONSTANT Fault = \"$fault\"" \
		'CHECK_DEADLOCK FALSE' \
		'INVARIANT TypeOK' \
		'INVARIANT ArchitectureSafety' > "$cfg"
	if (
		cd "$MODEL_DIR"
		java -XX:+UseParallelGC -cp "$TLA_JAR" tlc2.TLC \
			-metadir "$OUT_DIR/states-safety-$fault" \
			-config "$cfg" "$MODEL"
	) > "$log" 2>&1; then
		printf 'unsafe safety fault unexpectedly passed: %s\n' "$fault" >&2
		safety_failures=$((safety_failures + 1))
	elif grep -Eq 'Invariant (TypeOK|ArchitectureSafety) is violated' "$log"; then
		safety_expected=$((safety_expected + 1))
	else
		printf 'unsafe safety fault failed unexpectedly: %s\n' "$fault" >&2
		tail -n 40 "$log" >&2
		safety_failures=$((safety_failures + 1))
	fi
done < <(jq -r '.formal.unsafe_safety_faults[]' "$CONFIG")
[ "$safety_failures" = 0 ] || die "unsafe safety TLC failures: $safety_failures"
[ "$safety_expected" = "$safety_fault_count" ] ||
	die "unsafe safety mismatch: expected=$safety_fault_count actual=$safety_expected"
progress '76% all architecture-safety counterexamples reproduced'

liveness_fault_count=$(jq '.formal.unsafe_liveness_faults | length' "$CONFIG")
liveness_expected=0
liveness_failures=0
while IFS= read -r fault; do
	cfg="$OUT_DIR/generated-unsafe-configs/liveness-$fault.cfg"
	log="$OUT_DIR/tlc-liveness-$fault.log"
	printf '%s\n' \
		'SPECIFICATION Spec' \
		"CONSTANT Fault = \"$fault\"" \
		'CHECK_DEADLOCK FALSE' \
		'INVARIANT TypeOK' \
		'INVARIANT ArchitectureSafety' \
		'PROPERTY AllowedProgress' \
		'PROPERTY RevokedCurrentProgress' > "$cfg"
	if (
		cd "$MODEL_DIR"
		java -XX:+UseParallelGC -cp "$TLA_JAR" tlc2.TLC \
			-metadir "$OUT_DIR/states-liveness-$fault" \
			-config "$cfg" "$MODEL"
	) > "$log" 2>&1; then
		printf 'unsafe liveness fault unexpectedly passed: %s\n' "$fault" >&2
		liveness_failures=$((liveness_failures + 1))
	elif grep -q 'Temporal properties were violated' "$log"; then
		liveness_expected=$((liveness_expected + 1))
	else
		printf 'unsafe liveness fault failed unexpectedly: %s\n' "$fault" >&2
		tail -n 40 "$log" >&2
		liveness_failures=$((liveness_failures + 1))
	fi
done < <(jq -r '.formal.unsafe_liveness_faults[]' "$CONFIG")
[ "$liveness_failures" = 0 ] ||
	die "unsafe liveness TLC failures: $liveness_failures"
[ "$liveness_expected" = "$liveness_fault_count" ] ||
	die "unsafe liveness mismatch: expected=$liveness_fault_count actual=$liveness_expected"

progress '96% sealing source-free R6 architecture decision'
jq -S -n \
	--arg run_id "$RUN_ID" \
	--arg linux_commit "$actual_commit" --arg linux_tree "$actual_tree" \
	--arg r5_result_sha "$(file_sha "$R5_RESULT")" \
	--argjson anchors "$anchor_count" --argjson absences "$absence_count" \
	--argjson safe_states "$safe_states" \
	--argjson safe_distinct "$safe_distinct" \
	--argjson safe_depth "$safe_depth" \
	--argjson safety_faults "$safety_expected" \
	--argjson liveness_faults "$liveness_expected" '
{
  schema_version:1,
  run_id:$run_id,
  status:"passed_sealed_masked_domain_forest_architecture_only",
  linux_commit:$linux_commit,
  linux_tree:$linux_tree,
  r5_rejection_result_sha256:$r5_result_sha,
  source_anchor_count:$anchors,
  source_anchor_failures:0,
  future_absence_check_count:$absences,
  future_absence_check_failures:0,
  selected_successor:"sealed_masked_domain_forest",
  b_max:64,
  allowed_mask_bits:64,
  fixed_top_depth:6,
  masked_query_worst_case_nodes:127,
  masked_query_logarithmic_claimed:false,
  immutable_authority_plane:true,
  dynamic_selector_plane:true,
  publication_constant_work:true,
  cgroup_is_authority:false,
  flat_tree_variable_fallback:false,
  two_level_fairness_explicit:true,
  flat_cfs_equivalence_claimed:false,
  safe_passed:true,
  liveness_properties_checked:2,
  safe_states_generated:$safe_states,
  safe_distinct_states:$safe_distinct,
  safe_depth:$safe_depth,
  unsafe_safety_counterexamples:$safety_faults,
  unsafe_liveness_counterexamples:$liveness_faults,
  r6_e1_source_free_plan_may_be_drafted:true,
  r6_layout_or_source_may_start:false,
  real_scheduler_attachment:false,
  runtime_behavior_approved:false,
  bare_metal_validated:false,
  performance_claim:false,
  cost_claim:false,
  monitor_verified:false,
  production_protection:false,
  deployment_ready:false,
  multi_node_ready:false,
  multi_cluster_ready:false,
  datacenter_ready:false
}' > "$OUT_DIR/result.json"
file_sha "$OUT_DIR/result.json" > "$OUT_DIR/result.sha256"
chmod -R a-w "$OUT_DIR"
progress '100% R6 source-free architecture selected; E1 planning only'
printf 'result=%s\nsha256=%s\n' \
	"$OUT_DIR/result.json" "$(cat "$OUT_DIR/result.sha256")"
