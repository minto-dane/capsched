# Validation 0073: Direct-Call Carrier Requirements TLC

Status: Safe model passed; unsafe models produced expected counterexamples

Date: 2026-06-30

Related artifacts:

```text
analysis/0074-direct-call-carrier-requirements.md
analysis/direct-call-carrier-requirements-v1.json
formal/0051-direct-call-carrier-requirements-model/
```

Run directory:

```text
/media/nia/scsiusb/dev/linux-cap/build/tlc/direct-call-carrier-requirements-20260630T203945Z
```

## Purpose

This validation checks the N-101 implementation-facing direct-call carrier
requirements gate for `LocalMonitorAdmissionABI-v0`.

The model separates:

```text
direct-call carrier selection from monitor approval
bounded monitor copy/freeze before validation
canonical request image before decision
shared replay consume before ledger or success
same-nonce different-digest rejection
response handle backed by monitor ledger state
shared shadow generation
Linux timeout as transport observation, not monitor terminality
transport observations as non-authority
control/revoke priority without replay, budget, or epoch bypass
carrier sequence numbers as non-replay authority
future ring compatibility through carrier-neutral namespaces
```

## Safe Result

```text
DirectCallCarrierRequirementsSafe:
  Model checking completed. No error has been found.
  26 states generated
  22 distinct states found
  depth 20
```

## Expected Unsafe Counterexamples

```text
DirectCallCarrierRequirementsUnsafeCarrierSelectionAsApproval:
  Error: Invariant CarrierSelectionIsNotApproval is violated.

DirectCallCarrierRequirementsUnsafeCarrierSequenceReplay:
  Error: Invariant CarrierSequenceIsNotReplayAuthority is violated.

DirectCallCarrierRequirementsUnsafeControlPriorityBypass:
  Error: Invariant ControlRevokeRequiresReplayBudgetEpoch is violated.

DirectCallCarrierRequirementsUnsafeDirectOnlyNamespace:
  Error: Invariant DirectCallKeepsCarrierNeutralNamespaces is violated.

DirectCallCarrierRequirementsUnsafeLedgerBeforeReplay:
  Error: Invariant LedgerRequiresSharedReplay is violated.

DirectCallCarrierRequirementsUnsafeResponseWithoutLedger:
  Error: Invariant ResponseRequiresLedger is violated.

DirectCallCarrierRequirementsUnsafeSameNonceDiffDigestSuccess:
  Error: Invariant NoSameNonceDifferentDigestSuccess is violated.

DirectCallCarrierRequirementsUnsafeShadowWithoutSharedGeneration:
  Error: Invariant ShadowRequiresSharedGeneration is violated.

DirectCallCarrierRequirementsUnsafeSuccessWithoutAttempt:
  Error: Invariant SuccessRequiresCanonicalAttempt is violated.

DirectCallCarrierRequirementsUnsafeTimeoutAsMonitorFailure:
  Error: Invariant LinuxTimeoutIsNotMonitorFailure is violated.

DirectCallCarrierRequirementsUnsafeTransportObservationAsReceipt:
  Error: Invariant TransportObservationIsNotReceipt is violated.

DirectCallCarrierRequirementsUnsafeValidateBeforeCopy:
  Error: Invariant ValidationRequiresBoundedCopyFreeze is violated.
```

## Interpretation

This supports the N-101 direct-call carrier requirements gate:

```text
choosing direct-call first is a reference-carrier decision, not approval
monitor decisions require bounded copy/freeze and canonicalization
success requires canonical monitor attempt and shared replay consume
ledger writes require shared replay
same nonce with different canonical digest cannot become success
response handles require monitor ledger state
shadow refresh requires shared shadow generation
Linux timeout remains unknown transport observation
transport observations cannot mint receipts
control/revoke priority cannot bypass replay, budget, or epoch checks
carrier sequence numbers cannot become replay authority
direct-call requirements must keep carrier-neutral replay, ledger, and shadow namespaces for future ring refinement
```

This is semantic evidence only. It is not a binary ABI, C struct layout,
direct-call trap mechanism, Linux stub, monitor implementation, performance
benchmark, liveness proof, or production protection evidence.
