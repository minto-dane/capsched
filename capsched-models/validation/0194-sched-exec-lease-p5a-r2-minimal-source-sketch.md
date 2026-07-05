# Validation 0194: SchedExecLease P5A-R2 Minimal Source Sketch

Date: 2026-07-04

Status: passed. No Linux patch is approved.

## Scope

This validates the P5A-R2 minimal source sketch:

```text
analysis/0151-sched-exec-lease-p5a-r2-minimal-source-sketch.md
analysis/sched-exec-lease-p5a-r2-minimal-source-sketch-v1.json
formal/0118-p5a-r2-minimal-source-sketch-model/
validation/run-sched-exec-lease-p5a-r2-minimal-source-sketch.sh
```

## Result

Run:

```text
RUN_ID=20260704T-p5a-r2-minimal-source-sketch-r2
```

The validator passed:

```text
linux_commit: bd71af5daeae808ac948cbd12af2663151936f22
linux_tree: 25dbe4e04baa112ab9a872a897f67bec094df209
source_anchor_count: 36
line_drift_count: 0
missing_anchor_count: 0
augmentation_basis_observed: true
experimental_replacement_target_observed: true
current_group_boundaries_observed: true
hot_layout_conditional_basis_observed: true
late_validation_observed: true
safe TLC: 6 generated states, 5 distinct states, depth 5
unsafe expected counterexamples: 32
```

Output:

```text
build/source-check/sched-exec-lease-p5a-r2-minimal-source-sketch/20260704T-p5a-r2-minimal-source-sketch-r2/result.json
```

## Interpretation

The sketch records the smallest acceptable P5A-R2 production-shaped selector
direction:

```text
piggyback existing EEVDF augmentation
use min_pickable_vruntime-style Fresh summary
use U64_MAX-style sentinel for non-Fresh or non-pickable entities
keep curr outside the tree summary
propagate child cfs_rq Fresh-descendant state through group entities
reject boolean-only summaries, separate eligible trees, post-filter fallback,
unbounded rb_next scans, pick-time policy lookup, monitor calls, and synthetic
task->comm authority
```

It also records that any hot `sched_entity` / `cfs_rq` / `task_struct` layout
change is still conditional and requires a separate object/layout and
disabled-overhead evidence plan before a Linux behavior patch can be accepted.

## Non-Claims

This validation does not approve:

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

The next reviewable step is a P5A-R2 object/layout and disabled-overhead
evidence plan for the possible summary fields and affected hot functions.
