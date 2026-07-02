# Candidate-Scoped Drift Closure Gate TLC

Date: 2026-07-02

Status: safe model passed; unsafe models produced expected counterexamples.

## Purpose

Validate that P4 candidate-scoped drift closure cannot be confused with global
model freshness, P4 implementation approval, runtime denial, runtime coverage,
monitor verification, production protection, hypervisor-grade isolation,
cost-efficiency, or deployment readiness.

## Model

```text
formal/0093-candidate-scoped-drift-closure-gate-model/CandidateScopedDriftClosureGate.tla
```

Safe configuration:

```text
CandidateScopedDriftClosureGateSafe.cfg
```

Unsafe configurations:

```text
CandidateScopedDriftClosureGateUnsafeUnknownScope.cfg
CandidateScopedDriftClosureGateUnsafeCloseWithoutFreshFetch.cfg
CandidateScopedDriftClosureGateUnsafeCloseWithoutSourceRun.cfg
CandidateScopedDriftClosureGateUnsafeCloseWithoutWatchPathExistence.cfg
CandidateScopedDriftClosureGateUnsafeCloseWithFootprintMismatch.cfg
CandidateScopedDriftClosureGateUnsafeCloseWithCandidateStale.cfg
CandidateScopedDriftClosureGateUnsafeCloseWithoutNonCandidateRecord.cfg
CandidateScopedDriftClosureGateUnsafeGlobalFreshFromScopedGate.cfg
CandidateScopedDriftClosureGateUnsafeImplementationWithoutAnchors.cfg
CandidateScopedDriftClosureGateUnsafeRuntimeDenialFromP4.cfg
CandidateScopedDriftClosureGateUnsafeRuntimeCoverageFromScopedGate.cfg
CandidateScopedDriftClosureGateUnsafeMonitorVerificationFromScopedGate.cfg
CandidateScopedDriftClosureGateUnsafeProtectionFromScopedGate.cfg
CandidateScopedDriftClosureGateUnsafeCostEfficiencyFromScopedGate.cfg
```

## Safe Run

Command:

```sh
cd capsched/capsched-models/formal/0093-candidate-scoped-drift-closure-gate-model
java -cp /home/nia/tools/tla/tla2tools.jar \
  tlc2.TLC \
  -config CandidateScopedDriftClosureGateSafe.cfg \
  CandidateScopedDriftClosureGate.tla
```

Result:

```text
Model checking completed. No error has been found.
2 states generated, 1 distinct states found, 0 states left on queue.
Depth: 1.
Exit: 0.
```

## Unsafe Runs

The first batch used TLC's default `states/` directory and hit timestamp
metadir collisions for five configs. That was runner noise, not a model
counterexample result. The batch was rerun with explicit `-metadir` paths.

Command:

```sh
cd capsched/capsched-models/formal/0093-candidate-scoped-drift-closure-gate-model
rm -rf /tmp/candidate-scoped-drift-tlc
mkdir -p /tmp/candidate-scoped-drift-tlc
for cfg in CandidateScopedDriftClosureGateUnsafe*.cfg; do
  name=${cfg%.cfg}
  log="/tmp/candidate-scoped-drift-tlc/${name}.log"
  metadir="/tmp/candidate-scoped-drift-tlc/${name}-states"
  java -cp /home/nia/tools/tla/tla2tools.jar \
    tlc2.TLC \
    -metadir "$metadir" \
    -config "$cfg" \
    CandidateScopedDriftClosureGate.tla >"$log" 2>&1
done
```

Observed:

```text
EXPECTED_COUNTEREXAMPLE CandidateScopedDriftClosureGateUnsafeCloseWithCandidateStale.cfg
EXPECTED_COUNTEREXAMPLE CandidateScopedDriftClosureGateUnsafeCloseWithFootprintMismatch.cfg
EXPECTED_COUNTEREXAMPLE CandidateScopedDriftClosureGateUnsafeCloseWithoutFreshFetch.cfg
EXPECTED_COUNTEREXAMPLE CandidateScopedDriftClosureGateUnsafeCloseWithoutNonCandidateRecord.cfg
EXPECTED_COUNTEREXAMPLE CandidateScopedDriftClosureGateUnsafeCloseWithoutSourceRun.cfg
EXPECTED_COUNTEREXAMPLE CandidateScopedDriftClosureGateUnsafeCloseWithoutWatchPathExistence.cfg
EXPECTED_COUNTEREXAMPLE CandidateScopedDriftClosureGateUnsafeCostEfficiencyFromScopedGate.cfg
EXPECTED_COUNTEREXAMPLE CandidateScopedDriftClosureGateUnsafeGlobalFreshFromScopedGate.cfg
EXPECTED_COUNTEREXAMPLE CandidateScopedDriftClosureGateUnsafeImplementationWithoutAnchors.cfg
EXPECTED_COUNTEREXAMPLE CandidateScopedDriftClosureGateUnsafeMonitorVerificationFromScopedGate.cfg
EXPECTED_COUNTEREXAMPLE CandidateScopedDriftClosureGateUnsafeProtectionFromScopedGate.cfg
EXPECTED_COUNTEREXAMPLE CandidateScopedDriftClosureGateUnsafeRuntimeCoverageFromScopedGate.cfg
EXPECTED_COUNTEREXAMPLE CandidateScopedDriftClosureGateUnsafeRuntimeDenialFromP4.cfg
EXPECTED_COUNTEREXAMPLE CandidateScopedDriftClosureGateUnsafeUnknownScope.cfg
expected_counterexamples=14 unexpected=0
```

## Validation Decision

The P4 candidate-scoped drift blocker is closed.

This validation does not approve P4 implementation. The model explicitly keeps
`p4ImplementationApproved=false` because final-run and queued-move anchor
manifests and anchor observability are still missing.

Global model freshness remains false for broad claims until the stale
`device_queue_iommu` drift is refreshed or separately scoped out with explicit
non-claims.

## Non-Claims

No Linux patch, behavior change, runtime denial, runtime coverage, ABI,
monitor call, monitor verification, production protection, hypervisor-grade
isolation, cost-efficiency, or deployment readiness is approved by this
validation.
