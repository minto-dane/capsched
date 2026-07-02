# Implementation Reopen Drift Gate Model

Status: Checked with safe pass and expected unsafe counterexamples

Date: 2026-07-02

## Purpose

This model checks the B5 implementation-reopen upstream drift gate from
analysis/0119.

The model separates:

```text
fresh upstream observation
watched-group classification
merge-tree cleanliness
model freshness
touched-group freshness
claim-ledger presence
slice-specific gates
actual implementation approval
```

Clean merge is not semantic freshness, and drift freshness alone must not
approve implementation, behavior change, runtime coverage, ABI, monitor
verification, production protection, or cost-efficiency.

## Safe State

The safe state matches the current project posture:

```text
fresh fetch: true
source-drift runner: true
exact commits recorded: true
groups classified: true
merge-tree clean: true
model fresh: true
touched groups fresh: true
claim ledger present: true
P5 path classification present: true
P5 negative plan present: true
implementation scope reopened: false
linux patch approved: false
all protection/cost/ABI claims false
```

## Rejected Behaviors

Unsafe configs reject:

```text
reopen without fresh fetch
reopen without source-drift run
reopen without watched-group classification
clean merge used as semantic freshness
reopen with stale model freshness
reopen with stale touched group
reopen without claim ledger
P5 reopen without path classification
P5 reopen without negative denial plan
behavior change from drift freshness
runtime coverage from drift freshness
ABI from drift freshness
monitor verification from drift freshness
production protection from drift freshness
cost-efficiency from drift freshness
```

## TLC Result

Safe model:

```text
config: ImplementationReopenDriftGateSafe.cfg
result: pass
states_generated: 2
distinct_states: 1
depth: 1
```

Unsafe configs:

```text
ImplementationReopenDriftGateUnsafeNoFreshFetch.cfg: expected counterexample
ImplementationReopenDriftGateUnsafeNoSourceDriftRun.cfg: expected counterexample
ImplementationReopenDriftGateUnsafeUnknownGroupClassification.cfg: expected counterexample
ImplementationReopenDriftGateUnsafeCleanMergeAsFreshness.cfg: expected counterexample
ImplementationReopenDriftGateUnsafeStaleModelReopen.cfg: expected counterexample
ImplementationReopenDriftGateUnsafeTouchedGroupStale.cfg: expected counterexample
ImplementationReopenDriftGateUnsafeMissingClaimLedger.cfg: expected counterexample
ImplementationReopenDriftGateUnsafeP5MissingPathClassification.cfg: expected counterexample
ImplementationReopenDriftGateUnsafeP5MissingNegativePlan.cfg: expected counterexample
ImplementationReopenDriftGateUnsafeBehaviorChangeFromDrift.cfg: expected counterexample
ImplementationReopenDriftGateUnsafeRuntimeCoverageFromDrift.cfg: expected counterexample
ImplementationReopenDriftGateUnsafeAbiFromDrift.cfg: expected counterexample
ImplementationReopenDriftGateUnsafeMonitorVerificationFromDrift.cfg: expected counterexample
ImplementationReopenDriftGateUnsafeProductionProtectionFromDrift.cfg: expected counterexample
ImplementationReopenDriftGateUnsafeCostEfficiencyFromDrift.cfg: expected counterexample
```

## Non-Claims

This model does not approve Linux implementation, implementation scope
reopening, P3/P4/P5 code, behavior change, runtime denial, runtime coverage,
public ABI, monitor ABI, monitor implementation, monitor verification,
production protection, hypervisor-grade isolation, cost-efficiency, or
deployment readiness.
