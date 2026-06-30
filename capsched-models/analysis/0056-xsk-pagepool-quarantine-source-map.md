# Analysis 0056: XSK and Page-Pool Quarantine Source Map

Status: Draft source map with model gate

Date: 2026-06-29

Related artifacts:

```text
analysis/0052-ice-modern-nic-queuelease-source-map.md
analysis/0053-ice-modern-nic-revoke-source-map.md
analysis/0055-monitor-dma-iommu-memoryview-invalidation-source-map.md
formal/0029-xdp-afxdp-memory-ownership-model/
formal/0034-monitor-dma-iommu-invalidation-model/
validation/0048-xdp-afxdp-memory-ownership-tlc.md
validation/0054-monitor-dma-iommu-invalidation-tlc.md
```

## Purpose

N-082 established that DMA/IOMMU/MemoryView invalidation is a monitor-visible
receipt and not an IRQ or driver cleanup shortcut. N-083 maps the next narrow
hazard:

```text
After revoke, stale packet-memory completion must not become normal user-visible
or pool-visible return.
```

This is especially sharp for AF_XDP and page-pool paths. Linux uses fast
completion and recycling mechanisms for performance. CapSched-H must preserve
that performance path when the queue epoch is fresh, but after revoke it must
distinguish:

```text
settle old outstanding state:
  needed to avoid leaks and make progress

normal completion delivery:
  user-visible or pool-visible authority return

quarantine:
  old-epoch memory/control effect is absorbed without granting old authority
```

This is not an implementation plan and not protection evidence.

## Core Rule

For CapSched-H:

```text
DMA receipt makes memory unreachable to the old device path.
It does not automatically authorize normal XSK/page-pool return.
```

Normal return of packet memory after revoke requires:

```text
fresh QueueLease or explicit quarantine-settlement rule
fresh XSK/page-pool epoch
DMA/IOMMU/MemoryView receipt
stale completion settlement
packet generation reset or equivalent poisoning/retagging
no double-return across XSK/page-pool/page-owner paths
```

## Source Anchors

### Intel ice AF_XDP completion and cleanup

Useful anchors:

```text
drivers/net/ethernet/intel/ice/ice_xsk.c:
  ice_clean_xdp_irq_zc()       line 363
  xsk_buff_free(...)           line 398
  xsk_tx_completed(...)        line 414
  ice_xmit_zc()                line 791
  xsk_tx_peek_release_desc_batch(...) line 807
  ice_xsk_clean_rx_ring()      line 897
  ice_xsk_clean_xdp_ring()     line 916
  xsk_tx_completed(...) during cleanup line 940

drivers/net/ethernet/intel/ice/ice_txrx.c:
  ice_clean_tx_ring() XSK branch       line 208
  ice_clean_rx_ring() XSK branch       line 542
```

Interpretation:

```text
ice submits AF_XDP Tx completions through xsk_tx_completed().
ice also calls xsk_tx_completed() from XSK ring cleanup.
ice returns XSK buffers with xsk_buff_free().
```

These are normal Linux lifetime and completion mechanisms. CapSched-H must not
interpret them as proof that the old queue epoch is safe to expose.

Forbidden shortcut:

```text
Do not treat xsk_tx_completed() after revoke as normal user-visible authority
return unless a fresh XSK/QueueLease epoch or quarantine-settlement rule exists.
```

### AF_XDP core

Useful anchors:

```text
net/xdp/xsk.c:
  xsk_tx_completed()                 line 500
  xskq_prod_submit_n(pool->cq, ...)  line 502
  xsk_tx_peek_release_desc_batch()   line 577
  completion queue reservation       line 593
  xskq_prod_write_addr_batch(...)    line 612

include/net/xdp_sock_drv.h:
  xsk_pool_dma_unmap() wrapper       line 92
  xsk_buff_alloc_batch() wrapper     line 131
  xsk_buff_free() wrapper            line 141

net/xdp/xsk_buff_pool.c:
  xp_alloc_batch() release FQ entries line 636
  xp_free() free-list return          line 718
```

Interpretation:

```text
AF_XDP Tx reserves completion-queue space/address when descriptors are consumed.
Later xsk_tx_completed() submits the completion count to the user-visible CQ.
xsk_buff_free() returns buffers to the pool free-list.
```

For CapSched-H, those must be separated:

```text
reserve old completion:
  old outstanding ledger exists

submit old completion to CQ:
  user-visible delivery; forbidden after revoke unless explicitly allowed

free XSK buffer:
  pool-visible memory reuse; forbidden after revoke unless quarantine-settled
```

### Page pool

Useful anchors:

```text
net/core/page_pool.c:
  page_pool_return_netmem()          line 756
  __page_pool_put_page()             line 830
  page_pool_dma_sync_for_device()    line 847
  page_pool_put_unrefed_netmem()     line 903
  page_pool_scrub()                  line 1144
  disable dma_sync before unmap      line 1160
  synchronize_net() before unmap     line 1167
  page_pool_release()                line 1182
```

Interpretation:

```text
page_pool can recycle pages to direct cache/ring or return/free them. It also
has careful DMA sync and destroy-time scrub ordering.
```

CapSched-H must distinguish:

```text
page_pool recycle:
  efficient same-epoch reuse

page_pool return/free:
  allocator-visible release

quarantine:
  old-epoch page held until DMA receipt, generation reset, and PageOwner policy
```

Forbidden shortcut:

```text
Do not treat page_pool recycle eligibility as Domain/epoch return authority.
```

## Required Quarantine Receipt

A production stale packet-memory settlement receipt must cover:

```text
Queue epoch:
  the old QueueLease epoch is revoked and cannot accept new submit.

DMA receipt:
  N-082 DMA/IOMMU/MemoryView receipt exists.

Completion classification:
  stale XSK/page-pool completion is classified as quarantine settlement, not
  normal delivery.

XSK completion queue:
  old reserved completions are either dropped/quarantined/settled internally or
  delivered only through an explicit policy endpoint; they are not silently
  submitted to the old CQ.

XSK buffer free-list:
  old buffers are not returned to pool free-list while XSK pool epoch is stale.

Page-pool recycle:
  old pages are not recycled through direct cache/ring while page-pool epoch is
  stale.

Packet generation:
  memory returned to a Domain or allocator has a fresh generation, poison, or
  equivalent retag.

Single settlement:
  one old packet memory object cannot be returned through both XSK and
  page-pool/PageOwner paths.
```

## Design Consequence

The safe CapSched-H rule is:

```text
packet memory returned != xsk_tx_completed()
packet memory returned != xsk_buff_free()
packet memory returned != page_pool recycle
packet memory returned != page unpin/refcount release
packet memory returned != DMA receipt alone

packet memory returned =
  DMA/IOMMU/MemoryView receipt
  + stale completion classified
  + stale completion quarantined or explicitly policy-delivered
  + XSK/page-pool epoch fresh or quarantine-settled
  + packet generation reset/retag
  + no double return
```

Future implementation work must name how XSK CQ completion, XSK free-list
return, page-pool recycle, PageOwner transfer, and packet generation reset are
correlated before exposing packet memory to any Domain after revoke.
