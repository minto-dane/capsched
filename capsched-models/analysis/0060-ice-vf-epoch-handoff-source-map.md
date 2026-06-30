# Analysis 0060: ICE VF Epoch and Handoff Source Map

Status: Draft source map with model gate

Date: 2026-06-30

Linux source:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
commit: 7cf0b1e415bcead8a2079c8be94a9d41aad7d462
subject: sched/capsched: Add type-only authority scaffolding
```

Related artifacts:

```text
analysis/0052-ice-modern-nic-queuelease-source-map.md
analysis/0053-ice-modern-nic-revoke-source-map.md
analysis/0054-monitor-irq-route-invalidation-source-map.md
analysis/0055-monitor-dma-iommu-memoryview-invalidation-source-map.md
analysis/0058-ice-servicework-carrier-source-map.md
analysis/0059-ice-vf-mailbox-carrier-source-map.md
formal/0038-vf-mailbox-carrier-model/
```

## Purpose

N-087 maps the identity handoff problem around Intel `ice` SR-IOV VF reset,
VSI rebuild/reuse, queue reassignment, IRQ remapping, DMA ring reprogramming,
FDIR completion, and mailbox replay.

The key question is:

```text
When a VF is reset, removed, re-created, or reassigned, what prevents a stale
vf_id, VSI index, queue id, MSI-X vector, DMA address, FDIR context, or queued
service callback from carrying authority into the next Domain that receives the
same visible VF number?
```

The answer must not be "the Linux object still has a refcount" or "the VF id
matches". Those are object lifetime and lookup facts. They are not Domain
authority freshness.

## Core Rule

For CapSched-H:

```text
VF id equality != VF identity freshness
ice_vf pointer reachability != Domain ownership
refcount/RCU lifetime != authority epoch
cfg_lock serialization != stale carrier rejection
ICE_VF_STATE_ACTIVE != QueueLease authority
ICE_VF_STATE_DIS != monitor revoke receipt
VSI index stability != MemoryView stability
queue id range validity != queue ownership
MSI-X vector remap != IRQ route authority
FDIR ctx_done validity != frozen completion authority
reset/rebuild replay != fresh Domain request
```

The safe shape is:

```text
VF handoff effect =
  live service Domain authority
  intersect fresh VF identity epoch
  intersect fresh Domain binding epoch
  intersect fresh VSI generation
  intersect fresh QueueLease generation
  intersect monitor DMA/IOMMU MemoryView receipt
  intersect monitor IRQ route receipt
  intersect cleared or epoch-tagged FDIR async context
  intersect mailbox embargo/reopen proof
  intersect service replay reauthorization
```

Visible identifiers may be reused. Authority-bearing identifiers must not be
reused without an epoch change and explicit receipt chain.

## Existing Linux Mechanisms Worth Preserving

The current `ice` driver already has useful substrate:

```text
ice_get_vf_by_id()
  RCU lookup and kref lifetime guard.

vf->cfg_lock
  Serializes VF configuration and virtchnl request handling.

ICE_VF_STATE_DIS / ICE_VF_STATE_INIT / ICE_VF_STATE_ACTIVE
  Separates reset-disabled, initialized, and negotiated resource states.

ice_dis_vf_qs()
  Stops Tx/Rx rings and clears queue-enabled bitmaps.

ice_dis_vf_mappings()
  Clears VPINT and queue-base hardware mapping registers during teardown.

ice_vf_fdir_exit() / ice_vf_fdir_init()
  Flushes FDIR entries and resets FDIR local context fields.

ice_virt_get_irqs() / ice_virt_free_irqs()
  Maintains a PF-local MSI-X vector allocation bitmap.
```

These are necessary compatibility mechanisms. CapSched should not replace them
in L0/L1. It should add identity and authority tracking around them.

## CapSched Gap

The missing layer is an explicit generation boundary:

```text
struct capsched_vf_binding {
        u64 domain_id;
        u64 domain_epoch;
        u16 pf_id;
        u16 vf_id;
        u64 vf_epoch;
        u64 vsi_generation;
        u64 queue_generation;
        u64 irq_route_epoch;
        u64 dma_memoryview_epoch;
        u64 mailbox_generation;
};
```

This structure is illustrative, not an implementation decision. The important
requirement is semantic:

```text
Any effect derived from a VF request must carry the binding epoch that was
current when the request was frozen. Any reset, teardown, reassignment, or
Domain migration must invalidate old carriers before the visible identifier is
reopened.
```

## Source Anchors

### VF object lookup and visible identity

Useful anchors:

```text
drivers/net/ethernet/intel/ice/ice_vf_lib.c:
  ice_get_vf_by_id() lines 25-46
  ice_put_vf() lines 75-78
  ice_get_vf_vsi() lines 123-128

drivers/net/ethernet/intel/ice/ice_vf_lib.h:
  enum ice_vf_states lines 34-42
  struct ice_vf fields lines 139-200
```

Interpretation:

```text
VF lookup is keyed by vf_id and guarded by RCU/refcount lifetime. struct ice_vf
also stores lan_vsi_idx, ctrl_vsi_idx, driver_caps, txq_ena/rxq_ena bitmaps,
num_msix, num_vf_qs, vf_states, and opcodes_allowlist.
```

Forbidden shortcut:

```text
Do not treat a successful ice_get_vf_by_id() or matching vf->vf_id as proof
that a mailbox request, queued service callback, IRQ event, queue completion, or
FDIR completion belongs to the current Domain binding.
```

### VF initialization and resource negotiation

Useful anchors:

```text
drivers/net/ethernet/intel/ice/ice_sriov.c:
  VF allocation loop lines 697-722
  vf->vf_id assignment line 706
  hash_add_rcu() line 721

drivers/net/ethernet/intel/ice/ice_vf_lib.c:
  ice_initialize_vf_entry() lines 1001-1033
  default allowlist line 1010
  num_msix/num_vf_qs defaults lines 1013-1016
  ctrl_vsi invalidation lines 1020-1024

drivers/net/ethernet/intel/ice/virt/virtchnl.c:
  ice_vc_get_vf_res_msg() lines 245-355
  vf->driver_caps from VF message lines 267-271
  vfres queue/vector reporting lines 332-343
  vf->driver_caps = vfres->vf_cap_flags line 347
  allowlist update lines 349-350
  ICE_VF_STATE_ACTIVE set line 352
```

Interpretation:

```text
Resource negotiation transitions the VF into ACTIVE state and installs a
working virtchnl allowlist. This is a Linux protocol state transition, not a
Domain binding proof.
```

CapSched-H requirement:

```text
ACTIVE must be paired with a fresh capsched_vf_binding epoch. Negotiated
capabilities may select policy, but cannot mint QueueLease, IRQ route, DMA, or
offload authority by themselves.
```

### Single VF reset

Useful anchors:

```text
drivers/net/ethernet/intel/ice/ice_vf_lib.c:
  ice_reset_vf() lines 864-982
  optional notify lines 875-876
  cfg_lock handling lines 884-887 and 979-980
  DIS state set line 910
  reset trigger line 911
  ice_dis_vf_qs() line 919
  disable Tx queue AQ line 924
  poll reset status lines 927-936
  driver_caps clear and default allowlist lines 938-939
  promiscuous clear line 944
  FDIR exit/init lines 946-947
  ctrl VSI release lines 948-952
  pre rebuild line 954
  VSI reconfig lines 956-963
  representor update line 970
  mailbox count reset line 973
```

Interpretation:

```text
The reset path disables queues, clears driver capabilities, resets allowlists,
tears down FDIR local state, releases control VSI, rebuilds or reconfigures the
VSI, and clears mailbox counters.
```

CapSched-H requirement:

```text
DIS and reset completion must drive a VF epoch bump before any mailbox,
queue-enable, DMA base, IRQ route, or FDIR completion is accepted again.
Existing reset cleanup is useful substrate, but it is not a monitor-backed
revocation receipt.
```

### Reset all VFs

Useful anchors:

```text
drivers/net/ethernet/intel/ice/ice_vf_lib.c:
  ice_reset_all_vfs() lines 748-824
  mailbox count reset lines 761-763
  ICE_VF_DIS gate lines 765-769
  reset trigger loop lines 771-773
  poll loop lines 779-788
  per-VF reset rebuild loop lines 790-818
  driver_caps clear and allowlist reset lines 795-797
  FDIR exit/init lines 798-799
  ctrl VSI release lines 800-804
  pre/post VSI rebuild lines 806-813
  eswitch detach/attach lines 794 and 815
```

Interpretation:

```text
Bulk reset replays similar state cleanup across all VFs and temporarily gates
VF reset work through PF-level ICE_VF_DIS state.
```

CapSched-H requirement:

```text
Bulk reset must invalidate every affected VF binding epoch before the driver
replays host configuration and attaches representors again. A later attach must
derive a new lower QueueLease, not inherit the old one.
```

### VF teardown and SR-IOV disable

Useful anchors:

```text
drivers/net/ethernet/intel/ice/ice_sriov.c:
  ice_free_vfs() lines 131-185
  pci_disable_sriov() lines 145-152
  eswitch detach line 159
  ice_dis_vf_qs() line 160
  ice_virt_free_irqs() line 161
  ice_dis_vf_mappings() lines 163-166
  ice_free_vf_res() line 167
  num_qps_per reset line 181
  ice_free_vf_entries() line 182

  ice_free_vf_res() lines 48-83
  clear INIT line 56
  FDIR exit line 57
  ctrl VSI release lines 58-60
  LAN VSI release lines 62-67
  interrupt clear loop lines 75-79

  ice_dis_vf_mappings() lines 89-125
  VPINT clear lines 103-104
  GLINT_VECT2FUNC reset lines 106-114
  VPLAN_TX_QBASE clear lines 116-119
  VPLAN_RX_QBASE clear lines 121-124
```

Interpretation:

```text
Teardown clears queue/interrupt mappings and removes VF entries once references
are dropped. If VFs are assigned elsewhere, SR-IOV disable is refused.
```

CapSched-H requirement:

```text
The CapSched monitor must receive a teardown/revoke event before Linux releases
or reuses a VF binding. Queue, IRQ, and DMA views must be invalidated even when
Linux cannot disable SR-IOV because a VF is assigned to a service/Domain.
```

### MSI-X and queue mapping reuse

Useful anchors:

```text
drivers/net/ethernet/intel/ice/ice_sriov.c:
  ice_ena_vf_msix_mappings() lines 230-268
  VPINT allocation writes lines 249-257
  GLINT_VECT2FUNC writes lines 259-264
  mailbox interrupt mapping line 267

  ice_ena_vf_q_mappings() lines 276-317
  VPLAN_TXQ_MAPENA line 287
  VPLAN_TX_QBASE programming lines 295-297
  VPLAN_RXQ_MAPENA line 303
  VPLAN_RX_QBASE programming lines 311-313

  ice_ena_vf_mappings() lines 323-330

drivers/net/ethernet/intel/ice/ice_irq.c:
  ice_virt_get_irqs() lines 251-264
  ice_virt_free_irqs() lines 272-275

drivers/net/ethernet/intel/ice/ice_sriov.c:
  ice_sriov_remap_vectors() lines 876-911
  ice_sriov_set_msix_vec_count() lines 928-1025
```

Interpretation:

```text
MSI-X vectors and queue mappings are PF-local hardware resources that can be
freed and reallocated. Vector remapping can affect inactive VFs, and changing
MSI-X count disables old mappings, frees IRQs, rebuilds queue state, then
enables mappings again.
```

CapSched-H requirement:

```text
IRQ route epoch and QueueLease epoch must change when vectors or queue ranges
are remapped. A VF-visible vector_id or queue_id is insufficient because the
backing PF vector and PF queue can be reused.
```

### Queue config, DMA base, IRQ map, and queue enable

Useful anchors:

```text
drivers/net/ethernet/intel/ice/virt/queues.c:
  ice_vc_cfg_qs_msg() lines 749-914
  ACTIVE check line 763
  VSI id check lines 766-767
  queue count/range checks lines 773-808
  Tx dma_ring_addr copied to ring->dma line 812
  Rx dma_ring_addr copied to ring->dma line 833
  Tx/Rx queue programming lines 820 and 860

  ice_vc_cfg_irq_map_msg() lines 513-581
  ACTIVE and vector-count checks lines 529-534
  vector_id/VSI checks lines 547-557
  q_vector selection line 566
  ice_cfg_interrupt() lines 462-503
  q_vector and hardware interrupt context updates lines 480-500

  ice_vc_ena_qs_msg() lines 234-313
  ACTIVE check lines 243-246
  VSI and bitmap checks lines 248-256
  Rx queue enable line 279
  Rx interrupt enable and bitmap update lines 286-287
  Tx interrupt enable and bitmap update lines 301-302
  QS_ENA set lines 305-307
```

Interpretation:

```text
Queue config copies VF-provided DMA addresses into Linux ring state and
programs queue contexts. IRQ mapping binds VF vector ids to q_vectors and queue
interrupt context. Queue enable turns those configured objects live.
```

CapSched-H requirement:

```text
Queue config must require a fresh DMA MemoryView/IOMMU receipt. IRQ map must
require a fresh IRQ route receipt. Queue enable must require the frozen queue
configuration generation and fresh QueueLease epoch. A reset or vector/queue
reassignment invalidates all three.
```

### FDIR async completion and ctrl VSI

Useful anchors:

```text
drivers/net/ethernet/intel/ice/virt/fdir.c:
  ice_vc_fdir_set_irq_ctx() lines 1880-1907
  ctx_irq/ctx_done busy check lines 1887-1895
  ctx_irq setup lines 1896-1904
  ice_vf_fdir_timer() lines 1451-1482
  timer moves ctx_irq to ctx_done lines 1472-1477
  schedules service task lines 1480-1481
  ice_vc_fdir_irq_handler() lines 1489-1526
  IRQ moves ctx_irq to ctx_done lines 1516-1522
  ice_flush_fdir_ctx() lines 1803-1868
  ACTIVE check lines 1819-1820
  ctrl_vsi_idx check lines 1822-1823
  post add/delete handlers lines 1845-1848 and 1857-1860
  ice_vf_fdir_init() lines 2411-2422
  ctx_irq/ctx_done flags reset lines 2418-2420
  ice_vf_fdir_exit() lines 2428-2434
```

Interpretation:

```text
FDIR uses local async state split between ctx_irq and ctx_done. IRQ/timer
completion schedules service work, and service work later posts completion back
to the VF if the VF is ACTIVE and has a ctrl VSI.
```

CapSched-H requirement:

```text
FDIR ctx must carry VF epoch, ctrl_vsi generation, rule generation, and frozen
request carrier. ACTIVE and ctrl_vsi_idx checks are necessary but not sufficient
to prevent an old completion from being delivered after reset/reassignment.
```

### Mailbox request processing

Useful anchors:

```text
drivers/net/ethernet/intel/ice/virt/virtchnl.c:
  ice_vc_process_vf_msg() lines 2736-2935
  vf_id read from AQ event line 2740
  ice_get_vf_by_id() line 2750
  cfg_lock line 2757
  DIS check lines 2763-2767
  virtchnl_vc_validate_vf_msg() lines 2771-2778
  opcode allowlist check lines 2789-2794
  queue config dispatch lines 2816-2818
  queue enable dispatch lines 2819-2822
  IRQ map dispatch lines 2829-2831
  FDIR dispatch lines 2868-2872
  QoS dispatch lines 2901-2908
```

Interpretation:

```text
Mailbox dispatch uses vf_id, object lookup, DIS state, virtchnl payload
validation, and opcode allowlist to decide which Linux operation handler runs.
```

CapSched-H requirement:

```text
The mailbox ingress must freeze a VFRequestCarrier with current vf_epoch and
mailbox_generation before dispatch. Any reset starts a mailbox embargo. Reopen
requires a new carrier root, not just clearing DIS or setting ACTIVE.
```

## Required Handoff Receipts

Minimum receipt set for production-backed CapSched:

```text
VfEpochReceipt
  monitor says visible vf_id now maps to Domain D at vf_epoch E.

DomainBindingReceipt
  service Domain and target Domain agree on the current owner and service budget.

QueueLeaseReceipt
  PF queue range and VF queue ids are bound to a fresh queue_generation.

DmaMemoryViewReceipt
  descriptor ring addresses are inside the target Domain MemoryView and IOMMU
  mappings for the old epoch have been revoked.

IrqRouteReceipt
  MSI-X vector and interrupt-remapping route are bound to the current Domain.

FdirContextReceipt
  pending FDIR ctx is empty or every pending completion carries the current
  vf_epoch, ctrl_vsi_generation, and rule_generation.

MailboxEmbargoReceipt
  old mailbox messages cannot be processed after reset start and before reopen.

ServiceReplayReceipt
  reset/rebuild/service callbacks that reprogram hardware carry fresh service
  authority and fresh object epochs.
```

## Compatibility Consequence

Linux-only CapSched L0/L1 should not attempt to make `ice` a security boundary.
It can instrument and tag:

```text
vf_id
vf pointer
vf state bits
lan_vsi_idx / ctrl_vsi_idx
queue ids
DMA ring addresses
first_vector_idx / num_msix
FDIR ctx transitions
reset/rebuild entry and exit
mailbox dispatch opcode
```

Monitor-backed CapSched-H must later turn those tags into enforced roots:

```text
monitor-owned VF epoch
monitor-owned queue epoch
monitor-owned DMA MemoryView/IOMMU receipt
monitor-owned IRQ route receipt
monitor-owned revoke/reopen sequence
```

This preserves upstream Linux semantics while avoiding the false claim that
existing process/VF isolation is already hypervisor-grade.

## Multi-Cluster Datacenter OS Consequence

For a single OS spanning multiple clusters, VF identity must be location
independent:

```text
visible endpoint name:
  cluster/node/PF/VF/queue

authority identity:
  Domain id + Domain epoch + VF epoch + QueueLease epoch + MemoryView epoch
```

Moving a Domain or reassigning a device queue across nodes must compile into the
same handoff sequence:

```text
embargo old endpoint
drain or revoke old queues
invalidate DMA and IRQ routes
bump endpoint epoch
bind new MemoryView and queue route
reopen mailbox/submit path under fresh carrier
```

A cluster scheduler may optimize placement and locality, but it must not weaken
the epoch boundary. Reuse-friendly identifiers are operational conveniences, not
authority.

## Design Consequence

The next implementation model should not embed CapSched authority into raw
`vf_id`, `lan_vsi_idx`, `queue_id`, or `vector_id` checks.

Instead, any future patch should introduce a separable carrier/root concept:

```text
VFRequestCarrier:
  request-time mailbox authority

VfBindingEpoch:
  visible VF id to Domain binding

QueueLeaseGeneration:
  queue ownership and queue config freshness

DmaMemoryViewReceipt:
  descriptor memory ownership

IrqRouteReceipt:
  event delivery ownership

FdirCompletionCarrier:
  async FDIR completion provenance

ServiceReplayCarrier:
  reset/rebuild/replay authority
```

The practical invariant is:

```text
No old epoch effect may survive handoff into a new Domain, even when Linux
reuses the same VF id, VSI index, queue id, vector id, service worker, or
FDIR local context field.
```
