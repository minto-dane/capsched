#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
PRIMARY_DIR="$WORKSPACE_DIR/linux"
CANDIDATE_DIR="$WORKSPACE_DIR/build/DomainLeaseLinux.volume/worktrees/p5a-r2-e2-layout"
PATCH_QUEUE_DIR="$WORKSPACE_DIR/linux-patches"
CONFIG="$CAPSCHED_DIR/capsched-models/analysis/sched-exec-lease-p5a-r2-e3-rebuild-prototype-evidence-plan-v1.json"
MODEL_DIR="$CAPSCHED_DIR/capsched-models/formal/0129-p5a-r2-e3-rebuild-prototype-evidence-plan-model"
MODEL=P5AR2E3RebuildPrototypeEvidencePlan.tla
TLA_JAR=${TLA_JAR:-"$WORKSPACE_DIR/build/tools/tla/tla2tools.jar"}
RUN_ID=${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
OUT_DIR="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r2-e3-rebuild-prototype-evidence-plan/$RUN_ID"

die() { printf 'error: %s\n' "$*" >&2; exit 1; }
for cmd in awk find git grep java jq sed sha256sum wc; do
	command -v "$cmd" >/dev/null 2>&1 || die "missing command: $cmd"
done
[ -f "$TLA_JAR" ] || die "missing TLA jar: $TLA_JAR"
mkdir -p "$OUT_DIR"
jq empty "$CONFIG"

expected_primary=$(jq -r '.source.primary_commit' "$CONFIG")
expected_candidate=$(jq -r '.source.e2_candidate_commit' "$CONFIG")
expected_tree=$(jq -r '.source.e2_candidate_tree' "$CONFIG")
expected_diff=$(jq -r '.source.e2_candidate_diff_sha256' "$CONFIG")

[ "$(git -C "$PRIMARY_DIR" rev-parse HEAD)" = "$expected_primary" ] || die 'primary Linux moved'
[ "$(git -C "$CANDIDATE_DIR" rev-parse HEAD)" = "$expected_candidate" ] || die 'E2 candidate moved'
[ "$(git -C "$CANDIDATE_DIR" rev-parse HEAD^{tree})" = "$expected_tree" ] || die 'E2 candidate tree moved'
[ -z "$(git -C "$PRIMARY_DIR" status --porcelain --untracked-files=no)" ] || die 'primary Linux dirty'
[ -z "$(git -C "$CANDIDATE_DIR" status --porcelain --untracked-files=no)" ] || die 'E2 candidate dirty'
[ "$(tail -n 1 "$PATCH_QUEUE_DIR/patches/capsched-linux-l0/series")" = \
	'0014-sched-exec_lease-Expand-build-only-layout-probe.patch' ] || die 'patch queue moved'

git -C "$CANDIDATE_DIR" diff "$expected_primary..$expected_candidate" > "$OUT_DIR/e2-candidate.diff"
[ "$(sha256sum "$OUT_DIR/e2-candidate.diff" | awk '{print $1}')" = "$expected_diff" ] || die 'E2 candidate diff changed'

closure="$WORKSPACE_DIR/$(jq -r '.prerequisite.closure_result' "$CONFIG")"
closure_hash=$(sha256sum "$closure" | awk '{print $1}')
[ "$closure_hash" = "$(jq -r '.prerequisite.closure_result_sha256' "$CONFIG")" ] || die 'E2 closure hash mismatch'
jq -e '
  .status == "passed_e2_evidence_closure" and
  .e2_layout_evidence_complete == true and
  .exact_disposable_layout_frozen_for_e3_planning == true and
  .e3_plan_may_be_drafted == true and
  .e3_worktree_may_be_created == false and
  .production_layout_accepted == false and
  .e3_source_approved == false and
  .e3_rebuild_approved == false
' "$closure" >/dev/null

jq -e '
  .status == "e3_disposable_rebuild_prototype_pre_source_plan" and
  .source.allowed_files == ["init/Kconfig","kernel/sched/fair.c"] and
  .source.frozen_files == ["include/linux/sched.h","kernel/sched/sched.h","kernel/sched/exec_lease_layout_probe.c","kernel/sched/Makefile"] and
  .source.primary_change_allowed == false and
  .source.patch_queue_change_allowed == false and
  .source.e2_candidate_change_allowed == false and
  .configuration.name == "SCHED_EXEC_LEASE_REBUILD_KUNIT_TEST" and
  .configuration.type == "bool" and
  .configuration.default_enabled == false and
  .configuration.depends_on_layout_candidate == true and
  .configuration.depends_on_builtin_kunit == true and
  .configuration.selected_by_ordinary_lease == false and
  .configuration.selected_by_kunit_all_tests == false and
  .configuration.same_translation_unit == "kernel/sched/fair.c" and
  .configuration.suite_name == "sched_exec_lease_rebuild" and
  .configuration.makefile_change_allowed == false and
  ([.prototype.rq_lock_assertion_required,.prototype.state_refreshing_before_aggregate_write,.prototype.generation_acquire_read_before,.prototype.generation_acquire_read_after,.prototype.fresh_only_when_generation_unchanged_and_complete,.prototype.generation_saturation_is_blocked,.prototype.rb_postorder_required,.prototype.cfs_rq_bottom_up_required,.prototype.task_leaf_revalidation_exactly_once,.prototype.group_projection_after_child,.prototype.current_separate_from_tree,.prototype.tagged_wrap_aware_minimum] | all(. == true)) and
  ([.prototype.numeric_sentinel_allowed,.prototype.recursive_group_walk_allowed,.prototype.real_publisher_allowed,.prototype.real_fanout_allowed,.prototype.real_worker_allowed,.prototype.picker_connection_allowed,.prototype.incremental_update_hooks_allowed] | all(. == false)) and
  .oracle.independent_representation == true and
  .oracle.shares_combine_helper == false and
  .oracle.shares_postorder_helper == false and
  .oracle.calls_min_vruntime == false and
  .oracle.direct_signed_delta_comparison == true and
  .oracle.exhaustive_leaf_limit == 6 and
  .oracle.wrap_bases == ["0","S64_MAX","U64_MAX"] and
  (.required_case_families | length == 14) and
  (.forbidden_locked_operations | all(.[]; . == true)) and
  (.build_matrix | [.fresh_output_per_mode,.exact_parent_baseline,.e3_config_off_lease_off,.e3_config_off_layout_on,.e3_config_on_kunit_on,.disabled_helper_and_suite_symbols_absent,.enabled_helper_and_suite_symbols_present,.arm64_qemu_kunit_boot,.record_fair_object_evidence] | all(. == true)) and
  .build_matrix.required_cases_failed_allowed == 0 and
  .build_matrix.required_cases_skipped_allowed == 0 and
  (.source_anchors | length == 26) and
  (.absence_checks | length == 6) and
  .formal.unsafe_cfg_count == 24 and
  .authorization_after_plan_pass.e3_disposable_worktree_may_be_created == true and
  .authorization_after_plan_pass.e3_two_file_source_draft_may_be_created == true and
  .authorization_after_plan_pass.e3_source_accepted == false and
  .authorization_after_plan_pass.e3_rebuild_correctness_accepted == false and
  .authorization_after_plan_pass.e4_measurement_approved == false and
  (.safety_flags | all(.[]; . == false))
' "$CONFIG" >/dev/null

anchors="$OUT_DIR/source-anchors.tsv"
printf 'id\tstatus\tpath\tpattern\n' > "$anchors"
while IFS='|' read -r id path pattern; do
	if grep -Fq "$pattern" "$WORKSPACE_DIR/$path"; then status=ok; else status=missing; fi
	printf '%s\t%s\t%s\t%s\n' "$id" "$status" "$path" "$pattern" >> "$anchors"
done < <(jq -r '.source_anchors[] | [.id, .path, .pattern] | join("|")' "$CONFIG")
anchor_count=$(jq '.source_anchors | length' "$CONFIG")
anchor_failures=$(awk -F '\t' 'NR > 1 && $2 != "ok" {c++} END {print c+0}' "$anchors")
[ "$anchor_failures" = 0 ] || die "source anchor failures: $anchor_failures"

absence="$OUT_DIR/absence-checks.tsv"
printf 'id\tstatus\tpath\tpattern\n' > "$absence"
while IFS='|' read -r id path pattern; do
	if git -C "$WORKSPACE_DIR/$path" grep -Fq "$pattern" -- .; then status=present; else status=absent; fi
	printf '%s\t%s\t%s\t%s\n' "$id" "$status" "$path" "$pattern" >> "$absence"
done < <(jq -r '.absence_checks[] | [.id, .path, .pattern] | join("|")' "$CONFIG")
absence_failures=$(awk -F '\t' 'NR > 1 && $2 != "absent" {c++} END {print c+0}' "$absence")
[ "$absence_failures" = 0 ] || die "absence failures: $absence_failures"

(
	cd "$MODEL_DIR"
	java -cp "$TLA_JAR" tlc2.TLC -deadlock -metadir "$OUT_DIR/tlc-safe-states" \
		-config P5AR2E3RebuildPrototypeEvidencePlanSafe.cfg "$MODEL"
) > "$OUT_DIR/tlc-safe.log" 2>&1
grep -q 'Model checking completed. No error has been found' "$OUT_DIR/tlc-safe.log" || die 'safe TLC failed'
safe_states=$(sed -n 's/^\([0-9][0-9]*\) states generated.*/\1/p' "$OUT_DIR/tlc-safe.log" | tail -n 1)
safe_distinct=$(sed -n 's/^[0-9][0-9]* states generated, \([0-9][0-9]*\) distinct states found.*/\1/p' "$OUT_DIR/tlc-safe.log" | tail -n 1)
safe_depth=$(sed -n 's/^The depth of the complete state graph search is \([0-9][0-9]*\).*/\1/p' "$OUT_DIR/tlc-safe.log" | tail -n 1)

unsafe_expected=0
unsafe_failures=0
for cfg in "$MODEL_DIR"/P5AR2E3RebuildPrototypeEvidencePlanUnsafe*.cfg; do
	name=$(basename "$cfg" .cfg)
	log="$OUT_DIR/tlc-$name.log"
	if (cd "$MODEL_DIR" && java -cp "$TLA_JAR" tlc2.TLC -deadlock \
		-metadir "$OUT_DIR/states-$name" -config "$(basename "$cfg")" "$MODEL") > "$log" 2>&1; then
		unsafe_failures=$((unsafe_failures + 1))
	elif grep -q 'Invariant Safety is violated' "$log"; then
		unsafe_expected=$((unsafe_expected + 1))
	else
		unsafe_failures=$((unsafe_failures + 1))
	fi
done
cfg_count=$(find "$MODEL_DIR" -maxdepth 1 -name 'P5AR2E3RebuildPrototypeEvidencePlanUnsafe*.cfg' | wc -l | tr -d ' ')
[ "$unsafe_failures" = 0 ] || die "unsafe TLC failures: $unsafe_failures"
[ "$cfg_count" = 24 ] && [ "$unsafe_expected" = 24 ] || die 'unsafe TLC count mismatch'

jq -n \
	--arg run_id "$RUN_ID" --arg closure_hash "$closure_hash" \
	--arg primary "$expected_primary" --arg candidate "$expected_candidate" \
	--arg tree "$expected_tree" --arg diff "$expected_diff" \
	--argjson anchor_count "$anchor_count" --argjson anchor_failures "$anchor_failures" \
	--argjson absence_failures "$absence_failures" \
	--argjson safe_states "${safe_states:-0}" --argjson safe_distinct "${safe_distinct:-0}" \
	--argjson safe_depth "${safe_depth:-0}" --argjson unsafe "$unsafe_expected" \
	'{schema_version:1,run_id:$run_id,status:"passed_e3_plan_only",e2_closure_result_sha256:$closure_hash,primary_commit:$primary,e2_candidate_commit:$candidate,e2_candidate_tree:$tree,e2_candidate_diff_sha256:$diff,source_anchor_count:$anchor_count,source_anchor_failures:$anchor_failures,absence_failures:$absence_failures,safe_states_generated:$safe_states,safe_distinct_states:$safe_distinct,safe_depth:$safe_depth,unsafe_expected_counterexamples:$unsafe,allowed_files:["init/Kconfig","kernel/sched/fair.c"],frozen_field_count:4,required_case_family_count:14,e3_disposable_worktree_may_be_created:true,e3_two_file_source_draft_may_be_created:true,e3_source_accepted:false,e3_rebuild_correctness_accepted:false,e4_measurement_approved:false,production_layout_accepted:false,hot_field_approved:false,primary_linux_change_approved:false,patch_queue_change_approved:false,real_picker_fence_approved:false,real_publisher_approved:false,real_fanout_approved:false,runtime_behavior_approved:false,runtime_denial_correctness:false,production_protection:false,performance_claim:false,cost_claim:false,deployment_ready:false,datacenter_ready:false}' \
	> "$OUT_DIR/result.json"
cat "$OUT_DIR/result.json"
