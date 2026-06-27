# Analysis 0047: drivers/net Workqueue Origin Map

Status: Draft source-inventory map, no implementation approved

Date: 2026-06-27

Linux source:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
commit: 7cf0b1e415bcead8a2079c8be94a9d41aad7d462
```

Related artifacts:

```text
analysis/0046-workqueue-origin-taxonomy.md
validation/0042-workqueue-origin-source-inventory-result.md
validation/0043-drivers-net-workqueue-origin-inventory-result.md
validation/run-workqueue-origin-drivers-net-inventory.sh
```

## Purpose

`validation/0042` identified `drivers/net` as the largest unknown workqueue
origin group. This note records the first dedicated source-inventory pass for
that group.

The purpose is not to decide enforcement. The purpose is to reduce a single
large unknown bucket into:

```text
subtree distribution
API distribution
taxonomy projections
hotspot files
remaining proof gaps
```

## Inventory Result

The `drivers/net` inventory found:

```text
callsite rows: 1440
family rows:   164
API rows:       10
hotspot rows:   40
gap rows:       18
```

Largest family/subfamily groups:

```text
wireless/intel:       150
ethernet/intel:       112
ethernet/mellanox:    107
ethernet/marvell:      72
wireless/ath:          57
wireless/st:           43
wireless/realtek:      43
ethernet/sfc:          40
wireless/mediatek:     39
ethernet/qlogic:       35
ethernet/cavium:       33
wireless/marvell:      31
ethernet/broadcom:     25
```

Largest files:

```text
drivers/net/wireless/intel/ipw2x00/ipw2200.c: 55
drivers/net/amt.c:                              23
drivers/net/ethernet/intel/e1000e/netdev.c:     15
drivers/net/wireless/st/cw1200/sta.c:           14
drivers/net/bonding/bond_main.c:                14
drivers/net/wireless/intel/ipw2x00/ipw2100.c:   13
drivers/net/usb/usbnet.c:                       13
drivers/net/ethernet/intel/igb/igb_main.c:      13
```

API distribution:

```text
queue_work:                   486
schedule_work:                380
schedule_delayed_work:        284
queue_delayed_work:           211
mod_delayed_work:              57
kthread_queue_delayed_work:    13
queue_work_on:                  4
queue_rcu_work:                 2
kthread_queue_work:             2
queue_delayed_work_on:          1
```

Taxonomy projection distribution:

```text
PerInvocation_or_ServiceOnly_or_ExplicitMerge_candidate: 852
ExplicitMerge_or_ServiceOnly_candidate:                  553
InterruptDeferred_candidate:                              20
InterruptDeferred_or_ServiceOnly_candidate:               15
```

These projections are deliberately not enforcement classes. They only tell us
which taxonomy branches should be inspected next.

## Main Finding

`drivers/net` workqueue usage is not one security class.

It mixes at least:

```text
link maintenance
periodic stats and MIB reads
PTP/time synchronization work
firmware and device health work
device reset and recovery
interrupt/BH handoff
TX/RX cleanup
USB/network adapter bottom halves
bonding/team/tunnel control-plane work
wireless firmware/control work
virtual and simulated netdev control work
```

The common endpoint domain is:

```text
network device / network queue / network control plane
```

But the authority origin varies. Some work is service-only device maintenance.
Some is interrupt-deferred. Some is likely per-invocation. Some is explicit
merge or timer coalescing. API names do not decide this.

## CapSched Implication

For the final datacenter OS goal, `drivers/net` is where several CapSched
concepts meet:

```text
DomainTag
BudgetTicket
Network EndpointCap
QueueLease
IOMMU/DMA MemoryView
Service/driver Domain authority
Monitor-backed queue ownership
```

Therefore `drivers/net` should not be governed by a generic "workqueue has
caller carrier" rule.

The safer production direction is:

```text
1. data-plane queue leases:
   NIC queue ownership, DMA memory, XDP/NAPI, TX/RX ring effects

2. control-plane service authority:
   link reset, firmware, health, PTP, stats, ethtool, devlink

3. caller-derived endpoint operations:
   operations triggered by socket, ioctl, netlink, ethtool, or queue lease
   requests must freeze caller authority before work leaves caller context

4. interrupt-deferred handoff:
   IRQ/BH/kthread paths can carry event facts, not mint caller authority
```

## Delayed Work Is Usually a Merge Warning

`drivers/net` has 553 delayed or timer-like candidate rows:

```text
schedule_delayed_work: 284
queue_delayed_work:    211
mod_delayed_work:       57
queue_delayed_work_on:   1
```

This strongly suggests that many net driver works are not one-caller
PerInvocation work. They are likely:

```text
polling loops
link checks
periodic stats
firmware health checks
retry/recovery timers
aggregation/coalescing loops
```

CapSched rule:

```text
Delayed network work must be treated as ExplicitMerge_or_ServiceOnly until
source mapping proves a per-invocation caller-derived request.
```

## Interrupt-Deferred Network Work

The inventory found 35 interrupt-deferred candidates:

```text
20 BH workqueue candidates through system_bh_wq/system_bh_highpri_wq
15 kthread work candidates
```

Examples include:

```text
drivers/net/usb/usbnet.c:
  queue_work(system_bh_wq, &dev->bh_work)

drivers/net/ethernet/amd/xgbe:
  system_bh_wq bottom-half work

drivers/net/wireless/ath/ath12k:
  system_bh_wq CE pipe interrupt work

drivers/net/dsa/mv88e6xxx:
  kthread_queue_delayed_work(... irq_poll_work ...)

drivers/net/ethernet/intel/ice:
  kthread delayed work for PTP/GNSS/DPLL paths
```

CapSched rule:

```text
Interrupt-deferred net work may hand off event state, but endpoint authority
must be checked in the receiving service or DomainRequest path.
```

## Wireless Is a Service-Domain Hotspot

The wireless subtree is a major source of unknown work:

```text
wireless/intel:    150
wireless/ath:       57
wireless/st:        43
wireless/realtek:   43
wireless/mediatek:  39
wireless/marvell:   31
```

Wireless drivers usually involve firmware, scan/connect state machines,
interrupt/event handling, regulatory state, and device-specific control
queues. Those are poor candidates for caller ambient authority.

CapSched rule:

```text
Wireless work should default to ServiceOnly or InterruptDeferred service
Domain execution until a specific caller-derived endpoint operation is proven.
```

## Ethernet Is a QueueLease Hotspot

Ethernet is the largest family:

```text
ethernet/intel:     112
ethernet/mellanox:  107
ethernet/marvell:    72
ethernet/sfc:        40
ethernet/qlogic:     35
ethernet/cavium:     33
ethernet/broadcom:   25
```

This area is strongly tied to the HyperTag/QueueLease goal:

```text
TX/RX rings
DMA descriptors
NAPI polling
XDP/BPF hooks
devlink/ethtool control
firmware health/recovery
SR-IOV and representor paths
```

CapSched rule:

```text
Ethernet work should be mapped through queue ownership and device service
authority, not generic worker identity.
```

## Remaining Evidence Gaps

The dedicated inventory reduces the unknown from one bulk group to structured
unknowns, but key evidence is still missing:

```text
driver-callback-correlation:
  API callsites are not enough; we need INIT_WORK/INIT_DELAYED_WORK callback
  and container mapping.

endpoint-effect-map:
  callbacks must be tagged as link maintenance, reset, stats, TX/RX cleanup,
  firmware, PTP, queue control, or data-plane effect.

queue-lease-boundary:
  workqueue API names do not reveal netdev queue ownership, NAPI, XDP, DMA, or
  service Domain boundaries.

hardware-coverage:
  many paths need hardware-specific events and should remain source-inferred or
  not_observed unless a QEMU/device setup actually executes them.
```

## Next Source-Mapping Targets

The next source pass should focus on either:

```text
1. drivers/net/wireless/intel/ipw2x00/ipw2200.c
   largest single hotspot, 55 callsites

2. drivers/net/usb/usbnet.c
   clear BH work pattern and more likely QEMU/USB-test reachable

3. drivers/net/ethernet/intel/e1000e/netdev.c or igb_main.c
   representative Ethernet QueueLease mapping

4. drivers/net/bonding/bond_main.c
   control-plane delayed merge/timer example with virtual aggregation

5. drivers/net/amt.c
   tunnel/control-plane timer-heavy example
```

No generic workqueue enforcement hook should follow before at least one of
these target families has callback/container/effect mapping.
