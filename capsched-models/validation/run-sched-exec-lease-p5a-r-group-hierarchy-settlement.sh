#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
LINUX_DIR="$WORKSPACE_DIR/linux"
CONFIG="$CAPSCHED_DIR/capsched-models/analysis/sched-exec-lease-p5a-r-group-hierarchy-settlement-v1.json"
MODEL_DIR="$CAPSCHED_DIR/capsched-models/formal/0106-p5a-r-group-hierarchy-settlement-model"
MODEL="P5ARGroupHierarchySettlement.tla"
TLA_JAR=${TLA_JAR:-/home/nia/tools/tla/tla2tools.jar}
RUN_ID=${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
OUT_DIR="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r-group-hierarchy-settlement/$RUN_ID"

mkdir -p "$OUT_DIR"

for cmd in git jq awk java grep sed find wc sha256sum; do
	if ! command -v "$cmd" >/dev/null 2>&1; then
		echo "missing command: $cmd" >&2
		exit 1
	fi
done

if [ ! -f "$TLA_JAR" ]; then
	echo "missing TLA jar: $TLA_JAR" >&2
	exit 1
fi

jq empty "$CONFIG"

expected_linux_commit=$(jq -r '.source_basis.linux_commit' "$CONFIG")
actual_linux_commit=$(git -C "$LINUX_DIR" rev-parse HEAD)
if [ "$actual_linux_commit" != "$expected_linux_commit" ]; then
	echo "linux commit mismatch: expected=$expected_linux_commit actual=$actual_linux_commit" >&2
	exit 1
fi

jq -e '
	.scope.linux_patch_approved == false and
	.scope.behavior_change_approved == false and
	.scope.runtime_denial_approved == false and
	.scope.cfs_deny_and_repick_approved == false and
	.scope.group_hierarchy_implementation_approved == false and
	(.required_state_distinctions | length == 5) and
	all(.required_invariants[]; . == true) and
	all(.required_checks[]; . == true) and
	all(.safety_flags[]; . == false) and
	(.rejected_design_families | length >= 12) and
	(.formal.safe_passed == true) and
	(.formal.unsafe_cfg_count == 13) and
	(.formal.unsafe_expected_counterexamples == 13)
' "$CONFIG" >/dev/null

anchors="$OUT_DIR/source-anchors.tsv"
printf 'id\tpath\texpected_line\tactual_line\tline_status\n' > "$anchors"
anchor_count=0
line_drift=0
missing_anchor=0

while IFS=$'\t' read -r id path symbol expected_line pattern; do
	anchor_count=$((anchor_count + 1))
	file="$WORKSPACE_DIR/$path"
	actual_line=""
	if [ -f "$file" ]; then
		start_line=$(awk -v sym="$symbol" 'index($0, sym) { print NR; found=1; exit } END { if (!found) exit 1 }' "$file" || true)
		if [ -n "$start_line" ]; then
			actual_line=$(awk -v start="$start_line" -v pat="$pattern" 'NR >= start && index($0, pat) { print NR; found=1; exit } END { if (!found) exit 1 }' "$file" || true)
		else
			actual_line=$(awk -v pat="$pattern" 'index($0, pat) { print NR; found=1; exit } END { if (!found) exit 1 }' "$file" || true)
		fi
	fi
	if [ -z "$actual_line" ]; then
		status=missing
		missing_anchor=$((missing_anchor + 1))
	elif [ "$actual_line" = "$expected_line" ]; then
		status=ok
	else
		status=line_drift
		line_drift=$((line_drift + 1))
	fi
	printf '%s\t%s\t%s\t%s\t%s\n' "$id" "$path" "$expected_line" "${actual_line:-missing}" "$status" >> "$anchors"
done < <(jq -r '.source_anchors[] | [.id, .path, .symbol, (.expected_line | tostring), .pattern] | @tsv' "$CONFIG")

if [ "$missing_anchor" -ne 0 ]; then
	echo "missing source anchors: $missing_anchor" >&2
	cat "$anchors" >&2
	exit 1
fi

fair_c="$LINUX_DIR/kernel/sched/fair.c"
sched_h="$LINUX_DIR/kernel/sched/sched.h"
core_c="$LINUX_DIR/kernel/sched/core.c"
blockers="$OUT_DIR/blockers.tsv"
printf 'kind\tdetail\n' > "$blockers"

line_of_first() {
	local file=$1
	local pattern=$2
	awk -v pat="$pattern" 'index($0, pat) { print NR; exit }' "$file"
}

l_pick_task=$(line_of_first "$fair_c" 'struct task_struct *pick_task_fair(struct rq *rq, struct rq_flags *rf)')
l_root=$(awk -v start="$l_pick_task" 'NR >= start && index($0, "cfs_rq = &rq->cfs;") { print NR; exit }' "$fair_c")
l_do=$(awk -v start="$l_pick_task" 'NR >= start && index($0, "do {") { print NR; exit }' "$fair_c")
l_pick_next=$(awk -v start="$l_pick_task" 'NR >= start && index($0, "se = pick_next_entity(rq, cfs_rq, true);") { print NR; exit }' "$fair_c")
l_null_retry=$(awk -v start="$l_pick_task" 'NR >= start && index($0, "if (!se)") { print NR; exit }' "$fair_c")
l_group=$(awk -v start="$l_pick_task" 'NR >= start && index($0, "cfs_rq = group_cfs_rq(se);") { print NR; exit }' "$fair_c")
l_while=$(awk -v start="$l_pick_task" 'NR >= start && index($0, "} while (cfs_rq);") { print NR; exit }' "$fair_c")
l_task_of=$(awk -v start="$l_pick_task" 'NR >= start && index($0, "p = task_of(se);") { print NR; exit }' "$fair_c")
l_entity_is_task=$(line_of_first "$sched_h" '#define entity_is_task(se)')
l_task_of_symbol=$(line_of_first "$sched_h" 'static inline struct task_struct *task_of(struct sched_entity *se)')
l_task_of_warn=$(awk -v start="$l_task_of_symbol" 'NR >= start && index($0, "WARN_ON_ONCE(!entity_is_task(se));") { print NR; exit }' "$sched_h")
l_group_symbol=$(line_of_first "$sched_h" 'static inline struct cfs_rq *group_cfs_rq(struct sched_entity *grp)')
l_group_return=$(awk -v start="$l_group_symbol" 'NR >= start && index($0, "return grp->my_q;") { print NR; exit }' "$sched_h")
l_pick_next_entity=$(line_of_first "$fair_c" 'pick_next_entity(struct rq *rq, struct cfs_rq *cfs_rq, bool protect)')
l_delayed_dequeue=$(awk -v start="$l_pick_next_entity" 'NR >= start && index($0, "dequeue_entities(rq, se, DEQUEUE_SLEEP | DEQUEUE_DELAYED);") { print NR; exit }' "$fair_c")
l_core_pick=$(line_of_first "$core_c" 'p = pick_task_fair(rq, rf);')
l_core_settle=$(awk -v start="$l_core_pick" 'NR > start && index($0, "put_prev_set_next_task(rq, rq->donor, p);") { print NR; exit }' "$core_c")
l_set_next_task=$(line_of_first "$fair_c" 'static void set_next_task_fair(struct rq *rq, struct task_struct *p, bool first)')
l_ancestor_walk=$(awk -v start="$l_set_next_task" 'NR >= start && index($0, "for_each_sched_entity(se) {") { print NR; exit }' "$fair_c")
l_set_next_entity=$(line_of_first "$fair_c" 'set_next_entity(struct cfs_rq *cfs_rq, struct sched_entity *se, bool first)')
l_curr_write=$(awk -v start="$l_set_next_entity" 'NR >= start && index($0, "cfs_rq->curr = se;") { print NR; exit }' "$fair_c")

missing_semantic=0
for v in l_pick_task l_root l_do l_pick_next l_null_retry l_group l_while l_task_of \
	l_entity_is_task l_task_of_symbol l_task_of_warn l_group_symbol l_group_return \
	l_pick_next_entity l_delayed_dequeue l_core_pick l_core_settle \
	l_set_next_task l_ancestor_walk l_set_next_entity l_curr_write; do
	if [ -z "${!v:-}" ]; then
		echo -e "semantic\tmissing $v" >> "$blockers"
		missing_semantic=$((missing_semantic + 1))
	fi
done

order_ok=1
if [ "$missing_semantic" -eq 0 ]; then
	if ! [ "$l_pick_task" -lt "$l_root" ] ||
	   ! [ "$l_root" -lt "$l_do" ] ||
	   ! [ "$l_do" -lt "$l_pick_next" ] ||
	   ! [ "$l_pick_next" -lt "$l_null_retry" ] ||
	   ! [ "$l_null_retry" -lt "$l_group" ] ||
	   ! [ "$l_group" -lt "$l_while" ] ||
	   ! [ "$l_while" -lt "$l_task_of" ] ||
	   ! [ "$l_entity_is_task" -lt "$l_task_of_symbol" ] ||
	   ! [ "$l_task_of_symbol" -lt "$l_task_of_warn" ] ||
	   ! [ "$l_group_symbol" -lt "$l_group_return" ] ||
	   ! [ "$l_pick_next_entity" -lt "$l_delayed_dequeue" ] ||
	   ! [ "$l_core_pick" -lt "$l_core_settle" ] ||
	   ! [ "$l_set_next_task" -lt "$l_ancestor_walk" ] ||
	   ! [ "$l_set_next_entity" -lt "$l_curr_write" ]; then
		order_ok=0
		echo -e 'semantic\thierarchy relative order check failed' >> "$blockers"
	fi
else
	order_ok=0
fi

semantic_shape_ok=false
if [ "$missing_semantic" -eq 0 ] && [ "$order_ok" -eq 1 ]; then
	semantic_shape_ok=true
fi

cat > "$OUT_DIR/hierarchy-source-shape.json" <<EOF
{
  "status": "$(if $semantic_shape_ok; then echo passed; else echo failed; fi)",
  "line_drift_count": $line_drift,
  "missing_anchor_count": $missing_anchor,
  "pick_task_fair": {
    "symbol": ${l_pick_task:-0},
    "root_cfs": ${l_root:-0},
    "descent_loop": ${l_do:-0},
    "pick_next_entity": ${l_pick_next:-0},
    "null_retry": ${l_null_retry:-0},
    "group_descent": ${l_group:-0},
    "descent_until_leaf": ${l_while:-0},
    "task_materialization": ${l_task_of:-0}
  },
  "entity_helpers": {
    "entity_is_task": ${l_entity_is_task:-0},
    "task_of_symbol": ${l_task_of_symbol:-0},
    "task_of_warn": ${l_task_of_warn:-0},
    "group_cfs_rq_symbol": ${l_group_symbol:-0},
    "group_cfs_rq_return": ${l_group_return:-0}
  },
  "settlement": {
    "core_pick_task_fair": ${l_core_pick:-0},
    "core_put_prev_set_next_task": ${l_core_settle:-0},
    "set_next_task_fair": ${l_set_next_task:-0},
    "set_next_task_fair_ancestor_walk": ${l_ancestor_walk:-0},
    "set_next_entity": ${l_set_next_entity:-0},
    "cfs_rq_curr_write": ${l_curr_write:-0}
  },
  "relative_order_ok": $(if [ "$order_ok" -eq 1 ]; then echo true; else echo false; fi)
}
EOF

cat > "$OUT_DIR/nonclaim-results.json" <<EOF
{
  "status": "passed",
  "linux_patch_approved": false,
  "behavior_change_approved": false,
  "runtime_denial_approved": false,
  "cfs_deny_and_repick_approved": false,
  "group_hierarchy_implementation_approved": false,
  "runtime_coverage_claim": false,
  "monitor_verified": false,
  "production_protection": false,
  "cost_efficiency_claim": false,
  "datacenter_ready": false
}
EOF

jq empty "$OUT_DIR/hierarchy-source-shape.json" "$OUT_DIR/nonclaim-results.json"

if ! $semantic_shape_ok; then
	echo "group hierarchy source shape failed" >&2
	cat "$blockers" >&2
	exit 1
fi

(
	cd "$MODEL_DIR"
	java -cp "$TLA_JAR" tlc2.TLC -deadlock -metadir "$OUT_DIR/tlc-safe-states" -config P5ARGroupHierarchySettlementSafe.cfg "$MODEL"
) > "$OUT_DIR/tlc-safe.log" 2>&1

if ! grep -q 'Model checking completed. No error has been found.' "$OUT_DIR/tlc-safe.log"; then
	echo "safe TLC model did not pass" >&2
	tail -80 "$OUT_DIR/tlc-safe.log" >&2
	exit 1
fi

state_line=$(sed -n 's/^\([0-9][0-9]*\) states generated, \([0-9][0-9]*\) distinct states found.*/\1 \2/p' "$OUT_DIR/tlc-safe.log" | tail -1)
safe_states=$(printf '%s\n' "$state_line" | awk '{print $1}')
safe_distinct=$(printf '%s\n' "$state_line" | awk '{print $2}')
safe_depth=$(sed -n 's/^The depth of the complete state graph search is \([0-9][0-9]*\).*/\1/p' "$OUT_DIR/tlc-safe.log" | tail -1)

unsafe_expected=0
unsafe_fail=0
for cfg in "$MODEL_DIR"/P5ARGroupHierarchySettlementUnsafe*.cfg; do
	name=$(basename "$cfg" .cfg)
	log="$OUT_DIR/tlc-$name.log"
	if (
		cd "$MODEL_DIR"
		java -cp "$TLA_JAR" tlc2.TLC -deadlock -metadir "$OUT_DIR/tlc-$name-states" -config "$(basename "$cfg")" "$MODEL"
	) > "$log" 2>&1; then
		echo "unsafe config unexpectedly passed: $(basename "$cfg")" >&2
		unsafe_fail=$((unsafe_fail + 1))
	elif grep -q 'Invariant Safety is violated' "$log"; then
		unsafe_expected=$((unsafe_expected + 1))
	else
		echo "unsafe config failed for unexpected reason: $(basename "$cfg")" >&2
		tail -80 "$log" >&2
		unsafe_fail=$((unsafe_fail + 1))
	fi
done

cfg_count=$(find "$MODEL_DIR" -maxdepth 1 -name 'P5ARGroupHierarchySettlementUnsafe*.cfg' | wc -l)
if [ "$unsafe_fail" -ne 0 ] || [ "$unsafe_expected" -ne 13 ] || [ "$cfg_count" -ne 13 ]; then
	echo "unsafe counterexample mismatch: expected=13 actual=$unsafe_expected cfg_count=$cfg_count failures=$unsafe_fail" >&2
	exit 1
fi

cat > "$OUT_DIR/result.json" <<EOF
{
  "run_id": "$RUN_ID",
  "status": "passed",
  "config": "$CONFIG",
  "model_dir": "$MODEL_DIR",
  "linux_commit": "$actual_linux_commit",
  "anchor_count": $anchor_count,
  "missing_anchor_count": $missing_anchor,
  "line_drift_count": $line_drift,
  "semantic_shape_ok": true,
  "safe_passed": true,
  "safe_states_generated": ${safe_states:-0},
  "safe_distinct_states": ${safe_distinct:-0},
  "safe_depth": ${safe_depth:-0},
  "unsafe_expected_counterexamples": $unsafe_expected
}
EOF

cat "$OUT_DIR/result.json"
