# Analysis 0055: Monitor DMA/IOMMU and MemoryView Invalidation Source Map

Status: Draft source map with model gate

Date: 2026-06-29

Related artifacts:

```text
analysis/0053-ice-modern-nic-revoke-source-map.md
analysis/0054-monitor-irq-route-invalidation-source-map.md
formal/0031-modern-nic-queue-revoke-model/
formal/0033-monitor-irq-route-invalidation-model/
validation/0050-modern-nic-queue-revoke-tlc.md
validation/0053-monitor-irq-route-invalidation-tlc.md
```

## Purpose

N-081 separated IRQ route invalidation from Linux-visible teardown such as
VFIO eventfd detach, `free_irq()`, MSI vector free, and IRTE clear. N-082 maps
the next required boundary:

```text
IRQ route revoked does not imply DMA reachability revoked.
```

A modern NIC QueueLease revoke is not complete until old descriptors cannot
trigger new DMA, outstanding DMA has drained or remains quarantined away from
reuse, old IOMMU translations and stale IOTLB reachability are gone, old
MemoryView mappings are removed, and packet pages cannot be returned or mapped
to a new Domain before that receipt exists.

This is not an implementation plan and not protection evidence.

## Core Rule

For CapSched-H:

```text
DMA reachability is a monitor-owned QueueLease sub-authority.
```

Linux `dma_unmap_*()`, VFIO DMA unmap, iommufd IOAS unmap, IOMMU core unmap,
driver ring cleanup, and XSK pool DMA unmap are substrate and observation
points. They are not the production authority root.

The minimal monitor-backed revoke ordering is:

```text
1. Establish that the monitor owns the DMA root being reasoned about:
     RID/PASID/domain attachment or equivalent device DMA authority.
2. Begin QueueLease epoch revoke and block new submit, descriptor, XSK buffer,
   access pin, and MemoryView borrow effects.
3. Invalidate the IRQ route separately; do not treat that as DMA revoke.
4. Stop device queue DMA publication:
     descriptor publication disabled
     tail doorbell effects blocked
     queue/ring stop observed in hardware, or a stronger reset/blocking-domain
     event exists
5. Drain HW-owned descriptors that still point at revoked memory.
6. Unmap driver-visible DMA buffers and XSK/UMEM mappings.
7. Notify and release iommufd/VFIO access users before unpin/reuse.
8. Remove IOMMU/iommufd/VFIO IOVA translations for the old QueueTag.
9. Complete IOTLB or equivalent device-translation-cache invalidation.
10. Fence or block the device DMA domain/PASID for the old epoch.
11. Drain outstanding DMA or keep affected pages quarantined and unmapped.
12. Remove old Domain MemoryView mappings for affected pages.
13. Issue a monitor-visible DMA invalidation receipt.
14. Only then transfer PageOwner, return packet pages, or reassign the queue
    under a new QueueLease epoch.
```

## Source Anchors

### Intel ice queue and XSK teardown

Useful anchors:

```text
drivers/net/ethernet/intel/ice/ice_txrx.c:
  ice_unmap_and_free_tx_buf()                 line 114
  ice_clean_tx_ring()                         line 203
  ice_clean_rx_ring()                         line 538

drivers/net/ethernet/intel/ice/ice_xsk.c:
  ice_qvec_dis_irq()                          line 48
  xsk_pool_dma_unmap(pool, ICE_RX_DMA_ATTR)   line 131
  xsk_pool_dma_map(pool, ..., ICE_RX_DMA_ATTR)

drivers/net/ethernet/intel/ice/ice_base.c:
  ice_qp_dis()                                line 1436
  ice_vsi_ctrl_one_rx_ring(..., false)        line 1474

drivers/net/ethernet/intel/ice/ice_lib.c:
  ice_vsi_ctrl_all_rx_rings()                 line 47

drivers/net/ethernet/intel/ice/ice_main.c:
  ice_down()
  ice_vsi_dis_irq()
  ice_vsi_close()
```

Interpretation:

```text
ice can clean TX/RX rings, unmap SKB/XDP DMA buffers through DMA API paths,
and unmap AF_XDP pools through xsk_pool_dma_unmap().
```

These are required cooperation points. They do not prove that:

```text
old IOMMU translations are gone
stale IOTLB/device translation-cache entries are gone
outstanding device DMA has drained
old packet pages are not visible in the old MemoryView
old packet pages have not been returned to another Domain too early
```

The `ice_qp_dis()` path is a useful warning sign for modeling: it masks IRQ,
disables NAPI, stops TX rings, then requests one RX ring disable with
`wait=false` before cleaning rings. That may be appropriate for Linux's driver
semantics, but it is not by itself a monitor-grade hardware quiescence proof.
By contrast, the all-RX helper documents a flush/wait verification path. A
CapSched-H receipt must name which hardware-observed queue quiescence event it
relies on.

Forbidden shortcut:

```text
Do not treat ice ring cleanup, netdev down/reset, or XSK pool DMA unmap alone
as QueueLease DMA revoke authority.
```

### Linux DMA API and IOMMU DMA layer

Useful anchors:

```text
drivers/iommu/iommu.c:
  __iommu_group_set_core_domain()  line 2151
  domain-switch old/new-only rule  line 2485
  iommu_unmap()       line 2817
  iommu_unmap_fast()  line 2850

include/linux/iommu.h:
  iommu_iotlb_sync()  line 1012

drivers/iommu/dma-iommu.c:
  fq_flush_iotlb()                 line 174
  queue_iova()                     line 197
  dma_iova_link() caller sync rule line 1964
  dma_iova_sync()                  line 2017
  __iommu_dma_iova_unlink()        line 2071
  iommu_unmap_fast(...)
  iommu_iotlb_sync(...)
  iommu_dma_free_iova(...)
```

Interpretation:

```text
iommu_unmap() removes mappings and calls iommu_iotlb_sync().
iommu_unmap_fast() intentionally omits IOTLB sync for batched callers.
The DMA API path can use iommu_unmap_fast(); if the gather is not queued it
calls iommu_iotlb_sync(), otherwise flush completion can be delayed through
the IOVA flush queue.
```

The queued flush path is performance substrate. It must not be treated as a
monitor receipt until the relevant flush has completed for the old QueueTag and
MemoryView.

The group-domain path is also a warning sign: core code returns a group to a
blocking domain only while an owner exists; otherwise it returns to the default
DMA domain. Therefore `detach` or "back to core domain" is not automatically a
blocked-DMA proof. A production receipt must identify the monitor-owned
RID/PASID/domain transition or an equivalent fence.

Forbidden shortcut:

```text
Do not treat iommu_unmap_fast(), queued IOVA free, or driver dma_unmap return
as proof that stale device translations can no longer reach old pages.
```

### iommufd

Useful anchors:

```text
drivers/iommu/iommufd/device.c:
  iommufd_device_unbind()          line 334
  iommufd_hw_pagetable_detach()
  iommufd_device_detach()          line 1055
  iommufd_access_notify_unmap()    line 1299

drivers/iommu/iommufd/ioas.c:
  iommufd_ioas_unmap()             line 340

drivers/iommu/iommufd/io_pagetable.c:
  iopt_unmap_iova_range()          line 741
  iopt_unmap_iova()                line 852
  iopt_unmap_all()                 line 862

drivers/iommu/iommufd/pages.c:
  iommu_unmap_nofail()             line 225
  dmabuf revoke/unmap checks       line 1440
  unmap-before-unpin comment       line 1761
  iopt_area_unmap_domain()         line 1814
  iopt_area_unfill_domains()       line 2001
```

Interpretation:

```text
iommufd separates device ownership, device detach, IOAS unmap, access-user
notification, domain unfill, and page unpin/release paths.
```

The comments around `iommufd_access_notify_unmap()` are especially important:
drivers with attached users must stop using pages before unmap completes. This
is a useful Linux cooperation rule, not a substitute for a hostile-kernel-safe
monitor receipt.

iommufd's page code also records the essential ordering principle: pages must
not be unpinned while still DMA mapped. CapSched-H should generalize this to:
pages must not be returned, transferred, or mapped into a new Domain while old
DMA reachability can remain.

Forbidden shortcut:

```text
Do not treat iommufd IOAS unmap or device detach as final CapSched-H DMA revoke
unless the monitor can verify the corresponding IOMMU, IOTLB, PageOwner, and
MemoryView state.
```

### VFIO type1

Useful anchors:

```text
drivers/vfio/vfio_iommu_type1.c:
  unmap_unpin_fast()
  unmap_unpin_slow()
  vfio_unmap_unpin()        line 1147
  vfio_notify_dma_unmap()   line 1367
  vfio_dma_do_unmap()       line 1391
  vfio_remove_dma()
```

Interpretation:

```text
VFIO type1 explicitly separates fast unmap, slow unmap, batched sync/unpin,
driver dma_unmap callbacks, and mapping removal.
```

`vfio_notify_dma_unmap()` requires attached device drivers to unpin pages in
response to invalidation. The unmap path then removes IOMMU mappings and unpins
pages. This is a useful semantic template for CapSched service cooperation.

VFIO's own comment that other domains must be unmapped first so there are no
IOMMU translations remaining when pages are unpinned is exactly the kind of
ordering CapSched-H must make monitor-visible.

Forbidden shortcut:

```text
Do not treat VFIO dma_unmap callbacks, unpin, or the userspace ioctl return as
the monitor-owned PageOwner transfer proof.
```

### Architecture IOMMU drivers

Useful anchors:

```text
drivers/iommu/intel/iommu.c:
  intel_iommu_iotlb_sync_map()
  cache_tag_flush_range_np()

drivers/iommu/amd/iommu.c:
  amd_iommu_iotlb_sync()
  amd_iommu_domain_flush_pages()
```

Interpretation:

```text
IOMMU invalidation details are architecture- and driver-specific. CapSched-H
must name which lower-level invalidation event becomes the monitor receipt for
a given hardware backend.
```

## Required Invalidation Receipt

A production QueueLease DMA invalidation receipt must cover:

```text
QueueTag and queue epoch:
  old submit and doorbell effects cannot publish descriptors.

Monitor DMA root:
  the monitor owns or verifies the RID/PASID/domain attachment being revoked.

New work embargo:
  no new descriptors, XSK buffers, access pins, or MemoryView borrows can enter
  the old epoch.

Descriptor visibility:
  old descriptors cannot be consumed for new DMA.

Hardware quiescence:
  queue stop is observed in hardware or dominated by a stronger reset/fence;
  HW-owned descriptors that point at revoked memory have drained.

Driver DMA teardown:
  SKB/XDP/XSK/UMEM mappings are torn down or quarantined as appropriate.

Access users:
  iommufd/VFIO access users are notified and have released pins or are
  quarantined before page reuse.

IOMMU translation removal:
  old IOVA translations for the old QueueTag/MemoryView are removed.

IOTLB/device-translation-cache invalidation:
  stale cached translations are flushed, not merely scheduled for later flush.

Outstanding DMA:
  no in-flight write can reach pages that will be returned or reassigned.

MemoryView:
  old Domain view no longer maps pages that are being transferred or reused.

PageOwner:
  ownership transfer happens only after the receipt.

Completion/quarantine:
  stale completions cannot deliver normal packet ownership after revoke.
```

## Design Consequence

The safe CapSched-H rule is:

```text
DMA revoked != IRQ route revoked
DMA revoked != ice ring cleanup
DMA revoked != dma_unmap_*() return
DMA revoked != xsk_pool_dma_unmap() return
DMA revoked != VFIO dma_unmap callback
DMA revoked != iommufd IOAS unmap alone
DMA revoked != iommu_unmap_fast()
DMA revoked != queued IOVA flush

DMA revoked =
  old QueueLease epoch revoked
  + monitor-owned DMA root established
  + new work embargo active
  + descriptor/doorbell publication stopped
  + hardware queue quiescence observed
  + HW-owned descriptors drained
  + driver DMA mappings torn down or quarantined
  + access users released or quarantined
  + IOMMU translations removed
  + IOTLB/device translation cache invalidated
  + device DMA domain/PASID fenced for the old epoch
  + outstanding DMA drained
  + stale completions quarantined
  + old MemoryView mappings removed
  + monitor-visible invalidation receipt
```

Any future implementation plan must specify how this receipt is obtained for
the hardware backend before old packet pages, queues, or IOVAs are reused by a
new Domain.
