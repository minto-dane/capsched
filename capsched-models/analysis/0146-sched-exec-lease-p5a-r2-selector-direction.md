# Analysis 0146: SchedExecLease P5A-R2 Selector Direction

Date: 2026-07-04

Status: design direction recorded. No Linux patch is approved.

## Purpose

Validation/0187 made `0012` useful but non-production:

```text
post-filter denial can pass the synthetic QEMU test
post-filter denial cannot be the production root
```

This note defines the next P5A-R direction after `0012`. The key shift is:

```text
from:
  CFS picks first, SchedExecLease rejects later

to:
  CFS or an outer lease scheduler sees lease eligibility before selection
```

The production problem is not only "find another task". The production problem
is to preserve the security invariant without turning the scheduler into an
unbounded policy scanner or a hidden fallback authority.

## Source Shape

Current EEVDF already has a useful pattern: the rb-tree is ordered by
`deadline`, and subtree metadata lets the picker prune by eligibility:

```text
linux/kernel/sched/fair.c:1246
linux/kernel/sched/fair.c:1277
linux/kernel/sched/fair.c:1301
linux/kernel/sched/fair.c:1307
linux/kernel/sched/fair.c:1430
linux/kernel/sched/fair.c:1441
linux/kernel/sched/fair.c:1493
linux/kernel/sched/fair.c:1501
```

The relevant hot structures are:

```text
linux/include/linux/sched.h:576
linux/include/linux/sched.h:579
linux/include/linux/sched.h:581
linux/kernel/sched/sched.h:680
linux/kernel/sched/sched.h:697
linux/kernel/sched/sched.h:703
```

Enqueue/dequeue and group propagation are the places that keep the rb-tree and
subtree metadata coherent:

```text
linux/kernel/sched/fair.c:6436
linux/kernel/sched/fair.c:6482
linux/kernel/sched/fair.c:6651
linux/kernel/sched/fair.c:6663
linux/kernel/sched/fair.c:8132
linux/kernel/sched/fair.c:8170
linux/kernel/sched/fair.c:8209
linux/kernel/sched/fair.c:8366
```

The ordinary-CFS fast path remains only one selection path:

```text
linux/kernel/sched/core.c:6146
linux/kernel/sched/core.c:6164
linux/kernel/sched/fair.c:10330
linux/kernel/sched/fair.c:15733
```

Any production selector direction must explicitly settle or exclude the latter
paths.

## Authority Stability Problem

A real SchedExecLease decision is not the same kind of predicate as
`entity_eligible()`:

```text
entity_eligible:
  derived from CFS virtual time and queue state

lease eligible:
  derived from frozen grant, task generation, exec generation, domain epoch,
  grant epoch, CPU, SchedContext budget, and future monitor roots
```

That means a cached picker-visible bit is safe only if it is derived from a
stable frozen admission state and has explicit invalidation on:

```text
task generation change
exec generation change
domain epoch revoke
grant epoch revoke
CPU affinity or cpuset change
SchedContext budget exhaustion/refill
task exit
migration between rq/cfs_rq
group/cgroup movement
future monitor receipt revoke
```

If eligibility depends on the caller or on per-attempt mutable policy lookup,
it must not be cached in CFS tree metadata. The picker is too late for policy.

## Candidate A: Augment Existing CFS Tree

Add scheduler-private subtree metadata analogous to `min_vruntime`, but for
lease-pickable entities.

Possible shape:

```text
se->sched_exec_min_pickable_vruntime
or
se->sched_exec_pickable_subtree
```

Unpickable entities contribute an infinite sentinel. `pick_eevdf()` can then
prune subtrees that contain no pickable eligible entity instead of scanning.

Strengths:

```text
preserves one CFS timeline
can be O(log n)-like
closest to existing EEVDF mechanism
smallest conceptual move from current code
```

Risks:

```text
adds hot sched_entity fields or changes augmented callback payload
requires exact propagation on enqueue/dequeue/reweight/group movement
requires current entity special-case, because curr is not kept in the tree
requires explicit revoke refresh path
cannot encode caller-dependent authority
hard to keep upstream-friendly if the augmentation grows
```

Verdict:

```text
possible P5A-R2 candidate only if eligibility is task-local, frozen before
enqueue, and invalidation is modeled before code.
```

## Candidate B: Separate Eligible Timeline

Maintain a second CFS-local tree containing only lease-pickable entities.

Possible shape:

```text
cfs_rq->sched_exec_eligible_timeline
se->sched_exec_run_node
```

Strengths:

```text
no post-filter scan
clear separation between runnable and execution-eligible
can select only from eligible entities
explicit dequeue from eligible set on revoke
```

Risks:

```text
adds a second rb_node to sched_entity
large hot layout impact
duplicates enqueue/dequeue/group propagation logic
must define whether ineligible runnable tasks contribute to CFS lag/load
can drift from upstream CFS quickly
```

Verdict:

```text
too invasive for the next upstream-shaped L0 slice, but important as a clean
semantic reference for a later split-state Linux design.
```

## Candidate C: Lease Bucket Before CFS

Select a Domain/SchedContext/ExecutionGrant bucket before entering ordinary
CFS. Then run normal CFS inside the selected bucket.

Possible shape:

```text
outer selector:
  Domain/SchedContext/MemoryView/CPU-budget eligibility

inner selector:
  ordinary CFS among tasks admitted to that bucket
```

Strengths:

```text
matches HyperTag/Domain switch cost objective
matches datacenter multi-cluster OS goal
avoids per-task post-filter authority in the hot CFS picker
clear place for root budget, CPU affinity, co-tenancy, and MemoryView policy
can batch same-Domain execution
```

Risks:

```text
larger architectural move than P5A-R ordinary-CFS-only scope
requires integration with cgroup/task_group semantics
requires load balance, migration, wakeup, and tick accounting redesign
requires service-domain and async provenance model integration
```

Verdict:

```text
best long-horizon production direction, but not the immediate small patch.
Use it to constrain L0 so L0 does not paint us into a post-filter corner.
```

## Candidate D: Bounded Candidate Window

Keep one CFS tree and inspect only a fixed number of alternate candidates.

Strengths:

```text
small patch
bounded cost
useful for experimental negative testing
```

Risks:

```text
can fail to find an allowed candidate outside the window
cannot claim complete deny-and-repick
still a post-filter fallback
fairness and starvation semantics are arbitrary unless modeled
```

Verdict:

```text
acceptable only as an L0 experiment with a limited claim. Not production.
```

## Candidate E: Deny Means Block/Quarantine Before Pick

On failed authority, remove the task from CFS eligibility and move it to an
explicit blocked/quarantine state until grant refresh, control-plane action, or
revoke settlement.

Strengths:

```text
fail-closed is explicit
CFS picks from remaining eligible work naturally
avoids running denied tasks
good match for revocation and audit semantics
```

Risks:

```text
denial discovered in pick path is too late unless the state change is modeled
must not silently transform transient budget exhaustion into sleep
requires wakeup/refill/revoke/control-plane semantics
can break Linux compatibility if visible as unexpected blocking
```

Verdict:

```text
necessary as a settlement state, but not sufficient as the picker mechanism.
It belongs after a frozen admission model, not as ad hoc pick-time mutation.
```

## Recommended Direction

For the next project step:

```text
P5A-R2 immediate design target:
  Source/model gate for Candidate A with Candidate C constraints.

Meaning:
  Design a picker-visible lease eligibility summary only for task-local,
  frozen, rq-locked state, while preserving a route toward an outer
  Domain/SchedContext selector.
```

Do not continue extending `0012` fallback as the production path.

The next accepted design must answer:

```text
1. What exact state makes a task lease-pickable before CFS selection?
2. Which events update or invalidate that state?
3. Is the state task-local, Domain-local, SchedContext-local, or CPU-local?
4. Does CFS lag/load include ineligible tasks?
5. How does group hierarchy expose "this subtree has a pickable entity"?
6. How does current entity participate, since current is outside the tree?
7. What is the fail-closed settlement when no pickable entity exists?
8. How are core scheduling, proxy execution, sched_ext, DL server, RT,
   deadline, idle, and class-loop paths excluded or settled?
9. What generated-object/layout evidence is required?
10. What benchmark/cost evidence is required before any cost claim?
```

## Non-Claims

This note does not approve:

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
