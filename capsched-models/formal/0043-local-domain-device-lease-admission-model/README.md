# Local Domain Device Lease Admission Model

Status: Draft, intended for tiny finite TLC checking

Date: 2026-06-30

Related artifacts:

```text
analysis/0066-local-domain-device-lease-admission-protocol.md
analysis/local-domain-device-lease-admission-protocol-v1.json
analysis/0065-local-domain-device-lease-observation-contract.md
validation/0065-local-domain-device-lease-admission-tlc.md
```

## Purpose

This model checks the N-093 root-management/local monitor admission protocol
for `LocalDomainDeviceLease`.

It adds three things beyond the observation contract:

```text
failure paths:
  bad signature, stale epoch, revoked lease, service mismatch, device-root
  missing, target mismatch, target epoch/budget invalid

revoke ordering:
  request revoke -> embargo new receipts -> revoke derived receipts -> complete
  local lease revoke

forbidden shortcuts:
  compile after failed checks, receipts before compile, receipts during revoke,
  reuse before revoke completion, and audit-only acceptance
```

## Checked Invariants

```text
NoLocalLeaseAfterRejection
NoLocalLeaseWithoutCheckedClusterLease
NoLocalLeaseWithoutMatchingServiceDomain
NoLocalLeaseWithoutMonitorDeviceRoot
NoLocalLeaseWithoutMatchingTargetDomain
NoLocalLeaseWithoutTargetEpochBudget
NoReceiptBeforeLocalLease
NoEndpointBeforeLocalLease
NoNewReceiptDuringRevoke
NoReuseBeforeRevokeComplete
NoAuditOnlyAdmissionOrRevoke
NoRevokeCompleteWithLiveDerived
```

Unsafe configs intentionally violate one forbidden shortcut each.

## Scope Limit

This is not a monitor ABI, crypto protocol, root-management wire format, Linux
driver patch, or protection proof.

It is a semantic gate for the future admission protocol.
