#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
LINUX_DIR=${DOMAINLEASE_LINUX_DIR:-"$WORKSPACE_DIR/linux"}
CONFIG="$CAPSCHED_DIR/capsched-models/analysis/sched-exec-lease-p5a-r2-versioned-global-invalidation-fence-v1.json"
MODEL_DIR="$CAPSCHED_DIR/capsched-models/formal/0123-p5a-r2-versioned-global-invalidation-fence-model"
MODEL=P5AR2VersionedGlobalInvalidationFence.tla
TLA_JAR=${TLA_JAR:-"$WORKSPACE_DIR/build/tools/tla/tla2tools.jar"}
RUN_ID=${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
OUT_DIR="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r2-versioned-global-invalidation-fence/$RUN_ID"

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
  .status == "shared_invalidation_architecture_gate_global_conservative_no_linux_patch" and
  (.decision.locally_published_global_projection_generation == true) and
  (.decision.per_rq_built_generation == true) and
  (.decision.per_rq_semantic_state == true) and
  (.decision.picker_generation_fence == true) and
  (.decision.all_online_rq_fanout == true) and
  (.decision.targeted_domain_fanout == false) and
  (.decision.domain_runnable_index_required_for_baseline == false) and
  (.publication_contract.serialized_shared_update == true) and
  (.publication_contract.frozen_state_written_before_generation == true) and
  (.publication_contract.generation_release_publish == true) and
  (.publication_contract.picker_acquire_load == true) and
  (.publication_contract.fanout_after_generation_publish == true) and
  (.publication_contract.generation_wrap_reuse == false) and
  (.publication_contract.generation_saturation_blocks == true) and
  (.publication_contract.external_monitor_delivery_proven == false) and
  (.publication_contract.contract_starts_at_local_publication == true) and
  (.event_fence.domain_epoch_or_grant_generation == true) and
  (.event_fence.shared_budget_eligibility_transition == true) and
  (.event_fence.future_monitor_receipt_local_publication == true) and
  (.event_fence.outer_bucket_topology_or_configuration == true) and
  (.event_fence.ordinary_budget_decrement_above_threshold == false) and
  (.event_fence.per_pick_outer_selector_choice == false) and
  (.picker_contract | all(.[]; . == true or . == false)) and
  (.picker_contract.picker_scan == false) and
  (.picker_contract.picker_rebuild == false) and
  (.picker_contract.picker_allocation_or_sleep == false) and
  (.picker_contract.picker_policy_lookup == false) and
  (.picker_contract.picker_monitor_call == false) and
  (.rebuild_contract.owning_rq_lock_required == true) and
  (.rebuild_contract.rb_aggregate_full_rebuild == true) and
  (.rebuild_contract.separate_current_rebuilt == true) and
  (.rebuild_contract.group_projection_to_root_rebuilt == true) and
  (.rebuild_contract.generation_rechecked_before_fresh == true) and
  (.rebuild_contract.raced_rebuild_remains_stale_or_blocked == true) and
  (.rebuild_contract.partial_rebuild_published_fresh == false) and
  (.rebuild_contract.external_call_or_sleep == false) and
  (.rebuild_contract.full_o_n_locked_rebuild_is_performance_approved == false) and
  (.rebuild_contract.chunked_rebuild_approved == false) and
  (.mutation_contract | all(.[]; . == true)) and
  (.targeted_fanout_requirements.requirements_currently_met == false) and
  (.targeted_fanout_requirements.targeted_fanout_approved == false) and
  (.outer_selector_contract.generation_is_topology_membership_configuration == true) and
  (.outer_selector_contract.generation_is_per_pick_choice == false) and
  (.outer_selector_contract.candidate_c_implemented == false) and
  (.outer_selector_contract.candidate_a_remains_local_projection == true) and
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
[ "$anchor_count" = 15 ] || die "unexpected source anchor count: $anchor_count"
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
		-config P5AR2VersionedGlobalInvalidationFenceSafe.cfg "$MODEL"
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
for cfg in "$MODEL_DIR"/P5AR2VersionedGlobalInvalidationFenceUnsafe*.cfg; do
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
cfg_count=$(find "$MODEL_DIR" -maxdepth 1 -name 'P5AR2VersionedGlobalInvalidationFenceUnsafe*.cfg' | wc -l | tr -d ' ')
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
	  status: "passed_global_conservative_architecture_only",
	  linux_commit: $linux_commit,
	  linux_tree: $linux_tree,
	  config: $config,
	  model_dir: $model_dir,
	  tla_jar: $tla_jar,
	  source_anchor_count: $source_anchor_count,
	  source_anchor_failures: $source_anchor_failures,
	  future_absence_check_count: $future_absence_check_count,
	  future_absence_check_failures: $future_absence_check_failures,
	  global_projection_generation_required: true,
	  all_online_rq_fanout_required: true,
	  targeted_fanout_approved: false,
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
