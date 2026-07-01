# Exit/Revoke Pending Authority Drain Gate Model

Status: Checked with safe pass and expected unsafe counterexamples

Date: 2026-07-01

## Purpose

This model is the N-150 integration gate for exit and revoke completion.

It is not another local scheduler, workqueue, io_uring, endpoint, admission,
device, or budget model. It defines the global completion predicate:

```text
embargo old-epoch authority
  -> enumerate pending authority with complete identity keys
  -> drain, reject, quarantine, or settle every known carrier family
  -> revoke derived receipts and Linux shadows
  -> settle refs, locks, tickets, and root execution exactly once
  -> only then mark exit/revoke complete
```

Unknown carrier kinds do not default to drained.

## Covered Pending Authority Families

The model treats the following as separate carrier families:

```text
scheduler:
  queued FrozenRunUse
  selected FrozenRunUse
  denied candidate
  move tuple
  wake_q / remote wake entry

async:
  task_work
  workqueue / kthread / delayed work
  io_uring / io-wq / task_work fallback
  timer callback
  RCU callback
  softirq/completion-style carrier

resource:
  endpoint use
  direct-call monitor admission request/response
  monitor-owned ring slot/response
  derived receipt or Linux shadow

device:
  QueueLease submit/descriptor/DMA/completion/control/service-work carrier

budget/root:
  caller BudgetTicket reservation
  server borrow ticket
  monitor root timer or RunToken

unknown:
  any carrier class not represented in the inventory key set
```

## Model Boundary

Linux cleanup operations can be synchronization or implementation clues, but
they are not authority receipts in this model:

```text
cancel_work_sync()
flush_work()
work pending-bit clear
task_work_add() failure
io_uring cancel/free/CQE
timer delete/shutdown
rcu_barrier()
trace/audit rows
PID/TGID reuse
RCU visibility
```

## Validation

Safe config:

```text
ExitRevokePendingAuthorityDrainGateSafe.cfg
```

Unsafe configs:

```text
ExitRevokePendingAuthorityDrainGateUnsafe*.cfg
```

The validation record is:

```text
validation/0121-exit-revoke-pending-authority-drain-gate-tlc.md
```

## Non-Claims

This model does not approve Linux implementation, hook placement, public ABI,
task fields, carrier structs, endpoint structs, monitor ABI, runtime coverage,
behavior changes, monitor verification, or production protection.
