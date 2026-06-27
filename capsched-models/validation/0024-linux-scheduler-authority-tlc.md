# Validation 0024: Linux Scheduler Authority TLC Check

Status: Passed for tiny finite model

Date: 2026-06-27

## Target

```text
formal/0012-linux-scheduler-authority-model/LinuxSchedulerAuthority.tla
formal/0012-linux-scheduler-authority-model/LinuxSchedulerAuthority.cfg
```

## Purpose

Check the first LinuxSchedulerAuthority model before using it as a semantic
base for runnable authority hook selection.

The model covers:

```text
RemotePendingWake
SelectedUse
CurrentContinuation
QueuedMigration
SpawnedInitialUse
budget exhaustion
domain epoch revoke over queued, selected, running, and pending states
exit invalidation
```

## Command

Run from:

```text
/media/nia/scsiusb/dev/linux-cap/capsched/capsched-models/formal/0012-linux-scheduler-authority-model
```

Command:

```sh
timeout 120 java -cp /home/nia/tools/tla/tla2tools.jar tlc2.TLC LinuxSchedulerAuthority.tla
```

## Result

TLC completed with no invariant errors.

Summary:

```text
126113 states generated
17344 distinct states found
0 states left on queue
complete state graph depth: 21
runtime: 2 seconds
```

Checked invariants:

```text
TypeOK
NoCustodyWithoutValidGrant
NoRemotePendingRuns
NoRunningWithoutToken
NoRunningWithoutBudget
NoStaleActiveEpoch
NoDeadAuthority
NoTaskSelectedTwice
NoTaskRunsTwice
NoSelectedAndRunningSameTask
NoSelectedOnBusyCpu
CpuIdleShape
```

## Claim Boundary

This is finite semantic evidence, not implementation proof and not production
security evidence.

Allowed claim:

```text
The draft model has no finite counterexample for the listed safety invariants
under the tiny bounded configuration.
```

Forbidden claim:

```text
Linux L0 now enforces runnable authority.
CapSched-H has a proven scheduler boundary.
Existing Linux runtime accounting is a hard security budget root.
```

## Follow-Up

Before any behavior-changing patch, refine or decompose:

```text
failure after TASK_WAKING
same-Domain monitor fast-path freshness
root Domain budget versus SchedContext budget
NO_HZ/hrtick overrun bounds
CFS/RT/deadline/sched_ext/core/proxy selected-state behavior
exec process-generation semantics
```
