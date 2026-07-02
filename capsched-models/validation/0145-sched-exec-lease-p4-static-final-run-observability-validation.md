# SchedExecLease P4 Static Final-Run Observability Validation

Date: 2026-07-02

Status: source checker passed; safe model passed; unsafe models produced
expected counterexamples.

## Purpose

Validate static final-run anchor observability without claiming runtime
coverage.

This validation closes the static final-run observability blocker for the P4
allow-all candidate. It does not approve P4 implementation.

## Source Check

Contract:

```text
analysis/sched-exec-lease-p4-static-final-run-observability-v1.json
```

Runner:

```text
validation/run-sched-exec-lease-p4-static-final-run-observability.sh
```

Command:

```sh
DOMAINLEASE_RUN_ID=20260702T211219Z-n170-static-final-run \
  capsched/capsched-models/validation/run-sched-exec-lease-p4-static-final-run-observability.sh
```

Result:

```text
run_dir=/media/nia/scsiusb/dev/linux-cap/build/source-check/sched-exec-lease-p4-final-run-observability/20260702T211219Z-n170-static-final-run
work_commit=d5f77adb5a64f3b2545db6ab1dcdc4aa4442bab3
window_start=7065
window_end=7249
insert_after=7196
insert_before=7198
rq_curr_line=7205
trace_sched_switch_line=7235
p3_note_switch_line=7237
context_switch_line=7239
static_pre_rq_curr_anchor_observable=true
runtime_final_run_coverage_proven=false
p3_note_switch_usable_as_precommit_anchor=false
linux_patch_approved=false
runtime_denial=false
runtime_coverage=false
monitor_verified=false
production_protection=false
```

Interpretation:

- The future P4 final-run allow-all helper interval is statically observable
  before `rq->curr` publication.
- The existing P3 `sched_exec_lease_note_switch(prev, next)` marker is after
  `rq->curr` publication and cannot stand in for the P4 precommit anchor.
- Runtime final-run coverage remains unproven.

## TLA Model

Model:

```text
formal/0095-static-final-run-observability-gate-model/StaticFinalRunObservabilityGate.tla
```

Safe command:

```sh
cd capsched/capsched-models/formal/0095-static-final-run-observability-gate-model
java -cp /home/nia/tools/tla/tla2tools.jar \
  tlc2.TLC \
  -metadir /tmp/static-final-run-observability-safe \
  -config StaticFinalRunObservabilityGateSafe.cfg \
  StaticFinalRunObservabilityGate.tla
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
EXPECTED_COUNTEREXAMPLE StaticFinalRunObservabilityGateUnsafeCostEfficiencyFromStatic.cfg
EXPECTED_COUNTEREXAMPLE StaticFinalRunObservabilityGateUnsafeImplementationFromStatic.cfg
EXPECTED_COUNTEREXAMPLE StaticFinalRunObservabilityGateUnsafeNoSourceCheck.cfg
EXPECTED_COUNTEREXAMPLE StaticFinalRunObservabilityGateUnsafeNoStaticAnchor.cfg
EXPECTED_COUNTEREXAMPLE StaticFinalRunObservabilityGateUnsafeP3MarkerAsPrecommit.cfg
EXPECTED_COUNTEREXAMPLE StaticFinalRunObservabilityGateUnsafeProtectionFromStatic.cfg
EXPECTED_COUNTEREXAMPLE StaticFinalRunObservabilityGateUnsafeRuntimeCoverageFromStatic.cfg
EXPECTED_COUNTEREXAMPLE StaticFinalRunObservabilityGateUnsafeRuntimeDenialFromStatic.cfg
EXPECTED_COUNTEREXAMPLE StaticFinalRunObservabilityGateUnsafeStaticAnchorAfterRqCurr.cfg
expected_counterexamples=9 unexpected=0
```

## Decision

The static final-run anchor observability blocker is closed.

Remaining P4 blockers:

1. allow-all helper proof;
2. no reachable denial path proof;
3. generated-code review after the actual P4 patch;
4. build and QEMU validation after the actual P4 patch.

Runtime final-run coverage remains unproven and must not be claimed.

## Non-Claims

This validation does not approve Linux code, P4 implementation, runtime
denial, runtime coverage, ABI, monitor calls, monitor verification, production
protection, hypervisor-grade isolation, cost-efficiency, or deployment
readiness.
