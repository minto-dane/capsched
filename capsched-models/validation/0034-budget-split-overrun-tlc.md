# Validation 0034: Budget Split and NO_HZ Overrun TLC

Status: Completed bounded model check

Date: 2026-06-27

Model:

```text
capsched/capsched-models/formal/0022-budget-split-overrun-model/BudgetSplitOverrun.tla
```

Related analysis:

```text
capsched/capsched-models/analysis/0039-root-schedcontext-budget-nohz-overrun.md
```

TLC logs:

```text
/media/nia/scsiusb/dev/linux-cap/build/tlc/budget-split-overrun-20260627T085335Z/BudgetSplitOverrunSafe.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/budget-split-overrun-20260627T085335Z/BudgetSplitOverrunUnsafeClassRuntimeOnly.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/budget-split-overrun-20260627T085335Z/BudgetSplitOverrunUnsafeNoRootBudget.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/budget-split-overrun-20260627T085335Z/BudgetSplitOverrunUnsafeNoSchedBudget.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/budget-split-overrun-20260627T085335Z/BudgetSplitOverrunUnsafeNoHzNoTimer.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/budget-split-overrun-20260627T085335Z/BudgetSplitOverrunUnsafeHrtickFloor.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/budget-split-overrun-20260627T085335Z/BudgetSplitOverrunUnsafeRemoteTickOnly.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/budget-split-overrun-20260627T085335Z/BudgetSplitOverrunUnsafeReplenishNoEpoch.log
```

## Result Summary

Safe configuration:

```text
config: BudgetSplitOverrunSafe.cfg
result: PASS
generated states: 16
distinct states: 14
search depth: 7
```

Unsafe configurations produced expected counterexamples:

```text
config: BudgetSplitOverrunUnsafeClassRuntimeOnly.cfg
target invariant: NoClassRuntimeAsRootAuthority
result: expected FAIL
generated states before violation: 7
distinct states before violation: 7
depth: 4

config: BudgetSplitOverrunUnsafeNoRootBudget.cfg
target invariant: NoRunWithoutRootBudget
result: expected FAIL
generated states before violation: 7
distinct states before violation: 7
depth: 4

config: BudgetSplitOverrunUnsafeNoSchedBudget.cfg
target invariant: NoRunWithoutSchedContextBudget
result: expected FAIL
generated states before violation: 7
distinct states before violation: 7
depth: 4

config: BudgetSplitOverrunUnsafeNoHzNoTimer.cfg
target invariant: NoNoHzRunWithoutMonitorBudgetTimer
result: expected FAIL
generated states before violation: 15
distinct states before violation: 13
depth: 6

config: BudgetSplitOverrunUnsafeHrtickFloor.cfg
target invariant: NoHrtickFloorClaimAsExactCap
result: expected FAIL
generated states before violation: 11
distinct states before violation: 11
depth: 5

config: BudgetSplitOverrunUnsafeRemoteTickOnly.cfg
target invariant: NoRemoteTickOnlyRootBudgetEnforcer
result: expected FAIL
generated states before violation: 15
distinct states before violation: 13
depth: 6

config: BudgetSplitOverrunUnsafeReplenishNoEpoch.cfg
target invariant: NoReplenishWithoutEpochRefresh
result: expected FAIL
generated states before violation: 15
distinct states before violation: 13
depth: 6
```

`CHECK_DEADLOCK FALSE` is used in these finite safety configurations because
the model intentionally has terminal fail-closed states. Deadlock freedom is not
the property under test here.

## Validated Claims

This validation supports the following local design constraints:

```text
1. Running requires monitor root budget.

2. Running requires SchedContext budget.

3. Existing Linux class runtime cannot be treated as the root CPU authority.

4. Capped NO_HZ execution requires monitor-owned or equivalent unsuppressible
   budget timer coverage.

5. hrtick is not an exact root CPU cap because its delay is Linux-owned and
   has a minimum floor.

6. NO_HZ remote tick is observation/accounting support, not root budget
   enforcement.

7. Runtime replenishment or redistribution must refresh/invalidate budget
   epoch before selected or running use continues.
```

## Unsafe Counterexample Meaning

`BudgetSplitOverrunUnsafeClassRuntimeOnly.cfg` demonstrates a design that lets
class runtime act as authority:

```text
Start -> BudgetsPrepared -> Selected -> BadClassRuntimeOnlyRun
```

`BudgetSplitOverrunUnsafeNoRootBudget.cfg` demonstrates execution without
monitor root budget:

```text
Start -> BudgetsPrepared -> Selected -> BadClassRuntimeOnlyRun
```

`BudgetSplitOverrunUnsafeNoSchedBudget.cfg` demonstrates execution without
SchedContext budget:

```text
Start -> BudgetsPrepared -> Selected -> BadClassRuntimeOnlyRun
```

`BudgetSplitOverrunUnsafeNoHzNoTimer.cfg` demonstrates capped tickless
execution after monitor timer coverage is lost:

```text
Start -> BudgetsPrepared -> Selected -> TimerArmed -> Running
  -> BadNoHzNoTimer
```

`BudgetSplitOverrunUnsafeHrtickFloor.cfg` demonstrates treating hrtick floor
overrun as if execution could still continue safely:

```text
Start -> BudgetsPrepared -> Selected -> TimerArmed -> BadHrtickFloorRun
```

`BudgetSplitOverrunUnsafeRemoteTickOnly.cfg` demonstrates treating the remote
NO_HZ tick as root budget enforcement:

```text
Start -> BudgetsPrepared -> Selected -> TimerArmed -> Running
  -> BadRemoteTickOnlyRun
```

`BudgetSplitOverrunUnsafeReplenishNoEpoch.cfg` demonstrates runtime
replenishment/redistribution without budget epoch refresh:

```text
Start -> BudgetsPrepared -> Selected -> TimerArmed -> Running
  -> BadReplenishNoEpoch
```

## Evidence Limits

This validation does not prove:

```text
real monitor timer implementation
interrupt delivery latency
exact nanosecond overrun bounds
NO_HZ_FULL behavior across all kernel configurations
CFS/RT/DL/SCX class-specific integration
proxy execution owner/caller charging
SMT/core-wide budget accounting
```

Those remain separate proof obligations.

## Design Consequence

The budget rule is:

```text
MonitorRootBudget:
  absolute production root, monitor-owned

SchedContextBudget:
  CapSched scheduler semantic budget, required for execution

ClassRuntimeBudget:
  Linux compatibility/policy/accounting constraint only
```

Existing Linux runtime may narrow execution, but must never expand CapSched
authority or replace monitor-owned root budget enforcement.
