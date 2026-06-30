# Validation 0078: Direct-Call Inventory Expansion Result

Status: Executed; source-only inventory broadened

Date: 2026-06-30

Runner:

```text
capsched/capsched-models/validation/run-direct-call-inventory.sh
```

Related artifacts:

```text
analysis/0077-direct-call-trace-source-inventory-contract.md
formal/0054-direct-call-inventory-contract-model/
validation/0076-direct-call-inventory-contract-tlc.md
validation/0077-direct-call-inventory-run-result.md
capsched-ai/decisions/ADR-0007-n-series-overlay-traceability.md
capsched-ai/decisions/ADR-0008-long-horizon-first-implementation.md
```

Run directory:

```text
/media/nia/scsiusb/dev/linux-cap/build/direct-call-inventory/20260630T230536Z
```

Output files:

```text
inventory-ledger.tsv
inventory-ledger.json
tracefs-plan.txt
semantic-gaps.tsv
summary.txt
metadata.txt
overlay-seed.json
```

## Result Summary

```text
ledger_rows=41
available_rows=34
future_gap_rows=6
trace_plan_rows=1
trace_event_rows=19
symbol_candidate_rows=12
gap_rows=7
safety_flag_violations=0
overlay_seed_rows=41
source_only=true
requires_privilege=false
writes_tracefs=false
attaches_probes=false
modifies_linux=false
public_tracepoint_abi=false
authority_claim=false
monitor_verified=false
protection_claim=false
```

Linux source:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
commit: 7cf0b1e415bcead8a2079c8be94a9d41aad7d462
```

## Expansion

The N-105 runner emitted 10 rows. N-106 keeps those rows and adds source-only
catalog rows for existing trace event declarations and symbol candidates.

Existing trace event declaration rows:

```text
sched/sched_waking
sched/sched_wakeup
sched/sched_wakeup_new
sched/sched_switch
sched/sched_process_fork
sched/sched_process_exec
sched/sched_process_exit
sched/sched_prepare_exec
workqueue/workqueue_queue_work
workqueue/workqueue_activate_work
workqueue/workqueue_execute_start
workqueue/workqueue_execute_end
raw_syscalls/sys_enter
raw_syscalls/sys_exit
timer/tick_stop
irq/irq_handler_entry
irq/softirq_entry
ipi/ipi_raise
task/task_newtask
```

Existing symbol candidate rows:

```text
kernel/sched/core.c:try_to_wake_up
kernel/sched/core.c:wake_up_new_task
kernel/sched/core.c:enqueue_task
kernel/sched/core.c:context_switch
kernel/sched/core.c:__schedule
kernel/sched/core.c:sched_tick
kernel/workqueue.c:queue_work_on
kernel/workqueue.c:process_one_work
kernel/workqueue.c:worker->current_func(work)
kernel/fork.c:copy_process
fs/exec.c:bprm_execve
kernel/exit.c:do_exit
```

All additional trace event and symbol candidate rows were source-observed.

## Overlay Seed

The runner now emits `overlay-seed.json`.

This is not the final central traceability ledger. It is a source-only seed that
maps each inventory row to:

```text
N-106
ADR-0007
ADR-0008
formal/0054
validation/0078
LINUX-DIRECTCALL-* rows
checked Linux commit
source path
symbol or pattern
blob oid when available
drift_status=ok or gap
```

Every overlay seed row preserves:

```text
authority_claim=false
monitor_verified=false
protection_claim=false
behavior_change=false
public_abi=false
```

## Gap Rows

The original future gaps remain:

```text
request_envelope_builder
direct_call_entry_shape
schema_negotiation_probe
response_handle_shadow_refresh
control_revoke_lane
failure_injection_surface
```

The trace catalog remains plan-only:

```text
trace_only_observation_surface:
  existing tracefs-plan suggestions only
  no tracefs execution
  no runtime observation claim
```

## Validated Claim

This run supports only:

```text
The source-only direct-call inventory can broaden existing Linux trace event
and symbol-candidate coverage, emit overlay seed rows, and preserve the N-104,
ADR-0007, and ADR-0008 safety boundaries without modifying Linux, requiring
root, writing tracefs, attaching probes, creating public tracepoint ABI, or
producing authority/protection claims.
```

It does not support:

```text
direct-call admission exists
monitor verification occurred
tracefs runtime coverage occurred
dynamic probes were attached
source anchors provide authority
missing anchors remove semantic obligations
Linux timeout has monitor meaning
public tracepoint ABI is approved
production protection exists
```

## Design Consequence

N-106 is satisfied as a source-only inventory expansion.

The next safe step is to turn `overlay-seed.json` into an explicit
drift-aware traceability ledger/checker that can be rerun after upstream Linux
updates. That next step must still treat source anchors as non-authoritative.
