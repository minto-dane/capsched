# Formal 0002: Runnable Lease Model

Status: Draft

Date: 2026-06-25

Linux base:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
commit: 4edcdefd4083ae04b1a5656f4be6cd83ae919ef4
```

## Purpose

This is the first executable semantic model for CapSched. It models only the
execution-authority core:

```text
Task + TaskGeneration + ProcessGeneration
+ Domain + DomainEpoch
+ RunCap + SchedContext + FrozenRunUse
+ CPU placement constraints
+ runqueue / selected / running states
+ budget consumption and revocation
```

It intentionally does not model CFS, RT, deadline, full cgroup semantics,
io_uring, VFS, BPF verifier behavior, page ownership, or IOMMU enforcement.
Those are separate models.

## Files

```text
RunnableLease.tla
RunnableLease.cfg
notes.md
```

## Core Idea

The model separates:

```text
PolicyAllowsRun:
  BPF/LSM/cgroup-style policy input.

RunCap:
  authority snapshot to attempt runnable submission.

FrozenRunUse:
  enqueue-time lease derived from RunCap and SchedContext.

SchedContext:
  budget and placement resource object.

MonitorAllowed:
  placeholder for monitor-owned CPU/DomainEpoch acceptance.
```

The key rule is that policy approval alone never implies execution authority.
A task may be selected or run only through a valid frozen use whose task
generation, process generation, Domain epoch, SchedContext owner, budget, and
CPU placement constraints still match.

## Linux Compatibility Abstraction

CPU placement is modeled as an intersection:

```text
task affinity
intersect cpuset-effective CPUs
intersect SchedContext.allowed_cpus
intersect Domain.allowed_cpus
intersect MonitorAllowed(domain, epoch, cpu)
```

This encodes the compatibility rule from the topology analysis: CapSched must
refine Linux affinity/cpuset/sched-domain constraints rather than bypass them.

## Modeled States

```text
blocked
waking
remote_wake_pending
runnable_delayed
queued
throttled
migrating
selected
running
exiting
dead_but_referenced
```

These states are intentionally coarser than Linux internals but richer than
"running / not running". The distinction matters for revocation and stale
grant handling.

## Encoded Safety Properties

```text
NoQueuedWithoutFrozenUse
NoSelectedWithoutSchedContext
NoSelectedWithExhaustedBudget
NoSelectedWithMismatchedTaskGeneration
NoSelectedWithMismatchedDomainEpoch
NoRunningWithoutDomainActivation
NoGrantReuseAfterRevocation
NoBudgetUnderflow
NoCpuOutsidePlacement
NoTaskOnTwoCpus
```

The last two are extra compatibility/sanity properties derived from Linux
affinity/topology reading.

## Expected Validation

Run from this directory:

```text
java -cp /home/nia/tools/tla/tla2tools.jar tlc2.TLC RunnableLease.tla
```

or, if available:

```text
tlc RunnableLease.tla
```

The configuration intentionally uses a tiny finite model:

```text
2 domains
2 tasks
2 CPUs
2 sched contexts
epochs: 0..1
generations: 0..1
budgets: 0..2
```

The first objective is counterexample discovery, not realism.

## Design Questions This Model Pressures

1. Revocation cannot be a passive flag flip if queued grants must remain valid.
   Either revocation must dequeue/clear affected runnable state, or the
   invariant must allow stale queued grants and rely on pick-time rejection.
   This model currently chooses the stricter option: revocation clears affected
   runnable state.
2. `exec` cannot silently change Domain. The model preserves `TaskDomain` and
   refreshes the current frozen use's process generation for the running task.
3. Budget exhaustion transitions a running task to `throttled` and clears CPU
   execution. A future Linux plan must decide whether that maps to dequeue,
   throttle, or class-specific delayed runnable state.
4. Policy front-ends do not mint execution. `PolicyAllowsRun` gates RunCap
   issuance only; it is not sufficient for enqueue, pick, or run.
