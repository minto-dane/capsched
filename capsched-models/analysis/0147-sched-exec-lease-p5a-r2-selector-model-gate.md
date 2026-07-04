# Analysis 0147: SchedExecLease P5A-R2 Selector Model Gate

Date: 2026-07-04

Status: model gate defined. No Linux patch is approved.

## Purpose

Analysis/0146 chose the next direction after `0012`:

```text
do not continue turning post-filter fallback into production design
make lease eligibility visible before selection
preserve the long-horizon Domain/SchedContext outer selector
```

This note converts that direction into a model gate. The gate is intentionally
stricter than the current `0012` source shape. `0012` is evidence that a
synthetic denial test can be made to pass; it is also evidence that post-filter
repair is the wrong production root.

## Source Basis

The current CFS/EEVDF picker already has a pattern we can learn from:

```text
linux/kernel/sched/fair.c:1246  __min_vruntime_update
linux/kernel/sched/fair.c:1301  min_vruntime augmented callbacks
linux/kernel/sched/fair.c:1307  __enqueue_entity
linux/kernel/sched/fair.c:1431  EEVDF selector comment
linux/kernel/sched/fair.c:1441  O(log n) augmented rb-tree comment
linux/kernel/sched/fair.c:1494  heap search loop
```

The hot layout anchors are:

```text
linux/include/linux/sched.h:576  struct sched_entity
linux/include/linux/sched.h:579  run_node
linux/include/linux/sched.h:581  min_vruntime
linux/kernel/sched/sched.h:680  struct cfs_rq
linux/kernel/sched/sched.h:697  tasks_timeline
linux/kernel/sched/sched.h:703  curr
```

The current experimental coverage limits are:

```text
linux/kernel/sched/core.c:6149   ordinary all-fair fast path uses test picker
linux/kernel/sched/core.c:6164   class-loop path remains separate
linux/kernel/sched/fair.c:10330  fair-server path uses plain pick_task_fair
linux/kernel/sched/fair.c:15733  fair class op remains plain pick_task_fair
```

These anchors make the gate upstream-trackable: if upstream changes the EEVDF
shape or our experimental `0012` path moves, the gate should fail before a new
patch is approved.

## Model Gate

The formal model is:

```text
formal/0114-p5a-r2-selector-model-gate-model/P5AR2SelectorModelGate.tla
```

The safe path reaches `GateReady` only after all of the following are recorded:

```text
prior 0012 boundary review
P5A-R2 selector direction
source anchors checked
picker-visible-before-selection rule
frozen-before-enqueue rule
task-local cache only
caller-independent cache
invalidation model
generation/epoch model
budget/refill model
affinity/cpuset model
migration/group-refresh model
monitor receipt/exit invalidation model
group hierarchy summary model
EEVDF-compatible min-pickable summary model
boolean-only summary rejection
current entity model
fail-closed settlement model
cross-path settlement or exclusion
CFS accounting separation
outer Domain/SchedContext constraint
no post-filter production rule
no unbounded scan rule
no synthetic authority rule
no pick-time policy lookup rule
layout evidence requirement
benchmark evidence requirement
```

This deliberately treats Candidate A as a cache:

```text
allowed:
  local picker-visible summary of frozen admission state

forbidden:
  authority source
  raw capability storage
  monitor receipt root
  policy lookup result with caller dependence
  synthetic test property such as task name
  boolean-only "subtree has a pickable task" summaries
```

For the immediate CFS/EEVDF shape, the summary must be compatible with the
existing `min_vruntime` pruning discipline. A boolean "has pickable descendant"
is not enough because the picker needs to prune by the earliest eligible
virtual runtime. The model therefore requires an infinite-sentinel style
`min_pickable_vruntime` summary, or an equivalent EEVDF-compatible proof.

## Candidate C Constraint

Candidate A must remain a disciplined local projection of Candidate C:

```text
outer future selector:
  Domain / SchedContext / ExecutionGrant / MemoryView / root budget

inner current selector:
  CFS among tasks already admitted into the chosen execution context
```

If per-task CFS metadata becomes the source of truth, the project collapses
toward a clever container scheduler patch. That is not enough for the
datacenter OS or HyperTag Monitor target.

Therefore P5A-R2 requires:

```text
outerDomainConstraintRecorded = TRUE
```

before any future selector patch can be considered production-shaped.

## Unsafe Configurations

The model rejects twenty-one unsafe families:

```text
missing frozen-before-enqueue
caller-dependent cache
missing invalidation
missing generation/epoch model
missing budget/affinity model
missing migration/group refresh
missing monitor receipt/exit invalidation
missing group summary
missing EEVDF-compatible min summary
boolean-only summary
missing current entity handling
missing fail-closed settlement
missing cross-path settlement/exclusion
missing outer Domain/SchedContext constraint
post-filter production design
unbounded scan design
synthetic authority
pick-time policy lookup
Linux patch approval at this gate
hot layout approval at this gate
runtime/protection/cost/datacenter overclaim
```

## Consequence

The next reviewable work is not another fallback patch. It is:

```text
P5A-R2 selector model validation
```

After that, a future source-only plan may describe a no-behavior or behavior
patch. That future patch must still pass fresh object/layout/cost gates before
touching hot scheduler layout or claiming disabled overhead.

## Non-Claims

This gate does not approve:

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
