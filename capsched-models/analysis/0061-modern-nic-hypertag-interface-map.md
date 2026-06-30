# Analysis 0061: Modern NIC HyperTag Interface and Service Domain Split

Status: Draft architecture map with model gate

Date: 2026-06-30

Related artifacts:

```text
analysis/0052-ice-modern-nic-queuelease-source-map.md
analysis/0053-ice-modern-nic-revoke-source-map.md
analysis/0054-monitor-irq-route-invalidation-source-map.md
analysis/0055-monitor-dma-iommu-memoryview-invalidation-source-map.md
analysis/0056-xsk-pagepool-quarantine-source-map.md
analysis/0057-representor-lower-queuelease-source-map.md
analysis/0058-ice-servicework-carrier-source-map.md
analysis/0059-ice-vf-mailbox-carrier-source-map.md
analysis/0060-ice-vf-epoch-handoff-source-map.md
assurance/0002-modern-nic-queuelease-assurance-map.md
```

## Purpose

N-088 projects the modern NIC QueueLease evidence into the production
CapSched-H architecture:

```text
HyperTag Monitor roots
  +
Linux service/driver Domain authority
  +
typed endpoints exposed to target Domains
```

The question is:

```text
Which parts of modern NIC authority must be non-forgeable below Linux, which
parts can remain Linux service/driver policy, and which typed endpoints should
target Domains receive?
```

This is intentionally not a behavior-changing implementation plan. It is the
gate that prevents a later prototype from replacing monitor-owned roots with
Linux driver state, or from turning a PF service driver into a new ambient
hypervisor.

## Core Rule

For CapSched-H:

```text
service driver policy != monitor receipt
Linux object lifetime != device ownership
VF mailbox validity != Domain request authority
IOMMU unmap call != DMA revoke receipt
IRQ teardown call != IRQ route revoke receipt
queue id/vector id/VSI id != QueueLease identity
representor netdev/lower_dev != lower QueueLease
reset completion != fresh epoch handoff
cluster lease text != local monitor authority
```

The safe shape is:

```text
NIC Domain effect =
  local monitor-owned device root
  intersect local monitor-compiled Domain/VF/QueueLease epoch
  intersect service-domain policy approval
  intersect operation-specific typed endpoint carrier
  intersect DMA MemoryView/IOMMU receipt if DMA memory is touched
  intersect IRQ route receipt if event delivery is armed
  intersect queue/service budget
  intersect revoke/handoff freshness constraints
```

The monitor should not become a full NIC driver or virtchnl parser. It owns the
small roots that Linux must not forge. Linux service Domains keep the large
driver, firmware, devlink, switchdev, mailbox, and reset machinery.

## Production Roles

### HyperTag Monitor

The monitor owns only the security roots:

```text
Domain registry and Domain epochs
MemoryView and PageOwner roots
device DMA root: RID/PASID/IOMMU domain ownership
QueueTag and QueueLease epochs
IRQ route tags and route epochs
VF/SF/queue binding epochs
root CPU and service budget roots
sealed RunToken / QueueToken / RouteToken / MemoryReceipt keys
immutable audit root for root transitions and receipts
```

Monitor-owned does not mean monitor-parsed full driver semantics. It means:

```text
Linux cannot forge, roll back, or reuse these roots.
```

### Linux Service/Driver Domain

The service/driver Domain keeps Linux compatibility and driver complexity:

```text
PF driver and firmware AdminQ/MailboxQ logic
virtchnl/VF mailbox parsing and syntax validation
netdev/NAPI/ring/q_vector lifecycle
devlink, TC, switchdev, bridge, representor policy front-ends
PTP/DPLL/GNSS and device control-plane workers
reset/rebuild/service replay logic
hardware programming substrate for queue, IRQ, DMA, and offload registers
```

The service Domain can request monitor operations. It cannot mint monitor
receipts. A compromised service Domain is in the TCB for the device service
surface, but it must not be able to silently transfer ownership across target
Domains without monitor receipt checks.

### Target Domain

Target Domains receive typed endpoints, not raw PF authority:

```text
QueueSubmitEndpoint
  submit to a specific queue lease and submit class: SKB, XDP frame, XDP_TX
  page-pool, and AF_XDP are separate classes

DescriptorLedgerEndpoint
  descriptor publication, in-flight DMA, and doorbell publication tied to a
  submit class and queue epoch

CompletionEndpoint
  NAPI/IRQ/service completion settlement and stale-completion quarantine

VFMailboxEndpoint
  request attenuated VF operations through a frozen request carrier

QueueConfigEndpoint / QueueEnableEndpoint / IrqRouteEndpoint /
QueueBudgetEndpoint
  compatibility-shaped queue/DMA/IRQ/rate operations with explicit carriers

QueueControlEndpoint
  optional, policy-controlled control for queue lifecycle/rate changes

RepresentorForwardEndpoint
  representor ingress with derived lower QueueLease, not raw lower_dev

OffloadEndpoint
  TC/FDIR-like offload requests with rule generation and destination lease

PtpControlEndpoint / DpllControlEndpoint / telemetry endpoints
  optional caller-visible device controls, each with caller carrier and service
  budget
```

Target Domains do not receive:

```text
raw PF driver handle
raw IOMMU domain handle
raw MSI/MSI-X route handle
raw lower_dev authority
ambient devlink/switchdev authority
monitor receipt minting authority
```

### Root Management Domain

The root management Domain performs policy and admission:

```text
tenant/service/device placement policy
Domain-to-device admission
service Domain selection
initial queue/VF/SF allocation policy
cluster lease signing and revocation policy
```

It is not on the packet data path.

## Minimal Monitor Calls

Names are illustrative; the semantic obligations are the point.

### Device root registration

```text
monitor_device_register(service_domain, rid, pasid_or_none, iommu_domain)
  -> DeviceRootReceipt
```

Required facts:

```text
the monitor owns or mediates the device DMA root
the PF/VF/SF identity is tied to a service Domain
Linux cannot later move the device into an untracked DMA domain
```

Forbidden shortcuts:

```text
PCI enumeration, netdev registration, driver probe success, or VFIO group
ownership is not DeviceRootReceipt.
```

### Local lease compilation

```text
monitor_compile_cluster_lease(cluster_lease, node, service_domain)
  -> LocalDomainDeviceLease
```

Required facts:

```text
cluster authority has been admitted locally
local Domain epoch, MemoryView, device root, and budget are bound
remote lease text cannot be used directly on a NIC queue
```

Forbidden shortcuts:

```text
signed cluster policy or scheduler placement is not local queue authority until
compiled into local monitor roots.
```

### VF/SF binding epoch

```text
monitor_bind_vf(local_lease, pf_id, vf_id, service_domain, target_domain)
  -> VfEpochReceipt
```

Required facts:

```text
visible vf_id maps to exactly one fresh Domain binding epoch
old mailbox and queue carriers for that vf_id are invalid
service Domain cannot reopen the VF by clearing Linux DIS/ACTIVE bits alone
```

Forbidden shortcuts:

```text
ice_get_vf_by_id(), ice_vf pointer reachability, cfg_lock, ACTIVE/DIS state, or
VSI index stability is not VfEpochReceipt.
```

### QueueLease creation

```text
monitor_queue_lease_create(vf_epoch, queue_ids, budget, cotype_policy)
  -> QueueLeaseReceipt
```

Required facts:

```text
QueueTag and queue epoch are monitor-owned
queue budget/rate root is monitor-owned or tied to a monitor root
service policy narrows but cannot mint the QueueLease root
```

Forbidden shortcuts:

```text
ring pointer, q_vector, NAPI, queue_mapping, VF queue id, VPLAN queue base, or
devlink queue state is not QueueLeaseReceipt.
```

### DMA ring and packet memory validation

```text
monitor_dma_bind(queue_lease, memoryview, dma_region_digest, access_class)
  -> DmaMemoryViewReceipt
```

Required facts:

```text
descriptor ring and DMA buffers are inside the target Domain MemoryView or an
explicit shared service buffer
old IOMMU/device translations for the previous epoch cannot reach the memory
receipt binds queue epoch, MemoryView epoch, device root, and access class
```

Forbidden shortcuts:

```text
VF-provided dma_ring_addr, Linux dma_map_*(), VFIO/iommufd unmap callback,
iommu_unmap_fast(), queued flush, page unpin, xsk_pool_dma_unmap(), or
page_pool recycle is not DmaMemoryViewReceipt.
```

### IRQ route binding

```text
monitor_irq_route_bind(queue_lease, vector_digest, delivery_endpoint)
  -> IrqRouteReceipt
```

Required facts:

```text
event delivery endpoint is bound to the target Domain
route epoch is monitor-owned
interrupt remapping or isolated MSI state is tracked
posted interrupt and eventfd-like state cannot outlive revoke
```

Forbidden shortcuts:

```text
vector id range check, request_irq(), free_irq(), pci_free_irq_vectors(),
eventfd detach, or IRTE clear without flush is not IrqRouteReceipt.
```

### Queue activation

```text
monitor_queue_activate(queue_lease, queue_config_digest,
                       dma_receipt, irq_receipt, service_policy_digest)
  -> QueueActivationReceipt
```

Required facts:

```text
service Domain policy and syntax validation are present
DMA and IRQ receipts match the same queue epoch
queue config digest prevents Linux from swapping staged config after receipt
```

Forbidden shortcuts:

```text
queue enable, QS_ENA bit, virtchnl validation, opcode allowlist, or hardware
queue context write is not QueueActivationReceipt.
```

### Ledger root binding

```text
monitor_ledger_root_bind(queue_lease, submit_class, descriptor_policy_digest)
  -> LedgerRootReceipt
```

Required facts:

```text
submit class is fixed before data-plane use
descriptor publication and completion settlement can be correlated to the
QueueLease epoch
normal packet submission does not require a monitor trap per descriptor
```

Forbidden shortcuts:

```text
driver ring index, tracepoint visibility, current worker task, or last submitter
is not DescriptorLedger or CompletionSettlement authority.
```

### Offload and representor binding

```text
monitor_offload_rule_bind(queue_lease, offload_cap, rule_digest, dest_digest)
  -> OffloadRuleReceipt

monitor_representor_lower_bind(representor_endpoint, lower_queue_lease,
                               metadata_generation)
  -> LowerQueueLeaseReceipt
```

Required facts:

```text
hardware offload destinations are bound to fresh queue epochs
representor lower_dev and metadata_dst are policy inputs, not authority roots
stale offload rules are removed or quarantined on lower QueueLease revoke
```

Forbidden shortcuts:

```text
bridge FDB hit, VLAN allow, TC redirect target, metadata_dst, switchdev mark,
or LAG lower_dev rewrite is not lower QueueLease authority.
```

### Revoke and handoff

```text
monitor_queue_revoke(queue_lease)
  -> QueueRevokeReceipt

monitor_vf_epoch_bump(vf_epoch, queue_revoke_receipts,
                      dma_receipts, irq_receipts, async_context_receipts)
  -> NewVfEpochReceipt
```

Required facts:

```text
new submit and mailbox effects are embargoed
queue is quiesced and no old doorbell/descriptor publication can create work
DMA/IOMMU old reachability is gone or affected pages are quarantined
IRQ route old delivery is gone or completions are quarantined
FDIR/offload async completions are cleared or epoch-tagged
service replay is reauthorized under the new epoch
```

Forbidden shortcuts:

```text
netdev down, reset completion, representor stop, FDIR ctx_done clear, service
worker completion, or mailbox counter reset alone is not QueueRevokeReceipt or
NewVfEpochReceipt.
```

## Data Plane Efficiency Rule

The data path must not trap to the monitor per packet.

Safe fast path:

```text
1. Monitor establishes QueueLease, DMA, IRQ, budget, and endpoint receipts.
2. Monitor establishes typed ledger roots for the allowed submit classes.
3. Service Domain programs hardware according to those receipts.
4. Target Domain submits descriptors to its leased queue.
5. IOMMU/MemoryView and queue ownership limit damage if Linux or the target
   Domain is compromised.
6. Monitor is re-entered for bind, config, revoke, epoch bump, budget root
   changes, or queue ownership changes, not ordinary packet submission.
```

This is the cost-efficiency claim path:

```text
hypervisor-like isolation root
without per-VM guest kernel duplication
without virtio/emulated data path for direct-queue workloads
```

## Minimal TCB Rule

The monitor should accept small digests and receipts, not full Linux objects:

```text
stable ids:
  Domain id, service Domain id, PF/VF/SF id, QueueTag, RouteTag, MemoryView id

epochs:
  Domain epoch, VF epoch, queue epoch, route epoch, MemoryView epoch, rule
  generation

digests:
  queue config digest, DMA region digest, IRQ route digest, service policy
  digest, offload rule digest

receipts:
  DeviceRootReceipt, LocalDomainDeviceLease, VfEpochReceipt,
  QueueLeaseReceipt, DmaMemoryViewReceipt, IrqRouteReceipt,
  QueueActivationReceipt, LedgerRootReceipt, QueueRevokeReceipt,
  NewVfEpochReceipt
```

The monitor should not parse:

```text
full virtchnl protocol
full TC flower syntax
full devlink policy
full driver ring data structures
full bridge/VLAN/FDB policy
full packet contents
```

Those remain service Domain policy inputs. The monitor verifies that the final
effect is within non-forgeable roots.

## Confused-Deputy Hotspots

The highest-risk paths are:

```text
VF mailbox:
  syntax-valid virtchnl request treated as authority.

Descriptor/completion ledger:
  ring index, tracepoint, worker identity, or last submitter used instead of a
  typed ledger root and settlement rule.

Reset/rebuild replay:
  service Domain reprograms queues after revoke using stale policy or old
  Epoch.

FDIR/offload completion:
  ctx_done or async worker completion delivered after VF epoch bump.

Representor forwarding:
  lower_dev or metadata_dst changes without fresh lower QueueLease.

TC/switchdev offload:
  stale hardware destination survives lower QueueLease revoke.

DMA page return:
  XSK/page-pool returns memory before DMA/IOMMU receipt and generation reset.

IRQ delivery:
  eventfd/posting/MSI route continues after queue/VF revoke.

Cluster migration:
  signed remote lease used directly instead of compiled into local monitor
  roots.
```

## Non-Goals

N-088 does not require:

```text
generic VM emulation
monitor parsing of full driver protocols
per-packet monitor entry
complete NIC hardware implementation
behavior-changing Linux enforcement
```

It does require that any future behavior-changing plan name which monitor
receipt and which service-domain carrier is consumed by each effect.

## Design Consequence

The next implementation plan must be rejected if it:

```text
collapses monitor receipts into Linux driver state
lets service Domain mint QueueLease/DMA/IRQ/VF epoch receipts
lets target Domains see raw PF/VF/IOMMU/MSI/devlink authority
uses remote cluster lease text directly on a queue
reopens a VF or queue after reset without fresh monitor epoch
activates queue data path without matching DMA and IRQ receipts
claims production security from Linux-only trace/build evidence
```

The acceptable production split is:

```text
HyperTag Monitor:
  owns roots and receipts

Linux service/driver Domain:
  owns policy parsing, driver complexity, and hardware programming substrate

Target Domain:
  owns typed endpoints and direct data-plane queues within monitor leases

Root/cluster management:
  owns admission and remote-to-local lease compilation policy
```
