#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
LINUX_DIR=${DOMAINLEASE_LINUX_DIR:-"$WORKSPACE_DIR/linux"}
PATCH_QUEUE_DIR="$WORKSPACE_DIR/linux-patches"
CONFIG="$CAPSCHED_DIR/capsched-models/analysis/sched-exec-lease-p5a-r2-e2-disposable-layout-candidate-plan-v1.json"
MODEL_DIR="$CAPSCHED_DIR/capsched-models/formal/0126-p5a-r2-e2-disposable-layout-candidate-plan-model"
MODEL=P5AR2E2DisposableLayoutCandidatePlan.tla
TLA_JAR=${TLA_JAR:-"$WORKSPACE_DIR/build/tools/tla/tla2tools.jar"}
RUN_ID=${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
OUT_DIR="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r2-e2-disposable-layout-candidate-plan/$RUN_ID"

die() { printf 'error: %s\n' "$*" >&2; exit 1; }

for cmd in awk find git grep java jq sed wc; do
	command -v "$cmd" >/dev/null 2>&1 || die "missing command: $cmd"
done
[ -f "$TLA_JAR" ] || die "missing TLA jar: $TLA_JAR"
mkdir -p "$OUT_DIR"
jq empty "$CONFIG"

expected_commit=$(jq -r '.source_basis.linux_commit' "$CONFIG")
expected_tree=$(jq -r '.source_basis.linux_tree' "$CONFIG")
actual_commit=$(git -C "$LINUX_DIR" rev-parse HEAD)
actual_tree=$(git -C "$LINUX_DIR" rev-parse HEAD^{tree})
[ "$actual_commit" = "$expected_commit" ] || die "Linux commit mismatch: $actual_commit"
[ "$actual_tree" = "$expected_tree" ] || die "Linux tree mismatch: $actual_tree"
[ -z "$(git -C "$LINUX_DIR" status --porcelain --untracked-files=no)" ] || die 'primary Linux tree dirty'

jq -e '
  .status == "e2_arm64_disposable_layout_candidate_plan_no_linux_change" and
  .workspace_contract.disposable_git_worktree_required == true and
  .workspace_contract.primary_linux_branch_may_change == false and
  .workspace_contract.primary_patch_queue_may_change == false and
  .workspace_contract.allowed_paths == ["init/Kconfig","include/linux/sched.h","kernel/sched/sched.h","kernel/sched/exec_lease_layout_probe.c"] and
  .workspace_contract.makefile_change_allowed == false and
  .candidate_config.name == "SCHED_EXEC_LEASE_LAYOUT_CANDIDATE" and
  .candidate_config.default_enabled == false and
  .candidate_config.depends_on_layout_probe == true and
  .candidate_config.selected_by_normal_sched_exec_lease == false and
  (.candidate_fields | length == 4) and
  ([.candidate_fields[].type] == ["unsigned char","u64","unsigned char","u64"]) and
  .forbidden_candidate_fields.cfs_rq == true and
  .forbidden_candidate_fields.task_struct == true and
  .forbidden_candidate_fields.rq_callback_or_list_carrier == true and
  .conditional_probe.existing_symbols_must_remain == 51 and
  .conditional_probe.added_symbol_count == 8 and
  .conditional_probe.expected_total_symbols == 59 and
  .conditional_probe.expected_cacheline_table_fields == 27 and
  .arm64_envelope.sched_entity_delta_max == 8 and
  .arm64_envelope.cfs_rq_delta_required == 0 and
  .arm64_envelope.rq_delta_max == 32 and
  .arm64_envelope.task_struct_delta_required == 0 and
  .arm64_envelope.cross_architecture_identity_claim == false and
  .build_matrix.normal_config_off == true and
  .build_matrix.normal_config_on_candidate_disabled == true and
  .build_matrix.explicit_probe_and_candidate == true and
  (.source_anchors | length == 20) and
  (.absence_checks | length == 6) and
  .formal.unsafe_cfg_count == 30 and
  (.safety_flags | all(.[]; . == false))
' "$CONFIG" >/dev/null

anchors="$OUT_DIR/source-anchors.tsv"
printf 'id\tstatus\tpath\tpattern\n' > "$anchors"
while IFS= read -r row; do
	id=$(jq -r '.id' <<<"$row")
	path=$(jq -r '.path' <<<"$row")
	pattern=$(jq -r '.pattern // empty' <<<"$row")
	commit=$(jq -r '.git_commit // empty' <<<"$row")
	if [ -n "$commit" ]; then
		actual=$(git -C "$WORKSPACE_DIR/$path" rev-parse HEAD)
		[ "$actual" = "$commit" ] && status=ok || status=missing
	elif grep -Fq "$pattern" "$WORKSPACE_DIR/$path"; then
		status=ok
	else
		status=missing
	fi
	printf '%s\t%s\t%s\t%s%s\n' "$id" "$status" "$path" "$pattern" "$commit" >> "$anchors"
done < <(jq -c '.source_anchors[]' "$CONFIG")
anchor_count=$(jq '.source_anchors | length' "$CONFIG")
anchor_failures=$(awk -F '\t' 'NR > 1 && $2 != "ok" {c++} END {print c+0}' "$anchors")
[ "$anchor_failures" = 0 ] || die "source anchor failures: $anchor_failures"

absence="$OUT_DIR/absence-checks.tsv"
printf 'id\tstatus\tpath\tpattern\n' > "$absence"
while IFS= read -r row; do
	id=$(jq -r '.id' <<<"$row")
	path=$(jq -r '.path' <<<"$row")
	pattern=$(jq -r '.pattern' <<<"$row")
	target="$WORKSPACE_DIR/$path"
	if [ -d "$target" ]; then
		if git -C "$target" grep -Fq "$pattern" -- .; then status=present; else status=absent; fi
	else
		if grep -Fq "$pattern" "$target"; then status=present; else status=absent; fi
	fi
	printf '%s\t%s\t%s\t%s\n' "$id" "$status" "$path" "$pattern" >> "$absence"
done < <(jq -c '.absence_checks[]' "$CONFIG")
absence_failures=$(awk -F '\t' 'NR > 1 && $2 != "absent" {c++} END {print c+0}' "$absence")
[ "$absence_failures" = 0 ] || die "absence failures: $absence_failures"

series="$PATCH_QUEUE_DIR/patches/capsched-linux-l0/series"
[ "$(tail -n 1 "$series")" = '0014-sched-exec_lease-Expand-build-only-layout-probe.patch' ] || die 'primary patch queue moved beyond 0014'

(
	cd "$MODEL_DIR"
	java -cp "$TLA_JAR" tlc2.TLC -deadlock -metadir "$OUT_DIR/tlc-safe-states" \
		-config P5AR2E2DisposableLayoutCandidatePlanSafe.cfg "$MODEL"
) > "$OUT_DIR/tlc-safe.log" 2>&1
grep -q 'Model checking completed. No error has been found' "$OUT_DIR/tlc-safe.log" || die 'safe TLC failed'
safe_states=$(sed -n 's/^\([0-9][0-9]*\) states generated.*/\1/p' "$OUT_DIR/tlc-safe.log" | tail -n 1)
safe_distinct=$(sed -n 's/^[0-9][0-9]* states generated, \([0-9][0-9]*\) distinct states found.*/\1/p' "$OUT_DIR/tlc-safe.log" | tail -n 1)
safe_depth=$(sed -n 's/^The depth of the complete state graph search is \([0-9][0-9]*\).*/\1/p' "$OUT_DIR/tlc-safe.log" | tail -n 1)

unsafe_expected=0
unsafe_failures=0
for cfg in "$MODEL_DIR"/P5AR2E2DisposableLayoutCandidatePlanUnsafe*.cfg; do
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
cfg_count=$(find "$MODEL_DIR" -maxdepth 1 -name 'P5AR2E2DisposableLayoutCandidatePlanUnsafe*.cfg' | wc -l | tr -d ' ')
[ "$unsafe_failures" = 0 ] || die "unsafe TLC failures: $unsafe_failures"
[ "$cfg_count" = 30 ] && [ "$unsafe_expected" = 30 ] || die 'unsafe TLC count mismatch'

jq -n \
	--arg run_id "$RUN_ID" --arg linux_commit "$actual_commit" --arg linux_tree "$actual_tree" \
	--argjson anchor_count "$anchor_count" --argjson anchor_failures "$anchor_failures" \
	--argjson absence_failures "$absence_failures" --argjson safe_states "${safe_states:-0}" \
	--argjson safe_distinct "${safe_distinct:-0}" --argjson safe_depth "${safe_depth:-0}" \
	--argjson unsafe_expected "$unsafe_expected" \
	'{schema_version:1,run_id:$run_id,status:"passed_plan_only",linux_commit:$linux_commit,linux_tree:$linux_tree,source_anchor_count:$anchor_count,source_anchor_failures:$anchor_failures,absence_failures:$absence_failures,safe_states_generated:$safe_states,safe_distinct_states:$safe_distinct,safe_depth:$safe_depth,unsafe_expected_counterexamples:$unsafe_expected,primary_patch_queue_tail:"0014",expected_e1_symbols:51,expected_candidate_added_symbols:8,expected_candidate_total_symbols:59,expected_cacheline_table_fields:27,disposable_worktree_may_be_created:true,primary_linux_change_approved:false,patch_queue_change_approved:false,e3_rebuild_approved:false,behavior_approved:false,protection_claim:false}' \
	> "$OUT_DIR/result.json"
cat "$OUT_DIR/result.json"
