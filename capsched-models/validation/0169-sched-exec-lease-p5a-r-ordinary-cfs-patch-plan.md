# Validation 0169: SchedExecLease P5A-R Ordinary-CFS Patch Plan

Date: 2026-07-03

Status: source/formal patch-plan gate passed; safe model passed; 16 unsafe
configs produced expected counterexamples. No Linux code is modified by this
record.

## Scope

This validation checks:

```text
implementation/0033-sched-exec-lease-p5a-r-ordinary-cfs-patch-plan.md
implementation/sched-exec-lease-p5a-r-ordinary-cfs-patch-plan-v1.json
formal/0110-p5a-r-ordinary-cfs-patch-plan-model/P5AROrdinaryCfsPatchPlan.tla
```

## Expected Result

The runner must prove that the plan:

```text
allows drafting 0009 only as ordinary-CFS-only behavior-candidate code
keeps 0009 unaccepted until later validation passes
requires prior P5A-R gates 0163..0168
requires pre-settle picker integration
requires hierarchy and cross-path settlement/exclusion
requires bounded attempt-local carrier shape
requires build/object/QEMU/security/overclaim validation before acceptance
keeps runtime denial, CFS deny-and-repick, protection, and cost claims false
```

## Runner

```text
validation/run-sched-exec-lease-p5a-r-ordinary-cfs-patch-plan.sh
```

Run output:

```text
build/source-check/sched-exec-lease-p5a-r-ordinary-cfs-patch-plan/20260703T230145Z/
```

## Checks

Source/plan checks:

```text
anchor_count=10
missing_anchor_count=0
line_drift_count=0
prior_missing_count=0
semantic_shape_ok=true
pre_settle_window_ok=true
p4_late_for_p5ar_ok=true
cross_path_anchors_ok=true
acceptance_validation_count=22
```

Formal checks:

```text
safe_passed=true
safe_states_generated=6
safe_distinct_states=5
safe_depth=5
unsafe_expected_counterexamples=16
```

Unsafe cases reject:

```text
MissingPriorGates
MissingOrdinaryScope
MissingFileBoundary
MissingPreSettle
MissingHierarchy
MissingCrossPath
MissingBoundedCarrier
MissingNegativeValidation
MissingBuildObjectQemu
MissingDrift
MissingSecurity
PublicAbi
MonitorCall
HotLayout
RuntimeApproval
ProtectionCostClaim
```

## Result

The next Linux patch slot, `0009`, may now be drafted as an ordinary-CFS-only
behavior candidate under this plan.

This means:

```text
linux_behavior_patch_may_be_drafted=true
ordinary_cfs_only=true
acceptance_requires_future_validation=true
```

It does not mean the behavior is accepted. The future `0009` patch must still
pass patch replay, upstream replay/merge-tree, strict checkpatch/get_maintainer,
source-shape checks, full off/on builds, object/layout evidence, QEMU
denial-disabled smoke, QEMU negative denial tests, security diff review, and
final overclaim review.

## Non-Claims

This validation does not approve:

```text
Linux code changes
accepting the 0009 patch
runtime denial correctness
CFS deny-and-repick implementation
broad move denial
runtime coverage
benchmark evidence
budget enforcement
public ABI or trace ABI
monitor calls or monitor verification
production protection
hypervisor-grade isolation
cost-efficiency
deployment readiness
datacenter readiness
```

## Next

Draft the future `0009` Linux behavior patch under this plan, then validate it
as untrusted until the full acceptance matrix passes.
