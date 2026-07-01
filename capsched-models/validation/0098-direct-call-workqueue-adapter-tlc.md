# Validation 0098: Direct-Call Workqueue Adapter TLC

Status: safe model passed; unsafe models produced expected counterexamples

Date: 2026-07-01

## Inputs

```text
analysis/0084-direct-call-workqueue-adapter-refinement.md
analysis/direct-call-workqueue-adapter-refinement-v1.json
formal/0060-direct-call-workqueue-adapter-refinement-model/
formal/0059-direct-call-async-carrier-api-sketch-model/
implementation/0012-direct-call-async-carrier-api-sketch.md
```

## Run Directory

```text
/media/nia/scsiusb/dev/linux-cap/build/tlc/direct-call-workqueue-adapter-20260701T183316Z
```

## Safe Run

Command shape:

```sh
java -cp /home/nia/tools/tla/tla2tools.jar \
  tlc2.TLC \
  -config DirectCallWorkqueueAdapterSafe.cfg \
  DirectCallWorkqueueAdapter.tla
```

Result:

```text
exit_code=0
states_generated=16
distinct_states=15
states_left_on_queue=0
search_depth=15
```

The safe model covers:

```text
create -> freeze -> bind -> publish typed work ->
queue_work false handled -> delayed retime handled ->
dispatch callback -> revoke_check -> validate -> side effect ->
self-requeue handled -> caller-budget settlement -> release -> accept
```

## Expected Unsafe Counterexamples

All unsafe configurations exited with code `12` and violated the intended
invariant:

| Config | Violated invariant |
| --- | --- |
| `DirectCallWorkqueueAdapterUnsafeAbiApproval` | `NoAbiApproval` |
| `DirectCallWorkqueueAdapterUnsafeBehaviorChange` | `NoBehaviorChange` |
| `DirectCallWorkqueueAdapterUnsafeCancelFlushRevokeReceipt` | `NoCancelFlushRevokeReceipt` |
| `DirectCallWorkqueueAdapterUnsafeDelayedRetimeRefresh` | `NoReceiptRefreshFromRetimeOrRequeue` |
| `DirectCallWorkqueueAdapterUnsafeDoubleSettlement` | `SettlementAtMostOnce` |
| `DirectCallWorkqueueAdapterUnsafeFreezeAfterPublication` | `PublicationRequiresFrozenAndBound` |
| `DirectCallWorkqueueAdapterUnsafeMonitorVerified` | `NoMonitorVerifiedClaim` |
| `DirectCallWorkqueueAdapterUnsafePendingClearRevokeReceipt` | `NoPendingClearRevokeReceipt` |
| `DirectCallWorkqueueAdapterUnsafePendingOverwrite` | `NoPendingOverwrite` |
| `DirectCallWorkqueueAdapterUnsafeProtectionClaim` | `NoProtectionClaim` |
| `DirectCallWorkqueueAdapterUnsafeReleaseFreesLinuxWork` | `ReleaseDoesNotFreeLinuxWork` |
| `DirectCallWorkqueueAdapterUnsafeRescuerBypass` | `NoRescuerBypass` |
| `DirectCallWorkqueueAdapterUnsafeSecondCallerLeak` | `NoSecondCallerLeak` |
| `DirectCallWorkqueueAdapterUnsafeSelfRequeueRefresh` | `NoReceiptRefreshFromRetimeOrRequeue` |
| `DirectCallWorkqueueAdapterUnsafeServiceOnlyBudget` | `NoServiceOnlyBudget` |
| `DirectCallWorkqueueAdapterUnsafeSideEffectBeforeValidate` | `NoSideEffectBeforeValidate` |
| `DirectCallWorkqueueAdapterUnsafeWorkerIdentityAuthority` | `NoWorkerIdentityAuthority` |

Each unsafe run reached:

```text
exit_code=12
states_generated=3
distinct_states=3
states_left_on_queue=1
search_depth=2
```

## Meaning

The model adds a workqueue-specific gate for the N-126 shared async-carrier
direction:

```text
queue_work false must preserve the first carrier
publication requires prior freeze and bind
second caller candidates must not overwrite or leak
delayed-work retime must not refresh monitor receipts
self-requeue must not refresh monitor receipts
worker identity must not become authority
cancel/flush must not become monitor revoke receipts
pending clear must not become monitor revoke receipt
rescuer execution must not bypass carrier validation
budget must charge/refund the caller ticket or modeled child ticket, not service-only ambient budget
side effects require revoke_check and validate
settlement remains at most once
release drops only CapSched refs, not Linux work ownership
ABI, behavior, monitor verification, and protection claims remain false
```

## Limits

This is a tiny finite model. It does not model real workqueue locking, real
memory ordering, delayed-work timer internals, full cancel/flush interleavings,
monitor implementation, runtime coverage, or production protection.

The io_uring adapter still needs a separate refinement model. The broad
N-126 model is not enough to approve Linux code.

## Non-Claims

This validation does not approve Linux code, workqueue integration,
direct-call ABI, public tracepoints, runtime coverage, monitor verification,
behavior change, or production protection.
