# Validation 0153: SchedExecLease P5A0 No-Behavior Gate

Date: 2026-07-02

Status: passed for P5A0 proposal gating.

Linux source basis:

```text
a937c67f51d1b82297c4f8b7c471f63e8f1a4fe8
sched/exec_lease: Add allow-only validation skeleton
```

This validation does not approve a Linux code change. It validates the P5A0
proposal boundary recorded in:

```text
analysis/0131-sched-exec-lease-p5a0-no-behavior-infrastructure-proposal.md
implementation/0029-sched-exec-lease-p5a0-no-behavior-infrastructure-proposal.md
formal/0100-p5a0-no-behavior-gate-model/
```

## JSON Gate

Command:

```sh
DOMAINLEASE_RUN_ID=20260702T-p5a0-no-behavior-gate \
  capsched/capsched-models/validation/run-sched-exec-lease-p5a0-no-behavior-gate.sh
```

Output directory:

```text
build/source-check/sched-exec-lease-p5a0-no-behavior-gate/20260702T-p5a0-no-behavior-gate/
```

Result summary:

```text
work_commit_matches                         true
p5a0_proposal_recorded                      true
linux_patch_approved                        false
behavior_change_approved                    false
scheduler_branch_on_non_allow               false
runtime_denial_approved                     false
retry_fail_closed_quarantine                false
public_abi                                  false
monitor_call                                false
move_non_allow_reachable_in_p5a0            false
required_prepatch_evidence_planned          true
required_acceptance_validation_planned      true
production_or_cost_claim                    false
```

## TLC Gate

Model:

```text
formal/0100-p5a0-no-behavior-gate-model/P5A0NoBehaviorGate.tla
```

Output directory:

```text
build/tlc/p5a0-no-behavior-gate/20260702T-p5a0-no-behavior-gate/
```

Safe configuration:

```text
P5A0NoBehaviorGateSafe.cfg: pass
```

Expected unsafe counterexamples:

```text
P5A0NoBehaviorGateUnsafeBehaviorChange
P5A0NoBehaviorGateUnsafeLinuxPatchApproved
P5A0NoBehaviorGateUnsafeMissingPrePatchEvidence
P5A0NoBehaviorGateUnsafeMoveStatusBehavior
P5A0NoBehaviorGateUnsafeNonAllowBranch
P5A0NoBehaviorGateUnsafeProtectionCostOrDeploymentClaim
P5A0NoBehaviorGateUnsafePublicAbiOrMonitor
P5A0NoBehaviorGateUnsafePublicTestHarness
P5A0NoBehaviorGateUnsafeRetryFailClosedQuarantine
P5A0NoBehaviorGateUnsafeRunP4Denial
P5A0NoBehaviorGateUnsafeRuntimeDenial
P5A0NoBehaviorGateUnsafeSetupBehaviorChange
```

All unsafe configurations failed with `Safety` violation as intended.

## Meaning

P5A0 is now a recorded no-behavior proposal gate. It may prepare the shape of
future infrastructure, but this validation explicitly rejects:

- approving a Linux patch from the proposal alone;
- changing scheduler behavior;
- branching on a non-ALLOW validation result;
- runtime denial, retry, fail-closed, or quarantine semantics;
- using the current P4 final-run observation point as a denial hook;
- move-status plumbing that changes task placement or caller settlement;
- public tracepoint/syscall/ioctl/sysfs/procfs/debugfs/monitor ABI;
- production protection, hypervisor-grade isolation, cost-efficiency, or
  deployment-readiness claims.

The next reviewable work is P5A0.1: a prepatch evidence package containing a
fresh drift row for the touched scheduler groups, patch queue plan, source
checker plan, full build/QEMU plan, object/symbol review plan, negative harness
plan, claim ledger row, and explicit non-claims.
