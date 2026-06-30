# Validation 0068: Local Monitor Admission ABI TLC

Status: Safe model passed; unsafe models produced expected counterexamples

Date: 2026-06-30

Related artifacts:

```text
analysis/0069-local-monitor-admission-abi-semantics.md
analysis/local-monitor-admission-abi-semantics-v0.json
formal/0046-local-monitor-admission-abi-model/
```

Run directory:

```text
/media/nia/scsiusb/dev/linux-cap/build/tlc/local-monitor-admission-abi-20260630T055403Z
```

## Purpose

This validation checks the N-096 `LocalMonitorAdmissionABI-v0` semantic
candidate before choosing a carrier, binary ABI, Linux service-domain stub, or
monitor implementation.

The model separates:

```text
typed request classes
monitor-owned responses
monitor-owned receipt ledger writes
monitor-owned replay windows
Linux-visible shadows as non-authoritative state
failure terminality
revoke ordering and shadow invalidation
```

## Safe Result

```text
LocalMonitorAdmissionABISafe:
  Model checking completed. No error has been found.
  24 states generated
  20 distinct states found
  depth 12
```

## Expected Unsafe Counterexamples

```text
LocalMonitorAdmissionABIUnsafeUnknownClassAccepted:
  Error: Invariant KnownRequestClassRequiredForAccept is violated.

LocalMonitorAdmissionABIUnsafeResponseWithoutRequest:
  Error: Invariant MonitorResponseRequiresRequest is violated.

LocalMonitorAdmissionABIUnsafeReplayAccepted:
  Error: Invariant AcceptedRequestRequiresFreshReplayWindow is violated.

LocalMonitorAdmissionABIUnsafeFailureThenReceipt:
  Error: Invariant FailureTerminalForAttempt is violated.

LocalMonitorAdmissionABIUnsafeLinuxLedgerWrite:
  Error: Invariant MonitorOwnsReceiptLedgerWrites is violated.

LocalMonitorAdmissionABIUnsafeEndpointBeforeReceipt:
  Error: Invariant EndpointRequiresMonitorVerifiedReceipts is violated.

LocalMonitorAdmissionABIUnsafeShadowAuthority:
  Error: Invariant LinuxShadowIsNotAuthority is violated.

LocalMonitorAdmissionABIUnsafeShadowNotInvalidated:
  Error: Invariant ShadowInvalidatedBeforeRevokeComplete is violated.

LocalMonitorAdmissionABIUnsafeNewReceiptDuringRevoke:
  Error: Invariant NoNewReceiptsDuringRevoke is violated.

LocalMonitorAdmissionABIUnsafeRevokeCompleteBeforeDerived:
  Error: Invariant RevokeCompleteRequiresDerivedRevoke is violated.
```

## Model Refinement Note

An earlier safe run failed because the model mixed "endpoint was delivered in
the past" with "endpoint is still live". The model was corrected so derived
receipt revoke clears the live endpoint state. This is a useful semantic
constraint for the future ABI: endpoint delivery evidence and live endpoint
authority must be distinct or explicitly generation-scoped.

## Interpretation

This supports the N-096 semantic ABI gate:

```text
unknown request classes fail closed
monitor responses require a request
accepted requests require fresh replay-window state
failure is terminal for the request attempt
Linux cannot write authoritative receipt ledger state
endpoint delivery requires monitor-verified receipts
Linux-visible shadows are not authority
Linux-visible shadows are invalidated before revoke complete
new receipts cannot be minted during revoke
revoke complete requires derived receipt revoke
```

This is semantic evidence only. It is not a binary ABI, not a monitor call
layout, not a shared-ring format, not a Linux stub, not a monitor
implementation, and not production protection evidence.
