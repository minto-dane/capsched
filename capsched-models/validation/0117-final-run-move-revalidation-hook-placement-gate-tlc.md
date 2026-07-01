# Validation 0117: Final Run/Move Revalidation Hook Placement Gate TLC

Status: Safe model passed; unsafe models produced expected counterexamples;
JSON contract checked

Date: 2026-07-01

## Target

```text
analysis/0100-final-run-move-revalidation-hook-placement-gate.md
analysis/final-run-move-revalidation-hook-placement-gate-v1.json
formal/0078-final-run-move-revalidation-hook-placement-gate-model/
```

## Purpose

Validate the N-146 gate for final ordinary Domain run commitment and queued
task movement. This validation checks that final run/move authorization is a
tuple-consumption edge, not a reusable freshness boolean and not Linux selected
state.

## TLC Run

Run directory:

```text
/media/nia/scsiusb/dev/linux-cap/build/tlc/final-run-move-revalidation-hook-placement-gate-20260701T223939Z
```

Safe configuration:

```text
config: FinalRunMoveRevalidationHookPlacementGateSafe.cfg
result: PASS
states_generated: 750
distinct_states: 455
states_left_on_queue: 0
depth: 21
```

Unsafe configurations produced expected counterexamples:

```text
FinalRunMoveRevalidationHookPlacementGateUnsafeAttachTaskAuthority.cfg
FinalRunMoveRevalidationHookPlacementGateUnsafeBehaviorChangeClaim.cfg
FinalRunMoveRevalidationHookPlacementGateUnsafeCoreSchedulingAuthority.cfg
FinalRunMoveRevalidationHookPlacementGateUnsafeCoreSeqStale.cfg
FinalRunMoveRevalidationHookPlacementGateUnsafeDlPushPullAuthority.cfg
FinalRunMoveRevalidationHookPlacementGateUnsafeDomainEpochStale.cfg
FinalRunMoveRevalidationHookPlacementGateUnsafeEdgeMismatch.cfg
FinalRunMoveRevalidationHookPlacementGateUnsafeFairBalanceAuthority.cfg
FinalRunMoveRevalidationHookPlacementGateUnsafeHookAfterRqCurrCommit.cfg
FinalRunMoveRevalidationHookPlacementGateUnsafeHotplugPushAuthority.cfg
FinalRunMoveRevalidationHookPlacementGateUnsafeLinuxExceptionAuthority.cfg
FinalRunMoveRevalidationHookPlacementGateUnsafeLinuxHookApproved.cfg
FinalRunMoveRevalidationHookPlacementGateUnsafeMigrationStopAuthority.cfg
FinalRunMoveRevalidationHookPlacementGateUnsafeMonitorVerifiedClaim.cfg
FinalRunMoveRevalidationHookPlacementGateUnsafeMoveDestMismatch.cfg
FinalRunMoveRevalidationHookPlacementGateUnsafeMoveOutsideFreshSet.cfg
FinalRunMoveRevalidationHookPlacementGateUnsafeMoveQueuedAuthority.cfg
FinalRunMoveRevalidationHookPlacementGateUnsafeMoveSeqStale.cfg
FinalRunMoveRevalidationHookPlacementGateUnsafeMoveUsingRunValidation.cfg
FinalRunMoveRevalidationHookPlacementGateUnsafeMoveWithPendingMigration.cfg
FinalRunMoveRevalidationHookPlacementGateUnsafeMoveWithStaleValidation.cfg
FinalRunMoveRevalidationHookPlacementGateUnsafeMoveWithoutValidation.cfg
FinalRunMoveRevalidationHookPlacementGateUnsafeNoIntersectionRun.cfg
FinalRunMoveRevalidationHookPlacementGateUnsafePickNextAuthority.cfg
FinalRunMoveRevalidationHookPlacementGateUnsafeProtectionClaim.cfg
FinalRunMoveRevalidationHookPlacementGateUnsafeProxyMigrateAuthority.cfg
FinalRunMoveRevalidationHookPlacementGateUnsafeRtPushPullAuthority.cfg
FinalRunMoveRevalidationHookPlacementGateUnsafeRunCapEpochStale.cfg
FinalRunMoveRevalidationHookPlacementGateUnsafeRunDestMismatch.cfg
FinalRunMoveRevalidationHookPlacementGateUnsafeRunOutsideFreshSet.cfg
FinalRunMoveRevalidationHookPlacementGateUnsafeRunUsingMoveValidation.cfg
FinalRunMoveRevalidationHookPlacementGateUnsafeRunWithPendingMigration.cfg
FinalRunMoveRevalidationHookPlacementGateUnsafeRunWithStaleValidation.cfg
FinalRunMoveRevalidationHookPlacementGateUnsafeRunWithoutValidation.cfg
FinalRunMoveRevalidationHookPlacementGateUnsafeSchedCtxEpochStale.cfg
FinalRunMoveRevalidationHookPlacementGateUnsafeScxDispatchAuthority.cfg
FinalRunMoveRevalidationHookPlacementGateUnsafeScxSeqStale.cfg
FinalRunMoveRevalidationHookPlacementGateUnsafeSetTaskCpuAuthority.cfg
FinalRunMoveRevalidationHookPlacementGateUnsafeTaskGenStale.cfg
```

Summary:

```text
expected_fails: 39
unexpected_passes: 0
other_failures: 0
```

## JSON Contract Check

Observed:

```text
source_anchors=33
tuple_fields=13
run_edges=2
move_edges=10
invalidation_sources=12
forbidden_substitutions=18
unsafe_cases=39
safety_flags_false=16
safety_flags_total=16
```

## Meaning

This validation strengthens `ACT-001`, `EXEC-001`, and `COMPAT-001` model
evidence by requiring future scheduler hooks to preserve a final tuple
consumption boundary for both ordinary Domain run commitment and queued-task
movement.

It rejects authority replacement from:

```text
pick_next_task
set_task_cpu
move_queued_task
attach/detach task movement
fair balancing
RT push/pull
DL push/pull/server selection
sched_ext dispatch/DSQ custody
core scheduling cached picks and cookie steal
proxy migration
hotplug push
migration stop
Linux exception task kinds for ordinary Domain execution
hook placement after rq->curr commit
```

It is not implementation or protection evidence.

## Non-Claims

This validation does not approve Linux code, task fields, scheduler hooks,
budget hooks, public ABI, monitor ABI, runtime coverage, monitor
implementation, monitor verification, behavior change, or production
protection.
