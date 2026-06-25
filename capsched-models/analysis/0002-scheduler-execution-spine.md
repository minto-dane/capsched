# Analysis 0002: Scheduler Execution Spine

Status: Draft

Date: 2026-06-25

Linux base:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
commit: 4edcdefd4083ae04b1a5656f4be6cd83ae919ef4
```

## Purpose

This note records how current upstream Linux moves a task from wakeup to
runqueue, from runqueue to CPU, and from CPU to runtime accounting. It maps those
paths to CapSched invariants without choosing hook points.

## Existing Strengths

Linux already has several properties CapSched should respect:

- The scheduler has explicit locking rules. In `kernel/sched/core.c`, the
  scheduler documents the order `p->pi_lock -> rq->lock -> hrtimer_cpu_base->lock`
  around lines 556-630. This is a compatibility boundary.
- Runnable state is centralized enough to reason about: `activate_task()`,
  `deactivate_task()`, `enqueue_task()`, and `dequeue_task()` form a visible
  path in `kernel/sched/core.c` around lines 2172-2243.
- Scheduler classes have documented callbacks in `kernel/sched/sched.h` around
  `struct sched_class` at lines 2585-2675. CapSched must not silently break
  class contracts.
- Core scheduling already models limited co-tenancy through `core_cookie`.
  It is not enough for CapSched authority, but it is useful prior art.
- Runtime accounting is class-specific and mature. Fair, RT, deadline, and
  sched_ext each charge time differently.

## Execution Spine

### 1. Locking and Stable State

Evidence:

- `kernel/sched/core.c` lines 556-630 describe lock ordering and which fields
  are stabilized by `p->pi_lock`, `rq->lock`, or both.
- The same block names state changed by `sched_setaffinity()`,
  `set_user_nice()`, `__sched_setscheduler()`, `sched_move_task()`, and
  `uclamp_update_active()`.

CapSched reading:

`RunCap`, `SchedContext`, and `FrozenRunUse` cannot be looked up through an
arbitrary blocking or globally contended path while scheduler locks are held.
The first model must distinguish:

```text
authority resolution: may be slow, may allocate, may consult policy
authority validation: must be cheap, lock-compatible, and nonblocking
```

This supports the existing idea of `FrozenRunUse`: resolve and freeze before
placing a task where the scheduler fast path only needs small validation.

### 2. Enqueue and Activation

Evidence:

- `enqueue_task()` in `kernel/sched/core.c` around lines 2172-2193:
  updates the rq clock, increments uclamp state, calls the class enqueue
  callback, then updates PSI, sched info, and core scheduling state.
- `dequeue_task()` around lines 2198-2217 reverses much of that state, but class
  dequeue can fail or leave a delayed entity.
- `activate_task()` around lines 2219-2227 calls `enqueue_task()` and then sets
  `p->on_rq = TASK_ON_RQ_QUEUED`.
- `deactivate_task()` around lines 2230-2243 marks migration state before
  dequeue.

CapSched reading:

The phrase "No RunCap, no enqueue" is directionally right, but Linux's enqueue
is not just "append task to list". It updates uclamp, PSI, sched info, class
state, and core-sched state. If CapSched rejects after partial enqueue work, it
risks corrupting accounting. If it rejects too early, it must still preserve
legal wakeup semantics such as delayed entities and migration.

Open question:

```text
Should FrozenRunUse be attached before activate_task(), inside enqueue_task(),
or at a narrower runnable-submission layer?
```

This note does not answer it.

### 3. Wakeup and Already-Runnable Paths

Evidence:

- `ttwu_do_activate()` around lines 3805-3827 builds enqueue flags and calls
  `activate_task()`.
- `ttwu_runnable()` around lines 3865-3888 handles tasks already on a runqueue.
  It may call `enqueue_task()` with `ENQUEUE_DELAYED` for delayed fair entities,
  or it may only perform wakeup and preemption work.
- `sched_ttwu_pending()` around lines 3891-3925 drains remote wake lists.
- `try_to_wake_up()` around lines 4215-4422 is highly optimized around barriers,
  task state, `p->pi_lock`, `p->on_rq`, `p->on_cpu`, remote wake lists,
  `select_task_rq()`, and `set_task_cpu()`.
- `wake_up_process()` around lines 4545-4548 calls `try_to_wake_up()`.

CapSched reading:

A naive "check only in activate_task" model misses important cases:

```text
already queued task -> ttwu_runnable()
delayed fair entity -> enqueue_task(... ENQUEUE_DELAYED)
remote wake list -> activation deferred to another CPU
current task fast path -> state cleared without normal rq path
```

The formal model should include at least these states:

```text
blocked
waking
runnable but delayed
queued
selected
running
throttled
migrating
```

Compatibility hazard:

`try_to_wake_up()` deliberately tries to take only the lock it needs. Adding a
global capability-table lookup here could damage scalability and create lock
inversion risk.

### 4. Pick and Context Switch

Evidence:

- `__pick_next_task()` in `kernel/sched/core.c` around lines 6123-6170 has a
  fast path for fair-only workloads, then iterates scheduler classes.
- `pick_next_task()` with `CONFIG_SCHED_CORE` around lines 6172-6677 may choose
  idle or force idle because of core scheduling cookie constraints.
- `__schedule()` around lines 7023-7242 locks the rq, updates the clock, may
  block `prev`, calls `pick_next_task()`, updates `rq->curr`, and performs the
  switch.
- `prepare_task_switch()` around lines 5272-5297 and `context_switch()` around
  lines 5450-5513 handle mm/TLB and arch hooks.
- `finish_task_switch()` around lines 5318-5414 finalizes the previous task and
  delayed cleanup.

CapSched reading:

`EXEC-006: No DomainTag activation, no cross-Domain context switch` belongs
semantically near task switch, but placement is delicate. The switch path has:

```text
rq lock held
interrupts disabled
RCU and membarrier expectations
lazy TLB and mm switching
architecture hooks
finish-switch cleanup after switch_to()
```

The right abstraction may be:

```text
before switch: validate sealed execution token for next
during switch: activate CPU-local DomainTag if domain changes
after switch: account/trace the domain transition
```

But this is a model sketch, not a patch decision.

### 5. Tick and Runtime Charging

Evidence:

- `sched_tick()` in `kernel/sched/core.c` around lines 5762-5810 locks the rq,
  accounts IRQ time, updates the rq clock, and invokes the class `task_tick()`.
- Fair runtime updates happen in `kernel/sched/fair.c`:
  `update_curr()` around lines 1985-2035 and CFS bandwidth around lines
  6506-6559.
- RT runtime updates happen in `kernel/sched/rt.c`:
  `update_curr_rt()` around lines 974-1008 and RT tick logic around lines
  2540-2572.
- Deadline runtime updates happen in `kernel/sched/deadline.c`:
  `update_curr_dl_se()` around lines 1416-1437 and `update_curr_dl()` around
  lines 2128-2147.
- sched_ext runtime updates happen in `kernel/sched/ext/ext.c`:
  `update_curr_scx()` around lines 1321-1337 and `task_tick_scx()` around lines
  3505-3524.
- Fair `task_tick_fair()` around lines 14851-14873 notes it can be called
  remotely by full dynticks CPU load balancing.

CapSched reading:

`SchedContext` must be class-crossing. It cannot be implemented as "CFS
bandwidth with a different name". Existing class accounting remains useful
policy and fairness machinery, while CapSched budget is an execution lease with
security meaning.

Budget questions for the first model:

```text
Which entity consumes budget: current, donor, domain, or sched context?
How does proxy execution affect budget?
What happens on nohz and remote tick?
Does budget depletion dequeue, throttle, or make pick validation fail?
How is budget restored without giving ambient authority?
```

## Mapping to CapSched Invariants

| Invariant | Linux evidence | Current risk |
| --- | --- | --- |
| EXEC-001 No RunCap, no enqueue | `try_to_wake_up()`, `ttwu_do_activate()`, `activate_task()`, `enqueue_task()` | Already-runnable and delayed paths can bypass a single activate hook. |
| EXEC-002 No SchedContext, no execution | `pick_next_task()`, scheduler class callbacks, `context_switch()` | Pick can return class-specific or core-sched-forced results. |
| EXEC-003 No budget, no execution | `sched_tick()`, class `update_curr*()` functions | Budget is currently policy/class accounting, not non-forgeable authority. |
| EXEC-004 No FrozenRunUse, no runqueue entry | `p->on_rq`, class enqueue/dequeue, CFS delayed dequeue | A task can be runnable, delayed, throttled, migrating, or under sched_ext custody. |
| EXEC-005 No valid epoch/generation, no execution | No direct Linux equivalent | Needs a new generation/epoch model, with lazy invalidation considered. |
| EXEC-006 No DomainTag activation, no cross-Domain context switch | `context_switch()`, mm/TLB switch, core-sched | Placement must preserve arch, RCU, membarrier, and IRQ constraints. |

## Do Not Decide Yet

- Do not assume `activate_task()` is the only hook.
- Do not assume `task_struct` fields alone provide security.
- Do not replace scheduler classes with a CapSched class before proving why.
- Do not make sched_ext the enforcement root.
- Do not ignore core scheduling, proxy execution, delayed fair dequeue, or
  nohz remote tick behavior.

## Preliminary Conclusion

The Linux scheduler gives CapSched a strong skeleton: explicit runqueue state,
class callbacks, mature accounting, topology, and cgroup integration. Its main
problem is that current authority is ambient and mutable inside the kernel. The
best near-term design pressure is to separate slow authority resolution from
cheap frozen validation, then model every state transition where a task can
become runnable or continue running without a fresh enqueue.
