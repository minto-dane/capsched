# Formal 0017: Workqueue BudgetTicket Carrier Model

Status: Draft bounded carrier lifecycle model

Date: 2026-06-27

Related analysis:

```text
capsched/capsched-models/analysis/0034-workqueue-kthread-budgetticket-carrier.md
```

## Purpose

This model checks the local authority carrier requirements for
Domain-derived workqueue and kthread_work execution:

```text
prepare caller authority and BudgetTicket
queue work or delayed work
timer-fire into queued work
dispatch to worker
complete, cancel, or revoke
```

It does not model full workqueue pool concurrency, rescuer batching, CPU
affinity, memory reclaim, all flush barriers, or subsystem-specific merge
semantics.

## Checked Invariants

```text
NoWorkQueueWithoutCarrier:
  Domain-derived work cannot become queued, delayed, or pending without a
  prepared carrier.

NoRunWithoutBudgetTicket:
  running caller-derived work requires a live BudgetTicket and frozen endpoint
  use.

NoRunAfterCallerRevoke:
  running caller-derived work requires live caller and service epochs.

NoWorkerAmbientAuthority:
  worker task authority alone is never an authorization source.

NoCarrierOverwriteWhilePending:
  pending work cannot have its carrier overwritten unless explicit merge
  semantics are modeled.

NoDeadCarrierRefs:
  completed, canceled, or revoked work cannot retain authority-bearing refs.
```

## TLC Configurations

```text
WorkqueueCarrierSafe.cfg
WorkqueueCarrierUnsafeNoCarrier.cfg
WorkqueueCarrierUnsafeAmbient.cfg
WorkqueueCarrierUnsafeRevoke.cfg
WorkqueueCarrierUnsafeOverwrite.cfg
WorkqueueCarrierUnsafeDeadRefs.cfg
```

The safe configuration must pass. Unsafe configurations intentionally include
one bad transition each and should fail the named target invariant.
