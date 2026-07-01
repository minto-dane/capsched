# Analysis 0102: Task FrozenRun Lifetime and Locking Gate

Status: Draft model gate with TLC-backed design filter; no implementation
approved

Date: 2026-07-01

## Purpose

N-146 requires final ordinary Domain run and queued-task move edges to consume a
fresh validation tuple. N-147 requires denial to be explicit, bounded,
progress-making, and fail-closed. N-148 fixes the next lower-level semantic
condition:

```text
What makes the task identity inside a FrozenRunUse or denied-candidate record
safe to hold and consume?
```

The answer cannot be a raw `task_struct *`, and it cannot be "RCU made the
pointer visible". For CapSched purposes, task visibility is not task authority.

The required shape is:

```text
task identity is stabilized
  by task refcount or by the scheduler's locked queued/current context
  and by generation freshness
  and by not being in a migrating state
  and by not being released
then a FrozenRunUse may be consumed or a denial may be settled
```

This remains a model gate only. It does not approve a Linux storage layout,
refcounting implementation, or hook placement.

## Source Basis

Current Linux source:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
work commit: 7cf0b1e415bcead8a2079c8be94a9d41aad7d462
upstream ref: 665159e246749578d4e4bfe106ee3b74edcdab18
```

Current CapSched Linux code remains inert:

```text
include/linux/capsched.h
kernel/sched/capsched.c
```

No scheduler behavior has changed.

## Linux Source Anchors

| Surface | Current upstream anchor | CapSched meaning |
| --- | --- | --- |
| task lifetime count | `include/linux/sched.h:846 task_struct.usage` | task object lifetime is refcounted |
| get task reference | `include/linux/sched/task.h:114 get_task_struct()` | explicit stable lifetime source |
| try get task reference | `include/linux/sched/task.h:120 tryget_task_struct()` | safe reference acquisition when object may be dying |
| put task reference | `include/linux/sched/task.h:128 put_task_struct()` | reference release is delayed through RCU callback on final put |
| put many references | `include/linux/sched/task.h:164 put_task_struct_many()` | bulk release exists and must not become double-release |
| user RCU put | `include/linux/sched/task.h:170 put_task_struct_rcu_user()` | RCU delays free; not authority by itself |
| release task stack | `kernel/fork.c:517 release_task_stack()` | premature free is explicitly guarded |
| free task | `kernel/fork.c:533 free_task()` | final object destruction path |
| final put | `kernel/fork.c:781 __put_task_struct()` | object free after usage reaches zero |
| final put RCU callback | `kernel/fork.c:800 __put_task_struct_rcu_cb()` | RCU callback frees after final put |
| fork-error delayed free | `kernel/fork.c:1936 delayed_free_task()` | delayed free exists outside normal runnable authority |
| exit delayed put | `kernel/exit.c:223 delayed_put_task_struct()` | exit uses delayed task put |
| RCU user put | `kernel/exit.c:234 put_task_struct_rcu_user()` | exit path can defer final task release |
| release task | `kernel/exit.c:244 release_task()` | task exit/unhash/release boundary |
| task rq lock | `kernel/sched/core.c:732 ___task_rq_lock()` | rq lock retries until task is not migrating |
| task rq + pi lock | `kernel/sched/core.c:755 _task_rq_lock()` | stable rq view requires pi/rq locking |
| queued migration | `kernel/sched/core.c:2546 move_queued_task()` | move requires rq lock |
| CPU change locking rule | `kernel/sched/core.c:3341 set_task_cpu()` | CPU changes require pi or rq lock |
| current publication | `kernel/sched/core.c:7201 RCU_INIT_POINTER(rq->curr, next)` | RCU publishes current but does not mint CapSched authority |

## Required Semantics

For ordinary Domain task identity carried by `FrozenRunUse`, denied-candidate
state, or a future move validation tuple:

```text
raw task pointer is not authority
RCU visibility is not authority
task generation must match
task must be live at consumption
task must not be in TASK_ON_RQ_MIGRATING-equivalent state
queued move settlement requires rq locking
denial retry settlement must complete before releasing the candidate lifetime
release is exactly once
terminal model states must not leak task refs or rq/pi locks
exit/generation invalidation forces fail-closed rather than run
```

The model deliberately allows either:

```text
task refcount protects the object across a CapSched-owned record
```

or:

```text
the scheduler's locked queued/current context protects the object for the
immediate consume edge
```

It does not require every scheduler-local use to take an extra task reference.
That would overfit the model against Linux's existing rq-locked execution
spine.

## Rejected Designs

The model rejects:

```text
running after task free or exit invalidation
running without stable task lifetime
using RCU-only visibility as authority
using a raw task pointer as authority
running while the task is migrating
running with stale task generation
using a FrozenRunUse after release
releasing before deny/retry/fail-closed settlement
double release
leaking task refs or rq/pi locks at a terminal edge
moving a queued task without rq lock
retrying a denied candidate without stable candidate lifetime
ignoring exit/generation invalidation
behavior, monitor-verification, or protection overclaims
```

## Model

New model:

```text
formal/0080-task-frozen-run-lifetime-locking-gate-model/
```

Checked invariant group:

```text
Safety
```

with component obligations:

```text
NoRunAfterFree
NoRunWithoutStableLifetime
NoRunWhileMigrating
NoStaleGenerationRun
NoUseAfterRelease
NoReleaseBeforeDenySettled
NoDoubleRelease
NoRefLeakAtTerminal
NoMoveWithoutRqLock
NoRetryWithoutStableLifetime
NoExitInvalidationIgnored
NoNonClaimOverreach
```

## Non-Claims

This gate does not approve a Linux hook, task field, storage layout, refcount
scheme, locking protocol, public ABI, monitor ABI, runtime coverage, behavior
change, monitor verification, or production protection.

It supports only this claim shape:

```text
Any future scheduler authority hook must not treat raw task pointers, RCU
visibility, migration state, or released frozen records as runnable authority;
task identity must be live, generation-fresh, and lifetime-stabilized at each
consume/settle edge.
```
