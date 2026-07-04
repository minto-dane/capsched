# Validation 0193: SchedExecLease P5A-R2 Selector Patch Plan

Date: 2026-07-04

Status: passed. No Linux patch is approved.

## Scope

This validates the P5A-R2 selector patch-plan gate:

```text
analysis/0150-sched-exec-lease-p5a-r2-selector-patch-plan.md
analysis/sched-exec-lease-p5a-r2-selector-patch-plan-v1.json
formal/0117-p5a-r2-selector-patch-plan-model/
validation/run-sched-exec-lease-p5a-r2-selector-patch-plan.sh
```

## Result

Run:

```text
RUN_ID=20260704T-p5a-r2-selector-patch-plan-r2
```

The validator passed:

```text
linux_commit: bd71af5daeae808ac948cbd12af2663151936f22
linux_tree: 25dbe4e04baa112ab9a872a897f67bec094df209
prior_missing_count: 0
source_anchor_count: 21
line_drift_count: 0
missing_anchor_count: 0
experimental_blocker_observed: true
selector_basis_observed: true
ordinary_scope_observed: true
safe TLC: 6 generated states, 5 distinct states, depth 5
unsafe expected counterexamples: 30
```

The output is:

```text
build/source-check/sched-exec-lease-p5a-r2-selector-patch-plan/20260704T-p5a-r2-selector-patch-plan-r2/result.json
```

## Interpretation

The gate records that the next production-shaped P5A-R2 selector work must not
extend the experimental `0012` post-filter fallback. It must instead use an
EEVDF-compatible `min_pickable_vruntime`-style fresh summary or equivalent
proof, preserve the outer Domain/SchedContext selector, and rely only on frozen
task-local authority projections.

The checker also records the current experimental blockers:

```text
sched_exec_cfs_pickable_scan()
sched_exec_cfs_pickable_fallback()
```

Those helpers remain negative evidence and replacement targets, not accepted
production design.

## Non-Claims

This validation does not approve:

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

The next reviewable step is a minimal P5A-R2 source sketch for fresh-summary
placement and invalidation plumbing, paired with object/layout and
disabled-overhead evidence requirements before touching hot scheduler
structures.
