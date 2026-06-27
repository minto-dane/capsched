# Placement Refresh Authority Model

Status: Draft, checked with tiny finite TLC configurations

Date: 2026-06-27

Related analysis:

```text
capsched/capsched-models/analysis/0037-placement-refresh-affinity-hotplug-authority.md
```

## Purpose

This model captures the local placement safety boundary:

```text
Linux placement decisions are hints/inputs.
FrozenRunUse.allowed_cpus plus a fresh PlacementEpoch is execution authority.
```

## Modeled Events

```text
FreezeRunUse:
  freezes CPU placement authority while current Linux placement is fresh

SelectForRun:
  represents select_task_rq(), class placement, sched_ext select_cpu, or pick

AffinityShrinkInvalidates:
  represents affinity or cpuset effective mask shrink

CpuHotplugDeactivate:
  represents active CPU removal

NoIntersectionFailClosed:
  represents no CPU remaining in the CapSched envelope
```

## Checked Invariants

```text
NoRunOutsideCurrentPlacement
NoSelectedOutsideFrozenEnvelope
NoQueuedMoveOutsideFrozenEnvelope
NoFallbackExpansionCreatesAuthority
NoRunOnInactiveCpu
NoMigrationPendingRuns
```

## Scope Limit

This is not a full scheduler or cpuset model. It does not model all CPU masks,
real sched domains, load balancing, energy-aware selection, sched_ext BPF
dispatch queues, or detailed hotplug ordering. It is a design filter for the
authority split before any behavior-changing CapSched patch.
