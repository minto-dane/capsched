# Validation 0029: Workqueue BudgetTicket Carrier TLC

Status: Completed bounded model check

Date: 2026-06-27

Model:

```text
capsched/capsched-models/formal/0017-workqueue-budgetticket-carrier-model/WorkqueueCarrier.tla
```

Related analysis:

```text
capsched/capsched-models/analysis/0034-workqueue-kthread-budgetticket-carrier.md
```

TLC logs:

```text
/media/nia/scsiusb/dev/linux-cap/build/tlc/workqueue-carrier-20260627T081045Z/WorkqueueCarrierSafe.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/workqueue-carrier-20260627T081045Z/WorkqueueCarrierUnsafeNoCarrier.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/workqueue-carrier-20260627T081045Z/WorkqueueCarrierUnsafeAmbient.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/workqueue-carrier-20260627T081045Z/WorkqueueCarrierUnsafeRevoke.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/workqueue-carrier-20260627T081045Z/WorkqueueCarrierUnsafeOverwrite.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/workqueue-carrier-20260627T081045Z/WorkqueueCarrierUnsafeDeadRefs.log
```

## Result Summary

Safe configuration:

```text
config: WorkqueueCarrierSafe.cfg
result: PASS
generated states: 12
distinct states: 8
search depth: 5
```

Unsafe configurations produced expected counterexamples:

```text
config: WorkqueueCarrierUnsafeNoCarrier.cfg
target invariant: NoWorkQueueWithoutCarrier
result: expected FAIL
generated states before violation: 3
distinct states before violation: 3
depth: 2

config: WorkqueueCarrierUnsafeAmbient.cfg
target invariant: NoWorkerAmbientAuthority
result: expected FAIL
generated states before violation: 8
distinct states before violation: 8
depth: 4

config: WorkqueueCarrierUnsafeRevoke.cfg
target invariant: NoRunAfterCallerRevoke
result: expected FAIL
generated states before violation: 8
distinct states before violation: 8
depth: 4

config: WorkqueueCarrierUnsafeOverwrite.cfg
target invariant: NoCarrierOverwriteWhilePending
result: expected FAIL
generated states before violation: 8
distinct states before violation: 8
depth: 4

config: WorkqueueCarrierUnsafeDeadRefs.cfg
target invariant: NoDeadCarrierRefs
result: expected FAIL
generated states before violation: 13
distinct states before violation: 9
depth: 5
```

## Validated Claims

This validation supports the following local design constraints:

```text
1. Domain-derived work cannot become queued, delayed, or pending without a
   prepared CapSched carrier.

2. Running caller-derived work requires a live BudgetTicket and a frozen
   endpoint use.

3. Worker task authority alone does not authorize caller-derived endpoint work.

4. Caller revocation prevents queued or running work from using caller-derived
   authority.

5. Pending work cannot have its carrier overwritten by a different caller or
   ticket unless an explicit merge rule is modeled.

6. Completed, canceled, or revoked work cannot retain authority-bearing refs.
```

## Unsafe Counterexample Meaning

`WorkqueueCarrierUnsafeNoCarrier.cfg` demonstrates generic queue insertion with
no carrier:

```text
Start -> BadQueueNoCarrier
```

This is the failure mode where `queue_work()`/`kthread_queue_work()` is treated
as sufficient authority for Domain-derived work.

`WorkqueueCarrierUnsafeAmbient.cfg` demonstrates ambient worker authority:

```text
Start -> Prepared -> Queued -> BadAmbientRun
```

This is the failure mode where the worker task's service/kernel context is used
as the caller authority root.

`WorkqueueCarrierUnsafeRevoke.cfg` demonstrates revoked caller execution:

```text
Start -> Prepared -> Queued -> BadRunAfterRevoke
```

This is the failure mode where a queued work item executes after caller epoch
revocation.

`WorkqueueCarrierUnsafeOverwrite.cfg` demonstrates pending carrier overwrite:

```text
Start -> Prepared -> Queued -> BadOverwritePending
```

This is the failure mode caused by single `work_struct` coalescing when a
second caller overwrites the first caller's ticket or endpoint use.

`WorkqueueCarrierUnsafeDeadRefs.cfg` demonstrates completed work retaining
authority:

```text
Start -> Prepared -> Queued -> Running -> BadDeadRefs
```

This is the failure mode where completed/canceled/revoked work leaves caller
budget or endpoint authority reachable.

## Evidence Limits

This validation does not prove:

```text
full workqueue pool concurrency
rescuer scheduling fairness
delayed timer overrun cost
subsystem-specific merge semantics
task_work authority semantics
irq_work hard-context semantics
io_uring worker integration
monitor-backed service Domain activation
```

Those remain separate proof obligations.

## Design Consequence

The next behavior-changing Linux patch should not be a generic
`process_one_work()` global authority lookup.

The safer order is:

```text
1. Define type-only work carrier contracts.
2. Choose one narrow caller-derived wrapper or synthetic validation work item.
3. Prepare carrier before queue_work()/kthread_queue_work().
4. Assert carrier at callback entry.
5. Consume/release BudgetTicket on completion, cancel, or revoke.
6. Keep unconverted work categorized as service maintenance or audited
   kernel-internal exception with no caller-derived security claim.
```

The model fixes carrier semantics. It does not choose a Linux storage layout.
