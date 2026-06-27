# Formal 0016: Task-Local Run State Model

Status: Draft bounded lifecycle model

Date: 2026-06-27

Related analysis:

```text
capsched/capsched-models/analysis/0033-task-local-resumable-run-lifecycle.md
```

## Purpose

This model checks the local lifecycle requirements for ordinary task-local
resumable-run state:

```text
dup_task_struct raw copy
child CapSched reset
SpawnCap-derived preparation
initial wake_up_new_task activation
ordinary block and wake
revocation
exit and final authority clearing
```

It does not model full Linux scheduling policy, class-specific enqueue
behavior, PI/RT priority donation, futex endpoint authority, workqueue
provenance, or monitor-backed MemoryView activation.

## Checked Invariants

```text
NoForkGrantInheritance:
  child-prepared, queued, waking, enqueued, or running states cannot carry a
  copied parent frozen authority

NoInitialRunWithoutPreparedState:
  initial child queue/run cannot occur without SpawnCap-derived preparation

NoTaskWakingWithoutFrozenUse:
  ordinary blocked wake cannot reach TASK_WAKING without prepared frozen use

NoFrozenUseAfterRevoke:
  revoked authority cannot remain frozen, selected, or running

NoDeadTaskAuthority:
  dead task state cannot retain CapSched authority or owned references

NoOwnedRefsBeforeReset:
  child-owned CapSched references are impossible before post-dup reset and
  preparation

NoRunWithoutSelectedUse:
  running execution must come from a selected, frozen, non-revoked use
```

## TLC Configurations

```text
TaskLocalRunStateSafe.cfg
TaskLocalRunStateUnsafeForkCopy.cfg
TaskLocalRunStateUnsafeWakeNew.cfg
TaskLocalRunStateUnsafeRevoke.cfg
TaskLocalRunStateUnsafeExit.cfg
```

The safe configuration must pass. Unsafe configurations intentionally include
one bad transition each and should fail the named target invariant.
