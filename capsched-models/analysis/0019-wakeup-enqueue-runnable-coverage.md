# Analysis 0019: Wakeup, Enqueue, and Runnable-State Coverage

Status: Draft

Date: 2026-06-26

Linux source:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
commit: 7cf0b1e415bcead8a2079c8be94a9d41aad7d462
subject: sched/capsched: Add type-only authority scaffolding
```

## Purpose

This note is the first assurance-driven source gate after Slice 0B.

It supports:

```text
assurance claim:
  EXEC-001 No CPU execution without runnable authority

assurance gate:
  G2 Trace-only Linux observation
  G3 Runnable lease prototype, later
```

It does not approve behavior-changing scheduler hooks.

## Summary

The source reading confirms that a single future check in `activate_task()` is
not enough to understand runnable authority.

Important runnable transitions include:

```text
self wake of current task with no runqueue lock
already-runnable wake with no normal activate_task()
delayed fair entity requeue through enqueue_task(... ENQUEUE_DELAYED)
remote wake list enqueue followed by target-CPU activation
new task wake through wake_up_new_task()
queued-task migration through deactivate/set_task_cpu/activate
affinity and hotplug mask changes that can stale frozen CPU placement
fair fast pick, class iteration, sched_core cached picks, and forced idle
sched_ext BPF custody, bypass, direct dispatch, and internal re-enqueue
```

Therefore the next Linux-facing gate should remain trace-only or source-only.
The safest default is to draft Slice 0C as observation over these paths, not as
enforcement.

## Source Coverage Map

| Path | Source evidence | Runnable-state meaning | CapSched pressure |
| --- | --- | --- | --- |
| Generic enqueue | `enqueue_task()` at `kernel/sched/core.c:2172` updates rq clock, uclamp, class state, PSI, sched_info, and core scheduling. | This is the shared class enqueue wrapper. | Any future rejection must occur before partial accounting mutation or be structured as validation-only. |
| Generic activation | `activate_task()` at `kernel/sched/core.c:2219` calls `enqueue_task()` then sets `p->on_rq = TASK_ON_RQ_QUEUED`. | Normal transition to queued runqueue state. | Good observation point, but not complete coverage. |
| Generic deactivation/migration marker | `deactivate_task()` at `kernel/sched/core.c:2230` sets `TASK_ON_RQ_MIGRATING` before dequeue. | Migration is a special on-rq state, not simply blocked. | Future grants need a migrating/stale-placement state. |
| Queued migration | `move_queued_task()` at `kernel/sched/core.c:2546` deactivates, calls `set_task_cpu()`, locks the destination rq, and reactivates. | A queued task can move without a new user wakeup. | Frozen CPU placement can stale; migration should validate or refresh placement later. |
| Normal wake activation | `ttwu_do_activate()` at `kernel/sched/core.c:3804` builds enqueue flags, calls `activate_task()`, then `ttwu_do_wakeup()`. | The common not-yet-runnable wake path. | Candidate trace point for wake-to-queue transition. |
| Already-runnable wake | `ttwu_runnable()` at `kernel/sched/core.c:3865` handles `p->on_rq`; if fair delayed, it calls `enqueue_task(... ENQUEUE_DELAYED)` at line 3876, otherwise it may only wake/preempt. | Wake may complete without `activate_task()`. | Enforcement only in `activate_task()` would miss this semantic state. |
| Remote pending wake | `__ttwu_queue_wakelist()` at `kernel/sched/core.c:3950` puts work on the target CPU wakelist; `sched_ttwu_pending()` at `3891` drains and calls `ttwu_do_activate()` at `3911`. | Waker may defer activation to the target CPU. | Trace must distinguish remote-pending from activated; future revoke must cover pending wakelist state. |
| Wake queue decision | `ttwu_queue_cond()` at `kernel/sched/core.c:4005` checks sched_ext permission, CPU activity, and `p->cpus_ptr`. | Linux already refuses some remote queueing when placement is invalid. | CapSched placement must refine `p->cpus_ptr`, never expand it. |
| `try_to_wake_up()` self path | `try_to_wake_up()` at `kernel/sched/core.c:4251`; `p == current` path lines `4258-4283` clears blocked state and calls `ttwu_do_wakeup()` with no rq lock. | Current task can be made running without enqueue. | Future execution authority must treat current/running separately from enqueue authority. |
| `try_to_wake_up()` normal path | Lines `4292-4415` serialize under `p->pi_lock`, check `p->on_rq`, maybe use remote wakelist, run `select_task_rq()`, `set_task_cpu()`, then `ttwu_queue()`. | Wake path is a lock/barrier-sensitive state machine. | Slow capability resolution is unacceptable here; only frozen/cheap validation can fit. |
| New task wake | `wake_up_new_task()` at `kernel/sched/core.c:4941` sets `TASK_RUNNING`, picks CPU, locks rq, then `activate_task()` at line `4963`. | Fork/new task first becomes runnable outside normal `try_to_wake_up()`. | Future SpawnCap and generation semantics must be considered before runnable lease enforcement. |
| Affinity change | `__set_cpus_allowed_ptr_locked()` at `kernel/sched/core.c:3112` validates masks, calls `do_set_cpus_allowed()`, then `affine_move_task()`. | Allowed CPU set can change under task/rq locks and may force movement. | Frozen allowed CPU masks need refresh/invalidation when affinity, cpuset, or hotplug changes. |
| Fast fair pick | `__pick_next_task()` at `kernel/sched/core.c:6124`; fair fast path lines `6132-6153`. | Pick may bypass class iteration for common fair workloads. | Pick validation must cover the fast path. |
| Class iteration pick | `__pick_next_task()` lines `6156-6169` iterates active classes. | Higher classes and fallback classes select through callbacks. | Per-class hooks alone are incomplete unless generic final validation exists. |
| Core scheduling pick | `pick_next_task()` at `kernel/sched/core.c:6216` may reuse `rq->core_pick`, force idle, or reschedule siblings. | Core-wide selection can cache picks and select idle despite runnable tasks. | Domain co-tenancy and validation must compose with core scheduling. |
| Switch point | `__schedule()` picks at `kernel/sched/core.c:7149`, sets `rq->curr` at `7201`, traces at `7231`, and calls `context_switch()` at `7234`. | This is the final local CPU transition point. | Trace-only Domain transition observation belongs near here; production monitor activation would be before execution resumes. |
| Scheduler class contract | `struct sched_class` at `kernel/sched/sched.h:2585` documents locks for enqueue, dequeue, select, migrate, tick, and update hooks. | Class callbacks are lock-sensitive contracts. | CapSched must not add blocking lookup or allocation under these callbacks. |
| sched_ext enqueue | `enqueue_task_scx()` at `kernel/sched/ext/ext.c:2006`; `do_enqueue_task()` at `1866` may call BPF enqueue, direct dispatch, local/global DSQ, bypass. | sched_ext has custody and fallback paths. | sched_ext is a policy/experiment surface, not the production enforcement root. |

## Runnable-State Taxonomy for Modeling

The next runnable-state model or trace plan should distinguish at least:

```text
blocked
self-woken current
waking under p->pi_lock
remote-wake pending
queued
queued delayed
migrating
selected/picked
core cached pick
running/current
throttled
fork-new before first wake
exiting but still referenced
```

The existing RunnableLease model already has the right direction, but Linux
requires more than a binary queued/not queued state before enforcement.

## Hook-Coverage Risks

### Hook Only `activate_task()`

Would observe:

```text
normal wake activation
remote pending drain activation
new task wake
queued migration reactivation
```

Would miss or under-model:

```text
self wake of current task
already-runnable wake without activation
delayed fair requeue through enqueue_task(... ENQUEUE_DELAYED)
sched_ext internal custody and re-enqueue details
pick/core-sched cached selection
```

### Hook Only `enqueue_task()`

Would observe:

```text
generic class enqueue wrapper
delayed fair requeue
normal activation
new task activation
queued migration activation
```

Hazards:

```text
must run before uclamp/class/PSI/sched_info/core-sched mutation if it can fail
still misses self wake with no enqueue
does not by itself prove selected task is still valid at pick time
```

### Hook Only `try_to_wake_up()`

Would observe:

```text
normal wake state machine
self wake
already-runnable wake
remote wakelist decision
```

Would miss:

```text
wake_up_new_task()
queued migration
class-internal requeue
pick/core-sched final selection
```

### Hook Only Pick/Switch

Would observe:

```text
final selected task
core-sched forced idle or cached pick
Domain switch opportunity
```

Would fail to prove:

```text
No FrozenRunUse, no runqueue entry
```

It is useful as a last-chance safety check, not as the only runnable authority
model.

## Slice 0C Trace-Only Implication

If Slice 0C proceeds, it should observe rather than decide:

```text
wake path class:
  self_current
  already_runnable
  delayed_requeue
  local_activate
  remote_wakelist
  remote_pending_activate
  new_task
  queued_migration

pick path class:
  fair_fast
  class_iteration
  core_cached
  core_force_idle

switch path:
  prev/next task identity
  placeholder Domain shadow equality once such shadow exists
  no monitor activation claim
```

For now, Slice 0C should not:

```text
attach hot task_struct authority fields
reject wakeups
reject enqueue
reject pick
change scheduler class callbacks
add user ABI
claim No RunCap, no run
claim hypervisor-grade isolation
```

## Next Recommendation

Before a Linux patch, draft an implementation gate for Slice 0C that is
strictly trace-only and references this analysis plus assurance claims:

```text
claims:
  EXEC-001
  COMPAT-001

gates:
  G2 trace-only observation
```

The implementation gate should choose a minimal first observation set. A
reasonable first set is:

```text
try_to_wake_up() outcome category counters
activate_task() enqueue flag counters
wake_up_new_task() counter
move_queued_task() counter
__schedule() prev/next switch counter
```

Even this should be reviewed for disabled-config codegen impact before touching
Linux again.
