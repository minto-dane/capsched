#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0
#
# Validate the P5A0.E prepatch evidence package.
#
# This is a source-only gate. It does not approve or apply a Linux patch.

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_DIR=$(cd -- "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd -- "$REPO_DIR/.." && pwd)

LINUX_DIR=${DOMAINLEASE_LINUX_DIR:-"$WORKSPACE_DIR/linux"}
ANALYSIS_CONFIG=${DOMAINLEASE_P5A0_E_CONFIG:-"$REPO_DIR/capsched-models/analysis/sched-exec-lease-p5a0-e-prepatch-evidence-v1.json"}
IMPLEMENTATION_CONFIG=${DOMAINLEASE_P5A0_E_IMPL_CONFIG:-"$REPO_DIR/capsched-models/implementation/sched-exec-lease-p5a0-e-prepatch-evidence-v1.json"}
OUT_ROOT=${DOMAINLEASE_P5A0_E_OUT_ROOT:-"$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a0-e-prepatch-evidence"}
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

jq_string()
{
	local file=$1
	local expr=$2
	local expected=$3
	local actual

	actual=$(jq -r "$expr" "$file")
	[ "$actual" = "$expected" ] || \
		die "unexpected $expr in $file: got $actual expected $expected"
}

require_array_value()
{
	local file=$1
	local array_expr=$2
	local value=$3

	jq -e --arg value "$value" "$array_expr | index(\$value) != null" \
		"$file" >/dev/null || die "missing array value $value in $file at $array_expr"
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

summary_value()
{
	local file=$1
	local key=$2

	awk -F= -v key="$key" '$1 == key { print $2; found=1 } END { if (!found) exit 1 }' "$file"
}

require_summary_value()
{
	local file=$1
	local key=$2
	local expected=$3
	local actual

	actual=$(summary_value "$file" "$key") || die "missing summary key: $key"
	[ "$actual" = "$expected" ] || \
		die "unexpected summary $key: got $actual expected $expected"
}

require_cmd awk
require_cmd git
require_cmd grep
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

jq_string "$ANALYSIS_CONFIG" '.candidate.id' 'P5A0EPrepatchEvidence'
jq_string "$ANALYSIS_CONFIG" '.candidate.mode' 'evidence_only_no_linux_patch'
jq_string "$IMPLEMENTATION_CONFIG" '.candidate.id' 'P5A0EPrepatchEvidence'
jq_string "$IMPLEMENTATION_CONFIG" '.candidate.future_patch_id' 'P5A0.P1'

for group in l0_footprint scheduler_authority_core; do
	require_array_value "$ANALYSIS_CONFIG" '.candidate.touched_or_claimed_groups' "$group"
done

for file in include/linux/sched_exec_lease.h kernel/sched/exec_lease.c; do
	require_array_value "$ANALYSIS_CONFIG" '.future_patch_identity.p5a0_p1_recommended_file_allowlist' "$file"
	require_array_value "$IMPLEMENTATION_CONFIG" '.p5a0_p1_recommended_file_allowlist' "$file"
done

for file in \
	kernel/sched/core.c \
	kernel/sched/sched.h \
	kernel/sched/fair.c \
	kernel/sched/rt.c \
	kernel/sched/deadline.c \
	kernel/sched/ext/ext.c
do
	require_array_value "$ANALYSIS_CONFIG" '.future_patch_identity.scheduler_file_touch_requires_scope_reopen' "$file"
	require_array_value "$IMPLEMENTATION_CONFIG" '.scheduler_file_touch_requires_scope_reopen' "$file"
done

drift_run_dir="$WORKSPACE_DIR/$(jq -r '.source_drift_basis.run_dir' "$ANALYSIS_CONFIG")"
[ -d "$drift_run_dir" ] || die "missing drift run dir: $drift_run_dir"
summary="$drift_run_dir/summary.env"
groups="$drift_run_dir/group-results.tsv"
[ -f "$summary" ] || die "missing drift summary: $summary"
[ -f "$groups" ] || die "missing drift group results: $groups"

require_summary_value "$summary" work_commit "$actual_work_commit"
require_summary_value "$summary" merge_tree_clean true
require_summary_value "$summary" missing_watched_path_count 0
require_summary_value "$summary" patch_footprint_config_matches_actual true
require_summary_value "$summary" direct_footprint_drift false
require_summary_value "$summary" future_attachment_drift false
require_summary_value "$summary" semantic_drift_requires_refresh true
require_summary_value "$summary" model_freshness stale
require_summary_value "$summary" candidate_no_behavior_patch_reviewable false
require_summary_value "$summary" linux_patch_approved false
require_summary_value "$summary" behavior_change false
require_summary_value "$summary" runtime_coverage false
require_summary_value "$summary" abi false
require_summary_value "$summary" public_tracepoint_abi false
require_summary_value "$summary" monitor_verified false
require_summary_value "$summary" production_protection false

for group in l0_footprint scheduler_authority_core; do
	awk -F '\t' -v group="$group" '
		NR > 1 && $1 == group {
			if ($2 != "0" || $4 != "false" || $5 != "D0_no_relevant_drift")
				exit 2
			found=1
		}
		END { if (!found) exit 1 }
	' "$groups" || die "candidate group not fresh in drift row: $group"
done

awk -F '\t' '
	NR > 1 && $1 == "device_queue_iommu" {
		if ($2 == "0" || $4 != "true" || $5 != "D4_semantic_drift")
			exit 2
		found=1
	}
	END { if (!found) exit 1 }
' "$groups" || die "device_queue_iommu stale group not recorded"

header="$LINUX_DIR/include/linux/sched_exec_lease.h"
core="$LINUX_DIR/kernel/sched/core.c"
sched_h="$LINUX_DIR/kernel/sched/sched.h"
fair="$LINUX_DIR/kernel/sched/fair.c"

helper_count=0
for helper in \
	sched_exec_lease_validate_run_edge \
	sched_exec_lease_validate_move_edge \
	sched_exec_lease_validate_move_edge_locked
do
	line=$(require_line "helper definition $helper" "$header" "$helper(")
	return_line=$(awk -v start="$line" \
		'NR > start && index($0, "return SCHED_EXEC_VALIDATION_ALLOW;") { print NR; exit }' \
		"$header")
	[ -n "$return_line" ] || die "helper does not return ALLOW: $helper"
	printf '%s\t%s\t%s\n' "$helper" "$line" "$return_line" >> "$OUT_DIR/helper-lines.tsv"
	helper_count=$((helper_count + 1))
done

for forbidden in RETRY INELIGIBLE QUARANTINE; do
	if grep -RIn --include='*.c' --include='*.h' \
		"return[[:space:]]\\+SCHED_EXEC_VALIDATION_${forbidden};" \
		"$LINUX_DIR/include/linux/sched_exec_lease.h" "$LINUX_DIR/kernel/sched" \
		> "$OUT_DIR/forbidden-return-$forbidden.txt"; then
		die "found forbidden return: SCHED_EXEC_VALIDATION_${forbidden}"
	fi
done

if grep -RInE "if[[:space:]]*\\(.*sched_exec_lease_validate|switch[[:space:]]*\\(.*sched_exec_lease_validate|\\?.*sched_exec_lease_validate|sched_exec_lease_validate.*\\?" \
	"$LINUX_DIR/kernel/sched" "$header" > "$OUT_DIR/validation-branch-hits.txt"; then
	die "scheduler branches or ternary-depends on validation helper"
fi

callsite_count=$(grep -RIn "sched_exec_lease_validate_.*edge" "$LINUX_DIR/kernel/sched" | wc -l)
[ "$callsite_count" -eq 3 ] || die "unexpected scheduler validation callsite count: $callsite_count"

if grep -RIn "sched_exec_lease" "$fair" > "$OUT_DIR/fair-picker-sched-exec-hits.txt"; then
	die "fair picker contains sched_exec_lease hook; P5A0.E expects no fair ineligibility"
fi

run_validate=$(require_line "run validate callsite" "$core" "(void)sched_exec_lease_validate_run_edge(prev, next);")
pick_next=$(require_line "pick_next_task call" "$core" "next = pick_next_task(rq, &rf);")
rq_curr=$(require_line "rq curr publication" "$core" "RCU_INIT_POINTER(rq->curr, next);")
context_switch=$(require_line "context switch call" "$core" "context_switch(rq, prev, next, &rf);")
fast_settle=$(require_line "fast-class put_prev_set_next_task" "$core" "put_prev_set_next_task(rq, rq->donor, p);")
core_settle=$(require_last_line "core put_prev_set_next_task" "$core" "put_prev_set_next_task(rq, rq->donor, next);")

require_order "pick_next before run validation" "$pick_next" "$run_validate"
require_order "run validation before rq->curr" "$run_validate" "$rq_curr"
require_order "run validation before context_switch" "$run_validate" "$context_switch"
require_order "fast class settlement before run validation source" "$fast_settle" "$run_validate"
require_order "core settlement before run validation source" "$core_settle" "$run_validate"

move_validate=$(require_line "common move validate" "$core" "(void)sched_exec_lease_validate_move_edge(p, new_cpu);")
move_deactivate=$(require_line "common move deactivate" "$core" "deactivate_task(rq, p, DEQUEUE_NOCLOCK);")
move_set_cpu=$(require_line "common move set_task_cpu" "$core" "set_task_cpu(p, new_cpu);")
locked_move_validate=$(require_line "locked move validate" "$sched_h" "(void)sched_exec_lease_validate_move_edge_locked(task, dst_rq->cpu);")
locked_move_deactivate=$(require_line "locked move deactivate" "$sched_h" "deactivate_task(src_rq, task, 0);")
locked_move_set_cpu=$(require_line "locked move set_task_cpu" "$sched_h" "set_task_cpu(task, dst_rq->cpu);")

require_order "common move validate before deactivate" "$move_validate" "$move_deactivate"
require_order "common move validate before set_task_cpu" "$move_validate" "$move_set_cpu"
require_order "locked move validate before deactivate" "$locked_move_validate" "$locked_move_deactivate"
require_order "locked move validate before set_task_cpu" "$locked_move_validate" "$locked_move_set_cpu"

grep -nF "static struct rq *move_queued_task(" "$core" > "$OUT_DIR/common-move-signature.txt" || \
	die "move_queued_task signature changed"
grep -nF "void move_queued_task_locked(" "$sched_h" > "$OUT_DIR/locked-move-signature.txt" || \
	die "move_queued_task_locked signature changed"

common_move_call_count=$(grep -nF "rq = move_queued_task(rq, rf, p, dest_cpu);" "$core" | wc -l)
locked_move_call_count=$(grep -nF "move_queued_task_locked(" "$core" | wc -l)
[ "$common_move_call_count" -eq 2 ] || die "unexpected common move caller count: $common_move_call_count"
[ "$locked_move_call_count" -eq 3 ] || die "unexpected locked move caller count: $locked_move_call_count"

for plan in \
	patch_queue_plan \
	source_checker_plan \
	full_build_off_on_plan \
	qemu_denial_disabled_smoke_plan \
	object_symbol_review_plan \
	negative_harness_plan \
	claim_ledger_row \
	explicit_non_claims
do
	jq_bool "$ANALYSIS_CONFIG" ".required_plans.$plan" true
done

for flag in \
	linux_patch_approved \
	behavior_change_approved \
	runtime_denial_approved \
	retry_approved \
	fail_closed_approved \
	quarantine_approved \
	runtime_coverage \
	public_abi \
	monitor_call \
	monitor_verified \
	production_protection \
	hypervisor_grade_isolation \
	cost_efficiency_claim \
	deployment_readiness \
	datacenter_readiness
do
	jq_bool "$ANALYSIS_CONFIG" ".safety_flags.$flag" false
done

jq_bool "$ANALYSIS_CONFIG" '.decisions.p5a0_e_prepatch_evidence_recorded' true
jq_bool "$ANALYSIS_CONFIG" '.decisions.p5a0_p1_patch_approved' false
jq_bool "$ANALYSIS_CONFIG" '.decisions.p5a0_p2_move_status_patch_approved' false
jq_bool "$ANALYSIS_CONFIG" '.decisions.global_all_angles_freshness_claim' false
jq_bool "$IMPLEMENTATION_CONFIG" '.candidate.patch_queue_entry_created' false

{
	printf 'property\tvalue\tevidence\n'
	printf 'work_commit_matches\ttrue\t%s\n' "$actual_work_commit"
	printf 'drift_run_present\ttrue\t%s\n' "$drift_run_dir"
	printf 'candidate_groups_fresh\ttrue\tl0_footprint;scheduler_authority_core\n'
	printf 'non_candidate_device_queue_iommu_stale_recorded\ttrue\t%s\n' "$groups"
	printf 'global_model_freshness\tfalse\t%s\n' "$summary"
	printf 'linux_patch_approved\tfalse\tanalysis and implementation safety flags\n'
	printf 'helper_count\t%s\t%s\n' "$helper_count" "$OUT_DIR/helper-lines.tsv"
	printf 'helper_return_set_allow_only\ttrue\t%s\n' "$header"
	printf 'scheduler_validation_callsite_count\t%s\tsource_grep\n' "$callsite_count"
	printf 'scheduler_branch_on_validation_result\tfalse\tsource_grep\n'
	printf 'fair_picker_ineligibility\tfalse\t%s\n' "$fair"
	printf 'run_hook_p5_deny_ready\tfalse\tpost-picker-and-post-class-settle\n'
	printf 'common_move_hook_before_mutation\ttrue\t%s<%s,%s\n' "$move_validate" "$move_deactivate" "$move_set_cpu"
	printf 'locked_move_hook_before_mutation\ttrue\t%s<%s,%s\n' "$locked_move_validate" "$locked_move_deactivate" "$locked_move_set_cpu"
	printf 'common_move_returns_status\tfalse\tstatic-struct-rq-pointer\n'
	printf 'locked_move_returns_status\tfalse\tvoid-helper\n'
	printf 'common_move_call_count\t%s\texact-source-count\n' "$common_move_call_count"
	printf 'locked_move_call_count\t%s\texact-source-count\n' "$locked_move_call_count"
	printf 'p5a0_p1_patch_approved\tfalse\tprepatch-evidence-only\n'
	printf 'runtime_denial\tfalse\tnon-claim\n'
	printf 'production_or_cost_claim\tfalse\tnon-claim\n'
} > "$OUT_DIR/p5a0-e-prepatch-evidence.tsv"

jq -n \
	--arg run_id "$RUN_ID" \
	--arg work_commit "$actual_work_commit" \
	--arg drift_run_dir "$drift_run_dir" \
	--argjson helper_count "$helper_count" \
	--argjson callsite_count "$callsite_count" \
	--argjson common_move_call_count "$common_move_call_count" \
	--argjson locked_move_call_count "$locked_move_call_count" \
	'{
	  schema_version: 1,
	  run_id: $run_id,
	  work_commit: $work_commit,
	  drift_run_dir: $drift_run_dir,
	  candidate_groups_fresh: true,
	  non_candidate_device_queue_iommu_stale_recorded: true,
	  global_model_freshness: false,
	  linux_patch_approved: false,
	  helper_count: $helper_count,
	  helper_return_set_allow_only: true,
	  scheduler_validation_callsite_count: $callsite_count,
	  scheduler_branch_on_validation_result: false,
	  fair_picker_ineligibility: false,
	  run_hook_p5_deny_ready: false,
	  common_move_hook_before_mutation: true,
	  locked_move_hook_before_mutation: true,
	  common_move_returns_status: false,
	  locked_move_returns_status: false,
	  common_move_call_count: $common_move_call_count,
	  locked_move_call_count: $locked_move_call_count,
	  p5a0_p1_patch_approved: false,
	  runtime_denial: false,
	  production_or_cost_claim: false
	}' > "$OUT_DIR/result.json"

printf '[domainlease] P5A0.E prepatch evidence check completed\n'
printf '[domainlease] run_dir=%s\n' "$OUT_DIR"
cat "$OUT_DIR/p5a0-e-prepatch-evidence.tsv"
