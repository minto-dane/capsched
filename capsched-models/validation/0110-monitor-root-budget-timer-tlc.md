# Validation 0110: Monitor Root Budget Timer TLC

Status: Safe model passed; unsafe models produced expected counterexamples;
JSON contract checked

Date: 2026-07-01

## Target

```text
analysis/0093-monitor-root-budget-timer.md
analysis/monitor-root-budget-timer-v1.json
formal/0071-monitor-root-budget-timer-model/
```

## Purpose

Validate the monitor root-budget timer gate:

```text
Linux timer/accounting is not the root CPU budget.
```

A Domain can run only after the Monitor validates a sealed token, validates the
Domain epoch, owns remaining root budget, and arms a monitor-owned timer or
deadline. Linux hrtick, sched_tick, hrtimer, NO_HZ, and runtime charge reports
remain non-authoritative.

## TLC Run

Run directory:

```text
/media/nia/scsiusb/dev/linux-cap/build/tlc/monitor-root-budget-timer-20260701T202836Z
```

## Results

Safe configuration:

```text
config: MonitorRootBudgetTimerSafe.cfg
result: PASS
states_generated: 78
distinct_states: 37
states_left_on_queue: 0
depth: 7
```

Unsafe configurations produced expected counterexamples:

```text
config: MonitorRootBudgetTimerUnsafeNoTimer.cfg
target invariant: NoRunWithoutMonitorTimer
result: expected FAIL
states_generated_before_violation: 4
distinct_states_before_violation: 4
states_left_on_queue: 1
depth: 3

config: MonitorRootBudgetTimerUnsafeNoBudget.cfg
target invariant: NoRunWithoutRootBudget
result: expected FAIL
states_generated_before_violation: 3
distinct_states_before_violation: 3
states_left_on_queue: 1
depth: 2

config: MonitorRootBudgetTimerUnsafeLinuxTimerRoot.cfg
target invariant: NoLinuxTimerAsRootAuthority
result: expected FAIL
states_generated_before_violation: 3
distinct_states_before_violation: 3
states_left_on_queue: 1
depth: 2

config: MonitorRootBudgetTimerUnsafeOverrun.cfg
target invariant: NoOverrunAfterExpiry
result: expected FAIL
states_generated_before_violation: 24
distinct_states_before_violation: 20
states_left_on_queue: 13
depth: 5

config: MonitorRootBudgetTimerUnsafeLinuxChargeRoot.cfg
target invariant: NoLinuxChargeAsMonitorCharge
result: expected FAIL
states_generated_before_violation: 3
distinct_states_before_violation: 3
states_left_on_queue: 1
depth: 2

config: MonitorRootBudgetTimerUnsafeUnsealedToken.cfg
target invariant: NoActivationWithoutSealedToken
result: expected FAIL
states_generated_before_violation: 3
distinct_states_before_violation: 3
states_left_on_queue: 1
depth: 2

config: MonitorRootBudgetTimerUnsafeEpochRevoked.cfg
target invariant: NoEpochRevokedRunning
result: expected FAIL
states_generated_before_violation: 4
distinct_states_before_violation: 4
states_left_on_queue: 1
depth: 3

config: MonitorRootBudgetTimerUnsafeRunAfterInterrupt.cfg
target invariant: NoRunAfterMonitorInterrupt
result: expected FAIL
states_generated_before_violation: 14
distinct_states_before_violation: 13
states_left_on_queue: 8
depth: 5

config: MonitorRootBudgetTimerUnsafeNoHzStopsMonitor.cfg
target invariant: NoNoHzStopsMonitorTimer
result: expected FAIL
states_generated_before_violation: 9
distinct_states_before_violation: 9
states_left_on_queue: 5
depth: 4

config: MonitorRootBudgetTimerUnsafeProtectionClaim.cfg
target invariant: NoProtectionClaim
result: expected FAIL
states_generated_before_violation: 3
distinct_states_before_violation: 3
states_left_on_queue: 1
depth: 2
```

## JSON Contract Check

Expected:

```text
source_anchors=25
monitor_event_requirements=12
unsafe_cases=10
safety_flags_false=12
safety_flags_total=12
```

## Meaning

This validation strengthens `BUDGET-001` and `ACT-001` only as model evidence.
It shows that a root-budget model must reject execution without a monitor-owned
timer, remaining monitor root budget, sealed token, and fresh epoch, and must
reject Linux timers or Linux runtime reports as root budget authority.

It is not a monitor implementation, Linux hook approval, runtime coverage, or
production protection evidence.

## Non-Claims

This validation does not implement a monitor timer, add Linux hooks, approve a
budget hook, approve a scheduler hook, approve ABI, execute runtime tests,
verify production protection, or select an x86/arm64 monitor implementation.
