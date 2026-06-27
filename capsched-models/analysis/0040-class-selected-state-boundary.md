# Analysis 0040: Class-Specific Selected-State Boundary

Status: Draft source map with TLC-backed design filter, no implementation approved

Date: 2026-06-27

Linux source:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
commit: 7cf0b1e415bcead8a2079c8be94a9d41aad7d462
```

## Purpose

Earlier notes established that:

```text
RunCap gates runnable submission.
FrozenRunUse is the enqueue/pick-era frozen execution use.
Same-Domain fast path still needs freshness proof.
MonitorRootBudget, SchedContextBudget, and class runtime are separate.
```

This note narrows the next boundary: Linux scheduler classes do not all move
from pick to execution in the same way. A task can be:

```text
picked by a class
cached as a core-wide sibling pick
changed by set_next_task()
kept as previous sched_ext task
borrowed through fair/ext deadline server
used as a donor while another task is the actual execution context
```

CapSched consequence:

```text
selected is not authority.
class-specific selected state must be revalidated before execution commit.
```

## Core Finding

The common scheduler spine is:

```text
pick_next_task()
  -> class->pick_task()
  -> put_prev_set_next_task()
       prev->put_prev_task()
       next->set_next_task()
  -> __schedule()
       rq_set_donor()
       optional proxy execution
       RCU_INIT_POINTER(rq->curr, next)
       context_switch()
```

This creates multiple authority-sensitive windows:

```text
pick_task returned p
  but set_next_task may still alter class state

core scheduling cached p in rq->core_pick
  but sibling picks may be consumed later

sched_ext can keep prev or refill a zero slice
  but a BPF slice is not CapSched authority

deadline server can pick CFS or SCX through nested server_pick_task
  but borrowed server runtime is not caller/Domain authority

proxy execution can select a blocked donor and run an owner task
  but donor authority is not owner execution authority
```

Therefore a future CapSched hook cannot treat `class->pick_task()` alone as the
final enforcement point.

## Source Anchors

### Class API

`kernel/sched/sched.h:struct sched_class` separates:

```text
pick_task(rq, rf)         called from schedule/pick_next_task under rq->lock
put_prev_task(rq, p, n)   called from sched_change/__schedule under rq->lock
set_next_task(rq, p, f)   called from sched_change/__schedule under rq->lock
task_tick(rq, p, queued)  called from hrtick/sched_tick/remote tick
update_curr(rq)           called by task_sched_runtime and class paths
```

`put_prev_set_next_task()` calls:

```text
__put_prev_set_next_dl_server()
prev->sched_class->put_prev_task()
next->sched_class->set_next_task()
```

and returns early when `next == prev`.

CapSched consequence:

```text
If next == prev, class set_next hooks may be skipped.
Same-task continuation therefore still needs budget/revoke/timer coverage.
```

### Core pick cache

`kernel/sched/core.c:pick_next_task()` under `CONFIG_SCHED_CORE` can reuse:

```text
rq->core_pick
rq->core_dl_server
core_pick_seq
core_task_seq
rq->core_sched_seq
```

It can also select sibling tasks, store them in each sibling rq's `core_pick`,
reschedule sibling CPUs, and consume cached picks later.

CapSched consequence:

```text
core_pick is selected state, not authority. It requires task-sequence,
placement, side-policy, and budget freshness at consumption time.
```

If CapSched uses core scheduling for co-tenancy control, the core-wide group
must also be checked against:

```text
Domain side/co-tenancy policy
SMT sibling MemoryView compatibility
core cookie or CapSched co-run token
root budget for each runnable Domain
```

### CFS

`kernel/sched/fair.c:pick_task_fair()` may update current runtime while walking:

```text
if cfs_rq->curr && cfs_rq->curr->on_rq:
  update_curr(cfs_rq)
```

`set_next_task_fair()` calls:

```text
set_next_entity()
account_cfs_rq_runtime(cfs_rq, 0)
task_throttle_setup_work(p) if throttled
hrtick_start_fair()
sched_fair_update_stop_tick()
```

CFS can therefore discover or react to bandwidth/throttling at set-next time.

CapSched consequence:

```text
CFS selected state must be revalidated after set_next_task_fair() and before
execution commit. CFS bandwidth can narrow execution, but it cannot mint root
budget or refresh a stale FrozenRunUse.
```

### RT

`kernel/sched/rt.c:set_next_task_rt()`:

```text
sets exec_start
dequeues p from pushable tasks
updates RT load average when first
queues push tasks
```

`put_prev_task_rt()` calls `update_curr_rt()` and skips pushable requeue if
`task_is_blocked(p)`.

`task_tick_rt()` updates RT runtime and handles RR timeslice, while FIFO tasks
have no timeslice.

CapSched consequence:

```text
RT/FIFO selected state cannot rely on RR timeslice mechanics. Root budget and
SchedContext budget must be enforced independently of RT runtime and FIFO
no-timeslice behavior.
```

### SCHED_DEADLINE and deadline servers

`kernel/sched/deadline.c:set_next_task_dl()`:

```text
sets exec_start
dequeues from pushable DL tasks
sets dl_rq->curr
may start hrtick from p->dl.runtime
```

`pick_task_dl()` may pick a server:

```text
if dl_server(dl_se):
  p = dl_se->server_pick_task(dl_se, rf)
  rq->dl_server = dl_se
else:
  p = dl_task_of(dl_se)
```

Fair and sched_ext both have deadline-server pick paths:

```text
fair_server_pick_task() -> pick_task_fair()
ext_server_pick_task()  -> do_pick_task_scx(force_scx=true)
```

CapSched consequence:

```text
server-picked CFS/SCX tasks need two checks:
  1. the selected task's own FrozenRunUse/SchedContext/Domain authority
  2. an explicit server-budget or server-borrow ticket if DL server runtime is
     used to run lower class work
```

Deadline server runtime must not become ambient authority for a Domain.

### sched_ext

`kernel/sched/ext/ext.c:do_pick_task_scx()` can:

```text
drop and re-pin rq lock around balance_one()
return RETRY_TASK if higher-priority classes changed state
keep running prev when SCX_RQ_BAL_KEEP is set
refill zero slice with default slice
pick first local dispatch-queue task
```

`set_next_task_scx()` can:

```text
dequeue a task that core scheduling executes before dispatch
call BPF ops.running()
clear task runnable state
toggle SCX_RQ_CAN_STOP_TICK when SCX_SLICE_INF changes
update tick dependency
```

`put_prev_task_scx()` can:

```text
update runtime
call BPF ops.stopping()
put a still-runnable task back into local DSQ or BPF enqueue
notify cpu_release when preempted by a higher class
```

CapSched consequence:

```text
BPF scheduler decisions are policy inputs only. They cannot be security roots.
SCX slice refill, SCX_SLICE_INF, local DSQ position, and BPF running/stopping
callbacks must never create or refresh CapSched execution authority.
```

### Proxy execution

With `CONFIG_SCHED_PROXY_EXEC`, `__schedule()` can:

```text
next = pick_next_task()
rq_set_donor(rq, next)
if next->is_blocked:
  next = find_proxy_task(rq, next, rf)
```

`find_proxy_task()` follows a blocked-on mutex chain:

```text
donor scheduling context -> mutex -> owner execution context
```

The source comments distinguish CPU affinity of execution contexts from
scheduling contexts:

```text
respect CPU affinity of execution contexts (owner)
ignore affinity for scheduling contexts (donor)
move scheduling contexts towards potential execution contexts
```

`sched.h` also distinguishes:

```text
rq->curr   current execution context
rq->donor  current scheduling context
```

CapSched consequence:

```text
proxy execution requires an explicit ProxyExecutionTicket or equivalent
owner-budget rule. Donor RunCap/FrozenRunUse cannot authorize running an owner
from another Domain.
```

If the owner Domain differs from the donor Domain:

```text
owner must have executable authority
donor must have dependency/donation authority
charging must be explicit: owner budget, donor ticket, or service/broker rule
MemoryView activation must match the actual execution context
```

## Required Invariants

### Selected is not authority

```text
class->pick_task() returned p
  does not imply
p may execute
```

Execution requires:

```text
fresh FrozenRunUse
fresh Domain epoch
fresh PlacementEpoch
fresh MonitorRootBudget
fresh SchedContextBudget
class-specific revalidation after set_next/class mutation
```

### Core cached picks must be consumed fresh

```text
rq->core_pick
  must not survive task_seq, placement, side-policy, or budget epoch staleness
```

### Server runtime must be typed

```text
DL server picks lower-class task
  requires explicit ServerRunTicket or equivalent typed budget rule
```

### sched_ext slice is not authority

```text
SCX slice refill or SCX_SLICE_INF
  must not grant CapSched execution authority
```

### Proxy execution must split donor and owner

```text
donor selected
  does not authorize owner execution
```

Proxy execution needs:

```text
owner executable authority
donor dependency/donation authority
ProxyExecutionTicket or explicit owner-budget charge
monitor activation for actual execution Domain
```

## Hook Implications

A future behavior-changing L0 patch should avoid a single hook that assumes one
universal selected-state meaning. Candidate enforcement shape:

```text
F0: authority prepared before wake/enqueue
F1: freeze before TASK_WAKING/TASK_RUNNING admission
F2: class pick returns selected task
F3: after put_prev_set_next_task(), class-specific state has settled
F4: after proxy resolution, actual execution context is known
F5: before rq->curr commit/context_switch, selected use is revalidated
F6: tick/hrtick/monitor timer enforces continuation budget
```

Minimum safe design:

```text
validate at F1 for cheap fail-capable admission
revalidate at F5 for stale selected/core/proxy/server/class state
monitor/timer coverage for same-task continuation and NO_HZ
```

This does not imply every check must be expensive. It means each fast path must
prove the corresponding freshness instead of assuming selected state is stable.

## Model Link

The design filter for these invariants is:

```text
capsched/capsched-models/formal/0023-class-selected-state-model/
```
