# Analysis 0067: Local Monitor Admission Interface Boundary

Status: Draft interface-boundary map with model gate

Date: 2026-06-30

Related artifacts:

```text
analysis/0066-local-domain-device-lease-admission-protocol.md
analysis/local-monitor-admission-interface-boundary-v1.json
formal/0044-local-monitor-admission-interface-model/
validation/0066-local-monitor-admission-interface-tlc.md
```

## Purpose

N-094 defines the local monitor admission interface boundary for
`LocalDomainDeviceLease` before selecting a concrete monitor ABI, Linux stub,
or implementation.

The boundary is deliberately typed around request and receipt ownership:

```text
Linux service Domain may carry requests.
Root-management may issue cluster policy.
Only the local HyperTag Monitor may mint local admission responses and receipts.
Target Domains may receive typed endpoints only after monitor receipts exist.
```

## Non-ABI Scope

This is not:

```text
a syscall ABI
a VM-call ABI
a netlink ABI
a binary wire format
a cryptographic suite
a Linux patch plan
a monitor implementation
```

It is the semantic boundary that those future choices must preserve.

## Request Objects

Minimum request objects:

```text
ClusterLeaseImportRequest:
  cluster lease id, cluster epoch, root-management epoch, target node

ServiceAdmissionRequest:
  service Domain id, service Domain epoch, allowed service actions

DeviceRootBindRequest:
  device root id, PCI RID/PASID/equivalent identity, device-root epoch intent

TargetDomainAdmissionRequest:
  target Domain id, target Domain epoch, root budget id

LocalLeaseCompileRequest:
  previous request ids, queue classes, DMA MemoryView policy, IRQ route policy

DeviceReceiptMintRequest:
  LocalDomainDeviceLease id, requested DeviceRoot/VF/Queue/DMA/IRQ/Ledger
  receipt classes

LocalLeaseRevokeRequest:
  LocalDomainDeviceLease id, local lease epoch, revoke reason, requested
  revoke scope
```

## Monitor-Owned Response Objects

Minimum response/receipt objects:

```text
AdmissionFailureReceipt:
  reason, failed phase, monitor epoch, cluster lease id, node id

LocalDomainDeviceLeaseReceipt:
  local lease id, local lease epoch, monitor epoch, service Domain, target
  Domain, device root, queue classes, DMA/IRQ policies, root budget

DeviceRootReceipt:
  monitor-owned device root id and epoch

VfEpochReceipt:
  VF/SF identity epoch and binding

QueueLeaseReceipt:
  queue tag, queue epoch, allowed queue classes, queue budget

DmaMemoryViewReceipt:
  MemoryView/DMA root and IOMMU ownership epoch

IrqRouteReceipt:
  IRQ route tag, delivery endpoint, interrupt-remapping epoch

LedgerRootReceipt:
  submit/descriptor/completion ledger root

RevokeStartedReceipt:
  local lease id, revoke epoch, no-new-receipt rule begins

NewReceiptEmbargoReceipt:
  monitor confirms no new receipt can be minted under the old local lease epoch

DerivedReceiptRevokeReceipt:
  queue/DMA/IRQ/ledger/endpoint derived receipts are invalidated

LocalLeaseRevokeCompleteReceipt:
  local lease can no longer authorize derived receipts or endpoint delivery
```

## Freshness Fields

Every request and response family needs explicit freshness fields:

```text
request_nonce
request_generation
monitor_id
monitor_epoch
cluster_lease_id
cluster_epoch
root_management_epoch
node_id
service_domain_id
service_domain_epoch
target_domain_id
target_domain_epoch
device_root_id
device_root_epoch
local_lease_id
local_lease_epoch
receipt_epoch
revoke_epoch
replay_window_id
```

Missing freshness fields must be treated as `not admissible`, not as "best
effort".

## Linux Service-Domain Attachment Points

Future Linux-side probes or stubs may observe or carry:

```text
request construction
request submission to monitor
monitor response arrival
service-domain receipt consumption
hardware programming after receipt
typed endpoint delivery to target Domain
revoke request
revoke receipt consumption
```

They must not expose:

```text
raw PF/VF/IOMMU/MSI/devlink handles to target Domains
Linux-minted monitor responses
Linux-minted receipt ids
audit-only success
stale replayed responses
```

## Interface Invariants

```text
No Linux-minted monitor response.
No replayed admission response.
Failure receipt terminates the admission attempt.
No device receipt without a monitor-minted local lease response.
No typed endpoint without monitor-minted device receipts.
No local lease reuse before revoke complete.
No revoke complete while derived receipts remain live.
No raw service-domain device handle escapes as a typed target endpoint.
```

## Design Consequence

The next implementation-facing choice is the carrier shape:

```text
monitor call ABI
Linux service-domain request queue
root-management to node admission feed
receipt ledger storage
typed endpoint delivery path
revoke receipt path
```

But this boundary rejects any design where the Linux service Domain mints
monitor responses, accepts replayed monitor responses, exposes raw device
handles, or treats an audit log as receipt authority.
