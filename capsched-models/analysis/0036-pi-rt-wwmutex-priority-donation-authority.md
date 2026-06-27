# Analysis 0036: PI, RT, and ww_mutex Priority Donation Authority

Status: Draft source map with TLC-backed design filter, no implementation approved

Date: 2026-06-27

Linux source:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
commit: 7cf0b1e415bcead8a2079c8be94a9d41aad7d462
```

## Purpose

`analysis/0035` left PI futex and priority donation open. This note closes the
next local semantic boundary:

```text
Priority inheritance, RT mutex proxy locking, scheduler proxy execution, and
ww_mutex wound/wait are not RunCap minting operations.
```

They are dependency-resolution mechanisms. They may change scheduling order,
effective priority, or which runnable owner executes first, but they must not
grant a task runnable authority, create CPU budget, or become a generic
cross-Domain thread-control primitive.

This is not an approval to patch locking, futex, or scheduler code yet.

## Core Finding

Linux already has several dependency-driven scheduling mechanisms:

```text
rt_mutex PI:
  waiter blocks on owner-held rt_mutex
  owner may inherit effective priority from top waiter

futex PI:
  userspace futex endpoint delegates into rt_mutex PI
  proxy APIs enqueue or wait on behalf of a task

scheduler proxy execution:
  blocked donor can stay selectable
  scheduler follows blocked_on -> mutex -> owner
  owner becomes execution context for the donor's scheduling context

ww_mutex:
  wound/wait or wait/die can wake another owner/waiter to back out
  this is deadlock-resolution pressure, not kill/suspend authority
```

CapSched consequence:

```text
Priority donation is a derived scheduling-order override.
It is not RunCap, SchedControlCap, ThreadControlCap, or unbounded CPU budget.
```

The safe decomposition is:

```text
LockWaitCap:
  authority to block on a lock/futex/synchronization endpoint

PriorityDonationCap:
  authority for this endpoint to derive bounded priority donation from a
  blocked waiter to the current owner

ProxyExecutionTicket:
  optional bounded ticket allowing an owner to run because a blocked donor is
  waiting on it; charging policy must be explicit

WoundWaitCap:
  authority for a ww_mutex class/endpoint to request wound/wait backoff
```

None of these includes:

```text
RunCap
ThreadControlCap
SchedControlCap
budget creation
arbitrary priority assignment
```

## Source Anchors

Task-local PI and proxy fields:

```text
include/linux/sched.h:
  task_struct::pi_waiters
  task_struct::pi_top_task
  task_struct::pi_blocked_on
  task_struct::blocked_on
  task_struct::blocked_donor
```

RT mutex priority inheritance:

```text
kernel/locking/rtmutex.c:
  rt_mutex_adjust_prio()
    derives pi_task from task_top_pi_waiter()
    calls rt_mutex_setprio()

  task_blocks_on_rt_mutex()
    initializes waiter->task and waiter->lock
    enqueues waiter
    sets task->pi_blocked_on
    enqueues the waiter in owner's pi_waiters tree when it is top waiter
    adjusts owner priority and may walk the PI chain

  rt_mutex_adjust_prio_chain()
    follows pi_blocked_on / owner chain
    includes deadlock detection and bounded chain depth
```

Scheduler effective-priority update:

```text
kernel/sched/core.c:
  rt_mutex_setprio()
    changes effective p->prio and p->pi_top_task
    does not change p->normal_prio
    may change scheduling class derived from effective priority
```

PI futex proxy-lock API:

```text
kernel/locking/rtmutex_api.c:
  __rt_mutex_start_proxy_lock()
  rt_mutex_start_proxy_lock()
  rt_mutex_wait_proxy_lock()
  rt_mutex_cleanup_proxy_lock()
  rt_mutex_adjust_pi()

kernel/futex/pi.c:
  futex_lock_pi()
    obtains futex key
    queues futex_q
    starts rt_mutex proxy lock for current task
```

Scheduler proxy execution:

```text
kernel/sched/core.c:
  try_to_block_task()
    can keep mutex-blocked tasks on rq for proxy execution

  find_proxy_task()
    follows task->blocked_on to mutex owner
    sets owner->blocked_donor
    may migrate the blocked donor toward the owner's CPU
```

ww_mutex wound/wait:

```text
kernel/locking/ww_mutex.h:
  __ww_mutex_die()
    wakes a lesser waiter context to die/back out
    clears blocked_on to avoid circular proxy relationships

  __ww_mutex_wound()
    marks hold_ctx->wounded
    wakes owner so it observes wounded state
    clears blocked_on to avoid circular proxy relationships
```

## Authority Boundary

### PriorityDonationCap

`PriorityDonationCap` authorizes a lock endpoint to derive a temporary boost
from a blocked waiter to the lock owner:

```text
blocked waiter
+ live lock endpoint
+ owner holds the lock
+ donation authority on that endpoint
-> temporary effective priority donation
```

It does not authorize:

```text
enqueueing the owner without RunCap/FrozenRunUse
running the owner without budget
changing normal priority
changing SchedContext policy
donating after unlock, unqueue, timeout, signal, or endpoint revoke
```

In Linux terms, CapSched should treat `rt_mutex_setprio()` as an effective
priority/order update, not as capability creation.

### ProxyExecutionTicket

Scheduler proxy execution is more subtle than ordinary PI. A blocked donor can
remain selectable, and `find_proxy_task()` may select the runnable lock owner as
the execution context.

For CapSched this creates a budget question:

```text
If owner executes because donor is blocked on it, whose CPU budget is charged?
```

Allowed policies are explicit:

```text
owner-charged:
  owner must have valid RunCap/FrozenRunUse and owner SchedContext budget

donor-ticket-charged:
  blocked donor supplies a bounded ProxyExecutionTicket to run the owner only
  for resolving that dependency

dual-charged or capped:
  both owner and donor/service roots must remain under monitor budget
```

Rejected policy:

```text
priority donation makes owner runnable and consumes no budget
```

### Cross-Domain Locking

Cross-Domain locks are typed endpoints. A Domain should not gain scheduling
influence over another Domain merely because both can touch a shared futex word
or kernel lock object.

Cross-Domain PI requires:

```text
LockWaitCap(endpoint)
PriorityDonationCap(endpoint)
live endpoint epoch
policy allowing donation direction
explicit budget charging rule
```

For L0, the conservative option is to deny or disable cross-Domain PI donation
until these endpoint rules are modeled and implemented.

### WoundWaitCap

`ww_mutex` wound/wait is deadlock-resolution authority. It can cause another
participant to observe `wounded` or back out of acquisition.

It must not imply:

```text
kill
suspend
arbitrary wake/run
priority control
thread inspection
```

This belongs to endpoint-specific lock protocol authority, not
`ThreadControlCap`.

## Required Invariants

```text
NoDonationWithoutBlockedDependency:
  active donation implies waiter is blocked on an owner-held dependency

NoDonationWithoutDonationCap:
  active donation implies endpoint donation authority

NoCrossDomainDonationWithoutEndpoint:
  cross-Domain donation requires live typed endpoint authority

NoDonationCreatesRunAuthority:
  donated priority cannot run an owner unless owner execution authority has
  also been frozen

NoDonationCreatesBudget:
  donated priority cannot create free CPU time

NoDonationAfterUnlockOrRevoke:
  unlock, unqueue, timeout, signal, or endpoint revoke clears donation

NoWoundAsThreadControl:
  wound/wait can request lock-protocol backoff, not arbitrary thread control

NoProxyChainCycle:
  proxy and blocked-on chains must not create circular authority paths
```

## Compatibility Consequences

Linux compatibility argues against removing PI, RT mutex, futex PI, or
ww_mutex. Datacenter workloads and PREEMPT_RT paths depend on them. The design
goal is therefore not "delete donation"; it is "type and bound donation."

For Linux-only L0:

```text
1. Do not encode PI as RunCap.
2. Do not let effective-priority donation bypass task-local FrozenRunUse.
3. Do not claim protection for cross-Domain PI paths until endpoint authority
   and budget charging are implemented.
4. Treat SCHED_PROXY_EXEC as a special selected-state behavior that needs its
   own budget accounting rule before enforcement.
5. Keep ww_mutex wound/wait in endpoint/deadlock-resolution authority, not
   ThreadControlCap.
```

For monitor-backed CapSched-H:

```text
1. Monitor root budgets still cap the running Domain or proxy ticket.
2. Endpoint epoch revoke invalidates PI, proxy, and wound/wait use.
3. Cross-Domain donation direction must be policy-visible and auditable.
4. A compromised Domain kernel context must not forge donation into another
   Domain without endpoint and monitor-backed epoch authority.
```

## Open Questions

```text
1. Should default L0 proxy execution be owner-charged, donor-ticket-charged,
   or disabled across Domains?

2. How should priority donation interact with core scheduling cookies and
   co-tenancy policy?

3. Should PI donation across service Domains be allowed only for service
   endpoints with bounded broker-style BudgetTickets?

4. What exact rollback rule is needed if endpoint authority fails after a PI
   futex waiter has been queued?

5. How should deadlock-detection chain depth become a CapSched proof and audit
   parameter rather than an untyped kernel constant?
```

## Design Consequence

The next implementation model must keep this line bright:

```text
RunCap:
  may make a task runnable

PriorityDonationCap:
  may alter ordering/effective priority because a real dependency exists

ProxyExecutionTicket:
  may fund a bounded dependency-resolution execution

ThreadControlCap:
  may control another thread explicitly
```

Merging those capabilities would recreate ambient scheduling authority under a
new name.
