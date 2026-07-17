#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
PRIMARY_DIR="$WORKSPACE_DIR/linux"
CANDIDATE_DIR="$WORKSPACE_DIR/build/DomainLeaseLinux.volume/worktrees/p5a-r2-e2-layout"
PATCH_QUEUE_DIR="$WORKSPACE_DIR/linux-patches"
CONFIG="$CAPSCHED_DIR/capsched-models/analysis/sched-exec-lease-p5a-r2-e2-layout-evidence-closure-v1.json"
MODEL_DIR="$CAPSCHED_DIR/capsched-models/formal/0128-p5a-r2-e2-layout-evidence-closure-model"
MODEL=P5AR2E2LayoutEvidenceClosure.tla
TLA_JAR=${TLA_JAR:-"$WORKSPACE_DIR/build/tools/tla/tla2tools.jar"}
RUN_ID=${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
OUT_DIR="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r2-e2-layout-evidence-closure/$RUN_ID"

die() { printf 'error: %s\n' "$*" >&2; exit 1; }
for cmd in awk find git grep java jq sed sha256sum wc; do command -v "$cmd" >/dev/null 2>&1 || die "missing command: $cmd"; done
[ -f "$TLA_JAR" ] || die "missing TLA jar: $TLA_JAR"
mkdir -p "$OUT_DIR"
jq empty "$CONFIG"

arm_result="$WORKSPACE_DIR/$(jq -r '.evidence.arm64_result' "$CONFIG")"
x86_result="$WORKSPACE_DIR/$(jq -r '.evidence.x86_64_result' "$CONFIG")"
arm_hash=$(sha256sum "$arm_result" | awk '{print $1}')
x86_hash=$(sha256sum "$x86_result" | awk '{print $1}')
[ "$arm_hash" = "$(jq -r '.evidence.arm64_result_sha256' "$CONFIG")" ] || die 'arm64 result hash mismatch'
[ "$x86_hash" = "$(jq -r '.evidence.x86_64_result_sha256' "$CONFIG")" ] || die 'x86_64 result hash mismatch'

jq -e '
  .status == "passed" and .architecture == "arm64" and
  .normal_config_off_build == true and .normal_config_on_candidate_disabled_build == true and
  .normal_candidate_symbols_absent == true and .e1_probe_symbol_count == 51 and
  .candidate_probe_symbol_count == 59 and .added_candidate_symbol_count == 8 and
  .missing_e1_symbol_count == 0 and .changed_e1_symbol_value_count == 0 and
  .cacheline_table_field_count == 27 and .layout_delta == {sched_entity:0,cfs_rq:0,rq:0,task_struct:0} and
  .protected_offsets_unchanged == true and .candidate_fields_within_containing_structures == true and
  .candidate_layout == {sched_entity_summary_valid:{offset:92,size:1},sched_entity_summary_min:{offset:200,size:8},rq_summary_state:{offset:3508,size:1},rq_built_generation:{offset:3512,size:8}} and
  .layout_candidate_accepted == false and .e3_rebuild_approved == false
' "$arm_result" >/dev/null

jq -e '
  .status == "passed" and .architecture == "x86_64" and .cross_compiled == true and
  .normal_config_off_build == true and .normal_config_on_candidate_disabled_build == true and
  .normal_candidate_symbols_absent == true and .e1_probe_symbol_count == 51 and
  .candidate_probe_symbol_count == 59 and .added_candidate_symbol_count == 8 and
  .missing_e1_symbol_count == 0 and .changed_e1_symbol_value_count == 0 and
  .cacheline_table_field_count == 27 and .layout_delta == {sched_entity:0,cfs_rq:0,rq:0,task_struct:0} and
  .protected_e1_values_unchanged == true and .candidate_fields_within_containing_structures == true and
  .candidate_layout == {sched_entity_summary_valid:{offset:92,size:1},sched_entity_summary_min:{offset:200,size:8},rq_summary_state:{offset:3380,size:1},rq_built_generation:{offset:3384,size:8}} and
  .layout_candidate_accepted == false and .e3_rebuild_approved == false
' "$x86_result" >/dev/null

expected_primary=$(jq -r '.source.primary_commit' "$CONFIG")
expected_candidate=$(jq -r '.source.candidate_commit' "$CONFIG")
expected_tree=$(jq -r '.source.candidate_tree' "$CONFIG")
expected_diff=$(jq -r '.source.candidate_diff_sha256' "$CONFIG")
[ "$(git -C "$PRIMARY_DIR" rev-parse HEAD)" = "$expected_primary" ] || die 'primary moved'
[ "$(git -C "$CANDIDATE_DIR" rev-parse HEAD)" = "$expected_candidate" ] || die 'candidate moved'
[ "$(git -C "$CANDIDATE_DIR" rev-parse HEAD^{tree})" = "$expected_tree" ] || die 'candidate tree moved'
[ -z "$(git -C "$PRIMARY_DIR" status --porcelain --untracked-files=no)" ] || die 'primary dirty'
[ -z "$(git -C "$CANDIDATE_DIR" status --porcelain --untracked-files=no)" ] || die 'candidate dirty'
[ "$(tail -n 1 "$PATCH_QUEUE_DIR/patches/capsched-linux-l0/series")" = '0014-sched-exec_lease-Expand-build-only-layout-probe.patch' ] || die 'patch queue moved'
git -C "$CANDIDATE_DIR" diff "$expected_primary..$expected_candidate" > "$OUT_DIR/candidate.diff"
[ "$(sha256sum "$OUT_DIR/candidate.diff" | awk '{print $1}')" = "$expected_diff" ] || die 'candidate diff changed'

jq -e '
  .status == "e2_cross_architecture_evidence_closure_plan" and
  .source.exact_four_file_scope == true and .source.default_off_probe_dependent == true and
  .evidence.required_architectures == ["arm64","x86_64"] and
  .evidence.e1_symbols_each == 51 and .evidence.candidate_additions_each == 8 and
  .evidence.candidate_symbols_each == 59 and .evidence.table_fields_each == 27 and
  .evidence.changed_e1_values_allowed == 0 and .evidence.missing_e1_symbols_allowed == 0 and
  .evidence.all_structure_deltas_required == 0 and .evidence.cross_architecture_byte_identity == false and
  (.frozen_fields | length == 4) and
  .architecture_local_offsets.arm64.rq_state == 3508 and
  .architecture_local_offsets.x86_64.rq_state == 3380 and
  .decision.e2_layout_evidence_complete == true and
  .decision.exact_disposable_layout_frozen_for_e3_planning == true and
  .decision.e3_plan_may_be_drafted == true and
  .decision.e3_worktree_may_be_created == false and
  ([.decision.production_layout_accepted,.decision.hot_field_approved,.decision.primary_linux_change_approved,.decision.patch_queue_change_approved,.decision.e3_source_approved,.decision.e3_rebuild_approved,.decision.runtime_behavior_approved,.decision.runtime_denial_correctness,.decision.production_protection,.decision.performance_claim,.decision.cost_claim,.decision.deployment_ready,.decision.datacenter_ready] | all(. == false)) and
  .formal.unsafe_cfg_count == 24
' "$CONFIG" >/dev/null

(
	cd "$MODEL_DIR"
	java -cp "$TLA_JAR" tlc2.TLC -deadlock -metadir "$OUT_DIR/tlc-safe-states" -config P5AR2E2LayoutEvidenceClosureSafe.cfg "$MODEL"
) > "$OUT_DIR/tlc-safe.log" 2>&1
grep -q 'Model checking completed. No error has been found' "$OUT_DIR/tlc-safe.log" || die 'safe TLC failed'
safe_states=$(sed -n 's/^\([0-9][0-9]*\) states generated.*/\1/p' "$OUT_DIR/tlc-safe.log" | tail -n 1)
safe_distinct=$(sed -n 's/^[0-9][0-9]* states generated, \([0-9][0-9]*\) distinct states found.*/\1/p' "$OUT_DIR/tlc-safe.log" | tail -n 1)
safe_depth=$(sed -n 's/^The depth of the complete state graph search is \([0-9][0-9]*\).*/\1/p' "$OUT_DIR/tlc-safe.log" | tail -n 1)

unsafe_expected=0
unsafe_failures=0
for cfg in "$MODEL_DIR"/P5AR2E2LayoutEvidenceClosureUnsafe*.cfg; do
	name=$(basename "$cfg" .cfg)
	log="$OUT_DIR/tlc-$name.log"
	if (cd "$MODEL_DIR" && java -cp "$TLA_JAR" tlc2.TLC -deadlock -metadir "$OUT_DIR/states-$name" -config "$(basename "$cfg")" "$MODEL") > "$log" 2>&1; then
		unsafe_failures=$((unsafe_failures + 1))
	elif grep -q 'Invariant Safety is violated' "$log"; then
		unsafe_expected=$((unsafe_expected + 1))
	else
		unsafe_failures=$((unsafe_failures + 1))
	fi
done
cfg_count=$(find "$MODEL_DIR" -maxdepth 1 -name 'P5AR2E2LayoutEvidenceClosureUnsafe*.cfg' | wc -l | tr -d ' ')
[ "$unsafe_failures" = 0 ] || die "unsafe TLC failures: $unsafe_failures"
[ "$cfg_count" = 24 ] && [ "$unsafe_expected" = 24 ] || die 'unsafe TLC count mismatch'

jq -n --arg run_id "$RUN_ID" --arg arm_hash "$arm_hash" --arg x86_hash "$x86_hash" \
	--arg primary "$expected_primary" --arg candidate "$expected_candidate" --arg tree "$expected_tree" --arg diff "$expected_diff" \
	--argjson safe_states "${safe_states:-0}" --argjson safe_distinct "${safe_distinct:-0}" --argjson safe_depth "${safe_depth:-0}" --argjson unsafe "$unsafe_expected" \
	'{schema_version:1,run_id:$run_id,status:"passed_e2_evidence_closure",arm64_result_sha256:$arm_hash,x86_64_result_sha256:$x86_hash,primary_commit:$primary,candidate_commit:$candidate,candidate_tree:$tree,candidate_diff_sha256:$diff,architectures:["arm64","x86_64"],e1_values_preserved_each:51,candidate_additions_each:8,candidate_symbols_each:59,cacheline_table_fields_each:27,all_structure_deltas_zero:true,architecture_local_offsets_preserved:true,safe_states_generated:$safe_states,safe_distinct_states:$safe_distinct,safe_depth:$safe_depth,unsafe_expected_counterexamples:$unsafe,e2_layout_evidence_complete:true,exact_disposable_layout_frozen_for_e3_planning:true,e3_plan_may_be_drafted:true,e3_worktree_may_be_created:false,production_layout_accepted:false,hot_field_approved:false,primary_linux_change_approved:false,patch_queue_change_approved:false,e3_source_approved:false,e3_rebuild_approved:false,runtime_behavior_approved:false,production_protection:false,performance_claim:false,cost_claim:false,deployment_ready:false,datacenter_ready:false}' > "$OUT_DIR/result.json"
cat "$OUT_DIR/result.json"
