#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0
#
# Source-only P4 allow-all/no-denial helper proof checker.
#
# This runner:
# - does not modify Linux source
# - does not build kernels
# - does not attach probes, write tracefs, or load BPF
# - does not approve runtime denial, runtime coverage, monitor verification,
#   behavior change, or protection claims

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_DIR=$(cd -- "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd -- "$REPO_DIR/.." && pwd)

LINUX_DIR=${DOMAINLEASE_LINUX_DIR:-"$WORKSPACE_DIR/linux"}
CONFIG=${DOMAINLEASE_P4_ALLOW_ALL_CONFIG:-"$REPO_DIR/capsched-models/analysis/sched-exec-lease-p4-allow-all-helper-proof-v1.json"}
OUT_ROOT=${DOMAINLEASE_P4_ALLOW_ALL_OUT_ROOT:-"$WORKSPACE_DIR/build/source-check/sched-exec-lease-p4-allow-all-helper"}
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
[ -f "$CONFIG" ] || die "allow-all contract not found: $CONFIG"

mkdir -p "$OUT_DIR"

expected_work_commit=$(jq -r '.source_basis.work_commit' "$CONFIG")
actual_work_commit=$(git -C "$LINUX_DIR" rev-parse HEAD)
[ "$actual_work_commit" = "$expected_work_commit" ] || \
	die "Linux HEAD $actual_work_commit does not match contract work_commit $expected_work_commit"

exec_lease_c="$LINUX_DIR/kernel/sched/exec_lease.c"
[ -f "$exec_lease_c" ] || die "missing kernel/sched/exec_lease.c"

allow_helper=$(jq -r '.current_tree_checks.allow_all_helper' "$CONFIG")
allow_return=$(jq -r '.current_tree_checks.allow_return' "$CONFIG")

allow_helper_line=$(awk -v fn="$allow_helper" 'index($0, fn "(") { print NR; exit }' "$exec_lease_c")
[ -n "$allow_helper_line" ] || die "allow-all helper not found: $allow_helper"

allow_return_line=$(awk -v start="$allow_helper_line" -v ret="$allow_return" \
	'NR > start && index($0, "return " ret ";") { print NR; exit }' "$exec_lease_c")
[ -n "$allow_return_line" ] || die "allow-all helper does not return $allow_return"

for forbidden in $(jq -r '.current_tree_checks.forbidden_current_return_values[]' "$CONFIG"); do
	if grep -RIn --include='*.c' --include='*.h' "return[[:space:]]\\+$forbidden;" "$LINUX_DIR" \
		> "$OUT_DIR/forbidden-$forbidden.txt"; then
		die "found reachable forbidden return value: $forbidden"
	fi
done

if grep -RIn "sched_exec_lease_validate_.*edge" \
	"$LINUX_DIR/include/linux/sched_exec_lease.h" "$LINUX_DIR/kernel/sched" \
	> "$OUT_DIR/p4-validate-helper-hits.txt"; then
	die "P4 validate helpers are already present; this pre-implementation proof must be refreshed"
fi

if grep -RIn "SCHED_EXEC_VALIDATION_\\(RETRY\\|INELIGIBLE\\|QUARANTINE\\)" \
	"$LINUX_DIR/kernel/sched/core.c" "$LINUX_DIR/kernel/sched/sched.h" \
	> "$OUT_DIR/scheduler-nonallow-result-hits.txt"; then
	die "scheduler currently references non-allow validation results"
fi

if grep -RIn "if (.*sched_exec_.*validation\\|switch (.*sched_exec_.*validation" \
	"$LINUX_DIR/kernel/sched" "$LINUX_DIR/include/linux/sched_exec_lease.h" \
	> "$OUT_DIR/scheduler-validation-branch-hits.txt"; then
	die "scheduler currently branches on sched_exec validation"
fi

{
	printf 'property\tvalue\tevidence\n'
	printf 'allow_all_helper_exists\ttrue\tkernel/sched/exec_lease.c:%s\n' "$allow_helper_line"
	printf 'allow_all_helper_returns_allow\ttrue\tkernel/sched/exec_lease.c:%s\n' "$allow_return_line"
	printf 'forbidden_nonallow_returns_found\tfalse\tsource_grep\n'
	printf 'p4_validate_helpers_present\tfalse\tsource_grep\n'
	printf 'scheduler_branches_on_validation_result\tfalse\tsource_grep\n'
	printf 'linux_patch_approved\tfalse\tnon-claim\n'
	printf 'runtime_denial\tfalse\tnon-claim\n'
	printf 'runtime_coverage\tfalse\tnon-claim\n'
	printf 'production_protection\tfalse\tnon-claim\n'
} > "$OUT_DIR/allow-all-proof.tsv"

{
	printf 'run_id=%s\n' "$RUN_ID"
	printf 'workspace=%s\n' "$WORKSPACE_DIR"
	printf 'linux_dir=%s\n' "$LINUX_DIR"
	printf 'config=%s\n' "$CONFIG"
	printf 'work_commit=%s\n' "$actual_work_commit"
	printf 'allow_helper_line=%s\n' "$allow_helper_line"
	printf 'allow_return_line=%s\n' "$allow_return_line"
	printf 'allow_all_helper_exists=true\n'
	printf 'allow_all_helper_returns_allow=true\n'
	printf 'forbidden_nonallow_returns_found=false\n'
	printf 'p4_validate_helpers_present=false\n'
	printf 'scheduler_branches_on_validation_result=false\n'
	printf 'allow_all_helper_proof_closed=true\n'
	printf 'no_reachable_denial_path_proof_closed=true\n'
	printf 'linux_patch_approved=false\n'
	printf 'runtime_denial=false\n'
	printf 'runtime_coverage=false\n'
	printf 'monitor_verified=false\n'
	printf 'production_protection=false\n'
} > "$OUT_DIR/summary.env"

jq -n \
	--arg run_id "$RUN_ID" \
	--arg work_commit "$actual_work_commit" \
	--argjson allow_helper_line "$allow_helper_line" \
	--argjson allow_return_line "$allow_return_line" \
	'{
	  schema_version: 1,
	  run_id: $run_id,
	  work_commit: $work_commit,
	  allow_helper_line: $allow_helper_line,
	  allow_return_line: $allow_return_line,
	  allow_all_helper_exists: true,
	  allow_all_helper_returns_allow: true,
	  forbidden_nonallow_returns_found: false,
	  p4_validate_helpers_present: false,
	  scheduler_branches_on_validation_result: false,
	  allow_all_helper_proof_closed: true,
	  no_reachable_denial_path_proof_closed: true,
	  linux_patch_approved: false,
	  runtime_denial: false,
	  runtime_coverage: false,
	  monitor_verified: false,
	  production_protection: false
	}' > "$OUT_DIR/result.json"

printf '[domainlease] P4 allow-all helper proof check completed\n'
printf '[domainlease] run_dir=%s\n' "$OUT_DIR"
cat "$OUT_DIR/summary.env"
