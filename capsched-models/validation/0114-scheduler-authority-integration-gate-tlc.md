# Validation 0114: Scheduler Authority Integration Gate TLC

Status: Safe model passed; unsafe models produced expected counterexamples;
JSON contract checked

Date: 2026-07-01

## Target

```text
analysis/0097-scheduler-authority-integration-gate.md
analysis/scheduler-authority-integration-gate-v1.json
formal/0075-scheduler-authority-integration-gate-model/
```

## Purpose

Validate the first integration gate that composes recent scheduler authority
models back into one execution boundary:

```text
F1 frozen wake publication
selected-state settlement
server epoch tickets
deadline CBS/GRUB compatibility
monitor root timer/budget/token/epoch
```

The purpose is to prevent satisfying one layer while silently substituting
mutable Linux state for another.

## TLC Run

Run directory:

```text
/media/nia/scsiusb/dev/linux-cap/build/tlc/scheduler-authority-integration-gate-20260701T212750Z
```

## Results

Safe configuration:

```text
config: SchedulerAuthorityIntegrationGateSafe.cfg
result: PASS
states_generated: 59
distinct_states: 38
states_left_on_queue: 0
depth: 6
```

Unsafe configurations produced expected counterexamples:

```text
config: SchedulerAuthorityIntegrationGateUnsafePublication.cfg
target invariant: NoPublicationWithoutFrozenTuple
result: expected FAIL
states_generated_before_violation: 2
distinct_states_before_violation: 2
states_left_on_queue: 0
depth: 2

config: SchedulerAuthorityIntegrationGateUnsafeRunMissingFrozen.cfg
target invariant: NoRunWithoutFrozenTuple
result: expected FAIL
states_generated_before_violation: 2
distinct_states_before_violation: 2
states_left_on_queue: 0
depth: 2

config: SchedulerAuthorityIntegrationGateUnsafeSelectedSettlement.cfg
target invariant: NoRunWithoutSelectedSettlement
result: expected FAIL
states_generated_before_violation: 2
distinct_states_before_violation: 2
states_left_on_queue: 0
depth: 2

config: SchedulerAuthorityIntegrationGateUnsafeServerTicket.cfg
target invariant: NoRunWithoutServerAuthority
result: expected FAIL
states_generated_before_violation: 2
distinct_states_before_violation: 2
states_left_on_queue: 0
depth: 2

config: SchedulerAuthorityIntegrationGateUnsafeServerEpoch.cfg
target invariant: NoRunWithoutServerAuthority
result: expected FAIL
states_generated_before_violation: 2
distinct_states_before_violation: 2
states_left_on_queue: 0
depth: 2

config: SchedulerAuthorityIntegrationGateUnsafeLowerTask.cfg
target invariant: NoRunWithoutServerAuthority
result: expected FAIL
states_generated_before_violation: 2
distinct_states_before_violation: 2
states_left_on_queue: 0
depth: 2

config: SchedulerAuthorityIntegrationGateUnsafeDLAdmission.cfg
target invariant: NoRunWithoutDeadlineCompatibility
result: expected FAIL
states_generated_before_violation: 2
distinct_states_before_violation: 2
states_left_on_queue: 0
depth: 2

config: SchedulerAuthorityIntegrationGateUnsafeCBSThrottled.cfg
target invariant: NoRunWithoutDeadlineCompatibility
result: expected FAIL
states_generated_before_violation: 2
distinct_states_before_violation: 2
states_left_on_queue: 0
depth: 2

config: SchedulerAuthorityIntegrationGateUnsafeMonitorTimer.cfg
target invariant: NoRunWithoutMonitorRoot
result: expected FAIL
states_generated_before_violation: 2
distinct_states_before_violation: 2
states_left_on_queue: 0
depth: 2

config: SchedulerAuthorityIntegrationGateUnsafeLinuxRuntimeAuthority.cfg
target invariant: NoLinuxRuntimeAsAuthority
result: expected FAIL
states_generated_before_violation: 2
distinct_states_before_violation: 2
states_left_on_queue: 0
depth: 2

config: SchedulerAuthorityIntegrationGateUnsafeServerRuntimeAuthority.cfg
target invariant: NoServerRuntimeAsAuthority
result: expected FAIL
states_generated_before_violation: 2
distinct_states_before_violation: 2
states_left_on_queue: 0
depth: 2

config: SchedulerAuthorityIntegrationGateUnsafeDeadlineCompatAuthority.cfg
target invariant: NoDeadlineCompatibilityAsAuthority
result: expected FAIL
states_generated_before_violation: 2
distinct_states_before_violation: 2
states_left_on_queue: 0
depth: 2

config: SchedulerAuthorityIntegrationGateUnsafePlacementAuthority.cfg
target invariant: NoPlacementAsAuthority
result: expected FAIL
states_generated_before_violation: 2
distinct_states_before_violation: 2
states_left_on_queue: 0
depth: 2

config: SchedulerAuthorityIntegrationGateUnsafeRawCap.cfg
target invariant: NoRawCapAfterPublication
result: expected FAIL
states_generated_before_violation: 2
distinct_states_before_violation: 2
states_left_on_queue: 0
depth: 2

config: SchedulerAuthorityIntegrationGateUnsafeHeavyLookup.cfg
target invariant: NoHeavyLookupAfterPublication
result: expected FAIL
states_generated_before_violation: 2
distinct_states_before_violation: 2
states_left_on_queue: 0
depth: 2

config: SchedulerAuthorityIntegrationGateUnsafeFailClosedRunning.cfg
target invariant: NoFailClosedRunning
result: expected FAIL
states_generated_before_violation: 2
distinct_states_before_violation: 2
states_left_on_queue: 0
depth: 2

config: SchedulerAuthorityIntegrationGateUnsafeProtectionClaim.cfg
target invariant: NoProtectionClaim
result: expected FAIL
states_generated_before_violation: 2
distinct_states_before_violation: 2
states_left_on_queue: 0
depth: 2
```

## JSON Contract Check

Observed:

```text
source_anchors=23
integrated_subjects=7
execution_requirements=12
authority_rejections=17
unsafe_cases=17
safety_flags_false=15
safety_flags_total=15
```

## Meaning

This validation strengthens `EXEC-001`, `BUDGET-001`, `COMPAT-001`, and
`ACT-001` model evidence by requiring the scheduler execution edge to compose
all required layers:

```text
FrozenRunUse tuple
selected-state settlement
server ticket freshness
deadline CBS/GRUB compatibility
monitor root timer/budget/token/epoch
```

It rejects authority replacement from:

```text
Linux runtime accounting
Linux server runtime
Linux deadline admission/CBS/GRUB
Linux placement fallback
raw capability handles after publication
heavy authority lookup after publication
fail-closed state that still runs
```

It is not implementation or protection evidence.

## Non-Claims

This validation does not approve Linux code, scheduler hooks, budget hooks,
task fields, public ABI, monitor ABI, tracepoint ABI, runtime coverage,
monitor verification, architecture timer implementation, behavior change, or
production protection.
