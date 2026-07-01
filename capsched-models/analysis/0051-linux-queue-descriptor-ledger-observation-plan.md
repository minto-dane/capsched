# Analysis 0051: Linux Queue/Descriptor Ledger Observation Plan

Status: Draft observation-only plan, no enforcement approved

Date: 2026-06-27

Linux source:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
commit: 7cf0b1e415bcead8a2079c8be94a9d41aad7d462
```

Related artifacts:

```text
analysis/0045-workqueue-internal-redesign-boundary.md
analysis/0048-usbnet-workqueue-source-map.md
analysis/0049-e1000e-queuelease-source-map.md
analysis/0050-aggregate-queuelease-settlement-semantics.md
analysis/queue-descriptor-ledger-tags-v1.json
validation/0044-aggregate-queuelease-settlement-tlc.md
```

## Purpose

This plan defines an observation-only tag ledger for Linux queue and descriptor
paths. It is not an enforcement patch, not a user ABI, and not a protection
claim.

The goal is to learn whether Linux can expose enough semantic evidence to later
place QueueLease enforcement at the right boundaries:

```text
submit
DMA map
descriptor publish
tail doorbell
IRQ/NAPI completion
settlement
revoke/drop/quarantine
```

The plan exists because `analysis/0050` rejects two shortcuts:

```text
generic workqueue callback authority
single mutable caller BudgetTicket attached to a shared work_struct
```

## Answer To Internal-Only Redesign

Deep internal redesign is allowed and likely required. It is not enough by
itself.

Accepted:

```text
redesign internal network/device async paths into typed submit, batch,
completion, service, and revoke classes
make coalescing explicit instead of accidental
turn service work into budgetable service-domain execution
add internal ledger state that follows SKBs, descriptors, queues, and epochs
```

Rejected:

```text
worker identity as caller identity
last caller wins for a pending shared work item
generic internal callback as proof of caller authority
Linux-owned queue owner/IOMMU state as production authority root
claiming hypervisor-grade isolation without monitor-owned QueueTag/IOMMU roots
```

The right split is:

```text
Linux internal redesign:
  structured substrate and high-quality observation/accounting

Queue/descriptor ledger:
  proof-visible identity, merge, budget, completion, and revoke history

HyperTag Monitor:
  non-forgeable production root for QueueTag, IOMMU, epoch, and root budget
```

## Existing Observation Coverage

Existing upstream tracepoints provide useful outer visibility:

```text
include/trace/events/net.h:
  net_dev_queue
  net_dev_start_xmit
  net_dev_xmit
  net_dev_xmit_timeout
  netif_receive_skb
  netif_rx
  napi_gro_receive_entry/exit
  netif_receive_skb_entry/exit

include/trace/events/napi.h:
  napi_poll

include/trace/events/skb.h:
  kfree_skb
  consume_skb

include/trace/events/irq.h:
  irq_handler_entry
  irq_handler_exit

include/trace/events/iommu.h:
  map
  unmap

include/trace/events/dma.h:
  dma_map_sg
  dma_map_sg_err
  dma_unmap_sg
```

These tracepoints can show:

```text
SKB address and length at netdev queue/start/xmit
net namespace cookie
queue_mapping
NAPI poll work and budget
skb free/consume locations
IRQ handler execution
IOMMU map/unmap events
some scatter-gather DMA map/unmap events
```

They do not reliably show:

```text
driver ring identity as a QueueLease object
per-submit ledger identity
per-descriptor first/last indexes
descriptor publication as a semantic event
tail doorbell as a semantic event
batching caused by netdev_xmit_more()
which submit ledger owns an IOMMU/DMA map
which completion settles which ledger entry
revoke/drop/quarantine outcome
```

Therefore existing tracepoints are sufficient for outer correlation but
insufficient for semantic QueueLease proof.

## e1000e Source Anchors

The representative e1000e path shows the missing semantic points clearly:

```text
net/core/dev.c:4831
  trace_net_dev_queue(skb)

net/core/dev.c:3888
  trace_net_dev_start_xmit(skb, dev)

drivers/net/ethernet/intel/e1000e/netdev.c:5815 e1000_xmit_frame
  e1000_xmit_frame(skb, netdev)

drivers/net/ethernet/intel/e1000e/netdev.c:5585
  e1000_tx_map(tx_ring, skb, first, ...)

drivers/net/ethernet/intel/e1000e/netdev.c:5605
  dma_map_single(...)

drivers/net/ethernet/intel/e1000e/netdev.c:5640
  skb_frag_dma_map(...)

drivers/net/ethernet/intel/e1000e/netdev.c:5679
  e1000_tx_queue(tx_ring, tx_flags, count)

drivers/net/ethernet/intel/e1000e/netdev.c:5719-5722
  tx_desc fields receive DMA address, length, and command flags

drivers/net/ethernet/intel/e1000e/netdev.c:5742
  tx_ring->next_to_use = i

drivers/net/ethernet/intel/e1000e/netdev.c:5954 e1000_xmit_frame
  writel(tx_ring->next_to_use, tx_ring->tail)

drivers/net/ethernet/intel/e1000e/netdev.c:1228 e1000_clean_tx_irq
  e1000_clean_tx_irq(tx_ring)

drivers/net/ethernet/intel/e1000e/netdev.c:1277
  tx_ring->next_to_clean = i

drivers/net/ethernet/intel/e1000e/netdev.c:1279 e1000_clean_tx_irq
  netdev_completed_queue(netdev, pkts_compl, bytes_compl)

drivers/net/ethernet/intel/e1000e/netdev.c:2668
  e1000e_poll(napi, budget)
```

This shape suggests an observation ledger should begin near the driver-specific
queue object, not at generic `queue_work()`.

## Observation Ledger Objects

The observation plan uses three levels.

```text
QueueLedger:
  driver-visible queue/ring identity and epoch placeholder

SubmitLedger:
  one submitted packet/request or explicit batch

DescriptorLedger:
  one or more descriptors owned by a submit ledger
```

For L0 observation, these are not authority objects. They are tags.

Required property:

```text
ledger tags must never decide whether Linux is allowed to continue
```

The tags may be missing, sampled, or disabled. Missing tags are coverage gaps,
not fail-open security policy.

## Event Set

Minimum event kinds:

```text
queue_bind:
  netdev, driver queue/ring, napi, IRQ, and future QueueLease placeholder

submit_prepare:
  SKB/request enters a driver queue submit path

dma_map:
  SKB/request fragment maps for device access

desc_publish:
  driver writes one or more descriptors

doorbell:
  driver advances hardware-visible tail or equivalent queue kick

irq_entry:
  IRQ vector or handler associated with the queue fires

napi_poll:
  NAPI poll starts/ends with work and budget

completion_observed:
  hardware/device completion or descriptor done state is observed

settle:
  ledger accounting, DMA unmap, BQL/netdev accounting, delivery, or drop

revoke_start:
  queue/domain/epoch revoke begins

revoke_drop:
  outstanding submit/descriptor is dropped, quarantined, or refunded

revoke_finish:
  queue no longer has live old-epoch in-flight work
```

## Required Dimensions

Every event should carry fields from these dimensions where available:

```text
identity:
  event_seq, queue_ledger_id, submit_ledger_id, descriptor_ledger_id,
  skb_cookie, netdev_name, ifindex if available, driver_name

placement:
  cpu, numa node if available, queue_mapping, tx/rx queue index,
  napi pointer or id, irq number

authority placeholders:
  domain_id, domain_epoch, queue_epoch, queue_lease_id, service_domain,
  monitor_view_id

operation:
  event_kind, direction, byte_count, descriptor_count, first_desc, last_desc,
  xmit_more/batch flag, result

budget/performance:
  linux timestamp, batch size, NAPI budget/work, estimated hot-path cost,
  sampling state

trust:
  observation_only=true, authority_claim=false,
  linux_mutable=true, monitor_verified=false

revocation:
  revoke_epoch, revoke_reason, settle_outcome, quarantine/drop/refund marker
```

For L0, many authority placeholders will be zero or absent. That is expected.
The important rule is to reserve the fields now so the data model does not
pretend Linux-visible tags are future authority roots.

## Privacy And Safety Rules

Trace output should avoid turning observability into an information leak.

Default public trace should avoid raw values for:

```text
physical addresses
IOMMU IOVA values when not required
kernel pointers beyond ordinary tracefs policy
packet payload data
tenant/domain secrets
```

Preferred public forms:

```text
opaque local ids
monotonic per-CPU sequence numbers
hashed cookies where correlation is needed
lengths, counts, status, and queue indexes
```

Internal debug builds may keep richer data, but the analysis must label it as
debug-only and not suitable as a stable interface.

## Hot-Path Cost Rule

Observation must not distort the later performance conclusions.

Disabled path:

```text
no allocation
no string formatting
no locking beyond static-key/tracepoint disabled cost
no change to queueing behavior
```

Enabled path:

```text
bounded per-CPU writes or tracepoint emission
no sleeping in submit/IRQ/NAPI hot paths
sampling or per-queue enablement for high-rate devices
no mandatory global serialization
```

Any future trace-only patch must have a build/run validation separate from
security modeling.

## Existing-Trace First Stage

Before adding any Linux trace-only patch, use existing tracepoints and kprobes
where possible:

```text
net_dev_queue
net_dev_start_xmit
net_dev_xmit
napi_poll
irq_handler_entry/exit
kfree_skb
consume_skb
iommu map/unmap
dma scatter-gather map/unmap where available
```

Targeted kprobe/fprobe anchors for e1000e-like study:

```text
e1000_xmit_frame
e1000_tx_map
e1000_tx_queue
e1000_clean_tx_irq
e1000e_poll
```

Known limitations:

```text
inline/macros may not be probeable
tail doorbell write may require driver-specific source instrumentation
DMA map wrappers may collapse into generic mapping functions
existing tracepoint fields cannot reconstruct descriptor ledger identity
SKB pointer correlation may fail after clone/free/reuse boundaries
```

## Trace-Only Patch Stage

If existing trace cannot answer the semantic questions, introduce a later
`CONFIG_CAPSCHED_TRACE` or equivalent observation-only patch. Requirements:

```text
no behavior change
no scheduler policy change
no access-control decision
no stable user ABI claim
disabled by default
small driver-local helpers or tracepoints at semantic boundaries
separate validation proving disabled/enabled builds still boot
```

Initial candidate hooks:

```text
capsched_trace_queue_bind(...)
capsched_trace_submit_prepare(...)
capsched_trace_dma_map(...)
capsched_trace_desc_publish(...)
capsched_trace_doorbell(...)
capsched_trace_completion(...)
capsched_trace_settle(...)
capsched_trace_revoke(...)
```

The trace-only patch is still not enforcement. It is a measurement scaffold for
later QueueLease models.

## Hard Rejects

The observation plan rejects:

```text
generic workqueue CapSched enforcement from queue_work() alone
caller BudgetTicket stored mutably on a shared pending work_struct
driver service/reset/watchdog work charged to the last packet submitter
doorbell authority inferred from successful net_dev_xmit trace
DMA authority inferred from a Linux-owned dma_addr_t alone
completion delivery after revoke without ledger settlement
raw trace coverage treated as protection proof
```

## Success Criteria

The plan is successful when it can produce, for a representative driver:

```text
submit-to-doorbell trace chain with queue and descriptor identities
DMA map-to-submit correlation or explicit gap record
IRQ/NAPI-to-completion chain with queue identity
completion-to-settlement record
drop/quarantine/revoke outcome record or explicit unsupported gap
hot-path overhead estimate under disabled and enabled observation
clear statement that all results are observation-only
```

## Next Work

```text
N-071:
  Build an observation-only runner or static source-validation pass for the
  queue/descriptor ledger schema, starting with existing tracepoints and
  e1000e-like kprobe anchors. Do not add enforcement.

N-005:
  Apply the same source-map method to a modern multi-queue NIC path with
  MSI-X, XDP, page-pool, devlink, SR-IOV, or representor features.
```
