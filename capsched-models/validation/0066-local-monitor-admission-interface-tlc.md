# Validation 0066: Local Monitor Admission Interface TLC

Status: Safe model passed; unsafe models produced expected counterexamples

Date: 2026-06-30

Related artifacts:

```text
analysis/0067-local-monitor-admission-interface-boundary.md
analysis/local-monitor-admission-interface-boundary-v1.json
formal/0044-local-monitor-admission-interface-model/
```

Run directory:

```text
/media/nia/scsiusb/dev/linux-cap/build/tlc/local-monitor-admission-interface-20260630T052615Z
```

## Purpose

This validation checks the N-094 local monitor admission interface boundary
before choosing a concrete ABI, Linux stub, or implementation.

The model separates:

```text
Linux service Domain:
  request carrier only

Local HyperTag Monitor:
  sole minter of admission responses and receipts

Target Domain:
  typed endpoint receiver only after monitor receipts
```

## Safe Result

```text
LocalMonitorAdmissionInterfaceSafe:
  Model checking completed. No error has been found.
  14 states generated
  12 distinct states found
  depth 11
```

## Expected Unsafe Counterexamples

```text
LocalMonitorAdmissionInterfaceUnsafeLinuxMintsResponse:
  Error: Invariant NoLinuxMintedMonitorResponse is violated.

LocalMonitorAdmissionInterfaceUnsafeReplayAccepted:
  Error: Invariant NoReplayedAdmissionResponse is violated.

LocalMonitorAdmissionInterfaceUnsafeFailureThenCompile:
  Error: Invariant FailureReceiptTerminatesAttempt is violated.

LocalMonitorAdmissionInterfaceUnsafeReceiptWithoutMonitorResponse:
  Error: Invariant NoDeviceReceiptWithoutMonitorLocalLeaseResponse is violated.

LocalMonitorAdmissionInterfaceUnsafeEndpointWithoutReceipts:
  Error: Invariant NoTypedEndpointWithoutMonitorDeviceReceipts is violated.

LocalMonitorAdmissionInterfaceUnsafeRevokeCompleteWithLiveDerived:
  Error: Invariant NoRevokeCompleteWithLiveDerivedReceipts is violated.

LocalMonitorAdmissionInterfaceUnsafeRawServiceHandle:
  Error: Invariant NoRawServiceDomainHandleEscapes is violated.
```

## Interpretation

This supports the N-094 interface-boundary gate:

```text
Linux may carry requests but cannot mint monitor responses.
Replay/stale admission responses must not be accepted.
Failure receipts terminate the admission attempt.
Device receipts require a monitor-minted local lease response.
Typed endpoint delivery requires monitor-minted device receipts.
Revoke completion requires derived receipt revocation first.
Raw service-domain PF/VF/IOMMU/MSI/devlink handles must not escape as target
Domain endpoints.
```

This is semantic evidence only. It is not a monitor ABI, not a Linux stub, not
a monitor implementation, and not production protection evidence.
