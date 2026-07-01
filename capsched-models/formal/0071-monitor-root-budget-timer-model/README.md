# Formal 0071: Monitor Root Budget Timer Model

Status: Checked with safe pass and expected unsafe counterexamples

Date: 2026-07-01

## Purpose

This model checks the root CPU budget timer boundary required by analysis/0093.

The model keeps Linux hrtick, sched_tick, hrtimer, NO_HZ, and runtime charge
reports as non-authoritative surfaces. A Domain can run only after the Monitor
validates a sealed token, validates a fresh Domain epoch, owns remaining root
budget, and arms a monitor-owned timer/deadline.

## Required Meaning

```text
run requires monitor timer
run requires monitor root budget
timer expiry stops execution fail-closed
epoch revoke stops execution fail-closed
Linux timers and charge reports do not become root authority
NO_HZ tick stop does not affect the monitor timer
```

## Forbidden

```text
hrtick as root budget
sched_tick as root budget
Linux hrtimer as non-forgeable root
task_sched_runtime as enforcement
Linux charge report as monitor budget debit
run after timer expiry
run after epoch revoke
protection claim without implementation
```

## Validation

Recorded in:

```text
validation/0110-monitor-root-budget-timer-tlc.md
```

Safe TLC:

```text
78 generated states
37 distinct states
depth 7
```
