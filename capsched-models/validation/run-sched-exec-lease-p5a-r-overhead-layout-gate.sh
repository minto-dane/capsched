#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
LINUX_DIR="$WORKSPACE_DIR/linux"
CONFIG="$CAPSCHED_DIR/capsched-models/analysis/sched-exec-lease-p5a-r-overhead-layout-gate-v1.json"
MODEL_DIR="$CAPSCHED_DIR/capsched-models/formal/0108-p5a-r-overhead-layout-gate-model"
MODEL="P5AROverheadLayoutGate.tla"
TLA_JAR=${TLA_JAR:-/home/nia/tools/tla/tla2tools.jar}
RUN_ID=${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
OUT_DIR="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r-overhead-layout-gate/$RUN_ID"

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
	.scope.hot_layout_change_approved == false and
	.scope.disabled_overhead_change_approved == false and
	.scope.performance_claim_approved == false and
	all(.required_shape[]; . == true) and
	all(.required_checks[]; . == true) and
	all(.safety_flags[]; . == false) and
	(.rejected_design_families | length >= 18) and
	(.formal.safe_passed == true) and
	(.formal.unsafe_cfg_count == 18) and
	(.formal.unsafe_expected_counterexamples == 18)
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

sched_exec_h="$LINUX_DIR/include/linux/sched_exec_lease.h"
core_c="$LINUX_DIR/kernel/sched/core.c"
sched_h="$LINUX_DIR/kernel/sched/sched.h"
fair_c="$LINUX_DIR/kernel/sched/fair.c"
layout_doc="$CAPSCHED_DIR/capsched-models/validation/0158-sched-exec-lease-p5a0-p1-object-layout.md"
blockers="$OUT_DIR/blockers.tsv"
printf 'kind\tdetail\n' > "$blockers"

line_of_first() {
	local file=$1
	local pattern=$2
	awk -v pat="$pattern" 'index($0, pat) { print NR; exit }' "$file"
}

line_after() {
	local file=$1
	local start=$2
	local pattern=$3
	awk -v start="$start" -v pat="$pattern" 'NR >= start && index($0, pat) { print NR; exit }' "$file"
}

l_enabled=$(line_of_first "$sched_exec_h" 'static inline bool sched_exec_lease_enabled(void)')
l_is_enabled=$(line_after "$sched_exec_h" "$l_enabled" 'return IS_ENABLED(CONFIG_SCHED_EXEC_LEASE);')
l_run_helper=$(line_of_first "$sched_exec_h" 'sched_exec_lease_validate_run_edge(struct task_struct *prev,')
l_run_allow=$(line_after "$sched_exec_h" "$l_run_helper" 'return SCHED_EXEC_VALIDATION_ALLOW;')
l_move_helper=$(line_of_first "$sched_exec_h" 'sched_exec_lease_validate_move_edge(struct task_struct *p, int dest_cpu)')
l_move_allow=$(line_after "$sched_exec_h" "$l_move_helper" 'return SCHED_EXEC_VALIDATION_ALLOW;')
l_move_locked_helper=$(line_of_first "$sched_exec_h" 'sched_exec_lease_validate_move_edge_locked(struct task_struct *p, int dest_cpu)')
l_move_locked_allow=$(line_after "$sched_exec_h" "$l_move_locked_helper" 'return SCHED_EXEC_VALIDATION_ALLOW;')
l_task_layout=$(line_of_first "$sched_exec_h" 'struct sched_exec_task {')
l_task_field_gate=$(line_of_first "$LINUX_DIR/include/linux/sched.h" '#ifdef CONFIG_SCHED_EXEC_LEASE')
l_task_field=$(line_after "$LINUX_DIR/include/linux/sched.h" "$l_task_field_gate" 'struct sched_exec_task')
l_run_call=$(line_of_first "$core_c" '(void)sched_exec_lease_validate_run_edge(prev, next);')
l_move_call=$(line_of_first "$core_c" '(void)sched_exec_lease_validate_move_edge(p, new_cpu);')
l_locked_move_call=$(line_of_first "$sched_h" '(void)sched_exec_lease_validate_move_edge_locked(task, dst_rq->cpu);')
l_sched_entity=$(line_of_first "$LINUX_DIR/include/linux/sched.h" 'struct sched_entity {')
l_cfs_rq=$(line_of_first "$sched_h" 'struct cfs_rq {')
l_rq=$(line_of_first "$sched_h" 'struct rq {')
l_rq_hot=$(line_after "$sched_h" "$l_rq" 'extremely hot loop')
l_pick_task_fair=$(line_of_first "$fair_c" 'struct task_struct *pick_task_fair(struct rq *rq, struct rq_flags *rf)')
l_pick_eevdf=$(line_of_first "$fair_c" 'static struct sched_entity *pick_eevdf(struct cfs_rq *cfs_rq, bool protect)')
l_eevdf_single=$(line_after "$fair_c" "$l_pick_eevdf" 'if (cfs_rq->nr_queued == 1)')
l_eevdf_heap=$(line_after "$fair_c" "$l_pick_eevdf" 'while (node) {')
l_prior_core_equal=$(line_of_first "$layout_doc" 'core_function_size_table_equal=true')
l_prior_off_absent=$(line_of_first "$layout_doc" 'sched_exec field is absent from task_struct.')
l_prior_no_new_layout=$(line_of_first "$layout_doc" 'P2 task shadow layout remains as expected')

missing_semantic=0
for v in l_enabled l_is_enabled l_run_helper l_run_allow l_move_helper l_move_allow \
	l_move_locked_helper l_move_locked_allow l_task_layout l_task_field_gate \
	l_task_field l_run_call l_move_call l_locked_move_call l_sched_entity \
	l_cfs_rq l_rq l_rq_hot l_pick_task_fair l_pick_eevdf l_eevdf_single \
	l_eevdf_heap l_prior_core_equal l_prior_off_absent l_prior_no_new_layout; do
	if [ -z "${!v:-}" ]; then
		echo -e "semantic\tmissing $v" >> "$blockers"
		missing_semantic=$((missing_semantic + 1))
	fi
done

allow_return_count=$(awk 'index($0, "return SCHED_EXEC_VALIDATION_ALLOW;") { c++ } END { print c + 0 }' "$sched_exec_h")
non_allow_return_count=$(awk '/return SCHED_EXEC_VALIDATION_(RETRY|INELIGIBLE|QUARANTINE)/ { c++ } END { print c + 0 }' "$sched_exec_h")
branch_matches=$(grep -R -nE 'if[[:space:]]*\(.*sched_exec_lease_validate|switch[[:space:]]*\(.*sched_exec_lease_validate|SCHED_EXEC_VALIDATION_(RETRY|INELIGIBLE|QUARANTINE)' "$LINUX_DIR/kernel/sched" 2>/dev/null || true)
branch_on_validation_count=$(printf '%s\n' "$branch_matches" | sed '/^$/d' | wc -l)

order_ok=1
if [ "$missing_semantic" -eq 0 ]; then
	if ! [ "$l_enabled" -lt "$l_is_enabled" ] ||
	   ! [ "$l_run_helper" -lt "$l_run_allow" ] ||
	   ! [ "$l_move_helper" -lt "$l_move_allow" ] ||
	   ! [ "$l_move_locked_helper" -lt "$l_move_locked_allow" ] ||
	   ! [ "$l_task_field_gate" -lt "$l_task_field" ] ||
	   ! [ "$l_rq" -lt "$l_rq_hot" ] ||
	   ! [ "$l_pick_eevdf" -lt "$l_eevdf_single" ] ||
	   ! [ "$l_eevdf_single" -lt "$l_eevdf_heap" ]; then
		order_ok=0
		echo -e 'semantic\toverhead/layout relative order check failed' >> "$blockers"
	fi
else
	order_ok=0
fi

semantic_shape_ok=false
if [ "$missing_semantic" -eq 0 ] &&
   [ "$order_ok" -eq 1 ] &&
   [ "$allow_return_count" -eq 3 ] &&
   [ "$non_allow_return_count" -eq 0 ] &&
   [ "$branch_on_validation_count" -eq 0 ]; then
	semantic_shape_ok=true
else
	echo -e "semantic\tallow_return_count=$allow_return_count non_allow_return_count=$non_allow_return_count branch_on_validation_count=$branch_on_validation_count" >> "$blockers"
fi

cat > "$OUT_DIR/overhead-layout-source-shape.json" <<EOF_JSON
{
  "status": "$(if $semantic_shape_ok; then echo passed; else echo failed; fi)",
  "line_drift_count": $line_drift,
  "missing_anchor_count": $missing_anchor,
  "allow_return_count": $allow_return_count,
  "non_allow_return_count": $non_allow_return_count,
  "branch_on_validation_count": $branch_on_validation_count,
  "current_scaffold": {
    "sched_exec_lease_enabled": ${l_enabled:-0},
    "sched_exec_lease_enabled_is_enabled": ${l_is_enabled:-0},
    "run_helper": ${l_run_helper:-0},
    "run_allow": ${l_run_allow:-0},
    "move_helper": ${l_move_helper:-0},
    "move_allow": ${l_move_allow:-0},
    "move_locked_helper": ${l_move_locked_helper:-0},
    "move_locked_allow": ${l_move_locked_allow:-0},
    "task_layout": ${l_task_layout:-0},
    "task_field_gate": ${l_task_field_gate:-0},
    "task_field": ${l_task_field:-0}
  },
  "current_call_sites": {
    "run_edge": ${l_run_call:-0},
    "common_move": ${l_move_call:-0},
    "locked_move": ${l_locked_move_call:-0}
  },
  "hot_structures": {
    "sched_entity": ${l_sched_entity:-0},
    "cfs_rq": ${l_cfs_rq:-0},
    "rq": ${l_rq:-0},
    "rq_hot_loop_comment": ${l_rq_hot:-0}
  },
  "cfs_picker": {
    "pick_task_fair": ${l_pick_task_fair:-0},
    "pick_eevdf": ${l_pick_eevdf:-0},
    "single_entity_shortcut": ${l_eevdf_single:-0},
    "heap_search_shape": ${l_eevdf_heap:-0}
  },
  "prior_layout_evidence": {
    "core_function_size_table_equal": ${l_prior_core_equal:-0},
    "disabled_task_field_absent": ${l_prior_off_absent:-0},
    "no_new_hot_layout": ${l_prior_no_new_layout:-0}
  },
  "relative_order_ok": $(if [ "$order_ok" -eq 1 ]; then echo true; else echo false; fi)
}
EOF_JSON

cat > "$OUT_DIR/nonclaim-results.json" <<EOF_JSON
{
  "status": "passed",
  "linux_patch_approved": false,
  "behavior_change_approved": false,
  "runtime_denial_approved": false,
  "cfs_deny_and_repick_approved": false,
  "hot_layout_change_approved": false,
  "disabled_overhead_change_approved": false,
  "runtime_coverage_claim": false,
  "benchmark_claim": false,
  "monitor_verified": false,
  "production_protection": false,
  "cost_efficiency_claim": false,
  "datacenter_ready": false
}
EOF_JSON

jq empty "$OUT_DIR/overhead-layout-source-shape.json" "$OUT_DIR/nonclaim-results.json"

if ! $semantic_shape_ok; then
	echo "overhead/layout source shape failed" >&2
	cat "$blockers" >&2
	exit 1
fi

(
	cd "$MODEL_DIR"
	java -cp "$TLA_JAR" tlc2.TLC -deadlock -metadir "$OUT_DIR/tlc-safe-states" -config P5AROverheadLayoutGateSafe.cfg "$MODEL"
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
for cfg in "$MODEL_DIR"/P5AROverheadLayoutGateUnsafe*.cfg; do
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

cfg_count=$(find "$MODEL_DIR" -maxdepth 1 -name 'P5AROverheadLayoutGateUnsafe*.cfg' | wc -l)
if [ "$unsafe_fail" -ne 0 ] || [ "$unsafe_expected" -ne 18 ] || [ "$cfg_count" -ne 18 ]; then
	echo "unsafe counterexample mismatch: expected=18 actual=$unsafe_expected cfg_count=$cfg_count failures=$unsafe_fail" >&2
	exit 1
fi

cat > "$OUT_DIR/result.json" <<EOF_JSON
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
  "allow_return_count": $allow_return_count,
  "non_allow_return_count": $non_allow_return_count,
  "branch_on_validation_count": $branch_on_validation_count,
  "safe_passed": true,
  "safe_states_generated": ${safe_states:-0},
  "safe_distinct_states": ${safe_distinct:-0},
  "safe_depth": ${safe_depth:-0},
  "unsafe_expected_counterexamples": $unsafe_expected
}
EOF_JSON

jq empty "$OUT_DIR/result.json"
cat "$OUT_DIR/result.json"
