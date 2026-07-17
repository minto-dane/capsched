#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
LINUX_DIR=${DOMAINLEASE_LINUX_DIR:-"$WORKSPACE_DIR/linux"}
CONFIG="$CAPSCHED_DIR/capsched-models/analysis/sched-exec-lease-p5a-r2-global-fence-layout-rebuild-evidence-plan-v1.json"
MODEL_DIR="$CAPSCHED_DIR/capsched-models/formal/0124-p5a-r2-global-fence-layout-rebuild-evidence-plan-model"
MODEL=P5AR2GlobalFenceLayoutRebuildEvidencePlan.tla
TLA_JAR=${TLA_JAR:-"$WORKSPACE_DIR/build/tools/tla/tla2tools.jar"}
RUN_ID=${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
OUT_DIR="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r2-global-fence-layout-rebuild-evidence-plan/$RUN_ID"

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
  .status == "implementation_evidence_plan_no_linux_patch_or_hot_field_approved" and
  (.baseline.x86_64.sched_entity_size == 320) and
  (.baseline.arm64_raw_probe.sched_entity_size == 320) and
  (.baseline.arm64_raw_probe.rq_size == 3520) and
  (.baseline.arm64_raw_probe.structured_table_recorded == false) and
  (.baseline.cross_arch_byte_identity_expected == false) and
  (.baseline.compare_each_arch_to_own_baseline == true) and
  (.candidate_envelope.sched_entity_size_delta_max == 8) and
  (.candidate_envelope.cfs_rq_size_delta_required == 0) and
  (.candidate_envelope.rq_size_delta_max == 32) and
  (.candidate_envelope.task_struct_size_delta_required == 0) and
  (.candidate_envelope.rq_fields_after_existing_hot_regions == true) and
  (.candidate_envelope.exceeding_envelope_blocks_candidate == true) and
  (.evidence_stages.expanded_build_only_probe == true) and
  (.evidence_stages.disposable_layout_only_candidate == true) and
  (.evidence_stages.default_off_test_only_rebuild == true) and
  (.evidence_stages.live_lock_hold_measurement == true) and
  (.evidence_stages.behavior_patch_stage == false) and
  (.evidence_stages.patch_slot_reserved == false) and
  (.rebuild_correctness.brute_force_oracle_required == true) and
  (.rebuild_correctness.wrap_boundary_values_required == true) and
  (.rebuild_correctness.postorder_rb_source_proof_required == true) and
  (.rebuild_correctness.bottom_up_cfs_rq_source_proof_required == true) and
  (.rebuild_correctness.unbounded_recursive_group_walk_allowed == false) and
  (.rebuild_correctness.allocation_sleep_monitor_policy_allowed == false) and
  (.rebuild_correctness.partial_or_raced_fresh_allowed == false) and
  (.lock_hold_matrix.runnable_entities == [0,1,8,64,256,1024,4096]) and
  (.lock_hold_matrix.hierarchy_depths == [0,1,4,16,64]) and
  (.lock_hold_matrix.minimum_samples_where_practical == 10000) and
  (.lock_hold_gate.base_slice_ns == 700000) and
  (.lock_hold_gate.effective_p99_limit_ns == 25000) and
  (.lock_hold_gate.effective_raw_max_limit_ns == 50000) and
  (.lock_hold_gate.sample_may_reach_base_slice == false) and
  (.lock_hold_gate.lockdep_irqsoff_rcu_soft_hard_lockup_warning_allowed == false) and
  (.lock_hold_gate.failure_rejects_full_locked_rebuild == true) and
  (.lock_hold_gate.shrinking_test_range_without_enforced_bound_allowed == false) and
  (.build_matrix.config_off == true) and
  (.build_matrix.config_on_fence_disabled == true) and
  (.build_matrix.config_on_probe == true) and
  (.build_matrix.x86_64 == true) and
  (.build_matrix.arm64 == true) and
  (.build_matrix.config_off_candidate_symbols_or_branches == false) and
  (.build_matrix.disabled_picker_generation_load == false) and
  (.build_matrix.enabled_generation_check_per_rb_node == false) and
  (.build_matrix.picker_scan_rebuild_allocation_sleep_monitor_policy == false) and
  (.required_hot_functions | length == 11) and
  (.formal.unsafe_cfg_count == 32) and
  (.formal.unsafe_expected_counterexamples == 32) and
  (.safety_flags | all(.[]; . == false)) and
  (.next.linux_patch_allowed_after_this_gate == false)
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
[ "$anchor_count" = 24 ] || die "unexpected source anchor count: $anchor_count"
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
[ "$absence_count" = 6 ] || die "unexpected absence check count: $absence_count"
[ "$absence_failures" = 0 ] || die "future absence check failures: $absence_failures"

(
	cd "$MODEL_DIR"
	java -cp "$TLA_JAR" tlc2.TLC -deadlock \
		-metadir "$OUT_DIR/tlc-safe-states" \
		-config P5AR2GlobalFenceLayoutRebuildEvidencePlanSafe.cfg "$MODEL"
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
for cfg in "$MODEL_DIR"/P5AR2GlobalFenceLayoutRebuildEvidencePlanUnsafe*.cfg; do
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
cfg_count=$(find "$MODEL_DIR" -maxdepth 1 -name 'P5AR2GlobalFenceLayoutRebuildEvidencePlanUnsafe*.cfg' | wc -l | tr -d ' ')
[ "$cfg_count" = 32 ] || die "unsafe config count mismatch: $cfg_count"
[ "$unsafe_expected" = 32 ] || die "unsafe counterexample count mismatch: $unsafe_expected"

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
	  status: "passed_evidence_plan_only",
	  linux_commit: $linux_commit,
	  linux_tree: $linux_tree,
	  config: $config,
	  model_dir: $model_dir,
	  tla_jar: $tla_jar,
	  source_anchor_count: $source_anchor_count,
	  source_anchor_failures: $source_anchor_failures,
	  future_absence_check_count: $future_absence_check_count,
	  future_absence_check_failures: $future_absence_check_failures,
	  sched_entity_max_delta_bytes: 8,
	  cfs_rq_required_delta_bytes: 0,
	  rq_max_delta_bytes: 32,
	  task_struct_required_delta_bytes: 0,
	  p99_lock_hold_limit_ns: 25000,
	  raw_max_lock_hold_limit_ns: 50000,
	  safe_passed: true,
	  safe_states_generated: $safe_states_generated,
	  safe_distinct_states: $safe_distinct_states,
	  safe_depth: $safe_depth,
	  unsafe_expected_counterexamples: $unsafe_expected_counterexamples,
	  linux_patch_approved: false,
	  hot_field_approved: false,
	  runtime_behavior_approved: false,
	  protection_claim: false,
	  cost_claim: false
	}' > "$OUT_DIR/result.json"

cat "$OUT_DIR/result.json"
