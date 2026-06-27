# Formal 0013: Scheduler Admission Failure Model

Status: Checked with safe pass and expected unsafe counterexamples

Date: 2026-06-27

## Purpose

This model captures the failability boundary around Linux wake admission:

```text
safe:
  reject before TASK_WAKING

unsafe:
  defer authority freeze until after TASK_WAKING, then reject or rollback
```

It supports `analysis/0030-task-waking-failability-boundary-map.md`.

## Modeled States

The model abstracts a single wake attempt:

```text
Idle
PreRejected
Frozen
TaskWakingSet
RemotePending
Queued
Running
LostWake
```

Linux task state is abstracted as:

```text
Blocked
TaskWaking
Runnable
```

`frozen` stands for a valid CapSched `FrozenRunUse`.

## Configurations

Safe configuration:

```text
SchedulerAdmissionFailureSafe.cfg
```

Expected result:

```text
TLC completes with no invariant errors.
```

Unsafe delayed-freeze configuration:

```text
SchedulerAdmissionFailureUnsafeWaking.cfg
```

Expected result:

```text
TLC finds a counterexample to NoTaskWakingWithoutFrozenUse.
```

Unsafe rollback configuration:

```text
SchedulerAdmissionFailureUnsafeRollback.cfg
```

Expected result:

```text
TLC finds a counterexample to NoLostWakeAfterCondition.
```

## Interpretation

The model intentionally rejects the tempting design:

```text
set TASK_WAKING first
then check RunCap/SchedContext
if denied, put the task back
```

Without a much richer rollback protocol, that design can leave Linux in a
state where a wake condition has been delivered but the task has neither a
queued/running path nor an explicit pre-WAKING rejection.

## Claim Boundary

Allowed claim:

```text
The tiny model supports the design rule that fail-capable admission freeze
must happen before TASK_WAKING, while post-TASK_WAKING rejection needs a
separate rollback/quarantine proof.
```

Forbidden claim:

```text
The real Linux wakeup implementation has been proven.
Any particular hook location is approved.
CapSched enforcement can now be implemented safely.
```
