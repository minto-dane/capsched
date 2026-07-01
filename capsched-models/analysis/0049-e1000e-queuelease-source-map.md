# Analysis 0049: e1000e QueueLease Source Map

Status: Draft representative Ethernet source map, no implementation approved

Date: 2026-06-27

Linux source:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
commit: 7cf0b1e415bcead8a2079c8be94a9d41aad7d462
```

Related artifacts:

```text
analysis/0016-device-iommu-queue-lease-map.md
analysis/0047-drivers-net-workqueue-origin-map.md
analysis/0048-usbnet-workqueue-source-map.md
analysis/e1000e-queuelease-source-map-v1.json
```

## Purpose

`usbnet` showed that merged network workqueue callbacks must not be treated as
caller authority. `e1000e` is a more representative Ethernet driver for
QueueLease placement because its data path is ring/IRQ/NAPI based.

This note maps:

```text
TX submit path
DMA mapping and descriptor ring state
doorbell/tail write
IRQ and NAPI completion path
service workqueue paths
QueueLease implications
```

No behavior-changing network or device hook is approved by this note.

## Core Objects

The main container is `struct e1000_adapter`:

```text
drivers/net/ethernet/intel/e1000e/e1000.h:192 e1000_adapter
  struct e1000_adapter

important fields:
  watchdog_timer, phy_info_timer
  reset_task, watchdog_task
  tx_ring, rx_ring
  napi
  downshift_task, update_phy_task, print_hang_task
  tx_hwtstamp_skb, tx_hwtstamp_work
  pdev, netdev, hw
```

The queue object is `struct e1000_ring`:

```text
desc
dma
size, count
next_to_use, next_to_clean
head, tail
buffer_info
ims_val, itr_val
```

The per-buffer object is `struct e1000_buffer`:

```text
dma
skb
time_stamp
length
next_to_watch
segs
bytecount
mapped_as_page
```

Authority distinction:

```text
adapter:
  device/service/container authority

ring:
  queue ownership, descriptor memory, tail/head, interrupt vector binding

buffer_info:
  per-SKB DMA/accounting/completion state

work_struct:
  deferred service callback identity, not data-plane submit authority
```

## TX Submit Path

The netdev operation is:

```text
drivers/net/ethernet/intel/e1000e/netdev.c:7349 e1000_xmit_frame
  .ndo_start_xmit = e1000_xmit_frame
```

The submit path begins at:

```text
drivers/net/ethernet/intel/e1000e/netdev.c:5815 e1000_xmit_frame
  e1000_xmit_frame(skb, netdev)
```

The driver checks adapter state, ring space, offload requirements, and then maps
the SKB into DMA descriptors:

```text
drivers/net/ethernet/intel/e1000e/netdev.c:5922-5923
  count = e1000_tx_map(tx_ring, skb, first, ...)
```

`e1000_tx_map()` stores DMA addresses and SKB accounting state in the ring
buffer array:

```text
drivers/net/ethernet/intel/e1000e/netdev.c:5605-5607
  dma_map_single(... DMA_TO_DEVICE)

drivers/net/ethernet/intel/e1000e/netdev.c:5640-5642
  skb_frag_dma_map(... DMA_TO_DEVICE)

drivers/net/ethernet/intel/e1000e/netdev.c:5657-5660
  buffer_info[i].skb = skb
  buffer_info[i].segs = segs
  buffer_info[i].bytecount = bytecount
  buffer_info[first].next_to_watch = i
```

`e1000_tx_queue()` writes hardware descriptors:

```text
drivers/net/ethernet/intel/e1000e/netdev.c:5719-5722
  tx_desc->buffer_addr = cpu_to_le64(buffer_info->dma)
  tx_desc->lower.data = ...
  tx_desc->upper.data = ...

drivers/net/ethernet/intel/e1000e/netdev.c:5735-5742
  wmb()
  tx_ring->next_to_use = i
```

Finally, the driver may ring the device doorbell by writing the tail register:

```text
drivers/net/ethernet/intel/e1000e/netdev.c:5954 e1000_xmit_frame
  writel(tx_ring->next_to_use, tx_ring->tail)
```

This is the strongest QueueLease submit boundary in this source map.

CapSched implication:

```text
No live QueueLease:
  no DMA mapping for caller-owned packet buffers
  no descriptor publication
  no tail doorbell

No monitor-owned IOMMU map:
  no device DMA into Domain-owned or shared packet memory

No queue budget/rate:
  no tail advancement even if Linux netdev queue is open
```

The workqueue is not the submit authority root here. The ring is.

## TX Completion Path

TX completion is reclaimed by `e1000_clean_tx_irq()`:

```text
drivers/net/ethernet/intel/e1000e/netdev.c:1228 e1000_clean_tx_irq
  e1000_clean_tx_irq(tx_ring)
```

It walks completed descriptors, unmaps/free buffers, advances
`next_to_clean`, completes BQL accounting, and may wake the netdev queue:

```text
drivers/net/ethernet/intel/e1000e/netdev.c:1244-1277
  consume descriptors with E1000_TXD_STAT_DD
  e1000_put_txbuf()
  tx_ring->next_to_clean = i

drivers/net/ethernet/intel/e1000e/netdev.c:1279 e1000_clean_tx_irq
  netdev_completed_queue(netdev, pkts_compl, bytes_compl)

drivers/net/ethernet/intel/e1000e/netdev.c:1289-1292
  netif_wake_queue(netdev)
```

Completion can also schedule diagnostic service work:

```text
drivers/net/ethernet/intel/e1000e/netdev.c:1301-1305
  if TX hang suspected:
    schedule_work(&adapter->print_hang_task)
```

CapSched implication:

```text
completion path:
  settle descriptors and accounting
  release or refund QueueLease in-flight units
  must not mint a new caller authority

diagnostic work:
  service authority, not caller endpoint authority
```

## RX Path

RX completion is not caller-derived. The device writes descriptors and the
driver consumes them in NAPI:

```text
drivers/net/ethernet/intel/e1000e/netdev.c:927 e1000_clean_rx_irq
  e1000_clean_rx_irq(rx_ring, work_done, budget)

drivers/net/ethernet/intel/e1000e/netdev.c:947-953
  while descriptor DD is set and NAPI budget remains

drivers/net/ethernet/intel/e1000e/netdev.c:970-972
  dma_unmap_single(... DMA_FROM_DEVICE)

drivers/net/ethernet/intel/e1000e/netdev.c:1045-1046
  e1000_receive_skb(...)

drivers/net/ethernet/intel/e1000e/netdev.c:578
  napi_gro_receive(&adapter->napi, skb)
```

CapSched implication:

```text
RX queue ownership:
  service/queue owner controls buffer posting and DMA memory

packet delivery:
  endpoint demux happens after receive, not through workqueue caller identity

IOMMU:
  monitor must constrain device DMA target pages before RX buffers are posted
```

## IRQ and NAPI Path

Interrupt vectors are registered for RX and TX:

```text
drivers/net/ethernet/intel/e1000e/netdev.c:2122-2124
  request_irq(... e1000_intr_msix_rx ...)

drivers/net/ethernet/intel/e1000e/netdev.c:2138-2140
  request_irq(... e1000_intr_msix_tx ...)

drivers/net/ethernet/intel/e1000e/netdev.c:2180-2181
  request_irq(... e1000_intr_msi ...)
```

Legacy/MSI interrupt handling schedules NAPI and can schedule service work for
link or reset events:

```text
drivers/net/ethernet/intel/e1000e/netdev.c:1776-1778
  link-status interrupt may schedule downshift_task

drivers/net/ethernet/intel/e1000e/netdev.c:1806-1807
  uncorrectable ECC error schedules reset_task

drivers/net/ethernet/intel/e1000e/netdev.c:1892-1897
  napi_schedule_prep(); __napi_schedule_irqoff()
```

MSI-X separates RX and TX:

```text
drivers/net/ethernet/intel/e1000e/netdev.c:1936-1938
  TX interrupt calls e1000_clean_tx_irq()

drivers/net/ethernet/intel/e1000e/netdev.c:1963-1966
  RX interrupt schedules NAPI
```

The NAPI callback is:

```text
drivers/net/ethernet/intel/e1000e/netdev.c:2668-2682
  e1000e_poll(napi, budget)
    e1000_clean_tx_irq()
    adapter->clean_rx()

drivers/net/ethernet/intel/e1000e/netdev.c:2690-2697
  napi_complete_done(); re-enable interrupts
```

CapSched implication:

```text
interrupt/NAPI:
  queue ownership and IRQ route authority, not caller authority

NAPI budget:
  Linux service budget/latency mechanism, not MonitorRootBudget

completion settlement:
  likely place to account used QueueLease units and completion delivery
```

## Workqueue Service Paths

`e1000e` uses several work items, but they are mostly service/control paths:

```text
drivers/net/ethernet/intel/e1000e/netdev.c:7618
  INIT_WORK(&adapter->reset_task, e1000_reset_task)

drivers/net/ethernet/intel/e1000e/netdev.c:7619
  INIT_WORK(&adapter->watchdog_task, e1000_watchdog_task)

drivers/net/ethernet/intel/e1000e/netdev.c:7620
  INIT_WORK(&adapter->downshift_task, e1000e_downshift_workaround)

drivers/net/ethernet/intel/e1000e/netdev.c:7621
  INIT_WORK(&adapter->update_phy_task, e1000e_update_phy_task)

drivers/net/ethernet/intel/e1000e/netdev.c:7622
  INIT_WORK(&adapter->print_hang_task, e1000_print_hw_hang)

drivers/net/ethernet/intel/e1000e/netdev.c:4491
  INIT_WORK(&adapter->tx_hwtstamp_work, e1000e_tx_hwtstamp_work)
```

Examples:

```text
watchdog:
  timer callback schedules watchdog_task at netdev.c:5215
  watchdog_task checks link, updates stats, may schedule reset_task at
  netdev.c:5397, and re-arms watchdog_timer at netdev.c:5452-5454

reset:
  tx_timeout schedules reset_task at netdev.c:5976
  reset_task takes rtnl_lock and reinitializes adapter

downshift:
  link-status interrupt schedules downshift_task at netdev.c:1778/1857

print hang:
  TX completion hang detection schedules print_hang_task at netdev.c:1305

tx hardware timestamp:
  xmit path stores a single tx_hwtstamp_skb and schedules tx_hwtstamp_work at
  netdev.c:5932
  tx_hwtstamp_work polls the timestamp valid bit and can reschedule itself at
  netdev.c:1217
```

These work items share the same `schedule_work()` pending-bit merge behavior as
ordinary workqueue users. They are not per-caller queues.

Classification:

```text
reset_task:
  ServiceOnly device reinit

watchdog_task:
  timer-origin ServiceOnly device maintenance

downshift_task:
  InterruptDeferred_or_ServiceOnly PHY workaround

update_phy_task:
  ServiceOnly PHY stats/update

print_hang_task:
  ServiceOnly diagnostic/mitigation

tx_hwtstamp_work:
  ExplicitMerge_or_PerPacketSpecial; one global outstanding tx_hwtstamp_skb,
  not a generic per-caller work carrier
```

## Merge and Batching Rules

`e1000e` has multiple merge/batch mechanisms:

```text
workqueue pending bit:
  reset/watchdog/downshift/update_phy/print_hang/tx_hwtstamp work coalesce

watchdog timer:
  periodic timer schedules watchdog_task and re-arms itself

NAPI:
  interrupts merge into poll ownership and budget-limited cleaning

xmit_more:
  TX submit may defer tail doorbell until batching boundary

ring descriptors:
  many SKBs are represented by ring state, not by one work item

tx_hwtstamp_skb:
  single outstanding timestamp SKB pointer, explicitly not a queue
```

CapSched consequence:

```text
Do not model Ethernet data plane as one work_struct carrier.
Model it as QueueLease submit, in-flight ring ledger, completion settlement,
IRQ/NAPI ownership, and service-control work.
```

## Production Design Rule

For a monitor-backed datacenter OS:

```text
QueueLease submit boundary:
  before DMA map, descriptor publication, and tail doorbell

IOMMU boundary:
  before descriptor memory or packet buffer DMA is visible to the device

IRQ boundary:
  IRQ route must belong to the queue owner or device service Domain

NAPI/completion boundary:
  settlement and delivery, not new caller authority

workqueue boundary:
  reset/watchdog/PHY/hang/timestamp service, not ring submit authority
```

This suggests the first production-grade NIC work should be based on typed
queue ownership and DMA/IRQ routes, not generic workqueue carrier patches.

## Compatibility Note

`e1000e` has one TX/RX queue pair in this map and is not the ideal production
multi-tenant NIC queue model. It is still useful because it shows where the
Linux network driver stack already separates:

```text
netdev submit
DMA mapping
descriptor ring update
doorbell
interrupt
NAPI poll
completion accounting
service work
```

For stronger datacenter evaluation, the same source-map method should later be
applied to a modern multi-queue driver with MSI-X, XDP, NAPI, page-pool, and
devlink/SR-IOV paths.
