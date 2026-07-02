# SchedExecLease P4 Anchor Manifest Validation

Date: 2026-07-02

Status: source checker passed; safe model passed; unsafe models produced
expected counterexamples.

## Purpose

Validate the P4 anchor manifest without applying a Linux patch.

This validation closes the P4 anchor-manifest blocker. It does not approve P4
implementation, runtime denial, runtime coverage, monitor calls, production
protection, or cost-efficiency claims.

## Source Manifest Check

Manifest:

```text
analysis/sched-exec-lease-p4-anchor-manifest-v1.json
```

Runner:

```text
validation/run-sched-exec-lease-p4-anchor-manifest-check.sh
```

Command:

```sh
DOMAINLEASE_RUN_ID=20260702T210555Z-n169-p4-anchor \
  capsched/capsched-models/validation/run-sched-exec-lease-p4-anchor-manifest-check.sh
```

Result:

```text
run_dir=/media/nia/scsiusb/dev/linux-cap/build/source-check/sched-exec-lease-p4-anchors/20260702T210555Z-n169-p4-anchor
work_commit=d5f77adb5a64f3b2545db6ab1dcdc4aa4442bab3
anchor_count=3
linux_patch_approved=false
runtime_denial=false
runtime_coverage=false
monitor_verified=false
production_protection=false
```

Detected anchors:

```text
anchor_id                                   path                  window_start window_end insert_after insert_before status
A1_final_run_allow_all_join                 kernel/sched/core.c   7065         7249       7196         7198          ok
A2_common_queued_move_allow_all_edge        kernel/sched/core.c   2546         2567       2552         2553          ok
A3_double_rq_queued_move_allow_all_edge     kernel/sched/sched.h  4120         4133       4125         4126          ok
```

Interpretation:

- A1 is before `is_switch = prev != next`, `RCU_INIT_POINTER(rq->curr, next)`,
  and `context_switch()`.
- A2 is before common queued-task detach and CPU mutation.
- A3 is before double-rq locked queued-task detach and CPU mutation.

## TLA Model

Model:

```text
formal/0094-p4-anchor-manifest-gate-model/P4AnchorManifestGate.tla
```

Safe command:

```sh
cd capsched/capsched-models/formal/0094-p4-anchor-manifest-gate-model
java -cp /home/nia/tools/tla/tla2tools.jar \
  tlc2.TLC \
  -metadir /tmp/p4-anchor-manifest-safe \
  -config P4AnchorManifestGateSafe.cfg \
  P4AnchorManifestGate.tla
```

Safe result:

```text
Model checking completed. No error has been found.
2 states generated, 1 distinct states found, 0 states left on queue.
Depth: 1.
Exit: 0.
```

Unsafe batch:

```text
EXPECTED_COUNTEREXAMPLE P4AnchorManifestGateUnsafeCostEfficiencyFromManifest.cfg
EXPECTED_COUNTEREXAMPLE P4AnchorManifestGateUnsafeFinalRunAfterRqCurr.cfg
EXPECTED_COUNTEREXAMPLE P4AnchorManifestGateUnsafeImplementationFromManifest.cfg
EXPECTED_COUNTEREXAMPLE P4AnchorManifestGateUnsafeMissingCommonMoveAnchor.cfg
EXPECTED_COUNTEREXAMPLE P4AnchorManifestGateUnsafeMissingFinalRunAnchor.cfg
EXPECTED_COUNTEREXAMPLE P4AnchorManifestGateUnsafeMissingLockedMoveAnchor.cfg
EXPECTED_COUNTEREXAMPLE P4AnchorManifestGateUnsafeMissingNonCoverage.cfg
EXPECTED_COUNTEREXAMPLE P4AnchorManifestGateUnsafeMoveAfterCpuMutation.cfg
EXPECTED_COUNTEREXAMPLE P4AnchorManifestGateUnsafeMoveAfterDetach.cfg
EXPECTED_COUNTEREXAMPLE P4AnchorManifestGateUnsafeProtectionFromManifest.cfg
EXPECTED_COUNTEREXAMPLE P4AnchorManifestGateUnsafeRuntimeCoverageFromManifest.cfg
EXPECTED_COUNTEREXAMPLE P4AnchorManifestGateUnsafeRuntimeDenialFromManifest.cfg
expected_counterexamples=12 unexpected=0
```

## Decision

The P4 anchor manifest blocker is closed.

Remaining P4 blockers:

1. runtime or static final-run anchor observability record;
2. allow-all helper proof;
3. no reachable denial path proof;
4. generated-code review after the actual P4 patch;
5. build and QEMU validation after the actual P4 patch.

P5 remains blocked by denial source shape, liveness/progress properties,
negative denial tests, path-classification enforcement, async exclusions, and
monitor non-forgeability.

## Non-Claims

This validation does not approve Linux code, P4 implementation, runtime
denial, runtime coverage, ABI, monitor calls, monitor verification, production
protection, hypervisor-grade isolation, cost-efficiency, or deployment
readiness.
