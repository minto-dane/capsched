# Candidate-Scoped Drift Closure Gate

Date: 2026-07-02

Status: P4 candidate-scoped drift is closed; P4 implementation remains paused
pending anchor evidence.

## Purpose

N-167 found a real validation issue: the global source-drift gate is stale after
fresh upstream `87320be9f0d24fce67631b7eef919f0b79c3e45c` because
`device_queue_iommu` changed through current `net/` updates.

That global stale result is correct for datacenter, QueueLease, IOMMU, device,
and network claims. However, it is too coarse as the only decision gate for P4,
because P4 is a scheduler-only, allow-all, no-denial, no-ABI, no-monitor
candidate.

This note adds a stricter split:

```text
global all-angles freshness:
  required for broad architecture, device, datacenter, protection, and
  cost-efficiency claims.

candidate-scoped drift closure:
  required for a specific candidate slice, and valid only for the watched
  groups it touches or claims.
```

Candidate-scoped drift closure is not a bypass. It is a containment rule:
unrelated stale groups stay stale and cannot be used as evidence for the
candidate.

## Current Candidate

Candidate:

```text
P4SchedulerAllowAll
```

Candidate mode:

```text
allow-all
no denial
no retry
no fail-closed path
no ABI
no monitor call
no budget enforcement
no runtime coverage claim
no protection claim
```

Candidate touched/claimed groups:

```text
l0_footprint
scheduler_authority_core
task_lifecycle_identity
```

Fresh remote drift evidence from N-167:

```text
run_dir: build/source-drift/linux-source-drift-gate/20260702T203130Z-n167-p4-pre-audit
base_commit: 4edcdefd4083ae04b1a5656f4be6cd83ae919ef4
upstream_commit: 87320be9f0d24fce67631b7eef919f0b79c3e45c
work_commit: d5f77adb5a64f3b2545db6ab1dcdc4aa4442bab3
merge-tree: clean
watch path existence: checked
patch footprint: matches actual base..work diff
```

Candidate groups:

```text
l0_footprint: fresh
scheduler_authority_core: fresh
task_lifecycle_identity: fresh
```

Non-candidate stale group:

```text
device_queue_iommu: stale, D4_semantic_drift, 61 changed paths
```

Therefore:

```text
candidate_scoped_drift_closed=true
global_model_freshness=false
p4_implementation_approved=false
```

## Non-Collapse Rules

Candidate-scoped drift closure must not imply:

- global all-angles freshness;
- device/QueueLease freshness;
- datacenter evaluation freshness;
- P4 implementation approval;
- runtime denial;
- runtime coverage;
- monitor verification;
- production protection;
- hypervisor-grade isolation;
- cost-efficiency;
- deployment readiness.

It only means:

```text
The current scheduler-only P4 candidate is not blocked by unrelated
device_queue_iommu drift, provided all non-claims remain in force and stale
non-candidate groups remain explicitly recorded.
```

## Formal Gate

Formal model:

```text
formal/0093-candidate-scoped-drift-closure-gate-model/
```

The model requires:

```text
freshFetch
sourceDriftRun
exactCommitsRecorded
watchPathExistenceChecked
patchFootprintMatchesActual
groupsClassified
mergeTreeChecked
candidateScopeKnown
touchedGroupsFresh
claimGroupsFresh
no stale group in candidate scope
claim ledger present
non-claims recorded
non-candidate stale groups recorded
non-candidate stale groups blocked from broad claims
```

It rejects:

- unknown candidate scope;
- closure without fresh fetch;
- closure without source-drift run;
- closure without watched-path existence checking;
- closure with footprint mismatch;
- closure with candidate-scope stale groups;
- closure without non-candidate stale recording;
- global freshness claimed from scoped closure;
- P4 implementation approval without anchors;
- runtime denial from P4 scoped drift;
- runtime coverage claim from scoped drift;
- monitor verification claim from scoped drift;
- production/hypervisor-grade protection claim from scoped drift;
- cost-efficiency/deployment claim from scoped drift.

## Decision

The P4 candidate-scoped drift blocker is closed.

P4 implementation is still not approved. Remaining P4 blockers:

1. final-run anchor manifest;
2. queued-move anchor manifest;
3. runtime or static final-run anchor observability;
4. allow-all helper proof;
5. no reachable denial path;
6. generated-code review after the actual P4 patch;
7. QEMU/build validation after the actual P4 patch.

P5 remains blocked by denial source shape, liveness/progress properties,
negative denial tests, path-classification enforcement, async exclusions, and
monitor non-forgeability.

## Non-Claims

This note does not approve Linux code, P4 implementation, P5 denial, runtime
coverage, ABI, monitor calls, monitor verification, production protection,
hypervisor-grade isolation, cost-efficiency, or deployment readiness.
