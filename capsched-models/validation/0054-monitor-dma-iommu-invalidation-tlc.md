# Validation 0054: Monitor DMA/IOMMU Invalidation TLC

Status: Safe model passed; unsafe models produced expected counterexamples

Date: 2026-06-29

Model:

```text
capsched/capsched-models/formal/0034-monitor-dma-iommu-invalidation-model/MonitorDmaIommuInvalidation.tla
```

Related artifacts:

```text
capsched/capsched-models/analysis/0055-monitor-dma-iommu-memoryview-invalidation-source-map.md
capsched/capsched-models/analysis/monitor-dma-iommu-memoryview-invalidation-source-map-v1.json
capsched/capsched-models/formal/0033-monitor-irq-route-invalidation-model/README.md
capsched/capsched-models/validation/0053-monitor-irq-route-invalidation-tlc.md
```

TLC logs:

```text
/media/nia/scsiusb/dev/linux-cap/build/tlc/monitor-dma-iommu-invalidation-20260630T010946Z/MonitorDmaIommuInvalidationSafe.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/monitor-dma-iommu-invalidation-20260630T010946Z/MonitorDmaIommuInvalidationUnsafeCompletionAfterRevoke.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/monitor-dma-iommu-invalidation-20260630T010946Z/MonitorDmaIommuInvalidationUnsafeDriverUnmapOnlyReceipt.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/monitor-dma-iommu-invalidation-20260630T010946Z/MonitorDmaIommuInvalidationUnsafeIommuUnmapNoIotlbSync.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/monitor-dma-iommu-invalidation-20260630T010946Z/MonitorDmaIommuInvalidationUnsafeIrqOnlyReassign.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/monitor-dma-iommu-invalidation-20260630T010946Z/MonitorDmaIommuInvalidationUnsafeNewMemoryViewBeforeOldUnmapped.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/monitor-dma-iommu-invalidation-20260630T010946Z/MonitorDmaIommuInvalidationUnsafePacketReturnBeforeReceipt.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/monitor-dma-iommu-invalidation-20260630T010946Z/MonitorDmaIommuInvalidationUnsafePageOwnerInFlight.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/monitor-dma-iommu-invalidation-20260630T010946Z/MonitorDmaIommuInvalidationUnsafeQueuedFlushReceipt.log
```

## Result Summary

Safe configuration:

```text
config: MonitorDmaIommuInvalidationSafe.cfg
result: PASS
generated states: 17
distinct states: 17
search depth: 17
```

Unsafe configurations produced expected counterexamples:

```text
config: MonitorDmaIommuInvalidationUnsafeIrqOnlyReassign.cfg
target invariant: NoReassignWithoutDmaReceipt
result: expected FAIL
generated states before violation: 6
distinct states before violation: 6

config: MonitorDmaIommuInvalidationUnsafeDriverUnmapOnlyReceipt.cfg
target invariant: NoReceiptWithoutFullDmaInvalidation
result: expected FAIL
generated states before violation: 7
distinct states before violation: 7

config: MonitorDmaIommuInvalidationUnsafeIommuUnmapNoIotlbSync.cfg
target invariant: NoReceiptWithoutFullDmaInvalidation
result: expected FAIL
generated states before violation: 10
distinct states before violation: 10

config: MonitorDmaIommuInvalidationUnsafeQueuedFlushReceipt.cfg
target invariant: NoQueuedFlushAsReceipt
result: expected FAIL
generated states before violation: 10
distinct states before violation: 10

config: MonitorDmaIommuInvalidationUnsafePageOwnerInFlight.cfg
target invariant: NoPageOwnerTransferBeforeDmaSafe
result: expected FAIL
generated states before violation: 13
distinct states before violation: 13

config: MonitorDmaIommuInvalidationUnsafeNewMemoryViewBeforeOldUnmapped.cfg
target invariant: NoNewMemoryViewBeforeOldUnmappedAndSynced
result: expected FAIL
generated states before violation: 13
distinct states before violation: 13

config: MonitorDmaIommuInvalidationUnsafeCompletionAfterRevoke.cfg
target invariant: NoNormalDeliveryAfterRevoke
result: expected FAIL
generated states before violation: 5
distinct states before violation: 5

config: MonitorDmaIommuInvalidationUnsafePacketReturnBeforeReceipt.cfg
target invariant: NoPacketReturnBeforeReceipt
result: expected FAIL
generated states before violation: 15
distinct states before violation: 15
```

## Validated Claims

This validation supports these local constraints:

```text
1. Queue reassignment requires a monitor-visible DMA invalidation receipt,
   not only an IRQ invalidation receipt.

2. A DMA invalidation receipt requires all modeled pieces:
     old queue epoch revoked
     monitor-owned DMA root established
     new-work embargo established
     IRQ invalidated as a separate prerequisite
     descriptor and device DMA publication stopped
     hardware queue quiescence observed or dominated by stronger fence
     HW-owned descriptors drained
     driver DMA teardown observed
     iommufd/VFIO access users released or quarantined
     iommufd/IOMMU unmap observed
     IOMMU translation removed
     IOTLB or equivalent stale-translation invalidation completed
     queued flush no longer pending
     old device DMA domain/PASID fenced
     outstanding DMA drained
     stale completions quarantined
     old MemoryView unmapped

3. Driver `dma_unmap_*()`/XSK unmap/VFIO callback style teardown is not
   sufficient by itself.

4. `iommu_unmap_fast()` or queued IOVA flush cannot be treated as the receipt.
   The stale translation invalidation must be complete.

5. PageOwner transfer, new MemoryView mapping, packet page return, and queue
   reassignment are all downstream of the DMA receipt.

6. Stale completion delivery after revoke remains unsafe unless quarantined.
```

## Unsafe Counterexample Meaning

`MonitorDmaIommuInvalidationUnsafeIrqOnlyReassign.cfg` demonstrates queue
reuse after IRQ invalidation while DMA reachability has not been revoked.

`MonitorDmaIommuInvalidationUnsafeDriverUnmapOnlyReceipt.cfg` demonstrates a
false receipt after driver DMA teardown while IOMMU reachability remains.

`MonitorDmaIommuInvalidationUnsafeIommuUnmapNoIotlbSync.cfg` demonstrates a
false receipt after translation removal but before stale translation-cache
invalidation.

`MonitorDmaIommuInvalidationUnsafeQueuedFlushReceipt.cfg` demonstrates treating
a queued flush request as if it were a completed invalidation.

`MonitorDmaIommuInvalidationUnsafePageOwnerInFlight.cfg` demonstrates moving a
page to a new owner while the old device can still have in-flight DMA.

`MonitorDmaIommuInvalidationUnsafeNewMemoryViewBeforeOldUnmapped.cfg`
demonstrates mapping the page into a new Domain while the old MemoryView or old
DMA reachability remains live.

`MonitorDmaIommuInvalidationUnsafeCompletionAfterRevoke.cfg` demonstrates
normal stale completion delivery after revoke.

`MonitorDmaIommuInvalidationUnsafePacketReturnBeforeReceipt.cfg` demonstrates
packet page return before the monitor receipt exists.

## Evidence Limits

This validation does not prove:

```text
real IOMMU driver correctness
real IOTLB or device translation-cache latency
PCIe ATS/PRI/PASID behavior
real NIC queue stop/drain behavior
real page-pool or AF_XDP UMEM lifecycle correctness
real MemoryView implementation correctness
real HyperTag Monitor implementation correctness
```

Those remain implementation and monitor proof obligations.

## Design Consequence

The safe CapSched-H rule is:

```text
DMA revoked != IRQ revoked
DMA revoked != driver dma_unmap
DMA revoked != XSK pool DMA unmap
DMA revoked != VFIO dma_unmap callback
DMA revoked != iommufd IOAS unmap
DMA revoked != iommu_unmap_fast
DMA revoked != queued flush request

DMA revoked =
  QueueLease epoch revoked
  + monitor-owned DMA root established
  + new-work embargo active
  + descriptor/doorbell publication stopped
  + hardware queue quiescence observed
  + HW-owned descriptors drained
  + driver DMA teardown observed
  + access users released or quarantined
  + IOMMU translation removed
  + completed IOTLB/equivalent invalidation
  + old device DMA domain/PASID fenced
  + outstanding DMA drained
  + stale completions quarantined
  + old MemoryView unmapped
  + monitor-visible invalidation receipt
```

Any future driver or monitor implementation plan must name how it obtains or
verifies this receipt before PageOwner transfer, packet page return, new
MemoryView mapping, or queue reassignment.
