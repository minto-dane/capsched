# Validation 0070: Direct Call Reference ABI TLC

Status: Safe model passed; unsafe models produced expected counterexamples

Date: 2026-06-30

Related artifacts:

```text
analysis/0071-direct-call-reference-abi-sketch.md
analysis/direct-call-reference-abi-sketch-v1.json
formal/0048-direct-call-reference-abi-model/
```

Run directory:

```text
/media/nia/scsiusb/dev/linux-cap/build/tlc/direct-call-reference-abi-20260630T064515Z
```

## Purpose

This validation checks the N-098 direct-call reference ABI sketch for
`LocalMonitorAdmissionABI-v0`.

The model separates:

```text
Linux-visible request carrier
monitor entry
monitor-owned request copy/freeze
copied-request validation
replay-window consume before success ledger write
monitor-owned ledger write
sealed response handle
Linux shadow refresh from handle/ledger only
failure terminality
revoke slow path with in-flight direct-call drain
```

## Safe Result

```text
DirectCallReferenceABISafe:
  Model checking completed. No error has been found.
  23 states generated
  21 distinct states found
  depth 20
```

## Expected Unsafe Counterexamples

```text
DirectCallReferenceABIUnsafeValidateLinuxMutable:
  Error: Invariant NoValidationFromLinuxMutableRequest is violated.

DirectCallReferenceABIUnsafeSuccessWithoutEntry:
  Error: Invariant SuccessRequiresMonitorEntry is violated.

DirectCallReferenceABIUnsafeLedgerWithoutCopyValidation:
  Error: Invariant SuccessLedgerRequiresCopiedValidation is violated.

DirectCallReferenceABIUnsafeLedgerBeforeReplay:
  Error: Invariant SuccessLedgerRequiresReplayConsume is violated.

DirectCallReferenceABIUnsafeLinuxLedgerWrite:
  Error: Invariant NoLinuxLedgerWrite is violated.

DirectCallReferenceABIUnsafeResponseWithoutLedger:
  Error: Invariant ResponseHandleRequiresLedger is violated.

DirectCallReferenceABIUnsafeShadowFromRequest:
  Error: Invariant NoShadowFromRequest is violated.

DirectCallReferenceABIUnsafeShadowAuthority:
  Error: Invariant LinuxShadowIsNotAuthority is violated.

DirectCallReferenceABIUnsafeFailureThenReceipt:
  Error: Invariant NoReceiptAfterFailure is violated.

DirectCallReferenceABIUnsafeRevokeWithoutEmbargo:
  Error: Invariant RevokeCompleteRequiresEmbargo is violated.

DirectCallReferenceABIUnsafeRevokeWithInFlight:
  Error: Invariant RevokeCompleteRequiresInFlightDrain is violated.

DirectCallReferenceABIUnsafeRevokeBeforeDerivedShadow:
  Error: Invariant RevokeCompleteRequiresDerivedAndShadow is violated.
```

## Interpretation

This supports the N-098 direct-call reference ABI gate:

```text
monitor validates copied request images, not Linux mutable request memory
success responses require monitor entry
success ledger writes require copied-request validation
success ledger writes require replay-window consume
Linux cannot write authoritative ledger state
response handles require monitor ledger state
Linux shadows refresh from monitor handles/ledger state only
Linux shadows are not authority
terminal failure prevents later receipt for the same attempt
revoke complete requires new receipt embargo
revoke complete requires relevant in-flight direct calls drained or rejected
revoke complete requires derived receipt revoke and shadow invalidation
```

This is semantic evidence only. It is not a binary ABI, direct-call mechanism,
Linux stub, monitor implementation, performance benchmark, or production
protection evidence.
