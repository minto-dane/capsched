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
OVERLAY_SEED_JSON="$OUT_DIR/overlay-seed.json"

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

source_catalog_row()
{
	local row_id=$1
	local source_ref=$2
	local row_class=$3
	local inventory_class=$4
	local linux_anchor=$5
	local anchor_kind=$6
	local pattern=$7
	local trace_event=$8
	local dynamic_probe=$9
	local forbidden=${10}
	local next_step=${11}
	local gap_severity=${12}
	local available=false
	local confidence=missing_source_catalog_anchor
	local missing_reason="${inventory_class}_missing_or_pattern_not_found"
	local gap="$gap_severity"

	if file_has_pattern "$linux_anchor" "$pattern"; then
		available=true
		confidence=source_observed
		missing_reason=none
		gap=none
	fi

	emit_row \
		"$row_id" "$source_ref" "$row_class" "$inventory_class" "$linux_anchor" \
		"$anchor_kind" "$available" "$confidence" "$linux_anchor" \
		"$pattern" "$trace_event" "$dynamic_probe" \
		false false false \
		"$missing_reason" "$gap" true false \
		false false false false \
		false "$forbidden" "$next_step" none
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
		printf '%s\n' '- include/trace/events/syscalls.h'
		printf '%s\n' '- include/trace/events/timer.h'
		printf '%s\n' '- include/trace/events/irq.h'
		printf '%s\n' '- include/trace/events/ipi.h'
		printf '%s\n\n' '- include/trace/events/task.h'
		printf 'Candidate existing events for later operator-approved correlation:\n\n'
		printf '%s\n' '- sched/sched_waking'
		printf '%s\n' '- sched/sched_wakeup'
		printf '%s\n' '- sched/sched_wakeup_new'
		printf '%s\n' '- sched/sched_switch'
		printf '%s\n' '- sched/sched_process_fork'
		printf '%s\n' '- sched/sched_process_exec'
		printf '%s\n' '- sched/sched_process_exit'
		printf '%s\n' '- sched/sched_prepare_exec'
		printf '%s\n' '- workqueue/workqueue_queue_work'
		printf '%s\n' '- workqueue/workqueue_activate_work'
		printf '%s\n' '- workqueue/workqueue_execute_start'
		printf '%s\n' '- workqueue/workqueue_execute_end'
		printf '%s\n' '- raw_syscalls/sys_enter'
		printf '%s\n' '- raw_syscalls/sys_exit'
		printf '%s\n' '- timer/tick_stop'
		printf '%s\n' '- irq/irq_handler_entry'
		printf '%s\n' '- irq/softirq_entry'
		printf '%s\n' '- ipi/ipi_raise'
		printf '%s\n\n' '- task/task_newtask'
		printf 'Candidate existing dynamic-symbol probes for later operator-approved correlation:\n\n'
		printf '%s\n' '- kernel/sched/core.c:try_to_wake_up'
		printf '%s\n' '- kernel/sched/core.c:wake_up_new_task'
		printf '%s\n' '- kernel/sched/core.c:enqueue_task'
		printf '%s\n' '- kernel/sched/core.c:context_switch'
		printf '%s\n' '- kernel/sched/core.c:__schedule'
		printf '%s\n' '- kernel/sched/core.c:sched_tick'
		printf '%s\n' '- kernel/workqueue.c:queue_work_on'
		printf '%s\n' '- kernel/workqueue.c:process_one_work'
		printf '%s\n' '- kernel/workqueue.c:worker->current_func(work)'
		printf '%s\n' '- kernel/fork.c:copy_process'
		printf '%s\n' '- fs/exec.c:bprm_execve'
		printf '%s\n\n' '- kernel/exit.c:do_exit'
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
		printf 'adr_0007_overlay_traceability=true\n'
		printf 'adr_0008_long_horizon_first=true\n'
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
	LEDGER_TSV="$LEDGER_TSV" LEDGER_JSON="$LEDGER_JSON" GAPS_TSV="$GAPS_TSV" SUMMARY="$SUMMARY" OVERLAY_SEED_JSON="$OVERLAY_SEED_JSON" RUN_ID="$RUN_ID" LINUX_DIR="$LINUX_DIR" python3 - <<'PY'
import csv
import json
import os
import subprocess
from pathlib import Path

ledger_tsv = Path(os.environ["LEDGER_TSV"])
ledger_json = Path(os.environ["LEDGER_JSON"])
gaps_tsv = Path(os.environ["GAPS_TSV"])
summary = Path(os.environ["SUMMARY"])
overlay_seed_json = Path(os.environ["OVERLAY_SEED_JSON"])
linux_dir = Path(os.environ["LINUX_DIR"])
run_id = os.environ["RUN_ID"]

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

def git_output(args):
    return subprocess.check_output(["git", "-C", str(linux_dir)] + args, text=True).strip()

linux_head = git_output(["rev-parse", "HEAD"])
try:
    upstream_base = git_output(["rev-parse", "upstream/master"])
except subprocess.CalledProcessError:
    upstream_base = linux_head
mapped_on = f"{run_id[0:4]}-{run_id[4:6]}-{run_id[6:8]}"

overlay_rows = []
for row in rows:
    relation = "anchors" if row["anchor_available"] == "true" else "blocks"
    drift_status = "ok" if row["anchor_available"] == "true" else "gap"
    linux_anchor = {
        "linux_id": f'LINUX-DIRECTCALL-{row["row_id"].split("-")[-1]}',
        "upstream_base_commit": upstream_base,
        "work_commit": linux_head,
        "last_checked_commit": linux_head,
        "source_path": row["source_path"],
        "symbol_or_pattern": row["symbol_or_pattern"],
        "anchor_class": row["inventory_class"],
        "anchor_kind": row["anchor_kind"],
        "blob_oid": None,
        "drift_status": drift_status,
        "notes": row["missing_reason"],
    }
    if row["source_path"] != "none" and row["anchor_available"] == "true":
        try:
            linux_anchor["blob_oid"] = git_output(["rev-parse", f'HEAD:{row["source_path"]}'])
        except subprocess.CalledProcessError:
            linux_anchor["blob_oid"] = None

    overlay_rows.append({
        "row_id": f'overlay-{row["row_id"]}',
        "map_version": "v1",
        "mapped_on": mapped_on,
        "n_ids": ["N-106"],
        "artifact_paths": [
            "capsched-models/validation/run-direct-call-inventory.sh",
            "capsched-models/validation/0078-direct-call-inventory-expansion-result.md",
        ],
        "relation": relation,
        "evidence_class": "source_only",
        "semantic_ids": {
            "req": [],
            "thr": [],
            "inv": [],
            "des": ["ADR-0007", "ADR-0008"],
            "model": ["formal/0054-direct-call-inventory-contract-model"],
            "val": ["validation/0078-direct-call-inventory-expansion-result.md"],
            "linux": [linux_anchor["linux_id"]],
            "patch": [],
            "claim": [],
        },
        "long_horizon": {
            "target_layer": "L0",
            "long_horizon_invariant": "Linux source observations must remain non-authoritative placeholders for future monitor-backed direct-call receipts.",
            "future_monitor_responsibility": "HyperTag Monitor must own admission result, replay consume, ledger write, response handle, Domain epoch, and revoke ordering.",
            "linux_placeholder_status": "source_only",
            "forbidden_shortcuts": [row["forbidden_upgrade"]],
        },
        "linux_anchors": [linux_anchor],
        "supported_claims": [],
        "not_supported_claims": [
            "direct-call admission exists",
            "monitor verification occurred",
            "tracefs runtime coverage occurred",
            "source anchors provide authority",
            "missing anchors remove semantic obligations",
            "production protection exists",
        ],
        "safety_flags": {
            "authority_claim": False,
            "monitor_verified": False,
            "protection_claim": False,
            "behavior_change": False,
            "public_abi": False,
        },
        "confidence": "high" if row["anchor_available"] == "true" else "medium",
        "status": "active",
        "next_action": row["next_step"],
    })

overlay_seed_json.write_text(json.dumps(overlay_rows, indent=2, sort_keys=True) + "\n")

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
trace_event_rows = sum(1 for row in rows if row["inventory_class"] == "existing_trace_event_declaration")
symbol_candidate_rows = sum(1 for row in rows if row["inventory_class"] == "existing_symbol_candidate")

summary.write_text(
    "\n".join([
        f"ledger_rows={len(rows)}",
        f"available_rows={available_rows}",
        f"future_gap_rows={future_gap_rows}",
        f"trace_plan_rows={trace_plan_rows}",
        f"trace_event_rows={trace_event_rows}",
        f"symbol_candidate_rows={symbol_candidate_rows}",
        f"gap_rows={len(gap_rows)}",
        f"safety_flag_violations={len(safety_violations)}",
        f"overlay_seed_rows={len(overlay_rows)}",
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
	source_catalog_row direct-call-inventory-011 direct-call-attach-010 \
		sched_switch_trace_declaration existing_trace_event_declaration \
		include/trace/events/sched.h trace_event_declaration 'TRACE_EVENT(sched_switch' \
		sched/sched_switch none sched_switch_is_not_monitor_activation plan_only_trace_correlation medium
	source_catalog_row direct-call-inventory-012 direct-call-attach-010 \
		sched_waking_trace_declaration existing_trace_event_declaration \
		include/trace/events/sched.h trace_event_declaration 'DEFINE_EVENT(sched_wakeup_template, sched_waking' \
		sched/sched_waking none sched_waking_is_not_run_cap_authority plan_only_trace_correlation medium
	source_catalog_row direct-call-inventory-013 direct-call-attach-010 \
		sched_wakeup_trace_declaration existing_trace_event_declaration \
		include/trace/events/sched.h trace_event_declaration 'DEFINE_EVENT(sched_wakeup_template, sched_wakeup' \
		sched/sched_wakeup none sched_wakeup_is_not_run_cap_authority plan_only_trace_correlation medium
	source_catalog_row direct-call-inventory-014 direct-call-attach-010 \
		sched_wakeup_new_trace_declaration existing_trace_event_declaration \
		include/trace/events/sched.h trace_event_declaration 'DEFINE_EVENT(sched_wakeup_template, sched_wakeup_new' \
		sched/sched_wakeup_new none sched_wakeup_new_is_not_spawn_authority plan_only_trace_correlation medium
	source_catalog_row direct-call-inventory-015 direct-call-attach-010 \
		sched_process_fork_trace_declaration existing_trace_event_declaration \
		include/trace/events/sched.h trace_event_declaration 'TRACE_EVENT(sched_process_fork' \
		sched/sched_process_fork none fork_trace_is_not_spawn_authority plan_only_trace_correlation medium
	source_catalog_row direct-call-inventory-016 direct-call-attach-010 \
		sched_process_exec_trace_declaration existing_trace_event_declaration \
		include/trace/events/sched.h trace_event_declaration 'TRACE_EVENT(sched_process_exec' \
		sched/sched_process_exec none exec_trace_is_not_domain_change_authority plan_only_trace_correlation medium
	source_catalog_row direct-call-inventory-017 direct-call-attach-010 \
		sched_process_exit_trace_declaration existing_trace_event_declaration \
		include/trace/events/sched.h trace_event_declaration 'TRACE_EVENT(sched_process_exit' \
		sched/sched_process_exit none exit_trace_is_not_thread_control_authority plan_only_trace_correlation medium
	source_catalog_row direct-call-inventory-018 direct-call-attach-010 \
		sched_prepare_exec_trace_declaration existing_trace_event_declaration \
		include/trace/events/sched.h trace_event_declaration 'TRACE_EVENT(sched_prepare_exec' \
		sched/sched_prepare_exec none prepare_exec_trace_is_not_schema_or_domain_authority plan_only_trace_correlation medium
	source_catalog_row direct-call-inventory-019 direct-call-attach-010 \
		workqueue_queue_work_trace_declaration existing_trace_event_declaration \
		include/trace/events/workqueue.h trace_event_declaration 'TRACE_EVENT(workqueue_queue_work' \
		workqueue/workqueue_queue_work none queue_work_trace_is_not_async_authority plan_only_trace_correlation medium
	source_catalog_row direct-call-inventory-020 direct-call-attach-010 \
		workqueue_activate_work_trace_declaration existing_trace_event_declaration \
		include/trace/events/workqueue.h trace_event_declaration 'TRACE_EVENT(workqueue_activate_work' \
		workqueue/workqueue_activate_work none activate_work_trace_is_not_budget_ticket_authority plan_only_trace_correlation medium
	source_catalog_row direct-call-inventory-021 direct-call-attach-010 \
		workqueue_execute_start_trace_declaration existing_trace_event_declaration \
		include/trace/events/workqueue.h trace_event_declaration 'TRACE_EVENT(workqueue_execute_start' \
		workqueue/workqueue_execute_start none execute_start_trace_is_not_caller_provenance plan_only_trace_correlation medium
	source_catalog_row direct-call-inventory-022 direct-call-attach-010 \
		workqueue_execute_end_trace_declaration existing_trace_event_declaration \
		include/trace/events/workqueue.h trace_event_declaration 'TRACE_EVENT(workqueue_execute_end' \
		workqueue/workqueue_execute_end none execute_end_trace_is_not_settlement_authority plan_only_trace_correlation medium
	source_catalog_row direct-call-inventory-023 direct-call-attach-010 \
		raw_syscalls_enter_trace_declaration existing_trace_event_declaration \
		include/trace/events/syscalls.h trace_event_declaration 'TRACE_EVENT_SYSCALL(sys_enter' \
		raw_syscalls/sys_enter none syscall_trace_is_not_endpoint_authority plan_only_trace_correlation medium
	source_catalog_row direct-call-inventory-024 direct-call-attach-010 \
		raw_syscalls_exit_trace_declaration existing_trace_event_declaration \
		include/trace/events/syscalls.h trace_event_declaration 'TRACE_EVENT_SYSCALL(sys_exit' \
		raw_syscalls/sys_exit none syscall_trace_is_not_monitor_response plan_only_trace_correlation medium
	source_catalog_row direct-call-inventory-025 direct-call-attach-010 \
		tick_stop_trace_declaration existing_trace_event_declaration \
		include/trace/events/timer.h trace_event_declaration 'TRACE_EVENT(tick_stop' \
		timer/tick_stop none tick_trace_is_not_root_budget_authority plan_only_trace_correlation medium
	source_catalog_row direct-call-inventory-026 direct-call-attach-010 \
		irq_handler_entry_trace_declaration existing_trace_event_declaration \
		include/trace/events/irq.h trace_event_declaration 'TRACE_EVENT(irq_handler_entry' \
		irq/irq_handler_entry none irq_trace_is_not_irq_route_authority plan_only_trace_correlation medium
	source_catalog_row direct-call-inventory-027 direct-call-attach-010 \
		softirq_entry_trace_declaration existing_trace_event_declaration \
		include/trace/events/irq.h trace_event_declaration 'DEFINE_EVENT(softirq, softirq_entry' \
		irq/softirq_entry none softirq_trace_is_not_async_provenance plan_only_trace_correlation medium
	source_catalog_row direct-call-inventory-028 direct-call-attach-010 \
		ipi_raise_trace_declaration existing_trace_event_declaration \
		include/trace/events/ipi.h trace_event_declaration 'TRACE_EVENT(ipi_raise' \
		ipi/ipi_raise none ipi_trace_is_not_cross_cpu_authority plan_only_trace_correlation medium
	source_catalog_row direct-call-inventory-029 direct-call-attach-010 \
		task_newtask_trace_declaration existing_trace_event_declaration \
		include/trace/events/task.h trace_event_declaration 'TRACE_EVENT(task_newtask' \
		task/task_newtask none task_newtask_trace_is_not_spawn_authority plan_only_trace_correlation medium
	source_catalog_row direct-call-inventory-030 direct-call-attach-010 \
		try_to_wake_up_symbol_candidate existing_symbol_candidate \
		kernel/sched/core.c function_symbol 'int try_to_wake_up(struct task_struct *p' \
		none future_operator_approved_kprobe_or_fprobe_candidate_only try_to_wake_up_symbol_is_not_run_cap_authority plan_only_symbol_correlation medium
	source_catalog_row direct-call-inventory-031 direct-call-attach-010 \
		wake_up_new_task_symbol_candidate existing_symbol_candidate \
		kernel/sched/core.c function_symbol 'void wake_up_new_task(struct task_struct *p)' \
		none future_operator_approved_kprobe_or_fprobe_candidate_only wake_up_new_task_symbol_is_not_spawn_authority plan_only_symbol_correlation medium
	source_catalog_row direct-call-inventory-032 direct-call-attach-010 \
		enqueue_task_symbol_candidate existing_symbol_candidate \
		kernel/sched/core.c function_symbol 'void enqueue_task(struct rq *rq, struct task_struct *p, int flags)' \
		none future_operator_approved_kprobe_or_fprobe_candidate_only enqueue_task_symbol_is_not_enqueue_authority plan_only_symbol_correlation medium
	source_catalog_row direct-call-inventory-033 direct-call-attach-010 \
		context_switch_symbol_candidate existing_symbol_candidate \
		kernel/sched/core.c function_symbol 'context_switch(struct rq *rq, struct task_struct *prev,' \
		none future_operator_approved_kprobe_or_fprobe_candidate_only context_switch_symbol_is_not_monitor_activation plan_only_symbol_correlation medium
	source_catalog_row direct-call-inventory-034 direct-call-attach-010 \
		__schedule_symbol_candidate existing_symbol_candidate \
		kernel/sched/core.c function_symbol 'static void __sched notrace __schedule(int sched_mode)' \
		none future_operator_approved_kprobe_or_fprobe_candidate_only __schedule_symbol_is_not_pick_authority plan_only_symbol_correlation medium
	source_catalog_row direct-call-inventory-035 direct-call-attach-010 \
		sched_tick_symbol_candidate existing_symbol_candidate \
		kernel/sched/core.c function_symbol 'void sched_tick(void)' \
		none future_operator_approved_kprobe_or_fprobe_candidate_only sched_tick_symbol_is_not_root_budget_authority plan_only_symbol_correlation medium
	source_catalog_row direct-call-inventory-036 direct-call-attach-010 \
		queue_work_on_symbol_candidate existing_symbol_candidate \
		kernel/workqueue.c function_symbol 'bool queue_work_on(int cpu, struct workqueue_struct *wq,' \
		none future_operator_approved_kprobe_or_fprobe_candidate_only queue_work_on_symbol_is_not_budget_ticket_authority plan_only_symbol_correlation medium
	source_catalog_row direct-call-inventory-037 direct-call-attach-010 \
		process_one_work_symbol_candidate existing_symbol_candidate \
		kernel/workqueue.c function_symbol 'static void process_one_work(struct worker *worker, struct work_struct *work)' \
		none future_operator_approved_kprobe_or_fprobe_candidate_only process_one_work_symbol_is_not_caller_authority plan_only_symbol_correlation medium
	source_catalog_row direct-call-inventory-038 direct-call-attach-010 \
		worker_current_func_call_candidate existing_symbol_candidate \
		kernel/workqueue.c call_site 'worker->current_func(work);' \
		none future_operator_approved_kprobe_or_fprobe_candidate_only worker_func_call_is_not_caller_provenance plan_only_symbol_correlation medium
	source_catalog_row direct-call-inventory-039 direct-call-attach-010 \
		copy_process_symbol_candidate existing_symbol_candidate \
		kernel/fork.c function_symbol '__latent_entropy struct task_struct *copy_process(' \
		none future_operator_approved_kprobe_or_fprobe_candidate_only copy_process_symbol_is_not_spawn_authority plan_only_symbol_correlation medium
	source_catalog_row direct-call-inventory-040 direct-call-attach-010 \
		bprm_execve_symbol_candidate existing_symbol_candidate \
		fs/exec.c function_symbol 'static int bprm_execve(struct linux_binprm *bprm)' \
		none future_operator_approved_kprobe_or_fprobe_candidate_only bprm_execve_symbol_is_not_domain_change_authority plan_only_symbol_correlation medium
	source_catalog_row direct-call-inventory-041 direct-call-attach-010 \
		do_exit_symbol_candidate existing_symbol_candidate \
		kernel/exit.c function_symbol 'void __noreturn do_exit(long code)' \
		none future_operator_approved_kprobe_or_fprobe_candidate_only do_exit_symbol_is_not_thread_control_authority plan_only_symbol_correlation medium
	write_tracefs_plan
	postprocess

	after_head=$(git -C "$LINUX_DIR" rev-parse HEAD)
	after_status=$(git -C "$LINUX_DIR" status --short)
	[ "$before_head" = "$after_head" ] || die "Linux HEAD changed"
	[ "$before_status" = "$after_status" ] || die "Linux working tree status changed"

	printf 'Direct-call inventory written to %s\n' "$OUT_DIR"
}

main "$@"
