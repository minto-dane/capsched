# Validation 0030: Shared Futex Endpoint TLC

Status: Completed bounded model check

Date: 2026-06-27

Model:

```text
capsched/capsched-models/formal/0018-shared-futex-endpoint-model/SharedFutexEndpoint.tla
```

Related analysis:

```text
capsched/capsched-models/analysis/0035-shared-futex-endpoint-authority.md
```

TLC logs:

```text
/media/nia/scsiusb/dev/linux-cap/build/tlc/shared-futex-endpoint-20260627T081848Z/SharedFutexEndpointSafe.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/shared-futex-endpoint-20260627T081848Z/SharedFutexEndpointUnsafeWait.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/shared-futex-endpoint-20260627T081848Z/SharedFutexEndpointUnsafeWake.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/shared-futex-endpoint-20260627T081848Z/SharedFutexEndpointUnsafeWakeRuns.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/shared-futex-endpoint-20260627T081848Z/SharedFutexEndpointUnsafeRequeue.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/shared-futex-endpoint-20260627T081848Z/SharedFutexEndpointUnsafeRevoke.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/shared-futex-endpoint-20260627T081848Z/SharedFutexEndpointUnsafeLateFail.log
```

## Result Summary

Safe configuration:

```text
config: SharedFutexEndpointSafe.cfg
result: PASS
generated states: 16
distinct states: 10
search depth: 7
```

Unsafe configurations produced expected counterexamples:

```text
config: SharedFutexEndpointUnsafeWait.cfg
target invariant: NoSharedFutexWaitWithoutWaitCap
result: expected FAIL
generated states before violation: 3
distinct states before violation: 3
depth: 2

config: SharedFutexEndpointUnsafeWake.cfg
target invariant: NoSharedFutexWakeWithoutWakeCap
result: expected FAIL
generated states before violation: 8
distinct states before violation: 7
depth: 4

config: SharedFutexEndpointUnsafeWakeRuns.cfg
target invariant: NoWakeImpliesRun
result: expected FAIL
generated states before violation: 10
distinct states before violation: 8
depth: 5

config: SharedFutexEndpointUnsafeRequeue.cfg
target invariant: NoRequeueWithoutBothEndpointRights
result: expected FAIL
generated states before violation: 8
distinct states before violation: 7
depth: 4

config: SharedFutexEndpointUnsafeRevoke.cfg
target invariant: NoEndpointUseAfterRevoke
result: expected FAIL
generated states before violation: 8
distinct states before violation: 7
depth: 4

config: SharedFutexEndpointUnsafeLateFail.cfg
target invariant: NoLostWakeFromCapFailure
result: expected FAIL
generated states before violation: 8
distinct states before violation: 7
depth: 4
```

## Validated Claims

This validation supports the following local design constraints:

```text
1. Cross-Domain/shared futex wait cannot enqueue without FutexWaitCap.

2. Cross-Domain/shared futex wake cannot mark waiters without FutexWakeCap.

3. FutexWakeCap authorizes endpoint signaling only; target execution still
   requires task-local resumable-run freeze.

4. Requeue requires source and target endpoint authority.

5. Endpoint revocation invalidates queued/wake/requeue/run use.

6. Capability failure after queueing is unsafe without a separately proven
   rollback that preserves futex no-lost-wake ordering.
```

## Unsafe Counterexample Meaning

`SharedFutexEndpointUnsafeWait.cfg` demonstrates wait registration without
endpoint wait authority:

```text
Start -> BadWaitNoCap
```

`SharedFutexEndpointUnsafeWake.cfg` demonstrates endpoint signaling without
wake authority:

```text
Start -> WaitPrepared -> Queued -> BadWakeNoCap
```

`SharedFutexEndpointUnsafeWakeRuns.cfg` demonstrates the key responsibility
confusion:

```text
Start -> WaitPrepared -> Queued -> WakeAuthorized -> BadWakeRunsTask
```

The wake cap marks the endpoint event but incorrectly runs the task without a
target task-local frozen run use.

`SharedFutexEndpointUnsafeRequeue.cfg` demonstrates source-only requeue:

```text
Start -> WaitPrepared -> Queued -> BadRequeueNoBothCaps
```

`SharedFutexEndpointUnsafeRevoke.cfg` demonstrates wake/run after endpoint
revocation:

```text
Start -> WaitPrepared -> Queued -> BadUseAfterRevoke
```

`SharedFutexEndpointUnsafeLateFail.cfg` demonstrates cap failure after the
waiter is already queued:

```text
Start -> WaitPrepared -> Queued -> BadLateCapFailure
```

This violates the futex no-lost-wake discipline unless a separate rollback is
proved.

## Evidence Limits

This validation does not prove:

```text
full futex hash-bucket concurrency
all bitset semantics
FUTEX_WAKE_OP second-key write authority
PI futex rt_mutex ownership and donation semantics
robust futex list behavior
exact Linux errno policy for denied endpoint operations
monitor-backed endpoint identity
```

Those remain separate proof obligations.

## Design Consequence

The next behavior-changing Linux patch should not treat shared futex wake as
ordinary task-local resume.

The safer order is:

```text
1. Model/define FutexEndpoint identity and epoch.
2. Attach waiter-side endpoint context before futex_queue().
3. Validate FutexWakeCap before q->wake() / wake_q_add_safe().
4. Preserve task-local F1 freeze before TASK_WAKING.
5. Model PI futex and priority donation separately before enabling PI paths.
```
