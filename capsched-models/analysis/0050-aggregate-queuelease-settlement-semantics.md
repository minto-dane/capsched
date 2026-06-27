# Analysis 0050: Aggregate QueueLease Settlement Semantics

Status: Draft semantics with TLC-backed design filter

Date: 2026-06-27

Related artifacts:

```text
analysis/0048-usbnet-workqueue-source-map.md
analysis/0049-e1000e-queuelease-source-map.md
formal/0027-aggregate-queuelease-settlement-model/
validation/0044-aggregate-queuelease-settlement-tlc.md
```

## Purpose

`usbnet` and `e1000e` show the same underlying issue from opposite sides:

```text
usbnet:
  shared work_struct callbacks merge completion/control state

e1000e:
  data-plane authority lives in ring/DMA/doorbell/IRQ/NAPI state, while
  workqueue callbacks are service/control paths
```

The design problem is therefore not:

```text
How do we attach the caller BudgetTicket to the work_struct?
```

The design problem is:

```text
How do we submit, merge, complete, revoke, and settle queue work without
turning a shared callback object into caller authority?
```

## Required Split

A network/device data-plane operation needs at least four distinct authority
objects:

```text
QueueLease:
  authority to advance a device queue, publish descriptors, or ring a doorbell

IOMMU/DMA grant:
  authority for the device to access specific packet/descriptor memory

In-flight ledger entry:
  per-submit or per-descriptor accounting state used by completion

Service budget:
  authority for driver/service code to perform merged completion and recovery
```

This is deliberately not one `BudgetTicket` attached to `work_struct`.

## Submit Boundary

From the `e1000e` map, the strongest submit boundary is:

```text
before DMA map
before descriptor publication
before tail doorbell
```

At that boundary CapSched-H must be able to prove:

```text
live QueueLease
fresh queue epoch
live queue budget/rate allowance
monitor-owned IOMMU permission for packet/descriptor memory
IRQ/NAPI route belongs to the queue owner or service Domain
ledger entry allocated before the device can complete
```

## Completion Boundary

Completion can be merged by:

```text
IRQ coalescing
NAPI poll budget
workqueue pending bit
driver done queues
watchdog/timer rescheduling
```

Completion therefore cannot use:

```text
last caller
current worker task
current kthread
work_struct owner
most recent queued carrier
```

as caller authority.

Instead, completion must settle against:

```text
descriptor/SKB/request ledger entry
queue lease epoch
queue owner/service identity
service budget
revocation state
```

## Revocation Rule

Queue revocation must close all outstanding authority roots together:

```text
submit budget/rate
descriptor publication
tail doorbell authority
IOMMU mapping
IRQ/NAPI delivery route
in-flight ledger entries
pending merged completion work
service delivery authority
```

After revoke, completion may be dropped or quarantined, but it must not deliver
as if the old queue owner still had authority.

## Model Result

Formal model 0027 checks this local rule:

```text
submit authority belongs at QueueLease/DMA/doorbell boundaries;
merged completion work performs aggregate settlement only.
```

The safe model permits:

```text
PrepareQueueLease
SubmitDescriptor
DeviceCompletionEvent
MergeDuplicateCompletionEvent
RunMergedCompletion
SettleCompletion
RevokeQueue
```

The unsafe models intentionally demonstrate:

```text
doorbell without lease
submit without budget
DMA without IOMMU/ledger
completion without ledger
completion without service budget
delivery after revoke
ledger overwrite while completion pending
ambient completion authority
foreign completion
```

## Linux Design Consequence

For L0 and L1:

```text
do not patch generic workqueue as the root of network data-plane authority
do not attach one mutable caller ticket to a shared work item
do not enforce from queue_work() API names alone
```

Future Linux prototypes should instead introduce, in separate slices:

```text
1. observation-only descriptor/queue accounting tags
2. typed per-submit ledger objects
3. service-domain completion budget accounting
4. queue revoke/drop/quarantine semantics
5. only then behavior-changing QueueLease submit gates
```

## Monitor-Backed Consequence

For CapSched-H, the HyperTag Monitor must eventually own:

```text
QueueTag/QueueLease epoch
IOMMU map
IRQ route
doorbell/rate budget, directly or through a sealed device-service endpoint
revocation ordering
```

Linux may cache and account queue state, but a Linux-only shadow queue owner or
shadow IOMMU map cannot create device authority.

## Remaining Gaps

This model is intentionally small. It does not yet prove:

```text
multi-queue NIC queue sharing
per-Domain RX demux
XDP/page-pool ownership
devlink/SR-IOV representor control
real IOMMU invalidation latency
interrupt remapping hardware behavior
all NAPI busy-poll and netpoll paths
GPU/NVMe queue-specific completion semantics
```

Those remain future device-specific proof obligations.
