# SchedExecLease P4 Allow-All Helper Proof Validation

Date: 2026-07-02

Status: source checker passed; safe model passed; unsafe models produced
expected counterexamples.

## Purpose

Validate the P4 allow-all/no-denial helper proof contract without applying a
P4 patch.

This validation closes the pre-implementation allow-all helper and no reachable
denial path blockers. It does not approve P4 implementation.

## Source Check

Contract:

```text
analysis/sched-exec-lease-p4-allow-all-helper-proof-v1.json
```

Runner:

```text
validation/run-sched-exec-lease-p4-allow-all-helper-proof.sh
```

Command:

```sh
DOMAINLEASE_RUN_ID=20260702T211836Z-n171-allow-all \
  capsched/capsched-models/validation/run-sched-exec-lease-p4-allow-all-helper-proof.sh
```

Result:

```text
run_dir=/media/nia/scsiusb/dev/linux-cap/build/source-check/sched-exec-lease-p4-allow-all-helper/20260702T211836Z-n171-allow-all
work_commit=d5f77adb5a64f3b2545db6ab1dcdc4aa4442bab3
allow_helper_line=80
allow_return_line=82
allow_all_helper_exists=true
allow_all_helper_returns_allow=true
forbidden_nonallow_returns_found=false
p4_validate_helpers_present=false
scheduler_branches_on_validation_result=false
allow_all_helper_proof_closed=true
no_reachable_denial_path_proof_closed=true
linux_patch_approved=false
runtime_denial=false
runtime_coverage=false
monitor_verified=false
production_protection=false
```

Interpretation:

- The current private helper `sched_exec_allow_all_validation()` returns only
  `SCHED_EXEC_VALIDATION_ALLOW`.
- The current tree does not contain P4 validate-run/move helpers.
- The current scheduler does not branch on SchedExecLease validation results.
- Non-allow enum values remain type vocabulary only.

## TLA Model

Model:

```text
formal/0096-p4-allow-all-helper-gate-model/P4AllowAllHelperGate.tla
```

Safe command:

```sh
cd capsched/capsched-models/formal/0096-p4-allow-all-helper-gate-model
java -cp /home/nia/tools/tla/tla2tools.jar \
  tlc2.TLC \
  -metadir /tmp/p4-allow-all-helper-safe \
  -config P4AllowAllHelperGateSafe.cfg \
  P4AllowAllHelperGate.tla
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
EXPECTED_COUNTEREXAMPLE P4AllowAllHelperGateUnsafeAbi.cfg
EXPECTED_COUNTEREXAMPLE P4AllowAllHelperGateUnsafeBudgetCharge.cfg
EXPECTED_COUNTEREXAMPLE P4AllowAllHelperGateUnsafeCostEfficiencyFromHelperProof.cfg
EXPECTED_COUNTEREXAMPLE P4AllowAllHelperGateUnsafeHelperReturnsIneligible.cfg
EXPECTED_COUNTEREXAMPLE P4AllowAllHelperGateUnsafeHelperReturnsQuarantine.cfg
EXPECTED_COUNTEREXAMPLE P4AllowAllHelperGateUnsafeHelperReturnsRetry.cfg
EXPECTED_COUNTEREXAMPLE P4AllowAllHelperGateUnsafeImplementationFromHelperProof.cfg
EXPECTED_COUNTEREXAMPLE P4AllowAllHelperGateUnsafeMonitorCall.cfg
EXPECTED_COUNTEREXAMPLE P4AllowAllHelperGateUnsafeNoSourceCheck.cfg
EXPECTED_COUNTEREXAMPLE P4AllowAllHelperGateUnsafeNonAllowReachable.cfg
EXPECTED_COUNTEREXAMPLE P4AllowAllHelperGateUnsafeProtectionFromHelperProof.cfg
EXPECTED_COUNTEREXAMPLE P4AllowAllHelperGateUnsafeQuarantineBehavior.cfg
EXPECTED_COUNTEREXAMPLE P4AllowAllHelperGateUnsafeRetryBehavior.cfg
EXPECTED_COUNTEREXAMPLE P4AllowAllHelperGateUnsafeRuntimeCoverageFromHelperProof.cfg
EXPECTED_COUNTEREXAMPLE P4AllowAllHelperGateUnsafeSchedulerBranchesOnResult.cfg
expected_counterexamples=15 unexpected=0
```

## Decision

The P4 allow-all helper proof and no reachable denial path proof blockers are
closed at pre-implementation design scope.

Remaining before accepting an actual P4 patch:

1. implement the P4 patch;
2. run generated-code/object review;
3. run off/on build validation;
4. run QEMU compatibility validation;
5. run overclaim/security-diff review for the patch.

P5 remains blocked by denial source shape, liveness/progress properties,
negative denial tests, path-classification enforcement, async exclusions, and
monitor non-forgeability.

## Non-Claims

This validation does not approve Linux code, P4 implementation, runtime
denial, runtime coverage, ABI, monitor calls, monitor verification, production
protection, hypervisor-grade isolation, cost-efficiency, or deployment
readiness.
