# Analysis 0030: TASK_WAKING Failability Boundary Map

Status: Draft boundary map, no implementation approved

Date: 2026-06-27

Linux source:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
commit: 7cf0b1e415bcead8a2079c8be94a9d41aad7d462
```

## Purpose

This note identifies where a future CapSched runnable-admission check may fail
without violating Linux wakeup ordering.

The immediate result is conservative:

```text
fail-capable admission belongs before TASK_WAKING
post-TASK_WAKING checks must be nofail assertions or have a separately modeled
rollback/quarantine protocol
```

This is not a patch plan. It is a boundary map for later hook selection.

## Linux Wakeup Spine

Normal wake enters:

```text
kernel/sched/core.c:4251 try_to_wake_up()
kernel/sched/core.c:4292 take p->pi_lock
kernel/sched/core.c:4295 ttwu_state_match(p, state, &success)
kernel/sched/core.c:4322 smp_rmb()
kernel/sched/core.c:4323 already-runnable path through ttwu_runnable()
kernel/sched/core.c:4349 smp_acquire__after_ctrl_dep()
kernel/sched/core.c:4357 WRITE_ONCE(p->__state, TASK_WAKING)
kernel/sched/core.c:4378-4380 optional remote wakelist while p->on_cpu
kernel/sched/core.c:4391 smp_cond_load_acquire(&p->on_cpu, !VAL)
kernel/sched/core.c:4393 select_task_rq()
kernel/sched/core.c:4401 psi_ttwu_dequeue(p)
kernel/sched/core.c:4402 set_task_cpu(p, cpu)
kernel/sched/core.c:4415 ttwu_queue(p, cpu, wake_flags)
```

Direct activation path:

```text
kernel/sched/core.c:4067 ttwu_queue()
kernel/sched/core.c:4075 rq_lock()
kernel/sched/core.c:4077 ttwu_do_activate()
kernel/sched/core.c:3805 ttwu_do_activate()
kernel/sched/core.c:3824 activate_task()
kernel/sched/core.c:3827 ttwu_do_wakeup()
```

Remote wakelist path:

```text
kernel/sched/core.c:4056 ttwu_queue_wakelist()
kernel/sched/core.c:3950 __ttwu_queue_wakelist()
kernel/sched/core.c:3956 WRITE_ONCE(rq->ttwu_pending, 1)
kernel/sched/core.c:3958 __smp_call_single_queue(cpu, &p->wake_entry.llist)
kernel/sched/core.c:3891 sched_ttwu_pending()
kernel/sched/core.c:3901 rq_lock_irqsave()
kernel/sched/core.c:3911 ttwu_do_activate()
kernel/sched/core.c:3924 WRITE_ONCE(rq->ttwu_pending, 0)
```

Already-runnable path:

```text
kernel/sched/core.c:3865 ttwu_runnable()
kernel/sched/core.c:3870 task_on_rq_queued(p)
kernel/sched/core.c:3875-3876 delayed fair requeue via enqueue_task(... ENQUEUE_DELAYED)
kernel/sched/core.c:3887 ttwu_do_wakeup(p)
```

Current self-wake path:

```text
kernel/sched/core.c:4258 p == current
kernel/sched/core.c:4277 clear_task_blocked_on(p, NULL)
kernel/sched/core.c:4278 ttwu_state_match(...)
kernel/sched/core.c:4282 ttwu_do_wakeup(p)
```

This path is not runqueue admission and must not mint RunCap or FrozenRunUse.

## Barrier and Ordering Anchors

The waiter side uses:

```text
include/linux/sched.h:247 set_current_state()
include/linux/sched.h:251 smp_store_mb(current->__state, state_value)
```

The waker side says `try_to_wake_up()` executes a full barrier before reading
task state:

```text
kernel/sched/core.c:4226-4231 comments on atomicity and p->pi_lock
kernel/sched/core.c:4292 p->pi_lock
kernel/sched/core.c:4293 smp_mb__after_spinlock()
kernel/sched/core.c:4322 smp_rmb()
kernel/sched/core.c:4349 smp_acquire__after_ctrl_dep()
```

After this point, Linux relies on `TASK_WAKING` to bridge blocked state,
placement, and enqueue:

```text
kernel/sched/core.c:4352-4357 comment and TASK_WAKING store
kernel/sched/core.c:3341 set_task_cpu()
kernel/sched/core.c:3349 WARN unless TASK_RUNNING, TASK_WAKING, or on_rq
kernel/sched/deadline.c:2659 migrate_task_rq_dl() only handles TASK_WAKING
```

Affinity and migration paths also treat `TASK_WAKING` as a special in-flight
state:

```text
kernel/sched/core.c:2626-2628 migration_cpu_stop() comment about pending wakeups
kernel/sched/core.c:3052 task_on_cpu(rq, p) || p->__state == TASK_WAKING
kernel/sched/core.c:4424 __task_needs_rq_lock()
kernel/sched/core.c:4433 TASK_RUNNING || TASK_WAKING needs rq lock
```

## Failability Zones

### F0: Before Wake Match

Source region:

```text
try_to_wake_up() before ttwu_state_match()
```

Properties:

```text
no TASK_WAKING
no placement change
no runqueue custody
no remote wakelist
```

CapSched meaning:

```text
safe to reject, but may do unnecessary work for wake attempts that would not
match Linux state
```

Use carefully because this is the hottest and least informed point.

### F1: After State Match, Before TASK_WAKING

Source region:

```text
kernel/sched/core.c:4295 ttwu_state_match() succeeded
kernel/sched/core.c:4357 TASK_WAKING not yet written
```

Properties:

```text
p->pi_lock held
success is known
ordinary blocked task not yet converted to TASK_WAKING
already-runnable branch may have returned through ttwu_runnable()
```

CapSched meaning:

```text
best fail-capable admission-freeze zone for normal blocked wake
```

Hard constraints:

```text
must not allocate or sleep under p->pi_lock
must not perform slow distributed or monitor round trips
must not treat current self-wake as new admission
must preserve RT/freezer saved_state semantics from ttwu_state_match()
```

### F2: Already-Runnable Path

Source region:

```text
kernel/sched/core.c:4323 READ_ONCE(p->on_rq) && ttwu_runnable(...)
kernel/sched/core.c:3865 ttwu_runnable()
```

Properties:

```text
task already has runqueue custody
delayed enqueue may call enqueue_task(... ENQUEUE_DELAYED)
path can call ttwu_do_wakeup() without new admission
```

CapSched meaning:

```text
not an admission-freeze point
may be a nofail assertion or revalidation point for existing FrozenRunUse
```

Failing here as if this were a new RunCap submission would mix authority
admission with already-owned custody.

### F3: TASK_WAKING Written

Source region:

```text
kernel/sched/core.c:4357 WRITE_ONCE(p->__state, TASK_WAKING)
```

Properties:

```text
Linux has converted a blocked task into an in-flight wake
set_task_cpu() and class migration callbacks may rely on TASK_WAKING
task_call_func() and affinity paths treat TASK_WAKING as requiring rq locking
```

CapSched meaning:

```text
ordinary fail-return is forbidden until rollback/quarantine is modeled
```

A hook after this point may only be:

```text
nofail assertion
debug observation
fail-closed kernel stop/panic style protection
or a separately proven rollback/quarantine protocol
```

### F4: Remote Wakelist Pending

Source region:

```text
kernel/sched/core.c:4378-4380 ttwu_queue_wakelist()
kernel/sched/core.c:3950 __ttwu_queue_wakelist()
kernel/sched/core.c:3891 sched_ttwu_pending()
```

Properties:

```text
source CPU has dropped the normal activation path
target CPU will later drain the wake_entry.llist
rq->ttwu_pending is visible state
```

CapSched meaning:

```text
pending wake is not execution authority, but it is post-TASK_WAKING state
final drain must not be the first fail-capable authority check
```

Remote drain can assert that a FrozenRunUse exists, but if it can reject it
must also prove no lost wake, no stuck TASK_WAKING, and correct ttwu_pending
accounting.

### F5: Activation and Enqueue

Source region:

```text
kernel/sched/core.c:3805 ttwu_do_activate()
kernel/sched/core.c:3824 activate_task()
kernel/sched/core.c:2172 enqueue_task()
kernel/sched/core.c:2219 activate_task()
```

Properties:

```text
rq lock held
enqueue_task() returns void
scheduler class state, uclamp, psi, sched_info, and core scheduling state mutate
```

CapSched meaning:

```text
nofail assertion point until class rollback is modeled
```

### F6: Wake Complete

Source region:

```text
kernel/sched/core.c:3726 ttwu_do_wakeup()
kernel/sched/core.c:3827 ttwu_do_wakeup()
```

Properties:

```text
task state is TASK_RUNNING
preemption decisions may already have been made
```

CapSched meaning:

```text
too late for admission failure
```

## Immediate Rule

The next hook-selection constraint is:

```text
AdmissionFreeze may fail only in F0/F1.
F3 and later are nofail/assertion/observation zones unless a rollback model
exists and passes.
```

For first Linux behavior work, the likely split is:

```text
F1:
  fail-capable freeze of RunCap + SchedContext into FrozenRunUse

F5:
  nofail assertion that FrozenRunUse exists before enqueue custody

pick/switch:
  independent stale grant and monitor activation validation
```

## Why Post-TASK_WAKING Rollback Is Suspicious

After `TASK_WAKING`, Linux assumes the wake will either:

```text
queue directly
queue remotely and later drain
complete as already-runnable/current wake
```

An ordinary CapSched rejection here risks:

```text
lost condition wake
task stuck in TASK_WAKING
affinity/migration paths spinning or forcing stopper paths
deadline class accounting inconsistency
ttwu_pending accounting inconsistency
runqueue/class state partial mutation if rejection happens near enqueue
```

The formal model in `formal/0013-scheduler-admission-failure-model/` captures
the minimal version of this: pre-WAKING rejection is safe, while deferred
post-WAKING rejection either violates "TASK_WAKING requires frozen authority" or
can create a lost wake after rollback.

## Open Follow-Up

Required before implementation:

```text
1. Decide exact F1 data dependencies: which task/domain/sched-context fields
   must be precomputed so F1 does not allocate, sleep, or call remote services.
2. Model RT/freezer saved_state interaction if CapSched rejects after
   ttwu_state_match().
3. Map new-task wake_up_new_task() to an equivalent pre-TASK_RUNNING
   SpawnCap/freeze boundary.
4. Split F5 assertion behavior between CONFIG_CAPSCHED debug, L0 prototype,
   and CapSched-H fail-closed modes.
```
