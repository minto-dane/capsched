# Analysis 0149: SchedExecLease P5A-R2 Invalidation Semantics Gate

Date: 2026-07-04

Status: semantics gate defined. No Linux patch is approved.

## Purpose

Analysis/0148 and validation/0191 mapped where a future picker-visible
`min_pickable_vruntime`-style summary can become stale. This note defines the
semantic rule for what stale means.

The key rule is:

```text
stale summary state is not authority
```

The CFS picker may trust only fresh summaries. Stale, refreshing, or blocked
summaries must fail closed until a refresh rechecks frozen authority,
generation/epoch, budget, affinity, and the affected hierarchy.

## Summary States

P5A-R2 uses four semantic states:

```text
Fresh:
  derived from frozen task-local authority and current generation/epoch/budget/
  affinity state under the required lock.

Stale:
  invalidation was observed, but the affected summary has not been refreshed.

Refreshing:
  refresh is in progress or pending; picker cannot use this summary as proof.

Blocked:
  no fresh pickable proof exists, or monitor/root authority says the summary
  must not be trusted.
```

Only `Fresh` can contribute to picker-visible eligibility.

## Propagation

Invalidation must propagate to the affected summary layer:

```text
leaf summary:
  task generation, exec generation, exit, budget, affinity, migration

current summary:
  current entity entering/leaving the rb-tree, runtime/budget change, exit

group summary:
  leaf summary changes, cgroup movement, cpuset updates, child cfs_rq changes

monitor receipt summary:
  future monitor receipt revoke, domain epoch revoke, root budget revoke
```

The group rule is deliberately strict:

```text
no false positive:
  parent says pickable, but child cannot produce a fresh pickable descendant

no silent false negative:
  parent hides a fresh pickable descendant without explicit settlement
```

## Refresh Rule

Refresh is not a bit flip. A summary may move from `Stale` or `Refreshing` to
`Fresh` only after rechecking:

```text
frozen task-local authority
task generation
exec generation
domain/grant epoch
budget/refill state
affinity/cpuset/CPU placement
current/group membership
future monitor receipt freshness
```

The model rejects:

```text
in-place stale -> fresh without refresh
enqueue/dequeue-only refresh
policy lookup in picker
monitor call in picker
```

## Candidate C Constraint

The semantics preserve the long-horizon outer selector:

```text
outer:
  Domain / SchedContext / ExecutionGrant / MemoryView / root budget

inner:
  CFS among fresh summaries inside the selected execution context
```

The local CFS summary is still only a projection of frozen authority, not the
authority root.

## Formal Gate

The formal model is:

```text
formal/0116-p5a-r2-invalidation-semantics-gate-model/P5AR2InvalidationSemanticsGate.tla
```

It reaches `SemanticsReady` only when:

```text
summary states are defined
leaf/current/group/monitor-revoke propagation is defined
lock ownership is recorded
refresh requires frozen authority
refresh requires generation/epoch checks
refresh requires budget/affinity checks
picker trusts only fresh summaries
stale/refreshing/blocked summaries block picker trust
group summary false positives and silent false negatives are rejected
current entity is separate from tree summary
no fresh summary means fail closed
stale cannot become fresh without refresh
enqueue/dequeue-only refresh is rejected
policy lookup and monitor calls in picker are rejected
outer Domain/SchedContext constraint is preserved
```

## Non-Claims

This semantics gate does not approve:

```text
Linux code changes
accepting 0009-0012
runtime denial correctness
complete CFS deny-and-repick correctness
runtime coverage
hot layout changes
new public ABI
monitor enforcement
production protection
cost efficiency
deployment readiness
datacenter readiness
```

## Next

The next model-side step is a P5A-R2 selector patch plan. It must remain a
source/design gate unless it also includes fresh object/layout/cost validation
requirements for any hot `sched_entity`, `cfs_rq`, or picker changes.
