# Analysis 0052: Intel ice Modern NIC QueueLease Source Map

Status: Draft representative modern NIC source map, no implementation approved

Date: 2026-06-27

Linux source:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
commit: 7cf0b1e415bcead8a2079c8be94a9d41aad7d462
```

Related artifacts:

```text
analysis/0049-e1000e-queuelease-source-map.md
analysis/0050-aggregate-queuelease-settlement-semantics.md
analysis/0051-linux-queue-descriptor-ledger-observation-plan.md
analysis/ice-modern-nic-queuelease-source-map-v1.json
validation/0045-queue-descriptor-ledger-observation-plan.md
```

## Purpose

`e1000e` is a useful compact Ethernet map, but it is not representative of
modern datacenter NIC complexity. The Intel `ice` driver adds:

```text
multi-queue VSI/ring/q_vector mapping
MSI-X style interrupt vectors
NAPI per q_vector
XDP and AF_XDP zero-copy paths
page-pool/XDP RX memory models
devlink rate and scheduling controls
SR-IOV, subfunction, and representor paths
driver-specific tracepoints
service/reset/PTP/DPLL/eswitch work
```

This note maps those features to QueueLease and Domain authority boundaries.
It does not approve an enforcement hook.

## Core Objects

`struct ice_vsi` owns arrays of rings and vectors:

```text
drivers/net/ethernet/intel/ice/ice.h:334 ice_vsi
  struct ice_vsi

drivers/net/ethernet/intel/ice/ice.h:338-340
  rx_rings
  tx_rings
  q_vectors

drivers/net/ethernet/intel/ice/ice.h:414
  xdp_rings
```

`struct ice_q_vector` binds NAPI, interrupt index, and lists of Tx/Rx rings:

```text
drivers/net/ethernet/intel/ice/ice.h:468 ice_q_vector
  struct ice_q_vector

drivers/net/ethernet/intel/ice/ice.h:481
  struct napi_struct napi

drivers/net/ethernet/intel/ice/ice.h:483-484
  rx and tx ring containers

drivers/net/ethernet/intel/ice/ice.h:493
  struct msi_map irq
```

`struct ice_rx_ring` and `struct ice_tx_ring` carry the QueueLease-relevant
mutable queue state:

```text
drivers/net/ethernet/intel/ice/ice_txrx.h:277 ice_rx_ring
  struct ice_rx_ring

drivers/net/ethernet/intel/ice/ice_txrx.h:280-305
  page_pool, q_vector, tail, xdp_prog, xdp_ring, xsk_pool

drivers/net/ethernet/intel/ice/ice_txrx.h:330-340
  next_to_use, next_to_clean, q_index

drivers/net/ethernet/intel/ice/ice_txrx.h:349 ice_tx_ring
  struct ice_tx_ring

drivers/net/ethernet/intel/ice/ice_txrx.h:353-377
  tail, q_vector, q_index, xsk_pool, next_to_use, next_to_clean
```

These are useful Linux observation objects. They are not production authority
roots because all are Linux-mutable.

## Queue And Vector Binding

`ice` maps rings to q_vectors in a way that is directly relevant to future
QueueLedger and IRQ/NAPI ownership tags.

```text
drivers/net/ethernet/intel/ice/ice_base.c:103
  ice_vsi_alloc_q_vector()

drivers/net/ethernet/intel/ice/ice_base.c:143
  q_vector->irq = ice_alloc_irq(...)

drivers/net/ethernet/intel/ice/ice_base.c:158-159
  netif_napi_add_config(..., ice_napi_poll, v_idx)

drivers/net/ethernet/intel/ice/ice_base.c:924
  ice_vsi_map_rings_to_vectors()

drivers/net/ethernet/intel/ice/ice_base.c:954-956
  tx_ring->q_vector = q_vector

drivers/net/ethernet/intel/ice/ice_base.c:971-973
  rx_ring->q_vector = q_vector
```

QueueLease implication:

```text
Queue identity is not one netdev.
It is at least VSI + ring + q_vector + IRQ/NAPI + queue epoch.
```

## SKB TX Path

The ordinary SKB data plane starts at netdev ops:

```text
drivers/net/ethernet/intel/ice/ice_main.c:9780
  .ndo_start_xmit = ice_start_xmit

drivers/net/ethernet/intel/ice/ice_txrx.c:2273 ice_start_xmit
  ice_start_xmit(skb, netdev)

drivers/net/ethernet/intel/ice/ice_txrx.c:2284
  tx_ring = vsi->tx_rings[skb->queue_mapping]

drivers/net/ethernet/intel/ice/ice_txrx.c:2287
  ice_xmit_frame_ring(skb, tx_ring)
```

`ice_xmit_frame_ring()` prepares the first software buffer and then enters the
descriptor/DMA path:

```text
drivers/net/ethernet/intel/ice/ice_txrx.c:2168
  ice_trace(xmit_frame_ring, tx_ring, skb)

drivers/net/ethernet/intel/ice/ice_txrx.c:2171
  first = &tx_ring->tx_buf[tx_ring->next_to_use]

drivers/net/ethernet/intel/ice/ice_txrx.c:2256
  ice_tx_map(tx_ring, first, &offload)
```

`ice_tx_map()` is the primary SKB QueueLease submit boundary:

```text
drivers/net/ethernet/intel/ice/ice_txrx.c:1398
  ice_tx_map(...)

drivers/net/ethernet/intel/ice/ice_txrx.c:1434
  dma_map_single(...)

drivers/net/ethernet/intel/ice/ice_txrx.c:1495
  skb_frag_dma_map(...)

drivers/net/ethernet/intel/ice/ice_txrx.c:1451
  tx_desc->buf_addr = cpu_to_le64(dma)

drivers/net/ethernet/intel/ice/ice_txrx.c:1458
  tx_desc->cmd_type_offset_bsz = ice_build_ctob(...)

drivers/net/ethernet/intel/ice/ice_txrx.c:1508
  first->next_to_watch = tx_desc

drivers/net/ethernet/intel/ice/ice_txrx.c:1514
  tx_ring->next_to_use = i

drivers/net/ethernet/intel/ice/ice_txrx.c:1520
  __netdev_tx_sent_queue(..., netdev_xmit_more())

drivers/net/ethernet/intel/ice/ice_txrx.c:1567 ice_tx_map
  writel_relaxed(i, tx_ring->tail)
```

QueueLease implication:

```text
Submit authority must be checked before DMA map, descriptor publication,
next_to_watch publication, and tail doorbell.
```

The `ice_trace(xmit_frame_ring)` event is useful observation evidence, but it
does not replace a SubmitLedger id or monitor-owned QueueTag.

## XDP And AF_XDP Paths

`ice` has separate XDP paths that share or parallel queue authority.

XDP frame path:

```text
drivers/net/ethernet/intel/ice/ice_main.c:9811
  .ndo_xdp_xmit = ice_xdp_xmit

drivers/net/ethernet/intel/ice/ice_txrx_lib.c:368
  __ice_xmit_xdp_ring(...)

drivers/net/ethernet/intel/ice/ice_txrx_lib.c:411
  dma_map_single(...) for frame path

drivers/net/ethernet/intel/ice/ice_txrx_lib.c:416-417
  page_pool_get_dma_addr(...) and dma_sync_single_for_device(...) for XDP_TX

drivers/net/ethernet/intel/ice/ice_txrx_lib.c:427-428
  tx_desc->buf_addr and cmd_type_offset_bsz

drivers/net/ethernet/intel/ice/ice_txrx_lib.c:509-510
  ice_set_rs_bit(); ice_xdp_ring_update_tail()
```

AF_XDP zero-copy path:

```text
drivers/net/ethernet/intel/ice/ice_main.c:9812
  .ndo_xsk_wakeup = ice_xsk_wakeup

drivers/net/ethernet/intel/ice/ice_xsk.c:791
  ice_xmit_zc(...)

drivers/net/ethernet/intel/ice/ice_xsk.c:803
  xsk_tx_peek_release_desc_batch(...)

drivers/net/ethernet/intel/ice/ice_xsk.c:719
  ice_xmit_pkt(): descriptor from AF_XDP descriptor

drivers/net/ethernet/intel/ice/ice_xsk.c:734
  ice_xmit_pkt_batch(): batched descriptor publication

drivers/net/ethernet/intel/ice/ice_xsk.c:821-822
  ice_set_rs_bit(); ice_xdp_ring_update_tail()

drivers/net/ethernet/intel/ice/ice_xsk.c:840
  ice_xsk_wakeup(...)

drivers/net/ethernet/intel/ice/ice_xsk.c:865
  ice_trigger_sw_intr(...)
```

QueueLease implication:

```text
SKB QueueLease is not enough.
XDP frame, XDP_TX page-pool reuse, and AF_XDP zero-copy descriptors need
separate submit ledgers or a common queue ledger with typed operation classes.
```

## RX, Completion, And Settlement

NAPI polls a q_vector and may clean multiple Tx and Rx rings:

```text
drivers/net/ethernet/intel/ice/ice_txrx.c:1267
  ice_napi_poll(napi, budget)

drivers/net/ethernet/intel/ice/ice_txrx.c:1289
  ice_clean_tx_irq(tx_ring, budget)

drivers/net/ethernet/intel/ice/ice_txrx.c:1319-1320
  ice_clean_rx_irq_zc(...) or ice_clean_rx_irq(...)
```

TX completion:

```text
drivers/net/ethernet/intel/ice/ice_txrx.c:272
  ice_clean_tx_irq(...)

drivers/net/ethernet/intel/ice/ice_txrx.c:302
  ice_trace(clean_tx_irq, tx_ring, tx_desc, tx_buf)

drivers/net/ethernet/intel/ice/ice_txrx.c:306-308
  check ICE_TX_DESC_DTYPE_DESC_DONE

drivers/net/ethernet/intel/ice/ice_txrx.c:316
  napi_consume_skb(...)

drivers/net/ethernet/intel/ice/ice_txrx.c:319
  dma_unmap_single(...)

drivers/net/ethernet/intel/ice/ice_txrx.c:336
  dma_unmap_page(...)
```

RX completion:

```text
drivers/net/ethernet/intel/ice/ice_txrx.c:946
  ice_clean_rx_irq(...)

drivers/net/ethernet/intel/ice/ice_txrx.c:973
  check ICE_RX_FLEX_DESC_STATUS0_DD

drivers/net/ethernet/intel/ice/ice_txrx.c:981
  dma_rmb()

drivers/net/ethernet/intel/ice/ice_txrx.c:995
  ice_trace(clean_rx_irq, rx_ring, rx_desc)

drivers/net/ethernet/intel/ice/ice_txrx.c:1062
  ice_trace(clean_rx_irq_indicate, rx_ring, rx_desc, skb)

drivers/net/ethernet/intel/ice/ice_txrx.c:1064
  ice_receive_skb(rx_ring, skb, vlan_tci)
```

RX buffer repost and tail update:

```text
drivers/net/ethernet/intel/ice/ice_txrx_lib.c:12
  ice_release_rx_desc(...)

drivers/net/ethernet/intel/ice/ice_txrx_lib.c:36
  writel(val, rx_ring->tail)
```

QueueLease implication:

```text
Completion is aggregate q_vector/ring settlement, not caller authority.
RX owns page-pool/XSK memory and must be modeled as queue memory ownership plus
delivery endpoint authority.
```

## Driver-Specific Tracepoints

`ice` has stronger trace support than `e1000e`:

```text
drivers/net/ethernet/intel/ice/ice_trace.h:144-146
  ice_clean_tx_irq
  ice_clean_tx_irq_unmap
  ice_clean_tx_irq_unmap_eop

drivers/net/ethernet/intel/ice/ice_trace.h:164
  ice_clean_rx_irq

drivers/net/ethernet/intel/ice/ice_trace.h:189
  ice_clean_rx_irq_indicate

drivers/net/ethernet/intel/ice/ice_trace.h:217-218
  ice_xmit_frame_ring
  ice_xmit_frame_ring_drop

drivers/net/ethernet/intel/ice/ice_trace.h:264-327
  eswitch bridge FDB/VLAN/port tracepoints
```

These expose ring, descriptor, buffer, SKB, and bridge objects. They still do
not expose:

```text
monitor-owned QueueTag
Domain id/epoch
SubmitLedger id
QueueLease budget debit
IOMMU ownership proof
revoke/drop/quarantine outcome
```

## Control Plane And Virtualization Surfaces

The main netdev supports queue, VF, XDP, XSK, TC, bridge, and timestamp
operations:

```text
drivers/net/ethernet/intel/ice/ice_main.c:9777
  ice_netdev_ops

drivers/net/ethernet/intel/ice/ice_main.c:9780-9812
  start_xmit, select_queue, set_tx_maxrate, VF ops, setup_tc,
  bridge ops, bpf, xdp_xmit, xsk_wakeup, hwtstamp
```

Subfunction netdevs reuse the same data-plane paths:

```text
drivers/net/ethernet/intel/ice/ice_sf_eth.c:11
  ice_sf_netdev_ops
```

Representor transmit rewrites the SKB to the lower device and calls the
ordinary netdev queue path:

```text
drivers/net/ethernet/intel/ice/ice_repr.c:267-281
  representor netdev ops use ice_eswitch_port_start_xmit

drivers/net/ethernet/intel/ice/ice_eswitch.c:217
  ice_eswitch_port_start_xmit(...)

drivers/net/ethernet/intel/ice/ice_eswitch.c:224-227
  set metadata dst, set skb->dev to lower_dev, dev_queue_xmit(skb)
```

Devlink exposes hardware scheduling and control-plane knobs:

```text
drivers/net/ethernet/intel/ice/devlink/devlink.c:641
  ice_devlink_tx_sched_layers_set(...)

drivers/net/ethernet/intel/ice/devlink/devlink.c:1023-1139
  rate leaf/node tx_max, tx_share, tx_priority, tx_weight setters

drivers/net/ethernet/intel/ice/devlink/devlink.c:1323-1348
  devlink ops include reload and rate operations

drivers/net/ethernet/intel/ice/devlink/devlink.c:1661-1683
  MSI-X, tx_scheduling_layers, local_fwd params
```

QueueLease implication:

```text
Control-plane authority is separate from submit authority.
Devlink/VF/representor/SF operations can reshape which queue exists, who owns
it, how it is scheduled, and which lower device receives traffic. They need
QueueControlCap or DeviceService authority, not a RunCap or plain EndpointCap.
```

## Async And Service Work

`ice` has many workqueue/kthread service paths:

```text
ice_service_task
reset scheduling
DPLL work
GNSS work
PTP periodic work
eswitch bridge update work
LAG event work
DIM work
```

Representative anchors:

```text
drivers/net/ethernet/intel/ice/ice_main.c:1672
  queue_work(ice_wq, &pf->serv_task)

drivers/net/ethernet/intel/ice/ice_main.c:2406
  ice_schedule_reset(...)

drivers/net/ethernet/intel/ice/ice_eswitch_br.c:577
  queue_work(br_offloads->wq, ...)

drivers/net/ethernet/intel/ice/ice_ptp.c:2881
  kthread_queue_delayed_work(...)
```

These are not per-caller packet authority. They are service/control work and
must not receive a last-caller BudgetTicket.

## Resulting Design Rule

For a modern NIC, QueueLease must be factored into at least:

```text
QueueBind:
  VSI + ring + q_vector + IRQ/NAPI + queue epoch

SubmitLedger:
  SKB, XDP frame, XDP_TX, or AF_XDP descriptor batch

DescriptorLedger:
  hardware descriptor range, next_to_watch/RS/EOP, DMA mapping state

CompletionSettlement:
  Tx clean, Rx clean, XDP completion, AF_XDP completion, page-pool/XSK return

QueueControl:
  devlink rate/scheduler, MSI-X, local forwarding, VF/SF/representor lifecycle

ServiceWork:
  reset, PTP, DPLL, eswitch bridge, DIM, LAG, firmware/control work
```

The e1000e/equivalent model can remain the small proof seed, but a production
CapSched-H NIC model must include XDP/AF_XDP, representor/SF/VF, and devlink
control-plane authority.

## Hard Rejects

```text
Treating netdev as the queue authority.
Treating ice driver tracepoints as authority.
Treating AF_XDP descriptors as ordinary SKB submits.
Letting representor transmit bypass QueueLease derivation.
Mixing devlink rate/scheduler authority into RunCap.
Charging service/reset/PTP/DPLL work to the last submitter.
Claiming monitor-grade device isolation from Linux-owned ring/q_vector state.
```

## Next Work

```text
N-072:
  Model modern NIC QueueLease classes: SKB submit, XDP submit, AF_XDP submit,
  queue bind, devlink queue-control, representor forwarding, and aggregate
  completion settlement.

N-073:
  Build an observation-only static readiness checker for the ice source map,
  similar to validation/run-queue-descriptor-ledger-readiness.sh, but extended
  for XDP/AF_XDP/devlink/representor-specific events.
```
