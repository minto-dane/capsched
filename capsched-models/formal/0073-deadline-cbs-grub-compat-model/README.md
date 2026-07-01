# Formal 0073: Deadline CBS/GRUB Compatibility Model

Status: Checked with safe pass and expected unsafe counterexamples

Date: 2026-07-01

## Purpose

This model checks the compatibility boundary in analysis/0095.

Linux `SCHED_DEADLINE` admission, CBS runtime/replenishment, GRUB reclaim,
inactive timers, dynamic `sched_getattr`, and overrun notification may narrow
or observe scheduling. They must not mint CapSched execution authority,
refresh a stale RunCap-derived use, or replace monitor root budget.

## Required Meaning

```text
running requires CapSchedRunUse
running requires MonitorRootBudget
deadline execution requires Linux DL admission
deadline execution requires CBS runtime availability
GRUB reclaim changes Linux DL runtime accounting only
inactive timers change active-utilization accounting only
dynamic sched_getattr is read-side observation only
dl_overrun is notification only
```

## Forbidden

```text
DL admission as RunCap
CBS replenish as RunCap refresh
DL runtime as monitor budget
GRUB reclaim as monitor budget
inactive timer as Domain revoke/refresh receipt
dynamic sched_getattr as authority
overrun notification as enforcement
run while CBS-throttled
protection claim without implementation
```

## Validation

Recorded in:

```text
validation/0112-deadline-cbs-grub-compat-tlc.md
```

Safe TLC:

```text
70 generated states
27 distinct states
depth 10
```
