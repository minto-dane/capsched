# Analysis 0053: Intel ice Modern NIC Revoke Source Map

Status: Draft source map, no implementation approved

Date: 2026-06-29

Linux source:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
commit: 7cf0b1e415bcead8a2079c8be94a9d41aad7d462
```

Related artifacts:

```text
analysis/0052-ice-modern-nic-queuelease-source-map.md
assurance/0002-modern-nic-queuelease-assurance-map.md
formal/0031-modern-nic-queue-revoke-model/README.md
validation/0050-modern-nic-queue-revoke-tlc.md
analysis/ice-modern-nic-revoke-source-map-v1.json
```

## Purpose

This note maps formal/0031 revoke obligations back to Intel `ice` source.

The key rule from formal/0031 is:

```text
revoke != netdev down/reset
revoke != clearing Linux ring state
revoke != disabling a queue in driver-visible state

revoke =
  block new submit
  bump queue epoch
  mask or redirect IRQ
  drain or quarantine typed outstanding state
  invalidate IOMMU/DMA reachability
  prevent stale completion/control/representor/service effects
  only then reassign the queue under a new epoch
```

This source map does not approve enforcement hooks.

## Core Source Anchors

### VSI down path

`ice_down()` is the strongest existing source anchor for ordinary queue stop
and cleanup:

```text
drivers/net/ethernet/intel/ice/ice_main.c:7221
  ice_down()

drivers/net/ethernet/intel/ice/ice_main.c:7232-7237
  netif_carrier_off()
  netif_tx_disable()

drivers/net/ethernet/intel/ice/ice_main.c:7239
  ice_vsi_dis_irq()

drivers/net/ethernet/intel/ice/ice_main.c:7241
  ice_vsi_stop_lan_tx_rings()

drivers/net/ethernet/intel/ice/ice_main.c:7246
  ice_vsi_stop_xdp_tx_rings()

drivers/net/ethernet/intel/ice/ice_main.c:7252
  ice_vsi_stop_all_rx_rings()

drivers/net/ethernet/intel/ice/ice_main.c:7257
  ice_napi_disable_all()

drivers/net/ethernet/intel/ice/ice_main.c:7260-7267
  ice_clean_tx_ring()
  ice_clean_tx_ring() for XDP rings
  ice_clean_rx_ring()
```

CapSched reading:

```text
Useful Linux substrate:
  blocks many new netdev submits, masks IRQs, stops hardware rings, disables
  NAPI, and cleans software rings.

Not sufficient:
  no QueueTag, no queue epoch bump, no typed ledger settlement, no
  monitor-visible DMA/IOMMU invalidation, and no proof that old completions or
  service work cannot later deliver as normal effects.
```

### IRQ masking and synchronization

`ice_vsi_dis_irq()` masks Rx queue interrupt cause, clears vector dynamic
control, flushes MMIO, and synchronizes IRQs for non-VF VSIs:

```text
drivers/net/ethernet/intel/ice/ice_main.c:7212
  ice_vsi_dis_irq()

drivers/net/ethernet/intel/ice/ice_main.c:7224-7234
  QINT_RQCTL CAUSE_ENA cleared

drivers/net/ethernet/intel/ice/ice_main.c:7239-7242
  GLINT_DYN_CTL cleared

drivers/net/ethernet/intel/ice/ice_main.c:7244
  ice_flush()

drivers/net/ethernet/intel/ice/ice_main.c:7247-7251
  skip synchronize_irq() for VF from host

drivers/net/ethernet/intel/ice/ice_main.c:7253-7254
  synchronize_irq() for non-VF q_vectors
```

CapSched gap:

```text
VF-host paths need separate proof because the driver deliberately skips
synchronize_irq() for ICE_VSI_VF in this path. Monitor-backed QueueLease revoke
cannot inherit that exception without an IRQ ownership argument.
```

### NAPI and DIM cancellation

`ice_napi_disable_all()` disables NAPI for all q_vectors with rings and cancels
DIM work:

```text
drivers/net/ethernet/intel/ice/ice_main.c:7190
  ice_napi_disable_all()

drivers/net/ethernet/intel/ice/ice_main.c:7200-7201
  napi_disable()

drivers/net/ethernet/intel/ice/ice_main.c:7203-7204
  cancel_work_sync() for tx.dim.work and rx.dim.work
```

CapSched reading:

```text
Useful:
  NAPI execution and DIM work have visible shutdown points.

Not sufficient:
  this does not carry caller Domain, typed CompletionSettlement id, or
  service BudgetTicket. It is service/kernel work, not caller authority.
```

### Ring cleanup

Tx cleanup:

```text
drivers/net/ethernet/intel/ice/ice_txrx.c:203
  ice_clean_tx_ring()

drivers/net/ethernet/intel/ice/ice_txrx.c:208-210
  XDP ring with xsk_pool uses ice_xsk_clean_xdp_ring()

drivers/net/ethernet/intel/ice/ice_txrx.c:217-218
  ice_unmap_and_free_tx_buf() over tx_buf[]

drivers/net/ethernet/intel/ice/ice_txrx.c:223-226
  zero descriptor ring

drivers/net/ethernet/intel/ice/ice_txrx.c:228-229
  reset next_to_use and next_to_clean

drivers/net/ethernet/intel/ice/ice_txrx.c:235
  netdev_tx_reset_queue()
```

Rx cleanup:

```text
drivers/net/ethernet/intel/ice/ice_txrx.c:538
  ice_clean_rx_ring()

drivers/net/ethernet/intel/ice/ice_txrx.c:542-544
  xsk_pool uses ice_xsk_clean_rx_ring()

drivers/net/ethernet/intel/ice/ice_txrx.c:549
  libeth_xdp_return_stash()

drivers/net/ethernet/intel/ice/ice_txrx.c:552-558
  recycle rx_fqes/hdr_fqes

drivers/net/ethernet/intel/ice/ice_txrx.c:563-566
  xdp_rxq_info_detach_mem_model() and xdp_rxq_info_unreg()

drivers/net/ethernet/intel/ice/ice_txrx.c:569
  ice_rxq_pp_destroy()

drivers/net/ethernet/intel/ice/ice_txrx.c:574-578
  zero descriptor ring and reset indexes
```

CapSched gap:

```text
Ring cleanup clears Linux-visible ring state. It is not itself a proof that
DMA is drained, IOMMU mappings are invalidated, or typed ledgers are settled.
formal/0031 rejects clearing ledgers while DMA is still in flight.
```

### XSK and AF_XDP cleanup

XSK pool setup has DMA map/unmap anchors:

```text
drivers/net/ethernet/intel/ice/ice_xsk.c:124
  ice_xsk_pool_disable()

drivers/net/ethernet/intel/ice/ice_xsk.c:131
  xsk_pool_dma_unmap()

drivers/net/ethernet/intel/ice/ice_xsk.c:145
  ice_xsk_pool_enable()

drivers/net/ethernet/intel/ice/ice_xsk.c:156
  xsk_pool_dma_map()
```

Queue-pair disable during XSK pool changes:

```text
drivers/net/ethernet/intel/ice/ice_xsk.c:197
  ice_xsk_pool_setup()

drivers/net/ethernet/intel/ice/ice_xsk.c:215
  ice_qp_dis()

drivers/net/ethernet/intel/ice/ice_xsk.c:229
  ice_qp_ena()
```

XSK cleanup:

```text
drivers/net/ethernet/intel/ice/ice_xsk.c:897
  ice_xsk_clean_rx_ring()

drivers/net/ethernet/intel/ice/ice_xsk.c:905
  xdp_rxq_info_unreg()

drivers/net/ethernet/intel/ice/ice_xsk.c:911
  xsk_buff_free()

drivers/net/ethernet/intel/ice/ice_xsk.c:919
  ice_xsk_clean_xdp_ring()

drivers/net/ethernet/intel/ice/ice_xsk.c:931
  xsk_buff_free() for ICE_TX_BUF_XSK_TX

drivers/net/ethernet/intel/ice/ice_xsk.c:940
  xsk_tx_completed()
```

CapSched gap:

```text
xsk_tx_completed() during cleanup is exactly the kind of event that needs
typed revoke semantics. It may be a legitimate settlement in Linux, but for
CapSched it must be distinguished from stale normal completion delivery after
queue epoch revoke.
```

### Queue-pair disable/enable

`ice_qp_dis()` is a narrower per-queue anchor:

```text
drivers/net/ethernet/intel/ice/ice_base.c:1429
  ice_qp_dis()

drivers/net/ethernet/intel/ice/ice_base.c:1444
  synchronize_net()

drivers/net/ethernet/intel/ice/ice_base.c:1445-1446
  netif_carrier_off()
  netif_tx_stop_queue()

drivers/net/ethernet/intel/ice/ice_base.c:1448-1449
  ice_qvec_dis_irq()
  ice_qvec_toggle_napi(..., false)

drivers/net/ethernet/intel/ice/ice_base.c:1452
  ice_vsi_stop_tx_ring()

drivers/net/ethernet/intel/ice/ice_base.c:1458
  ice_vsi_stop_tx_ring() for XDP ring

drivers/net/ethernet/intel/ice/ice_base.c:1465
  ice_vsi_ctrl_one_rx_ring(..., false)

drivers/net/ethernet/intel/ice/ice_base.c:1466-1467
  ice_qp_clean_rings()
  ice_qp_reset_stats()
```

`ice_qp_ena()` re-enables queues and starts tx queue after `synchronize_net()`:

```text
drivers/net/ethernet/intel/ice/ice_base.c:1476
  ice_qp_ena()

drivers/net/ethernet/intel/ice/ice_base.c:1523
  synchronize_net()

drivers/net/ethernet/intel/ice/ice_base.c:1527-1528
  netif_tx_start_queue()
  netif_carrier_on()
```

CapSched reading:

```text
Good candidate for a future observation slice:
  per-queue disable/enable has source-local ordering around netif stop,
  IRQ/NAPI, Tx/Rx hardware control, clean, and re-enable.

Hard gap:
  no queue epoch exists between ice_qp_dis() and ice_qp_ena().
```

### Representor and eswitch paths

Representor transmit is a lower-netdev handoff:

```text
drivers/net/ethernet/intel/ice/ice_eswitch.c:217
  ice_eswitch_port_start_xmit()

drivers/net/ethernet/intel/ice/ice_eswitch.c:226
  skb->dev = repr->dst->u.port_info.lower_dev

drivers/net/ethernet/intel/ice/ice_eswitch.c:228
  dev_queue_xmit()
```

Representor queues can be stopped:

```text
drivers/net/ethernet/intel/ice/ice_eswitch.c:434
  ice_eswitch_stop_all_tx_queues()

drivers/net/ethernet/intel/ice/ice_repr.c:546
  ice_repr_stop_tx_queues()

drivers/net/ethernet/intel/ice/ice_repr.c:548-549
  netif_carrier_off()
  netif_tx_stop_all_queues()
```

CapSched gap:

```text
Stopping representor netdev queues is not lower QueueLease revoke. The lower
dev_queue_xmit() path still needs RepresentorForwardCap, lower QueueLease
epoch, service budget, and stale-forward prevention.
```

### Service/reset work

Service task scheduling is coalesced:

```text
drivers/net/ethernet/intel/ice/ice_main.c:1667
  ice_service_task_schedule()

drivers/net/ethernet/intel/ice/ice_main.c:1670-1672
  test_and_set ICE_SERVICE_SCHED and queue_work(ice_wq, &pf->serv_task)

drivers/net/ethernet/intel/ice/ice_main.c:1695
  ice_service_task_stop()

drivers/net/ethernet/intel/ice/ice_main.c:1700
  timer_delete_sync()

drivers/net/ethernet/intel/ice/ice_main.c:1702
  cancel_work_sync(&pf->serv_task)
```

Reset subtask:

```text
drivers/net/ethernet/intel/ice/ice_main.c:2292
  ice_service_task()

drivers/net/ethernet/intel/ice/ice_main.c:2300
  ice_reset_subtask()

drivers/net/ethernet/intel/ice/ice_main.c:676
  ice_reset_subtask()

drivers/net/ethernet/intel/ice/ice_main.c:703
  ice_prepare_for_reset()

drivers/net/ethernet/intel/ice/ice_main.c:725-741
  ice_do_reset()
```

Prepare-for-reset:

```text
drivers/net/ethernet/intel/ice/ice_main.c:536
  ice_prepare_for_reset()

drivers/net/ethernet/intel/ice/ice_main.c:550
  synchronize_irq(pf->oicr_irq.virq)

drivers/net/ethernet/intel/ice/ice_main.c:552
  ice_unplug_aux_dev()

drivers/net/ethernet/intel/ice/ice_main.c:556
  ice_vc_notify_reset()

drivers/net/ethernet/intel/ice/ice_main.c:560-562
  ice_set_vf_state_dis()

drivers/net/ethernet/intel/ice/ice_main.c:567
  ice_eswitch_br_fdb_flush()

drivers/net/ethernet/intel/ice/ice_main.c:595
  netif_device_detach()

drivers/net/ethernet/intel/ice/ice_main.c:601
  ice_pf_dis_all_vsi()

drivers/net/ethernet/intel/ice/ice_main.c:604
  ice_ptp_prepare_for_reset()

drivers/net/ethernet/intel/ice/ice_main.c:610
  ice_sched_clear_port()

drivers/net/ethernet/intel/ice/ice_main.c:612
  ice_shutdown_all_ctrlq()
```

CapSched gap:

```text
service work is service/control authority. It is not per-caller authority and
cannot be charged to the last submitter. ICE_SERVICE_SCHED coalescing also
means a single pending service work item cannot safely carry a mutable caller
BudgetTicket.
```

### Devlink reload

Devlink reload reinit uses unload/deconfig/deinit and reload-up:

```text
drivers/net/ethernet/intel/ice/devlink/devlink.c:455
  ice_devlink_reinit_down()

drivers/net/ethernet/intel/ice/devlink/devlink.c:459
  ice_unload()

drivers/net/ethernet/intel/ice/devlink/devlink.c:461
  ice_vsi_decfg()

drivers/net/ethernet/intel/ice/devlink/devlink.c:1235
  ice_devlink_reinit_up()

drivers/net/ethernet/intel/ice/devlink/devlink.c:1262
  ice_vsi_cfg()

drivers/net/ethernet/intel/ice/devlink/devlink.c:1267
  ice_load()
```

CapSched gap:

```text
devlink reload is QueueControl authority. It can be a future control-plane
source anchor, but it is not a monitor-backed QueueControlCap or QueueLease
revoke root.
```

## Formal Obligation Matrix

| formal/0031 obligation | ice source anchors | Current status | Gap |
| --- | --- | --- | --- |
| Block new submit | `netif_tx_disable()` in `ice_down`; `netif_tx_stop_queue()` in `ice_qp_dis`; representor stop queue helpers | source-observed | no monitor QueueTag or queue epoch; netdev stop is not complete authority |
| Bump queue epoch | none | not present | requires CapSched/Monitor state |
| Mask or redirect IRQ | `ice_vsi_dis_irq`, `ice_qvec_dis_irq`, `synchronize_irq` | partial | VF host path skips `synchronize_irq`; no monitor IRQ ownership |
| Drain or quarantine submit/descriptor/DMA | `ice_vsi_stop_*_rings`, `ice_clean_tx_ring`, `ice_clean_rx_ring`, `ice_qp_clean_rings` | partial | no typed SubmitLedger/DescriptorLedger; no proof ledger clear waits for DMA drain |
| Invalidate IOMMU/DMA reachability | `xsk_pool_dma_unmap` for XSK setup/disable; DMA unmap/free in Tx cleanup | partial | no monitor MemoryView/IOMMU invalidation root; no universal packet memory revoke |
| Prevent stale completion delivery | NAPI disable, ring clean, XSK clean | partial | `xsk_tx_completed()` during cleanup needs revoke-aware settlement/quarantine |
| Prevent stale QueueControl | reset flags, devlink reload/down, service task reset path | partial | no QueueControlCap epoch; devlink/control ops are Linux authority |
| Prevent stale RepresentorForward | representor stop queues, eswitch bridge flush, representor destroy paths | partial | stopping representor netdev is not lower QueueLease revoke |
| Stop service work effects | `ice_service_task_stop`, service task reset checks | partial | service work is coalesced and service-authority, no per-Domain carrier |
| Reassign only after drain/quarantine/invalidation | `ice_qp_ena`, rebuild/reload-up paths | source-observed | no old/new queue epoch handoff proof |

## Current Verdict

```text
ice has strong Linux shutdown/rebuild machinery.
ice does not have CapSched revoke semantics.
```

The useful existing anchors are:

```text
ice_down()
ice_vsi_dis_irq()
ice_napi_disable_all()
ice_vsi_stop_lan_tx_rings()
ice_vsi_stop_xdp_tx_rings()
ice_vsi_stop_all_rx_rings()
ice_clean_tx_ring()
ice_clean_rx_ring()
ice_xsk_clean_rx_ring()
ice_xsk_clean_xdp_ring()
ice_qp_dis()
ice_qp_ena()
ice_prepare_for_reset()
ice_service_task_stop()
ice_eswitch_stop_all_tx_queues()
ice_repr_stop_tx_queues()
devlink reload down/up
```

The hard CapSched gaps are:

```text
1. no QueueTag or queue epoch root
2. no typed SubmitLedger, DescriptorLedger, or CompletionSettlement id
3. no monitor-owned IOMMU/MemoryView invalidation
4. no stale XSK/page-pool completion quarantine distinction
5. no VF IRQ ownership proof for the synchronize_irq exception
6. no RepresentorForward-to-lower-QueueLease revoke proof
7. no service work carrier or service/caller authority intersection
8. no old epoch/new epoch reassign proof
```

## Implementation Consequence

Future Linux work may add trace-only observation around these anchors.

Behavior-changing QueueLease revoke enforcement remains forbidden until a
future implementation plan names:

```text
monitor QueueTag and queue epoch
submit/descriptor/completion ledger representation
IOMMU/MemoryView invalidate ordering
IRQ ownership and synchronization, including VF paths
XDP/page-pool and AF_XDP/XSK quarantine semantics
representor lower QueueLease revoke
service work classification and cancellation
old-to-new epoch reassign rule
```
