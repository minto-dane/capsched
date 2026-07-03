# Analysis 0143: SchedExecLease P5A-R Upstream Drift and Source-Shape Refresh

Date: 2026-07-03

Status: refreshed upstream/source-shape gate for P5A-R ordinary-CFS patch
drafting.

## Purpose

After the initial P5A-R patch-plan audit, `upstream/master` advanced:

```text
previous_upstream=87320be9f0d24fce67631b7eef919f0b79c3e45c
current_upstream=71dfdfb0209b43dfd6f494f84f5548e4cfd18cb5
```

This gate checks whether that movement invalidates the P5A-R ordinary-CFS-only
source-shape evidence.

## Result

The P5A-R direct scheduler source-shape is still fresh for drafting `0009`.

Current upstream changed:

```text
fs/exec.c
kernel/fork.c
```

Current upstream did not change the P5A-R direct source-shape files between the
previous and current upstream refs:

```text
kernel/sched/core.c
kernel/sched/fair.c
kernel/sched/sched.h
kernel/sched/ext/ext.c
kernel/sched/core_sched.c
```

The local work tree can be merge-tree checked against the current upstream
without a merge conflict:

```text
merge_tree_clean=true
```

## Interpretation

For the narrow next step:

```text
draft ordinary-CFS-only Linux patch 0009
```

the upstream drift is nonblocking.

For wider claims:

```text
task lifecycle freshness
fork/exec global freshness
global all-angles model freshness
production protection
datacenter readiness
```

the drift is not closed by this gate. The fork/exec movement must be re-read
before any lifecycle-facing patch or broad claim depends on it.

## Non-Claims

This gate does not approve:

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
