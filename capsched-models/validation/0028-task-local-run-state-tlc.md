# Validation 0028: Task-Local Run State TLC

Status: Completed bounded model check

Date: 2026-06-27

Model:

```text
capsched/capsched-models/formal/0016-task-local-run-state-model/TaskLocalRunState.tla
```

Related analysis:

```text
capsched/capsched-models/analysis/0033-task-local-resumable-run-lifecycle.md
```

TLC logs:

```text
/media/nia/scsiusb/dev/linux-cap/build/tlc/task-local-run-state-20260627T080220Z/TaskLocalRunStateSafe.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/task-local-run-state-20260627T080220Z/TaskLocalRunStateUnsafeForkCopy.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/task-local-run-state-20260627T080233Z/TaskLocalRunStateUnsafeWakeNew.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/task-local-run-state-20260627T080233Z/TaskLocalRunStateUnsafeRevoke.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/task-local-run-state-20260627T080233Z/TaskLocalRunStateUnsafeExit.log
```

## Result Summary

Safe configuration:

```text
config: TaskLocalRunStateSafe.cfg
result: PASS
generated states: 41
distinct states: 22
search depth: 13
```

Unsafe configurations produced expected counterexamples:

```text
config: TaskLocalRunStateUnsafeForkCopy.cfg
target invariant: NoForkGrantInheritance
result: expected FAIL
generated states before violation: 5
distinct states before violation: 5
depth: 3

config: TaskLocalRunStateUnsafeWakeNew.cfg
target invariant: NoInitialRunWithoutPreparedState
result: expected FAIL
generated states before violation: 7
distinct states before violation: 7
depth: 4

config: TaskLocalRunStateUnsafeRevoke.cfg
target invariant: NoFrozenUseAfterRevoke
result: expected FAIL
generated states before violation: 29
distinct states before violation: 20
depth: 10

config: TaskLocalRunStateUnsafeExit.cfg
target invariant: NoDeadTaskAuthority
result: expected FAIL
generated states before violation: 19
distinct states before violation: 14
depth: 8
```

## Validated Claims

This validation supports the following local design constraints:

```text
1. A child may transiently contain raw-copied parent CapSched bits after task
   duplication, but it must not become prepared, queued, waking, enqueued, or
   running until those bits are reset.

2. wake_up_new_task() must not activate a child unless SpawnCap-derived task
   run state has already been prepared.

3. Ordinary TASK_WAKING must be reachable only after a prepared continuation is
   frozen into a valid use.

4. Revocation must clear or invalidate frozen, selected, and running uses before
   they can authorize execution.

5. Dead task state must not retain authority-bearing CapSched references.
```

## Unsafe Counterexample Meaning

`TaskLocalRunStateUnsafeForkCopy.cfg` demonstrates the raw-copy hazard:

```text
Start -> ForkCopied -> BadForkGrantInheritance
```

The child is prepared while still carrying copied parent frozen authority. This
is exactly the failure mode created by treating `dup_task_struct()` as harmless
for task-local capability state.

`TaskLocalRunStateUnsafeWakeNew.cfg` demonstrates initial activation without
prepared state:

```text
Start -> ForkCopied -> ForkReset -> BadWakeNewNoPrep
```

This is the failure mode where `wake_up_new_task()` or equivalent initial
activation runs before SpawnCap-derived state exists.

`TaskLocalRunStateUnsafeRevoke.cfg` demonstrates revoked execution:

```text
... -> TaskBlocked -> RevokedBlocked -> BadFrozenAfterRevoke
```

This is the failure mode where a blocked task's stale continuation is still
frozen and executed after revocation.

`TaskLocalRunStateUnsafeExit.cfg` demonstrates authority surviving death:

```text
... -> Running -> BadDeadAuthority
```

This is the failure mode where a dead task still owns prepared, frozen,
selected, or running state.

## Evidence Limits

This validation does not prove:

```text
PI/RT/ww_mutex priority donation authority
futex cross-Domain endpoint authority
workqueue or kthread_work BudgetTicket carriers
class-specific stale queued task behavior
same-Domain monitor fast path correctness
NO_HZ/hrtick budget overrun bounds
exec process_generation semantics
Linux memory safety or monitor-backed physical isolation
```

Those remain separate proof obligations.

## Design Consequence

The next behavior-changing Linux patch should not begin by adding generic
capability lookup to `try_to_wake_up()`.

The safer order is:

```text
1. Define task-local CapSched lifecycle state.
2. Ensure post-dup reset before child CapSched ownership exists.
3. Prepare SpawnCap-derived initial run state before wake_up_new_task().
4. Allow F1 to freeze only from prepared local state.
5. Clear derived uses on block, revoke, exit, and free paths.
```

Storage layout remains undecided:

```text
embedded hot state
pointer to preallocated task state
hybrid hot/cold split
```

The model only fixes lifecycle semantics.
