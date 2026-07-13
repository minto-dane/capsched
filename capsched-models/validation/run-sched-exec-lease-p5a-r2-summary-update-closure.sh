#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
LINUX_DIR=${DOMAINLEASE_LINUX_DIR:-"$WORKSPACE_DIR/linux"}
CONFIG="$CAPSCHED_DIR/capsched-models/analysis/sched-exec-lease-p5a-r2-summary-update-closure-map-v1.json"
MODEL_DIR="$CAPSCHED_DIR/capsched-models/formal/0122-p5a-r2-summary-update-closure-model"
MODEL=P5AR2SummaryUpdateClosure.tla
TLA_JAR=${TLA_JAR:-"$WORKSPACE_DIR/build/tools/tla/tla2tools.jar"}
RUN_ID=${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
OUT_DIR="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r2-summary-update-closure/$RUN_ID"

die()
{
	printf 'error: %s\n' "$*" >&2
	exit 1
}

for command_name in awk find git grep java jq sed wc; do
	command -v "$command_name" >/dev/null 2>&1 \
		|| die "missing command: $command_name"
done
[ -f "$TLA_JAR" ] || die "missing TLA jar: $TLA_JAR"

mkdir -p "$OUT_DIR"
jq empty "$CONFIG"

jq -e '
  .status == "source_locking_update_closure_gate_shared_invalidation_unresolved" and
  (.summary_layers.rb_node_aggregate == true) and
  (.summary_layers.cfs_rq_tree_or_separate_current == true) and
  (.summary_layers.group_entity_projects_child == true) and
  (.summary_layers.final_task_fresh_recheck == true) and
  (.summary_layers.existing_min_vruntime_augmentation_is_fresh_summary == false) and
  (.summary_layers.existing_pelt_propagation_is_fresh_summary == false) and
  (.locking_contract | all(.[]; . == true)) and
  (.event_closure | all(.[]; . == true)) and
  (.shared_invalidation_gap.runtime_authority_publication_exists == false) and
  (.shared_invalidation_gap.domain_to_runnable_membership_index_exists == false) and
  (.shared_invalidation_gap.per_rq_receipt_generation_exists == false) and
  (.shared_invalidation_gap.shared_budget_fanout_exists == false) and
  (.shared_invalidation_gap.monitor_revoke_fanout_exists == false) and
  (.shared_invalidation_gap.selector_generation_protocol_exists == false) and
  (.shared_invalidation_gap.shared_invalidation_mechanism_resolved == false) and
  (.shared_invalidation_gap.behavior_patch_blocked == true) and
  (.picker_contract.summary_coherent_or_conservatively_invalid_before_pick == true) and
  (.picker_contract.picker_repairs_summary == false) and
  (.picker_contract.picker_scans_for_freshness == false) and
  (.picker_contract.monitor_call_in_picker == false) and
  (.picker_contract.policy_lookup_in_picker == false) and
  (.picker_contract.final_entity_fresh_recheck == true) and
  (.formal.unsafe_cfg_count == 24) and
  (.formal.unsafe_expected_counterexamples == 24) and
  (.safety_flags | all(.[]; . == false)) and
  (.next.linux_behavior_patch_allowed_after_this_gate == false)
' "$CONFIG" >/dev/null

expected_commit=$(jq -r '.source_basis.linux_commit' "$CONFIG")
expected_tree=$(jq -r '.source_basis.linux_tree' "$CONFIG")
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
[ "$anchor_count" = 32 ] || die "unexpected source anchor count: $anchor_count"
[ "$anchor_failures" = 0 ] || die "source anchor failures: $anchor_failures"

absence_ledger="$OUT_DIR/future-absence-checks.tsv"
printf 'id\tstatus\tpath\tpattern\n' > "$absence_ledger"
while IFS= read -r row; do
	id=$(printf '%s\n' "$row" | jq -r '.id')
	relative_path=$(printf '%s\n' "$row" | jq -r '.path')
	pattern=$(printf '%s\n' "$row" | jq -r '.pattern')
	repo="$WORKSPACE_DIR/$relative_path"
	if git -C "$repo" grep -Fq "$pattern" -- .; then
		status=unexpected-present
	else
		status=absent
	fi
	printf '%s\t%s\t%s\t%s\n' "$id" "$status" "$relative_path" "$pattern" \
		>> "$absence_ledger"
done < <(jq -c '.future_absence_checks[]' "$CONFIG")

absence_count=$(jq '.future_absence_checks | length' "$CONFIG")
absence_failures=$(awk -F '\t' 'NR > 1 && $2 != "absent" {c++} END {print c+0}' "$absence_ledger")
[ "$absence_count" = 4 ] || die "unexpected absence check count: $absence_count"
[ "$absence_failures" = 0 ] || die "future absence check failures: $absence_failures"

(
	cd "$MODEL_DIR"
	java -cp "$TLA_JAR" tlc2.TLC -deadlock \
		-metadir "$OUT_DIR/tlc-safe-states" \
		-config P5AR2SummaryUpdateClosureSafe.cfg "$MODEL"
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
for cfg in "$MODEL_DIR"/P5AR2SummaryUpdateClosureUnsafe*.cfg; do
	name=$(basename "$cfg" .cfg)
	log="$OUT_DIR/tlc-$name.log"
	if (
		cd "$MODEL_DIR"
		java -cp "$TLA_JAR" tlc2.TLC -deadlock \
			-metadir "$OUT_DIR/states-$name" \
			-config "$(basename "$cfg")" "$MODEL"
	) > "$log" 2>&1; then
		printf 'unsafe config unexpectedly passed: %s\n' "$(basename "$cfg")" >&2
		unsafe_failures=$((unsafe_failures + 1))
	elif grep -q 'Invariant Safety is violated' "$log"; then
		unsafe_expected=$((unsafe_expected + 1))
	else
		printf 'unsafe config failed unexpectedly: %s\n' "$(basename "$cfg")" >&2
		tail -n 60 "$log" >&2
		unsafe_failures=$((unsafe_failures + 1))
	fi
done

[ "$unsafe_failures" = 0 ] || die "unsafe TLC failures: $unsafe_failures"
cfg_count=$(find "$MODEL_DIR" -maxdepth 1 -name 'P5AR2SummaryUpdateClosureUnsafe*.cfg' | wc -l | tr -d ' ')
[ "$cfg_count" = 24 ] || die "unsafe config count mismatch: $cfg_count"
[ "$unsafe_expected" = 24 ] || die "unsafe counterexample count mismatch: $unsafe_expected"

jq -n \
	--arg run_id "$RUN_ID" \
	--arg linux_commit "$actual_commit" \
	--arg linux_tree "$actual_tree" \
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
	  status: "passed_with_shared_invalidation_blocker",
	  linux_commit: $linux_commit,
	  linux_tree: $linux_tree,
	  config: $config,
	  model_dir: $model_dir,
	  tla_jar: $tla_jar,
	  source_anchor_count: $source_anchor_count,
	  source_anchor_failures: $source_anchor_failures,
	  future_absence_check_count: $future_absence_check_count,
	  future_absence_check_failures: $future_absence_check_failures,
	  event_family_count: 10,
	  shared_invalidation_missing_mechanism_count: 6,
	  shared_invalidation_mechanism_resolved: false,
	  behavior_patch_blocked: true,
	  safe_passed: true,
	  safe_states_generated: $safe_states_generated,
	  safe_distinct_states: $safe_distinct_states,
	  safe_depth: $safe_depth,
	  unsafe_expected_counterexamples: $unsafe_expected_counterexamples,
	  linux_patch_approved: false,
	  runtime_behavior_approved: false,
	  protection_claim: false,
	  cost_claim: false
	}' > "$OUT_DIR/result.json"

cat "$OUT_DIR/result.json"
