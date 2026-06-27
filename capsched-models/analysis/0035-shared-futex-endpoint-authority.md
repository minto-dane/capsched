# Analysis 0035: Shared Futex Endpoint Authority

Status: Draft source map and design constraints, no implementation approved

Date: 2026-06-27

Linux source:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
commit: 7cf0b1e415bcead8a2079c8be94a9d41aad7d462
```

## Purpose

`analysis/0032` established that generic wake paths cannot discover authority.
`analysis/0033` established ordinary task-local resumable-run lifecycle.
`analysis/0034` established that async worker execution needs explicit typed
carriers.

This note handles shared futexes:

```text
When a futex key can be shared across processes or Domains, futex_wait(),
futex_wake(), futex_wake_op(), and futex_requeue() become endpoint operations,
not merely local task sleep/resume operations.
```

This is not an approval to patch futex code yet.

## Core Finding

Private futexes are keyed by the current address space:

```text
private key:
  current->mm + address
```

Shared futexes are keyed by file/inode mapping identity:

```text
shared key:
  inode sequence + page offset + offset within page
```

Therefore shared futexes can connect tasks that are not in the same address
space, and under CapSched may connect tasks in different Domains.

CapSched consequence:

```text
shared futex == typed synchronization endpoint
```

The endpoint must have separate authority:

```text
FutexWaitCap:
  authority to register the current task as a waiter on the endpoint

FutexWakeCap:
  authority to wake waiters on the endpoint

FutexRequeueCap:
  authority to move waiters from one endpoint to another

FutexPiCap / PriorityDonationCap:
  separate authority for PI ownership and priority donation paths
```

The wake operation still does not directly authorize execution. A waker-side
`FutexWakeCap` authorizes endpoint signaling; the target task still needs valid
task-local resumable-run state and F1 freeze before `TASK_WAKING`.

## Source Anchors

Futex flags and shared/private distinction:

```text
include/uapi/linux/futex.h:26 FUTEX_PRIVATE_FLAG
kernel/futex/futex.h:30 FLAGS_SHARED
kernel/futex/futex.h:47 futex_to_flags()
kernel/futex/futex.h:51-52 missing FUTEX_PRIVATE_FLAG sets FLAGS_SHARED
```

Key construction:

```text
kernel/futex/core.c:476 get_futex_key()
kernel/futex/core.c:488-493 comment: shared key is inode sequence, page offset,
  offset within page
kernel/futex/core.c:495-499 comment: private key is current->mm and address
kernel/futex/core.c:502 get_futex_key() implementation
kernel/futex/core.c:583 private futex path stores current mm and address
```

Wait setup:

```text
kernel/futex/waitwake.c:605 futex_wait_setup()
kernel/futex/waitwake.c:648 get_futex_key()
kernel/futex/waitwake.c:657 futex_q_lock()
kernel/futex/waitwake.c:681 uval compare against expected val
kernel/futex/waitwake.c:690-695 set_current_state() then futex_queue()
kernel/futex/waitwake.c:704 __futex_wait()
kernel/futex/waitwake.c:717 futex_wait_setup()
kernel/futex/waitwake.c:721 futex_do_wait()
```

Multiple wait:

```text
kernel/futex/waitwake.c:416 futex_wait_multiple_setup()
kernel/futex/waitwake.c:448-455 get_futex_key() can sleep, so keys are fetched
  before setting task state
kernel/futex/waitwake.c:459-490 set_current_state() then queue each futex
```

Wake:

```text
kernel/futex/waitwake.c:134 futex_wake_mark()
kernel/futex/waitwake.c:140 __futex_wake_mark()
kernel/futex/waitwake.c:149 wake_q_add_safe()
kernel/futex/waitwake.c:181 futex_wake()
kernel/futex/waitwake.c:188 get_futex_key()
kernel/futex/waitwake.c:198 hb waiters fast check
kernel/futex/waitwake.c:203-221 scan matching futex_q, call q->wake()
kernel/futex/waitwake.c:224 wake_up_q()
```

Wake op:

```text
kernel/futex/waitwake.c:282 futex_wake_op()
kernel/futex/waitwake.c:287 get key1
kernel/futex/waitwake.c:290 get key2
kernel/futex/waitwake.c:300 futex_atomic_op_inuser()
kernel/futex/waitwake.c:323 retry_private on private fault path
```

Requeue and PI:

```text
kernel/futex/requeue.c:360 futex_requeue()
kernel/futex/requeue.c:445 get source key
kernel/futex/requeue.c:448 get target key
kernel/futex/requeue.c:483 retry_private on private fault path
kernel/futex/requeue.c:720 futex_wait_requeue_pi()
kernel/futex/pi.c:928 futex_lock_pi()
```

## Why Shared Futex Is an Endpoint

A futex word is user memory, but the kernel-visible wait queue is keyed by a
kernel-derived key and can wake tasks that may not share an `mm_struct`.

For CapSched this means:

```text
caller Domain A:
  writes shared futex word
  calls FUTEX_WAKE

target Domain B:
  has a task queued on the same futex key
  may become runnable
```

This is cross-Domain influence over scheduling state. It is not necessarily
bad, but it must be authorized as an endpoint operation.

Allowed shape:

```text
Domain A has FutexWakeCap(endpoint E)
Domain B task has FutexWaitCap(endpoint E)
Domain B task has valid resumable-run state
F1 freezes target run use before TASK_WAKING
```

Rejected shape:

```text
any task mapping the same page may wake any Domain's waiter because Linux
futex key matches
```

## Authority Split

### WaitCap

`FutexWaitCap` authorizes registration:

```text
get endpoint key
validate endpoint wait authority
prepare waiter endpoint state
set task state
futex_queue()
```

It does not authorize another task to wake the waiter. It only proves the
waiter is allowed to block on that endpoint.

### WakeCap

`FutexWakeCap` authorizes signaling:

```text
get endpoint key
validate endpoint wake authority
scan matching futex_q
mark selected waiters for wake
```

It does not grant the target task CPU execution. The actual wake still needs:

```text
target's prepared task-local resumable-run state
F1 freeze before TASK_WAKING
generation/epoch/budget/placement validation
```

### RequeueCap

`FutexRequeueCap` authorizes moving waiters:

```text
source FutexEndpoint
target FutexEndpoint
requeue count
optional wake count
epoch of both endpoints
```

It must not be modeled as source wake alone. Requeue changes which endpoint can
later wake the task.

### PI Authority

PI futexes combine endpoint wake with priority donation and rt_mutex ownership.
They must remain a separate proof obligation:

```text
FutexPiCap
PriorityDonationCap
ThreadControlCap interactions
```

This note does not close PI semantics.

## Placement in Existing Futex Ordering

Futex ordering is delicate. The kernel already separates sleepable key
acquisition from task-state and queue transitions.

Key lesson:

```text
sleepable endpoint discovery/preparation must happen before set_current_state()
and before hash-bucket locked hot paths that cannot sleep.
```

For `futex_wait_setup()`:

```text
1. get_futex_key() may sleep
2. prepare or look up FutexEndpoint authority using sleepable context
3. lock hash bucket
4. reread futex value
5. perform no-sleep, local endpoint epoch/freeze check
6. set_current_state()
7. futex_queue()
```

If the no-sleep endpoint check fails:

```text
unlock hash bucket
do not queue
return -EPERM or future policy error before the task is queued
```

For `futex_wait_multiple_setup()`:

```text
all keys and endpoint wait authorities must be prepared before
set_current_state()
```

Once the task state is set and any q is queued, failure recovery must preserve
Linux's no-lost-wake semantics.

For `futex_wake()`:

```text
get_futex_key()
validate FutexWakeCap before scanning waiters
for each q:
  endpoint wake is allowed
  q->wake() can mark for wake
  target task still needs F1/task-local run validation later
```

For `futex_requeue()`:

```text
get source and target keys
validate RequeueCap(source, target)
validate source wake authority for nr_wake waiters
validate target wait-transfer authority for requeued waiters
only then move waiters
```

## Required State Carrier

`struct futex_q` already has:

```text
task
wake function
wake_data
key
pi_state
rt_waiter
bitset
requeue state
```

CapSched needs a waiter-side endpoint carrier, either in `futex_q` under
`CONFIG_CAPSCHED` or in a side table keyed by `futex_q *` with precise lifetime:

```c
struct capsched_futex_wait_ctx {
        u64 caller_domain;
        u64 caller_epoch;
        u64 task_generation;
        u64 process_generation;
        u64 endpoint_id;
        u64 endpoint_epoch;
        unsigned int rights; /* wait, wake-match, requeue-source, pi */
};
```

This is a semantic shape, not an approved C layout.

Waker-side authority should not be stored in target `futex_q`. It belongs to
the waker's syscall context and endpoint cap root.

## Required Invariants

```text
NoSharedFutexWaitWithoutWaitCap:
  cross-Domain/shared futex wait cannot enqueue without FutexWaitCap.

NoSharedFutexWakeWithoutWakeCap:
  cross-Domain/shared futex wake cannot mark waiters without FutexWakeCap.

NoWakeImpliesRun:
  FutexWakeCap only authorizes endpoint signaling; target execution still
  requires task-local resumable-run freeze.

NoRequeueWithoutBothEndpointRights:
  requeue requires source and target endpoint authority.

NoEndpointUseAfterRevoke:
  endpoint epoch revoke invalidates queued waiter context and wake/requeue use.

NoLostWakeFromCapFailure:
  capability failure must happen before queuing or must follow a separately
  proven rollback that preserves futex no-lost-wake ordering.
```

## Compatibility Notes

Linux ABI compatibility requires:

```text
private same-Domain futex remains fast and can often use task-local authority
shared futex behavior remains available when policy grants endpoint caps
futex value comparison and no-lost-wake ordering are preserved
normal return values remain compatible unless CapSched policy explicitly denies
  cross-Domain endpoint use
PI futex semantics are not silently weakened or folded into RunCap
```

When `CONFIG_CAPSCHED=n`, there must be no behavior change.

## Hard Rejects

```text
shared futex wake is treated as ordinary task-local resume only
FutexWakeCap directly grants target execution
wait-side endpoint authority is looked up after set_current_state()
futex_q is queued before WaitCap is validated
requeue validates only source endpoint and ignores target endpoint
PI priority donation is folded into RunCap
endpoint revoke leaves queued futex waiters wakeable as if still authorized
```

## Open Follow-Ups

```text
Q-030:
  Should same-Domain private futexes bypass FutexEndpoint objects in L0, or
  should all futexes pass through a uniform endpoint abstraction?

Q-031:
  What exact errno or fail action should CapSched use for denied shared futex
  endpoint operations while preserving userspace compatibility?

Q-032:
  Where should waiter-side capsched_futex_wait_ctx live: futex_q field,
  stack-owned side object, or hash-bucket side table?

Q-033:
  How should FUTEX_WAKE_OP's second-key write authority compose with
  FutexWakeCap?

Q-034:
  Which PI futex paths must be separated into the PI/RT/ww_mutex authority
  model in N-052?
```
