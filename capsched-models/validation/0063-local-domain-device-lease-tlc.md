# Validation 0063: Local Domain Device Lease TLC

Status: Safe model passed; unsafe models produced expected counterexamples

Date: 2026-06-30

Related artifacts:

```text
analysis/0064-local-domain-device-lease-compilation.md
analysis/local-domain-device-lease-compilation-v1.json
formal/0042-local-domain-device-lease-model/
```

## Purpose

This validation checks the N-091 external-gap resolution for
`LocalDomainDeviceLease`.

The model separates:

```text
ClusterLease:
  remote/root-management policy statement

ServiceAdmission:
  permission for a service/driver Domain to request monitor actions

Linux device registration:
  Linux-visible mutable substrate

LocalDomainDeviceLease:
  local HyperTag Monitor-minted authority root required before queue, DMA, IRQ,
  ledger, and typed endpoint receipts
```

## Command

```sh
model_dir=/media/nia/scsiusb/dev/linux-cap/capsched/capsched-models/formal/0042-local-domain-device-lease-model
run_dir=/media/nia/scsiusb/dev/linux-cap/build/tlc/local-domain-device-lease-20260630T050201Z

for cfg in "$model_dir"/LocalDomainDeviceLease*.cfg; do
        base="$(basename "$cfg" .cfg)"
        java -cp /home/nia/tools/tla/tla2tools.jar tlc2.TLC \
                -metadir "$run_dir/${base}-states" \
                -config "$cfg" \
                "$model_dir/LocalDomainDeviceLease.tla" \
                > "$run_dir/${base}.log" 2>&1 || true
done
```

## Safe Result

```text
LocalDomainDeviceLeaseSafe:
  Model checking completed. No error has been found.
  10 states generated
  9 distinct states found
  depth 9
```

## Expected Unsafe Counterexamples

```text
LocalDomainDeviceLeaseUnsafeRemoteDirect:
  Error: Invariant NoRemoteLeaseDirectUse is violated.

LocalDomainDeviceLeaseUnsafeSchedulerPlacement:
  Error: Invariant NoSchedulerPlacementAsAuthority is violated.

LocalDomainDeviceLeaseUnsafeServiceAdmissionMints:
  Error: Invariant NoServiceAdmissionMintsLease is violated.

LocalDomainDeviceLeaseUnsafeLinuxDeviceRoot:
  Error: Invariant NoLinuxDeviceRootAsLease is violated.

LocalDomainDeviceLeaseUnsafeStaleClusterEpoch:
  Error: Invariant NoStaleClusterEpochLease is violated.

LocalDomainDeviceLeaseUnsafeWrongService:
  Error: Invariant NoWrongServiceDomainLease is violated.

LocalDomainDeviceLeaseUnsafeWrongTarget:
  Error: Invariant NoWrongTargetDomainLease is violated.

LocalDomainDeviceLeaseUnsafeQueueReceiptNoLease:
  Error: Invariant NoDeviceReceiptWithoutLocalLease is violated.

LocalDomainDeviceLeaseUnsafeAuditOnly:
  Error: Invariant NoAuditOnlyCompile is violated.
```

## Interpretation

This supports the following design gate:

```text
No QueueLease/DMA/IRQ/ledger/typed endpoint receipt may be minted from a remote
ClusterLease, scheduler placement decision, service-domain admission, Linux
device registration, IOMMU attach trace, stale cluster epoch, wrong service
Domain, wrong target Domain, or audit-only monitor call.
```

`LocalDomainDeviceLease` remains outside upstream Linux. Tracefs can observe
Linux-side source paths, but it cannot prove that root-management authority was
compiled into a local monitor-owned lease.

This is semantic evidence only. It is not a HyperTag Monitor implementation,
not Linux behavior evidence, and not production protection evidence.
