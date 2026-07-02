# P5A0.P1 Patch Plan Gate Model

Status: checked plan gate; no Linux patch is approved.

This model records the narrow conditions under which a future P5A0.P1 patch is
reviewable. It is not a behavior model and it is not a Linux-code approval
gate.

The safe configuration requires:

- P5A0.E evidence exists and remains candidate-scoped, not globally fresh.
- The future patch identity and future queue slot `0008` are recorded.
- The future P5A0.P1 delta is scoped to `include/linux/sched_exec_lease.h` and
  `kernel/sched/exec_lease.c`.
- The future checker must inspect the `0008` delta, not the whole existing
  queue footprint.
- Scheduler control-flow and lifecycle files require a scope reopen.
- Header hot-path helpers and lifecycle helper bodies remain frozen.
- No Linux patch/code approval, behavior change, non-ALLOW path, scheduler
  branch, runtime denial, retry, fail-closed, quarantine, public ABI, monitor
  ABI, allocation, sleep, lock/refcount transfer, tracepoint, static key,
  printk, object/layout impact, or production/cost/datacenter claim is made.

The safe spec uses weak fairness plus `PlanRecordedEventually` so the model
cannot pass by staying forever in `Start`.

The unsafe configurations are expected to fail `Safety`.
