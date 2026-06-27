# Formal 0018: Shared Futex Endpoint Model

Status: Draft bounded endpoint authority model

Date: 2026-06-27

Related analysis:

```text
capsched/capsched-models/analysis/0035-shared-futex-endpoint-authority.md
```

## Purpose

This model checks the local authority separation for cross-Domain/shared futex
operations:

```text
FutexWaitCap gates enqueueing a waiter
FutexWakeCap gates marking a waiter for wake
FutexRequeueCap gates moving waiters between endpoints
FutexWakeCap does not grant target CPU execution
target task execution still requires task-local resumable-run freeze
endpoint revocation invalidates queued/wake/requeue uses
capability failure must not be delayed until after queueing without proven
rollback
```

It does not model full futex hashing, all wake bitset rules, actual user memory
loads/stores, PI rt_mutex ownership, robust futex lists, or all requeue races.

## Checked Invariants

```text
NoSharedFutexWaitWithoutWaitCap
NoSharedFutexWakeWithoutWakeCap
NoWakeImpliesRun
NoRequeueWithoutBothEndpointRights
NoEndpointUseAfterRevoke
NoLostWakeFromCapFailure
```

## TLC Configurations

```text
SharedFutexEndpointSafe.cfg
SharedFutexEndpointUnsafeWait.cfg
SharedFutexEndpointUnsafeWake.cfg
SharedFutexEndpointUnsafeWakeRuns.cfg
SharedFutexEndpointUnsafeRequeue.cfg
SharedFutexEndpointUnsafeRevoke.cfg
SharedFutexEndpointUnsafeLateFail.cfg
```

The safe configuration must pass. Unsafe configurations intentionally include
one bad transition each and should fail the named target invariant.
