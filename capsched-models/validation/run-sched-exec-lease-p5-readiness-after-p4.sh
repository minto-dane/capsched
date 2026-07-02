#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0
#
# Source-order checker for the P5 readiness refresh after the P4 allow-only
# skeleton. This runner intentionally validates that P5 remains blocked.

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_DIR=$(cd -- "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd -- "$REPO_DIR/.." && pwd)

LINUX_DIR=${DOMAINLEASE_LINUX_DIR:-"$WORKSPACE_DIR/linux"}
CONFIG=${DOMAINLEASE_P5_READINESS_CONFIG:-"$REPO_DIR/capsched-models/analysis/sched-exec-lease-p5-readiness-refresh-after-p4-v1.json"}
OUT_ROOT=${DOMAINLEASE_P5_READINESS_OUT_ROOT:-"$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5-readiness-after-p4"}
RUN_ID=${DOMAINLEASE_RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
OUT_DIR="$OUT_ROOT/$RUN_ID"

die()
{
	printf 'error: %s\n' "$*" >&2
	exit 1
}

require_cmd()
{
	command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

line_of()
{
	local file=$1
	local pattern=$2

	awk -v pat="$pattern" 'index($0, pat) { print NR; exit }' "$file"
}

last_line_of()
{
	local file=$1
	local pattern=$2

	awk -v pat="$pattern" 'index($0, pat) { line = NR } END { if (line) print line }' "$file"
}

require_line()
{
	local name=$1
	local file=$2
	local pattern=$3
	local line

	line=$(line_of "$file" "$pattern")
	[ -n "$line" ] || die "missing $name: $pattern"
	printf '%s' "$line"
}

require_last_line()
{
	local name=$1
	local file=$2
	local pattern=$3
	local line

	line=$(last_line_of "$file" "$pattern")
	[ -n "$line" ] || die "missing $name: $pattern"
	printf '%s' "$line"
}

require_order()
{
	local name=$1
	local before=$2
	local after=$3

	[ "$before" -lt "$after" ] || die "$name order violation: $before !< $after"
}

require_cmd awk
require_cmd git
require_cmd grep
require_cmd jq

git -C "$LINUX_DIR" rev-parse --git-dir >/dev/null 2>&1 || \
	die "Linux Git tree not found: $LINUX_DIR"
[ -f "$CONFIG" ] || die "P5 readiness config not found: $CONFIG"

mkdir -p "$OUT_DIR"

expected_work_commit=$(jq -r '.source_basis.linux_commit' "$CONFIG")
actual_work_commit=$(git -C "$LINUX_DIR" rev-parse HEAD)
[ "$actual_work_commit" = "$expected_work_commit" ] || \
	die "Linux HEAD $actual_work_commit does not match contract $expected_work_commit"

core="$LINUX_DIR/kernel/sched/core.c"
sched_h="$LINUX_DIR/kernel/sched/sched.h"
header="$LINUX_DIR/include/linux/sched_exec_lease.h"

run_validate=$(require_line "run validate callsite" "$core" "(void)sched_exec_lease_validate_run_edge(prev, next);")
pick_next=$(require_line "pick_next_task call" "$core" "next = pick_next_task(rq, &rf);")
clear_resched=$(require_line "clear_tsk_need_resched" "$core" "clear_tsk_need_resched(prev);")
is_switch=$(require_line "is_switch assignment" "$core" "is_switch = prev != next;")
rq_curr=$(require_line "rq curr publication" "$core" "RCU_INIT_POINTER(rq->curr, next);")
context_switch=$(require_line "context switch call" "$core" "context_switch(rq, prev, next, &rf);")

require_order "pick_next before run validation" "$pick_next" "$run_validate"
require_order "clear resched before run validation" "$clear_resched" "$run_validate"
require_order "run validation before is_switch" "$run_validate" "$is_switch"
require_order "run validation before rq->curr" "$run_validate" "$rq_curr"
require_order "run validation before context_switch" "$run_validate" "$context_switch"

fast_settle=$(require_line "fast-class put_prev_set_next_task" "$core" "put_prev_set_next_task(rq, rq->donor, p);")
core_settle=$(require_last_line "core put_prev_set_next_task" "$core" "put_prev_set_next_task(rq, rq->donor, next);")
dl_server_settle=$(require_line "dl-server settlement" "$sched_h" "__put_prev_set_next_dl_server(rq, prev, next);")
put_prev_settle=$(require_line "put_prev_task settlement" "$sched_h" "prev->sched_class->put_prev_task(rq, prev, next);")
set_next_settle=$(require_line "set_next_task settlement" "$sched_h" "next->sched_class->set_next_task(rq, next, true);")

require_order "known fast settlement source before run validation source" "$fast_settle" "$run_validate"
require_order "known core settlement source before run validation source" "$core_settle" "$run_validate"
require_order "dl-server settlement before class put/set" "$dl_server_settle" "$put_prev_settle"
require_order "put_prev before set_next" "$put_prev_settle" "$set_next_settle"

move_validate=$(require_line "common move validate" "$core" "(void)sched_exec_lease_validate_move_edge(p, new_cpu);")
move_note=$(require_line "common move note" "$core" "sched_exec_lease_note_queued_move(p, new_cpu);")
move_deactivate=$(require_line "common move deactivate" "$core" "deactivate_task(rq, p, DEQUEUE_NOCLOCK);")
move_set_cpu=$(require_line "common move set_task_cpu" "$core" "set_task_cpu(p, new_cpu);")
move_activate=$(require_line "common move activate" "$core" "activate_task(rq, p, 0);")

require_order "common move validate before note" "$move_validate" "$move_note"
require_order "common move validate before deactivate" "$move_validate" "$move_deactivate"
require_order "common move validate before set_task_cpu" "$move_validate" "$move_set_cpu"
require_order "common move set_task_cpu before activate" "$move_set_cpu" "$move_activate"

locked_move_validate=$(require_line "locked move validate" "$sched_h" "(void)sched_exec_lease_validate_move_edge_locked(task, dst_rq->cpu);")
locked_move_note=$(require_line "locked move note" "$sched_h" "sched_exec_lease_note_queued_move(task, dst_rq->cpu);")
locked_move_deactivate=$(require_line "locked move deactivate" "$sched_h" "deactivate_task(src_rq, task, 0);")
locked_move_set_cpu=$(require_line "locked move set_task_cpu" "$sched_h" "set_task_cpu(task, dst_rq->cpu);")
locked_move_activate=$(require_line "locked move activate" "$sched_h" "activate_task(dst_rq, task, 0);")

require_order "locked move validate before note" "$locked_move_validate" "$locked_move_note"
require_order "locked move validate before deactivate" "$locked_move_validate" "$locked_move_deactivate"
require_order "locked move validate before set_task_cpu" "$locked_move_validate" "$locked_move_set_cpu"
require_order "locked move set_task_cpu before activate" "$locked_move_set_cpu" "$locked_move_activate"

if grep -RInE "if[[:space:]]*\\(.*sched_exec_lease_validate|switch[[:space:]]*\\(.*sched_exec_lease_validate" \
	"$LINUX_DIR/kernel/sched" "$header" > "$OUT_DIR/validation-branch-hits.txt"; then
	die "scheduler currently branches on SchedExecLease validation helper"
fi

common_move_returns_status=false
locked_move_returns_status=false

if grep -nF "static struct rq *move_queued_task(" "$core" > "$OUT_DIR/common-move-signature.txt"; then
	common_move_returns_status=false
else
	die "move_queued_task signature changed; refresh P5 readiness gate"
fi

if grep -nF "void move_queued_task_locked(" "$sched_h" > "$OUT_DIR/locked-move-signature.txt"; then
	locked_move_returns_status=false
else
	die "move_queued_task_locked signature changed; refresh P5 readiness gate"
fi

common_call_count=$(grep -nF "move_queued_task(rq" "$core" | wc -l)
locked_call_count=$(grep -nF "move_queued_task_locked" "$core" "$sched_h" | wc -l)

{
	printf 'property\tvalue\tevidence\n'
	printf 'work_commit_matches\ttrue\t%s\n' "$actual_work_commit"
	printf 'helpers_allow_only\ttrue\t%s\n' "$header"
	printf 'scheduler_branches_on_validation_result\tfalse\t%s\n' "$OUT_DIR/validation-branch-hits.txt"
	printf 'run_hook_before_rq_curr\ttrue\t%s<%s\n' "$run_validate" "$rq_curr"
	printf 'run_hook_before_context_switch\ttrue\t%s<%s\n' "$run_validate" "$context_switch"
	printf 'run_hook_after_pick_next_task\ttrue\t%s<%s\n' "$pick_next" "$run_validate"
	printf 'run_hook_after_resched_clear\ttrue\t%s<%s\n' "$clear_resched" "$run_validate"
	printf 'known_class_settlement_before_run_hook_source\ttrue\t%s,%s<%s\n' "$fast_settle" "$core_settle" "$run_validate"
	printf 'run_hook_p5_deny_ready\tfalse\tpost-settle-or-rollback-proof-required\n'
	printf 'common_move_hook_before_mutation\ttrue\t%s<%s,%s\n' "$move_validate" "$move_deactivate" "$move_set_cpu"
	printf 'locked_move_hook_before_mutation\ttrue\t%s<%s,%s\n' "$locked_move_validate" "$locked_move_deactivate" "$locked_move_set_cpu"
	printf 'common_move_returns_status\t%s\tstatic-struct-rq-pointer\n' "$common_move_returns_status"
	printf 'locked_move_returns_status\t%s\tvoid-helper\n' "$locked_move_returns_status"
	printf 'common_move_call_count\t%s\tgrep\n' "$common_call_count"
	printf 'locked_move_call_count\t%s\tgrep\n' "$locked_call_count"
	printf 'p5_approved\tfalse\tblocked-gate\n'
	printf 'runtime_denial_approved\tfalse\tblocked-gate\n'
	printf 'runtime_coverage_claim\tfalse\tnon-claim\n'
	printf 'production_protection_claim\tfalse\tnon-claim\n'
} > "$OUT_DIR/p5-readiness.tsv"

jq -n \
	--arg run_id "$RUN_ID" \
	--arg work_commit "$actual_work_commit" \
	--argjson run_validate "$run_validate" \
	--argjson pick_next "$pick_next" \
	--argjson clear_resched "$clear_resched" \
	--argjson rq_curr "$rq_curr" \
	--argjson context_switch "$context_switch" \
	--argjson fast_settle "$fast_settle" \
	--argjson core_settle "$core_settle" \
	--argjson move_validate "$move_validate" \
	--argjson move_deactivate "$move_deactivate" \
	--argjson move_set_cpu "$move_set_cpu" \
	--argjson locked_move_validate "$locked_move_validate" \
	--argjson locked_move_deactivate "$locked_move_deactivate" \
	--argjson locked_move_set_cpu "$locked_move_set_cpu" \
	--argjson common_call_count "$common_call_count" \
	--argjson locked_call_count "$locked_call_count" \
	'{
	  schema_version: 1,
	  run_id: $run_id,
	  work_commit: $work_commit,
	  run_validate_line: $run_validate,
	  pick_next_line: $pick_next,
	  clear_resched_line: $clear_resched,
	  rq_curr_line: $rq_curr,
	  context_switch_line: $context_switch,
	  fast_settle_line: $fast_settle,
	  core_settle_line: $core_settle,
	  move_validate_line: $move_validate,
	  move_deactivate_line: $move_deactivate,
	  move_set_cpu_line: $move_set_cpu,
	  locked_move_validate_line: $locked_move_validate,
	  locked_move_deactivate_line: $locked_move_deactivate,
	  locked_move_set_cpu_line: $locked_move_set_cpu,
	  common_move_call_count: $common_call_count,
	  locked_move_call_count: $locked_call_count,
	  scheduler_branches_on_validation_result: false,
	  run_hook_before_rq_curr: true,
	  run_hook_before_context_switch: true,
	  run_hook_after_pick_next_task: true,
	  run_hook_after_resched_clear: true,
	  known_class_settlement_before_run_hook_source: true,
	  run_hook_p5_deny_ready: false,
	  common_move_hook_before_mutation: true,
	  locked_move_hook_before_mutation: true,
	  common_move_returns_status: false,
	  locked_move_returns_status: false,
	  p5_approved: false,
	  runtime_denial_approved: false,
	  runtime_coverage_claim: false,
	  monitor_verified: false,
	  production_protection_claim: false
	}' > "$OUT_DIR/result.json"

printf '[domainlease] P5 readiness after P4 source check completed\n'
printf '[domainlease] run_dir=%s\n' "$OUT_DIR"
cat "$OUT_DIR/p5-readiness.tsv"
