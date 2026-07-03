#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
LINUX_DIR="$WORKSPACE_DIR/linux"
CONFIG="$CAPSCHED_DIR/capsched-models/analysis/sched-exec-lease-p5a-r-cross-path-exclusion-settlement-v1.json"
MODEL_DIR="$CAPSCHED_DIR/capsched-models/formal/0107-p5a-r-cross-path-exclusion-settlement-model"
MODEL="P5ARCrossPathExclusionSettlement.tla"
TLA_JAR=${TLA_JAR:-/home/nia/tools/tla/tla2tools.jar}
RUN_ID=${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
OUT_DIR="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r-cross-path-exclusion-settlement/$RUN_ID"

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
	.scope.ordinary_cfs_only == true and
	.scope.linux_patch_approved == false and
	.scope.behavior_change_approved == false and
	.scope.runtime_denial_approved == false and
	.scope.cfs_deny_and_repick_approved == false and
	.scope.cross_path_behavior_patch_approved == false and
	.scope.core_settlement_approved == false and
	.scope.deadline_server_settlement_approved == false and
	.scope.proxy_settlement_approved == false and
	.scope.sched_ext_settlement_approved == false and
	(.required_state_distinctions | length >= 14) and
	all(.required_invariants[]; . == true) and
	all(.required_checks[]; . == true) and
	all(.safety_flags[]; . == false) and
	(.rejected_design_families | length >= 15) and
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

core_c="$LINUX_DIR/kernel/sched/core.c"
sched_h="$LINUX_DIR/kernel/sched/sched.h"
fair_c="$LINUX_DIR/kernel/sched/fair.c"
deadline_c="$LINUX_DIR/kernel/sched/deadline.c"
ext_c="$LINUX_DIR/kernel/sched/ext/ext.c"
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

l_pick_next_plain=$(line_of_first "$core_c" '__pick_next_task(struct rq')
l_scx_gate=$(line_after "$core_c" "$l_pick_next_plain" 'if (scx_enabled())')
l_fair_fastpath=$(line_after "$core_c" "$l_pick_next_plain" 'p = pick_task_fair(rq, rf);')
l_fair_settle=$(line_after "$core_c" "$l_fair_fastpath" 'put_prev_set_next_task(rq, rq->donor, p);')
l_class_loop=$(line_after "$core_c" "$l_pick_next_plain" 'for_each_active_class(class)')
l_class_pick=$(line_after "$core_c" "$l_class_loop" 'p = class->pick_task(rq, rf);')

l_sched_core_helper=$(line_of_first "$sched_h" 'static inline bool sched_core_enabled(struct rq *rq)')
l_pick_next_core=$(awk '/^[[:space:]]*pick_next_task\(struct rq \*rq, struct rq_flags \*rf\)/ { print NR; exit }' "$core_c")
l_core_disabled=$(line_after "$core_c" "$l_pick_next_core" 'if (!sched_core_enabled(rq))')
l_core_plain_return=$(line_after "$core_c" "$l_core_disabled" 'return __pick_next_task(rq, rf);')
l_core_cached_seq=$(line_after "$core_c" "$l_pick_next_core" 'if (rq->core->core_pick_seq == rq->core->core_task_seq &&')
l_core_cached_next=$(line_after "$core_c" "$l_core_cached_seq" 'next = rq->core_pick;')
l_core_sibling_pick=$(line_after "$core_c" "$l_pick_next_core" 'p = pick_task(rq_i, rf);')
l_core_sibling_cache=$(line_after "$core_c" "$l_core_sibling_pick" 'rq_i->core_pick = p;')
l_core_cookie_find=$(line_after "$core_c" "$l_core_sibling_cache" 'p = sched_core_find(rq_i, cookie);')
l_core_cookie_cache=$(line_after "$core_c" "$l_core_cookie_find" 'rq_i->core_pick = p;')
l_core_out_set_next=$(line_after "$core_c" "$l_core_cookie_cache" 'put_prev_set_next_task(rq, rq->donor, next);')
l_sched_core_find=$(line_of_first "$core_c" 'static struct task_struct *sched_core_find(struct rq *rq, unsigned long cookie)')
l_try_steal=$(line_of_first "$core_c" 'static bool try_steal_cookie(int this, int that)')
l_try_steal_find=$(line_after "$core_c" "$l_try_steal" 'p = sched_core_find(src, cookie);')
l_try_steal_move=$(line_after "$core_c" "$l_try_steal" 'move_queued_task_locked(src, dst, p);')

l_dl_server_init=$(line_of_first "$deadline_c" 'void dl_server_init(struct sched_dl_entity *dl_se, struct rq *rq,')
l_dl_server_store=$(line_after "$deadline_c" "$l_dl_server_init" 'dl_se->server_pick_task = pick_task;')
l_pick_task_dl=$(line_of_first "$deadline_c" 'static struct task_struct *__pick_task_dl(struct rq *rq, struct rq_flags *rf)')
l_dl_pick_callback=$(line_after "$deadline_c" "$l_pick_task_dl" 'p = dl_se->server_pick_task(dl_se, rf);')
l_dl_set_server=$(line_after "$deadline_c" "$l_dl_pick_callback" 'rq->dl_server = dl_se;')
l_fair_server=$(line_of_first "$fair_c" 'fair_server_pick_task(struct sched_dl_entity *dl_se, struct rq_flags *rf)')
l_fair_server_returns=$(line_after "$fair_c" "$l_fair_server" 'return pick_task_fair(dl_se->rq, rf);')
l_put_dl_server=$(line_of_first "$sched_h" 'next->dl_server = rq->dl_server;')
l_ext_server=$(line_of_first "$ext_c" 'ext_server_pick_task(struct sched_dl_entity *dl_se, struct rq_flags *rf)')
l_ext_server_returns=$(line_after "$ext_c" "$l_ext_server" 'return do_pick_task_scx(dl_se->rq, rf, true);')

l_find_proxy=$(line_of_first "$core_c" 'find_proxy_task(struct rq *rq, struct task_struct *donor, struct rq_flags *rf)')
l_proxy_guard=$(line_of_first "$core_c" 'if (sched_proxy_exec()) {')
l_proxy_set_donor=$(line_after "$core_c" "$l_proxy_guard" 'rq_set_donor(rq, next);')
l_proxy_rewrite=$(line_after "$core_c" "$l_proxy_set_donor" 'next = find_proxy_task(rq, next, &rf);')
l_proxy_retry=$(line_after "$core_c" "$l_proxy_rewrite" 'goto pick_again;')
l_proxy_keep_resched=$(line_after "$core_c" "$l_proxy_rewrite" 'goto keep_resched;')

l_scx_macro=$(line_of_first "$sched_h" '#define scx_enabled()')
l_next_active=$(line_of_first "$sched_h" 'static inline const struct sched_class *next_active_class')
l_scx_skip_fair=$(line_after "$sched_h" "$l_next_active" 'if (scx_switched_all() && class == &fair_sched_class)')
l_pick_scx=$(line_of_first "$ext_c" 'static struct task_struct *pick_task_scx(struct rq *rq, struct rq_flags *rf)')
l_pick_scx_returns=$(line_after "$ext_c" "$l_pick_scx" 'return do_pick_task_scx(rq, rf, false);')
l_ext_class=$(line_of_first "$ext_c" 'DEFINE_SCHED_CLASS(ext)')
l_ext_class_pick=$(line_after "$ext_c" "$l_ext_class" 'pick_task_scx')

missing_semantic=0
for v in l_pick_next_plain l_scx_gate l_fair_fastpath l_fair_settle l_class_loop l_class_pick \
	l_sched_core_helper l_pick_next_core l_core_disabled l_core_plain_return \
	l_core_cached_seq l_core_cached_next l_core_sibling_pick l_core_sibling_cache \
	l_core_cookie_find l_core_cookie_cache l_core_out_set_next l_sched_core_find \
	l_try_steal l_try_steal_find l_try_steal_move l_dl_server_init l_dl_server_store \
	l_pick_task_dl l_dl_pick_callback l_dl_set_server l_fair_server l_fair_server_returns \
	l_put_dl_server l_ext_server l_ext_server_returns l_find_proxy l_proxy_guard \
	l_proxy_set_donor l_proxy_rewrite l_proxy_retry l_proxy_keep_resched l_scx_macro \
	l_next_active l_scx_skip_fair l_pick_scx l_pick_scx_returns l_ext_class l_ext_class_pick; do
	if [ -z "${!v:-}" ]; then
		echo -e "semantic\tmissing $v" >> "$blockers"
		missing_semantic=$((missing_semantic + 1))
	fi
done

order_ok=1
if [ "$missing_semantic" -eq 0 ]; then
	if ! [ "$l_scx_gate" -lt "$l_fair_fastpath" ] ||
	   ! [ "$l_fair_fastpath" -lt "$l_fair_settle" ] ||
	   ! [ "$l_fair_settle" -lt "$l_class_loop" ] ||
	   ! [ "$l_class_loop" -lt "$l_class_pick" ] ||
	   ! [ "$l_sched_core_helper" -lt "$l_pick_next_core" ] ||
	   ! [ "$l_core_disabled" -lt "$l_core_plain_return" ] ||
	   ! [ "$l_core_plain_return" -lt "$l_core_cached_seq" ] ||
	   ! [ "$l_core_cached_seq" -lt "$l_core_cached_next" ] ||
	   ! [ "$l_core_sibling_pick" -lt "$l_core_sibling_cache" ] ||
	   ! [ "$l_core_sibling_cache" -lt "$l_core_cookie_find" ] ||
	   ! [ "$l_core_cookie_find" -lt "$l_core_cookie_cache" ] ||
	   ! [ "$l_core_cookie_cache" -lt "$l_core_out_set_next" ] ||
	   ! [ "$l_sched_core_find" -lt "$l_pick_next_core" ] ||
	   ! [ "$l_try_steal" -lt "$l_try_steal_find" ] ||
	   ! [ "$l_try_steal_find" -lt "$l_try_steal_move" ] ||
	   ! [ "$l_dl_server_init" -lt "$l_pick_task_dl" ] ||
	   ! [ "$l_dl_pick_callback" -lt "$l_dl_set_server" ] ||
	   ! [ "$l_fair_server" -lt "$l_fair_server_returns" ] ||
	   ! [ "$l_ext_server" -lt "$l_ext_server_returns" ] ||
	   ! [ "$l_find_proxy" -lt "$l_proxy_guard" ] ||
	   ! [ "$l_proxy_guard" -lt "$l_proxy_set_donor" ] ||
	   ! [ "$l_proxy_set_donor" -lt "$l_proxy_rewrite" ] ||
	   ! [ "$l_proxy_rewrite" -lt "$l_proxy_retry" ] ||
	   ! [ "$l_proxy_rewrite" -lt "$l_proxy_keep_resched" ] ||
	   ! [ "$l_scx_macro" -lt "$l_next_active" ] ||
	   ! [ "$l_next_active" -lt "$l_scx_skip_fair" ] ||
	   ! [ "$l_pick_scx" -lt "$l_pick_scx_returns" ] ||
	   ! [ "$l_ext_class" -lt "$l_ext_class_pick" ]; then
		order_ok=0
		echo -e 'semantic\tcross-path relative order check failed' >> "$blockers"
	fi
else
	order_ok=0
fi

semantic_shape_ok=false
if [ "$missing_semantic" -eq 0 ] && [ "$order_ok" -eq 1 ]; then
	semantic_shape_ok=true
fi

cat > "$OUT_DIR/cross-path-source-shape.json" <<EOF_JSON
{
  "status": "$(if $semantic_shape_ok; then echo passed; else echo failed; fi)",
  "line_drift_count": $line_drift,
  "missing_anchor_count": $missing_anchor,
  "ordinary_cfs_fastpath": {
    "scx_gate": ${l_scx_gate:-0},
    "pick_task_fair": ${l_fair_fastpath:-0},
    "put_prev_set_next_task": ${l_fair_settle:-0},
    "class_loop": ${l_class_loop:-0},
    "class_pick_task": ${l_class_pick:-0}
  },
  "core_scheduling": {
    "sched_core_enabled_helper": ${l_sched_core_helper:-0},
    "pick_next_task": ${l_pick_next_core:-0},
    "disabled_returns_plain_pick": ${l_core_plain_return:-0},
    "cached_pick_seq": ${l_core_cached_seq:-0},
    "cached_pick_next": ${l_core_cached_next:-0},
    "sibling_pick": ${l_core_sibling_pick:-0},
    "sibling_cache": ${l_core_sibling_cache:-0},
    "cookie_replacement_find": ${l_core_cookie_find:-0},
    "cookie_replacement_cache": ${l_core_cookie_cache:-0},
    "out_set_next": ${l_core_out_set_next:-0},
    "sched_core_find": ${l_sched_core_find:-0},
    "try_steal_cookie": ${l_try_steal:-0},
    "try_steal_find": ${l_try_steal_find:-0},
    "try_steal_move": ${l_try_steal_move:-0}
  },
  "deadline_servers": {
    "dl_server_init": ${l_dl_server_init:-0},
    "server_pick_task_store": ${l_dl_server_store:-0},
    "pick_task_dl": ${l_pick_task_dl:-0},
    "server_callback": ${l_dl_pick_callback:-0},
    "rq_dl_server_set": ${l_dl_set_server:-0},
    "fair_server": ${l_fair_server:-0},
    "fair_server_pick_task_fair": ${l_fair_server_returns:-0},
    "next_dl_server_copy": ${l_put_dl_server:-0},
    "ext_server": ${l_ext_server:-0},
    "ext_server_force_scx": ${l_ext_server_returns:-0}
  },
  "proxy_execution": {
    "find_proxy_task": ${l_find_proxy:-0},
    "sched_proxy_exec_guard": ${l_proxy_guard:-0},
    "set_donor": ${l_proxy_set_donor:-0},
    "rewrite_next": ${l_proxy_rewrite:-0},
    "retry_path": ${l_proxy_retry:-0},
    "keep_resched_path": ${l_proxy_keep_resched:-0}
  },
  "sched_ext": {
    "scx_enabled_macro": ${l_scx_macro:-0},
    "next_active_class": ${l_next_active:-0},
    "switched_all_skips_fair": ${l_scx_skip_fair:-0},
    "pick_task_scx": ${l_pick_scx:-0},
    "pick_task_scx_returns_do_pick": ${l_pick_scx_returns:-0},
    "ext_sched_class": ${l_ext_class:-0},
    "ext_sched_class_pick_task": ${l_ext_class_pick:-0}
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
  "cross_path_behavior_patch_approved": false,
  "runtime_coverage_claim": false,
  "monitor_verified": false,
  "production_protection": false,
  "cost_efficiency_claim": false,
  "datacenter_ready": false
}
EOF_JSON

jq empty "$OUT_DIR/cross-path-source-shape.json" "$OUT_DIR/nonclaim-results.json"

if ! $semantic_shape_ok; then
	echo "cross-path source shape failed" >&2
	cat "$blockers" >&2
	exit 1
fi

(
	cd "$MODEL_DIR"
	java -cp "$TLA_JAR" tlc2.TLC -deadlock -metadir "$OUT_DIR/tlc-safe-states" -config P5ARCrossPathExclusionSettlementSafe.cfg "$MODEL"
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
for cfg in "$MODEL_DIR"/P5ARCrossPathExclusionSettlementUnsafe*.cfg; do
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

cfg_count=$(find "$MODEL_DIR" -maxdepth 1 -name 'P5ARCrossPathExclusionSettlementUnsafe*.cfg' | wc -l)
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
  "safe_passed": true,
  "safe_states_generated": ${safe_states:-0},
  "safe_distinct_states": ${safe_distinct:-0},
  "safe_depth": ${safe_depth:-0},
  "unsafe_expected_counterexamples": $unsafe_expected
}
EOF_JSON

jq empty "$OUT_DIR/result.json"
cat "$OUT_DIR/result.json"
