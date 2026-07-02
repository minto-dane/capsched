#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0
#
# Validate the P5A scope proposal. This is a no-Linux-code gate.

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_DIR=$(cd -- "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd -- "$REPO_DIR/.." && pwd)

LINUX_DIR=${DOMAINLEASE_LINUX_DIR:-"$WORKSPACE_DIR/linux"}
ANALYSIS_CONFIG=${DOMAINLEASE_P5A_SCOPE_CONFIG:-"$REPO_DIR/capsched-models/analysis/sched-exec-lease-p5a-scope-proposal-v1.json"}
IMPLEMENTATION_CONFIG=${DOMAINLEASE_P5A_IMPL_CONFIG:-"$REPO_DIR/capsched-models/implementation/sched-exec-lease-p5a-scope-proposal-v1.json"}
OUT_ROOT=${DOMAINLEASE_P5A_SCOPE_OUT_ROOT:-"$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-scope-gate"}
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

jq_bool()
{
	local file=$1
	local expr=$2
	local expected=$3
	local actual

	actual=$(jq -r "$expr" "$file")
	[ "$actual" = "$expected" ] || \
		die "unexpected $expr in $file: got $actual expected $expected"
}

require_cmd git
require_cmd jq

git -C "$LINUX_DIR" rev-parse --git-dir >/dev/null 2>&1 || \
	die "Linux Git tree not found: $LINUX_DIR"
[ -f "$ANALYSIS_CONFIG" ] || die "missing analysis config: $ANALYSIS_CONFIG"
[ -f "$IMPLEMENTATION_CONFIG" ] || die "missing implementation config: $IMPLEMENTATION_CONFIG"

mkdir -p "$OUT_DIR"

expected_work_commit=$(jq -r '.source_basis.linux_commit' "$ANALYSIS_CONFIG")
actual_work_commit=$(git -C "$LINUX_DIR" rev-parse HEAD)
[ "$actual_work_commit" = "$expected_work_commit" ] || \
	die "Linux HEAD $actual_work_commit does not match contract $expected_work_commit"

jq_bool "$ANALYSIS_CONFIG" '.decision.p5a_decomposed' true
jq_bool "$ANALYSIS_CONFIG" '.decision.first_patch_may_change_behavior' false
jq_bool "$ANALYSIS_CONFIG" '.decision.p5_linux_implementation_approved' false
jq_bool "$ANALYSIS_CONFIG" '.decision.runtime_denial_approved' false
jq_bool "$ANALYSIS_CONFIG" '.safety_flags.p5a_scope_recorded' true
jq_bool "$ANALYSIS_CONFIG" '.safety_flags.linux_code_change_approved' false
jq_bool "$ANALYSIS_CONFIG" '.safety_flags.behavior_change_approved' false
jq_bool "$ANALYSIS_CONFIG" '.safety_flags.runtime_denial_approved' false
jq_bool "$ANALYSIS_CONFIG" '.safety_flags.production_protection' false
jq_bool "$ANALYSIS_CONFIG" '.safety_flags.cost_efficiency_claim' false

jq_bool "$IMPLEMENTATION_CONFIG" '.safety_flags.linux_code_approved' false
jq_bool "$IMPLEMENTATION_CONFIG" '.safety_flags.behavior_change_approved' false
jq_bool "$IMPLEMENTATION_CONFIG" '.safety_flags.runtime_denial_approved' false
jq_bool "$IMPLEMENTATION_CONFIG" '.safety_flags.production_protection' false
jq_bool "$IMPLEMENTATION_CONFIG" '.safety_flags.cost_efficiency_claim' false

for required in P5A0 P5A-R P5A-M P5A-V; do
	jq -e --arg id "$required" '.sub_slices[] | select(.id == $id)' \
		"$ANALYSIS_CONFIG" >/dev/null || die "missing sub-slice: $required"
done

for denied in \
	deny_one_cfs_task_and_choose_next_cfs_task \
	broad_common_move_denial \
	branch_on_non_allow \
	runtime_denial
do
	if ! jq -e --arg denied "$denied" \
		'.. | arrays | .[]? | select(. == $denied)' \
		"$ANALYSIS_CONFIG" "$IMPLEMENTATION_CONFIG" >/dev/null; then
		die "expected forbidden/not-approved marker missing: $denied"
	fi
done

{
	printf 'property\tvalue\tevidence\n'
	printf 'work_commit_matches\ttrue\t%s\n' "$actual_work_commit"
	printf 'p5a_scope_recorded\ttrue\t%s\n' "$ANALYSIS_CONFIG"
	printf 'p5a_decomposed\ttrue\tP5A0/P5A-R/P5A-M/P5A-V\n'
	printf 'first_patch_may_change_behavior\tfalse\tanalysis decision\n'
	printf 'p5_linux_implementation_approved\tfalse\tanalysis decision\n'
	printf 'runtime_denial_approved\tfalse\tanalysis decision\n'
	printf 'deny_one_cfs_pick_next_approved\tfalse\tnot-approved marker\n'
	printf 'broad_common_move_denial_approved\tfalse\tnot-approved marker\n'
	printf 'production_protection\tfalse\tsafety flags\n'
	printf 'cost_efficiency_claim\tfalse\tsafety flags\n'
} > "$OUT_DIR/p5a-scope-gate.tsv"

jq -n \
	--arg run_id "$RUN_ID" \
	--arg work_commit "$actual_work_commit" \
	'{
	  schema_version: 1,
	  run_id: $run_id,
	  work_commit: $work_commit,
	  p5a_scope_recorded: true,
	  p5a_decomposed: true,
	  first_patch_may_change_behavior: false,
	  p5_linux_implementation_approved: false,
	  runtime_denial_approved: false,
	  deny_one_cfs_pick_next_approved: false,
	  broad_common_move_denial_approved: false,
	  production_protection: false,
	  cost_efficiency_claim: false
	}' > "$OUT_DIR/result.json"

printf '[domainlease] P5A scope gate check completed\n'
printf '[domainlease] run_dir=%s\n' "$OUT_DIR"
cat "$OUT_DIR/p5a-scope-gate.tsv"
