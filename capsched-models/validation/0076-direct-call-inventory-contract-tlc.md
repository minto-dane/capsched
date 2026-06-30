# Validation 0076: Direct-Call Inventory Contract TLC

Status: Safe model passed; unsafe models produced expected counterexamples

Date: 2026-06-30

Related artifacts:

```text
analysis/0077-direct-call-trace-source-inventory-contract.md
analysis/direct-call-trace-source-inventory-contract-v1.json
analysis/0076-direct-call-attachment-readiness.md
formal/0054-direct-call-inventory-contract-model/
```

Run directory:

```text
/media/nia/scsiusb/dev/linux-cap/build/tlc/direct-call-inventory-contract-20260630T215029Z
```

## Purpose

This validation checks the N-104 no-code direct-call trace/source inventory
contract.

The model separates:

```text
source-only inventory from privileged tracefs execution
current source anchors from future semantic gaps
tracefs-plan suggestions from runtime observations
source/trace observability from authority
inventory output completeness from protection evidence
```

## Safe Result

```text
DirectCallInventoryContractSafe:
  Model checking completed. No error has been found.
  6 states generated
  5 distinct states found
  depth 5
```

## Expected Unsafe Counterexamples

```text
DirectCallInventoryContractUnsafeAnchorAsAuthority:
  Error: Invariant AnchorsAreNotAuthority is violated.

DirectCallInventoryContractUnsafeBehaviorChange:
  Error: Invariant NoBehaviorChange is violated.

DirectCallInventoryContractUnsafeLinuxModification:
  Error: Invariant NoLinuxModification is violated.

DirectCallInventoryContractUnsafeMissingAsNoObligation:
  Error: Invariant MissingAnchorsRemainObligations is violated.

DirectCallInventoryContractUnsafeMonitorVerified:
  Error: Invariant NoMonitorVerifiedClaim is violated.

DirectCallInventoryContractUnsafeOutputIncomplete:
  Error: Invariant AcceptanceRequiresOutputs is violated.

DirectCallInventoryContractUnsafeProbeAttachment:
  Error: Invariant NoProbeAttachment is violated.

DirectCallInventoryContractUnsafeProtectionClaim:
  Error: Invariant NoProtectionClaim is violated.

DirectCallInventoryContractUnsafePublicTracepointAbi:
  Error: Invariant NoPublicTracepointAbi is violated.

DirectCallInventoryContractUnsafeRawHandleExposure:
  Error: Invariant NoRawHandleExposure is violated.

DirectCallInventoryContractUnsafeRootRequired:
  Error: Invariant NoSourceOnlyRootRequirement is violated.

DirectCallInventoryContractUnsafeRuntimeObservationClaim:
  Error: Invariant NoRuntimeObservationClaim is violated.

DirectCallInventoryContractUnsafeSafetyFlagsMissing:
  Error: Invariant AcceptanceRequiresOutputs is violated.

DirectCallInventoryContractUnsafeTraceAsAuthority:
  Error: Invariant TracePlanIsNotAuthority is violated.

DirectCallInventoryContractUnsafeTracefsWrite:
  Error: Invariant NoTracefsWrite is violated.
```

## Interpretation

This supports the N-104 direct-call inventory contract:

```text
source-only inventory must not modify Linux
source-only inventory must not require root
source-only inventory must not write tracefs
source-only inventory must not attach probes or BPF
inventory rows require complete fields and safety flags
missing future anchors remain semantic gaps
current source anchors are not authority
tracefs-plan entries are not authority
runtime observation is not claimed by source inventory
raw handles cannot be exposed
monitor verification cannot be claimed
production protection cannot be claimed
behavior cannot change
```

This is semantic evidence only. It is not a runner implementation, Linux patch,
tracefs execution, QEMU run, binary ABI, public tracepoint ABI, user ABI,
monitor implementation, performance benchmark, liveness proof, or production
protection evidence.
