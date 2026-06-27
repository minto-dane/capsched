# Validation 0047: ice Modern NIC Readiness Result

Status: Executed observation-only static readiness check

Date: 2026-06-27

Runner:

```text
capsched/capsched-models/validation/run-ice-modern-nic-readiness.sh
```

Related artifacts:

```text
capsched/capsched-models/analysis/0052-ice-modern-nic-queuelease-source-map.md
capsched/capsched-models/analysis/ice-modern-nic-queuelease-source-map-v1.json
capsched/capsched-models/formal/0028-modern-nic-queuelease-model/ModernNicQueueLease.tla
capsched/capsched-models/validation/0046-modern-nic-queuelease-tlc.md
```

## Purpose

This validation checks whether the `ice` modern NIC source map can be converted
into an observation-only readiness ledger for:

```text
QueueBind
SubmitLedgerSKB
SubmitLedgerXDPFrame
SubmitLedgerXDPTxPagePool
SubmitLedgerAFXDP
DescriptorLedger
CompletionSettlement
QueueControl
RepresentorForward
ServiceWork
RevokeSemantics
```

It is not an enforcement test and not a protection proof.

## Executed Result

Final run:

```text
run directory:
  /media/nia/scsiusb/dev/linux-cap/build/ice-modern-nic-readiness/20260627T113618Z

tracepoints:
  /media/nia/scsiusb/dev/linux-cap/build/ice-modern-nic-readiness/20260627T113618Z/tracepoint-inventory.tsv

source anchors:
  /media/nia/scsiusb/dev/linux-cap/build/ice-modern-nic-readiness/20260627T113618Z/source-anchors.tsv

readiness:
  /media/nia/scsiusb/dev/linux-cap/build/ice-modern-nic-readiness/20260627T113618Z/class-readiness.tsv

gaps:
  /media/nia/scsiusb/dev/linux-cap/build/ice-modern-nic-readiness/20260627T113618Z/semantic-gaps.tsv
```

Outcome:

```text
status: observation_only_ice_static_readiness
tracepoint_rows: 19
tracepoint_missing_rows: 0
source_anchor_rows: 40
source_anchor_missing_rows: 0
class_readiness_rows: 11
gap_rows: 12
```

Every readiness row carries:

```text
observation_only=true
authority_claim=false
monitor_verified=false
```

## Tracepoint Coverage

Existing generic tracepoints cover useful outer events:

```text
net_dev_start_xmit
net_dev_xmit
napi_poll
irq_handler_entry
irq_handler_exit
consume_skb
kfree_skb
iommu map/unmap
dma_map_sg
```

Existing `ice` driver tracepoints cover stronger ring-local evidence:

```text
ice_xmit_frame_ring
ice_xmit_frame_ring_drop
ice_clean_tx_irq
ice_clean_tx_irq_unmap
ice_clean_tx_irq_unmap_eop
ice_clean_rx_irq
ice_clean_rx_irq_indicate
ice_eswitch_br_port_link
ice_eswitch_br_port_unlink
```

These tracepoints improve observability, but they do not provide:

```text
monitor QueueTag
Domain id or epoch
typed SubmitLedger id
typed DescriptorLedger id
QueueControlCap
RepresentorForward derivation
service BudgetTicket
queue revoke epoch or quarantine outcome
```

## Source Anchor Coverage

The checker found all 40 source anchors with zero missing rows.

Class distribution:

```text
QueueBind: 6
SubmitLedgerSKB: 6
SubmitLedgerXDPFrame: 3
SubmitLedgerXDPTxPagePool: 2
SubmitLedgerAFXDP: 4
DescriptorLedger: 4
CompletionSettlement: 5
QueueControl: 3
RepresentorForward: 3
ServiceWork: 4
```

Key anchors include:

```text
ice_vsi, ice_q_vector, netif_napi_add_config, ring->q_vector
ice_start_xmit, skb queue_mapping, ice_tx_map, dma_map_single, skb_frag_dma_map
tx_desc field writes, next_to_watch, TX tail doorbell
ndo_xdp_xmit, __ice_xmit_xdp_ring, page_pool_get_dma_addr, XDP tail update
ndo_xsk_wakeup, ice_xsk_wakeup, ice_xmit_zc, xsk_tx_peek_release_desc_batch
ice_napi_poll, ice_clean_tx_irq, ice_clean_rx_irq, napi_consume_skb
ice_devlink_tx_sched_layers_set and devlink rate ops
representor ndo_start_xmit, ice_eswitch_port_start_xmit, lower dev_queue_xmit
ice service task, reset scheduling, eswitch bridge work, PTP kthread work
```

## Readiness Classification

```text
partially_ready:
  QueueBind

partial_gap_recorded:
  SubmitLedgerSKB
  DescriptorLedger
  CompletionSettlement
  RepresentorForward

source_only_gap_recorded:
  SubmitLedgerXDPFrame
  SubmitLedgerXDPTxPagePool
  SubmitLedgerAFXDP
  QueueControl
  ServiceWork

not_ready_future_capsched:
  RevokeSemantics
```

## High-Severity Gaps

All recorded gaps are high severity:

```text
authority-root:
  all observed ice state is Linux-mutable and monitor_verified=false

queue-tag:
  no QueueTag or queue epoch is emitted

submit-ledger-skb:
  SKB xmit trace and source anchors do not link skb, DMA maps, descriptors,
  and tail doorbell

submit-ledger-xdp:
  XDP submit has source anchors but no typed submit ledger tracepoint

page-pool-ownership:
  XDP_TX page-pool reuse lacks ownership provenance

xsk-ownership:
  AF_XDP descriptor batch fetch lacks XSK/UMEM ownership correlation

descriptor-ledger:
  descriptor field writes and tail doorbell are source-inferred but no typed
  DescriptorLedger is emitted

completion-settlement:
  ice clean tracepoints expose ring/desc/buf but not submit-class settlement or
  service budget

queue-control:
  devlink rate/scheduling source anchors exist but no QueueControlCap or
  monitor QueueTag is checked

representor-derivation:
  representor transmit calls dev_queue_xmit on lower dev without CapSched
  derivation evidence

service-provenance:
  service/reset/PTP/eswitch work anchors exist but no caller provenance or
  explicit ServiceOnly classification is emitted

revoke-semantics:
  reset/down/service paths exist but no CapSched queue revoke epoch or
  quiescence proof exists
```

## Validated Non-Claims

This result does not prove:

```text
QueueLease enforcement exists
IOMMU ownership is monitor protected
ice tracepoints are authority
Linux ring/q_vector state is non-forgeable
XDP/page-pool/AF_XDP memory ownership is safe
devlink queue-control is policy checked by CapSched
representor forwarding derives lower QueueLease authority
service work is charged to a correct BudgetTicket
revoke is safe
```

## Design Consequence

The `ice` source is sufficiently mapped to support future trace-only tags or
targeted probe decoders, but not behavior-changing enforcement.

The next device-facing design step should preserve the class split validated by
formal/0028:

```text
QueueBind
SubmitLedgerSKB
SubmitLedgerXDPFrame
SubmitLedgerXDPTxPagePool
SubmitLedgerAFXDP
DescriptorLedger
CompletionSettlement
QueueControl
RepresentorForward
ServiceWork
RevokeSemantics
```

No single generic netdev hook, workqueue hook, driver tracepoint, or Linux ring
object can serve as the authority root for these classes.
