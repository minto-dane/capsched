# Local Domain Device Lease Model

Status: Draft, intended for tiny finite TLC checking

Date: 2026-06-30

Related artifacts:

```text
analysis/0064-local-domain-device-lease-compilation.md
analysis/local-domain-device-lease-compilation-v1.json
validation/0063-local-domain-device-lease-tlc.md
```

## Purpose

This model checks the N-091 resolution for the `LocalDomainDeviceLease`
external gap.

The key point is:

```text
ClusterLease is not local authority.
ServiceAdmission is not local authority.
Linux device registration is not local authority.
LocalDomainDeviceLease must be monitor-minted before device receipts.
```

## Checked Invariants

```text
NoDeviceReceiptWithoutLocalLease
NoRemoteLeaseDirectUse
NoSchedulerPlacementAsAuthority
NoServiceAdmissionMintsLease
NoLinuxDeviceRootAsLease
NoStaleClusterEpochLease
NoWrongServiceDomainLease
NoWrongTargetDomainLease
NoAuditOnlyCompile
NoBadRemoteLeaseDirect
NoBadSchedulerPlacement
NoBadServiceAdmissionMints
NoBadLinuxDeviceRoot
NoBadStaleClusterEpoch
NoBadWrongServiceDomain
NoBadWrongTargetDomain
NoBadQueueReceiptNoLocalLease
NoBadAuditOnlyCompile
```

## Unsafe Configurations

```text
LocalDomainDeviceLeaseUnsafeRemoteDirect.cfg
LocalDomainDeviceLeaseUnsafeSchedulerPlacement.cfg
LocalDomainDeviceLeaseUnsafeServiceAdmissionMints.cfg
LocalDomainDeviceLeaseUnsafeLinuxDeviceRoot.cfg
LocalDomainDeviceLeaseUnsafeStaleClusterEpoch.cfg
LocalDomainDeviceLeaseUnsafeWrongService.cfg
LocalDomainDeviceLeaseUnsafeWrongTarget.cfg
LocalDomainDeviceLeaseUnsafeQueueReceiptNoLease.cfg
LocalDomainDeviceLeaseUnsafeAuditOnly.cfg
```

## Scope Limit

This is not a distributed control plane implementation and not a HyperTag
Monitor implementation.

It is a semantic filter for the external gap left by source-observation: Linux
tracefs can observe device paths, but it cannot prove root-management policy
has been compiled into a local monitor-owned device lease.
