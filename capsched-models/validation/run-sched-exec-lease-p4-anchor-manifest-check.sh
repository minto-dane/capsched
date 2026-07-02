#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0
#
# Source-only SchedExecLease P4 anchor manifest checker.
#
# This runner:
# - does not modify Linux source
# - does not build kernels
# - does not attach probes, write tracefs, or load BPF
# - does not approve Linux patches, runtime coverage, monitor verification,
#   behavior change, or protection claims

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_DIR=$(cd -- "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd -- "$REPO_DIR/.." && pwd)

LINUX_DIR=${DOMAINLEASE_LINUX_DIR:-"$WORKSPACE_DIR/linux"}
CONFIG=${DOMAINLEASE_P4_ANCHOR_CONFIG:-"$REPO_DIR/capsched-models/analysis/sched-exec-lease-p4-anchor-manifest-v1.json"}
OUT_ROOT=${DOMAINLEASE_P4_ANCHOR_OUT_ROOT:-"$WORKSPACE_DIR/build/source-check/sched-exec-lease-p4-anchors"}
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
[ -f "$CONFIG" ] || die "anchor manifest not found: $CONFIG"

mkdir -p "$OUT_DIR"

expected_work_commit=$(jq -r '.source_basis.work_commit' "$CONFIG")
actual_work_commit=$(git -C "$LINUX_DIR" rev-parse HEAD)
[ "$actual_work_commit" = "$expected_work_commit" ] || \
	die "Linux HEAD $actual_work_commit does not match manifest work_commit $expected_work_commit"

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

printf 'anchor_id\tpath\twindow_start\twindow_end\tinsert_after\tinsert_before\tstatus\n' \
	> "$OUT_DIR/anchors.tsv"

jq -c '.anchors[]' "$CONFIG" | while read -r anchor_json; do
	anchor_id=$(printf '%s' "$anchor_json" | jq -r '.id')
	path=$(printf '%s' "$anchor_json" | jq -r '.path')
	window_start_pattern=$(printf '%s' "$anchor_json" | jq -r '.window_start')
	window_end_pattern=$(printf '%s' "$anchor_json" | jq -r '.window_end')
	insert_after_pattern=$(printf '%s' "$anchor_json" | jq -r '.insert_after')
	insert_before_pattern=$(printf '%s' "$anchor_json" | jq -r '.insert_before')
	file="$LINUX_DIR/$path"

	[ -f "$file" ] || die "$anchor_id: source file missing: $path"

	window_start=$(line_of_first "$file" "$window_start_pattern")
	[ -n "$window_start" ] || die "$anchor_id: window_start not found: $window_start_pattern"

	window_end=$(line_of_first_after "$file" "$window_start" "$window_end_pattern")
	[ -n "$window_end" ] || die "$anchor_id: window_end not found after line $window_start: $window_end_pattern"
	[ "$window_start" -lt "$window_end" ] || die "$anchor_id: invalid source window"

	prev=$window_start
	while IFS= read -r pattern; do
		line=$(line_of_first_after "$file" "$prev" "$pattern")
		[ -n "$line" ] || die "$anchor_id: ordered pattern not found after line $prev: $pattern"
		[ "$line" -lt "$window_end" ] || die "$anchor_id: ordered pattern outside window: $pattern"
		prev=$line
	done < <(printf '%s' "$anchor_json" | jq -r '.ordered_patterns[]')

	insert_after=$(line_of_first_after "$file" "$window_start" "$insert_after_pattern")
	[ -n "$insert_after" ] || die "$anchor_id: insert_after not found: $insert_after_pattern"
	insert_before=$(line_of_first_after "$file" "$insert_after" "$insert_before_pattern")
	[ -n "$insert_before" ] || die "$anchor_id: insert_before not found after insert_after: $insert_before_pattern"
	[ "$insert_after" -lt "$insert_before" ] || die "$anchor_id: insert interval is invalid"
	[ "$insert_before" -lt "$window_end" ] || die "$anchor_id: insert interval outside window"

	while IFS= read -r pattern; do
		must_line=$(line_of_first_after "$file" "$window_start" "$pattern")
		[ -n "$must_line" ] || die "$anchor_id: must_be_before pattern not found: $pattern"
		[ "$insert_before" -le "$must_line" ] || die "$anchor_id: insertion point is after forbidden commit/mutation pattern: $pattern"
	done < <(printf '%s' "$anchor_json" | jq -r '.must_be_before[]')

	printf '%s\t%s\t%s\t%s\t%s\t%s\tok\n' \
		"$anchor_id" "$path" "$window_start" "$window_end" "$insert_after" "$insert_before" \
		>> "$OUT_DIR/anchors.tsv"
done

anchor_count=$(awk 'NR > 1 { count++ } END { print count + 0 }' "$OUT_DIR/anchors.tsv")

{
	printf 'run_id=%s\n' "$RUN_ID"
	printf 'workspace=%s\n' "$WORKSPACE_DIR"
	printf 'linux_dir=%s\n' "$LINUX_DIR"
	printf 'config=%s\n' "$CONFIG"
	printf 'work_commit=%s\n' "$actual_work_commit"
	printf 'anchor_count=%s\n' "$anchor_count"
	printf 'linux_patch_approved=false\n'
	printf 'runtime_denial=false\n'
	printf 'runtime_coverage=false\n'
	printf 'monitor_verified=false\n'
	printf 'production_protection=false\n'
} > "$OUT_DIR/summary.env"

jq -Rn \
	--arg run_id "$RUN_ID" \
	--arg work_commit "$actual_work_commit" \
	--argjson anchor_count "$anchor_count" \
	'{
	  schema_version: 1,
	  run_id: $run_id,
	  work_commit: $work_commit,
	  anchor_count: $anchor_count,
	  linux_patch_approved: false,
	  runtime_denial: false,
	  runtime_coverage: false,
	  monitor_verified: false,
	  production_protection: false
	}' > "$OUT_DIR/result.json"

printf '[domainlease] P4 anchor manifest check completed\n'
printf '[domainlease] run_dir=%s\n' "$OUT_DIR"
cat "$OUT_DIR/summary.env"
