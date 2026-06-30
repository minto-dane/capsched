# Validation 0072: Combined Admission Carriers TLC

Status: Safe model passed; unsafe models produced expected counterexamples

Date: 2026-06-30

Related artifacts:

```text
analysis/0073-combined-admission-carriers-plan.md
analysis/combined-admission-carriers-plan-v1.json
formal/0050-combined-admission-carriers-model/
```

Run directory:

```text
/media/nia/scsiusb/dev/linux-cap/build/tlc/combined-admission-carriers-20260630T070827Z
```

## Purpose

This validation checks the N-100 combined direct-call plus monitor-owned-ring
carrier plan for `LocalMonitorAdmissionABI-v0`.

The model separates:

```text
canonical monitor admission attempt
direct-call carrier
monitor-owned ring carrier
ring-full fallback before monitor claim
shared replay namespace
shared receipt ledger
shared shadow generation
cross-carrier fallback without duplicate success
revoke ordering across both carriers
carrier-visible epoch consistency
```

## Safe Result

```text
CombinedAdmissionCarriersSafe:
  Model checking completed. No error has been found.
  52 states generated
  46 distinct states found
  depth 17
```

## Expected Unsafe Counterexamples

```text
CombinedAdmissionCarriersUnsafeAttemptFromCarrierId:
  Error: Invariant LedgerRequiresMonitorAttempt is violated.

CombinedAdmissionCarriersUnsafeCarrierLocalLedger:
  Error: Invariant NoCarrierLocalLedgerAuthority is violated.

CombinedAdmissionCarriersUnsafeCarrierShadowGeneration:
  Error: Invariant CarrierShadowGenerationIsNotAuthority is violated.

CombinedAdmissionCarriersUnsafeDuplicateSuccessFallback:
  Error: Invariant AtMostOneSuccessPerReplayKey is violated.

CombinedAdmissionCarriersUnsafeEpochSplit:
  Error: Invariant NoCarrierEpochSplit is violated.

CombinedAdmissionCarriersUnsafeResponseWithoutSharedLedger:
  Error: Invariant ResponseRequiresSharedLedger is violated.

CombinedAdmissionCarriersUnsafeRevokeStopsOneCarrier:
  Error: Invariant RevokeCompleteStopsAllCarriers is violated.

CombinedAdmissionCarriersUnsafeRevokeWithDirectInFlight:
  Error: Invariant RevokeCompleteDrainsAllCarriers is violated.

CombinedAdmissionCarriersUnsafeRevokeWithRingPending:
  Error: Invariant RevokeCompleteDrainsAllCarriers is violated.

CombinedAdmissionCarriersUnsafeRingFullAsMonitorFailure:
  Error: Invariant RingFullAccountingIsNotMonitorFailure is violated.

CombinedAdmissionCarriersUnsafeSeparateReplayNamespace:
  Error: Invariant CarrierLocalReplayIsNotAuthority is violated.
```

## Interpretation

This supports the N-100 combined-carrier gate:

```text
direct-call and ring carriers share one monitor-owned admission attempt model
carrier-local ids are not monitor attempt ids
carrier-local replay is not authority
carrier-local ledgers are not authority
carrier-local shadow generations are not authority
direct/ring fallback cannot produce duplicate success for one replay key
responses require shared monitor ledger state
epoch splits between carrier-visible request and ledger state fail
ring full before monitor claim is availability/accounting, not monitor failure
revoke complete must stop and drain both carriers
```

This is semantic evidence only. It is not a binary ABI, direct-call trap
mechanism, ring memory layout, Linux stub, monitor implementation, performance
benchmark, cluster-scale liveness proof, or production protection evidence.
