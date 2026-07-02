# Analysis 0119: Implementation Reopen Upstream Drift Gate

Status: Design-only implementation-reopen drift gate; no implementation approved

Date: 2026-07-02

## Purpose

Close the B5 upstream-drift recheck blocker from analysis/0113 as a design
gate.

Existing analysis/0086 and analysis/0087 already define a reusable source-only
drift runner. This note specializes that machinery for a stronger question:

```text
May implementation scope be reopened for a proposed SchedExecLease slice?
```

The answer is still no for the current project state because implementation
scope has not been explicitly reopened. But the drift side of the gate has now
been freshly observed against current upstream.

## Fresh Upstream Observation

The Linux upstream remote was fetched on 2026-07-02.

```text
upstream/master_before=665159e246749578d4e4bfe106ee3b74edcdab18
upstream/master_after=4a50a141f05a8d1737661b19ee22ff8455b94409
upstream_after_date=2026-07-01 14:21:03 -1000
upstream_after_subject=Merge tag 'bootconfig-fixes-v7.2-rc1' of git://git.kernel.org/pub/scm/linux/kernel/git/trace/linux-trace
```

Source-only drift gate run:

```text
run_dir=build/source-drift/linux-source-drift-gate/20260702T063331Z-b5-recheck
base_commit=4edcdefd4083ae04b1a5656f4be6cd83ae919ef4
upstream_commit=4a50a141f05a8d1737661b19ee22ff8455b94409
work_commit=a0f2676adda634391983e74f29fcba577a9c919e
base_to_upstream_commit_count=342
watched_changed_count=1
model_refresh_required_count=0
direct_footprint_drift=false
future_attachment_drift=false
semantic_drift_requires_refresh=false
merge_tree_exit=0
merge_tree_clean=true
model_freshness=fresh
linux_patch_approved=false
```

Changed watched path:

```text
kernel/sched/cpufreq_schedutil.c
classification=D1_nearby_non_intersecting_drift
stale_if_changed=false
```

## B5 Reopen Rule

Before any new Linux implementation scope is reopened, a proposal must pass a
fresh drift gate that records:

```text
fresh upstream fetch
exact upstream commit
exact base commit
exact work commit
watched group classification
model freshness
merge-tree result
touched group freshness
claim ledger row
slice-specific gate references
explicit non-claims
```

Clean merge is necessary but insufficient. It proves only mechanical merge
shape. It does not prove semantic freshness.

## Slice-Specific Reopen Requirements

### P3 / placement-only scheduler touchpoints

Required fresh groups:

```text
l0_footprint
scheduler_authority_core
task_lifecycle_identity
```

Required gates:

```text
analysis/0112 source-verified P3/P4 boundary
analysis/0113 implementation-ready audit
analysis/0118 implementation claim ledger gate
```

P3 must still remain no-denial and no-ABI.

### P4 / allow-all final revalidation skeleton

Required fresh groups:

```text
l0_footprint
scheduler_authority_core
task_lifecycle_identity
```

Required gates:

```text
analysis/0100 final run/move hook placement gate
analysis/0115 bounded retry and ineligibility source design
analysis/0118 implementation claim ledger gate
```

P4 must still be allow-all and must not approve denial, retry, fail-closed, or
runtime coverage.

### P5 / test-only denial

Required fresh groups:

```text
l0_footprint
scheduler_authority_core
task_lifecycle_identity
async_workqueue
async_io_uring
```

Required gates:

```text
analysis/0115 bounded retry and ineligibility source design
analysis/0116 negative denial validation plan
analysis/0117 scheduler path classification
analysis/0118 implementation claim ledger gate
```

P5 may only be reopened as test-only denial for the classified support set
unless the path classification and validation plan are updated first.

## Hard Rejects

The implementation-reopen drift gate rejects:

```text
no fresh fetch
no source-drift runner result
unknown watched-group classification
clean merge treated as semantic freshness
stale model freshness
changed touched group without source-map/model refresh
missing claim ledger row
P5 reopening without scheduler path classification
P5 reopening without negative-denial obligations
behavior change approved by drift freshness alone
runtime coverage claim from drift freshness
ABI claim from drift freshness
monitor verification claim from drift freshness
production protection claim from drift freshness
cost-efficiency claim from drift freshness
```

## Current Decision

For the current state:

```text
drift observation: fresh
merge-tree: clean
model freshness: fresh
implementation scope reopened: false
linux patch approved: false
behavior change: false
runtime coverage: false
monitor verification: false
production protection: false
cost-efficiency: false
```

This closes B5 as a design gate. It does not reopen implementation scope. The
remaining blocker is a final implementation-ready audit.

## Non-Claims

This note does not approve Linux code, implementation scope reopening, P3/P4/P5
patches, behavior change, runtime denial, runtime coverage, ABI, monitor ABI,
monitor implementation, monitor verification, production protection,
hypervisor-grade isolation, cost-efficiency, or deployment readiness.
