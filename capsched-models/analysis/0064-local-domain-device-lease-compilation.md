# Analysis 0064: Local Domain Device Lease Compilation

Status: Draft external-gap resolution map with model gate

Date: 2026-06-30

Related artifacts:

```text
analysis/0063-modern-nic-hypertag-observation-ledger.md
validation/0062-modern-nic-hypertag-observation-ledger-result.md
formal/0042-local-domain-device-lease-model/
validation/0063-local-domain-device-lease-tlc.md
```

## Purpose

N-091 resolves the `LocalDomainDeviceLease` gap left by the modern NIC HyperTag
observation ledger.

The N-090 runner correctly reported:

```text
LocalDomainDeviceLease:
  not_in_linux
```

That is not a missing Linux anchor. It is a design boundary.

`LocalDomainDeviceLease` is the local monitor-owned authority created when
root-management or cluster policy is compiled into a node-local device lease.
It must exist before any target Domain can use a queue, VF, SF, DMA view, IRQ
route, or typed endpoint on that node.

## Why Tracefs Cannot Resolve This Gap

Tracefs can observe Linux-visible events:

```text
PCI probe
devlink register
IOMMU attach
VF mailbox dispatch
queue config
DMA map/unmap
IRQ delivery
service work
```

None of those are the act of compiling external authority into a non-forgeable
local monitor root.

Therefore:

```text
privileged tracefs run:
  useful for source-path coverage
  not sufficient for LocalDomainDeviceLease authority

root-management/local monitor model:
  required before distributed device lease claims
```

## Object Boundary

### ClusterLease

Meaning:

```text
remote/root-management policy statement saying that a tenant, Domain, service
Domain, device, queue class, budget, and epoch are allowed somewhere in the
cluster
```

Not authority for local queue use:

```text
signed text
control-plane database row
scheduler placement decision
orchestrator assignment
tenant intent
```

### LocalDomainDeviceLease

Meaning:

```text
local HyperTag Monitor-owned root tying:
  node id
  local monitor epoch
  service Domain
  target Domain
  device root
  VF/SF/queue namespace
  allowed queue classes
  DMA MemoryView boundary
  IRQ route namespace
  root budget
  cluster lease epoch
```

It is the local precondition for minting:

```text
DeviceRootReceipt
VfEpochReceipt
QueueLeaseReceipt
DmaMemoryViewReceipt
IrqRouteReceipt
LedgerRootReceipt
typed endpoint carriers
revoke/handoff receipts
```

### ServiceAdmission

Meaning:

```text
Linux service/driver Domain is selected and allowed to request monitor actions
for a device
```

Not authority:

```text
service admission cannot mint LocalDomainDeviceLease
service admission cannot mint QueueLease/DMA/IRQ receipts
service admission cannot bypass local monitor compilation
```

### DeviceRootBinding

Meaning:

```text
local monitor has registered a PCI RID/PASID or equivalent device root and tied
it to service Domain mediation
```

Not authority:

```text
PCI probe, devlink registration, VFIO group ownership, or IOMMU attach trace is
not DeviceRootBinding authority until the monitor mints the binding
```

## Safe Compilation Flow

The safe local compilation path is:

```text
Root management issues ClusterLease
  -> target node receives lease
  -> local monitor checks cluster signature/epoch/revocation
  -> root management policy admits service Domain for device
  -> local monitor confirms DeviceRootBinding
  -> local monitor checks target Domain epoch and budget root
  -> local monitor compiles LocalDomainDeviceLease
  -> service Domain may request VF/Queue/DMA/IRQ receipts
  -> target Domain may receive typed endpoints
```

No queue activation may happen before `LocalDomainDeviceLease` exists.

## Unsafe Shortcuts

The following are forbidden:

```text
remote cluster lease used directly as local queue authority
scheduler placement used as local queue authority
service Domain admission used as local monitor authority
Linux device registration used as local monitor authority
IOMMU attach trace used as local device root authority
local lease compiled under stale cluster epoch
local lease compiled for wrong service Domain
local lease compiled for wrong target Domain
queue receipt minted before local lease exists
audit-only monitor call after Linux already configured the queue
```

## Required Ledger Fields

Any future root-management/local monitor observation ledger must include:

```text
cluster_lease_id
cluster_epoch
root_management_epoch
node_id
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
observation_only
authority_claim
monitor_verified
behavior_change
protection_claim
```

Until a real monitor exists, observation rows must remain:

```text
observation_only=true
authority_claim=false
monitor_verified=false
behavior_change=false
protection_claim=false
```

## Interaction With Modern NIC QueueLease

`LocalDomainDeviceLease` sits above the modern NIC receipts:

```text
LocalDomainDeviceLease
  -> DeviceRootReceipt
  -> VfEpochReceipt
  -> QueueLeaseReceipt
  -> DmaMemoryViewReceipt
  -> IrqRouteReceipt
  -> LedgerRootReceipt
  -> typed endpoints
```

It does not replace those receipts. It only permits local receipt minting under
the correct root-management, node, service, target, device, and epoch context.

## Design Consequence

The next non-behavior-changing step should be a root-management/local monitor
admission model and observation contract, not a Linux tracefs run, if the goal
is to reduce the `LocalDomainDeviceLease` gap.

Tracefs remains useful later for verifying that Linux-side device paths are
visible, but it cannot prove local monitor compilation.
