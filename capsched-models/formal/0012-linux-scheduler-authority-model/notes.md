# LinuxSchedulerAuthority Notes

Date: 2026-06-27

## What This Model Adds

Compared with `formal/0002-runnable-lease-model`, this model adds an explicit
`Selected` state and a monitor-style `runToken` for active execution. That is
the important semantic split:

```text
Queued/FrozenRunUse:
  Linux has runnable custody.

Selected:
  scheduler class logic has chosen a task, but active execution is not
  committed.

Running:
  a run token is active for a CPU, domain epoch, task identity, and sched
  context.
```

This split matters because stale budget or epoch after pick must fail before
execution, not become a cross-Domain active context.

## Open Refinements

Required before implementation selection:

```text
1. Model failure after Linux writes TASK_WAKING and prove why it is forbidden
   without a rollback protocol.
2. Split root Domain budget from per-SchedContext budget.
3. Add same-Domain fast-path freshness rules for monitor-backed activation.
4. Add a bounded tick/NO_HZ overrun model.
5. Add class-specific selected-state refinements for CFS, RT, deadline,
   sched_ext, core scheduling, and proxy execution.
6. Refine fork/clone/exec identity generation rules after analysis/0029.
```

## Design Pressure Found

The model reinforces three design constraints:

```text
admission freeze may be fail-capable only before non-rollback Linux wake
mutation;

enqueue and selected-state checks are better treated as nofail assertions or
fail-closed deselection until class rollback is modeled;

active execution must be guarded by a token-like object separate from Linux
mutable task state.
```
