# Validation 0154: SchedExecLease P5A0.E Prepatch Evidence

Date: 2026-07-02

Status: passed for P5A0.E prepatch evidence; no Linux patch approved.

Linux source basis:

```text
a937c67f51d1b82297c4f8b7c471f63e8f1a4fe8
sched/exec_lease: Add allow-only validation skeleton
```

P5A0.E is the evidence package before any future P5A0.P1 Linux patch. It
exists to avoid the earlier ambiguity where "P5A0.1" could mean either
prepatch evidence or the first patch unit.

Canonical names:

```text
P5A0.E:
  prepatch evidence; no Linux patch

P5A0.P1:
  future first no-behavior Linux patch proposal

P5A0.P2:
  future move status plumbing proposal
```

## Subagent Review Integration

Five read-only subagent reviews were integrated:

- security review: P5A0 validation needed stronger non-claim and layout gates;
- performance/scalability review: no-behavior must also gate hot-path overhead,
  layout deltas, object/symbol impact, and trace/static-key overhead;
- upstream-maintenance review: global drift is stale, so P5A0.E needs explicit
  candidate-scoped freshness and stale non-candidate recording;
- formal review: P5A0 models were checklist-style gates and needed stronger
  fields plus a distinct P5A0.E gate;
- Linux source review: current source supports no-behavior evidence only, not
  CFS denial or broad move denial.

## Source-Drift Evidence

Fresh drift run:

```text
build/source-drift/linux-source-drift-gate/20260702T-p5a0-1-drift/
```

Summary:

```text
base_commit=4edcdefd4083ae04b1a5656f4be6cd83ae919ef4
upstream_commit=87320be9f0d24fce67631b7eef919f0b79c3e45c
work_commit=a937c67f51d1b82297c4f8b7c471f63e8f1a4fe8
merge_tree_clean=true
patch_footprint_config_matches_actual=true
model_freshness=stale
candidate_no_behavior_patch_reviewable=false
```

Candidate-scoped freshness:

```text
l0_footprint: changed_count=0
scheduler_authority_core: changed_count=0
```

Non-candidate stale group:

```text
device_queue_iommu: D4_semantic_drift, changed_count=61
```

This stale group remains barred from device, QueueLease, IOMMU, datacenter,
protection, and cost-efficiency claims.

## Source/JSON Gate

Command:

```sh
DOMAINLEASE_RUN_ID=20260702T-p5a0-e-prepatch \
  capsched/capsched-models/validation/run-sched-exec-lease-p5a0-e-prepatch-evidence.sh
```

Output directory:

```text
build/source-check/sched-exec-lease-p5a0-e-prepatch-evidence/20260702T-p5a0-e-prepatch/
```

Result summary:

```text
candidate_groups_fresh                         true
non_candidate_device_queue_iommu_stale_recorded true
global_model_freshness                         false
linux_patch_approved                           false
helper_count                                   3
helper_return_set_allow_only                   true
scheduler_validation_callsite_count            3
scheduler_branch_on_validation_result          false
fair_picker_ineligibility                      false
run_hook_p5_deny_ready                         false
common_move_hook_before_mutation               true
locked_move_hook_before_mutation               true
common_move_returns_status                     false
locked_move_returns_status                     false
common_move_call_count                         2
locked_move_call_count                         3
p5a0_p1_patch_approved                         false
runtime_denial                                 false
production_or_cost_claim                       false
```

## TLC Gate

Model:

```text
formal/0101-p5a0-e-prepatch-evidence-gate-model/P5A0EPrepatchEvidenceGate.tla
```

Output directory:

```text
build/tlc/p5a0-e-prepatch-evidence-gate/20260702T-p5a0-e-prepatch/
```

Safe configuration:

```text
P5A0EPrepatchEvidenceGateSafe.cfg: pass
```

Expected unsafe counterexamples:

```text
P5A0EPrepatchEvidenceGateUnsafeFairPickerDenialClaim
P5A0EPrepatchEvidenceGateUnsafeLayoutOrObjectImpact
P5A0EPrepatchEvidenceGateUnsafeMissingFreshDrift
P5A0EPrepatchEvidenceGateUnsafeMissingPlans
P5A0EPrepatchEvidenceGateUnsafeMoveSettlementClaim
P5A0EPrepatchEvidenceGateUnsafeNonAllowReachable
P5A0EPrepatchEvidenceGateUnsafeP1WithoutFileAllowlist
P5A0EPrepatchEvidenceGateUnsafePatchApproved
P5A0EPrepatchEvidenceGateUnsafeProtectionCostDatacenterClaim
P5A0EPrepatchEvidenceGateUnsafePublicAbiOrMonitor
P5A0EPrepatchEvidenceGateUnsafeRuntimeCoverageOrMonitorClaim
P5A0EPrepatchEvidenceGateUnsafeSchedulerBranch
P5A0EPrepatchEvidenceGateUnsafeSchedulerTouchWithoutReopen
P5A0EPrepatchEvidenceGateUnsafeScopedFreshnessAsGlobal
```

All unsafe configurations failed with `Safety` violation as intended.

## Meaning

P5A0.E closes the evidence-package requirement only. It does not approve a
Linux patch.

The recommended future P5A0.P1 file allowlist is:

```text
include/linux/sched_exec_lease.h
kernel/sched/exec_lease.c
```

Touching scheduler control-flow files such as `kernel/sched/core.c`,
`kernel/sched/sched.h`, `kernel/sched/fair.c`, `kernel/sched/rt.c`,
`kernel/sched/deadline.c`, or `kernel/sched/ext/ext.c` reopens scope.

P5A-R run denial remains blocked because the current run hook is post-picker
and post-class-settlement. P5A-M broad move denial remains blocked because move
helpers are pre-mutation but caller settlement still assumes success.

No runtime denial, runtime coverage, monitor verification, production
protection, hypervisor-grade isolation, cost-efficiency, deployment readiness,
datacenter readiness, or global all-angles freshness is claimed.
