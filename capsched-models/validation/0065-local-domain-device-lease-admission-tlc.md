# Validation 0065: Local Domain Device Lease Admission TLC

Status: Safe model passed; unsafe models produced expected counterexamples

Date: 2026-06-30

Related artifacts:

```text
analysis/0066-local-domain-device-lease-admission-protocol.md
analysis/local-domain-device-lease-admission-protocol-v1.json
analysis/0065-local-domain-device-lease-observation-contract.md
formal/0043-local-domain-device-lease-admission-model/
```

Run directory:

```text
/media/nia/scsiusb/dev/linux-cap/build/tlc/local-domain-device-lease-admission-20260630T051906Z
```

## Purpose

This validation checks the N-093 root-management/local monitor admission
protocol for `LocalDomainDeviceLease`.

The model includes:

```text
happy path:
  ClusterLease issue -> node receive -> monitor check -> service admission ->
  device-root bind -> target epoch/budget check -> local lease compile ->
  receipt mint -> endpoint delivery -> revoke request -> receipt embargo ->
  derived receipt revoke -> complete revoke

failure paths:
  bad cluster signature
  stale cluster epoch
  cluster lease revoked
  service Domain mismatch
  device root missing
  target Domain mismatch
  target epoch or root budget invalid

unsafe shortcuts:
  compile after failed cluster checks
  compile with service mismatch
  compile with target mismatch
  receipt before local lease compile
  new receipt during revoke
  local lease reuse before revoke completion
  audit-only admission/revoke acceptance
```

## Command

```sh
model_dir=/media/nia/scsiusb/dev/linux-cap/capsched/capsched-models/formal/0043-local-domain-device-lease-admission-model
run_dir=/media/nia/scsiusb/dev/linux-cap/build/tlc/local-domain-device-lease-admission-20260630T051906Z

for cfg in "$model_dir"/LocalDomainDeviceLeaseAdmission*.cfg; do
        base="$(basename "$cfg" .cfg)"
        java -cp /home/nia/tools/tla/tla2tools.jar tlc2.TLC \
                -metadir "$run_dir/${base}-states" \
                -config "$cfg" \
                "$model_dir/LocalDomainDeviceLeaseAdmission.tla" \
                > "$run_dir/${base}.log" 2>&1 || true
done
```

## Safe Result

```text
LocalDomainDeviceLeaseAdmissionSafe:
  Model checking completed. No error has been found.
  29 states generated
  21 distinct states found
  depth 14
```

## Expected Unsafe Counterexamples

```text
LocalDomainDeviceLeaseAdmissionUnsafeCompileBadCluster:
  Error: Invariant NoLocalLeaseWithoutCheckedClusterLease is violated.

LocalDomainDeviceLeaseAdmissionUnsafeCompileServiceMismatch:
  Error: Invariant NoLocalLeaseWithoutMatchingServiceDomain is violated.

LocalDomainDeviceLeaseAdmissionUnsafeCompileTargetMismatch:
  Error: Invariant NoLocalLeaseWithoutMatchingTargetDomain is violated.

LocalDomainDeviceLeaseAdmissionUnsafeReceiptBeforeCompile:
  Error: Invariant NoReceiptBeforeLocalLease is violated.

LocalDomainDeviceLeaseAdmissionUnsafeReceiptDuringRevoke:
  Error: Invariant NoNewReceiptDuringRevoke is violated.

LocalDomainDeviceLeaseAdmissionUnsafeReuseBeforeRevokeComplete:
  Error: Invariant NoReuseBeforeRevokeComplete is violated.

LocalDomainDeviceLeaseAdmissionUnsafeAuditOnlyAccept:
  Error: Invariant NoAuditOnlyAdmissionOrRevoke is violated.
```

## Interpretation

This supports the N-093 gate:

```text
Admission failures are terminal for that attempt.
Local lease compile requires checked cluster lease, matching service Domain,
monitor-owned device root, matching target Domain, fresh target epoch, and root
budget.
Receipt and endpoint rows require local lease compile.
Revoke prevents new receipts before derived receipts are revoked and local lease
reuse is allowed only after revoke completion.
Audit-only logs are never admission or revoke authority.
```

This is semantic evidence only. It is not a root-management implementation, not
a HyperTag Monitor implementation, not a Linux behavior change, and not
production protection evidence.
