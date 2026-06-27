# Validation 0043: drivers/net Workqueue Origin Inventory Result

Status: Executed observation-only source inventory

Date: 2026-06-27

Runner:

```text
capsched/capsched-models/validation/run-workqueue-origin-drivers-net-inventory.sh
```

Related analysis:

```text
capsched/capsched-models/analysis/0047-drivers-net-workqueue-origin-map.md
capsched/capsched-models/analysis/0046-workqueue-origin-taxonomy.md
capsched/capsched-models/validation/0042-workqueue-origin-source-inventory-result.md
```

Linux source:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
commit: 7cf0b1e415bcead8a2079c8be94a9d41aad7d462
subject: sched/capsched: Add type-only authority scaffolding
```

## Result Summary

Final run:

```text
run directory:
  /media/nia/scsiusb/dev/linux-cap/build/workqueue-origin-drivers-net-inventory/20260627T102701Z

calls:
  /media/nia/scsiusb/dev/linux-cap/build/workqueue-origin-drivers-net-inventory/20260627T102701Z/drivers-net-callsite-inventory.tsv

family counts:
  /media/nia/scsiusb/dev/linux-cap/build/workqueue-origin-drivers-net-inventory/20260627T102701Z/drivers-net-family-counts.tsv

API counts:
  /media/nia/scsiusb/dev/linux-cap/build/workqueue-origin-drivers-net-inventory/20260627T102701Z/drivers-net-api-counts.tsv

hotspots:
  /media/nia/scsiusb/dev/linux-cap/build/workqueue-origin-drivers-net-inventory/20260627T102701Z/drivers-net-hotspots.tsv

gaps:
  /media/nia/scsiusb/dev/linux-cap/build/workqueue-origin-drivers-net-inventory/20260627T102701Z/drivers-net-gaps.tsv
```

Outcome:

```text
status: observation_only_drivers_net_source_inventory
callsite_rows: 1440
family_rows: 164
api_rows: 10
hotspot_rows: 40
gap_rows: 18
```

## API Counts

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

## Taxonomy Projection Counts

```text
PerInvocation_or_ServiceOnly_or_ExplicitMerge_candidate: 852
ExplicitMerge_or_ServiceOnly_candidate:                  553
InterruptDeferred_candidate:                              20
InterruptDeferred_or_ServiceOnly_candidate:               15
```

These are only source-inventory projections, not enforcement classes.

## Largest Groups

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

Largest hotspot file:

```text
drivers/net/wireless/intel/ipw2x00/ipw2200.c: 55
```

## Gap Meaning

The inventory narrows the largest unknown group but does not make it
enforcement-ready.

Remaining gaps:

```text
driver-callback-correlation:
  API callsites are not callback/container mappings.

endpoint-effect-map:
  network drivers mix link maintenance, reset, stats, TX/RX completion,
  firmware, PTP, and queue control.

queue-lease-boundary:
  workqueue API names do not represent netdev queue, NAPI, XDP, DMA, or
  service Domain ownership.

hardware-coverage:
  many paths require hardware-specific events.
```

## Validation Meaning

This validation supports:

```text
drivers/net has been decomposed from one large unknown group into family,
API, hotspot, and taxonomy-projection inventories.
```

It does not prove:

```text
network driver workqueue paths are classified completely.
generic workqueue enforcement is safe.
network QueueLease enforcement points are known.
driver callbacks preserve caller authority.
```

## Consequence

Next work should focus on source-mapping one representative target:

```text
drivers/net/usb/usbnet.c:
  likely reachable, clear BH-work pattern

drivers/net/ethernet/intel/e1000e/netdev.c or igb_main.c:
  representative Ethernet QueueLease mapping

drivers/net/bonding/bond_main.c:
  delayed merge/control-plane virtual aggregation

drivers/net/amt.c:
  timer-heavy tunnel/control-plane work

drivers/net/wireless/intel/ipw2x00/ipw2200.c:
  largest hotspot, but likely harder and less representative of modern
  datacenter NIC paths
```

No behavior-changing net driver hook should be proposed from this inventory
alone.
