# Validation 0107: Runtime Charge Subject TLC

Status: Safe model passed; unsafe models produced expected counterexamples;
JSON contract checked

Date: 2026-07-01

## Target

```text
analysis/0090-runtime-charge-subject-map.md
analysis/runtime-charge-subject-v1.json
formal/0068-runtime-charge-subject-model/
```

## Purpose

Validate the `NoUnspecifiedRuntimeCharge` gate:

```text
every runtime surface that informs scheduler budget semantics must explicitly
name current/executor, donor, cgroup donor, class runtime, monitor root budget,
proxy ticket, or observation-only status.
```

## TLC Run

Run directory:

```text
/media/nia/scsiusb/dev/linux-cap/build/tlc/runtime-charge-subject-20260701T195712Z
```

## Results

Safe configuration:

```text
config: RuntimeChargeSubjectSafe.cfg
result: PASS
states_generated: 79
distinct_states: 48
states_left_on_queue: 0
depth: 4
```

Unsafe configurations produced expected counterexamples:

```text
config: RuntimeChargeSubjectUnsafeUnspecified.cfg
target invariant: NoUnspecifiedRuntimeCharge
result: expected FAIL
states_generated_before_violation: 19
distinct_states_before_violation: 19
states_left_on_queue: 16
depth: 3

config: RuntimeChargeSubjectUnsafeClassRuntime.cfg
target invariant: NoClassRuntimeAsRootAuthority
result: expected FAIL
states_generated_before_violation: 19
distinct_states_before_violation: 19
states_left_on_queue: 16
depth: 3

config: RuntimeChargeSubjectUnsafeProxy.cfg
target invariant: NoProxyRuntimeWithoutTicket
result: expected FAIL
states_generated_before_violation: 40
distinct_states_before_violation: 36
states_left_on_queue: 16
depth: 4

config: RuntimeChargeSubjectUnsafeRemoteTick.cfg
target invariant: NoRemoteTickProxyAuthority
result: expected FAIL
states_generated_before_violation: 24
distinct_states_before_violation: 24
states_left_on_queue: 16
depth: 3

config: RuntimeChargeSubjectUnsafeTaskSchedRuntime.cfg
target invariant: NoObservationOnlyAsAuthority
result: expected FAIL
states_generated_before_violation: 33
distinct_states_before_violation: 33
states_left_on_queue: 16
depth: 3

config: RuntimeChargeSubjectUnsafeCfsProxy.cfg
target invariant: NoCfsProxyWithoutDonorCgroup
result: expected FAIL
states_generated_before_violation: 26
distinct_states_before_violation: 26
states_left_on_queue: 16
depth: 3
```

## JSON Contract Check

Expected:

```text
source_anchors=15
unsafe_cases=6
safety_flags_false=12
safety_flags_total=12
```

## Meaning

The validation supports the local design rule that budget models must not
collapse Linux runtime accounting into a single current-task or class-runtime
authority source.

It strengthens BUDGET-001 model evidence only. It is not production protection.

## Non-Claims

This validation does not approve Linux code, budget hooks, task fields,
tracepoint ABI, runtime coverage, monitor verification, behavior change, or
production protection.

