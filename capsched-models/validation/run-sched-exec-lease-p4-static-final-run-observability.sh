#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0
#
# Source-only static final-run observability checker for SchedExecLease P4.
#
# This runner:
# - does not modify Linux source
# - does not build kernels
# - does not attach probes, write tracefs, or load BPF
# - does not approve runtime coverage, monitor verification, behavior change,
#   runtime denial, or protection claims

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_DIR=$(cd -- "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd -- "$REPO_DIR/.." && pwd)

LINUX_DIR=${DOMAINLEASE_LINUX_DIR:-"$WORKSPACE_DIR/linux"}
CONFIG=${DOMAINLEASE_P4_FINAL_RUN_OBS_CONFIG:-"$REPO_DIR/capsched-models/analysis/sched-exec-lease-p4-static-final-run-observability-v1.json"}
OUT_ROOT=${DOMAINLEASE_P4_FINAL_RUN_OBS_OUT_ROOT:-"$WORKSPACE_DIR/build/source-check/sched-exec-lease-p4-final-run-observability"}
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

require_cmd git
require_cmd jq
require_cmd awk

[ -d "$LINUX_DIR/.git" ] || die "Linux Git tree not found: $LINUX_DIR"
[ -f "$CONFIG" ] || die "observability contract not found: $CONFIG"

mkdir -p "$OUT_DIR"

expected_work_commit=$(jq -r '.source_basis.work_commit' "$CONFIG")
actual_work_commit=$(git -C "$LINUX_DIR" rev-parse HEAD)
[ "$actual_work_commit" = "$expected_work_commit" ] || \
	die "Linux HEAD $actual_work_commit does not match contract work_commit $expected_work_commit"

line_of_first()
{
	local file=$1
	local pattern=$2

	awk -v pat="$pattern" 'index($0, pat) { print NR; exit }' "$file"
}

line_of_first_after()
{
	local file=$1
	local start=$2
	local pattern=$3

	awk -v start="$start" -v pat="$pattern" \
		'NR > start && index($0, pat) { print NR; exit }' "$file"
}

path=$(jq -r '.final_run_anchor.path' "$CONFIG")
file="$LINUX_DIR/$path"
[ -f "$file" ] || die "source file missing: $path"

window_start_pattern=$(jq -r '.final_run_anchor.window_start' "$CONFIG")
window_end_pattern=$(jq -r '.final_run_anchor.window_end' "$CONFIG")
insert_after_pattern=$(jq -r '.final_run_anchor.insert_after' "$CONFIG")
insert_before_pattern=$(jq -r '.final_run_anchor.insert_before' "$CONFIG")
p3_marker_pattern=$(jq -r '.existing_p3_marker.pattern' "$CONFIG")

window_start=$(line_of_first "$file" "$window_start_pattern")
[ -n "$window_start" ] || die "window_start not found: $window_start_pattern"
window_end=$(line_of_first_after "$file" "$window_start" "$window_end_pattern")
[ -n "$window_end" ] || die "window_end not found: $window_end_pattern"

insert_after=$(line_of_first_after "$file" "$window_start" "$insert_after_pattern")
[ -n "$insert_after" ] || die "insert_after not found: $insert_after_pattern"
insert_before=$(line_of_first_after "$file" "$insert_after" "$insert_before_pattern")
[ -n "$insert_before" ] || die "insert_before not found: $insert_before_pattern"
[ "$insert_after" -lt "$insert_before" ] || die "invalid insert interval"
[ "$insert_before" -lt "$window_end" ] || die "insert interval outside window"

rq_curr_line=$(line_of_first_after "$file" "$window_start" "RCU_INIT_POINTER(rq->curr, next);")
trace_line=$(line_of_first_after "$file" "$window_start" "trace_sched_switch(preempt, prev, next, prev_state);")
p3_marker_line=$(line_of_first_after "$file" "$window_start" "$p3_marker_pattern")
context_switch_line=$(line_of_first_after "$file" "$window_start" "rq = context_switch(rq, prev, next, &rf);")

[ -n "$rq_curr_line" ] || die "rq->curr publication line not found"
[ -n "$trace_line" ] || die "trace_sched_switch line not found"
[ -n "$p3_marker_line" ] || die "P3 note_switch marker not found"
[ -n "$context_switch_line" ] || die "context_switch line not found"

[ "$insert_before" -le "$rq_curr_line" ] || die "static anchor is after rq->curr publication"
[ "$insert_before" -le "$trace_line" ] || die "static anchor is after trace_sched_switch"
[ "$insert_before" -le "$p3_marker_line" ] || die "static anchor is after P3 note_switch marker"
[ "$insert_before" -le "$context_switch_line" ] || die "static anchor is after context_switch"
[ "$rq_curr_line" -lt "$p3_marker_line" ] || die "P3 note_switch marker is not after rq->curr publication"
[ "$p3_marker_line" -lt "$context_switch_line" ] || die "P3 note_switch marker is not before context_switch"

{
	printf 'property\tvalue\tevidence\n'
	printf 'static_pre_rq_curr_anchor_observable\ttrue\t%s:%s-%s\n' "$path" "$insert_after" "$insert_before"
	printf 'runtime_final_run_coverage_proven\tfalse\tsource-only runner\n'
	printf 'p3_note_switch_after_rq_curr\ttrue\t%s:%s>%s\n' "$path" "$p3_marker_line" "$rq_curr_line"
	printf 'p3_note_switch_usable_as_precommit_anchor\tfalse\tmarker_after_rq_curr\n'
	printf 'p4_implementation_approved\tfalse\tnon-claim\n'
	printf 'production_protection\tfalse\tnon-claim\n'
} > "$OUT_DIR/observability.tsv"

{
	printf 'run_id=%s\n' "$RUN_ID"
	printf 'workspace=%s\n' "$WORKSPACE_DIR"
	printf 'linux_dir=%s\n' "$LINUX_DIR"
	printf 'config=%s\n' "$CONFIG"
	printf 'work_commit=%s\n' "$actual_work_commit"
	printf 'window_start=%s\n' "$window_start"
	printf 'window_end=%s\n' "$window_end"
	printf 'insert_after=%s\n' "$insert_after"
	printf 'insert_before=%s\n' "$insert_before"
	printf 'rq_curr_line=%s\n' "$rq_curr_line"
	printf 'trace_sched_switch_line=%s\n' "$trace_line"
	printf 'p3_note_switch_line=%s\n' "$p3_marker_line"
	printf 'context_switch_line=%s\n' "$context_switch_line"
	printf 'static_pre_rq_curr_anchor_observable=true\n'
	printf 'runtime_final_run_coverage_proven=false\n'
	printf 'p3_note_switch_usable_as_precommit_anchor=false\n'
	printf 'linux_patch_approved=false\n'
	printf 'runtime_denial=false\n'
	printf 'runtime_coverage=false\n'
	printf 'monitor_verified=false\n'
	printf 'production_protection=false\n'
} > "$OUT_DIR/summary.env"

jq -n \
	--arg run_id "$RUN_ID" \
	--arg work_commit "$actual_work_commit" \
	--argjson window_start "$window_start" \
	--argjson window_end "$window_end" \
	--argjson insert_after "$insert_after" \
	--argjson insert_before "$insert_before" \
	--argjson rq_curr_line "$rq_curr_line" \
	--argjson trace_sched_switch_line "$trace_line" \
	--argjson p3_note_switch_line "$p3_marker_line" \
	--argjson context_switch_line "$context_switch_line" \
	'{
	  schema_version: 1,
	  run_id: $run_id,
	  work_commit: $work_commit,
	  window_start: $window_start,
	  window_end: $window_end,
	  insert_after: $insert_after,
	  insert_before: $insert_before,
	  rq_curr_line: $rq_curr_line,
	  trace_sched_switch_line: $trace_sched_switch_line,
	  p3_note_switch_line: $p3_note_switch_line,
	  context_switch_line: $context_switch_line,
	  static_pre_rq_curr_anchor_observable: true,
	  runtime_final_run_coverage_proven: false,
	  p3_note_switch_usable_as_precommit_anchor: false,
	  linux_patch_approved: false,
	  runtime_denial: false,
	  runtime_coverage: false,
	  monitor_verified: false,
	  production_protection: false
	}' > "$OUT_DIR/result.json"

printf '[domainlease] P4 static final-run observability check completed\n'
printf '[domainlease] run_dir=%s\n' "$OUT_DIR"
cat "$OUT_DIR/summary.env"
