# Analysis 0062: Modern NIC HyperTag Readiness Probe Map

Status: Draft implementation-readiness map, no behavior-changing approval

Date: 2026-06-30

Related artifacts:

```text
analysis/0061-modern-nic-hypertag-interface-map.md
formal/0040-modern-nic-hypertag-split-model/
validation/0060-modern-nic-hypertag-split-tlc.md
implementation/0007-modern-nic-hypertag-readiness-gate.md
```

## Purpose

N-089 defines the first implementation-readiness gate for the monitor-backed
modern NIC path. The goal is not to implement HyperTag enforcement yet.

The goal is:

```text
map every required monitor receipt or typed carrier
  to observation-only Linux probes or inert stubs
  while proving those probes/stubs cannot be claimed as authority
```

This is a brake, not an accelerator. It exists because a realistic NIC
integration can easily slip into unsafe shortcuts:

```text
Linux saw the queue -> queue authority exists
Linux unmapped DMA -> DMA is revoked
Linux freed IRQ -> IRQ route is revoked
driver reset finished -> fresh VF epoch exists
tracepoint fired -> ledger exists
stub compiled -> monitor exists
```

All of those are forbidden.

## Gate Vocabulary

Use these terms precisely.

```text
receipt:
  monitor-minted fact that Linux cannot forge, replay, or roll back

carrier:
  frozen service/endpoint request context consumed by a Linux service Domain

probe:
  observation-only Linux measurement of a source path or event

stub:
  inert type or call shape that compiles but has no authority, no hardware
  effect, no user ABI, and no changed return value

readiness:
  evidence that the next implementation question is well-scoped, not evidence
  that protection already exists
```

The following implication is forbidden:

```text
probe observed OR stub compiled
  => authority exists
```

The only allowed implication is:

```text
probe observed OR stub compiled
  => we know where a future authority check or receipt consumption would have
     to be placed, and what evidence is still missing
```

## Required Receipt And Carrier Rows

Each row below must eventually become machine-checkable in a readiness ledger.
The immediate N-089 map names the row, the observation surface, the stub shape,
and the forbidden claim.

### LocalDomainDeviceLease

Authority meaning:

```text
remote or root-management placement policy has been compiled into a local
monitor-owned device lease for this node, service Domain, device, and epoch
```

Observation-only probes:

```text
root-management admission decision log
service Domain selection log
device placement policy trace
cluster lease receive/revoke trace
```

Inert stub shape:

```text
opaque local lease id
epoch value
service Domain id
device id
no direct queue, DMA, or IRQ authority
```

Forbidden claim:

```text
signed cluster lease text, scheduler placement, or service admission is not
local monitor authority.
```

### DeviceRootReceipt

Authority meaning:

```text
the monitor owns or mediates the device DMA root, interrupt root, and receipt
namespace for the PCI RID/PASID or equivalent device identity
```

Observation-only probes:

```text
PCI probe/remove
driver bind/unbind
VFIO/iommufd group or device ownership transitions
IOMMU domain attach/detach events
netdev register/unregister
devlink instance register/unregister
```

Inert stub shape:

```text
device root receipt type
RID/PASID identity fields
service Domain binding field
monitor epoch field
no IOMMU attach, no MSI change, no queue enable
```

Forbidden claim:

```text
PCI enumeration, netdev registration, driver probe success, VFIO group
ownership, or iommufd object lifetime is not DeviceRootReceipt.
```

### VfEpochReceipt

Authority meaning:

```text
the visible VF/SF identity has a fresh monitor epoch and cannot inherit old
queue, DMA, IRQ, mailbox, FDIR, or service replay authority
```

Observation-only probes:

```text
ice_get_vf_by_id() source anchor
ice_reset_vf(), ice_reset_all_vfs(), ice_free_vfs()
VFLR and rebuild path traces
ICE_VF_STATE_ACTIVE/DIS transitions
mailbox open/embargo/reopen traces
VSI index release/reuse traces
```

Inert stub shape:

```text
VF epoch token type
visible vf_id
monitor vf_epoch
VSI generation placeholder
no mailbox acceptance, no queue enable, no service replay
```

Forbidden claim:

```text
vf_id equality, ice_vf pointer reachability, cfg_lock, ACTIVE/DIS state,
stable VSI index, or reset completion is not fresh VF epoch authority.
```

### QueueLeaseReceipt

Authority meaning:

```text
specific Domain, VF/SF, queue, queue epoch, submit class, budget, and co-tenant
policy may use a specific queue under monitor ownership
```

Observation-only probes:

```text
ring allocation/free
q_vector/NAPI binding
VSI queue map changes
VF queue configuration
devlink/rate queue-control paths
XDP/AF_XDP queue bind paths
representor lower queue selection
```

Inert stub shape:

```text
QueueLease id and epoch type
submit class enum
queue budget placeholder
allowed queue id
no queue state mutation
```

Forbidden claim:

```text
ring pointer, q_vector, NAPI instance, queue_mapping, VF queue id, VPLAN queue
base, or devlink queue state is not QueueLeaseReceipt.
```

### DmaMemoryViewReceipt

Authority meaning:

```text
the queue may DMA only to pages in the target MemoryView, and old mappings are
revoked only after completed monitor-visible invalidation and drain
```

Observation-only probes:

```text
VF-provided dma_ring_addr copy points
dma_map_* and dma_unmap_* call paths
dma-iommu unmap and sync paths
iommufd access-user release/unmap/unpin paths
VFIO type1 unmap/unpin callbacks
IOMMU queued flush and completion paths
XSK pool map/unmap
page_pool recycle/return
```

Inert stub shape:

```text
DMA MemoryView receipt type
old/new MemoryView ids
IOTLB completion placeholder
outstanding DMA drain placeholder
no dma_map, no iommu_unmap, no page owner transfer
```

Forbidden claim:

```text
Linux dma_map/unmap, VFIO/iommufd unmap callback, iommu_unmap_fast, queued
flush, page unpin, XSK pool unmap, or page_pool recycle is not DMA receipt.
```

### IrqRouteReceipt

Authority meaning:

```text
interrupt delivery is routed only to the owning Domain/service endpoint, and old
routes cannot deliver after revoke or reassignment
```

Observation-only probes:

```text
MSI/MSI-X vector allocation/free
request_irq/free_irq
VFIO eventfd attach/detach
iommufd isolated-MSI setup
IRTE or architecture route updates
interrupt-entry-cache flush
posted interrupt teardown
queue vector remap paths
```

Inert stub shape:

```text
IRQ route receipt type
route tag
route epoch
delivery endpoint id
no request_irq, no free_irq, no vector write
```

Forbidden claim:

```text
vector id range check, request_irq, free_irq, pci_free_irq_vectors, eventfd
detach, or IRTE clear without flush is not IRQ route receipt.
```

### LedgerRootReceipt

Authority meaning:

```text
descriptor publication, doorbell, in-flight DMA, completion settlement, and
stale-completion quarantine share a typed ledger root for this queue epoch
```

Observation-only probes:

```text
descriptor write points
tail doorbell writes
NAPI poll completion paths
IRQ completion paths
XSK CQ submit/free-list return
page_pool return/recycle
driver tracepoints
```

Inert stub shape:

```text
SubmitLedger id
DescriptorLedger id
CompletionSettlement id
queue epoch
submit class
no descriptor write, no doorbell, no completion delivery
```

Forbidden claim:

```text
driver ring index, tracepoint visibility, current worker task, last submitter,
or NAPI poll context is not ledger authority.
```

### Typed Endpoint Carriers

Authority meaning:

```text
target Domains receive operation-specific endpoint authority, not raw PF/VF,
IOMMU, MSI, devlink, switchdev, or lower_dev authority
```

Required carrier classes:

```text
QueueSubmitEndpoint
DescriptorLedgerEndpoint
CompletionEndpoint
VFMailboxEndpoint
QueueConfigEndpoint
QueueEnableEndpoint
IrqRouteEndpoint
QueueBudgetEndpoint
QueueControlEndpoint
RepresentorForwardEndpoint
OffloadEndpoint
PtpControlEndpoint
DpllControlEndpoint
ServiceWorkCarrier
BudgetTicket
```

Observation-only probes:

```text
virtchnl message dispatch and handler selection
queue config and queue enable paths
IRQ map paths
bandwidth/quanta programming paths
FDIR/TC/switchdev offload install/delete/complete paths
representor transmit and lower_dev rebinding paths
PTP/DPLL/GNSS control workers
service-task coalescing and reset/replay loops
```

Inert stub shape:

```text
frozen request/carrier structures
explicit operation class
caller Domain id and epoch fields
service Domain id and epoch fields
budget placeholder
no hardware programming and no return-value change
```

Forbidden claim:

```text
virtchnl validation, opcode allowlist, devlink object reachability, bridge/FDB
policy, switchdev mark, representor netdev reachability, service worker
identity, or PTP/DPLL callback reachability is not typed endpoint authority.
```

### Revoke And Handoff Receipts

Authority meaning:

```text
old queue, DMA, IRQ, offload, mailbox, service replay, and packet-memory effects
are settled before reuse by a new Domain or epoch
```

Observation-only probes:

```text
queue disable and drain paths
reset/VFLR completion paths
FDIR ctx_irq/ctx_done clear paths
TC/offload stale-rule removal paths
XSK/page-pool quarantine-like settlement paths
DMA/IOMMU invalidation paths
IRQ route invalidation paths
mailbox embargo/reopen paths
```

Inert stub shape:

```text
QueueRevokeReceipt placeholder
NewVfEpochReceipt placeholder
stale completion quarantine marker
generation reset placeholder
no page return, no queue reassignment, no mailbox reopen
```

Forbidden claim:

```text
netdev down, reset completion, ring cleanup, FDIR ctx_done clear, representor
stop, service work completion, mailbox counter reset, or packet free is not
revoke/handoff safety.
```

## Observation-Only Patch Rules

Any future Linux probe/stub patch for this gate must obey:

```text
CONFIG_CAPSCHED gated
no user ABI
no new public tracepoint ABI unless separately approved
no changed return values
no queue rejection
no queue enable/disable behavior change
no DMA map/unmap behavior change
no IRQ allocation/free behavior change
no netdev/devlink/VFIO/iommufd semantic change
no scheduler behavior change
no monitor security claim
```

Allowed shape:

```text
static keys or disabled-by-default counters for observation
compile-only opaque structs and enums
trace-only source anchors through existing ftrace/kprobe where possible
machine-readable readiness rows with:
  observation_only=true
  authority_claim=false
  monitor_verified=false
  behavior_change=false
```

Disallowed names in Linux probe/stub code:

```text
authorize
enforce
grant
validate_token
activate_monitor
mint_receipt
security_boundary
```

Those words are reserved for future gates where a real monitor exists.

## Gate Exit Criteria

N-089 does not approve behavior-changing enforcement. It exits only when:

```text
1. every required receipt/carrier row has an observation surface
2. every row has a forbidden-shortcut statement
3. every proposed stub is inert and has no hardware/user-visible effect
4. a finite model rejects behavior-changing approval before gate satisfaction
5. the assurance case records the gate as readiness evidence only
6. the next Linux action is still observation or inert type scaffolding
```

After this gate, a future task may propose an observation-only Linux patch or a
more precise no-code trace runner. It still may not claim protection.
