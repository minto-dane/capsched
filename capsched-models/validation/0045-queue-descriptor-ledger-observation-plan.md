# Validation 0045: Queue/Descriptor Ledger Observation Plan

Status: Planned observation-only validation, not executed

Date: 2026-06-27

Related analysis:

```text
analysis/0051-linux-queue-descriptor-ledger-observation-plan.md
analysis/queue-descriptor-ledger-tags-v1.json
analysis/0049-e1000e-queuelease-source-map.md
analysis/0050-aggregate-queuelease-settlement-semantics.md
```

## Purpose

This validation plan checks whether the observation-only queue/descriptor
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

## Next Action

```text
N-071:
  Implement a small observation-only runner or static/probe readiness checker
  for the queue/descriptor ledger schema. Keep it outside enforcement paths.
```
