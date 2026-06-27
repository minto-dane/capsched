# Analysis 0032: Block, Wait, and Register Authority Preparation

Status: Draft source map and design constraints, no implementation approved

Date: 2026-06-27

Linux source:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
commit: 7cf0b1e415bcead8a2079c8be94a9d41aad7d462
```

## Purpose

`analysis/0031` established:

```text
F1 is validation/freeze, not authority discovery.
```

Therefore this note asks:

```text
Where can resumable-run or endpoint-derived wake authority be prepared before
wake_q_add(), wake_up_q(), or try_to_wake_up() reaches the F1 boundary?
```

This is still not an implementation approval.

## Core Finding

Generic Linux wake paths usually carry only:

```text
task_struct *
state mask
wake flags
optional waitqueue key
```

They do not carry a typed CapSched authority object.

Therefore CapSched must not design F1 as a generic waker-side capability lookup
point. Authority must be prepared earlier, attached to one of:

```text
task-local resumable-run state
waiter-specific object state
endpoint-specific async carrier
work item carrier
kthread/service-domain task state
SpawnCap-derived initial task state
explicit kernel/service exception type
```

The first behavior-changing scheduler slice should not depend on adding a slow
global capability lookup to `try_to_wake_up()`.

## Generic Waitqueue

Key source anchors:

```text
include/linux/wait.h:80-85 init_waitqueue_entry() stores private task and func
include/linux/wait.h:302-325 ___wait_event() stack-allocates wait_queue_entry
include/linux/wait.h:1233-1248 DEFINE_WAIT_FUNC/init_wait_func use current
kernel/sched/wait.c:92-113 __wake_up_common() calls curr->func()
kernel/sched/wait.c:248-257 prepare_to_wait() queues and sets task state
kernel/sched/wait.c:289-323 prepare_to_wait_event() queues or aborts on signal
kernel/sched/wait.c:375-399 finish_wait() removes waiter and sets RUNNING
kernel/sched/wait.c:401-409 autoremove_wake_function() removes on successful wake
kernel/sched/core.c:7564-7569 default_wake_function() calls try_to_wake_up()
```

Important properties:

```text
wait_queue_entry is commonly stack allocated
private usually points to current task
func may be custom and can consume/filter wake events
prepare_to_wait_event() may remove the entry and return -ERESTARTSYS
finish_wait() must clean up the wait descriptor
default_wake_function() passes only task, mode, and wake_flags to the scheduler
```

CapSched consequence:

```text
Generic waitqueue wake is not an authority-discovery interface.
```

Two viable authority preparation shapes:

```text
task-local resumable-run:
  ordinary blocking preserves the task's own right to resume if its Domain,
  generation, SchedContext, and budget remain valid

object-specific wait wrapper:
  endpoint code that registers a wait also freezes a typed wait/wake authority
  in object-specific storage, then generic wake only resumes the task
```

Hard risk:

```text
Adding a pointer to every wait_queue_entry would touch many stack waiters and
custom wake functions. It is not a good first slice.
```

## Wake Queues

Key source anchors:

```text
include/linux/sched/wake_q.h:31-33 task must be ready at wake_q_add()
kernel/sched/core.c:1091-1112 __wake_q_add() only links task->wake_q node
kernel/sched/core.c:1116-1127 wake_q_add() says use as-if wake_up_process()
kernel/sched/core.c:1133-1154 wake_q_add_safe() task-safe variant
kernel/sched/core.c:1156-1174 wake_up_q() calls wake_up_process()
```

Important properties:

```text
wake_q stores task->wake_q, not a separate authority payload
wake_q_add() may be followed by wake_up_q(), but immediate wake is not ruled out
task readiness is required at wake_q_add() time
```

CapSched consequence:

```text
Any wake_q user must have authority ready before wake_q_add().
```

If a task's authority is revoked after `wake_q_add()` and before `wake_up_q()`:

```text
F1 may reject before TASK_WAKING
or later selected/switch checks may fail closed before execution
```

But if authority is missing at `wake_q_add()`:

```text
that is a design bug, not a normal F1 lookup case
```

## Futex

Key source anchors:

```text
kernel/futex/futex.h:181-225 struct futex_q contains task, wake fn, wake_data, key
kernel/futex/futex.h:313-336 futex_queue() requires hb lock and releases it
kernel/futex/waitwake.c:16-26 wait computes bucket, locks, rereads user value,
  queues, releases lock, and schedules
kernel/futex/waitwake.c:110-149 futex_wake_mark() unqueues then wake_q_add_safe()
kernel/futex/waitwake.c:416-452 futex_wait_multiple_setup() pins keys before
  setting task state because get_futex_key() can sleep
kernel/futex/waitwake.c:470-490 multiple-futex wait sets state then queues q
kernel/futex/waitwake.c:605-699 futex_wait_setup() validates key/value then
  sets state and queues
kernel/futex/waitwake.c:701-738 __futex_wait() uses futex_do_wait()
kernel/futex/waitwake.c:370-390 futex_do_wait() schedules and returns RUNNING
```

Important existing lesson:

```text
futex_wait_multiple_setup() explicitly separates sleepable key acquisition
from task-state transition so it will not lose wake events.
```

This mirrors CapSched's requirement:

```text
sleepable capability preparation must happen before task state / wake hot path
```

CapSched preparation candidates:

```text
before futex_queue():
  validate Domain policy for the futex key
  prepare local wait authority for q->task
  optionally attach endpoint/futex authority to futex_q or side storage

at futex_wake_mark()/wake_q_add_safe():
  require prepared authority, no discovery

at F1:
  reject if authority was revoked or task-local data is stale
```

Open risk:

```text
shared futexes can cross mm or file-backed memory boundaries. If cross-Domain
shared futex is allowed, futex key ownership and wake authority become endpoint
semantics, not plain task-resume semantics.
```

## Completion and Swait

Key source anchors:

```text
kernel/sched/completion.c:21-31 complete_with_flags() swake_up_locked()
kernel/sched/completion.c:50-53 complete()
kernel/sched/completion.c:72-82 complete_all()
kernel/sched/completion.c:85-110 do_wait_for_common() uses stack swait_queue
kernel/sched/completion.c:113-127 __wait_for_common()
kernel/sched/swait.c:22-32 swake_up_locked() calls try_to_wake_up()
kernel/sched/swait.c:62-83 swake_up_all()
kernel/sched/swait.c:85-90 __prepare_to_swait() stores current task
kernel/sched/swait.c:103-123 prepare_to_swait_event()
kernel/sched/swait.c:126-144 finish_swait()
```

Important properties:

```text
swait carries task only
completion waiters are usually stack waiters
complete()/complete_all() know the completion object, not a CapSched authority
```

CapSched consequence:

```text
Completion wake authority must be task-resume or operation-specific state
created by the code that chose to wait for that completion.
```

Completion itself should not become a universal object capability root.

## Locking Wake Queues

Representative anchors:

```text
kernel/locking/semaphore.c:220-239 up() builds wake_q then wake_up_q()
kernel/locking/semaphore.c:245-249 semaphore_waiter carries task and up bit
kernel/locking/semaphore.c:346-353 __up() wake_q_add()
kernel/locking/rwsem.c:421-423 caller must later invoke wake_up_q()
kernel/locking/rwsem.c:454 writer wake_q_add()
kernel/locking/rwsem.c:570-587 reader wake_q_add_safe()
kernel/locking/rwsem.c:1055-1095 reader slowpath queues waiter then sets state
kernel/locking/rwsem.c:1244-1255 rwsem_wake()
kernel/locking/rtmutex.c:551-584 RT mutex wake_q wrappers
kernel/locking/rtmutex.c:1363-1367 preempt-disabled wakeup-next-waiter window
kernel/locking/rtmutex.c:1480-1483 wake next waiter
kernel/locking/rwbase_rt.c:155-171 RT rwbase wake
kernel/locking/ww_mutex.h:327-328,386-387 wound/wake owner via wake_q_add()
```

Important properties:

```text
lock waiters are often stack records containing task pointers
wake_q_add() is used after lock state transfer decisions
RT mutex and ww_mutex may wake tasks for PI/wound semantics, not just resource
availability
```

CapSched consequence:

```text
ordinary lock wake should use the target task's prepared resumable-run state
rather than a waker-provided RunCap
```

But this area must later get a dedicated model for:

```text
priority inheritance vs SchedContext authority
cross-Domain lock sharing
lock-owner wake and wound semantics
CONFIG_PREEMPT_RT TASK_RTLOCK_WAIT
```

Hard rule:

```text
RunCap must not silently include priority donation, priority boost, or lock
ownership transfer semantics.
```

## Workqueue

Key source anchors:

```text
include/linux/workqueue.h:673-699 queue_work() memory-ordering guarantee
kernel/workqueue.c:2275-2411 __queue_work()
kernel/workqueue.c:2442-2458 queue_work_on()
kernel/workqueue.c:2861-2893 create_worker() starts worker task
kernel/workqueue.c:3207-3380 process_one_work()
kernel/workqueue.c:3321-3327 worker executes work->func()
kernel/workqueue.c:3431-3502 worker_thread() sleeps as TASK_IDLE
kernel/workqueue.c:3562-3679 rescuer_thread()
```

Important properties:

```text
queue_work() publishes prior stores to the executing CPU
worker wake only wakes a kernel worker task
the actual caller-derived authority is in the work item, not in worker wake
workers process many unrelated works
rescuers may execute work to guarantee reclaim progress
```

CapSched consequence:

```text
Generic workqueue must not execute caller-Domain work under ambient worker
authority.
```

Required preparation shape:

```text
queue_work()/delayed-work registration:
  freeze caller Domain, epoch, endpoint authority, and BudgetTicket into a
  capsched_work_ctx or equivalent wrapper

worker before work->func():
  effective authority = service authority intersection caller frozen authority
  budget is charged to the caller or an explicit donated ticket

worker wake:
  only resumes a service/kernel worker task; it is not the authority source
```

This reinforces prior endpoint-async analysis.

## Kthread and Kthread Worker

Key source anchors:

```text
include/linux/kthread.h:60-75 kthread_run() create then wake_up_process()
include/linux/kthread.h:219-231 kthread_run_worker() create then wake worker
kernel/kthread.c:411-420 new kthread starts blocked until first wake
kernel/kthread.c:423-436 started flag, cgroup_kthread_ready(), threadfn()
kernel/kthread.c:680-688 kthread_unpark() wake_up_state(TASK_PARKED)
kernel/kthread.c:703-760 kthread_park()/kthread_stop() set flags and wake
kernel/kthread.c:1000-1044 kthread_worker_fn() sleeps and runs queued work
kernel/kthread.c:1173-1184 kthread_insert_work() wakes worker task
```

Important properties:

```text
kthreads are service/kernel tasks, not ordinary user-Domain continuations
kthread wake often means start, park, unpark, stop, or process queued work
kthread workers share the workqueue confused-deputy shape
```

CapSched consequence:

```text
kthread tasks need explicit service-domain authority, not inherited user RunCap
kthread_work needs a work-carrier authority model similar to workqueue
```

## Signal Wake

Key source anchors:

```text
include/linux/sched/signal.h:444-451 signal_wake_up()
kernel/signal.c:721-735 signal_wake_up_state()
kernel/signal.c:963-1031 complete_signal()
kernel/signal.c:1260-1269 do_send_sig_info()
kernel/signal.c:1291-1322 force_sig_info_to_task()
```

Important properties:

```text
signal delivery chooses a target thread
signal_wake_up_state() sets TIF_SIGPENDING then wake_up_state()
fatal signals may wake a whole thread group
```

CapSched consequence:

```text
signal send is ThreadControlCap or policy-front-end authority
signal wake is target task resumable-run authority
```

Do not mix these:

```text
RunCap does not authorize signal send or terminate.
ThreadControlCap does not provide CPU budget or runnable authority.
```

## Timer and Timeout Wake

Key source anchors:

```text
kernel/time/sleep_timeout.c:15-28 process_timer stores task and wakes it
kernel/time/sleep_timeout.c:61-109 schedule_timeout()
kernel/time/hrtimer.c:2286-2295 hrtimer_wakeup()
kernel/time/hrtimer.c:2306-2324 hrtimer_sleeper_start_expires()
kernel/time/hrtimer.c:2390-2406 do_nanosleep()
kernel/sched/core.c:8118-8157 io_schedule_prepare()/io_schedule()
```

Important properties:

```text
timeout wake carries task only
timer sleepers store task pointer in stack or hrtimer_sleeper object
io_schedule only changes iowait accounting and flushes plug before sleeping
```

CapSched consequence:

```text
timeout and io-wait wake are ordinary resumable-run continuations.
```

If a Domain is revoked while sleeping:

```text
F1 rejects before TASK_WAKING
or later pick/switch fails closed before execution
```

The timer path is not an authority issuance point.

## Authority Carrier Taxonomy

| Path | Existing carrier | CapSched preparation point | First acceptable authority |
| --- | --- | --- | --- |
| generic wait_event | stack wait_queue_entry + task | before prepare_to_wait_event or task-local | task resumable-run |
| swait/completion | stack swait_queue + task | wait_for_completion caller path | task resumable-run or operation carrier |
| futex wait | futex_q | after key validation, before futex_queue | task resumable-run plus futex endpoint if shared |
| wake_q users | task->wake_q only | before wake_q_add | already-prepared task/waiter authority |
| semaphore/rwsem | stack waiter + task | before blocking slowpath | task resumable-run; later PI/lock model |
| rtmutex/ww_mutex | waiter + PI/owner state | before blocking/proxy lock | task resumable-run plus explicit PI semantics |
| workqueue | work_struct | queue_work wrapper | frozen work ctx: caller authority + service authority |
| kthread_work | kthread_work | kthread_queue_work wrapper | frozen work ctx |
| kthread start/stop/park | kthread flags + task | kthread creation/service policy | service-domain task authority |
| signal | signal pending state + task | signal send policy | ThreadControlCap for send, resumable-run for target |
| timer/timeout | process_timer/hrtimer_sleeper task | sleep setup | task resumable-run |

## Initial Design Rule

For the first behavior-changing runnable admission slice:

```text
1. Ordinary sleeping tasks carry task-local resumable-run authority.
2. Generic wake paths consume that local state; they do not discover authority.
3. Endpoint and async operations carry authority in endpoint-specific wrappers.
4. Workqueue/kthread_work require wrapper authority before queued execution.
5. wake_q_add() is treated as a readiness checkpoint.
6. F1 handles revocation/staleness, not missing-authority discovery.
```

## Hard Rejects

Reject any implementation candidate requiring:

```text
LSM/cgroup/namespace policy walk in try_to_wake_up()
allocation in generic wake F1
remote cluster lease lookup in generic wake
monitor call to mint wake authority
attaching caller authority only to worker task instead of work item
treating wake_q as a per-wake authority carrier without adding a modeled field
allowing shared-futex cross-Domain wake without endpoint semantics
folding signal send/terminate authority into RunCap
folding PI priority donation into RunCap or ordinary SchedContext budget
```

## Open Follow-Up

Next refinements:

```text
1. Model wake authority preparation and revoke-before-F1 behavior.
2. Source-map exact ordinary blocking points where task-local resumable-run
   authority can be initialized, refreshed, and cleared.
3. Decide whether the first L0 slice uses only task-local resumable-run state
   or also a minimal workqueue wrapper.
4. Model shared futex cross-Domain semantics before treating futex as safe
   inter-Domain synchronization.
5. Model PI/RT/ww_mutex priority donation separately from RunCap.
```

## Formal Evidence

Supporting tiny model and TLC record:

```text
formal/0015-wake-authority-preparation-model/
validation/0027-wake-authority-preparation-tlc.md
```

This evidence is a design filter only. It does not prove Linux waitqueue,
futex, workqueue, or locking behavior.
