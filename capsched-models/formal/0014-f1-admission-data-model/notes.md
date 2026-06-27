# F1 Admission Data Notes

Date: 2026-06-27

## Key Result

F1 is a validation and freeze point, not an authority-discovery point.

That implies:

```text
RunCap and SchedContext must already be reachable locally.
FrozenRunUse storage must already exist.
Domain and SchedContext epochs must be local scalar/atomic reads.
Placement must already be compiled into a local envelope.
Budget must be cheap to read or reserve.
```

TLC record:

```text
validation/0026-f1-admission-data-tlc.md
```

## Why Placement Is Required

F1 precedes `select_task_rq()`. After `TASK_WAKING`, ordinary failure is
forbidden. Therefore F1 must know that later CPU selection cannot escape the
grant.

The conservative first rule is:

```text
p->cpus_ptr subset of FrozenRunUse.allowed_cpus
```

This is too strong for final performance, but useful as a first safety rule.
Later placement-refresh modeling may allow weaker forms.

## Why Wake Queues Matter

`wake_q_add()` says the task must be ready to be woken at the add site because
the wake can happen immediately or later. Therefore generic delayed wake queues
cannot be the place where CapSched first discovers authority.

## Open Refinement

Next useful model:

```text
wait/block registration authority preparation
```

That model should answer how a blocking task carries resumable-run authority,
endpoint-derived wake authority, or service-domain wake authority into a later
generic wake path.
