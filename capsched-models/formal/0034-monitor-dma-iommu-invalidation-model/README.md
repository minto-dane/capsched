# Monitor DMA/IOMMU Invalidation Model

Status: Checked with safe pass and expected unsafe counterexamples

Date: 2026-06-29

Related artifacts:

```text
analysis/0055-monitor-dma-iommu-memoryview-invalidation-source-map.md
analysis/monitor-dma-iommu-memoryview-invalidation-source-map-v1.json
formal/0033-monitor-irq-route-invalidation-model/
validation/0053-monitor-irq-route-invalidation-tlc.md
validation/0054-monitor-dma-iommu-invalidation-tlc.md
```

## Purpose

This model refines N-082:

```text
QueueLease IRQ route invalidation and QueueLease DMA reachability invalidation
are separate monitor receipts.
```

The model separates:

```text
IRQ route invalidation:
  delivery path safety; already modeled in formal/0033

driver DMA unmap:
  Linux cooperation and buffer teardown substrate

hardware queue quiescence:
  queue/ring stop observed in hardware or dominated by a stronger fence

HW-owned descriptor drain:
  old descriptors cannot still point hardware at revoked memory

access user release:
  iommufd/VFIO attached users have released pins or are quarantined

IOMMU translation removal:
  page-table/IOVA state change

IOTLB/device translation cache invalidation:
  stale DMA reachability removal

device DMA domain/PASID fence:
  detach/blocking-domain/old-epoch fence is distinct from per-IOVA unmap

outstanding DMA drain:
  no old write can still target pages to be reused

MemoryView unmap:
  old Domain no longer maps pages being transferred

PageOwner transfer:
  new Domain or allocator can receive the page only after receipt
```

## Modeled Hazards

```text
queue reassignment after IRQ invalidation alone
receipt after driver dma_unmap only
receipt after IOMMU unmap without IOTLB sync
receipt while queued flush remains pending
receipt without hardware queue quiescence, descriptor drain, access release,
or device DMA-domain fence
PageOwner transfer while DMA remains in flight
new MemoryView mapping before old view is unmapped and DMA-safe
normal completion delivery after revoke
packet page return before DMA invalidation receipt
```

## Checked Invariants

```text
NoReceiptWithoutFullDmaInvalidation
NoQueuedFlushAsReceipt
NoReassignWithoutDmaReceipt
NoPageOwnerTransferBeforeDmaSafe
NoNewMemoryViewBeforeOldUnmappedAndSynced
NoNormalDeliveryAfterRevoke
NoPacketReturnBeforeReceipt
NoReachableOldDmaAfterReassign
```

## Scope Limit

This is not a real NIC, IOMMU, VFIO, iommufd, or HyperTag Monitor model. It
does not model PCIe ordering, ATS/PRI/PASID, page-pool internals, AF_XDP UMEM
pinning, SWIOTLB, IOMMU driver error handling, or hardware drain latency.

It is a design filter:

```text
IRQ invalidation, driver unmap, IOMMU PTE removal, queued flush, IOTLB sync,
DMA drain, old MemoryView unmap, PageOwner transfer, and page return are
separate proof events.
None may be collapsed into "DMA revoked" by itself.
```
