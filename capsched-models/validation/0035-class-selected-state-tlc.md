# Validation 0035: Class Selected-State TLC

Status: Completed bounded model check

Date: 2026-06-27

Model:

```text
capsched/capsched-models/formal/0023-class-selected-state-model/ClassSelectedState.tla
```

Related analysis:

```text
capsched/capsched-models/analysis/0040-class-selected-state-boundary.md
```

TLC logs:

```text
/media/nia/scsiusb/dev/linux-cap/build/tlc/class-selected-state-20260627T090311Z/ClassSelectedStateSafe.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/class-selected-state-20260627T090311Z/ClassSelectedStateUnsafeNoFrozen.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/class-selected-state-20260627T090311Z/ClassSelectedStateUnsafeNoClassRevalidation.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/class-selected-state-20260627T090311Z/ClassSelectedStateUnsafeCoreCachedStale.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/class-selected-state-20260627T090311Z/ClassSelectedStateUnsafeDlServerNoTicket.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/class-selected-state-20260627T090311Z/ClassSelectedStateUnsafeScxSliceAuthority.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/class-selected-state-20260627T090311Z/ClassSelectedStateUnsafeProxyNoTicket.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/class-selected-state-20260627T090311Z/ClassSelectedStateUnsafeClassMutationRun.log
```

## Result Summary

Safe configuration:

```text
config: ClassSelectedStateSafe.cfg
result: PASS
generated states: 47
distinct states: 27
search depth: 5
```

Unsafe configurations produced expected counterexamples:

```text
config: ClassSelectedStateUnsafeNoFrozen.cfg
target invariant: NoRunWithoutFrozenUse
result: expected FAIL
generated states before violation: 11
distinct states before violation: 11
depth: 4

config: ClassSelectedStateUnsafeNoClassRevalidation.cfg
target invariant: NoRunWithoutClassRevalidation
result: expected FAIL
generated states before violation: 11
distinct states before violation: 11
depth: 4

config: ClassSelectedStateUnsafeCoreCachedStale.cfg
target invariant: NoCoreCachedPickWithStaleSeq
result: expected FAIL
generated states before violation: 11
distinct states before violation: 11
depth: 4

config: ClassSelectedStateUnsafeDlServerNoTicket.cfg
target invariant: NoDlServerBorrowWithoutTicket
result: expected FAIL
generated states before violation: 11
distinct states before violation: 11
depth: 4

config: ClassSelectedStateUnsafeScxSliceAuthority.cfg
target invariant: NoScxSliceAsAuthority
result: expected FAIL
generated states before violation: 11
distinct states before violation: 11
depth: 4

config: ClassSelectedStateUnsafeProxyNoTicket.cfg
target invariant: NoProxyRunWithoutProxyTicket
result: expected FAIL
generated states before violation: 11
distinct states before violation: 11
depth: 4

config: ClassSelectedStateUnsafeClassMutationRun.cfg
target invariant: NoClassMutationRunWithoutRefresh
result: expected FAIL
generated states before violation: 26
distinct states before violation: 24
depth: 5
```

## Validated Claims

This validation supports the following local design constraints:

```text
1. A task selected by a scheduler class cannot run without a fresh FrozenRunUse.

2. Class selection must be followed by class-specific revalidation before
   execution commit.

3. Core cached picks require fresh core/task sequence and related freshness at
   consumption time.

4. Deadline-server borrowed execution requires a typed server ticket or
   equivalent budget rule.

5. sched_ext slice refill, local DSQ position, and infinite slice cannot create
   CapSched execution authority.

6. Proxy execution requires a ProxyExecutionTicket or explicit owner-budget
   rule. Donor selected authority is not owner execution authority.

7. If class state mutates after selection, selected/running use must refresh,
   revalidate, preempt, or fail closed.
```

## Unsafe Counterexample Meaning

`ClassSelectedStateUnsafeNoFrozen.cfg` demonstrates running after selected-state
with a stale/missing FrozenRunUse.

`ClassSelectedStateUnsafeNoClassRevalidation.cfg` demonstrates treating
`class->pick_task()` as final authority.

`ClassSelectedStateUnsafeCoreCachedStale.cfg` demonstrates consuming a cached
core scheduling pick after sequence staleness.

`ClassSelectedStateUnsafeDlServerNoTicket.cfg` demonstrates a lower-class task
borrowed through a deadline server without typed server budget authority.

`ClassSelectedStateUnsafeScxSliceAuthority.cfg` demonstrates sched_ext slice
refill or slice state being treated as execution authority.

`ClassSelectedStateUnsafeProxyNoTicket.cfg` demonstrates donor-selected proxy
execution running an owner without a proxy ticket.

`ClassSelectedStateUnsafeClassMutationRun.cfg` demonstrates class state changing
after revalidation without invalidating selected/running use.

## Evidence Limits

This validation does not prove:

```text
exact CFS vruntime semantics
exact RT push/pull behavior
deadline admission or CBS/GRUB properties
BPF scheduler correctness
full SMT/co-tenancy safety
real proxy execution chain safety
real monitor activation ordering
```

Those remain separate proof obligations.

## Design Consequence

The future enforcement shape should distinguish:

```text
F1 admission freeze before TASK_WAKING/TASK_RUNNING
F2 class pick as selected state
F3 class set_next/put_prev settled state
F4 proxy/server/core resolution
F5 final pre-rq->curr/context_switch revalidation
F6 tick/hrtick/monitor continuation enforcement
```

A single pick-time check is not sufficient for CapSched authority because class,
core, server, and proxy paths can change the meaning of the selected task before
actual execution.
