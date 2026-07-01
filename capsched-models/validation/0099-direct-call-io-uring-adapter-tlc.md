# Validation 0099: Direct-Call io_uring Adapter TLC

Status: safe model passed; unsafe models produced expected counterexamples

Date: 2026-07-01

## Inputs

```text
analysis/0085-direct-call-io-uring-adapter-refinement.md
analysis/direct-call-io-uring-adapter-refinement-v1.json
formal/0061-direct-call-io-uring-adapter-refinement-model/
formal/0059-direct-call-async-carrier-api-sketch-model/
implementation/0012-direct-call-async-carrier-api-sketch.md
```

## Run Directory

```text
/media/nia/scsiusb/dev/linux-cap/build/tlc/direct-call-io-uring-adapter-20260701T184003Z
```

## Safe Run

Command shape:

```sh
java -cp /home/nia/tools/tla/tla2tools.jar \
  tlc2.TLC \
  -config DirectCallIoUringAdapterSafe.cfg \
  DirectCallIoUringAdapter.tla
```

Result:

```text
exit_code=0
states_generated=26
distinct_states=24
states_left_on_queue=0
search_depth=15
```

The safe model covers:

```text
allocate request -> consume SQE -> freeze caller tuple ->
bind resource authority -> inline issue or io-wq queue/worker select ->
handle reissue without refresh -> revoke_check -> validate -> side effect ->
post CQE result -> settle -> release -> accept
```

## Expected Unsafe Counterexamples

All unsafe configurations exited with code `12` and violated the intended
invariant:

| Config | Violated invariant |
| --- | --- |
| `DirectCallIoUringAdapterUnsafeAbiApproval` | `NoAbiApproval` |
| `DirectCallIoUringAdapterUnsafeBehaviorChange` | `NoBehaviorChange` |
| `DirectCallIoUringAdapterUnsafeCancelRevokeReceipt` | `NoCancelRevokeReceipt` |
| `DirectCallIoUringAdapterUnsafeCqeSettlementProof` | `NoCqeSettlementProof` |
| `DirectCallIoUringAdapterUnsafeCredTctxAuthority` | `NoLinuxObjectAuthority` |
| `DirectCallIoUringAdapterUnsafeDoubleSettlement` | `SettlementAtMostOnce` |
| `DirectCallIoUringAdapterUnsafeImmutableOverwrite` | `NoImmutableOverwrite` |
| `DirectCallIoUringAdapterUnsafeIoKiocbAuthority` | `NoLinuxObjectAuthority` |
| `DirectCallIoUringAdapterUnsafeIoWqWorkAuthority` | `NoLinuxObjectAuthority` |
| `DirectCallIoUringAdapterUnsafeLinkInheritWithoutCarrier` | `NoImplicitLinkAuthority` |
| `DirectCallIoUringAdapterUnsafeMonitorVerified` | `NoMonitorVerifiedClaim` |
| `DirectCallIoUringAdapterUnsafeProtectionClaim` | `NoProtectionClaim` |
| `DirectCallIoUringAdapterUnsafeReissueRefresh` | `NoReissueRefresh` |
| `DirectCallIoUringAdapterUnsafeReleaseDropsLinuxRefs` | `ReleaseDoesNotDropLinuxRefs` |
| `DirectCallIoUringAdapterUnsafeResourceUpdateMutatesInflight` | `NoResourceUpdateMutatesInflight` |
| `DirectCallIoUringAdapterUnsafeRsrcNodeAuthority` | `NoLinuxObjectAuthority` |
| `DirectCallIoUringAdapterUnsafeSideEffectBeforeValidate` | `NoSideEffectBeforeValidate` |
| `DirectCallIoUringAdapterUnsafeStaleExecuteAfterRevoke` | `NoStaleExecutionAfterRevoke` |
| `DirectCallIoUringAdapterUnsafeUringCmdWithoutEndpoint` | `NoUringCmdWithoutEndpoint` |

Each unsafe run reached:

```text
exit_code=12
states_generated=3
distinct_states=3
states_left_on_queue=1
search_depth=2
```

## Meaning

The model adds an io_uring-specific gate for the N-126 shared async-carrier
direction:

```text
SQE consumption, caller freeze, resource binding, issue, io-wq worker
selection, reissue, cancel, CQE, settlement, release, and free are distinct
semantic states.

io_kiocb, io_wq_work, req->creds, req->tctx, SQPOLL credentials,
io_rsrc_node liveness, REQ_F_REISSUE, CQE, cancel flags, completion, ref drop,
and free are not CapSched authority or monitor proof.

Resource generation snapshots must not be silently mutated by registered
resource updates. Linked requests must not inherit authority without explicit
carrier relationship. uring_cmd must not bypass typed endpoint authority.
```

## Limits

This is a tiny finite model. It does not model real io_uring locking, SQPOLL
interleavings, all request opcodes, all linked-request chains, registered
resource table internals, monitor implementation, runtime coverage, or
production protection.

The next step is to integrate the workqueue and io_uring refinement outputs
into an implementation-facing no-patch adapter precondition gate before any
Linux code proposal.

## Non-Claims

This validation does not approve Linux code, io_uring integration,
direct-call ABI, public tracepoints, runtime coverage, monitor verification,
behavior change, or production protection.
