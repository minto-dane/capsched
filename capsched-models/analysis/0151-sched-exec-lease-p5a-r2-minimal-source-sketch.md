# Analysis 0151: SchedExecLease P5A-R2 Minimal Source Sketch

Date: 2026-07-04

Status: source sketch gate. No Linux patch is approved.

## Purpose

Analysis/0150 rejects extending the experimental `0012` post-filter fallback.
This note sketches the smallest production-shaped selector path that could
replace it later.

The sketch is deliberately not a Linux patch. It is the source-facing contract
that a later patch must satisfy before it can be reviewed.

## Core Sketch

The future P5A-R2 selector should piggyback the existing EEVDF augmented rb-tree
instead of creating a second timeline or scanning the existing one.

Current EEVDF already stores:

```text
se->min_vruntime = min(se->vruntime, left.min_vruntime, right.min_vruntime)
```

The P5A-R2 shape is the analogous local projection:

```text
se->sched_exec_min_pickable_vruntime =
  min(local_pickable_vruntime(se),
      left.sched_exec_min_pickable_vruntime,
      right.sched_exec_min_pickable_vruntime)
```

with a sentinel:

```text
SCHED_EXEC_PICKABLE_NONE = U64_MAX
```

For a task entity:

```text
Fresh and allowed:
  local_pickable_vruntime = se->vruntime

Stale / Refreshing / Blocked / denied:
  local_pickable_vruntime = SCHED_EXEC_PICKABLE_NONE
```

For a group entity:

```text
child cfs_rq has Fresh pickable descendant:
  local_pickable_vruntime = se->vruntime

otherwise:
  local_pickable_vruntime = SCHED_EXEC_PICKABLE_NONE
```

This lets the parent tree know whether descending into the child can produce a
Fresh runnable leaf without treating the group entity itself as authority.

## Picker Rule

The picker may use a subtree only if the subtree summary proves there is a
Fresh pickable entity that can also satisfy EEVDF eligibility:

```text
vruntime_eligible(cfs_rq, subtree.sched_exec_min_pickable_vruntime)
```

The picker still confirms the candidate entity when it reaches the node. A
summary is a pruning proof, not a replacement for the final task-local freshness
check.

`curr` remains separate from the rb-tree. It needs its own Fresh check and must
not be hidden inside the tree summary.

## Placement

The minimal future patch would likely touch:

```text
kernel/sched/fair.c
kernel/sched/sched.h
```

It may need a hot `struct sched_entity` field in:

```text
include/linux/sched.h
```

That is conditional and not approved here. Any such field requires a separate
object/layout and disabled-overhead evidence gate before a behavior patch is
accepted.

## Rejected Shapes

The sketch rejects:

```text
separate eligible rb-tree
boolean-only subtree marker
post-filter fallback extension
unbounded rb_next() scan
pick-time policy lookup
monitor call from pick_eevdf()
synthetic task->comm authority
group parent pickable without child Fresh descendant
stale current entity running via curr shortcut
```

The current `sched_exec_cfs_test_denies()` harness and `0012` fallback remain
test-only negative evidence, not authority.

## Invalidation Sketch

A future patch must provide a single summary-refresh path that can be called
from each invalidation family mapped in analysis/0148:

```text
task generation / exec generation / exit
domain epoch / grant epoch / future monitor receipt
budget charge / throttle / refill
affinity / cpuset / migration / set_task_cpu
enqueue / dequeue / delayed dequeue
current entering or leaving the tree
cgroup movement and group hierarchy changes
```

The refresh path must do one of two things:

```text
refresh under the required scheduler lock
or
mark affected summaries Stale/Blocked before picker trust
```

It must not silently flip Stale to Fresh.

## Evidence Requirements

Before a Linux behavior patch can be accepted, the project needs:

```text
object size and layout evidence for sched_entity/cfs_rq/task_struct
hot function-size evidence for pick_eevdf and update paths
CONFIG off/on disabled-overhead evidence
negative stale-summary bypass tests
negative group false-positive and false-negative tests
negative current-entity stale tests
QEMU compatibility and denial tests
upstream drift and patch queue replay
security diff review
final overclaim review
```

## Non-Claims

This sketch does not approve:

```text
Linux code changes
new hot fields
accepting 0009-0012
runtime denial correctness
complete CFS deny-and-repick correctness
runtime coverage
monitor enforcement
production protection
cost efficiency
deployment readiness
datacenter readiness
```

## Next

The next reviewable work is an object/layout and disabled-overhead evidence
plan for the possible `sched_entity` / `cfs_rq` summary fields. Only after that
should a P5A-R2 behavior patch be drafted.
