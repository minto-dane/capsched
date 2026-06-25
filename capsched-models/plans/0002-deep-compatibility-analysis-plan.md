# Plan 0002: Deep Compatibility and Cluster-Capability Analysis

Status: Active

Date: 2026-06-25

Linux base:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
commit: 4edcdefd4083ae04b1a5656f4be6cd83ae919ef4
```

## Purpose

The first source map identified files and functions. This plan raises the bar:
before any Linux source patch, CapSched must understand where upstream Linux is
already strong, where its semantics are incompatible with non-forgeable
capability authority, and where compatibility can be preserved by treating
existing Linux mechanisms as policy inputs rather than replacing them.

This is still an analysis plan. It is not an implementation decision.

## Analysis Goal

Build a map from upstream Linux behavior to CapSched concepts:

```text
Linux task and scheduler state
  -> CapSched DomainTag / RunCap / SchedContext / FrozenRunUse

Linux cgroup, cpuset, affinity, priority, LSM, cred
  -> policy and compatibility inputs

Linux async execution
  -> provenance preservation or explicit service-domain execution

Linux topology and partitioning
  -> local compilation target for cluster-wide resource leases
```

The output must help us avoid two failures:

1. Breaking Linux ABI or scheduler performance by inserting authority checks at
   the wrong layer.
2. Overstating security by confusing Linux policy controls with
   non-forgeable monitor-backed authority.

## Required Notes

The following notes are required before selecting an L0 patch slice:

| Note | Topic | Required question |
| --- | --- | --- |
| 0002 | Scheduler execution spine | Which runnable, pick, switch, and tick paths can invalidate a naive RunCap model? |
| 0003 | Task lifecycle and identity | How do fork, clone, exec, exit, kernel threads, and io workers change authority context? |
| 0004 | Existing controls and compatibility | Which Linux controls must remain ABI-compatible policy inputs? |
| 0005 | Async provenance risk map | Where does caller authority disappear after the syscall returns? |
| 0006 | Cluster-domain mapping | How can one OS substrate span clusters without a monolithic distributed scheduler? |
| 0007 | Capability invariant matrix | Which invariants are covered, unclear, or contradicted by current source evidence? |

## Compatibility Rules

CapSched must initially compose with, not replace:

- `sched_setattr()`, `sched_setscheduler()`, `sched_setaffinity()`
- `nice`, `RLIMIT_NICE`, `RLIMIT_RTPRIO`, `CAP_SYS_NICE`
- cgroup CPU controller, cpuset, uclamp, CFS bandwidth
- RT and deadline admission checks
- core scheduling cookies
- LSM hooks and credential transitions
- namespace and cgroup lifecycle behavior
- `sched_ext` as a policy lab only

The working model is:

```text
effective schedulability =
  Linux ABI policy result
  ∩ cgroup/cpuset/topology constraints
  ∩ CapSched RunCap
  ∩ CapSched SchedContext
  ∩ monitor-issued root lease, once Monitor exists
```

## Evidence Standard

Every compatibility claim must name source files and functions. Line numbers are
recorded against the current upstream commit and may drift after rebases.

When evidence is incomplete, mark it as uncertainty. Do not fill gaps with a
desired design.

## Cluster Direction

The datacenter goal includes a DragonflyBSD-like intuition: one OS substrate
must scale across multiple clusters or nodes. CapSched should not make a single
global Linux runqueue. Instead, cluster-level authority should be represented as
bounded leases that compile into node-local kernel and monitor objects.

Initial rule:

```text
Cluster control plane may issue leases.
Node-local Linux scheduler still performs dispatch.
Node-local HyperTag Monitor enforces non-forgeable roots.
```

This allows a single administrative and capability namespace without pretending
that a global scheduler can safely hold every fast-path lock or make every
per-CPU decision.

## Stop Condition

The plan is complete only when the analysis index points to notes 0002 through
0007 and the state ledger records the deeper analysis pass. Linux source must
remain unmodified.
