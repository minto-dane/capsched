# Budget Split and Overrun Model

Status: Draft, checked with tiny finite TLC configurations

Date: 2026-06-27

Related analysis:

```text
capsched/capsched-models/analysis/0039-root-schedcontext-budget-nohz-overrun.md
```

## Purpose

This model captures the local safety rule for CapSched budget enforcement:

```text
existing Linux class runtime can constrain execution,
but it cannot be the root authority for Domain CPU execution.
```

## Modeled Hazards

```text
class runtime treated as root CPU authority
execution with no MonitorRootBudget
execution with no SchedContextBudget
NO_HZ capped execution without monitor timer coverage
hrtick minimum-delay overrun treated as an exact cap
remote NO_HZ tick treated as root budget enforcement
class-runtime replenishment without budget epoch refresh
```

## Checked Invariants

```text
NoRunWithoutRootBudget
NoRunWithoutSchedContextBudget
NoRunWithStaleBudgetEpoch
NoClassRuntimeAsRootAuthority
NoNoHzRunWithoutMonitorBudgetTimer
NoHrtickFloorClaimAsExactCap
NoRemoteTickOnlyRootBudgetEnforcer
NoReplenishWithoutEpochRefresh
```

## Scope Limit

This is not a full scheduler, timer, cgroup, deadline, or sched_ext model. It
does not model exact nanosecond arithmetic, hrtimer drift, interrupt latency,
CPU hotplug, SMT, proxy execution charging, or BPF scheduler behavior.

It is a design filter: a future patch may use Linux class runtime and timers
for compatibility and measurement, but a monitor-backed protection claim must
be rooted in monitor-owned budget state and unsuppressible timer coverage.
