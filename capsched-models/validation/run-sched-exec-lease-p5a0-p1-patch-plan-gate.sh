#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0
#
# Validate the P5A0.P1 patch-plan gate.
#
# This checker validates the plan contract only. It must fail if a Linux 0008
# patch already exists or if the plan tries to approve Linux behavior.

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_DIR=$(cd -- "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd -- "$REPO_DIR/.." && pwd)

LINUX_DIR=${DOMAINLEASE_LINUX_DIR:-"$WORKSPACE_DIR/linux"}
PATCHES_DIR=${DOMAINLEASE_LINUX_PATCHES_DIR:-"$WORKSPACE_DIR/linux-patches"}
ANALYSIS_CONFIG=${DOMAINLEASE_P5A0_P1_CONFIG:-"$REPO_DIR/capsched-models/analysis/sched-exec-lease-p5a0-p1-no-behavior-patch-plan-v1.json"}
IMPLEMENTATION_CONFIG=${DOMAINLEASE_P5A0_P1_IMPL_CONFIG:-"$REPO_DIR/capsched-models/implementation/sched-exec-lease-p5a0-p1-no-behavior-patch-plan-v1.json"}
OUT_ROOT=${DOMAINLEASE_P5A0_P1_OUT_ROOT:-"$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a0-p1-patch-plan-gate"}
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

require_array_len()
{
	local file=$1
	local array_expr=$2
	local expected=$3
	local actual

	actual=$(jq -r "$array_expr | length" "$file")
	[ "$actual" = "$expected" ] || \
		die "unexpected array length $array_expr in $file: got $actual expected $expected"
}

line_of()
{
	local file=$1
	local pattern=$2

	awk -v pat="$pattern" 'index($0, pat) { print NR; exit }' "$file"
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

require_cmd awk
require_cmd git
require_cmd grep
require_cmd jq
require_cmd wc

git -C "$LINUX_DIR" rev-parse --git-dir >/dev/null 2>&1 || \
	die "Linux Git tree not found: $LINUX_DIR"
git -C "$PATCHES_DIR" rev-parse --git-dir >/dev/null 2>&1 || \
	die "linux-patches Git tree not found: $PATCHES_DIR"
[ -f "$ANALYSIS_CONFIG" ] || die "missing analysis config: $ANALYSIS_CONFIG"
[ -f "$IMPLEMENTATION_CONFIG" ] || die "missing implementation config: $IMPLEMENTATION_CONFIG"

mkdir -p "$OUT_DIR"

expected_work_commit=$(jq -r '.source_basis.linux_commit' "$ANALYSIS_CONFIG")
actual_work_commit=$(git -C "$LINUX_DIR" rev-parse HEAD)
[ "$actual_work_commit" = "$expected_work_commit" ] || \
	die "Linux HEAD $actual_work_commit does not match contract $expected_work_commit"

if [ -n "$(git -C "$LINUX_DIR" status --porcelain)" ]; then
	git -C "$LINUX_DIR" status --short > "$OUT_DIR/linux-dirty-status.txt"
	die "Linux tree is dirty; P5A0.P1 plan gate expects no Linux edits"
fi

jq_string "$ANALYSIS_CONFIG" '.candidate.id' 'P5A0.P1'
jq_string "$ANALYSIS_CONFIG" '.candidate.mode' 'no_behavior_patch_plan_only'
jq_bool "$ANALYSIS_CONFIG" '.candidate.linux_patch_created' false
jq_bool "$ANALYSIS_CONFIG" '.candidate.linux_patch_approved' false
jq_string "$ANALYSIS_CONFIG" '.candidate.future_patch_queue_slot' '0008'
jq_string "$IMPLEMENTATION_CONFIG" '.candidate.id' 'P5A0.P1'
jq_bool "$IMPLEMENTATION_CONFIG" '.candidate.linux_patch_created' false
jq_bool "$IMPLEMENTATION_CONFIG" '.candidate.linux_patch_approved' false
jq_string "$IMPLEMENTATION_CONFIG" '.candidate.future_patch_queue_slot' '0008'

require_array_len "$ANALYSIS_CONFIG" '.file_allowlist' 2
require_array_len "$IMPLEMENTATION_CONFIG" '.file_allowlist' 2
for file in include/linux/sched_exec_lease.h kernel/sched/exec_lease.c; do
	require_array_value "$ANALYSIS_CONFIG" '.file_allowlist' "$file"
	require_array_value "$IMPLEMENTATION_CONFIG" '.file_allowlist' "$file"
done

for file in \
	include/linux/sched.h \
	kernel/sched/core.c \
	kernel/sched/sched.h \
	kernel/sched/fair.c \
	kernel/sched/rt.c \
	kernel/sched/deadline.c \
	kernel/sched/ext/ext.c \
	kernel/fork.c \
	fs/exec.c \
	kernel/exit.c \
	init/Kconfig \
	kernel/sched/Makefile
do
	require_array_value "$ANALYSIS_CONFIG" '.forbidden_files' "$file"
	require_array_value "$IMPLEMENTATION_CONFIG" '.forbidden_files' "$file"
done

jq_bool "$ANALYSIS_CONFIG" '.delta_scope.per_0008_delta_footprint_required' true
jq_bool "$ANALYSIS_CONFIG" '.delta_scope.whole_existing_queue_footprint_is_not_sufficient' true
jq_bool "$ANALYSIS_CONFIG" '.delta_scope.p5a0_p1_new_delta_must_remain_allowlisted' true
jq_bool "$IMPLEMENTATION_CONFIG" '.delta_scope.per_0008_delta_footprint_required' true
jq_bool "$IMPLEMENTATION_CONFIG" '.delta_scope.whole_existing_queue_footprint_is_not_sufficient' true
jq_bool "$IMPLEMENTATION_CONFIG" '.delta_scope.p5a0_p1_new_delta_must_remain_allowlisted' true

for helper in \
	sched_exec_lease_prepare_wake \
	sched_exec_lease_prepare_new_task \
	sched_exec_lease_note_queued_move \
	sched_exec_lease_observe_tick \
	sched_exec_lease_note_switch \
	sched_exec_lease_validate_run_edge \
	sched_exec_lease_validate_move_edge \
	sched_exec_lease_validate_move_edge_locked
do
	require_array_value "$ANALYSIS_CONFIG" '.frozen_hot_path_helpers' "$helper"
	require_array_value "$IMPLEMENTATION_CONFIG" '.frozen_hot_path_helpers' "$helper"
done

for helper in \
	sched_exec_task_reset \
	sched_exec_task_prepare_fork \
	sched_exec_task_commit_exec \
	sched_exec_task_exit
do
	require_array_value "$ANALYSIS_CONFIG" '.frozen_lifecycle_helpers' "$helper"
	require_array_value "$IMPLEMENTATION_CONFIG" '.frozen_lifecycle_helpers' "$helper"
done

for flag in \
	sched_exec_task_layout_change \
	task_struct_layout_change \
	rq_layout_change \
	sched_entity_layout_change \
	cfs_rq_layout_change \
	scheduler_callsite_change \
	hot_path_helper_body_change \
	lifecycle_helper_body_change \
	validation_result_consumption \
	runtime_constructor_added \
	global_runtime_state_added \
	external_layout_exposed \
	runtime_denial \
	non_allow_reachable \
	retry \
	fail_closed \
	quarantine \
	denied_receipt \
	runtime_status_publication \
	allocation \
	sleep_or_blocking_call \
	new_lock_or_refcount_transfer \
	static_key \
	tracepoint \
	printk \
	public_abi \
	non_static_symbol_added \
	exported_symbol \
	monitor_call \
	monitor_abi
do
	jq_bool "$ANALYSIS_CONFIG" ".forbidden_diff_classes.$flag" true
done

for flag in \
	sched_exec_task_layout_change \
	hot_path_helper_body_change \
	lifecycle_helper_body_change \
	validation_return_change \
	validation_result_consumption \
	runtime_constructor_added \
	global_runtime_state_added \
	external_layout_exposed \
	non_static_symbol_added \
	exported_symbol
do
	jq_bool "$IMPLEMENTATION_CONFIG" ".forbidden_delta_classes.$flag" true
done

for item in \
	recorded_base_commit \
	parent_work_commit \
	future_work_commit \
	future_0008_patch_file \
	future_0008_patch_sha256 \
	series_sha256 \
	linux_patches_commit \
	exact_current_upstream_ref \
	exact_current_upstream_commit \
	source_drift_run_id \
	merge_tree_result \
	replay_log_path \
	replayed_tree_diff_against_authored_candidate
do
	require_array_value "$ANALYSIS_CONFIG" '.future_acceptance_metadata_required' "$item"
done

for item in \
	per_0008_delta_footprint_manifest \
	patch_queue_replay_from_recorded_base \
	disposable_upstream_replay \
	upstream_merge_tree_check \
	checkpatch \
	source_checker \
	config_off_full_vmlinux_build \
	config_on_full_vmlinux_build \
	qemu_denial_disabled_boot_workload_smoke \
	object_symbol_disassembly_review \
	exec_lease_object_section_size_review \
	hot_scheduler_function_growth_review \
	task_rq_sched_entity_cfs_rq_layout_review \
	overclaim_security_review
do
	require_array_value "$ANALYSIS_CONFIG" '.future_acceptance_requirements' "$item"
	require_array_value "$IMPLEMENTATION_CONFIG" '.future_acceptance_requirements' "$item"
done

for flag in \
	linux_patch_approved \
	behavior_change_approved \
	runtime_denial_approved \
	runtime_coverage \
	public_abi \
	monitor_call \
	monitor_verified \
	production_protection \
	hypervisor_grade_isolation \
	cost_efficiency_claim \
	deployment_readiness \
	datacenter_readiness \
	global_all_angles_freshness
do
	jq_bool "$ANALYSIS_CONFIG" ".safety_flags.$flag" false
	jq_bool "$IMPLEMENTATION_CONFIG" ".safety_flags.$flag" false
done

evidence_run_dir="$WORKSPACE_DIR/$(jq -r '.evidence_basis.p5a0_e_source_check_run' "$ANALYSIS_CONFIG")"
evidence_result="$evidence_run_dir/result.json"
[ -f "$evidence_result" ] || die "missing P5A0.E evidence result: $evidence_result"
jq_bool "$evidence_result" '.candidate_groups_fresh' true
jq_bool "$evidence_result" '.non_candidate_device_queue_iommu_stale_recorded' true
jq_bool "$evidence_result" '.global_model_freshness' false
jq_bool "$evidence_result" '.linux_patch_approved' false
jq_bool "$evidence_result" '.helper_return_set_allow_only' true
jq_bool "$evidence_result" '.scheduler_branch_on_validation_result' false
jq_bool "$evidence_result" '.fair_picker_ineligibility' false
jq_bool "$evidence_result" '.run_hook_p5_deny_ready' false
jq_bool "$evidence_result" '.p5a0_p1_patch_approved' false
jq_bool "$evidence_result" '.runtime_denial' false
jq_bool "$evidence_result" '.production_or_cost_claim' false

patch_series="$PATCHES_DIR/patches/capsched-linux-l0/series"
[ -f "$patch_series" ] || die "missing patch series: $patch_series"
if find "$PATCHES_DIR/patches/capsched-linux-l0" -maxdepth 1 -type f -name '0008-*' \
	| grep -q .; then
	find "$PATCHES_DIR/patches/capsched-linux-l0" -maxdepth 1 -type f -name '0008-*' \
		> "$OUT_DIR/unexpected-0008-files.txt"
	die "P5A0.P1 plan gate found an existing 0008 patch"
fi
if grep -q '^0008-' "$patch_series"; then
	grep '^0008-' "$patch_series" > "$OUT_DIR/unexpected-0008-series.txt"
	die "P5A0.P1 plan gate found 0008 in series"
fi

base_txt="$PATCHES_DIR/upstream/base.txt"
[ -f "$base_txt" ] || die "missing base metadata: $base_txt"
grep -q "^work_commit=$actual_work_commit$" "$base_txt" || \
	die "base.txt work_commit does not match Linux HEAD"
grep -q '^base_commit=' "$base_txt" || die "base.txt missing base_commit"
grep -q '^remote=https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git$' "$base_txt" || \
	die "base.txt remote is not torvalds upstream"

header="$LINUX_DIR/include/linux/sched_exec_lease.h"
exec_lease_c="$LINUX_DIR/kernel/sched/exec_lease.c"
core="$LINUX_DIR/kernel/sched/core.c"
sched_h="$LINUX_DIR/kernel/sched/sched.h"
fair="$LINUX_DIR/kernel/sched/fair.c"
fork_c="$LINUX_DIR/kernel/fork.c"
exec_c="$LINUX_DIR/fs/exec.c"
exit_c="$LINUX_DIR/kernel/exit.c"

hot_helper_count=0
for helper in \
	sched_exec_lease_prepare_wake \
	sched_exec_lease_prepare_new_task \
	sched_exec_lease_note_queued_move \
	sched_exec_lease_observe_tick \
	sched_exec_lease_note_switch \
	sched_exec_lease_validate_run_edge \
	sched_exec_lease_validate_move_edge \
	sched_exec_lease_validate_move_edge_locked
do
	line=$(require_line "hot helper $helper" "$header" "$helper(")
	printf '%s\t%s\n' "$helper" "$line" >> "$OUT_DIR/hot-helper-lines.tsv"
	hot_helper_count=$((hot_helper_count + 1))
done
[ "$hot_helper_count" -eq 8 ] || die "unexpected hot helper count: $hot_helper_count"

validation_helper_count=0
for helper in \
	sched_exec_lease_validate_run_edge \
	sched_exec_lease_validate_move_edge \
	sched_exec_lease_validate_move_edge_locked
do
	line=$(require_line "validation helper $helper" "$header" "$helper(")
	return_line=$(awk -v start="$line" \
		'NR > start && index($0, "return SCHED_EXEC_VALIDATION_ALLOW;") { print NR; exit }' \
		"$header")
	[ -n "$return_line" ] || die "validation helper does not return ALLOW: $helper"
	printf '%s\t%s\t%s\n' "$helper" "$line" "$return_line" >> "$OUT_DIR/validation-helper-lines.tsv"
	validation_helper_count=$((validation_helper_count + 1))
done
[ "$validation_helper_count" -eq 3 ] || die "unexpected validation helper count: $validation_helper_count"

for forbidden in RETRY INELIGIBLE QUARANTINE; do
	if grep -RIn --include='*.c' --include='*.h' \
		"return[[:space:]]\\+SCHED_EXEC_VALIDATION_${forbidden};" \
		"$header" "$LINUX_DIR/kernel/sched" > "$OUT_DIR/forbidden-return-$forbidden.txt"; then
		die "found forbidden return: SCHED_EXEC_VALIDATION_${forbidden}"
	fi
done

if grep -RInE "if[[:space:]]*\\(.*sched_exec_lease_validate|switch[[:space:]]*\\(.*sched_exec_lease_validate|\\?.*sched_exec_lease_validate|sched_exec_lease_validate.*\\?" \
	"$LINUX_DIR/kernel/sched" "$header" > "$OUT_DIR/validation-branch-hits.txt"; then
	die "scheduler branches or ternary-depends on validation helper"
fi

validation_callsite_count=$(grep -RIn "sched_exec_lease_validate_.*edge" "$LINUX_DIR/kernel/sched" | wc -l)
[ "$validation_callsite_count" -eq 3 ] || \
	die "unexpected scheduler validation callsite count: $validation_callsite_count"

if grep -RIn "sched_exec_lease" "$fair" > "$OUT_DIR/fair-picker-sched-exec-hits.txt"; then
	die "fair picker contains sched_exec_lease hook; P5A0.P1 cannot claim CFS denial"
fi

lifecycle_helper_count=0
for helper in \
	sched_exec_task_reset \
	sched_exec_task_prepare_fork \
	sched_exec_task_commit_exec \
	sched_exec_task_exit
do
	line=$(require_line "lifecycle helper $helper" "$exec_lease_c" "$helper(")
	printf '%s\t%s\n' "$helper" "$line" >> "$OUT_DIR/lifecycle-helper-lines.tsv"
	lifecycle_helper_count=$((lifecycle_helper_count + 1))
done
[ "$lifecycle_helper_count" -eq 4 ] || \
	die "unexpected lifecycle helper count: $lifecycle_helper_count"

fork_reset_call=$(require_line "fork reset callsite" "$fork_c" "sched_exec_task_reset(tsk);")
fork_prepare_call=$(require_line "fork prepare_fork callsite" "$fork_c" "sched_exec_task_prepare_fork(p);")
exec_commit_call=$(require_line "exec commit callsite" "$exec_c" "sched_exec_task_commit_exec(me);")
exit_call=$(require_line "exit callsite" "$exit_c" "sched_exec_task_exit(tsk);")
printf 'fork_reset\t%s\nfork_prepare\t%s\nexec_commit\t%s\nexit\t%s\n' \
	"$fork_reset_call" "$fork_prepare_call" "$exec_commit_call" "$exit_call" \
	> "$OUT_DIR/lifecycle-callsite-lines.tsv"

for symbol in \
	SYSCALL_DEFINE \
	register_sysctl \
	proc_create \
	debugfs_create \
	TRACE_EVENT \
	EXPORT_SYMBOL \
	EXPORT_SYMBOL_GPL \
	DEFINE_STATIC_KEY \
	static_branch \
	printk \
	pr_warn \
	WARN_ON \
	kmalloc \
	kzalloc \
	vmalloc \
	msleep \
	schedule_timeout \
	refcount_inc \
	refcount_dec \
	mutex_lock \
	spin_lock
do
	if grep -RIn "$symbol" "$header" "$exec_lease_c" > "$OUT_DIR/forbidden-surface-$symbol.txt"; then
		die "found forbidden surface/API token in P5A0.P1 allowlist file: $symbol"
	fi
done

{
	printf 'property\tvalue\tevidence\n'
	printf 'work_commit_matches\ttrue\t%s\n' "$actual_work_commit"
	printf 'linux_tree_clean\ttrue\tgit-status\n'
	printf 'p5a0_p1_plan_recorded\ttrue\t%s\n' "$ANALYSIS_CONFIG"
	printf 'linux_patch_created\tfalse\tanalysis and implementation candidate flags\n'
	printf 'linux_patch_approved\tfalse\tanalysis and implementation candidate flags\n'
	printf 'future_0008_patch_exists\tfalse\t%s\n' "$patch_series"
	printf 'per_0008_delta_required\ttrue\tanalysis and implementation delta_scope\n'
	printf 'whole_queue_footprint_not_sufficient\ttrue\tanalysis and implementation delta_scope\n'
	printf 'file_allowlist_exact\ttrue\tinclude/linux/sched_exec_lease.h;kernel/sched/exec_lease.c\n'
	printf 'hot_path_helper_count\t%s\t%s\n' "$hot_helper_count" "$OUT_DIR/hot-helper-lines.tsv"
	printf 'validation_helper_count\t%s\t%s\n' "$validation_helper_count" "$OUT_DIR/validation-helper-lines.tsv"
	printf 'helper_return_set_allow_only\ttrue\t%s\n' "$header"
	printf 'scheduler_validation_callsite_count\t%s\tsource_grep\n' "$validation_callsite_count"
	printf 'scheduler_branch_on_validation_result\tfalse\tsource_grep\n'
	printf 'fair_picker_ineligibility\tfalse\t%s\n' "$fair"
	printf 'lifecycle_helper_count\t%s\t%s\n' "$lifecycle_helper_count" "$OUT_DIR/lifecycle-helper-lines.tsv"
	printf 'lifecycle_callsite_baseline_present\ttrue\tfork_exec_exit_grep\n'
	printf 'lifecycle_helper_body_change_allowed\tfalse\tplan forbidden delta classes\n'
	printf 'object_and_hot_function_growth_review_required\ttrue\tfuture acceptance requirements\n'
	printf 'layout_review_required\ttrue\tfuture acceptance requirements\n'
	printf 'runtime_denial_approved\tfalse\tsafety flags\n'
	printf 'public_abi_or_monitor\tfalse\tsafety flags\n'
	printf 'production_or_cost_claim\tfalse\tsafety flags\n'
	printf 'global_all_angles_freshness\tfalse\tsafety flags and P5A0.E evidence\n'
} > "$OUT_DIR/p5a0-p1-patch-plan-gate.tsv"

jq -n \
	--arg run_id "$RUN_ID" \
	--arg work_commit "$actual_work_commit" \
	--arg evidence_result "$evidence_result" \
	'{
	  schema_version: 1,
	  run_id: $run_id,
	  work_commit: $work_commit,
	  p5a0_p1_plan_recorded: true,
	  linux_tree_clean: true,
	  linux_patch_created: false,
	  linux_patch_approved: false,
	  future_0008_patch_exists: false,
	  per_0008_delta_required: true,
	  whole_queue_footprint_not_sufficient: true,
	  file_allowlist_exact: true,
	  hot_path_helper_count: 8,
	  validation_helper_count: 3,
	  helper_return_set_allow_only: true,
	  scheduler_validation_callsite_count: 3,
	  scheduler_branch_on_validation_result: false,
	  fair_picker_ineligibility: false,
	  lifecycle_helper_count: 4,
	  lifecycle_callsite_baseline_present: true,
	  lifecycle_helper_body_change_allowed: false,
	  object_and_hot_function_growth_review_required: true,
	  layout_review_required: true,
	  runtime_denial_approved: false,
	  public_abi_or_monitor: false,
	  production_or_cost_claim: false,
	  global_all_angles_freshness: false,
	  p5a0_e_evidence_result: $evidence_result
	}' > "$OUT_DIR/result.json"

printf '[domainlease] P5A0.P1 patch-plan gate check completed\n'
printf '[domainlease] run_dir=%s\n' "$OUT_DIR"
cat "$OUT_DIR/p5a0-p1-patch-plan-gate.tsv"
