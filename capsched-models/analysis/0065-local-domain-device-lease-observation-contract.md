# Analysis 0065: Local Domain Device Lease Observation Contract

Status: Draft observation contract, no behavior change

Date: 2026-06-30

Related artifacts:

```text
analysis/0064-local-domain-device-lease-compilation.md
analysis/local-domain-device-lease-compilation-v1.json
analysis/local-domain-device-lease-observation-contract-v1.json
validation/run-local-domain-device-lease-observation-contract.sh
validation/0064-local-domain-device-lease-observation-contract-result.md
```

## Purpose

N-092 turns the `LocalDomainDeviceLease` external boundary into an observation
contract.

This contract exists because the modern NIC HyperTag observation ledger cannot
resolve `LocalDomainDeviceLease` inside upstream Linux. The missing row is not
a driver-source gap. It is the future point where root-management policy is
compiled into a node-local HyperTag Monitor-owned device lease.

The contract answers only:

```text
What rows must a future root-management/local monitor observation ledger emit?
Which fields must be present?
Which dependencies must hold before a local lease compile row can appear?
Which safety flags prevent this observation contract from becoming a protection
claim?
```

It does not answer:

```text
Does a root-management control plane exist?
Does a HyperTag Monitor exist?
Has a local monitor minted any lease?
Is queue, DMA, IRQ, or endpoint protection enforced?
```

## Observation Sequence

The minimum row sequence is:

```text
RootManagementIssueClusterLease
ReceiveClusterLeaseOnNode
MonitorCheckClusterLease
RootManagementAdmitServiceDomain
MonitorBindDeviceRoot
MonitorCheckTargetEpochBudget
MonitorCompileLocalDomainDeviceLease
ServiceDomainRequestDeviceReceipts
TargetDomainReceiveTypedEndpoints
MonitorRevokeLocalDomainDeviceLease
```

`MonitorCompileLocalDomainDeviceLease` is the first row that may name a
`compiled_local_lease_id`.

No receipt or typed endpoint row may appear as locally usable authority before
that compile row.

## Required Fields

Every row must carry enough data to distinguish remote policy from local
authority:

```text
row_id
phase
authority_object
cluster_lease_id
cluster_epoch
root_management_epoch
node_id
local_monitor_id
local_monitor_epoch
service_domain_id
target_domain_id
device_root_id
device_root_epoch
allowed_queue_classes
dma_memoryview_policy_id
irq_route_policy_id
root_budget_id
compiled_local_lease_id
compiled_local_lease_epoch
compile_result
revocation_status
predecessors
evidence_surface
expected_pre_monitor_status
forbidden_shortcut
observation_only
authority_claim
monitor_verified
behavior_change
protection_claim
```

The field values may be opaque strings in early ledgers. The important point is
that the same row cannot blur cluster authority, service admission, Linux
device registration, and monitor-minted local authority into one object.

## Pre-Monitor Safety Flags

Until a real monitor exists, every row must remain:

```text
observation_only=true
authority_claim=false
monitor_verified=false
behavior_change=false
protection_claim=false
```

This is stricter than a normal audit log. A row that observes a desirable
future event is still not the event.

## Dependency Rules

The contract rejects these dependency collapses:

```text
Local lease compile without checked cluster lease
Local lease compile without service admission matching the lease
Local lease compile without monitor-owned device-root binding
Local lease compile without target Domain epoch and root budget check
Receipt request before local lease compile
Typed endpoint delivery before local lease compile
Revoke row treated as proof that stale receipts are already gone
```

## Forbidden Shortcuts

The observation contract must keep these visibly false:

```text
ClusterLease text is LocalDomainDeviceLease.
Scheduler placement is LocalDomainDeviceLease.
ServiceAdmission is LocalDomainDeviceLease.
Linux PCI/devlink/IOMMU registration is LocalDomainDeviceLease.
IOMMU attach trace is DeviceRootBinding authority.
Audit-only monitor log is compile authority.
Receipt request is receipt minting.
Typed endpoint delivery is monitor verification.
Revocation request is completed revoke.
```

## Validation Runner

The no-behavior-change runner:

```text
validation/run-local-domain-device-lease-observation-contract.sh
```

validates the JSON contract and emits:

```text
contract-rows.tsv
semantic-gaps.tsv
summary.txt
```

It does not:

```text
modify Linux
touch tracefs
require root
run QEMU
talk to a monitor
claim protection
```

## Design Consequence

The next implementation-facing work may use this contract as a hard input, but
not as authority.

A future monitor or root-management prototype must either emit rows compatible
with this contract or explicitly replace the contract with a stronger one.

Any design that lets `ClusterLease`, scheduler placement, service Domain
admission, or Linux device registration stand in for `LocalDomainDeviceLease`
is rejected before implementation.
