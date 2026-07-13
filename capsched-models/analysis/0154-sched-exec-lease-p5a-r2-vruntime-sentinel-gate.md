# Analysis 0154: SchedExecLease P5A-R2 Vruntime Sentinel Gate

Date: 2026-07-13

Status: source/representation gate. No Linux patch or hot field is approved.

## Purpose

Analysis/0151 used a literal `U64_MAX` value as the provisional
`SCHED_EXEC_PICKABLE_NONE` sentinel for a future picker-visible
`min_pickable_vruntime` summary. Validation/0197 through 0199 then established
the layout and disabled-build baseline needed to examine that representation
more precisely.

The literal sentinel is not valid for Linux CFS vruntime ordering. This note
corrects the representation before any behavior patch is drafted.

## Source Fact: Vruntime Is a Cyclic Order

Current CFS compares vruntime values using a signed delta:

```c
(s64)(a - b)
```

This is intentional. Vruntime is a wrapping `u64` domain whose meaningful
values must remain within a signed half-range, not a conventional integer
domain with a global maximum.

For example:

```text
a = U64_MAX
b = 100
(s64)(a - b) = -101
```

Therefore `vruntime_cmp(U64_MAX, ">", 100)` is false. A summary initialized to
literal `U64_MAX` can fail to adopt a real child minimum. Passing the same
literal to `vruntime_eligible()` is also unsafe because that function first
converts the delta from `cfs_rq->zero_vruntime` into the signed vruntime
coordinate system. The sentinel can look like an old, eligible vruntime rather
than "none".

## Correct Representation

Absence must be represented outside the vruntime number:

```text
summary.valid = false:
  summary.min_vruntime is unspecified and must not be read as picker proof

summary.valid = true:
  summary.min_vruntime is the wrap-aware minimum vruntime of at least one
  Fresh and locally pickable descendant
```

The combination operator is:

```text
none + none = none
valid(a) + none = valid(a)
none + valid(b) = valid(b)
valid(a) + valid(b) = valid(vruntime_min(a, b))
```

The `valid` bit is not the rejected boolean-only summary from analysis/0151.
A boolean-only summary cannot preserve EEVDF pruning order. Here validity and
the numeric minimum are an inseparable pair: validity says whether a proof
exists, while the wrap-aware minimum supplies the ordering proof.

Names and physical field placement remain provisional. This gate does not
approve adding either field to `struct sched_entity` or `struct cfs_rq`.

## Picker Rule

A future left-subtree pruning check must guard the numeric value:

```text
left.summary.valid &&
vruntime_eligible(cfs_rq, left.summary.min_vruntime)
```

The picker must still validate the reached entity. An augmented summary is a
pruning proof, not authority and not a replacement for the final frozen
task-local Fresh check.

## Current and Group Boundaries

`cfs_rq->curr` is outside `tasks_timeline`, so it cannot be silently folded
into an rb-node aggregate. It requires a separate Fresh/pickable check.

For a group entity, local validity is a projection of the child `cfs_rq`:

```text
child tree has a valid Fresh descendant
or
child curr is separately Fresh and pickable
```

When that child aggregate changes, the group entity's contribution to its
parent tree must be recomputed and propagated through the existing augmented
tree mechanism. The update must be owned by the runqueue locking boundary.
Enqueue/dequeue-only refresh remains insufficient because lifecycle, epoch,
budget, affinity, migration, throttle/refill, current, group, and future
monitor-receipt events can invalidate the proof while an entity remains
runnable.

## Layout Consequence

Validation/0198 measured the current x86_64 baseline:

```text
sched_entity size: 320
cfs_rq size: 384
```

The source layout currently has small flag storage followed by aligned `u64`
fields, but this does not authorize assuming that a validity bit is free on
all configurations or architectures. A future candidate must re-run the
probe on each claimed architecture and compare CONFIG off/on/candidate modes.

The arm64 reconstruction baseline executed on 2026-07-13 also passed CONFIG
off/on targeted builds and explicit probe compilation. It is environment
compatibility evidence only, not a hot-layout approval.

## Rejected Representations

```text
literal U64_MAX as numeric infinity
any other untagged numeric sentinel in the cyclic vruntime domain
boolean-only subtree pickable flag
reading the numeric member while valid=false
using ordinary unsigned min instead of vruntime-aware ordering
folding curr into the rb-tree aggregate
group validity without a Fresh child tree-or-curr witness
enqueue/dequeue-only freshness
picker-time monitor or policy calls
extending the 0012 post-filter scan
```

## Non-Claims

This gate does not approve:

```text
Linux code changes
new hot scheduler fields
runtime behavior changes
accepting 0009-0012 as production design
runtime denial correctness
complete CFS deny-and-repick correctness
runtime coverage
monitor enforcement
production protection
performance or cost efficiency
deployment readiness
datacenter readiness
```

## Next

Create a P5A-R2 summary update-closure source map before drafting a Linux
behavior patch. It must map exact update and propagation obligations for:

```text
rb insert/erase and explicit augmentation propagation
set_next_entity() and put_prev_entity()
child cfs_rq to parent group entity projection
lifecycle and generation/epoch invalidation
budget charge, throttle, unthrottle, and refill
affinity, cpuset, migration, and cgroup movement
future monitor receipt revoke
```
