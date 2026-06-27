# Validation 0033: Same-Domain Fast Path Freshness TLC

Status: Completed bounded model check

Date: 2026-06-27

Model:

```text
capsched/capsched-models/formal/0021-same-domain-fastpath-freshness-model/SameDomainFastPath.tla
```

Related analysis:

```text
capsched/capsched-models/analysis/0038-same-domain-monitor-fastpath-budget-freshness.md
```

TLC logs:

```text
/media/nia/scsiusb/dev/linux-cap/build/tlc/same-domain-fastpath-20260627T084157Z/SameDomainFastPathSafe.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/same-domain-fastpath-20260627T084157Z/SameDomainFastPathUnsafeStaleEpoch.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/same-domain-fastpath-20260627T084157Z/SameDomainFastPathUnsafeStaleMemView.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/same-domain-fastpath-20260627T084157Z/SameDomainFastPathUnsafeRunNoBudget.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/same-domain-fastpath-20260627T084157Z/SameDomainFastPathUnsafeNoHzNoTimer.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/same-domain-fastpath-20260627T084157Z/SameDomainFastPathUnsafeRevokeRun.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/same-domain-fastpath-20260627T084157Z/SameDomainFastPathUnsafeSelectedBudget.log
```

## Result Summary

Safe configuration:

```text
config: SameDomainFastPathSafe.cfg
result: PASS
generated states: 25
distinct states: 13
search depth: 10
```

Unsafe configurations produced expected counterexamples:

```text
config: SameDomainFastPathUnsafeStaleEpoch.cfg
target invariant: NoFastPathWithStaleMonitor
result: expected FAIL
generated states before violation: 7
distinct states before violation: 7
depth: 4

config: SameDomainFastPathUnsafeStaleMemView.cfg
target invariant: NoRunWithStaleMonitor
result: expected FAIL
generated states before violation: 7
distinct states before violation: 7
depth: 4

config: SameDomainFastPathUnsafeRunNoBudget.cfg
target invariant: NoRunWithoutBudget
result: expected FAIL
generated states before violation: 10
distinct states before violation: 8
depth: 5

config: SameDomainFastPathUnsafeNoHzNoTimer.cfg
target invariant: NoNoHzBudgetWithoutMonitorTimer
result: expected FAIL
generated states before violation: 14
distinct states before violation: 9
depth: 6

config: SameDomainFastPathUnsafeRevokeRun.cfg
target invariant: NoRevokePendingRun
result: expected FAIL
generated states before violation: 14
distinct states before violation: 9
depth: 6

config: SameDomainFastPathUnsafeSelectedBudget.cfg
target invariant: NoSelectedBudgetStaleRun
result: expected FAIL
generated states before violation: 7
distinct states before violation: 7
depth: 4
```

## Validated Claims

This validation supports the following local design constraints:

```text
1. Same-Domain fast path requires monitor active context, fresh Domain epoch,
   and fresh MemoryView.

2. Running requires fresh monitor-owned context and fresh FrozenRunUse.

3. Running requires both root budget and SchedContext budget.

4. NO_HZ execution of a capped Domain requires monitor-owned or unsuppressible
   budget timer coverage.

5. Revocation pending cannot coexist with ordinary Domain execution.

6. Selected-state budget changes require revalidation, refresh, monitor call,
   or fail-closed before fast path and run.
```

## Unsafe Counterexample Meaning

`SameDomainFastPathUnsafeStaleEpoch.cfg` demonstrates fast path after epoch
staleness:

```text
Start -> MonitorActive -> Selected -> BadFastPathStaleEpoch
```

`SameDomainFastPathUnsafeStaleMemView.cfg` demonstrates execution with stale
MemoryView:

```text
Start -> MonitorActive -> Selected -> BadFastPathStaleMemView
```

`SameDomainFastPathUnsafeRunNoBudget.cfg` demonstrates owner execution after
budget loss:

```text
Start -> MonitorActive -> Selected -> FastPathReady -> BadRunNoBudget
```

`SameDomainFastPathUnsafeNoHzNoTimer.cfg` demonstrates NO_HZ execution of a
capped Domain without a monitor/unsuppressible budget timer:

```text
Start -> MonitorActive -> Selected -> FastPathReady -> Running
  -> BadNoHzNoTimer
```

`SameDomainFastPathUnsafeRevokeRun.cfg` demonstrates same-task/current
continuation after revoke:

```text
Start -> MonitorActive -> Selected -> FastPathReady -> Running -> BadRevokeRun
```

`SameDomainFastPathUnsafeSelectedBudget.cfg` demonstrates selected-state budget
staleness:

```text
Start -> MonitorActive -> Selected -> BadSelectedBudgetRun
```

## Evidence Limits

This validation does not prove:

```text
real monitor call ABI
stage-2/EPT switch ordering
IPI/timer delivery reliability
all NO_HZ_FULL cases
all hrtick and class runtime interactions
SMT/core-wide active context
proxy execution budget charging
root-vs-SchedContext budget accounting details
```

Those remain separate proof obligations.

## Design Consequence

The fast path rule is:

```text
different Domain:
  monitor activation required

same Domain:
  monitor activation may be skipped only if local freshness proof succeeds

same task / no context switch:
  revocation and root budget require interrupt/timer/preemption coverage
```

Skipping the monitor without freshness proof is a protection bug, not a
performance optimization.
