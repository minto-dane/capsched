# Validation 0171: SchedExecLease P5A-R Upstream Drift Source-Shape Refresh

Date: 2026-07-03

Status: upstream/source-shape refresh passed. P5A-R direct scheduler
source-shape remains fresh for ordinary-CFS-only `0009` drafting; lifecycle
drift is recorded and does not support lifecycle/global freshness claims.

## Scope

This validation checks:

```text
analysis/0143-sched-exec-lease-p5a-r-upstream-drift-source-shape-refresh.md
analysis/sched-exec-lease-p5a-r-upstream-drift-source-shape-refresh-v1.json
formal/0112-p5a-r-upstream-drift-source-shape-refresh-model/P5ARUpstreamDriftSourceShapeRefresh.tla
```

## Expected Result

The runner must prove:

```text
upstream/master is fetched to the recorded current commit
previous upstream is an ancestor of current upstream
P5A-R direct scheduler source-shape files did not change between upstream refs
fork/exec lifecycle drift is recorded and not claimed fresh
merge-tree against current upstream is clean
ordinary-CFS 0009 draft remains reviewable
runtime/protection/cost claims remain false
```

## Runner

```text
validation/run-sched-exec-lease-p5a-r-upstream-drift-source-shape-refresh.sh
```

Run output:

```text
build/source-check/sched-exec-lease-p5a-r-upstream-drift-source-shape-refresh/20260703T233452Z/
```

## Checks

Source/upstream checks:

```text
previous_upstream_commit=87320be9f0d24fce67631b7eef919f0b79c3e45c
current_upstream_commit=71dfdfb0209b43dfd6f494f84f5548e4cfd18cb5
direct_source_shape_changed_count=0
lifecycle_changed_count=2
merge_tree_clean=true
ordinary_cfs_0009_draft_reviewable=true
lifecycle_freshness_claim=false
global_all_angles_freshness_claim=false
```

Formal checks:

```text
safe_passed=true
safe_states_generated=5
safe_distinct_states=4
safe_depth=4
unsafe_expected_counterexamples=9
```

## Result

The upstream movement does not invalidate P5A-R ordinary-CFS-only `0009`
drafting. It does invalidate any attempt to claim broad lifecycle/global
freshness from the old source basis without a separate refresh.

## Non-Claims

This validation does not approve:

```text
Linux code changes
accepting 0009
runtime denial correctness
CFS deny-and-repick implementation
fork/exec lifecycle freshness for future patches
global all-angles freshness
runtime coverage
monitor verification
production protection
cost-efficiency
deployment readiness
datacenter readiness
```
