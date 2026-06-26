# Plan 0004: Runnable Lease Model Execution Plan

Status: Draft

Date: 2026-06-25

## Purpose

This plan turns `formal/0001-model-selection.md` into the next concrete work
item. It defines the minimum model, expected files, validation command, and
acceptance gate before any Linux L0 patch slice is chosen.

## Model Directory

Create:

```text
capsched-models/formal/0002-runnable-lease-model/
```

Expected files:

```text
README.md
RunnableLease.tla
RunnableLease.cfg
notes.md
```

If TLA+ tooling is missing, record that in `notes.md` and still write the spec
so it can be checked later.

## Scope

Model only execution authority, not every Linux scheduler detail.

Objects:

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

Abstract states:

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

## Required Transitions

Minimum transitions:

```text
IssueRunCap
FreezeRunUse
WakeTask
RemoteWakeTask
DelayRunnable
EnqueueTask
PickTask
ActivateDomain
RunTick
BudgetExhaust
DequeueTask
MigrateTask
ExecTask
ExitTask
RevokeDomainEpoch
RevokeTaskGeneration
```

`ExecTask` must not mint a new Domain. It may bump process generation or
invalidate endpoint-related placeholders.

`ExitTask` must invalidate execution grants while allowing the task object to
remain referenced.

## Required Safety Properties

The first model must express:

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

## Required Placeholders

Keep these as uninterpreted or lightly modeled relations:

```text
AsyncWorkCreated(task, frozen_authority)
AsyncWorkInvalidated(domain_epoch)
EndpointUseRequires(domain, endpoint, op)
MonitorAllowsRun(domain, epoch, cpu, budget)
```

This prevents a false model where all authority flows only through direct
enqueue.

## Tiny Initial State

Start with a deliberately small finite model:

```text
2 domains
2 tasks
1 or 2 CPUs
2 sched contexts
bounded budget values: 0, 1, 2
bounded epochs: 0, 1
bounded generations: 0, 1
```

The first objective is counterexample discovery, not realism.

## Validation Command

Try these in order:

```text
tlc RunnableLease.tla
java -cp /path/to/tla2tools.jar tlc2.TLC RunnableLease.tla
```

If neither exists, record:

```text
tooling unavailable on this machine at validation time
```

and keep the spec syntactically reviewed.

## Acceptance Gate

Before Linux L0 patch planning:

1. The model exists.
2. All required safety properties are encoded.
3. The checker has been run, or missing tooling is documented.
4. Counterexamples, if any, are summarized.
5. Linux-only claim boundary is restated.
6. The user accepts the L0 slice derived from the model.

## Design Pressure for L0

The model should answer these before patching:

```text
Does FrozenRunUse attach to task, runqueue entry, or class entity?
Does budget exhaustion dequeue, throttle, or fail pick?
Can delayed runnable state hold a FrozenRunUse?
How does remote wake preserve generation/epoch validity?
How is Domain activation represented if Monitor is absent in L0?
```

## Current Recommendation

Write the model next, then derive the L0 implementation plan from the model's
state machine rather than from intuition about a single Linux hook.
