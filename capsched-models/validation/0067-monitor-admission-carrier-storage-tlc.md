# Validation 0067: Monitor Admission Carrier Storage TLC

Status: Safe model passed; unsafe models produced expected counterexamples

Date: 2026-06-30

Related artifacts:

```text
analysis/0068-local-monitor-admission-carrier-storage.md
analysis/local-monitor-admission-carrier-storage-v1.json
formal/0045-monitor-admission-carrier-storage-model/
```

Run directory:

```text
/media/nia/scsiusb/dev/linux-cap/build/tlc/monitor-admission-carrier-storage-20260630T053457Z
```

## Purpose

This validation checks the N-095 carrier/storage choice gate before selecting a
concrete monitor ABI, Linux service-domain queue, shared ring, or Linux-visible
receipt cache.

The model separates:

```text
request carrier:
  transports admission intent

monitor receipt ledger:
  monitor-owned authority root

Linux shadow:
  non-authoritative cache, index, trace row, or acceleration hint
```

## Safe Result

```text
MonitorAdmissionCarrierStorageSafe:
  Model checking completed. No error has been found.
  11 states generated
  9 distinct states found
  depth 7
```

## Expected Unsafe Counterexamples

```text
MonitorAdmissionCarrierStorageUnsafeLinuxResponseStore:
  Error: Invariant NoLinuxOwnedResponseStoreAuthority is violated.

MonitorAdmissionCarrierStorageUnsafeQueueAsAuthority:
  Error: Invariant NoServiceDomainQueueItemAsAuthority is violated.

MonitorAdmissionCarrierStorageUnsafeShadowAsAuthority:
  Error: Invariant NoLinuxShadowStateAsAuthority is violated.

MonitorAdmissionCarrierStorageUnsafeRingReplay:
  Error: Invariant NoReplayedRingSlotAccepted is violated.

MonitorAdmissionCarrierStorageUnsafeLedgerTamper:
  Error: Invariant NoTamperedReceiptLedgerAccepted is violated.

MonitorAdmissionCarrierStorageUnsafeRequestAsReceipt:
  Error: Invariant NoRequestCarrierTreatedAsReceipt is violated.

MonitorAdmissionCarrierStorageUnsafeAuditLogAsAuthority:
  Error: Invariant NoAuditOnlyLogTreatedAsAuthority is violated.

MonitorAdmissionCarrierStorageUnsafeRawHandleEndpoint:
  Error: Invariant NoRawServiceDomainHandleEndpoint is violated.
```

## Interpretation

This supports the N-095 choice gate:

```text
direct monitor call is acceptable as a correctness baseline
monitor-owned shared ring is acceptable only with monitor-owned slot freshness
Linux service-domain queues are request carriers only
Linux-visible shadows are cache/index/trace hints only
monitor receipt ledger is the authority root
audit-only logs are not runtime authority
raw driver handles are not target Domain endpoints
endpoint delivery requires monitor-verified receipt state
```

This is semantic evidence only. It is not a monitor ABI, not a Linux service
Domain implementation, not a cryptographic sealing design, and not production
protection evidence.
