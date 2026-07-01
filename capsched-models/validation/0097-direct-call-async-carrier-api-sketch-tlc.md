# Validation 0097: Direct-Call Async Carrier API Sketch TLC

Status: safe model passed; unsafe models produced expected counterexamples

Date: 2026-07-01

## Inputs

```text
formal/0059-direct-call-async-carrier-api-sketch-model/
implementation/0012-direct-call-async-carrier-api-sketch.md
implementation/direct-call-async-carrier-api-sketch-v1.json
validation/0096-direct-call-async-carrier-api-sketch-result.md
```

## Run Directory

```text
/media/nia/scsiusb/dev/linux-cap/build/tlc/direct-call-async-carrier-api-sketch-20260701T061239Z
```

## Safe Run

Command shape:

```sh
java -cp /home/nia/tools/tla/tla2tools.jar \
  tlc2.TLC \
  -config DirectCallAsyncCarrierApiSketchSafe.cfg \
  DirectCallAsyncCarrierApiSketch.tla
```

Result:

```text
exit_code=0
states_generated=25
distinct_states=23
states_left_on_queue=0
search_depth=12
```

The safe model covers both adapter surfaces:

```text
workqueue:
  create -> freeze -> bind -> publish -> coalescing handled ->
  revoke_check -> validate -> side effect -> settle -> release -> accept

io_uring:
  create -> freeze -> bind -> request prepared -> reissue handled ->
  revoke_check -> validate -> side effect -> settle -> release -> accept
```

## Expected Unsafe Counterexamples

All unsafe configurations exited with code `12` and violated the intended
invariant:

| Config | Violated invariant |
| --- | --- |
| `DirectCallAsyncCarrierApiSketchUnsafeAbiApproval` | `NoAbiApproval` |
| `DirectCallAsyncCarrierApiSketchUnsafeAuthorityIntersection` | `EffectiveAuthorityIsIntersection` |
| `DirectCallAsyncCarrierApiSketchUnsafeBehaviorChange` | `NoBehaviorChange` |
| `DirectCallAsyncCarrierApiSketchUnsafeCqeSettlementProof` | `NoCqeSettlementProof` |
| `DirectCallAsyncCarrierApiSketchUnsafeDoubleSettlement` | `SettlementAtMostOnce` |
| `DirectCallAsyncCarrierApiSketchUnsafeImmutableOverwrite` | `NoImmutableOverwrite` |
| `DirectCallAsyncCarrierApiSketchUnsafeLinuxObjectAuthority` | `NoLinuxObjectAuthority` |
| `DirectCallAsyncCarrierApiSketchUnsafeMonitorVerified` | `NoMonitorVerifiedClaim` |
| `DirectCallAsyncCarrierApiSketchUnsafePendingOverwrite` | `NoPendingOverwrite` |
| `DirectCallAsyncCarrierApiSketchUnsafeProtectionClaim` | `NoProtectionClaim` |
| `DirectCallAsyncCarrierApiSketchUnsafeReissueRefresh` | `NoReissueRefresh` |
| `DirectCallAsyncCarrierApiSketchUnsafeReleaseDropsLinuxRefs` | `ReleaseDoesNotDropLinuxRefs` |
| `DirectCallAsyncCarrierApiSketchUnsafeSecondCallerLeak` | `NoSecondCallerLeak` |
| `DirectCallAsyncCarrierApiSketchUnsafeSideEffectBeforeValidate` | `NoSideEffectBeforeValidate` |

Each unsafe run reached:

```text
exit_code=12
states_generated=4
distinct_states=4
states_left_on_queue=2
```

## Meaning

The N-126 model adds a checked transition-ordering gate for the N-125 API
sketch:

```text
side effects require revoke_check and validate
frozen and bound tuples are not overwritten
second-caller pending coalescing cannot leak or overwrite the first carrier
settlement is at most once
release cannot own Linux object cleanup
CQE cannot be settlement proof
REQ_F_REISSUE cannot refresh receipts
effective authority must remain subset of both caller and service/resource
Linux object identity is not carrier authority
ABI, behavior, monitor verification, and protection claims remain false
```

## Limits

This is a tiny finite model. It does not model real io_uring internals, real
workqueue locking, Linux memory ordering, monitor implementation, runtime
coverage, or production protection.

The next refinement should split the broad adapter obligations into more
specific io_uring and workqueue models before any Linux code proposal.

## Non-Claims

This validation does not approve Linux code, workqueue integration, io_uring
integration, direct-call ABI, public tracepoints, runtime coverage, monitor
verification, behavior change, or production protection.
