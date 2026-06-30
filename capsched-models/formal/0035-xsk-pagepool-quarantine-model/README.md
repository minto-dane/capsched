# XSK and Page-Pool Quarantine Model

Status: Checked with safe pass and expected unsafe counterexamples

Date: 2026-06-29

Related artifacts:

```text
analysis/0056-xsk-pagepool-quarantine-source-map.md
analysis/xsk-pagepool-quarantine-source-map-v1.json
formal/0034-monitor-dma-iommu-invalidation-model/
validation/0054-monitor-dma-iommu-invalidation-tlc.md
validation/0055-xsk-pagepool-quarantine-tlc.md
```

## Purpose

This model refines N-083:

```text
After QueueLease revoke, stale XSK/page-pool packet-memory completion must be
quarantined or explicitly policy-delivered. It must not silently become normal
user-visible completion or pool-visible memory return.
```

The model separates:

```text
XSK CQ reservation:
  AF_XDP Tx path has reserved completion space/address for outstanding work.

XSK CQ submit:
  user-visible completion delivery through xsk_tx_completed().

XSK free-list return:
  pool-visible buffer reuse through xsk_buff_free()/xp_free().

Page-pool recycle:
  direct/cache/ring reuse through page_pool paths.

DMA receipt:
  N-082 memory reachability revocation receipt.

Quarantine settlement:
  old completion is absorbed and made non-deliverable under old authority.

Packet generation reset:
  memory is retagged/poisoned before it is returned to a Domain or allocator.
```

## Modeled Hazards

```text
XSK CQ submit after revoke
XSK free-list return after revoke
page-pool normal recycle after revoke
packet return before DMA receipt
PageOwner transfer before XSK/page-pool quarantine
packet return without generation reset
double return through XSK and page-pool/PageOwner paths
queue reassignment before stale packet-memory settlement
```

## Checked Invariants

```text
NoXskCqSubmitAfterRevokeWithoutFreshEpoch
NoXskFreeListReturnAfterRevokeWithoutQuarantine
NoPagePoolNormalRecycleAfterRevoke
NoPacketReturnBeforeDmaReceipt
NoPageOwnerTransferBeforeQuarantine
NoPacketReturnWithoutGenerationReset
NoDoubleReturn
NoReassignBeforeSettlement
NoOutstandingAfterReassign
```

## Scope Limit

This is not a real AF_XDP, page-pool, or `ice` implementation model. It does
not model UMEM chunk layout, multi-buffer packets, page fragments, real CQ/FQ
ring arithmetic, NAPI budget races, or page-pool destroy retries.

It is a design filter:

```text
xsk_tx_completed(), xsk_buff_free(), page_pool recycle, DMA receipt, and
PageOwner transfer are separate proof events.
None may be collapsed into "packet memory safely returned" by itself.
```
