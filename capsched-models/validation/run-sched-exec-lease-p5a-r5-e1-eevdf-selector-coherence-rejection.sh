#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
LINUX_DIR=${DOMAINLEASE_LINUX_DIR:-"$WORKSPACE_DIR/linux"}
CANONICAL_CONFIG="$CAPSCHED_DIR/capsched-models/analysis/sched-exec-lease-p5a-r5-e1-eevdf-selector-coherence-rejection-v1.json"
MODEL_DIR="$CAPSCHED_DIR/capsched-models/formal/0141-p5a-r5-e1-eevdf-selector-coherence-model"
MODEL=P5AR5E1EEVDFSelectorCoherence.tla
SAFE_CFG=P5AR5E1EEVDFSelectorCoherenceSafe.cfg
UNSAFE_CFG=P5AR5E1EEVDFSelectorCoherenceUnsafeTrustStale.cfg
AVAILABILITY_CFG=P5AR5E1EEVDFSelectorCoherenceAvailability.cfg
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

R5_RESULT="$WORKSPACE_DIR/$(jq -r '.prerequisite.result' "$CONFIG")"
OUT_ROOT="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r5-e1-eevdf-selector-coherence-rejection"
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

progress '5% validating exact R5 E1 rejection contract'
jq empty "$CONFIG"
jq -e '
  .schema_version == 1 and
  .status == "rejected_r5_generation_sealed_immutable_selector_before_source" and
  .prerequisite.result_sha256 == "ceb595322a92886c2296cbcafd3c2fd08b220753a250ac2c4a7222a54a64bf9b" and
  .prerequisite.r5_source_free_only == true and
  .prerequisite.eevdf_representation_deferred_to_e1 == true and
  .prerequisite.r5_layout_or_source_approved == false and
  .source_basis.primary_linux_commit == "5e1ca3037e34823d1ba0cdd1dc04161fac170280" and
  .source_basis.primary_linux_tree == "54f685aad94f28f0027cbba18cf5e29aadce234a" and
  .eevdf_contract.tree == "cfs_rq.tasks_timeline" and
  .eevdf_contract.tree_order == "deadline" and
  .eevdf_contract.subtree_augmentation == "sched_entity.min_vruntime" and
  (.eevdf_contract.eligibility_aggregates | length) == 4 and
  (.eevdf_contract.live_entity_fields | length) == 7 and
  .eevdf_contract.pick_complexity_depends_on_live_augmentation == true and
  .eevdf_contract.ordinary_update_curr_changes_selector_state == true and
  .eevdf_contract.enqueue_dequeue_change_selector_state == true and
  .eevdf_contract.current_tree_transitions_change_selector_state == true and
  .eevdf_contract.authority_stability_implies_selector_stability == false and
  .r5_contradiction.immutable_selector_view == true and
  .r5_contradiction.ordinary_dynamic_eevdf_mutation == true and
  .r5_contradiction.variable_picker_scan_allowed == false and
  .r5_contradiction.mutable_post_install_selector_maintenance_allowed == false and
  .r5_contradiction.stale_view_trusted == false and
  .r5_contradiction.safe_result_after_dynamic_mutation == "Blocked" and
  .r5_contradiction.allowed_runnable_eventually_selected == false and
  .r5_contradiction.stable_authority_window_sufficient_for_availability == false and
  .r5_contradiction.r5_e1_feasible == false and
  .experimental_negative_evidence.final_pickable_predicate_part_of_min_vruntime_augmentation == false and
  .experimental_negative_evidence.fallback_function == "sched_exec_cfs_pickable_scan" and
  .experimental_negative_evidence.fallback_walks_complete_tasks_timeline == true and
  .experimental_negative_evidence.fallback_complexity == "O(n)" and
  .experimental_negative_evidence.fallback_accepted == false and
  (.source_anchors | length) == 18 and
  .formal.safe_fail_closed_expected == true and
  .formal.unsafe_stale_trust_counterexample_expected == true and
  .formal.safe_availability_counterexample_expected == true and
  .decision.r5_rejected_before_layout == true and
  .decision.r5_rejected_before_source == true and
  .decision.r5_repair_authorized == false and
  .decision.successor_selected == false and
  .decision.successor_analysis_may_start == true and
  (.claims | [
    .r5_source_approved,.r6_source_approved,.real_scheduler_attachment,
    .runtime_behavior_approved,.bare_metal_validated,.performance_claim,
    .cost_claim,.monitor_verified,.production_protection,.deployment_ready,
    .multi_node_ready,.multi_cluster_ready,.datacenter_ready
  ] | all(. == false))
' "$CONFIG" >/dev/null || die 'R5 E1 rejection contract changed'

if [ "$CONTRACT_ONLY" = 1 ]; then
	progress '100% exact rejection contract accepted in test mode'
	exit 0
fi

[ ! -e "$OUT_DIR" ] || die "output already exists: $OUT_DIR"
for file in "$TLA_JAR" "$R5_RESULT" \
	"$MODEL_DIR/$MODEL" "$MODEL_DIR/$SAFE_CFG" \
	"$MODEL_DIR/$UNSAFE_CFG" "$MODEL_DIR/$AVAILABILITY_CFG"; do
	[ -f "$file" ] || die "missing canonical input: $file"
	[ ! -L "$file" ] || die "canonical input is a symlink: $file"
done
mkdir -p "$OUT_DIR"
chmod 0700 "$OUT_DIR"

progress '15% revalidating the source-free R5 prerequisite'
[ "$(file_sha "$R5_RESULT")" = "$(jq -r '.prerequisite.result_sha256' "$CONFIG")" ] ||
	die 'R5 architecture result hash changed'
jq -e '
  .status == "passed_generation_sealed_immutable_projection_architecture_only" and
  .selected_successor == "generation_sealed_immutable_projection_install" and
  .immutable_view_built_outside_rq_lock == true and
  .constant_work_rq_lock_install == true and
  .exact_picker_fence == true and
  .safe_passed == true and .liveness_properties_checked == 2 and
  .unsafe_expected_counterexamples == 49 and
  .r5_e1_source_free_plan_may_be_drafted == true and
  .r5_layout_or_source_may_start == false and
  .real_scheduler_attachment == false and
  .runtime_behavior_approved == false
' "$R5_RESULT" >/dev/null || die 'R5 architecture prerequisite semantics changed'

progress '28% binding current EEVDF source identity and dynamic-state anchors'
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

progress '45% proving fail-closed safety after ordinary selector mutation'
(
	cd "$MODEL_DIR"
	java -XX:+UseParallelGC -cp "$TLA_JAR" tlc2.TLC \
		-metadir "$OUT_DIR/tlc-safe-states" -config "$SAFE_CFG" "$MODEL"
) > "$OUT_DIR/tlc-safe.log" 2>&1
grep -q 'Model checking completed. No error has been found' \
	"$OUT_DIR/tlc-safe.log" || die 'safe fail-closed TLC model did not pass'
safe_states=$(sed -n 's/^\([0-9][0-9]*\) states generated.*/\1/p' \
	"$OUT_DIR/tlc-safe.log" | tail -n 1)
safe_distinct=$(sed -n \
	's/^[0-9][0-9]* states generated, \([0-9][0-9]*\) distinct states found.*/\1/p' \
	"$OUT_DIR/tlc-safe.log" | tail -n 1)
safe_depth=$(sed -n \
	's/^The depth of the complete state graph search is \([0-9][0-9]*\).*/\1/p' \
	"$OUT_DIR/tlc-safe.log" | tail -n 1)
[ "${safe_states:-0}" = 3 ] || die 'unexpected safe state count'
[ "${safe_distinct:-0}" = 3 ] || die 'unexpected safe distinct-state count'
[ "${safe_depth:-0}" = 3 ] || die 'unexpected safe search depth'

progress '65% reproducing stale-trust safety counterexample'
if (
	cd "$MODEL_DIR"
	java -XX:+UseParallelGC -cp "$TLA_JAR" tlc2.TLC \
		-metadir "$OUT_DIR/tlc-unsafe-states" -config "$UNSAFE_CFG" "$MODEL"
) > "$OUT_DIR/tlc-unsafe.log" 2>&1; then
	die 'stale-trust configuration unexpectedly passed'
fi
grep -q 'Invariant Safety is violated' "$OUT_DIR/tlc-unsafe.log" ||
	die 'stale-trust failure was not the expected safety counterexample'

progress '82% reproducing allowed-runnable availability counterexample'
if (
	cd "$MODEL_DIR"
	java -XX:+UseParallelGC -cp "$TLA_JAR" tlc2.TLC \
		-metadir "$OUT_DIR/tlc-availability-states" \
		-config "$AVAILABILITY_CFG" "$MODEL"
) > "$OUT_DIR/tlc-availability.log" 2>&1; then
	die 'safe availability configuration unexpectedly passed'
fi
grep -q 'Temporal properties were violated' "$OUT_DIR/tlc-availability.log" ||
	die 'safe availability failure was not the expected temporal counterexample'
grep -q 'State 4: Stuttering' "$OUT_DIR/tlc-availability.log" ||
	die 'availability counterexample did not reach the expected blocked stutter'

progress '96% sealing the R5 E1 valid-negative rejection'
jq -S -n \
	--arg run_id "$RUN_ID" \
	--arg linux_commit "$actual_commit" --arg linux_tree "$actual_tree" \
	--arg r5_result_sha "$(file_sha "$R5_RESULT")" \
	--argjson anchors "$anchor_count" \
	--argjson anchor_failures "$anchor_failures" \
	--argjson safe_states "$safe_states" \
	--argjson safe_distinct "$safe_distinct" \
	--argjson safe_depth "$safe_depth" '
{
  schema_version:1,
  run_id:$run_id,
  status:"passed_r5_e1_selector_coherence_rejection_before_source",
  linux_commit:$linux_commit,
  linux_tree:$linux_tree,
  r5_architecture_result_sha256:$r5_result_sha,
  source_anchor_count:$anchors,
  source_anchor_failures:$anchor_failures,
  ordinary_eevdf_mutation_with_stable_authority_generation:true,
  immutable_selector_view_becomes_stale:true,
  safe_fail_closed_passed:true,
  safe_states_generated:$safe_states,
  safe_distinct_states:$safe_distinct,
  safe_depth:$safe_depth,
  stale_trust_safety_counterexample:true,
  allowed_progress_liveness_counterexample:true,
  variable_picker_scan_accepted:false,
  mutable_post_install_selector_maintenance_accepted:false,
  r5_e1_feasible:false,
  r5_rejected_before_layout:true,
  r5_rejected_before_source:true,
  successor_analysis_may_start:true,
  successor_selected:false,
  r5_source_approved:false,
  r6_source_approved:false,
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
progress '100% R5 rejected at E1; successor analysis only'
printf 'result=%s\nsha256=%s\n' \
	"$OUT_DIR/result.json" "$(cat "$OUT_DIR/result.sha256")"
