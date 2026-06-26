# Formal 0001: Model Selection

Status: Draft

Date: 2026-06-25

## Decision

The first formal model should be:

```text
Runnable Lease Model
```

It should cover:

```text
Task
TaskGeneration
ProcessGeneration
Domain
DomainEpoch
RunCap
SchedContext
FrozenRunUse
RunqueueState
CPU
Budget
```

This model should be written before any Linux prototype patch.

## Why This Model First

It is the smallest model that directly tests the scheduler capability core:

```text
EXEC-001: No RunCap, no enqueue.
EXEC-002: No SchedContext, no execution.
EXEC-003: No budget, no execution.
EXEC-004: No FrozenRunUse, no runqueue entry.
EXEC-005: No valid epoch and generation, no execution.
```

It also blocks a common design mistake: adding a `capsched_domain *` to
`task_struct` and assuming that task labeling equals execution authority.

## Minimum States

The model should not use only "running" and "not running". Source analysis found
more states that matter:

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

The model can abstract Linux details, but it must preserve the distinction
between:

```text
task has a safe pointer lifetime
task has valid execution authority
task is visible to scheduler
task may actually run
```

## Core Safety Properties

The initial TLA+ or equivalent model should assert:

```text
NoQueuedWithoutFrozenUse
NoSelectedWithoutSchedContext
NoSelectedWithExhaustedBudget
NoSelectedWithMismatchedTaskGeneration
NoSelectedWithMismatchedDomainEpoch
NoRunningWithoutDomainActivation
NoGrantReuseAfterRevocation
NoBudgetUnderflow
```

## Liveness Properties

The first model may include bounded liveness, but safety matters first.

Candidate liveness:

```text
If a task has valid RunCap, SchedContext, budget, and allowed CPU, then it can
eventually become selected unless blocked by modeled scheduler policy.
```

This must be weak enough not to contradict core scheduling, throttling,
priority, and cpuset behavior.

## Explicit Out of Scope

The first model should not try to model:

- VFS or file operation semantics
- BPF verifier behavior
- io_uring resource registration
- page cache coherency
- IOMMU page tables
- real Linux runqueue algorithms
- full CFS/RT/deadline fairness
- global cluster scheduling

These are not ignored. They are separate models.

## Required Placeholders

Even though async and monitor behavior are out of scope, the model should keep
explicit uninterpreted hooks:

```text
AsyncWorkCreated(task, frozen_authority)
AsyncWorkInvalidated(domain_epoch)
MonitorAllowsRun(domain, epoch, cpu, budget)
EndpointUseRequires(domain, endpoint, op)
```

This prevents the model from accidentally implying that all execution and
authority flows through direct task enqueue.

## Follow-On Models

Model 2:

```text
Async Provenance Model
CallerTask + ServiceWorker + WorkItem + FrozenAuthority + BudgetTicket
```

Model 3:

```text
Domain Switch and Monitor Token Model
CPU + CurrentDomainTag + MemoryView + RunToken + MonitorState
```

Model 4:

```text
Endpoint Capability Model
fd/file/socket/resource endpoint + operation + frozen use + revocation
```

Model 5:

```text
Cluster Lease Compilation Model
ClusterLease -> local DomainEpoch + SchedContext + EndpointCaps
```

## Acceptance Gate Before Prototype

Do not start L0 patches until:

1. Runnable Lease Model exists.
2. It has at least the core safety properties above.
3. There is a written list of assumptions that Linux L0 will not enforce.
4. The model explicitly marks Linux-only security claims as limited.
5. The user accepts the first L0 slice.

## Current Recommendation

Build the Runnable Lease Model with a small state machine first. Then use its
counterexamples to refine the L0 implementation plan. The goal is not to prove
Linux correct. The goal is to prevent CapSched from encoding a false authority
story before the first patch.
