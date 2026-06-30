# Validation 0069: Monitor Admission Carrier Sketch TLC

Status: Safe model passed; unsafe models produced expected counterexamples

Date: 2026-06-30

Related artifacts:

```text
analysis/0070-local-monitor-admission-carrier-sketch-comparison.md
analysis/local-monitor-admission-carrier-sketch-comparison-v1.json
formal/0047-monitor-admission-carrier-sketch-model/
```

Run directory:

```text
/media/nia/scsiusb/dev/linux-cap/build/tlc/monitor-admission-carrier-sketch-20260630T060150Z
```

## Purpose

This validation checks the N-097 comparison between direct-call-first reference
semantics and monitor-owned-ring-first throughput refinement for
`LocalMonitorAdmissionABI-v0`.

The model separates:

```text
direct-call monitor entry
ring monitor slot claim
monitor-owned replay check
monitor-owned ledger write
Linux-visible shadow refresh from ledger only
pending ring response drain before revoke complete
performance cost from security authority
```

## Safe Result

```text
MonitorAdmissionCarrierSketchSafe:
  Model checking completed. No error has been found.
  18 states generated
  16 distinct states found
  depth 9
```

## Expected Unsafe Counterexamples

```text
MonitorAdmissionCarrierSketchUnsafeLinuxDirectResponse:
  Error: Invariant NoLinuxDirectResponseAuthority is violated.

MonitorAdmissionCarrierSketchUnsafeDirectNoReplayCheck:
  Error: Invariant ResponseRequiresReplayCheck is violated.

MonitorAdmissionCarrierSketchUnsafeRingSlotAuthority:
  Error: Invariant RingSlotIsNotAuthority is violated.

MonitorAdmissionCarrierSketchUnsafeRingResponseBeforeClaim:
  Error: Invariant RingResponseRequiresMonitorClaim is violated.

MonitorAdmissionCarrierSketchUnsafeBatchEpochCrossing:
  Error: Invariant NoBatchEpochCrossing is violated.

MonitorAdmissionCarrierSketchUnsafeShadowFromCarrier:
  Error: Invariant ShadowRefreshRequiresLedger is violated.

MonitorAdmissionCarrierSketchUnsafeRevokeWithPendingRing:
  Error: Invariant NoPendingRingAtRevokeComplete is violated.

MonitorAdmissionCarrierSketchUnsafeCostAsSecurity:
  Error: Invariant CostMetricIsNotSecurityAuthority is violated.
```

## Interpretation

This supports the N-097 carrier-sketch gate:

```text
direct-call-first is the small reference semantic sketch
monitor-owned-ring-first is the required throughput refinement direction
ring slots are not authority
ring response publication follows monitor slot claim
replay checks precede success response and ledger writes
batch reordering cannot cross epoch boundaries
shadows refresh from monitor ledger state only
revoke complete requires pending ring responses drained or invalidated
performance cost metrics cannot authorize security decisions
```

This is semantic evidence only. It is not a binary ABI, shared-ring memory
layout, direct-call mechanism, Linux stub, monitor implementation, performance
benchmark, or production protection evidence.
