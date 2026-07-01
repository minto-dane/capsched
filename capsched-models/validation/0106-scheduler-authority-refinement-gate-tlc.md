# Validation 0106: Scheduler Authority Refinement Gate TLC

Status: Safe model passed; unsafe models produced expected counterexamples;
JSON contract checked

Date: 2026-07-01

## Target

```text
formal/0067-scheduler-authority-refinement-gate-model/
analysis/0089-scheduler-authority-refinement-gate.md
analysis/scheduler-authority-refinement-gate-v1.json
```

## Purpose

This validation checks the integration gate that ties together:

```text
TASK_WAKING failability
donor/current/proxy budget subject selection
selected-state retry and class settlement
```

This is a model gate. It is not Linux implementation approval.

## TLC Run

Run directory:

```text
/media/nia/scsiusb/dev/linux-cap/build/tlc/scheduler-authority-refinement-gate-20260701T194752Z
```

Command shape:

```sh
java -cp /home/nia/tools/tla/tla2tools.jar tlc2.TLC \
  -config <cfg> \
  SchedulerAuthorityRefinementGate.tla
```

## Results

Safe configuration:

```text
config: SchedulerAuthorityRefinementGateSafe.cfg
result: PASS
states_generated: 18
distinct_states: 14
states_left_on_queue: 0
depth: 7
```

Unsafe configurations produced expected counterexamples:

```text
config: SchedulerAuthorityRefinementGateUnsafeTaskWaking.cfg
target invariant: NoTaskWakingWithoutFrozenUse
result: expected FAIL
states_generated_before_violation: 3
distinct_states_before_violation: 3
states_left_on_queue: 1
depth: 2

config: SchedulerAuthorityRefinementGateUnsafeCurrentOnlyProxy.cfg
target invariant: NoRunWithoutDonorBudget
result: expected FAIL
states_generated_before_violation: 15
distinct_states_before_violation: 14
states_left_on_queue: 6
depth: 7

config: SchedulerAuthorityRefinementGateUnsafeRetry.cfg
target invariant: NoRunWithoutSettledSelection
result: expected FAIL
states_generated_before_violation: 10
distinct_states_before_violation: 10
states_left_on_queue: 4
depth: 6

config: SchedulerAuthorityRefinementGateUnsafeNoClassSettlement.cfg
target invariant: NoRunWithoutSettledSelection
result: expected FAIL
states_generated_before_violation: 10
distinct_states_before_violation: 10
states_left_on_queue: 4
depth: 6
```

## Checked Invariants

```text
TypeOK
NoTaskWakingWithoutFrozenUse
NoRunWithoutFrozenUse
NoRunWithoutSettledSelection
NoRunWithoutDonorBudget
NoRunWithoutExecutorAuthority
NoProxyRunWithoutProxyTicket
NoFailClosedRunning
```

## JSON Contract Check

Expected contract:

```text
analysis/scheduler-authority-refinement-gate-v1.json
```

Required checks:

```text
source_anchors=17
unsafe_cases=4
safety_flags_false=13
safety_flags_total=13
```

## Meaning

The validation supports this local design rule:

```text
Scheduler authority core cannot collapse admission freeze, selected state,
donor budget, executor authority, and proxy execution into a current-task-only
check.
```

The gate strengthens `EXEC-001` and `BUDGET-001` model support but does not
turn either into production protection evidence.

## Non-Claims

This validation does not approve:

```text
Linux code changes
task_struct fields
enqueue hooks
pick hooks
switch hooks
budget hooks
direct-call stubs
tracepoint ABI
public ABI
runtime coverage
monitor verification
production protection
```
