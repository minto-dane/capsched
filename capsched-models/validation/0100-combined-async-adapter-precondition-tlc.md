# Validation 0100: Combined Async Adapter Precondition TLC

Status: safe model passed; unsafe models produced expected counterexamples;
gate JSON checked

Date: 2026-07-01

## Inputs

```text
implementation/0013-combined-async-adapter-precondition-gate.md
implementation/combined-async-adapter-precondition-gate-v1.json
formal/0062-combined-async-adapter-precondition-model/
validation/0097-direct-call-async-carrier-api-sketch-tlc.md
validation/0098-direct-call-workqueue-adapter-tlc.md
validation/0099-direct-call-io-uring-adapter-tlc.md
```

## Run Directory

```text
/media/nia/scsiusb/dev/linux-cap/build/tlc/combined-async-adapter-precondition-20260701T184839Z
```

## Safe Run

Command shape:

```sh
java -cp /home/nia/tools/tla/tla2tools.jar \
  tlc2.TLC \
  -config CombinedAsyncAdapterPreconditionSafe.cfg \
  CombinedAsyncAdapterPrecondition.tla
```

Result:

```text
exit_code=0
states_generated=10
distinct_states=9
states_left_on_queue=0
search_depth=9
```

The safe model covers:

```text
shared core checked -> workqueue refinement checked ->
io_uring refinement checked -> adapter mechanics separated ->
authority and budget checked -> revoke/source/evidence checked ->
candidate patch proposal allowed -> accept
```

## Expected Unsafe Counterexamples

All unsafe configurations exited with code `12` and violated the intended
invariant:

| Config | Violated invariant |
| --- | --- |
| `CombinedAsyncAdapterPreconditionUnsafeAbiApproval` | `NoAbiApproval` |
| `CombinedAsyncAdapterPreconditionUnsafeBehaviorChange` | `NoBehaviorChange` |
| `CombinedAsyncAdapterPreconditionUnsafeBroadModelOnly` | `NoBroadModelOnlyGate` |
| `CombinedAsyncAdapterPreconditionUnsafeCrossAdapterCollapse` | `NoCrossAdapterCollapse` |
| `CombinedAsyncAdapterPreconditionUnsafeLinuxObjectAuthority` | `NoLinuxObjectAuthority` |
| `CombinedAsyncAdapterPreconditionUnsafeMissingEvidenceSplit` | `EvidenceSplitRequired` |
| `CombinedAsyncAdapterPreconditionUnsafeMonitorVerified` | `NoMonitorVerifiedClaim` |
| `CombinedAsyncAdapterPreconditionUnsafePatchBeforeIoUring` | `CandidatePatchRequiresBothAdapters` |
| `CombinedAsyncAdapterPreconditionUnsafePatchBeforeWorkqueue` | `CandidatePatchRequiresBothAdapters` |
| `CombinedAsyncAdapterPreconditionUnsafeProtectionClaim` | `NoProtectionClaim` |
| `CombinedAsyncAdapterPreconditionUnsafeSharedCoreGenericAsync` | `NoSharedCoreGenericAsync` |

Each unsafe run reached:

```text
exit_code=12
states_generated=3
distinct_states=3
states_left_on_queue=1
search_depth=2
```

## JSON Gate Check

Command shape:

```sh
jq empty \
  capsched/capsched-models/implementation/combined-async-adapter-precondition-gate-v1.json

jq -r '[ ... ] | @tsv' \
  capsched/capsched-models/implementation/combined-async-adapter-precondition-gate-v1.json
```

Result:

```text
gate_rows=10
gate_rows_with_required_preconditions_forbidden_fallbacks_required_evidence_and_patch_precondition=10
unique_gate_ids=10
global_non_claims=9
safety_flags_false=10
safety_flags_total=10
rows_referencing_validation_0098=3
rows_referencing_validation_0099=3
```

## Meaning

This gate reconciles N-126, N-127, and N-128:

```text
The broad async-carrier API sketch alone is not enough to draft a Linux
candidate patch.

The workqueue and io_uring adapter refinements must both be complete before a
combined async-carrier patch proposal can be drafted.

One adapter's lifecycle cannot prove the other adapter.

Linux object identity, evidence-class collapse, ABI approval, behavior change,
monitor verification, and protection claims remain rejected.
```

## Limits

This is still not Linux implementation, workqueue integration, io_uring
integration, direct-call ABI, public tracepoint ABI, runtime coverage, monitor
verification, behavior change, or production protection.

It only allows a future candidate patch proposal to be drafted against explicit
preconditions.

## Non-Claims

This validation does not approve Linux code, direct-call ABI, public
tracepoints, runtime coverage, monitor verification, behavior change, or
production protection.
