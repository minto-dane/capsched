#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0
#
# Validate the P5A0 no-behavior proposal. This is a no-Linux-code gate.

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_DIR=$(cd -- "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd -- "$REPO_DIR/.." && pwd)

LINUX_DIR=${DOMAINLEASE_LINUX_DIR:-"$WORKSPACE_DIR/linux"}
ANALYSIS_CONFIG=${DOMAINLEASE_P5A0_CONFIG:-"$REPO_DIR/capsched-models/analysis/sched-exec-lease-p5a0-no-behavior-infrastructure-proposal-v1.json"}
IMPLEMENTATION_CONFIG=${DOMAINLEASE_P5A0_IMPL_CONFIG:-"$REPO_DIR/capsched-models/implementation/sched-exec-lease-p5a0-no-behavior-infrastructure-proposal-v1.json"}
OUT_ROOT=${DOMAINLEASE_P5A0_OUT_ROOT:-"$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a0-no-behavior-gate"}
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

jq_string "$ANALYSIS_CONFIG" '.status' 'proposal_recorded_no_linux_patch_approved'
jq_string "$IMPLEMENTATION_CONFIG" '.status' 'implementation_proposal_only_no_linux_patch_approved'

for shape in \
	status_plumbing_shape \
	test_harness_shape \
	setup_time_path_disable_shape \
	claim_ledger_shape
do
	require_array_value "$ANALYSIS_CONFIG" '.allowed_shapes' "$shape"
done

jq_bool "$ANALYSIS_CONFIG" '.future_p5a0_patch_constraints.config_off_no_impact' true
jq_bool "$ANALYSIS_CONFIG" '.future_p5a0_patch_constraints.config_on_helpers_allow_only' true
jq_bool "$ANALYSIS_CONFIG" '.future_p5a0_patch_constraints.scheduler_branch_on_non_allow' false
jq_bool "$ANALYSIS_CONFIG" '.future_p5a0_patch_constraints.runtime_denial' false
jq_bool "$ANALYSIS_CONFIG" '.future_p5a0_patch_constraints.retry' false
jq_bool "$ANALYSIS_CONFIG" '.future_p5a0_patch_constraints.fail_closed' false
jq_bool "$ANALYSIS_CONFIG" '.future_p5a0_patch_constraints.quarantine' false
jq_bool "$ANALYSIS_CONFIG" '.future_p5a0_patch_constraints.public_abi' false
jq_bool "$ANALYSIS_CONFIG" '.future_p5a0_patch_constraints.monitor_call' false

jq_bool "$ANALYSIS_CONFIG" '.move_status_plumbing_shape.allow_path_identical_required' true
jq_bool "$ANALYSIS_CONFIG" '.move_status_plumbing_shape.non_allow_reachable_in_p5a0' false
jq_bool "$ANALYSIS_CONFIG" '.move_status_plumbing_shape.caller_behavior_change_allowed' false
jq_bool "$ANALYSIS_CONFIG" '.move_status_plumbing_shape.waiter_completion_change_allowed' false
jq_bool "$ANALYSIS_CONFIG" '.move_status_plumbing_shape.resched_change_allowed' false
jq_bool "$ANALYSIS_CONFIG" '.move_status_plumbing_shape.task_cpu_placement_change_allowed' false

jq_bool "$ANALYSIS_CONFIG" '.run_status_plumbing_shape.current_p4_final_run_hook_as_denial_hook' false
jq_bool "$ANALYSIS_CONFIG" '.run_status_plumbing_shape.observation_only' true
jq_bool "$ANALYSIS_CONFIG" '.run_status_plumbing_shape.allow_only' true
jq_bool "$ANALYSIS_CONFIG" '.run_status_plumbing_shape.future_denial_requires_p5a_r' true

jq_bool "$ANALYSIS_CONFIG" '.test_harness_shape.internal_only' true
jq_bool "$ANALYSIS_CONFIG" '.test_harness_shape.public_tracepoint_abi' false
jq_bool "$ANALYSIS_CONFIG" '.test_harness_shape.syscall_abi' false
jq_bool "$ANALYSIS_CONFIG" '.test_harness_shape.ioctl_abi' false
jq_bool "$ANALYSIS_CONFIG" '.test_harness_shape.sysfs_abi' false
jq_bool "$ANALYSIS_CONFIG" '.test_harness_shape.procfs_abi' false
jq_bool "$ANALYSIS_CONFIG" '.test_harness_shape.debugfs_abi' false
jq_bool "$ANALYSIS_CONFIG" '.test_harness_shape.monitor_abi' false

jq_bool "$ANALYSIS_CONFIG" '.setup_time_disable_shape.behavior_change_in_proposal' false

for required in \
	fresh_upstream_drift_row_for_touched_groups \
	patch_queue_plan \
	source_checker_plan \
	full_build_off_on_plan \
	qemu_denial_disabled_smoke_plan \
	object_symbol_review_plan \
	negative_harness_plan \
	claim_ledger_row \
	explicit_non_claims
do
	require_array_value "$ANALYSIS_CONFIG" '.required_before_patch_review' "$required"
done

for required in \
	patch_queue_replay \
	checkpatch \
	source_checker_no_non_allow_reachable_behavior \
	source_checker_no_scheduler_branch_on_validation_result \
	config_off_on_build \
	qemu_denial_disabled_boot_workload_smoke \
	object_symbol_review \
	overclaim_review
do
	require_array_value "$ANALYSIS_CONFIG" '.required_before_patch_acceptance' "$required"
done

jq_bool "$ANALYSIS_CONFIG" '.safety_flags.proposal_recorded' true
jq_bool "$ANALYSIS_CONFIG" '.safety_flags.linux_patch_approved' false
jq_bool "$ANALYSIS_CONFIG" '.safety_flags.behavior_change_approved' false
jq_bool "$ANALYSIS_CONFIG" '.safety_flags.runtime_denial_approved' false
jq_bool "$ANALYSIS_CONFIG" '.safety_flags.retry_approved' false
jq_bool "$ANALYSIS_CONFIG" '.safety_flags.fail_closed_approved' false
jq_bool "$ANALYSIS_CONFIG" '.safety_flags.quarantine_approved' false
jq_bool "$ANALYSIS_CONFIG" '.safety_flags.public_abi' false
jq_bool "$ANALYSIS_CONFIG" '.safety_flags.monitor_call' false
jq_bool "$ANALYSIS_CONFIG" '.safety_flags.production_protection' false
jq_bool "$ANALYSIS_CONFIG" '.safety_flags.hypervisor_grade_isolation' false
jq_bool "$ANALYSIS_CONFIG" '.safety_flags.cost_efficiency_claim' false
jq_bool "$ANALYSIS_CONFIG" '.safety_flags.deployment_readiness' false
jq_bool "$ANALYSIS_CONFIG" '.safety_flags.datacenter_readiness' false

jq_bool "$IMPLEMENTATION_CONFIG" '.allowed_future_patch_shape.helpers_allow_only' true
jq_bool "$IMPLEMENTATION_CONFIG" '.allowed_future_patch_shape.scheduler_branch_on_validation_result' false
jq_bool "$IMPLEMENTATION_CONFIG" '.allowed_future_patch_shape.non_allow_path_reachable' false
jq_bool "$IMPLEMENTATION_CONFIG" '.allowed_future_patch_shape.retry' false
jq_bool "$IMPLEMENTATION_CONFIG" '.allowed_future_patch_shape.fail_closed' false
jq_bool "$IMPLEMENTATION_CONFIG" '.allowed_future_patch_shape.quarantine' false
jq_bool "$IMPLEMENTATION_CONFIG" '.allowed_future_patch_shape.runtime_denial' false
jq_bool "$IMPLEMENTATION_CONFIG" '.allowed_future_patch_shape.abi' false
jq_bool "$IMPLEMENTATION_CONFIG" '.allowed_future_patch_shape.monitor_call' false

jq_bool "$IMPLEMENTATION_CONFIG" '.safety_flags.linux_patch_approved' false
jq_bool "$IMPLEMENTATION_CONFIG" '.safety_flags.behavior_change_approved' false
jq_bool "$IMPLEMENTATION_CONFIG" '.safety_flags.runtime_denial_approved' false
jq_bool "$IMPLEMENTATION_CONFIG" '.safety_flags.abi' false
jq_bool "$IMPLEMENTATION_CONFIG" '.safety_flags.monitor_call' false
jq_bool "$IMPLEMENTATION_CONFIG" '.safety_flags.production_protection' false
jq_bool "$IMPLEMENTATION_CONFIG" '.safety_flags.cost_efficiency_claim' false
jq_bool "$IMPLEMENTATION_CONFIG" '.safety_flags.deployment_readiness' false

for unit in \
	p5a0_1_source_only_contract_and_internal_type_shapes \
	p5a0_2_move_status_carrier_plumbing_allow_only \
	p5a0_3_internal_negative_test_harness_skeleton_no_public_abi \
	p5a0_4_disabled_path_setup_skeleton_no_behavior_until_test_denial_mode \
	p5a0_5_validation_and_overclaim_review
do
	require_array_value "$IMPLEMENTATION_CONFIG" '.candidate_patch_units' "$unit"
done

{
	printf 'property\tvalue\tevidence\n'
	printf 'work_commit_matches\ttrue\t%s\n' "$actual_work_commit"
	printf 'p5a0_proposal_recorded\ttrue\t%s\n' "$ANALYSIS_CONFIG"
	printf 'linux_patch_approved\tfalse\tanalysis and implementation safety flags\n'
	printf 'behavior_change_approved\tfalse\tanalysis and implementation safety flags\n'
	printf 'scheduler_branch_on_non_allow\tfalse\tfuture patch constraints\n'
	printf 'runtime_denial_approved\tfalse\tanalysis and implementation safety flags\n'
	printf 'retry_fail_closed_quarantine\tfalse\tfuture patch constraints\n'
	printf 'public_abi\tfalse\ttest harness and safety flags\n'
	printf 'monitor_call\tfalse\tfuture patch constraints\n'
	printf 'move_non_allow_reachable_in_p5a0\tfalse\tmove status shape\n'
	printf 'required_prepatch_evidence_planned\ttrue\trequired_before_patch_review\n'
	printf 'required_acceptance_validation_planned\ttrue\trequired_before_patch_acceptance\n'
	printf 'production_or_cost_claim\tfalse\tsafety flags\n'
} > "$OUT_DIR/p5a0-no-behavior-gate.tsv"

jq -n \
	--arg run_id "$RUN_ID" \
	--arg work_commit "$actual_work_commit" \
	'{
	  schema_version: 1,
	  run_id: $run_id,
	  work_commit: $work_commit,
	  p5a0_proposal_recorded: true,
	  linux_patch_approved: false,
	  behavior_change_approved: false,
	  scheduler_branch_on_non_allow: false,
	  runtime_denial_approved: false,
	  retry_fail_closed_quarantine: false,
	  public_abi: false,
	  monitor_call: false,
	  move_non_allow_reachable_in_p5a0: false,
	  required_prepatch_evidence_planned: true,
	  required_acceptance_validation_planned: true,
	  production_or_cost_claim: false
	}' > "$OUT_DIR/result.json"

printf '[domainlease] P5A0 no-behavior gate check completed\n'
printf '[domainlease] run_dir=%s\n' "$OUT_DIR"
cat "$OUT_DIR/p5a0-no-behavior-gate.tsv"
