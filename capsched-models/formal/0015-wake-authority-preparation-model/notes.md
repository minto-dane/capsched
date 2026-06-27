# Wake Authority Preparation Notes

Date: 2026-06-27

## Key Result

The scheduler wake hot path cannot be the first authority-discovery point.

Authority preparation belongs at:

```text
ordinary block/register:
  task-local resumable-run state

futex/shared endpoint registration:
  waiter or endpoint-specific carrier before queueing

workqueue/kthread_work queueing:
  work item carrier, not worker task ambient authority

kernel service task creation:
  service-domain authority
```

TLC record:

```text
validation/0027-wake-authority-preparation-tlc.md
```

## Revocation Shape

If authority is revoked while blocked or after `wake_q_add()`:

```text
F1 rejects before TASK_WAKING
or selected/switch validation fails closed before execution
```

The model's safe path covers the first conservative form.

## Open Refinement

The model does not yet distinguish:

```text
shared futex endpoint authority
priority inheritance authority
signal ThreadControlCap
workqueue caller BudgetTicket
```

Those need separate models before implementation claims.
