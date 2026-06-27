# Analysis 0048: usbnet Workqueue Source Map

Status: Draft representative source map, no implementation approved

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
analysis/0046-workqueue-origin-taxonomy.md
analysis/0047-drivers-net-workqueue-origin-map.md
analysis/usbnet-workqueue-source-map-v1.json
validation/0043-drivers-net-workqueue-origin-inventory-result.md
```

## Purpose

`analysis/0047` concluded that `drivers/net` cannot be treated as one generic
workqueue authority class. This note source-maps one representative driver
framework, `drivers/net/usb/usbnet.c`, down to:

```text
queue sites
INIT_WORK callback
container object
merge rule
endpoint effects
QueueLease relevance
```

The purpose is not to approve a network enforcement hook. The purpose is to
learn which evidence is required before any network async path can be assigned
caller-derived authority.

## Core Objects

`struct usbnet` embeds both work items:

```text
include/linux/usb/usbnet.h:
  struct usbnet:
    rxq, txq, done, rxq_pause
    interrupt, deferred
    bh_work
    kevent
    flags
```

It also records USB/net endpoint state:

```text
udev, intf
in, out, status
net
rx_qlen, tx_qlen
driver_info callbacks
```

Per-packet transient state is carried in `skb->cb` as `struct skb_data`:

```text
urb
dev
state: tx_start, tx_done, rx_start, rx_done, rx_cleanup, unlink_start
length
packets
```

This is an important distinction:

```text
work_struct authority:
  none by itself

usbnet object authority:
  device/service/queue state

skb_data:
  packet/URB state, not caller execution authority
```

## bh_work Mapping

Initialization:

```text
drivers/net/usb/usbnet.c:1781
  INIT_WORK(&dev->bh_work, usbnet_bh_work)
```

Callback:

```text
drivers/net/usb/usbnet.c:1644-1648
  usbnet_bh_work(work)
    dev = from_work(dev, work, bh_work)
    usbnet_bh(&dev->delay)
```

`usbnet_bh()` is also the timer callback:

```text
drivers/net/usb/usbnet.c:1784
  timer_setup(&dev->delay, usbnet_bh, 0)
```

So this logic is not purely worker-context logic. It is a shared bottom-half /
timer maintenance routine.

Endpoint effects inside `usbnet_bh()`:

```text
drivers/net/usb/usbnet.c:1585-1603
  drain dev->done
  rx_done -> rx_process()
  tx_done -> netdev_completed_queue()
  rx_cleanup -> free URB/SKB

drivers/net/usb/usbnet.c:1620-1637
  if RX queue is short and device is running/present/carrier-ok:
    rx_alloc_submit()
    queue bh_work again if RX queue is still short

drivers/net/usb/usbnet.c:1639-1640
  wake TX queue when below TX_QLEN
```

The core queue-site in `defer_bh()` is:

```text
drivers/net/usb/usbnet.c:459-461
  __skb_queue_tail(&dev->done, skb)
  if (dev->done.qlen == 1)
    queue_work(system_bh_wq, &dev->bh_work)
```

This means many packet completions merge into the same `dev->done` drain. If
`dev->done` is already non-empty, no new queue attempt is made. Even when a
queue attempt is made, `queue_work()` itself still coalesces an already-pending
`work_struct`.

Other `bh_work` queue sites include:

```text
rx_submit error path:
  usbnet.c:549

resume paused RX:
  usbnet.c:710

open, after the netdev is fully opened:
  usbnet.c:966

link-change read re-post:
  usbnet.c:1152

RX halt recovery:
  usbnet.c:1227

RX memory recovery:
  usbnet.c:1253

TX timeout cleanup:
  usbnet.c:1354

bh self-resubmit while RX queue remains short:
  usbnet.c:1637

USB resume:
  usbnet.c:2014
```

These queue sites are not one authority origin. They mix completion cleanup,
RX refill, link state, error recovery, open/resume, timeout, and queue wakeup.

Classification:

```text
carrier:            usbnet.bh_work
container:          struct usbnet
callback:           usbnet_bh_work -> usbnet_bh
origin class:       InterruptDeferred_or_ServiceOnly
merge class:        ExplicitMerge via dev->done + work pending bit
endpoint class:     USB network data queue and netdev service state
QueueLease role:    completion/refill/accounting path, not submit authority
caller authority:   not preserved by work_struct
```

## kevent Mapping

Initialization:

```text
drivers/net/usb/usbnet.c:1782
  INIT_WORK(&dev->kevent, usbnet_deferred_kevent)
```

Queue helper:

```text
drivers/net/usb/usbnet.c:472-476
  usbnet_defer_kevent(dev, work)
    set_bit(work, &dev->flags)
    schedule_work(&dev->kevent)
```

The code comment immediately above the helper records the core merge hazard:

```text
drivers/net/usb/usbnet.c:467-470
  if work is active, schedule_work() fails
```

This is not a per-caller request queue. It is a bitset of device events plus a
single work item.

Callback:

```text
drivers/net/usb/usbnet.c:1182-1186
  usbnet_deferred_kevent(work)
    dev = container_of(work, struct usbnet, kevent)
```

Endpoint effects:

```text
EVENT_TX_HALT:
  unlink TX URBs, usb_clear_halt(out), wake netif queue

EVENT_RX_HALT:
  unlink RX URBs, usb_clear_halt(in), queue bh_work

EVENT_RX_MEMORY:
  allocate URB, rx_submit(), possibly queue bh_work

EVENT_LINK_RESET:
  driver_info->link_reset(), then handle link change

EVENT_LINK_CHANGE:
  carrier and RX queue handling

EVENT_SET_RX_MODE:
  driver_info->set_rx_mode()
```

Classification:

```text
carrier:            usbnet.kevent
container:          struct usbnet
callback:           usbnet_deferred_kevent
origin class:       ExplicitMerge_or_ServiceOnly
merge class:        flags bitset + work pending bit
endpoint class:     USB/network control plane
QueueLease role:    service/control side, not direct data-plane submit
caller authority:   not preserved by work_struct or flags
```

## Caller-Derived Work Is Elsewhere

The caller-relevant data-plane submit path is `usbnet_start_xmit()`:

```text
drivers/net/usb/usbnet.c:
  usbnet_start_xmit(skb, net)
    optional tx_fixup()
    usb_alloc_urb()
    usb_fill_bulk_urb(... tx_complete ...)
    usb_submit_urb()
    __usbnet_queue_skb(&dev->txq, skb, tx_start)
```

That is where a future network `EndpointCap` or `QueueLease` submit check would
belong conceptually, not in `bh_work` completion cleanup.

After the URB completes:

```text
tx_complete()
  accounting/error handling
  defer_bh(dev, skb, &dev->txq, tx_done)
```

At that point, `bh_work` should settle completion/accounting state. It should
not be treated as a new caller-authorized endpoint operation.

## Security Consequence

`usbnet` demonstrates why a generic workqueue rule is unsafe:

```text
bad rule:
  attach one caller BudgetTicket to dev->bh_work or dev->kevent

why bad:
  multiple origins merge into one work_struct
  schedule/queue can fail when already active or pending
  state is carried in queues and flags, not in the work item
  worker context has no natural caller DomainTag
  later service recovery can be triggered by earlier device events
```

The safe shape is different:

```text
submit-time:
  caller-derived TX or control request freezes endpoint/queue authority before
  crossing into driver/service state

device/service-time:
  bh_work and kevent execute under device service authority and service budget

completion-time:
  per-packet or per-queue accounting may settle against a QueueLease ledger,
  but it must not mint caller authority

merge-time:
  merged work uses aggregate queue/flag state, not a single overwritten ticket
```

## QueueLease Implication

For monitor-backed CapSched-H, `usbnet` is not the ideal high-performance
datacenter NIC queue model, but it reveals the generic driver pattern:

```text
software queue object:
  dev->rxq, dev->txq, dev->done

hardware/DMA object:
  URB, USB host-controller transfer buffers, scatterlist

control object:
  usb_clear_halt, link_reset, set_rx_mode, runtime PM

completion object:
  tx_complete/rx_complete -> defer_bh -> usbnet_bh
```

Production rules:

```text
1. No QueueLease, no caller data-plane submit.
2. No service authority, no link reset, halt clear, rx mode change, or PM work.
3. No monitor IOMMU/DMA ownership, no device DMA into Domain memory.
4. Workqueue callback execution is not itself proof of caller authority.
5. Merged device work needs an aggregate ledger, not a mutable single-ticket
   field on work_struct.
```

## Compatibility Consequence

Linux compatibility argues against rewriting generic workqueue semantics first.

For L0 and early L1:

```text
do not change queue_work() semantics
do not require every kernel-internal work_struct to carry caller authority
do not treat usbnet.bh_work or usbnet.kevent as per-caller work
do not enforce network async rules from API names alone
```

Instead:

```text
observe and classify driver work
add typed wrappers only for Domain-derived requests
keep service/device maintenance as explicit service authority
model aggregate QueueLease settlement before behavior changes
```

## Resulting Design Rule

`usbnet` supports this rule:

```text
Network async work must be classified at the object/effect level.

work_struct callback identity:
  necessary for tracing
  insufficient for authority

container object:
  required for endpoint classification

queue/flag merge state:
  required for budget and revocation semantics

submit path:
  where caller-derived QueueLease authority is frozen

completion/service path:
  where service authority and aggregate settlement apply
```

No behavior-changing network async hook should be proposed until this pattern
has also been checked against a representative modern Ethernet driver.
