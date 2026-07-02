# Validation 0137: Implementation Claim Ledger Gate TLC

Status: Safe model passed; unsafe models produced expected counterexamples; no
implementation or protection claim

Date: 2026-07-02

## Scope

Validate `formal/0090-implementation-claim-ledger-gate-model/` for the B4
implementation claim-ledger blocker in `analysis/0113` and the claim rules in
`analysis/0118`.

This check verifies claim escalation rules only. It does not approve Linux
implementation, runtime denial, runtime coverage, monitor verification,
production protection, or cost-efficiency.

## Safe Run

Command:

```sh
java -cp /home/nia/tools/tla/tla2tools.jar tlc2.TLC \
  -metadir build/tlc/implementation-claim-ledger-gate-<timestamp>/safe \
  -config ImplementationClaimLedgerGateSafe.cfg \
  ImplementationClaimLedgerGate.tla
```

Result:

```text
exit_code: 0
states_generated: 2
distinct_states: 1
depth: 1
error: none
```

## Unsafe Runs

All unsafe configs exited with code 12 and produced the expected `Safety`
invariant counterexample:

```text
ImplementationClaimLedgerGateUnsafeMissingLedger.cfg
ImplementationClaimLedgerGateUnsafeImplementationApprovalWithoutScope.cfg
ImplementationClaimLedgerGateUnsafeImplementationApprovalStaleDrift.cfg
ImplementationClaimLedgerGateUnsafeBehaviorChangeWithoutEvidence.cfg
ImplementationClaimLedgerGateUnsafeRuntimeDenialWithoutTrace.cfg
ImplementationClaimLedgerGateUnsafeRuntimeCoverageWithoutTrace.cfg
ImplementationClaimLedgerGateUnsafeMonitorVerifiedWithoutMonitor.cfg
ImplementationClaimLedgerGateUnsafeProductionWithoutMonitorEval.cfg
ImplementationClaimLedgerGateUnsafeHypervisorGradeFromP5.cfg
ImplementationClaimLedgerGateUnsafeCostEfficiencyWithoutEvaluation.cfg
ImplementationClaimLedgerGateUnsafePublicAbiWithoutAbiGate.cfg
ImplementationClaimLedgerGateUnsafeModelOnlyProductionClaim.cfg
ImplementationClaimLedgerGateUnsafeCompatibilityAsProtection.cfg
```

## Interpretation

The gate preserves these separations:

```text
model evidence != implementation evidence
build/QEMU compatibility != runtime denial
negative denial tests != full scheduler runtime coverage
runtime trace coverage != monitor verification
monitor validation != cost-efficiency
Linux-only P5 evidence != hypervisor-grade protection
```

## Non-Claims

This validation does not approve implementation, P3/P4/P5 code, behavior
change, runtime denial, runtime coverage, public ABI, monitor ABI, monitor
implementation, monitor verification, production protection, hypervisor-grade
isolation, cost-efficiency, or deployment readiness.
