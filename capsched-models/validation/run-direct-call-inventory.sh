#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0
#
# Source-only direct-call trace/source inventory runner.
#
# This runner implements the N-104 contract:
# - no Linux source modification
# - no root requirement
# - no tracefs writes
# - no probe or BPF attachment
# - no public tracepoint ABI creation
# - no authority, monitor-verification, or protection claims

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_DIR=$(cd -- "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd -- "$REPO_DIR/.." && pwd)
LINUX_DIR=${CAPSCHED_LINUX_DIR:-"$WORKSPACE_DIR/linux"}
OUT_ROOT=${CAPSCHED_DIRECT_CALL_INVENTORY_OUT:-"$WORKSPACE_DIR/build/direct-call-inventory"}
RUN_ID=${CAPSCHED_RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
OUT_DIR="$OUT_ROOT/$RUN_ID"

LEDGER_TSV="$OUT_DIR/inventory-ledger.tsv"
LEDGER_JSON="$OUT_DIR/inventory-ledger.json"
TRACEFS_PLAN="$OUT_DIR/tracefs-plan.txt"
GAPS_TSV="$OUT_DIR/semantic-gaps.tsv"
SUMMARY="$OUT_DIR/summary.txt"
METADATA="$OUT_DIR/metadata.txt"

die()
{
	printf 'error: %s\n' "$*" >&2
	exit 1
}

require_linux_tree()
{
	[ -d "$LINUX_DIR" ] || die "Linux tree not found: $LINUX_DIR"
	[ -d "$LINUX_DIR/.git" ] || die "Linux tree is not a Git repository: $LINUX_DIR"
}

file_has_pattern()
{
	local rel=$1
	local pattern=$2
	[ -f "$LINUX_DIR/$rel" ] || return 1
	grep -F -q -- "$pattern" "$LINUX_DIR/$rel"
}

file_exists()
{
	local rel=$1
	[ -f "$LINUX_DIR/$rel" ]
}

emit_header()
{
	printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
		row_id source_row_ref row_class inventory_class linux_anchor \
		anchor_kind anchor_available anchor_confidence source_path \
		symbol_or_pattern trace_event dynamic_probe_candidate \
		requires_privilege runtime_observation_required observed_now \
		missing_reason gap_severity observation_only authority_claim \
		monitor_verified behavior_change user_abi public_tracepoint_abi \
		protection_claim forbidden_upgrade next_step code > "$LEDGER_TSV"
}

emit_row()
{
	printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$@" >> "$LEDGER_TSV"
}

current_row()
{
	local row_id=$1
	local source_ref=$2
	local row_class=$3
	local linux_anchor=$4
	local pattern=$5
	local forbidden=$6
	local available=false
	local confidence=missing_current_anchor
	local missing_reason="current_anchor_missing_or_pattern_not_found"
	local gap=high

	if file_has_pattern "$linux_anchor" "$pattern"; then
		available=true
		confidence=source_observed
		missing_reason=none
		gap=none
	fi

	emit_row \
		"$row_id" "$source_ref" "$row_class" current_source_anchor "$linux_anchor" \
		current_source_file "$available" "$confidence" "$linux_anchor" \
		"$pattern" none none \
		false false false \
		"$missing_reason" "$gap" true false \
		false false false false \
		false "$forbidden" source_inventory_only none
}

future_gap_row()
{
	local row_id=$1
	local source_ref=$2
	local row_class=$3
	local linux_anchor=$4
	local reason=$5
	local severity=$6
	local forbidden=$7
	local next_step=$8

	emit_row \
		"$row_id" "$source_ref" "$row_class" future_gap "$linux_anchor" \
		future_gap false gap_recorded none \
		none none none \
		false false false \
		"$reason" "$severity" true false \
		false false false false \
		false "$forbidden" "$next_step" none
}

trace_plan_row()
{
	local source_path=include/trace/events/sched.h
	local available=false
	local confidence=gap_recorded
	local pattern=TRACE_EVENT
	local missing_reason=existing_sched_trace_event_catalog_not_found

	if file_exists "$source_path"; then
		available=partial_plan_only
		confidence=plan_only
		missing_reason=runtime_tracefs_execution_requires_separate_validation
	fi

	emit_row \
		direct-call-inventory-010 direct-call-attach-010 trace_only_observation_surface \
		trace_catalog_plan existing_ftrace_kprobe_tracefs_where_possible \
		existing_trace_catalog_plan "$available" "$confidence" "$source_path" \
		"$pattern" existing_events_only future_operator_approved_candidates_only \
		false false false \
		"$missing_reason" medium true false \
		false false false false \
		false trace_observation_or_new_tracepoint_abi_is_not_authority emit_tracefs_plan_only none
}

write_tracefs_plan()
{
	{
		printf '# Direct-call inventory tracefs plan\n\n'
		printf 'Status: plan only, not executed\n\n'
		printf 'This file names existing trace surfaces that a later privileged validation may inspect.\n'
		printf 'The runner did not write tracefs, attach probes, load BPF, or run a workload.\n\n'
		printf 'Existing source catalog checked:\n\n'
		printf '%s\n' '- include/trace/events/sched.h'
		printf '%s\n' '- include/trace/events/workqueue.h'
		printf '%s\n\n' '- include/trace/events/syscalls.h'
		printf 'Candidate existing events for later operator-approved correlation:\n\n'
		printf '%s\n' '- sched/sched_switch'
		printf '%s\n' '- sched/sched_process_fork'
		printf '%s\n' '- sched/sched_process_exec'
		printf '%s\n' '- sched/sched_process_exit'
		printf '%s\n' '- workqueue/workqueue_queue_work'
		printf '%s\n' '- workqueue/workqueue_execute_start'
		printf '%s\n' '- raw_syscalls/sys_enter'
		printf '%s\n\n' '- raw_syscalls/sys_exit'
		printf 'Forbidden interpretation:\n\n'
		printf '%s\n' '- existing trace events are not direct-call authority'
		printf '%s\n' '- this plan is not runtime coverage'
		printf '%s\n' '- no new public tracepoint ABI is created here'
	} > "$TRACEFS_PLAN"
}

write_metadata()
{
	local head
	local branch
	head=$(git -C "$LINUX_DIR" rev-parse HEAD)
	branch=$(git -C "$LINUX_DIR" branch --show-current)

	{
		printf 'runner=run-direct-call-inventory.sh\n'
		printf 'run_id=%s\n' "$RUN_ID"
		printf 'linux_dir=%s\n' "$LINUX_DIR"
		printf 'linux_branch=%s\n' "$branch"
		printf 'linux_head=%s\n' "$head"
		printf 'source_only=true\n'
		printf 'requires_privilege=false\n'
		printf 'writes_tracefs=false\n'
		printf 'attaches_probes=false\n'
		printf 'modifies_linux=false\n'
		printf 'public_tracepoint_abi=false\n'
	} > "$METADATA"
}

postprocess()
{
	LEDGER_TSV="$LEDGER_TSV" LEDGER_JSON="$LEDGER_JSON" GAPS_TSV="$GAPS_TSV" SUMMARY="$SUMMARY" python3 - <<'PY'
import csv
import json
import os
from pathlib import Path

ledger_tsv = Path(os.environ["LEDGER_TSV"])
ledger_json = Path(os.environ["LEDGER_JSON"])
gaps_tsv = Path(os.environ["GAPS_TSV"])
summary = Path(os.environ["SUMMARY"])

rows = list(csv.DictReader(ledger_tsv.open(), delimiter="\t"))

required_flags = {
    "observation_only": "true",
    "authority_claim": "false",
    "monitor_verified": "false",
    "behavior_change": "false",
    "user_abi": "false",
    "public_tracepoint_abi": "false",
    "protection_claim": "false",
}
source_only_defaults = {
    "requires_privilege": "false",
    "runtime_observation_required": "false",
    "observed_now": "false",
}

safety_violations = []
for row in rows:
    for key, expected in required_flags.items():
        if row[key] != expected:
            safety_violations.append((row["row_id"], key, row[key], expected))
    for key, expected in source_only_defaults.items():
        if row[key] != expected:
            safety_violations.append((row["row_id"], key, row[key], expected))

ledger_json.write_text(json.dumps(rows, indent=2, sort_keys=True) + "\n")

gap_rows = [
    row for row in rows
    if row["gap_severity"] != "none" or row["anchor_available"] in {"false", "partial_plan_only"}
]
with gaps_tsv.open("w", newline="") as f:
    writer = csv.writer(f, delimiter="\t")
    writer.writerow(["row_id", "row_class", "linux_anchor", "gap_severity", "missing_reason", "next_step"])
    for row in gap_rows:
        writer.writerow([
            row["row_id"],
            row["row_class"],
            row["linux_anchor"],
            row["gap_severity"],
            row["missing_reason"],
            row["next_step"],
        ])

available_rows = sum(1 for row in rows if row["anchor_available"] == "true")
future_gap_rows = sum(1 for row in rows if row["inventory_class"] == "future_gap")
trace_plan_rows = sum(1 for row in rows if row["inventory_class"] == "trace_catalog_plan")

summary.write_text(
    "\n".join([
        f"ledger_rows={len(rows)}",
        f"available_rows={available_rows}",
        f"future_gap_rows={future_gap_rows}",
        f"trace_plan_rows={trace_plan_rows}",
        f"gap_rows={len(gap_rows)}",
        f"safety_flag_violations={len(safety_violations)}",
        "source_only=true",
        "requires_privilege=false",
        "writes_tracefs=false",
        "attaches_probes=false",
        "modifies_linux=false",
        "public_tracepoint_abi=false",
        "authority_claim=false",
        "monitor_verified=false",
        "protection_claim=false",
    ]) + "\n"
)

if safety_violations:
    for row_id, key, actual, expected in safety_violations:
        print(f"safety violation: {row_id} {key}={actual} expected={expected}", flush=True)
    raise SystemExit(2)
PY
}

main()
{
	require_linux_tree
	mkdir -p "$OUT_DIR"

	local before_head
	local after_head
	local before_status
	local after_status
	before_head=$(git -C "$LINUX_DIR" rev-parse HEAD)
	before_status=$(git -C "$LINUX_DIR" status --short)

	write_metadata
	emit_header
	current_row direct-call-inventory-001 direct-call-attach-001 \
		capsched_type_namespace include/linux/capsched.h "struct capsched_domain" \
		capsched_opaque_ids_are_not_monitor_receipts
	current_row direct-call-inventory-002 direct-call-attach-002 \
		capsched_internal_translation_unit kernel/sched/capsched.c "intentionally inert" \
		inert_translation_unit_is_not_direct_call_authority
	current_row direct-call-inventory-003 direct-call-attach-003 \
		capsched_build_gate kernel/sched/Makefile 'obj-$(CONFIG_CAPSCHED) += capsched.o' \
		build_visibility_is_not_behavior_approval
	future_gap_row direct-call-inventory-004 direct-call-attach-004 \
		request_envelope_builder future_internal_helper_not_user_abi \
		no_approved_direct_call_request_envelope_helper_exists high \
		linux_built_envelope_is_not_canonical_monitor_image design_only_before_stub
	future_gap_row direct-call-inventory-005 direct-call-attach-005 \
		direct_call_entry_shape future_arch_independent_wrapper_plus_arch_backend \
		no_approved_direct_call_entry_wrapper_or_arch_backend_exists high \
		wrapper_return_is_not_monitor_approval design_only_before_stub
	future_gap_row direct-call-inventory-006 direct-call-attach-006 \
		schema_negotiation_probe future_internal_query_path \
		no_approved_schema_negotiation_query_path_exists high \
		linux_cannot_decide_schema_acceptance design_only_before_stub
	future_gap_row direct-call-inventory-007 direct-call-attach-007 \
		response_handle_shadow_refresh future_internal_query_cache_path \
		no_approved_monitor_backed_response_handle_shadow_refresh_path_exists high \
		timeout_or_return_code_cannot_refresh_shadow_authority design_only_before_stub
	future_gap_row direct-call-inventory-008 direct-call-attach-008 \
		control_revoke_lane future_internal_control_path \
		no_approved_control_revoke_lane_exists high \
		control_priority_cannot_bypass_replay_budget_or_epoch design_only_before_stub
	future_gap_row direct-call-inventory-009 direct-call-attach-009 \
		failure_injection_surface future_test_only_fault_injection_or_kunit_style_surface \
		no_approved_test_only_failure_injection_surface_exists medium \
		fault_injection_cannot_change_live_decisions test_plan_only_before_stub
	trace_plan_row
	write_tracefs_plan
	postprocess

	after_head=$(git -C "$LINUX_DIR" rev-parse HEAD)
	after_status=$(git -C "$LINUX_DIR" status --short)
	[ "$before_head" = "$after_head" ] || die "Linux HEAD changed"
	[ "$before_status" = "$after_status" ] || die "Linux working tree status changed"

	printf 'Direct-call inventory written to %s\n' "$OUT_DIR"
}

main "$@"
