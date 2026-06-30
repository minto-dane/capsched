# Analysis 0057: Representor Lower QueueLease Source Map

Status: Draft source map with model gate

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
analysis/0053-ice-modern-nic-revoke-source-map.md
formal/0028-modern-nic-queuelease-model/
formal/0030-queuecontrol-representor-model/
formal/0031-modern-nic-queue-revoke-model/
validation/0046-modern-nic-queuelease-tlc.md
validation/0049-queuecontrol-representor-tlc.md
validation/0050-modern-nic-queue-revoke-tlc.md
```

## Purpose

N-084 refines the earlier `RepresentorForward` abstraction against actual
Linux `ice`, bridge, switchdev, TC, and BPF redirect paths.

The narrow risk is:

```text
representor netdev reachability must not become lower QueueLease authority.
```

A representor is a Linux-visible netdev, but packets sent through it can be
retargeted to an uplink/lower device and then transmitted through the lower
device queue machinery. A CapSched-H design must keep these authorities
separate:

```text
RepresentorForward authority:
  may enter a representor forwarding path

lower QueueLease authority:
  may submit to the lower physical queue/DMA/doorbell path

QueueControl/Offload authority:
  may program hardware switch/TC/FDB/VLAN forwarding state
```

This is not an implementation plan and not protection evidence.

## Core Rule

For CapSched-H:

```text
lower queue submit != representor netdev is reachable
lower queue submit != bridge FDB hit
lower queue submit != VLAN allows egress
lower queue submit != TC redirect target exists
lower queue submit != metadata_dst exists
lower queue revoke != representor netdev queue stopped
```

Software representor forwarding requires:

```text
fresh RepresentorForwardCap
fresh representor epoch
fresh metadata_dst binding
metadata lower_dev bound to the same lower QueueLease
fresh lower QueueLease epoch
lower queue budget
bridge/FDB/VLAN admission only as policy input
frozen forwarding carrier visible across dev_queue_xmit()
```

Hardware/switchdev offload requires:

```text
QueueControl/OffloadCap
fresh offload epoch
validated source and destination VSI/port mapping
fresh lower QueueLease epoch for the affected data path
revoke-time removal or invalidation of stale hardware rules
```

## Source Anchors

### ice representor transmit

Useful anchors:

```text
drivers/net/ethernet/intel/ice/ice_repr.c:
  ice_repr_vf_netdev_ops.ndo_start_xmit = ice_eswitch_port_start_xmit line 271
  ice_repr_sf_netdev_ops.ndo_start_xmit = ice_eswitch_port_start_xmit line 281
  ice_repr_stop_tx_queues() line 546

drivers/net/ethernet/intel/ice/ice_eswitch.c:
  ice_eswitch_setup_repr() line 109
  metadata_dst_alloc(..., METADATA_HW_PORT_MUX, ...) line 115
  dst->u.port_info.port_id = vsi->vsi_num line 121
  dst->u.port_info.lower_dev = uplink_vsi->netdev line 122
  ice_eswitch_port_start_xmit() line 216
  skb_dst_set(... repr->dst ...) line 225
  skb->dev = repr->dst->u.port_info.lower_dev line 226
  dev_queue_xmit(skb) line 228
  ice_eswitch_set_target_vsi() line 240
  dst->u.port_info.port_id used in Tx context descriptor line 255

drivers/net/ethernet/intel/ice/ice_lag.c:
  ice_lag_config_eswitch() line 116
  repr->dst->u.port_info.lower_dev = netdev line 123
```

Interpretation:

```text
The representor xmit path retargets skb->dev to the lower device and enters
dev_queue_xmit(). LAG can also rewrite the lower_dev stored in representor
metadata.
```

Forbidden shortcuts:

```text
Do not treat access to the representor netdev as authority to submit on the
lower device queue.

Do not treat metadata_dst existence as lower QueueLease proof; the metadata is
Linux-owned and mutable.

Do not treat LAG lower_dev update as safe unless the metadata is rebound to a
fresh lower QueueLease.
```

### Linux dev_queue_xmit and TC/BPF redirect

Useful anchors:

```text
net/core/dev.c:
  xmit_one() line 3878
  netdev_start_xmit(...) line 3889
  __dev_queue_xmit() line 4768
  dev = skb->dev line 4770
  sch_handle_egress(...) line 4809
  netdev_core_pick_tx(dev, skb, sb_dev) line 4827
  dev_hard_start_xmit(...) line 4872

net/sched/act_mirred.c:
  tcf_mirred_forward() line 237
  tcf_dev_queue_xmit(skb, dev_queue_xmit) line 242
  skb_to_send->dev = dev line 320

net/core/filter.c:
  __bpf_tx_skb() line 2141
  skb->dev = dev line 2151
  dev_queue_xmit(skb) line 2156
  skb_do_redirect() line 2519
```

Interpretation:

```text
Generic Linux transmit and redirect paths use skb->dev as the device to queue
on. TC/BPF can retarget skb->dev. Representor xmit also retargets skb->dev to
the lower device before generic transmit.
```

For CapSched-H, the forwarding carrier must survive this retargeting:

```text
incoming authority:
  representor endpoint / bridge policy / TC policy

outgoing authority:
  lower QueueLease submit authority

required link:
  frozen carrier that binds representor epoch, lower QueueLease epoch, metadata
  generation, and service/budget accounting
```

### bridge, FDB, VLAN, and switchdev marks

Useful anchors:

```text
net/bridge/br_input.c:
  br_handle_frame_finish() line 76
  br_allowed_ingress(...) line 110
  nbp_switchdev_frame_mark(...) line 140
  br_fdb_find_rcu(...) line 204
  br_forward(...) line 226

net/bridge/br_forward.c:
  should_deliver() line 21
  br_allowed_egress(...) line 29
  nbp_switchdev_allowed_egress(...) line 29
  nbp_switchdev_frame_mark_tx_fwd_offload(...) line 84
  br_handle_vlan(...) line 87
  skb->dev = to->dev line 92
  br_dev_queue_push_xmit() line 33
  br_switchdev_frame_set_offload_fwd_mark(...) line 51
  dev_queue_xmit(skb) line 53

net/bridge/br_switchdev.c:
  br_switchdev_frame_set_offload_fwd_mark() line 35
  nbp_switchdev_frame_mark_tx_fwd_offload() line 41
  nbp_switchdev_frame_mark_tx_fwd_to_hwdom() line 53
  nbp_switchdev_frame_mark() line 60
  nbp_switchdev_allowed_egress() line 67
  br_switchdev_fdb_notify() line 144
  SWITCHDEV_FDB_ADD_TO_DEVICE notification line 172
```

Interpretation:

```text
Bridge FDB, VLAN, STP, isolated-port, and switchdev hwdom/offload marks are
forwarding policy and loop/duplication controls. They are useful policy inputs
but are not lower QueueLease proof.
```

Forbidden shortcuts:

```text
Do not treat an FDB hit, VLAN egress success, switchdev hwdom mark, or
offload_fwd_mark as a lower QueueLease.
```

### ice bridge and TC offload programming

Useful anchors:

```text
drivers/net/ethernet/intel/ice/ice_eswitch_br.c:
  ice_eswitch_br_is_dev_valid() line 21
  accepts port representors, PF netdev, and LAG master line 23
  bridge port representor init line 931
  br_port->vsi = repr->src_vsi line 941
  br_port->repr_id = repr->id line 944
  ice_eswitch_br_port_link() line 1100
  repr port link line 1117

drivers/net/ethernet/intel/ice/ice_tc_lib.c:
  ice_tc_setup_action() line 669
  representor-to-representor dest_vsi selection line 683
  representor-to-uplink dest_vsi selection line 689
  uplink-to-representor dest_vsi selection line 695
  ice_eswitch_tc_parse_action() line 727
  FLOW_ACTION_REDIRECT line 741
  FLOW_ACTION_MIRRED line 749
  ice_eswitch_add_tc_fltr() line 914
  rule_info.sw_act.vsi_handle = fltr->dest_vsi->idx line 946
  VF to uplink special case line 967
  ice_add_adv_rule(...) line 994
  ice_del_tc_fltr() line 2127
  ice_rem_adv_rule_by_id(...) line 2142
```

Interpretation:

```text
The driver can program hardware switch forwarding between uplink and
representor/source VSIs. This is not per-packet dev_queue_xmit authority; it is
QueueControl/Offload authority that affects future data-plane reachability.
```

Forbidden shortcuts:

```text
Do not treat TC flower install/delete or bridge offload notification as plain
RepresentorForward. It programs device forwarding state and therefore requires
QueueControl/OffloadCap plus lower QueueLease epoch binding.
```

## Required Forwarding Receipt

A production representor forward receipt must cover:

```text
Representor side:
  representor netdev id
  representor epoch
  source Domain / service Domain
  RepresentorForwardCap

Metadata side:
  metadata_dst generation
  target port_id
  lower_dev identity
  LAG generation if lower_dev came through LAG

Lower queue side:
  lower QueueTag
  lower queue epoch
  queue budget
  IOMMU/MemoryView binding
  IRQ/completion ownership class

Bridge side:
  FDB/VLAN/STP/isolation decisions as policy inputs only
  no bridge decision can mint lower QueueLease authority

TC/offload side:
  QueueControl/OffloadCap
  rule cookie/generation
  source/destination VSI tuple
  rule removal/invalidation receipt on revoke
```

## Design Consequence

The minimum safe separation is:

```text
RepresentorEndpointCap:
  permission to use a representor-facing endpoint

RepresentorForwardCap:
  permission to derive a forwarding carrier from a representor epoch

LowerQueueLease:
  permission to submit to a concrete lower device queue epoch

QueueControl/OffloadCap:
  permission to program or remove hardware switch/TC/FDB/VLAN state
```

The carrier produced at forwarding time must not be a mutable field on
`struct net_device`, `struct ice_repr`, `metadata_dst`, `skb->dev`, bridge FDB
entry, or TC rule alone. Those are Linux-mutable observation objects. The
production authority must be monitor-backed or cryptographically/epoch sealed
against Domain escape.

## Open Follow-Up

This map does not yet decide hook placement. Candidate later hooks include:

```text
ice_eswitch_port_start_xmit()
dev_queue_xmit()/__dev_queue_xmit()
TC redirect/offload setup
bridge switchdev notifications
ice_eswitch_add_tc_fltr()/ice_del_tc_fltr()
LAG lower_dev update
```

Hook choice must wait until implementation planning. The invariant is already
clear: netdev/control-plane reachability cannot be collapsed into lower
QueueLease authority.
