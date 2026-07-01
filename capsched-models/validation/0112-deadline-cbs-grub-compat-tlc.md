# Validation 0112: Deadline CBS/GRUB Compatibility TLC

Status: Safe model passed; unsafe models produced expected counterexamples;
JSON contract checked

Date: 2026-07-01

## Target

```text
analysis/0095-deadline-cbs-grub-compatibility.md
analysis/deadline-cbs-grub-compat-v1.json
formal/0073-deadline-cbs-grub-compat-model/
```

## Purpose

Validate the Linux `SCHED_DEADLINE` CBS/GRUB compatibility boundary:

```text
Linux DL admission, CBS runtime/replenishment, GRUB reclaim, inactive timers,
dynamic sched_getattr, and overrun notification are compatibility policy or
observation surfaces, not CapSched authority or monitor root budget.
```

DL execution under CapSched requires:

```text
CapSchedRunUse
MonitorRootBudget
Linux DL admission
CBS runtime availability
```

## TLC Run

Run directory:

```text
/media/nia/scsiusb/dev/linux-cap/build/tlc/deadline-cbs-grub-compat-20260701T205812Z
```

## Results

Safe configuration:

```text
config: DeadlineCbsGrubCompatSafe.cfg
result: PASS
states_generated: 70
distinct_states: 27
states_left_on_queue: 0
depth: 10
```

Unsafe configurations produced expected counterexamples:

```text
config: DeadlineCbsGrubCompatUnsafeAdmission.cfg
target invariant: NoLinuxAdmissionAsAuthority
result: expected FAIL
states_generated_before_violation: 5
distinct_states_before_violation: 5
states_left_on_queue: 1
depth: 4

config: DeadlineCbsGrubCompatUnsafeCBSReplenish.cfg
target invariant: NoCBSReplenishAsAuthority
result: expected FAIL
states_generated_before_violation: 30
distinct_states_before_violation: 20
states_left_on_queue: 8
depth: 7

config: DeadlineCbsGrubCompatUnsafeGRUBBudget.cfg
target invariant: NoGRUBAsMonitorBudget
result: expected FAIL
states_generated_before_violation: 8
distinct_states_before_violation: 8
states_left_on_queue: 3
depth: 5

config: DeadlineCbsGrubCompatUnsafeDLRuntimeBudget.cfg
target invariant: NoDLRuntimeAsMonitorBudget
result: expected FAIL
states_generated_before_violation: 8
distinct_states_before_violation: 8
states_left_on_queue: 3
depth: 5

config: DeadlineCbsGrubCompatUnsafeInactiveTimer.cfg
target invariant: NoInactiveTimerAsAuthority
result: expected FAIL
states_generated_before_violation: 8
distinct_states_before_violation: 8
states_left_on_queue: 3
depth: 5

config: DeadlineCbsGrubCompatUnsafeDynamicGetattr.cfg
target invariant: NoDynamicGetattrAsAuthority
result: expected FAIL
states_generated_before_violation: 8
distinct_states_before_violation: 8
states_left_on_queue: 3
depth: 5

config: DeadlineCbsGrubCompatUnsafeOverrunNotification.cfg
target invariant: NoOverrunNotificationAsEnforcement
result: expected FAIL
states_generated_before_violation: 8
distinct_states_before_violation: 8
states_left_on_queue: 3
depth: 5

config: DeadlineCbsGrubCompatUnsafeNoDLAdmission.cfg
target invariant: NoRunWithoutDLAdmission
result: expected FAIL
states_generated_before_violation: 4
distinct_states_before_violation: 4
states_left_on_queue: 1
depth: 3

config: DeadlineCbsGrubCompatUnsafeCBSThrottledRun.cfg
target invariant: NoRunWithoutCBSRuntime
result: expected FAIL
states_generated_before_violation: 8
distinct_states_before_violation: 8
states_left_on_queue: 3
depth: 5

config: DeadlineCbsGrubCompatUnsafeProtectionClaim.cfg
target invariant: NoProtectionClaim
result: expected FAIL
states_generated_before_violation: 28
distinct_states_before_violation: 19
states_left_on_queue: 8
depth: 7
```

## JSON Contract Check

Observed:

```text
source_anchors=48
compatibility_obligations=11
authority_rejections=9
unsafe_cases=10
safety_flags_false=14
safety_flags_total=14
```

## Meaning

This validation strengthens `EXEC-001`, `BUDGET-001`, and `COMPAT-001` model
evidence by requiring Linux deadline compatibility constraints while rejecting
authority collapse from:

```text
admission success
CBS replenish
DL runtime/deadline
GRUB reclaim
inactive timers
dynamic sched_getattr
overrun notification
DL throttling
```

It is not implementation or protection evidence.

## Non-Claims

This validation does not approve Linux code, scheduler hooks, budget hooks,
task fields, tracepoint ABI, ABI changes, runtime coverage, monitor
verification, behavior change, or production protection.
