# Analysis 0150: SchedExecLease P5A-R2 Selector Patch Plan

Date: 2026-07-04

Status: source/design patch-plan gate. No Linux patch is approved.

## Purpose

P5A-R `0012` is useful negative evidence, but it is not a production shape. It
uses a post-filter fallback that can walk the CFS rb-tree after denial blockage.
That helped expose the forward-progress problem in the synthetic workload, but
it is the wrong root for a datacenter-grade scheduler capability boundary.

This record defines the next acceptable patch direction before any new Linux
behavior patch is drafted.

## Patch Direction

The next selector patch must be a P5A-R2 selector-summary patch, not an
extension of `0012`.

```text
accepted direction:
  EEVDF-compatible picker-visible fresh-summary path

rejected production direction:
  larger post-filter fallback
  unbounded rb-tree scan
  pick-time policy lookup
  monitor call from the picker
```

The local CFS mechanism remains only a projection of already frozen authority.
It must not mint authority and must not decide policy at pick time.

## Candidate Shape

Candidate A is allowed only in this constrained form:

```text
leaf:
  frozen task-local authority projection

subtree:
  min_pickable_vruntime-style summary, compatible with EEVDF pruning

stale state:
  not picker proof

picker:
  can use only Fresh summaries
```

Boolean-only subtree markers are rejected. They cannot preserve the ordering
information needed to avoid a scan while respecting EEVDF's pruning structure.

Candidate C remains the long-horizon outer selector:

```text
outer:
  Domain / SchedContext / ExecutionGrant / MemoryView / root budget

inner:
  ordinary CFS among fresh local summaries
```

The patch must not collapse the outer Domain/SchedContext selector into a local
CFS cache.

## Freshness Prerequisites

The patch plan depends on validations/0190, 0191, and 0192:

```text
0190:
  selector model gate; min-pickable summary required

0191:
  invalidation source map; enqueue/dequeue-only freshness rejected

0192:
  Fresh/Stale/Refreshing/Blocked semantics; only Fresh is picker proof
```

A future patch must explicitly cover:

```text
leaf invalidation
current-entity invalidation
group-summary invalidation
future monitor-receipt invalidation
generation / epoch / exec / exit changes
budget charge / throttle / refill
affinity / cpuset / migration / set_task_cpu
cgroup movement and hierarchy changes
```

## Source Boundaries

Default review scope for a future patch is:

```text
kernel/sched/fair.c
kernel/sched/sched.h
```

`include/linux/sched.h` is conditional, not default. A persistent field in
`struct sched_entity` or another hot layout is allowed only after fresh object
size, layout, disabled-overhead, and hot-function-size evidence is defined and
validated.

The patch must not add:

```text
public ABI
trace ABI
exported symbol
LSM hook
cgroup interface
monitor call
```

## Existing Experimental Blockers

The current Linux tree still contains the experimental `0012` fallback:

```text
sched_exec_cfs_pickable_scan()
sched_exec_cfs_pickable_fallback()
```

This plan treats those helpers as negative evidence and replacement targets,
not as production foundations.

## Required Acceptance Evidence

Any future behavior patch needs, at minimum:

```text
patch queue replay
upstream drift and merge-tree refresh
strict checkpatch and maintainer evidence
source-shape checker
CONFIG off/on targeted scheduler build
CONFIG off/on full vmlinux build
object/layout/function-size evidence
disabled-overhead evidence
QEMU compatibility smoke
negative runtime tests for stale-summary bypasses
negative runtime tests for denied CFS forward progress
security diff review
final overclaim review
```

## Non-Claims

This gate does not approve:

```text
Linux code changes
accepting 0009-0012
runtime denial correctness
complete CFS deny-and-repick correctness
runtime coverage
hot layout changes
new ABI
monitor enforcement
production protection
cost efficiency
deployment readiness
datacenter readiness
```

## Next

If this gate validates, the next reviewable work is not a large patch. It is a
concrete P5A-R2 source sketch for the smallest possible `min_pickable` summary
delta, with a separately validated layout/cost plan before touching hot
structures.
