#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
LINUX_DIR=${DOMAINLEASE_LINUX_DIR:-"$WORKSPACE_DIR/linux"}
PATCH_QUEUE_DIR="$WORKSPACE_DIR/linux-patches"
CONFIG="$CAPSCHED_DIR/capsched-models/analysis/sched-exec-lease-p5a-r2-expanded-layout-probe-patch-plan-v1.json"
MODEL_DIR="$CAPSCHED_DIR/capsched-models/formal/0125-p5a-r2-expanded-layout-probe-patch-plan-model"
MODEL=P5AR2ExpandedLayoutProbePatchPlan.tla
TLA_JAR=${TLA_JAR:-"$WORKSPACE_DIR/build/tools/tla/tla2tools.jar"}
RUN_ID=${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
OUT_DIR="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r2-expanded-layout-probe-patch-plan/$RUN_ID"
IMPLEMENTED_0014=${DOMAINLEASE_P5AR2_0014_IMPLEMENTED:-0}

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
if [ "$IMPLEMENTED_0014" = 1 ]; then
	actual_parent=$(git -C "$LINUX_DIR" rev-parse HEAD^)
	actual_parent_tree=$(git -C "$LINUX_DIR" rev-parse HEAD^^{tree})
	[ "$actual_parent" = "$expected_commit" ] || die "implemented 0014 parent mismatch"
	[ "$actual_parent_tree" = "$expected_tree" ] || die "implemented 0014 parent tree mismatch"
else
	[ "$actual_commit" = "$expected_commit" ] || die "Linux commit mismatch"
	[ "$actual_tree" = "$expected_tree" ] || die "Linux tree mismatch"
fi
[ -z "$(git -C "$LINUX_DIR" status --porcelain --untracked-files=no)" ] || die 'Linux tracked tree is dirty'

jq -e '
  .status == "expanded_probe_patch_plan_no_linux_patch_created" and
  .patch_plan.slot == "0014" and
  .patch_plan.linux_patch_created == false and
  .patch_plan.linux_patch_approved_after_gate == true and
  .patch_plan.behavior_patch_approved == false and
  .patch_plan.allowed_linux_paths == ["kernel/sched/exec_lease_layout_probe.c"] and
  .patch_plan.kconfig_change_allowed == false and
  .patch_plan.makefile_change_allowed == false and
  .patch_plan.structure_or_hot_field_change_allowed == false and
  .patch_plan.runtime_function_or_callsite_allowed == false and
  .patch_plan.expected_existing_symbol_count == 24 and
  .patch_plan.expected_added_symbol_count == 27 and
  .patch_plan.expected_total_symbol_count == 51 and
  (.added_measurements | length == 14) and
  (.cacheline_contract.cacheline_width_measured_from_object == true) and
  (.cacheline_contract.start_index_derived == true) and
  (.cacheline_contract.end_index_derived == true) and
  (.cacheline_contract.runtime_reporting_added == false) and
  (.cacheline_contract.compare_each_architecture_to_own_baseline == true) and
  (.cacheline_contract.cross_arch_byte_identity == false) and
  (.candidate_field_contract.candidate_fields_exist == false) and
  (.candidate_field_contract.placeholder_fields_allowed == false) and
  (.candidate_field_contract.candidate_symbols_allowed_in_0014 == false) and
  (.candidate_field_contract.conditional_symbols_added_with_future_disposable_e2_delta == true) and
  (.required_validation | all(.[]; . == true)) and
  (.source_anchors | length == 25) and
  (.absence_checks | length == 3) and
  .formal.unsafe_cfg_count == 20 and
  (.safety_flags | all(.[]; . == false))
' "$CONFIG" >/dev/null

anchors="$OUT_DIR/source-anchors.tsv"
printf 'id\tstatus\tpath\tpattern\n' > "$anchors"
while IFS= read -r row; do
	id=$(jq -r '.id' <<<"$row")
	path=$(jq -r '.path' <<<"$row")
	pattern=$(jq -r '.pattern' <<<"$row")
	if grep -Fq "$pattern" "$WORKSPACE_DIR/$path"; then status=ok; else status=missing; fi
	printf '%s\t%s\t%s\t%s\n' "$id" "$status" "$path" "$pattern" >> "$anchors"
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
	if [ "$IMPLEMENTED_0014" = 1 ] && [ "$id" = slot_free ]; then
		if tail -n 1 "$target" | grep -q '^0014-'; then status=implemented-expected; else status=missing-implementation; fi
	elif [ "$IMPLEMENTED_0014" = 1 ] && [ "$id" = new_probe_symbols_absent ]; then
		if grep -Fq "$pattern" "$target"; then status=implemented-expected; else status=missing-implementation; fi
	elif [ -d "$target" ]; then
		if git -C "$target" grep -Fq "$pattern" -- .; then status=present; else status=absent; fi
	else
		if grep -Fq "$pattern" "$target"; then status=present; else status=absent; fi
	fi
	printf '%s\t%s\t%s\t%s\n' "$id" "$status" "$path" "$pattern" >> "$absence"
done < <(jq -c '.absence_checks[]' "$CONFIG")
absence_failures=$(awk -F '\t' 'NR > 1 && $2 != "absent" && $2 != "implemented-expected" {c++} END {print c+0}' "$absence")
[ "$absence_failures" = 0 ] || die "absence failures: $absence_failures"

series="$PATCH_QUEUE_DIR/patches/capsched-linux-l0/series"
if [ "$IMPLEMENTED_0014" = 1 ]; then
	[ "$(tail -n 1 "$series")" = '0014-sched-exec_lease-Expand-build-only-layout-probe.patch' ] || die 'patch queue tail is not implemented 0014'
else
	[ "$(tail -n 1 "$series")" = '0013-sched-exec_lease-Add-build-only-layout-probe.patch' ] || die 'patch queue tail is not 0013'
fi

(
	cd "$MODEL_DIR"
	java -cp "$TLA_JAR" tlc2.TLC -deadlock -metadir "$OUT_DIR/tlc-safe-states" \
		-config P5AR2ExpandedLayoutProbePatchPlanSafe.cfg "$MODEL"
) > "$OUT_DIR/tlc-safe.log" 2>&1
grep -q 'Model checking completed. No error has been found' "$OUT_DIR/tlc-safe.log" || die 'safe TLC failed'
safe_states=$(sed -n 's/^\([0-9][0-9]*\) states generated.*/\1/p' "$OUT_DIR/tlc-safe.log" | tail -n 1)
safe_distinct=$(sed -n 's/^[0-9][0-9]* states generated, \([0-9][0-9]*\) distinct states found.*/\1/p' "$OUT_DIR/tlc-safe.log" | tail -n 1)
safe_depth=$(sed -n 's/^The depth of the complete state graph search is \([0-9][0-9]*\).*/\1/p' "$OUT_DIR/tlc-safe.log" | tail -n 1)

unsafe_expected=0
unsafe_failures=0
for cfg in "$MODEL_DIR"/P5AR2ExpandedLayoutProbePatchPlanUnsafe*.cfg; do
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
cfg_count=$(find "$MODEL_DIR" -maxdepth 1 -name 'P5AR2ExpandedLayoutProbePatchPlanUnsafe*.cfg' | wc -l | tr -d ' ')
[ "$unsafe_failures" = 0 ] || die "unsafe TLC failures: $unsafe_failures"
[ "$cfg_count" = 20 ] && [ "$unsafe_expected" = 20 ] || die 'unsafe TLC count mismatch'

jq -n \
	--arg run_id "$RUN_ID" --arg linux_commit "$actual_commit" --arg linux_tree "$actual_tree" \
	--argjson implemented_0014 "$IMPLEMENTED_0014" \
	--argjson anchor_count "$anchor_count" --argjson anchor_failures "$anchor_failures" \
	--argjson absence_failures "$absence_failures" --argjson safe_states "${safe_states:-0}" \
	--argjson safe_distinct "${safe_distinct:-0}" --argjson safe_depth "${safe_depth:-0}" \
	--argjson unsafe_expected "$unsafe_expected" \
	'{schema_version:1,run_id:$run_id,status:(if $implemented_0014 == 1 then "passed_retrospective_arithmetic_correction" else "passed_patch_plan_only" end),implemented_0014:($implemented_0014 == 1),linux_commit:$linux_commit,linux_tree:$linux_tree,source_anchor_count:$anchor_count,source_anchor_failures:$anchor_failures,absence_failures:$absence_failures,safe_states_generated:$safe_states,safe_distinct_states:$safe_distinct,safe_depth:$safe_depth,unsafe_expected_counterexamples:$unsafe_expected,patch_slot:"0014",expected_existing_probe_symbols:24,expected_added_probe_symbols:27,expected_total_probe_symbols:51,linux_patch_may_be_drafted:true,behavior_patch_approved:false,hot_field_approved:false,protection_claim:false}' \
	> "$OUT_DIR/result.json"
cat "$OUT_DIR/result.json"
