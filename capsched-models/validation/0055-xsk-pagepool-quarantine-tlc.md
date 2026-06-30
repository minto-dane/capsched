# Validation 0055: XSK and Page-Pool Quarantine TLC

Status: Safe model passed; unsafe models produced expected counterexamples

Date: 2026-06-29

Model:

```text
capsched/capsched-models/formal/0035-xsk-pagepool-quarantine-model/XskPagePoolQuarantine.tla
```

Related artifacts:

```text
capsched/capsched-models/analysis/0056-xsk-pagepool-quarantine-source-map.md
capsched/capsched-models/analysis/xsk-pagepool-quarantine-source-map-v1.json
capsched/capsched-models/formal/0034-monitor-dma-iommu-invalidation-model/README.md
capsched/capsched-models/validation/0054-monitor-dma-iommu-invalidation-tlc.md
```

TLC logs:

```text
/media/nia/scsiusb/dev/linux-cap/build/tlc/xsk-pagepool-quarantine-20260630T012805Z/XskPagePoolQuarantineSafe.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/xsk-pagepool-quarantine-20260630T012805Z/XskPagePoolQuarantineUnsafeDoubleReturn.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/xsk-pagepool-quarantine-20260630T012805Z/XskPagePoolQuarantineUnsafeOwnerBeforeQuarantine.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/xsk-pagepool-quarantine-20260630T012805Z/XskPagePoolQuarantineUnsafePacketReturnNoDma.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/xsk-pagepool-quarantine-20260630T012805Z/XskPagePoolQuarantineUnsafePagePoolRecycle.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/xsk-pagepool-quarantine-20260630T012805Z/XskPagePoolQuarantineUnsafeReassignBeforeSettlement.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/xsk-pagepool-quarantine-20260630T012805Z/XskPagePoolQuarantineUnsafeReturnNoGeneration.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/xsk-pagepool-quarantine-20260630T012805Z/XskPagePoolQuarantineUnsafeXskCqSubmit.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/xsk-pagepool-quarantine-20260630T012805Z/XskPagePoolQuarantineUnsafeXskFreeListReturn.log
```

## Result Summary

Safe configuration:

```text
config: XskPagePoolQuarantineSafe.cfg
result: PASS
generated states: 11
distinct states: 11
search depth: 11
```

Unsafe configurations produced expected counterexamples:

```text
config: XskPagePoolQuarantineUnsafeXskCqSubmit.cfg
target invariant: NoXskCqSubmitAfterRevokeWithoutFreshEpoch
result: expected FAIL
generated states before violation: 6
distinct states before violation: 6

config: XskPagePoolQuarantineUnsafeXskFreeListReturn.cfg
target invariant: NoXskFreeListReturnAfterRevokeWithoutQuarantine
result: expected FAIL
generated states before violation: 6
distinct states before violation: 6

config: XskPagePoolQuarantineUnsafePagePoolRecycle.cfg
target invariant: NoPagePoolNormalRecycleAfterRevoke
result: expected FAIL
generated states before violation: 6
distinct states before violation: 6

config: XskPagePoolQuarantineUnsafePacketReturnNoDma.cfg
target invariant: NoPacketReturnBeforeDmaReceipt
result: expected FAIL
generated states before violation: 6
distinct states before violation: 6

config: XskPagePoolQuarantineUnsafeOwnerBeforeQuarantine.cfg
target invariant: NoPageOwnerTransferBeforeQuarantine
result: expected FAIL
generated states before violation: 7
distinct states before violation: 7

config: XskPagePoolQuarantineUnsafeReturnNoGeneration.cfg
target invariant: NoPacketReturnWithoutGenerationReset
result: expected FAIL
generated states before violation: 10
distinct states before violation: 10

config: XskPagePoolQuarantineUnsafeDoubleReturn.cfg
target invariant: NoDoubleReturn
result: expected FAIL
generated states before violation: 10
distinct states before violation: 10

config: XskPagePoolQuarantineUnsafeReassignBeforeSettlement.cfg
target invariant: NoReassignBeforeSettlement
result: expected FAIL
generated states before violation: 7
distinct states before violation: 7
```

## Validated Claims

This validation supports these local constraints:

```text
1. `xsk_tx_completed()` is user-visible completion delivery and must not run
   as normal old-epoch delivery after QueueLease revoke.

2. `xsk_buff_free()`/`xp_free()` is pool-visible buffer return and must not
   return old-epoch buffers to a stale XSK free-list.

3. page-pool direct/cache/ring recycle is not Domain/epoch authority and must
   not recycle revoked packet memory as normal same-epoch memory.

4. DMA/IOMMU/MemoryView receipt is necessary but not sufficient for normal
   packet return. Stale completion must be classified and quarantined or
   explicitly policy-delivered.

5. PageOwner transfer and packet memory return require stale XSK completion
   quarantine, page-pool quarantine, and packet generation reset/retag.

6. A packet memory object must not be returned twice through XSK and
   page-pool/PageOwner paths.

7. Queue reassignment requires stale packet-memory settlement.
```

## Unsafe Counterexample Meaning

`XskPagePoolQuarantineUnsafeXskCqSubmit.cfg` demonstrates old completion
delivery to the AF_XDP completion queue after revoke.

`XskPagePoolQuarantineUnsafeXskFreeListReturn.cfg` demonstrates stale XSK
buffer return to the pool free-list after revoke.

`XskPagePoolQuarantineUnsafePagePoolRecycle.cfg` demonstrates normal page-pool
recycle after revoke.

`XskPagePoolQuarantineUnsafePacketReturnNoDma.cfg` demonstrates packet return
before the N-082 DMA/IOMMU/MemoryView receipt.

`XskPagePoolQuarantineUnsafeOwnerBeforeQuarantine.cfg` demonstrates PageOwner
transfer before stale XSK/page-pool completion quarantine.

`XskPagePoolQuarantineUnsafeReturnNoGeneration.cfg` demonstrates packet memory
return without generation reset or retag.

`XskPagePoolQuarantineUnsafeDoubleReturn.cfg` demonstrates the same packet
memory returned through more than one settlement path.

`XskPagePoolQuarantineUnsafeReassignBeforeSettlement.cfg` demonstrates queue
reassignment before stale packet-memory settlement.

## Evidence Limits

This validation does not prove:

```text
real AF_XDP UMEM correctness
real xsk queue arithmetic
real page-pool recycle correctness
real ice NAPI/cleanup race freedom
real packet generation reset implementation
real HyperTag Monitor implementation correctness
```

Those remain implementation and monitor proof obligations.

## Design Consequence

The safe CapSched-H rule is:

```text
packet memory returned != xsk_tx_completed()
packet memory returned != xsk_buff_free()
packet memory returned != page_pool recycle
packet memory returned != DMA receipt alone

packet memory returned =
  DMA/IOMMU/MemoryView receipt
  + stale completion classification
  + XSK completion quarantine or explicit policy delivery
  + page-pool quarantine
  + packet generation reset/retag
  + single settlement path
```

Any future driver or monitor implementation plan must name how it obtains or
verifies this settlement before AF_XDP CQ submission, XSK free-list return,
page-pool recycle, PageOwner transfer, or queue reassignment after revoke.
