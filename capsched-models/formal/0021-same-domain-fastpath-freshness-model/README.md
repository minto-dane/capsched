# Same-Domain Fast Path Freshness Model

Status: Draft, checked with tiny finite TLC configurations

Date: 2026-06-27

Related analysis:

```text
capsched/capsched-models/analysis/0038-same-domain-monitor-fastpath-budget-freshness.md
```

## Purpose

This model captures the local safety boundary for monitor-backed same-Domain
fast paths:

```text
same Domain does not mean no check.
It means monitor transition can be skipped only if freshness is locally proven.
```

## Modeled Hazards

```text
stale Domain epoch
stale MemoryView
root/SchedContext budget exhaustion after selection
NO_HZ with no monitor budget timer
revocation during same-task/current continuation
```

## Checked Invariants

```text
NoFastPathWithStaleMonitor
NoRunWithStaleMonitor
NoRunWithoutBudget
NoNoHzBudgetWithoutMonitorTimer
NoRevokePendingRun
NoSelectedBudgetStaleRun
```

## Scope Limit

This is not a full context-switch or monitor model. It does not model real
stage-2/EPT operations, IPI delivery, all scheduler classes, SMT/core-wide
active context, or concrete timer drift. It is a design filter for deciding
what a same-Domain fast path must prove before it may skip the monitor.
