# Scheduler Admission Failure Notes

Date: 2026-06-27

## Design Pressure

The model is small on purpose. It isolates one question:

```text
Can a fail-capable CapSched check happen after Linux writes TASK_WAKING?
```

The conservative answer is:

```text
No, not as an ordinary reject/return path.
```

The first acceptable design is:

```text
F1 admission freeze:
  fail before TASK_WAKING

F5 enqueue assertion:
  nofail assertion that a FrozenRunUse already exists
```

## What Was Not Modeled

Not modeled yet:

```text
RT/freezer saved_state
multiple concurrent wakers
on_cpu release/acquire details
task_rq_lock/task_call_func interactions
sched_ext queued wakeup policy
deadline non-contending accounting
actual class enqueue rollback
```

Those are refinements, not excuses to weaken the boundary.

## Next Refinement

The next useful refinement is probably:

```text
F1 data dependency model
```

Question:

```text
What exact CapSched data must already be available so the F1 check can freeze
without allocation, sleep, remote service calls, or monitor round trips under
p->pi_lock?
```
