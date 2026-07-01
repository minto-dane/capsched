# Validation 0109: Runtime Coverage Gate TLC

Status: Safe model passed; unsafe models produced expected counterexamples;
JSON contract checked

Date: 2026-07-01

## Target

```text
analysis/0092-runtime-coverage-gate.md
analysis/runtime-coverage-gate-v1.json
formal/0070-runtime-coverage-gate-model/
```

## Purpose

Validate the trace-only runtime coverage gate:

```text
runtime observation is not runtime authority
```

An acceptable future coverage artifact must record current, donor, proxy
relation, server relation, evidence class, and trace-only non-claims before it
can support a runtime source-coverage claim.

## TLC Run

Run directory:

```text
/media/nia/scsiusb/dev/linux-cap/build/tlc/runtime-coverage-gate-20260701T201835Z
```

## Results

Safe configuration:

```text
config: RuntimeCoverageGateSafe.cfg
result: PASS
states_generated: 49
distinct_states: 29
states_left_on_queue: 0
depth: 6
```

Unsafe configurations produced expected counterexamples:

```text
config: RuntimeCoverageGateUnsafeMissingCurrent.cfg
target invariant: NoAcceptWithoutCurrent
result: expected FAIL
states_generated_before_violation: 6
distinct_states_before_violation: 6
states_left_on_queue: 4
depth: 2

config: RuntimeCoverageGateUnsafeMissingDonor.cfg
target invariant: NoAcceptWithoutDonor
result: expected FAIL
states_generated_before_violation: 6
distinct_states_before_violation: 6
states_left_on_queue: 4
depth: 2

config: RuntimeCoverageGateUnsafeMissingProxy.cfg
target invariant: NoAcceptProxyWithoutRelation
result: expected FAIL
states_generated_before_violation: 12
distinct_states_before_violation: 12
states_left_on_queue: 7
depth: 3

config: RuntimeCoverageGateUnsafeMissingServer.cfg
target invariant: NoAcceptServerWithoutFullCoverage
result: expected FAIL
states_generated_before_violation: 19
distinct_states_before_violation: 16
states_left_on_queue: 7
depth: 4

config: RuntimeCoverageGateUnsafeMissingEvidence.cfg
target invariant: NoAcceptWithoutEvidenceClass
result: expected FAIL
states_generated_before_violation: 6
distinct_states_before_violation: 6
states_left_on_queue: 4
depth: 2

config: RuntimeCoverageGateUnsafeSchedStat.cfg
target invariant: NoSchedStatOnlyAuthority
result: expected FAIL
states_generated_before_violation: 6
distinct_states_before_violation: 6
states_left_on_queue: 4
depth: 2

config: RuntimeCoverageGateUnsafeRemoteTick.cfg
target invariant: NoRemoteTickOnlyProxyCoverage
result: expected FAIL
states_generated_before_violation: 6
distinct_states_before_violation: 6
states_left_on_queue: 4
depth: 2

config: RuntimeCoverageGateUnsafeTraceProtection.cfg
target invariant: NoTraceOnlyProtectionClaim
result: expected FAIL
states_generated_before_violation: 6
distinct_states_before_violation: 6
states_left_on_queue: 4
depth: 2

config: RuntimeCoverageGateUnsafeServerLifecycle.cfg
target invariant: NoServerLifecycleOnlyCoverage
result: expected FAIL
states_generated_before_violation: 6
distinct_states_before_violation: 6
states_left_on_queue: 4
depth: 2

config: RuntimeCoverageGateUnsafeClassRuntimeRoot.cfg
target invariant: NoClassRuntimeAsRootEvidence
result: expected FAIL
states_generated_before_violation: 6
distinct_states_before_violation: 6
states_left_on_queue: 4
depth: 2
```

## JSON Contract Check

Expected:

```text
source_anchors=33
coverage_requirements=12
unsafe_cases=10
safety_flags_false=12
safety_flags_total=12
```

## Meaning

This validation strengthens `BUDGET-001` and `COMPAT-001` only as model
evidence for future trace-only runtime coverage. It says that coverage rows must
not be accepted unless they preserve current/donor/proxy/server distinctions and
non-claim flags.

It is not runtime coverage, Linux implementation, monitor timer evidence, or
production protection evidence.

## Non-Claims

This validation does not execute tracefs, add tracepoints, approve public ABI,
approve Linux hooks, approve budget hooks, provide runtime coverage, verify the
monitor, change behavior, or provide production protection.
