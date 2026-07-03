#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
LINUX_DIR="$WORKSPACE_DIR/linux"
CONFIG="$CAPSCHED_DIR/capsched-models/analysis/sched-exec-lease-p5a-r-eevdf-return-dominance-v1.json"
MODEL_DIR="$CAPSCHED_DIR/capsched-models/formal/0105-p5a-r-eevdf-return-dominance-model"
MODEL="P5AREevdfReturnDominance.tla"
TLA_JAR=${TLA_JAR:-/home/nia/tools/tla/tla2tools.jar}
RUN_ID=${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
OUT_DIR="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r-eevdf-return-dominance/$RUN_ID"

mkdir -p "$OUT_DIR"

for cmd in git jq awk java grep sed find wc; do
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
	.scope.group_hierarchy_settlement_approved == false and
	all(.required_checks[]; . == true) and
	all(.safety_flags[]; . == false) and
	(.source_shape.pick_eevdf_direct_return_count == 4) and
	(.source_shape.pick_eevdf_semantic_candidate_families == 6) and
	(.source_shape.required_direct_returns | length == 4) and
	(.source_shape.required_indirect_funnel_paths | length == 3) and
	(.source_shape.forbidden_scan_patterns_for_future_denial | length >= 8) and
	(.runner_outputs | length == 8) and
	(.formal.safe_passed == true) and
	(.formal.unsafe_cfg_count == 11) and
	(.formal.unsafe_expected_counterexamples == 11) and
	(.allowed_claims | length == 2) and
	(.supported_configs | length >= 1) and
	(.excluded_paths | length >= 5) and
	(.rejected_design_implications | length >= 8)
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
shape_json="$OUT_DIR/return-dominance.json"
source_units="$OUT_DIR/semantic-source-units.json"
contexts_json="$OUT_DIR/callgraph-contexts.json"
blockers="$OUT_DIR/blockers.tsv"
printf 'kind\tdetail\n' > "$blockers"

awk '
	/static struct sched_entity \*pick_eevdf\(struct cfs_rq \*cfs_rq, bool protect\)/ { in_fn=1; depth=0 }
	in_fn {
		print
		for (i = 1; i <= length($0); i++) {
			ch = substr($0, i, 1)
			if (ch == "{") depth++
			if (ch == "}") depth--
		}
		if (in_fn && depth == 0 && $0 ~ /^}/) exit
	}
' "$fair_c" > "$OUT_DIR/pick_eevdf.body.c"

if [ ! -s "$OUT_DIR/pick_eevdf.body.c" ]; then
	echo -e 'semantic\tpick_eevdf body extraction failed' >> "$blockers"
	echo "failed to extract pick_eevdf body" >&2
	exit 1
fi

return_count=$(grep -c '^[[:space:]]*return ' "$OUT_DIR/pick_eevdf.body.c")
if [ "$return_count" -ne 4 ]; then
	echo -e "semantic\tpick_eevdf direct return count is $return_count, expected 4" >> "$blockers"
fi

line_of_first() {
	local pattern=$1
	awk -v pat="$pattern" 'index($0, pat) { print NR; exit }' "$fair_c"
}

l_symbol=$(line_of_first 'static struct sched_entity *pick_eevdf(struct cfs_rq *cfs_rq, bool protect)')
l_singleton_guard=$(line_of_first 'if (cfs_rq->nr_queued == 1)')
l_singleton_return=$(line_of_first 'return curr && curr->on_rq ? curr : se;')
l_buddy_guard=$(line_of_first 'if (sched_feat(PICK_BUDDY) && protect &&')
l_buddy_return=$(line_of_first 'return cfs_rq->next;')
l_curr_scrub=$(line_of_first 'if (curr && (!curr->on_rq || !entity_eligible(cfs_rq, curr)))')
l_protected_guard=$(line_of_first 'if (curr && protect && protect_slice(curr))')
l_protected_return=$(line_of_first 'return curr;')
l_leftmost_guard=$(line_of_first 'if (se && entity_eligible(cfs_rq, se))')
l_leftmost_best=$(line_of_first 'best = se;')
l_goto_found=$(line_of_first 'goto found;')
l_heap=$(line_of_first 'while (node) {')
l_heap_best=$(awk -v start="$l_heap" 'NR > start && index($0, "best = se;") { print NR; exit }' "$fair_c")
l_heap_break=$(awk -v start="$l_heap" 'NR > start && index($0, "break;") { print NR; exit }' "$fair_c")
l_found=$(line_of_first 'found:')
l_override=$(line_of_first 'if (!best || (curr && entity_before(curr, best)))')
l_final_return=$(line_of_first 'return best;')
l_pick_next_symbol=$(line_of_first 'pick_next_entity(struct rq *rq, struct cfs_rq *cfs_rq, bool protect)')
l_pick_next_call=$(line_of_first 'se = pick_eevdf(cfs_rq, protect);')
l_wakeup_call=$(line_of_first 'nse = pick_next_entity(rq, cfs_rq, preempt_action != PREEMPT_WAKEUP_SHORT);')
l_schedule_call=$(line_of_first 'se = pick_next_entity(rq, cfs_rq, true);')
l_group_descent=$(awk -v start="$l_schedule_call" 'NR > start && index($0, "cfs_rq = group_cfs_rq(se);") { print NR; exit }' "$fair_c")
l_task_of=$(awk -v start="$l_schedule_call" 'NR > start && index($0, "p = task_of(se);") { print NR; exit }' "$fair_c")

missing_semantic=0
for v in l_symbol l_singleton_guard l_singleton_return l_buddy_guard l_buddy_return \
	l_curr_scrub l_protected_guard l_protected_return l_leftmost_guard l_leftmost_best \
	l_goto_found l_heap l_heap_best l_heap_break l_found l_override l_final_return \
	l_pick_next_symbol l_pick_next_call l_wakeup_call l_schedule_call l_group_descent l_task_of; do
	if [ -z "${!v:-}" ]; then
		echo -e "semantic\tmissing $v" >> "$blockers"
		missing_semantic=$((missing_semantic + 1))
	fi
done

order_ok=1
if [ "$missing_semantic" -eq 0 ]; then
	if ! [ "$l_symbol" -lt "$l_singleton_guard" ] ||
	   ! [ "$l_singleton_guard" -lt "$l_singleton_return" ] ||
	   ! [ "$l_singleton_return" -lt "$l_buddy_guard" ] ||
	   ! [ "$l_buddy_guard" -lt "$l_buddy_return" ] ||
	   ! [ "$l_buddy_return" -lt "$l_curr_scrub" ] ||
	   ! [ "$l_curr_scrub" -lt "$l_protected_guard" ] ||
	   ! [ "$l_protected_guard" -lt "$l_protected_return" ] ||
	   ! [ "$l_protected_return" -lt "$l_leftmost_guard" ] ||
	   ! [ "$l_leftmost_guard" -lt "$l_goto_found" ] ||
	   ! [ "$l_goto_found" -lt "$l_heap" ] ||
	   ! [ "$l_heap" -lt "$l_heap_best" ] ||
	   ! [ "$l_heap_best" -lt "$l_heap_break" ] ||
	   ! [ "$l_heap_break" -lt "$l_found" ] ||
	   ! [ "$l_found" -lt "$l_override" ] ||
	   ! [ "$l_override" -lt "$l_final_return" ] ||
	   ! [ "$l_pick_next_symbol" -lt "$l_pick_next_call" ] ||
	   ! [ "$l_wakeup_call" -lt "$l_schedule_call" ] ||
	   ! [ "$l_schedule_call" -lt "$l_group_descent" ] ||
	   ! [ "$l_group_descent" -lt "$l_task_of" ]; then
		order_ok=0
		echo -e 'semantic\trelative order check failed' >> "$blockers"
	fi
else
	order_ok=0
fi

direct_returns_ok=false
if [ "$return_count" -eq 4 ] && [ "$missing_semantic" -eq 0 ] && [ "$order_ok" -eq 1 ]; then
	direct_returns_ok=true
fi

body_hash=$(sed 's/[[:space:]]\+/ /g; s/^ //; s/ $//' "$OUT_DIR/pick_eevdf.body.c" | sha256sum | awk '{print $1}')
cfg_hash=$(grep -nE '^[[:space:]]*(if|while|goto|return|break;|continue;|found:)' "$OUT_DIR/pick_eevdf.body.c" | sha256sum | awk '{print $1}')

forbidden_scan_count=0
for pat in 'rb_next' 'rb_first' 'list_for_each' 'for_each_leaf_cfs_rq' 'for_each_sched_entity'; do
	if grep -q "$pat" "$OUT_DIR/pick_eevdf.body.c"; then
		forbidden_scan_count=$((forbidden_scan_count + 1))
		echo -e "semantic\tforbidden future-denial scan primitive in pick_eevdf body: $pat" >> "$blockers"
	fi
done

cat > "$source_units" <<EOF
{
  "linux_commit": "$actual_linux_commit",
  "units": [
    {
      "symbol": "pick_eevdf",
      "path": "linux/kernel/sched/fair.c",
      "start_line": ${l_symbol:-0},
      "direct_return_count": $return_count,
      "normalized_body_hash": "$body_hash",
      "cfg_hash": "$cfg_hash",
      "semantic_shape_ok": $direct_returns_ok
    }
  ]
}
EOF

cat > "$shape_json" <<EOF
{
  "status": "$(if $direct_returns_ok; then echo passed; else echo failed; fi)",
  "direct_return_count": $return_count,
  "expected_direct_return_count": 4,
  "line_drift_count": $line_drift,
  "missing_anchor_count": $missing_anchor,
  "forbidden_scan_count": $forbidden_scan_count,
  "return_sites": {
    "singleton": ${l_singleton_return:-0},
    "next_buddy": ${l_buddy_return:-0},
    "protected_current": ${l_protected_return:-0},
    "final_best_funnel": ${l_final_return:-0}
  },
  "funnel_paths": {
    "leftmost_goto_found": ${l_goto_found:-0},
    "heap_best_break": ${l_heap_break:-0},
    "found_label": ${l_found:-0},
    "final_current_override": ${l_override:-0}
  },
  "relative_order_ok": $(if [ "$order_ok" -eq 1 ]; then echo true; else echo false; fi)
}
EOF

cat > "$contexts_json" <<EOF
{
  "status": "$(if [ "$missing_semantic" -eq 0 ] && [ "$order_ok" -eq 1 ]; then echo passed; else echo failed; fi)",
  "call_contexts": {
    "wakeup_preempt_pick_next_entity_call": ${l_wakeup_call:-0},
    "schedule_pick_task_fair_call": ${l_schedule_call:-0},
    "group_descent": ${l_group_descent:-0},
    "task_materialization": ${l_task_of:-0}
  },
  "wakeup_before_schedule_pick": $(if [ -n "${l_wakeup_call:-}" ] && [ -n "${l_schedule_call:-}" ] && [ "$l_wakeup_call" -lt "$l_schedule_call" ]; then echo true; else echo false; fi),
  "hierarchy_descent_before_task_of": $(if [ -n "${l_group_descent:-}" ] && [ -n "${l_task_of:-}" ] && [ "$l_group_descent" -lt "$l_task_of" ]; then echo true; else echo false; fi)
}
EOF

cat > "$OUT_DIR/drift-results.json" <<EOF
{
  "status": "$(if [ "$missing_anchor" -eq 0 ] && [ "$return_count" -eq 4 ] && [ "$forbidden_scan_count" -eq 0 ]; then echo passed; else echo failed; fi)",
  "line_drift_count": $line_drift,
  "missing_anchor_count": $missing_anchor,
  "semantic_return_count": $return_count,
  "forbidden_scan_count": $forbidden_scan_count,
  "line_drift_blocks_behavior_patch": false,
  "semantic_drift_blocks_behavior_patch": true
}
EOF

cat > "$OUT_DIR/nonclaim-results.json" <<EOF
{
  "status": "passed",
  "linux_patch_approved": false,
  "behavior_change_approved": false,
  "runtime_denial_approved": false,
  "cfs_deny_and_repick_approved": false,
  "group_hierarchy_settlement_approved": false,
  "runtime_coverage_claim": false,
  "monitor_verified": false,
  "production_protection": false,
  "cost_efficiency_claim": false,
  "datacenter_ready": false
}
EOF

cat > "$OUT_DIR/summary.env" <<EOF
RUN_ID=$RUN_ID
STATUS=pending
LINUX_COMMIT=$actual_linux_commit
ANCHOR_COUNT=$anchor_count
LINE_DRIFT_COUNT=$line_drift
MISSING_ANCHOR_COUNT=$missing_anchor
PICK_EEVDF_DIRECT_RETURN_COUNT=$return_count
FORBIDDEN_SCAN_COUNT=$forbidden_scan_count
EOF

jq empty "$source_units" "$shape_json" "$contexts_json" "$OUT_DIR/drift-results.json" "$OUT_DIR/nonclaim-results.json"

if ! $direct_returns_ok || [ "$forbidden_scan_count" -ne 0 ]; then
	echo "EEVDF return dominance source shape failed" >&2
	cat "$blockers" >&2
	exit 1
fi

(
	cd "$MODEL_DIR"
	java -cp "$TLA_JAR" tlc2.TLC -deadlock -metadir "$OUT_DIR/tlc-safe-states" -config P5AREevdfReturnDominanceSafe.cfg "$MODEL"
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
for cfg in "$MODEL_DIR"/P5AREevdfReturnDominanceUnsafe*.cfg; do
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

cfg_count=$(find "$MODEL_DIR" -maxdepth 1 -name 'P5AREevdfReturnDominanceUnsafe*.cfg' | wc -l)
if [ "$unsafe_fail" -ne 0 ] || [ "$unsafe_expected" -ne 11 ] || [ "$cfg_count" -ne 11 ]; then
	echo "unsafe counterexample mismatch: expected=11 actual=$unsafe_expected cfg_count=$cfg_count failures=$unsafe_fail" >&2
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
  "pick_eevdf_direct_return_count": $return_count,
  "pick_eevdf_semantic_candidate_families": 6,
  "forbidden_scan_count": $forbidden_scan_count,
  "semantic_shape_ok": true,
  "safe_passed": true,
  "safe_states_generated": ${safe_states:-0},
  "safe_distinct_states": ${safe_distinct:-0},
  "safe_depth": ${safe_depth:-0},
  "unsafe_expected_counterexamples": $unsafe_expected
}
EOF

sed -i 's/^STATUS=pending$/STATUS=passed/' "$OUT_DIR/summary.env"

cat "$OUT_DIR/result.json"
