# Analysis 0059: ICE VF Mailbox Queue Carrier Source Map

Status: Draft source map with model gate

Date: 2026-06-30

Linux source:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
commit: 7cf0b1e415bcead8a2079c8be94a9d41aad7d462
```

Related artifacts:

```text
analysis/0052-ice-modern-nic-queuelease-source-map.md
analysis/0053-ice-modern-nic-revoke-source-map.md
analysis/0054-monitor-irq-route-invalidation-source-map.md
analysis/0055-monitor-dma-iommu-memoryview-invalidation-source-map.md
analysis/0058-ice-servicework-carrier-source-map.md
formal/0033-monitor-irq-route-invalidation-model/
formal/0034-monitor-dma-iommu-invalidation-model/
formal/0037-modern-nic-servicework-carrier-model/
```

## Purpose

N-086 maps the authority boundary for Intel `ice` VF mailbox operations that
turn a VF request into queue, DMA, IRQ, budget, or FDIR/offload effects.

The key question is:

```text
When a VF sends a valid virtchnl message, what else must be true before the PF
driver may program a queue, descriptor-ring DMA base, interrupt route, queue
budget, or hardware FDIR/offload rule on that VF's behalf?
```

The answer must not be "virtchnl validation succeeded". Virtchnl validation is
payload syntax and Linux policy substrate. It is not Domain authority.

## Core Rule

For CapSched-H:

```text
VF mailbox validity != VF Domain request authority
opcode allowlist != QueueControl authority
queue id range check != QueueLease authority
ring DMA address value != DMA MemoryView authority
vector id range check != IRQ route authority
queue bandwidth/quanta request != queue budget authority
FDIR rule validation != OffloadCap authority
FDIR ctx_done completion != frozen request carrier
```

The safe shape is:

```text
effective VF mailbox authority =
  live service Domain authority
  intersect live VF/Domain request carrier
  intersect fresh VF epoch
  intersect operation-specific endpoint cap
  intersect fresh queue/device epoch
  intersect monitor-backed QueueLease / QueueControl / DMA MemoryView /
            IRQ route / queue budget / Offload authority as required
  intersect service budget or explicit caller-charged service budget
```

For FDIR and other deferred effects:

```text
async completion authority =
  frozen request carrier
  intersect fresh VF epoch
  intersect fresh rule generation
  intersect live offload/control authority
  intersect live service Domain authority
```

## Required Carrier Classes

### `VFRequestCarrier`

Minimum contents:

```text
VF Domain id
VF id and VF epoch
request sequence or mailbox generation
virtchnl opcode
payload digest or parsed operation digest
service Domain id and service epoch
service budget or caller-charged service ticket
```

This carrier is required before treating a mailbox message as a Domain request.

### `QueueConfigCarrier`

Minimum contents:

```text
VFRequestCarrier
QueueLease id
queue epoch
Tx/Rx queue ids
ring length
descriptor-ring DMA address class
DMA MemoryView/IOMMU receipt for the ring address
QueueControl authority for changing queue context
```

This carrier is required before copying VF-provided DMA ring addresses into
driver ring state or programming Tx/Rx queue contexts.

### `QueueEnableCarrier`

Minimum contents:

```text
VFRequestCarrier
QueueLease id
queue epoch
previously frozen QueueConfigCarrier generation
IRQ route status if queue interrupts are enabled
```

This carrier is required before enabling Rx/Tx queues or marking `rxq_ena` /
`txq_ena`.

### `IrqRouteCarrier`

Minimum contents:

```text
VFRequestCarrier
IRQ route id
IRQ route epoch
VF vector id
queue bitmap
event delivery endpoint or isolated MSI route
interrupt-remapping receipt when production-backed
```

This carrier is required before mapping queue vectors or enabling queue
interrupt causes.

### `QueueBudgetCarrier`

Minimum contents:

```text
VFRequestCarrier
QueueLease id
queue epoch
budget/rate authority
traffic class
peak/committed limits or quanta profile
```

This carrier is required before queue bandwidth or quanta programming.

### `FdirOffloadCarrier`

Minimum contents:

```text
VFRequestCarrier
OffloadCap or QueueControlCap
rule generation
flow id
destination queue or action digest
ctrl_vsi generation
async completion context id
```

This carrier is required at request time and must survive FDIR IRQ/timer
completion. It must not be reconstructed from `ctx_done` alone.

## Source Anchors

### VF mailbox ingress

Useful anchors:

```text
drivers/net/ethernet/intel/ice/virt/virtchnl.c:
  ice_vc_process_vf_msg() lines 2736-2935
  ice_get_vf_by_id() use line 2750
  vf->cfg_lock lock line 2757
  ICE_VF_STATE_DIS check line 2764
  virtchnl_vc_validate_vf_msg() lines 2771-2778
  ice_vc_is_opcode_allowed() line 2789
  VIRTCHNL_OP_CONFIG_VSI_QUEUES dispatch line 2816
  VIRTCHNL_OP_ENABLE_QUEUES dispatch line 2819
  VIRTCHNL_OP_CONFIG_IRQ_MAP dispatch line 2829
  VIRTCHNL_OP_ADD_FDIR_FILTER dispatch line 2868
  VIRTCHNL_OP_CONFIG_QUEUE_BW dispatch line 2904
  VIRTCHNL_OP_CONFIG_QUANTA dispatch line 2907
```

Interpretation:

```text
The mailbox handler establishes Linux VF object reachability, serializes through
vf->cfg_lock, validates virtchnl message syntax, checks an opcode allowlist, and
dispatches to operation handlers.
```

Forbidden shortcut:

```text
Do not treat VF object reachability, vf->cfg_lock, virtchnl validation, or the
opcode allowlist as Domain request authority.
```

### VF resource negotiation and allowlist

Useful anchors:

```text
drivers/net/ethernet/intel/ice/virt/virtchnl.c:
  get resources path lines 250-352
  vf->driver_caps from VF message line 268
  granted vfres->vf_cap_flags calculation lines 281-329
  vf->driver_caps = vfres->vf_cap_flags line 347
  ice_vc_set_caps_allowlist() line 349
  ice_vc_set_working_allowlist() line 350
  ICE_VF_STATE_ACTIVE set line 352

drivers/net/ethernet/intel/ice/virt/allowlist.c:
  working queue/IRQ opcode allowlist lines 31-37
  FDIR allowlist lines 82-85
  QoS allowlist lines 93-95
  ice_vc_is_opcode_allowed() lines 123-134
```

Interpretation:

```text
The VF advertises caps, the PF intersects them with supported features, and the
driver opens opcode classes accordingly. This is compatibility negotiation and
policy substrate, not non-forgeable CapSched authority.
```

Forbidden shortcut:

```text
Do not treat VIRTCHNL_VF_OFFLOAD_QOS, VIRTCHNL_VF_OFFLOAD_FDIR_PF, working
queue opcodes, or opcodes_allowlist bits as QueueBudgetCap, OffloadCap,
QueueControlCap, or QueueLease authority.
```

### Queue configuration and descriptor-ring DMA base

Useful anchors:

```text
drivers/net/ethernet/intel/ice/virt/queues.c:
  ice_vc_cfg_qs_msg() lines 749-914
  ICE_VF_STATE_ACTIVE check line 763
  ice_vc_isvalid_vsi_id() line 766
  queue pair bounds lines 773-778
  ring length and queue id validation lines 793-797
  Tx ring DMA address copy line 812
  Tx queue hardware configure line 820
  Rx ring DMA address copy line 833
  Rx queue hardware configure line 860
  RXDID/PTP timestamp descriptor selection lines 871-886

drivers/net/ethernet/intel/ice/ice_base.c:
  ice_setup_tx_ctx() lines 343-381
  Tx context base = ring->dma line 350
  ice_setup_rx_ctx() lines 460-525
  Rx context base = ring->dma line 494
  ice_vsi_cfg_txq() lines 1039-1080
```

Interpretation:

```text
`ice_vc_cfg_qs_msg()` copies VF-provided descriptor-ring DMA addresses into
`vsi->tx_rings[q_idx]->dma` and `vsi->rx_rings[q_idx]->dma`. The base driver
then packs those addresses into Tx/Rx hardware queue contexts.
```

Forbidden shortcut:

```text
Do not treat a valid queue id, valid ring length, active VF, or syntactically
valid DMA address field as DMA MemoryView/IOMMU authority.
```

### Queue enable and disable

Useful anchors:

```text
drivers/net/ethernet/intel/ice/virt/queues.c:
  ice_vc_ena_qs_msg() lines 234-312
  Rx queue enable line 280
  Rx interrupt cause enable line 286
  Tx interrupt cause enable line 301
  rxq_ena and txq_ena set lines 287 and 302
  ICE_VF_STATE_QS_ENA set line 306
  ice_vc_dis_qs_msg() lines 361-451
  Tx queue disable line 394
  all-Rx stop path lines 411-419
  per-Rx stop path lines 426-440
```

Interpretation:

```text
Queue enable consumes prior queue context, optionally enables interrupt causes,
and sets Linux VF queue-enabled bits. Queue disable clears Linux state and
stops rings, but is not a monitor-grade revoke proof by itself.
```

Forbidden shortcut:

```text
Do not treat rxq_ena, txq_ena, ICE_VF_STATE_QS_ENA, or queue disable success as
QueueLease epoch authority or revoke authority.
```

### IRQ route mapping

Useful anchors:

```text
drivers/net/ethernet/intel/ice/virt/queues.c:
  ice_cfg_interrupt() lines 463-504
  q_vector rx/tx ring assignment lines 476-500
  ice_cfg_rxq_interrupt() / ice_cfg_txq_interrupt() calls lines 479-502
  ice_vc_cfg_irq_map_msg() lines 513-581
  vf->num_msix and vector count checks lines 529-531
  vector id / vsi id validation lines 550-554
  q_vector lookup line 568
```

Interpretation:

```text
The VF supplies vector-to-queue maps. The driver validates vector and queue
ranges, assigns q_vector pointers, programs queue interrupt routing, and later
queue enable may set interrupt cause enable.
```

Forbidden shortcut:

```text
Do not treat vector_id < vf->num_msix, q_vector lookup, or successful
ice_cfg_interrupt() as monitor-backed IRQ route ownership.
```

### Queue bandwidth and quanta

Useful anchors:

```text
drivers/net/ethernet/intel/ice/virt/queues.c:
  ice_vf_cfg_qs_bw() lines 70-112
  ice_cfg_q_bw_lmt() / default limit calls lines 87-106
  ice_vf_cfg_q_quanta_profile() lines 129-150
  ice_vc_cfg_q_bw() lines 593-665
  vf->qs_bw[] copies lines 651-655
  ice_vf_cfg_qs_bw() call line 659
  ice_vc_cfg_q_quanta() lines 677-739
  vsi->tx_rings[i]->quanta_prof_id assignment lines 734-735
```

Interpretation:

```text
The VF can request queue rate limits and quanta profiles when QoS opcodes are
enabled. This mutates hardware scheduling/rate behavior for queues.
```

Forbidden shortcut:

```text
Do not treat queue rate fields, QoS caps, or traffic class checks as
QueueBudgetCarrier authority.
```

### FDIR/offload request and async completion

Useful anchors:

```text
drivers/net/ethernet/intel/ice/virt/fdir.c:
  ice_vc_validate_fdir_fltr() lines 1223-1245
  ice_vc_fdir_write_fltr() path uses ice_prgm_fdir_fltr() line 1436
  ice_vf_fdir_timer() lines 1453-1480
  ice_vc_fdir_irq_handler() lines 1493-1525
  ice_flush_fdir_ctx() lines 1801-1866
  ice_vc_fdir_set_irq_ctx() lines 1880-1907
  ice_vc_add_fdir_fltr() lines 2085-2242
  ice_vc_del_fdir_fltr() lines 2311-2419
```

Interpretation:

```text
FDIR request processing validates patterns/actions, inserts software entries,
sets `ctx_irq`, writes a hardware filter, then completes later through IRQ or
timer into `ctx_done`, which is flushed by service work.
```

Forbidden shortcut:

```text
Do not treat FDIR rule validation, `ctx_irq.flags`, `ctx_done.flags`, timer
completion, or service-task flush as frozen OffloadCap. The original request
carrier must survive into the async completion path.
```

## Implementation Pressure

A future prototype may keep much of the Linux virtchnl structure, but the
authority boundary must be explicit:

```text
before ice_vc_cfg_qs_msg copies dma_ring_addr:
  require VFRequestCarrier + QueueConfigCarrier + DMA MemoryView proof

before ice_vsi_cfg_single_txq/rxq:
  require QueueControl + QueueLease epoch + DMA receipt

before ice_cfg_interrupt:
  require IrqRouteCarrier

before ice_vc_ena_qs_msg enables queues or interrupt causes:
  require QueueEnableCarrier with prior config generation

before ice_vc_cfg_q_bw / ice_vc_cfg_q_quanta applies rate/quanta:
  require QueueBudgetCarrier

before ice_vc_add_fdir_fltr / ice_vc_del_fdir_fltr writes hardware:
  require FdirOffloadCarrier

before ice_flush_fdir_ctx finalizes async status:
  revalidate frozen FdirOffloadCarrier, VF epoch, rule generation, and revoke
  state
```

## Consequence

The next formal model should reject these designs:

```text
1. queue config authorized by virtchnl validation and opcode allowlist alone
2. DMA ring base programmed without MemoryView/IOMMU authority
3. queue enable before fresh QueueLease and queue config generation
4. IRQ map programmed without IRQ route authority
5. queue budget/quanta programmed without budget authority
6. FDIR hardware rule installed without OffloadCap
7. FDIR async completion accepted without frozen request context
8. queue or FDIR effect after VF/queue revoke without fresh reauthorization
```

This remains analysis/modeling evidence only. It does not approve a
behavior-changing driver or workqueue patch.
