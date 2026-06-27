# Validation 0045: Queue/Descriptor Ledger Observation Plan

Status: Executed observation-only static readiness check

Date: 2026-06-27

Related analysis:

```text
analysis/0051-linux-queue-descriptor-ledger-observation-plan.md
analysis/queue-descriptor-ledger-tags-v1.json
analysis/0049-e1000e-queuelease-source-map.md
analysis/0050-aggregate-queuelease-settlement-semantics.md
```

## Purpose

This validation checks whether the observation-only queue/descriptor
ledger schema can be populated from current Linux tracepoints, source anchors,
and targeted kprobes/fprobes before any trace-only Linux patch is proposed.

It is not an enforcement test and not a protection proof.

## Non-Claims

The plan does not prove:

```text
QueueLease enforcement exists
IOMMU ownership is monitor protected
Linux trace tags are trustworthy against a compromised kernel
descriptor completion is safe after revoke
generic workqueue callbacks carry caller authority
```

It only measures semantic visibility and records gaps.

## Inputs

Existing tracepoints:

```text
net/net_dev_queue
net/net_dev_start_xmit
net/net_dev_xmit
napi/napi_poll
irq/irq_handler_entry
irq/irq_handler_exit
skb/consume_skb
skb/kfree_skb
iommu/map
iommu/unmap
dma/dma_map_sg
dma/dma_map_sg_err
dma/dma_unmap_sg
```

Targeted source or probe anchors for an e1000e-like representative:

```text
e1000_xmit_frame
e1000_tx_map
e1000_tx_queue
e1000_clean_tx_irq
e1000e_poll
tail doorbell source anchor
```

## Output Schema

The runner should emit two TSV outputs.

Event rows:

```text
event_seq
event_kind
phase
timestamp
cpu
driver_name
netdev_name
queue_ledger_id
submit_ledger_id
descriptor_ledger_id
skb_cookie_or_request_cookie
direction
byte_count
descriptor_count
first_desc
last_desc
result
observation_source
confidence
semantic_gap
```

Coverage rows:

```text
target_event_kind
observed
source_inferred
requires_trace_only_patch
requires_hardware
requires_driver_specific_map
gap_reason
```

Allowed confidence:

```text
observed
source_inferred
partially_observed
not_observed
not_trace_provable
```

## Pass Criteria

This validation passes only as an observation-readiness check if it can produce:

```text
queue/netdev/NAPI outer correlation
submit-to-doorbell chain or precise descriptor/doorbell gap record
DMA map-to-submit correlation or precise gap record
IRQ/NAPI-to-completion chain or precise gap record
settlement/delivery/drop observation or precise gap record
explicit statement that every event row is observation_only
```

The validation should fail or remain incomplete if it silently assumes:

```text
net_dev_xmit success equals descriptor doorbell
skb free/consume equals queue settlement
IOMMU map trace equals caller-owned DMA authority
worker/kthread context equals caller context
```

## Expected Result

Expected first result:

```text
existing tracepoints should cover outer network events and NAPI/IRQ shape
driver-specific source/probe anchors should be required for descriptor publish,
tail doorbell, and completion ledger identity
DMA-to-submit correlation is likely partial without driver-local tags
revoke/drop/quarantine remains mostly future CapSched trace-only work
```

This is acceptable. The validation is designed to discover gaps before we add
any behavior-changing QueueLease gate.

## Executed Result

Final run:

```text
run directory:
  /media/nia/scsiusb/dev/linux-cap/build/queue-descriptor-ledger-readiness/20260627T110900Z

tracepoints:
  /media/nia/scsiusb/dev/linux-cap/build/queue-descriptor-ledger-readiness/20260627T110900Z/tracepoint-inventory.tsv

source anchors:
  /media/nia/scsiusb/dev/linux-cap/build/queue-descriptor-ledger-readiness/20260627T110900Z/source-anchors.tsv

readiness:
  /media/nia/scsiusb/dev/linux-cap/build/queue-descriptor-ledger-readiness/20260627T110900Z/event-readiness.tsv

gaps:
  /media/nia/scsiusb/dev/linux-cap/build/queue-descriptor-ledger-readiness/20260627T110900Z/semantic-gaps.tsv
```

Outcome:

```text
status: observation_only_static_readiness
tracepoint_rows: 14
tracepoint_missing_rows: 0
source_anchor_rows: 25
source_anchor_missing_rows: 0
event_readiness_rows: 12
gap_rows: 8
```

Every readiness row carries:

```text
observation_only=true
authority_claim=false
monitor_verified=false
```

The result confirms that current Linux has useful outer visibility:

```text
net_dev_queue
net_dev_start_xmit
net_dev_xmit
net_dev_xmit_timeout
napi_poll
consume_skb
kfree_skb
irq_handler_entry
irq_handler_exit
iommu map/unmap
dma_map_sg/dma_map_sg_err/dma_unmap_sg
```

The representative e1000e source anchors were all found:

```text
netif_queue_set_napi RX/TX
request_irq MSI-X
e1000_xmit_frame
ndo_start_xmit binding
e1000_tx_map
dma_map_single
skb_frag_dma_map
e1000_tx_queue
tx_desc field writes
tail writel
e1000e_update_tdt_wa
e1000_intr_msi
e1000_intr_msix_tx
e1000_intr_msix_rx
e1000e_poll
e1000_clean_tx_irq
E1000_TXD_STAT_DD
e1000_put_txbuf
netdev_completed_queue
dev_consume_skb_any
driver down/reset and TX ring cleanup anchors
```

## Readiness Classification

The checker classified the event kinds as:

```text
partially_ready:
  queue_bind
  submit_prepare
  irq_entry
  napi_poll

partial_gap_recorded:
  dma_map
  settle

source_only_gap_recorded:
  desc_publish
  doorbell
  completion_observed

not_ready_future_capsched:
  revoke_start
  revoke_drop
  revoke_finish
```

This means existing tracepoints are enough to see the outer network/IRQ/NAPI
shape, but not enough to construct a semantic QueueLease proof.

## High-Severity Gaps

The checker records these high-severity gaps:

```text
submit-ledger-id:
  net tracepoints expose skbaddr and queue_mapping but no SubmitLedger id.

dma-submit-correlation:
  dma_map_single/skb_frag_dma_map anchors exist, but generic DMA/IOMMU traces
  do not tie maps to submit ledgers.

descriptor-publish:
  e1000_tx_queue writes descriptors, but there is no generic descriptor publish
  tracepoint.

tail-doorbell:
  tail writel exists and may be batched by netdev_xmit_more, but generic
  register probes are not semantic doorbells.

completion-ledger:
  e1000_clean_tx_irq observes descriptor done state, but generic skb/free
  events cannot reconstruct descriptor ledger settlement.

revoke-semantics:
  driver down/reset cleanup exists, but no CapSched queue revoke epoch or
  quarantine/drop outcome exists.

authority-root:
  all observed state is Linux-mutable and monitor_verified=false.
```

The `authority-root` gap is decisive. This validation output must not be used as
protection evidence. It is only evidence for where later observation tags,
models, or monitor-backed roots are needed.

## Next Action

```text
N-005:
  Apply the same source-map method to a modern multi-queue NIC path with MSI-X,
  XDP, page-pool, devlink, SR-IOV, or representor features.
```
