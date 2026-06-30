# Assurance 0002: Modern NIC QueueLease Subclaim Map

Status: Active consolidation, no implementation approved

Date: 2026-06-30

Parent claim:

```text
DEV-001:
Device queue ownership, allowed DMA memory, interrupt route, epoch, and
queue-specific budget/rate limit are one monitor-owned QueueLease boundary.
```

## Purpose

This note consolidates the modern NIC evidence chain into an assurance map.

The important separation is:

```text
model-checked constraints:
  what the authority semantics require in finite TLA+ models

source-observed anchors:
  where Linux/ice appears to have the relevant queue, DMA, completion, control,
  representor, and service paths

observation-only readiness:
  whether existing tracepoints/source anchors are visible enough to study

protection-missing roots:
  what is still absent for a monitor-backed security claim

forbidden implementation claims:
  shortcuts that would create a false sense of hypervisor-grade isolation
```

This is not a QueueLease implementation plan. It is the gate that prevents the
implementation plan from collapsing distinct authority classes into "the NIC
queue" or "the driver callback".

## Related Evidence

Model-checked evidence:

```text
formal/0028-modern-nic-queuelease-model/
validation/0046-modern-nic-queuelease-tlc.md

formal/0029-xdp-afxdp-memory-ownership-model/
validation/0048-xdp-afxdp-memory-ownership-tlc.md

formal/0030-queuecontrol-representor-model/
validation/0049-queuecontrol-representor-tlc.md

formal/0031-modern-nic-queue-revoke-model/
validation/0050-modern-nic-queue-revoke-tlc.md

formal/0032-vf-irq-revoke-ownership-model/
validation/0052-vf-irq-revoke-ownership-tlc.md

formal/0033-monitor-irq-route-invalidation-model/
validation/0053-monitor-irq-route-invalidation-tlc.md

formal/0034-monitor-dma-iommu-invalidation-model/
validation/0054-monitor-dma-iommu-invalidation-tlc.md

formal/0035-xsk-pagepool-quarantine-model/
validation/0055-xsk-pagepool-quarantine-tlc.md

formal/0036-representor-lower-queuelease-model/
validation/0056-representor-lower-queuelease-tlc.md

formal/0037-modern-nic-servicework-carrier-model/
validation/0057-modern-nic-servicework-carrier-tlc.md

formal/0038-vf-mailbox-carrier-model/
validation/0058-vf-mailbox-carrier-tlc.md

formal/0039-vf-epoch-handoff-model/
validation/0059-vf-epoch-handoff-tlc.md

formal/0040-modern-nic-hypertag-split-model/
validation/0060-modern-nic-hypertag-split-tlc.md

formal/0041-modern-nic-readiness-gate-model/
validation/0061-modern-nic-readiness-gate-tlc.md

formal/0042-local-domain-device-lease-model/
validation/0063-local-domain-device-lease-tlc.md

formal/0043-local-domain-device-lease-admission-model/
validation/0065-local-domain-device-lease-admission-tlc.md

formal/0044-local-monitor-admission-interface-model/
validation/0066-local-monitor-admission-interface-tlc.md

formal/0045-monitor-admission-carrier-storage-model/
validation/0067-monitor-admission-carrier-storage-tlc.md

formal/0046-local-monitor-admission-abi-model/
validation/0068-local-monitor-admission-abi-tlc.md

formal/0047-monitor-admission-carrier-sketch-model/
validation/0069-monitor-admission-carrier-sketch-tlc.md

formal/0048-direct-call-reference-abi-model/
validation/0070-direct-call-reference-abi-tlc.md
```

Source-observed and readiness evidence:

```text
analysis/0049-e1000e-queuelease-source-map.md
analysis/0050-aggregate-queuelease-settlement-semantics.md
analysis/0051-linux-queue-descriptor-ledger-observation-plan.md
analysis/0052-ice-modern-nic-queuelease-source-map.md
analysis/0053-ice-modern-nic-revoke-source-map.md
analysis/0055-monitor-dma-iommu-memoryview-invalidation-source-map.md
analysis/0056-xsk-pagepool-quarantine-source-map.md
analysis/0057-representor-lower-queuelease-source-map.md
analysis/0058-ice-servicework-carrier-source-map.md
analysis/0059-ice-vf-mailbox-carrier-source-map.md
analysis/0060-ice-vf-epoch-handoff-source-map.md
analysis/0061-modern-nic-hypertag-interface-map.md
analysis/0062-modern-nic-hypertag-readiness-probe-map.md
analysis/0063-modern-nic-hypertag-observation-ledger.md
analysis/0064-local-domain-device-lease-compilation.md
analysis/0065-local-domain-device-lease-observation-contract.md
analysis/0066-local-domain-device-lease-admission-protocol.md
analysis/0067-local-monitor-admission-interface-boundary.md
analysis/0068-local-monitor-admission-carrier-storage.md
analysis/0069-local-monitor-admission-abi-semantics.md
analysis/0070-local-monitor-admission-carrier-sketch-comparison.md
analysis/0071-direct-call-reference-abi-sketch.md
analysis/ice-modern-nic-queuelease-source-map-v1.json
analysis/ice-modern-nic-revoke-source-map-v1.json
analysis/monitor-dma-iommu-memoryview-invalidation-source-map-v1.json
analysis/xsk-pagepool-quarantine-source-map-v1.json
analysis/representor-lower-queuelease-source-map-v1.json
analysis/ice-servicework-carrier-source-map-v1.json
analysis/ice-vf-mailbox-carrier-source-map-v1.json
analysis/ice-vf-epoch-handoff-source-map-v1.json
analysis/modern-nic-hypertag-interface-map-v1.json
analysis/modern-nic-hypertag-readiness-probe-map-v1.json
analysis/modern-nic-hypertag-observation-ledger-v1.json
analysis/local-domain-device-lease-compilation-v1.json
analysis/local-domain-device-lease-observation-contract-v1.json
analysis/local-domain-device-lease-admission-protocol-v1.json
analysis/local-monitor-admission-interface-boundary-v1.json
analysis/local-monitor-admission-carrier-storage-v1.json
analysis/local-monitor-admission-abi-semantics-v0.json
analysis/local-monitor-admission-carrier-sketch-comparison-v1.json
analysis/direct-call-reference-abi-sketch-v1.json
validation/0045-queue-descriptor-ledger-observation-plan.md
validation/0047-ice-modern-nic-readiness-result.md
validation/0051-ice-revoke-readiness-result.md
validation/0062-modern-nic-hypertag-observation-ledger-result.md
validation/0064-local-domain-device-lease-observation-contract-result.md
validation/0065-local-domain-device-lease-admission-tlc.md
validation/0066-local-monitor-admission-interface-tlc.md
validation/0067-monitor-admission-carrier-storage-tlc.md
validation/0068-local-monitor-admission-abi-tlc.md
validation/0069-monitor-admission-carrier-sketch-tlc.md
validation/0070-direct-call-reference-abi-tlc.md

implementation/0007-modern-nic-hypertag-readiness-gate.md
validation/run-modern-nic-hypertag-observation-ledger.sh
validation/run-local-domain-device-lease-observation-contract.sh
```

Top-level assurance evidence:

```text
assurance/0001-hypervisor-grade-domain-separation-case.md
assurance/claims.json
```

## Core Finding

Modern NIC authority is not one object.

The first safe decomposition is:

```text
QueueBind:
  live queue identity, ring, q_vector, NAPI, IRQ route, epoch, and queue budget

SubmitLedgerSKB:
  SKB/frags submit with DMA/IOMMU authority

SubmitLedgerXDPFrame:
  ordinary XDP frame transmit

SubmitLedgerXDPTxPagePool:
  XDP_TX page-pool reuse with page-pool ownership

SubmitLedgerAFXDP:
  AF_XDP zero-copy submit with XSK/UMEM ownership and frozen descriptors

DescriptorLedger:
  descriptor write, next_to_watch, in-flight DMA, and tail doorbell publication

CompletionSettlement:
  NAPI/IRQ/service completion against a typed ledger and service budget

QueueControl:
  devlink/rate/scheduler/VF/SF/representor lifecycle authority

RepresentorForward:
  representor ingress authority plus live lower QueueLease derivation,
  metadata generation, lower_dev binding, bridge/FDB/VLAN policy input, and
  LAG rebind proof

ServiceWork:
  reset, PTP, DPLL, eswitch, LAG, DIM, firmware, and maintenance authority

RevokeSemantics:
  epoch change, queue drain/quarantine, DMA/IRQ invalidation, and stale work
  cancellation

VfEpochHandoff:
  visible VF id, VSI index, queue id, vector id, mailbox generation, FDIR
  context, and service replay are reopened only after fresh VF/Domain/queue
  epochs and monitor receipts

HyperTagSplit:
  monitor mints roots and receipts, Linux service Domains parse policy and
  program hardware only after receipts, target Domains receive typed endpoints,
  and ordinary packet submission does not trap to the monitor per packet

ReadinessGate:
  every required receipt/carrier maps to observation-only probes or inert stubs;
  probes and stubs are not authority, do not change behavior, do not expose raw
  endpoints, and do not justify protection claims

LocalDomainDeviceLease:
  root-management ClusterLease, scheduler placement, service Domain admission,
  and Linux device registration are not local queue authority. The local
  HyperTag Monitor must compile a node-local device lease before any
  DeviceRoot, VF epoch, QueueLease, DMA, IRQ, ledger, or typed endpoint receipt
  can be minted.

LocalDomainDeviceLeaseObservationContract:
  a future root-management/local monitor ledger must preserve separate rows for
  cluster lease issue, node receive, cluster check, service admission,
  device-root binding, target epoch/budget check, local lease compile, receipt
  request, endpoint delivery, and revoke. The contract remains
  observation_only=true, authority_claim=false, monitor_verified=false,
  behavior_change=false, and protection_claim=false until a real monitor
  exists.

LocalDomainDeviceLeaseAdmission:
  admission failures are terminal for that attempt; local lease compile requires
  checked cluster lease, matching service Domain, monitor-owned device root,
  matching target Domain, target epoch/root budget, and local monitor compile.
  Revoke requires new receipt embargo, derived receipt revoke, and local lease
  revoke completion before reuse.

LocalMonitorAdmissionInterface:
  Linux service Domains may carry requests but cannot mint monitor responses.
  Monitor responses reject replay/stale state, failure receipts terminate the
  attempt, device receipts require a monitor-minted local lease response, typed
  endpoints require monitor-minted device receipts, revoke completion requires
  derived receipt revoke, and raw service-domain handles must not escape.

MonitorAdmissionCarrierStorage:
  request carriers transport intent but are not receipt authority. Direct
  monitor calls are the correctness baseline, monitor-owned shared rings are a
  throughput extension only with monitor-owned slot freshness, Linux
  service-domain queues are request-only, Linux-visible shadows are
  non-authoritative caches, monitor receipt ledgers are the authority root,
  audit-only logs are not runtime authority, and raw driver handles are not
  target Domain endpoints.

LocalMonitorAdmissionABI:
  `LocalMonitorAdmissionABI-v0` is a semantic candidate, not a binary ABI.
  Typed request classes, monitor-owned responses, monitor-owned receipt ledger
  writes, monitor-owned replay windows, non-authoritative Linux shadows,
  terminal failure, and ordered revoke with shadow invalidation are required
  before any carrier or code layout can be selected.

MonitorAdmissionCarrierSketch:
  direct-call-first is the small reference semantic sketch and
  monitor-owned-ring-first is the throughput refinement direction. The ring
  path must add monitor slot claims, slot epochs, batch epoch stability, pending
  response drain, and DoS accounting; it must not replace monitor authority with
  ring state.

DirectCallReferenceABI:
  direct-call reference semantics require monitor entry, monitor-owned
  request copy/freeze before validation, replay-window consume before success
  ledger write, monitor-owned response handle minting, non-authoritative Linux
  shadow refresh from handle/ledger state, terminal failure for the same
  attempt, and revoke completion only after embargo, in-flight direct call
  drain, derived receipt revoke, and shadow invalidation.
```

The `ice` source map gives useful Linux anchors for each of these classes. It
does not make any of them non-forgeable. Every observed readiness row remains:

```text
observation_only=true
authority_claim=false
monitor_verified=false
```

## Internal Redesign Boundary

Deep internal redesign is allowed and probably necessary for production
CapSched-H.

It is not sufficient by itself.

Even if Linux driver internals, workqueues, NAPI ownership, descriptor
publication, and service tasks are redesigned, the proof-visible boundary must
still preserve:

```text
Domain id
Domain epoch
QueueTag
QueueLease epoch
MemoryView/IOMMU ownership
typed submit class
DescriptorLedger id
CompletionSettlement id
QueueControlCap or RepresentorForwardCap where applicable
service-domain authority
BudgetTicket or service budget rule
revoke/quarantine outcome
```

Otherwise, "internal only" becomes ambient authority. In this threat model,
ambient internal authority is exactly what a Domain-local kernel compromise can
abuse.

## Subclaim Map

### DEV-NIC-001: Queue Identity and Binding

Claim:

```text
A queue effect is bound to a live QueueTag, queue epoch, ring, q_vector, NAPI
instance, IRQ route, and queue budget before descriptor or completion effects
are accepted.
```

Current status: Model-supported plus source-observed

Evidence:

```text
Model:
  formal/0028, validation/0046

Source:
  analysis/0052 maps ice_vsi, ice_q_vector, ring arrays, netif_napi_add_config,
  q_vector IRQ allocation, and ring-to-vector binding.

Readiness:
  validation/0047 classifies QueueBind as partially_ready.
```

Protection missing:

```text
no monitor QueueTag
no queue epoch emitted or checked
no non-forgeable IRQ route ownership
no queue budget root below Linux
```

Forbidden claim:

```text
Do not treat netdev, queue_mapping, ring pointer, q_vector pointer, or NAPI
reachability as QueueLease authority.
```

### DEV-NIC-002: Typed Submit Classes

Claim:

```text
SKB, XDP frame, XDP_TX page-pool, and AF_XDP zero-copy submit paths are
different authority classes even when they touch the same lower ring.
```

Current status: Model-supported plus source-observed

Evidence:

```text
Model:
  formal/0028, validation/0046
  formal/0029, validation/0048

Source:
  analysis/0052 maps ice_start_xmit(), ice_tx_map(),
  __ice_xmit_xdp_ring(), page_pool_get_dma_addr(), ice_xmit_zc(),
  xsk_tx_peek_release_desc_batch(), and ice_xsk_wakeup().

Readiness:
  validation/0047 records SKB as partial_gap_recorded and XDP/AF_XDP classes
  as source_only_gap_recorded.
```

Protection missing:

```text
no typed SubmitLedger id
no Domain/epoch correlation on submitted packet memory
no frozen XDP or AF_XDP descriptor authority
no monitor-backed XSK/UMEM ownership
```

Forbidden claim:

```text
Do not authorize XDP_TX or AF_XDP zero-copy by SKB authority, generic netdev
reachability, generic XDP reachability, or ambient driver worker state.
```

### DEV-NIC-003: Descriptor Publication and Doorbell

Claim:

```text
Descriptor writes, next_to_watch publication, in-flight DMA state, and tail
doorbell writes consume a typed DescriptorLedger that matches the submit class.
```

Current status: Model-supported plus source-observed

Evidence:

```text
Model:
  formal/0028, validation/0046

Source:
  analysis/0052 maps ice_tx_map() descriptor field writes, next_to_watch,
  next_to_use update, __netdev_tx_sent_queue(), and writel_relaxed(tail).

Readiness:
  validation/0047 classifies DescriptorLedger as partial_gap_recorded.
```

Protection missing:

```text
no typed DescriptorLedger emitted
no monitor-visible descriptor publication event
no descriptor-to-DMA-to-doorbell correlation
no stale descriptor quarantine after revoke
```

Forbidden claim:

```text
Do not treat an ice tracepoint or a Linux ring index as the ledger itself.
```

### DEV-NIC-004: DMA Packet Memory Ownership

Claim:

```text
DMA-capable packet memory is authorized by MemoryView/IOMMU ownership and
class-specific memory authority, not by queue reachability alone.
```

Current status: Model-supported plus source-observed

Evidence:

```text
Model:
  formal/0029, validation/0048
  formal/0034, validation/0054
  formal/0035, validation/0055
  formal/0038, validation/0058
  formal/0039, validation/0059
  formal/0039, validation/0059

Source:
  analysis/0052 maps dma_map_single(), skb_frag_dma_map(),
  page_pool_get_dma_addr(), dma_sync_single_for_device(), xsk_pool, and
  AF_XDP descriptor batch fetch.
  analysis/0055 maps ice teardown, DMA API, IOMMU core, iommufd, VFIO type1,
  and arch-IOMMU invalidation anchors for revoke ordering.
  analysis/0056 maps XSK completion, XSK free-list return, page-pool recycle,
  and packet generation reset hazards.
  analysis/0059 maps VF-provided descriptor-ring DMA address configuration
  through ice virtchnl queue config into Tx/Rx hardware queue contexts.
  analysis/0060 maps VF reset/reassignment handoff paths where stale DMA,
  queue, IRQ, and VSI state could otherwise cross into a new Domain binding.

Readiness:
  validation/0047 records page-pool-ownership and xsk-ownership as high
  severity gaps.
```

Protection missing:

```text
no monitor-backed MemoryView for packet pages
no IOMMU ownership root below Linux
no page-pool ownership provenance
no XSK/UMEM ownership provenance
no real monitor-backed DMA invalidation receipt implementation
no real IOMMU invalidation latency/order proof
no real stale XSK/page-pool quarantine implementation
no packet generation reset/retag implementation
no VF mailbox QueueConfigCarrier or DMA ring-address carrier implementation
no VF epoch handoff DMA/IOMMU receipt implementation
```

Forbidden claim:

```text
Do not treat Linux DMA mapping success as proof that the DMA target is
Domain-authorized.
Do not treat IRQ invalidation, dma_unmap_*(), xsk_pool_dma_unmap(),
iommu_unmap_fast(), queued IOVA flush, iommufd IOAS unmap, VFIO unmap callback,
or page unpin/refcount release as PageOwner transfer safety.
Do not treat xsk_tx_completed(), xsk_buff_free(), or page_pool recycle as
safe packet memory return after revoke.
Do not treat VF-provided dma_ring_addr plus queue/ring validation as DMA
MemoryView authority.
Do not treat vf_id equality, stable VSI index, or VF reset completion as DMA
MemoryView freshness.
```

### DEV-NIC-005: Completion Settlement

Claim:

```text
NAPI/IRQ/worker completion settles a previously typed ledger under service
authority and service budget; it is not caller authority by ambient execution
context.
```

Current status: Model-supported plus source-observed

Evidence:

```text
Model:
  formal/0028, validation/0046
  formal/0029, validation/0048
  formal/0035, validation/0055

Source:
  analysis/0052 maps ice_napi_poll(), ice_clean_tx_irq(),
  ice_clean_rx_irq(), consume/free paths, and ice clean tracepoints.
  analysis/0056 maps AF_XDP CQ submission and packet-memory return paths.

Readiness:
  validation/0047 classifies CompletionSettlement as partial_gap_recorded.
```

Protection missing:

```text
no completion ledger id
no submit-class settlement correlation
no service BudgetTicket or service budget rule
no proof that completion cannot deliver after revoke
no stale XSK completion quarantine implementation
```

Forbidden claim:

```text
Do not charge completion to the last submitter, the current worker task, or the
driver service context unless an explicit settlement rule exists.
```

### DEV-NIC-006: QueueControl

Claim:

```text
Devlink rate/scheduler and VF/SF/representor lifecycle operations require
QueueControl authority and a live queue epoch. RunCap and plain netdev
reachability cannot authorize them.
```

Current status: Model-supported plus source-observed

Evidence:

```text
Model:
  formal/0028, validation/0046
  formal/0030, validation/0049
  formal/0036, validation/0056
  formal/0038, validation/0058

Source:
  analysis/0052 maps ice_devlink_tx_sched_layers_set and devlink rate/control
  anchors.
  analysis/0057 maps TC/switchdev redirect/mirror rule programming and hardware
  switch rule install/delete anchors.
  analysis/0059 maps VF mailbox queue config, queue enable, IRQ map,
  bandwidth/quanta, and FDIR operations as distinct carrier requirements.

Readiness:
  validation/0047 classifies QueueControl as source_only_gap_recorded.
```

Protection missing:

```text
no QueueControlCap
no monitor QueueTag check
no VF/SF lifecycle authority model
no devlink policy proof
no TC/switchdev OffloadCap or rule-generation proof
no VF mailbox QueueControl carrier implementation
no VF mailbox queue budget carrier implementation
```

Forbidden claim:

```text
Do not authorize queue/rate/scheduler control by RunCap, CAP_NET_ADMIN alone,
netdev reachability alone, or the fact that Linux can call devlink ops.
Do not treat TC/switchdev hardware rule installation as plain
RepresentorForward.
```

### DEV-NIC-007: RepresentorForward

Claim:

```text
Representor transmit requires RepresentorForward authority plus a live derived
lower QueueLease with a fresh lower queue epoch and service budget. Bridge FDB,
VLAN, metadata_dst, TC redirect target, and representor netdev reachability are
policy or Linux metadata inputs, not lower queue authority.
```

Current status: Model-supported plus source-observed, refined by N-084

Evidence:

```text
Model:
  formal/0028, validation/0046
  formal/0030, validation/0049
  formal/0036, validation/0056

Source:
  analysis/0052 maps representor ndo_start_xmit,
  ice_eswitch_port_start_xmit(), and lower dev_queue_xmit().
  analysis/0057 maps bridge/FDB/VLAN/switchdev, TC/BPF redirect, TC flower
  offload, and LAG lower_dev update hazards.

Readiness:
  validation/0047 classifies RepresentorForward as partial_gap_recorded.
```

Protection missing:

```text
no RepresentorForwardCap
no lower QueueLease derivation artifact
no fresh lower queue epoch check
no service budget proof
no bridge/FDB/VLAN/TC policy proof
no metadata_dst generation or lower_dev-to-QueueLease binding
no LAG lower_dev rebind proof
no TC/switchdev stale-rule invalidation receipt
```

Forbidden claim:

```text
Do not treat a representor netdev as direct authority to submit on the lower
queue.
Do not treat bridge FDB hit, VLAN allow, switchdev hwdom/offload mark, TC
redirect target, metadata_dst, or representor Tx queue stop as lower QueueLease
authority or revoke proof.
```

### DEV-NIC-008: ServiceWork and Async Provenance

Claim:

```text
Reset, PTP, DPLL, eswitch, LAG, DIM, firmware, and maintenance work execute as
service/kernel authority classes and cannot create caller-attributed effects
unless a typed carrier exists.
```

Current status: Model-supported plus source-observed

Evidence:

```text
Model:
  formal/0028, validation/0046
  formal/0017, validation/0029
  formal/0037, validation/0057
  formal/0038, validation/0058
  formal/0039, validation/0059

Source:
  analysis/0045, analysis/0046, analysis/0047, and analysis/0052 map workqueue
  pending coalescing, worker callback execution, origin taxonomy, and ice
  service/reset/eswitch/PTP anchors.
  analysis/0058 maps ice service task coalescing, reset/AdminQ/MailboxQ,
  VF virtchnl queue-control, PTP, DPLL, bridge/eswitch, LAG, and GNSS work
  as service-work carrier and per-effect authority hazards.
  analysis/0059 maps the VF mailbox request side of queue/DMA/IRQ/budget/FDIR
  effects that the service work model requires to preserve.
  analysis/0060 maps reset/rebuild replay and mailbox reopen hazards across
  VF epoch handoff.

Readiness:
  validation/0047 classifies ServiceWork as source_only_gap_recorded.
```

Protection missing:

```text
no typed service work carrier
no merge policy for coalesced work
no service/caller authority intersection
no cancellation/quarantine rule for stale queued work
no service-domain budget charging rule
no reset/rebuild replay reauthorization implementation
no frozen VF request carrier propagation into async FDIR completion
no VF epoch handoff carrier for reset/reassignment reopen
```

Forbidden claim:

```text
Do not make generic workqueue execution a CapSched authority hook. Only
Domain-derived async work should require typed carriers; kernel-internal work
must remain service/kernel classified until proved otherwise.
Do not treat worker identity, ICE_SERVICE_SCHED, virtchnl allowlists, PTP/DPLL
callback reachability, bridge/FDB events, LAG lower_dev rewrites, or reset
rebuild replay as caller, queue, control, offload, or lower QueueLease
authority.
Do not treat vf_id equality, ICE_VF_STATE_ACTIVE, ICE_VF_STATE_DIS, or
vf->cfg_lock as VF Domain authority.
```

### DEV-NIC-009: Revoke Semantics

Claim:

```text
Queue revoke invalidates submit, descriptor, doorbell, in-flight DMA,
completion, control, representor, and service work before authority can be
reused or delivered to another Domain.
```

Current status: Model-supported, source-observed reset/down anchors,
observation-only readiness with high-severity gaps

Evidence:

```text
Model:
  formal/0028, validation/0046
  formal/0029, validation/0048
  formal/0030, validation/0049
  formal/0031, validation/0050
  formal/0032, validation/0052
  formal/0033, validation/0053
  formal/0034, validation/0054
  formal/0035, validation/0055
  formal/0038, validation/0058

Source:
  analysis/0052 records reset/down/service paths as future revoke anchors.
  analysis/0053 maps formal/0031 obligations to ice down/reset/NAPI/IRQ/DMA/
  XDP/AF_XDP/representor/service anchors.
  analysis/0055 maps the DMA/IOMMU/MemoryView invalidation substrate and its
  forbidden shortcuts.
  analysis/0056 maps XSK/page-pool stale completion and packet memory return
  substrate.
  analysis/0059 maps VF mailbox queue/DMA/IRQ/budget/FDIR carrier substrate.
  analysis/0060 maps VF identity epoch, reset/reassignment, stale VSI/queue/
  IRQ/DMA/FDIR/mailbox, and service replay handoff substrate.

Readiness:
  validation/0047 classifies RevokeSemantics as not_ready_future_capsched.
  validation/0051 emits formal/0031 obligation coverage for ice revoke paths
  with tracepoint_rows=8, source_anchor_rows=31, and gap_rows=8. Every row is
  observation_only=true, authority_claim=false, and monitor_verified=false.

Refinement:
  validation/0052 models the ICE_VSI_VF synchronize_irq exception as a typed
  IRQ-ownership hazard. Safe TLC passes only when host-owned IRQ, VF-owned IRQ,
  and monitor-owned IRQ quiescence are separated before queue reassignment.
  validation/0053 models monitor-backed IRQ route invalidation across VFIO
  eventfd, Linux IRQ/MSI allocation, iommufd isolated MSI, IRTE clear, IEC
  flush, and posted interrupt state. Safe TLC passes only when a full
  invalidation receipt exists before queue reassignment.
  validation/0054 models monitor-backed DMA/IOMMU/MemoryView invalidation.
  Safe TLC passes only when monitor-owned DMA root, new-work embargo, IRQ
  invalidation, descriptor/doorbell stop, hardware queue quiescence, HW-owned
  descriptor drain, driver DMA teardown, access-user release,
  IOMMU translation removal, completed IOTLB invalidation, old device-domain/
  PASID fence, outstanding DMA drain, stale completion quarantine, and old
  MemoryView unmap are all present before PageOwner transfer, page return, or
  queue reassignment.
  validation/0059 models VF epoch handoff. Safe TLC passes only when mailbox
  embargo, queue quiescence, DMA/IRQ revoke, FDIR context clear, VF epoch bump,
  VSI/QueueLease generation bump, fresh Domain binding, and fresh service replay
  authority are present before a new Domain effect.
  validation/0060 models the modern NIC HyperTag split. Safe TLC passes only
  when local monitor lease compilation, device-root receipt, service policy, VF
  epoch receipt, QueueLease receipt, DMA receipt, IRQ receipt, ledger root
  receipt, typed endpoints, and fresh service carrier are all present before a
  data-plane effect, while ordinary packet submission avoids per-packet monitor
  traps.
  validation/0061 models the implementation-readiness gate. Safe TLC passes
  only when receipt/carrier inventory, observation probe mapping, observation-
  only probe classification, inert stubs, no raw endpoint exposure, model gate,
  and assurance linkage are all present before behavior-changing approval.
  validation/0062 emits the first modern NIC HyperTag observation ledger from
  the current Linux source tree. It records 37 rows, 36 available anchors, 1
  expected missing LocalDomainDeviceLease row, 1 high-severity gap, and 0
  safety-flag violations.
  validation/0063 models LocalDomainDeviceLease compilation. Safe TLC passes
  only when a received ClusterLease is checked for signature, epoch, and
  revocation, service Domain admission matches the lease, monitor-owned device
  root binding exists, target Domain epoch and root budget are fresh, and the
  local monitor mints the LocalDomainDeviceLease before queue/DMA/IRQ receipts.
  validation/0064 validates the LocalDomainDeviceLease observation contract.
  The runner emits 10 rows, checks 7 dependency rules, reports 0 dependency
  errors, reports 0 safety-flag violations, and preserves 9 forbidden authority
  collapses for pre-monitor planning.
  validation/0065 models LocalDomainDeviceLease admission protocol failure and
  revoke ordering. Safe TLC passes with 29 generated states, 21 distinct states,
  and depth 14. Unsafe configs reject compile after failed cluster checks,
  compile with service mismatch, compile with target mismatch, receipt before
  local lease, new receipt during revoke, local lease reuse before revoke
  completion, and audit-only admission/revoke acceptance.
  validation/0066 models the local monitor admission interface boundary. Safe
  TLC passes with 14 generated states, 12 distinct states, and depth 11. Unsafe
  configs reject Linux-minted monitor response, replayed admission response,
  failure-then-compile, receipt without monitor response, endpoint without
  receipts, revoke complete with live derived receipts, and raw service-handle
  exposure.
  validation/0055 models stale XSK/page-pool completion quarantine. Safe TLC
  passes only when old XSK CQ completion, XSK free-list return, page-pool
  recycle, PageOwner transfer, packet generation reset, and queue reassignment
  are separated after revoke.
  validation/0058 models VF mailbox queue/DMA/IRQ/budget/FDIR carrier
  separation. Safe TLC passes only when virtchnl validation, opcode allowlists,
  queue id checks, DMA address fields, IRQ vector checks, QoS caps, and FDIR
  ctx_done are not treated as authority.
```

Protection missing:

```text
no queue revoke epoch implementation
no queue drain/quarantine implementation
no DMA/IOMMU/IRQ invalidation order proof
no outstanding ledger cleanup proof
no stale service-work cancellation proof
no monitor-backed implementation of VF IRQ route invalidation
no monitor-backed IRQ route invalidation receipt implementation
no monitor-backed DMA/IOMMU/MemoryView invalidation receipt implementation
no stale XSK/page-pool quarantine or packet generation reset implementation
no VF mailbox request carrier and async FDIR context implementation
```

Forbidden claim:

```text
Do not claim queue revocation from Linux netdev down/reset alone.
```

### DEV-NIC-010: Linux Substrate Compatibility

Claim:

```text
Linux netdev, NAPI, XDP, AF_XDP, devlink, representor, workqueue, and driver
tracepoint structures are useful compatibility substrates, but they are not
production authority roots.
```

Current status: Source-observed only

Evidence:

```text
analysis/0052 maps a representative modern NIC path.
validation/0047 confirms source and tracepoint observability.
validation/0051 confirms observation-only revoke readiness for selected ice
down/reset/NAPI/IRQ/DMA/XSK/representor/service/rebuild anchors.
```

Protection missing:

```text
all observed state is Linux-mutable
no monitor verification
no non-forgeable authority roots
no hostile-kernel containment evidence
```

Forbidden claim:

```text
Do not upgrade source observation into protection evidence.
Do not treat visible vf_id, ice_vf pointer reachability, ICE_VF_STATE_ACTIVE,
ICE_VF_STATE_DIS, stable lan_vsi_idx/ctrl_vsi_idx, queue id, vector id, old
allowlist state, or VPINT/VPLAN programming success as fresh handoff authority.
Do not treat service Domain policy, Linux DMA/IRQ state, signed cluster lease
text, audit-only monitor logging, or raw PF/VF/IOMMU/MSI/devlink handles as
monitor roots or receipts.
```

## Gate Result

Current gate result:

```text
DEV-001 modern NIC refinement:
  model-supported for authority-class separation
  model-supported for VF IRQ ownership separation
  model-supported for monitor IRQ route invalidation receipt semantics
  model-supported for monitor DMA/IOMMU/MemoryView invalidation receipt
  semantics
  model-supported for stale XSK/page-pool quarantine semantics
  model-supported for modern NIC ServiceWork carrier and service/caller
  authority intersection semantics
  model-supported for VF mailbox queue/DMA/IRQ/budget/FDIR carrier semantics
  model-supported for VF epoch handoff and stale identifier rejection semantics
  model-supported for HyperTag Monitor/service Domain/target endpoint split
  semantics
  model-supported for implementation-readiness gate ordering
  model-supported for LocalDomainDeviceLease root-management/local monitor
  compilation semantics
  observation-contract validated for LocalDomainDeviceLease root-management/
  local monitor row shape and dependency rules
  model-supported for LocalDomainDeviceLease admission failure and revoke
  ordering semantics
  model-supported for local monitor admission interface boundary semantics
  source-observed for Intel ice anchors
  observation-only for trace/readiness
  observation-only for selected ice revoke readiness
  readiness-only for HyperTag probe/stub planning
  observation-only for modern NIC HyperTag source-anchor ledger emission
  not protection-evidenced
  not implementation-approved
```

Allowed next work:

```text
trace-only observation improvements
machine-readable ledger refinement
additional device family source maps
small formal models for revoke/drain/quarantine ordering
observation-only implementation planning that names receipt/carrier coverage
VF epoch handoff planning that names mailbox embargo, VF epoch bump, VSI
generation, QueueLease generation, DMA/IRQ receipts, FDIR context clearing, and
service replay authorization
HyperTag interface planning that names monitor-owned roots, service Domain
policy-only authority, typed target endpoints, receipt minting, and no
per-packet monitor trap
HyperTag readiness planning that maps receipt/carrier rows to observation-only
Linux probes or inert stubs, with authority_claim=false and behavior_change=false
privileged no-code tracefs run using the emitted tracefs plan, if operator
approval/root execution is available
root-management/local monitor observation-contract planning for
LocalDomainDeviceLease rows, including lease epoch, service/target Domain,
device root, DMA MemoryView, IRQ route, root budget, compile result, and
revocation status fields
root-management/local monitor admission-protocol planning that consumes the
LocalDomainDeviceLease observation contract without claiming enforcement
failure-mode and revoke-ordering refinement for root-management/local monitor
admission before any monitor ABI or Linux stub is selected
local monitor admission interface boundary refinement before choosing monitor
ABI, Linux service-domain stubs, or typed endpoint carriers
```

Still forbidden:

```text
behavior-changing NIC enforcement patches
generic workqueue enforcement hooks
using Linux ring/q_vector/netdev/devlink state as non-forgeable authority
claiming IOMMU/QueueLease protection without monitor-backed ownership
collapsing SKB/XDP/AF_XDP/control/representor/service paths into one cap
using vf_id, ice_vf pointer reachability, ICE_VF_STATE_ACTIVE/DIS, lan_vsi_idx,
ctrl_vsi_idx, queue id, vector id, old allowlist state, or reset completion as
fresh VF/Domain/QueueLease authority
service Domain minting monitor receipts
Linux DMA/IRQ state as monitor receipts
raw PF/VF/IOMMU/MSI/devlink authority exposed to target Domains
audit-only monitor calls after Linux side effects
using ClusterLease text, scheduler placement, service-domain admission, Linux
PCI/devlink/IOMMU registration, or tracefs observation as LocalDomainDeviceLease
per-packet monitor traps as the normal data path
```

## Implementation Consequence

Any future QueueLease prototype must name which of these subclaims it supports.

A minimal trace-only Linux slice may observe queue identity, descriptor
publication, and completion correlations. It must not claim enforcement.

A behavior-changing prototype is not allowed until it has at least:

```text
1. typed QueueTag and queue epoch representation
2. typed SubmitLedger and DescriptorLedger representation
3. explicit MemoryView/IOMMU ownership boundary for DMA packet memory
   including an invalidation receipt before PageOwner transfer
4. stale XSK/page-pool completion quarantine and packet generation reset rule
5. QueueControl and RepresentorForward split
6. service work classification and carrier/merge policy
7. revoke/drain/quarantine model
8. reset/rebuild replay reauthorization and stale service-work cancellation
9. VF mailbox request carrier for queue config, DMA ring base, IRQ map,
   queue budget/quanta, and FDIR async completion
10. VF epoch handoff carrier for mailbox embargo, reset/reassignment reopen,
    VSI generation, QueueLease generation, DMA/IRQ receipts, FDIR context
    clearing, and service replay freshness
11. HyperTag interface split that keeps receipt minting in the monitor, policy
    and hardware programming in the service Domain, typed endpoints in target
    Domains, cluster lease compilation local, and ordinary packet submission off
    the monitor slow path
12. HyperTag readiness gate proof that probes/stubs are observation-only,
    coverage-complete, inert, raw-endpoint-free, and not protection evidence
13. review of the LocalDomainDeviceLease external gap before any distributed
    lease or cluster-local monitor claim; ClusterLease, scheduler placement,
    service admission, Linux device registration, and tracefs observation are
    not LocalDomainDeviceLease authority
14. clear statement that Linux-only evidence is compatibility/prototype
   evidence, not hypervisor-grade protection evidence
```
