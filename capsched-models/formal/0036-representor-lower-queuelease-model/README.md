# Representor Lower QueueLease Model

Status: Draft, intended for tiny finite TLC checking

Date: 2026-06-29

Related artifacts:

```text
analysis/0057-representor-lower-queuelease-source-map.md
analysis/representor-lower-queuelease-source-map-v1.json
formal/0030-queuecontrol-representor-model/
validation/0049-queuecontrol-representor-tlc.md
```

## Purpose

This model refines N-084:

```text
Representor netdev reachability, bridge/FDB/VLAN policy, TC redirect targets,
and Linux metadata_dst must not stand in for lower QueueLease authority.
```

The model separates:

```text
representor netdev reachability:
  the Linux netdev can be opened/reached and has .ndo_start_xmit

metadata freshness:
  metadata_dst contains a target port_id and lower_dev binding

bridge/FDB/VLAN policy:
  ingress/egress forwarding decisions

lower QueueLease:
  concrete lower device queue/DMA/epoch/budget authority

TC/switchdev offload:
  hardware rule programming authority

representor stop:
  stopping the representor netdev queue
```

## Modeled Hazards

```text
lower queue submit by representor netdev reachability only
bridge FDB hit treated as lower QueueLease
VLAN allow decision treated as lower QueueLease
TC/switchdev rule installed without QueueControl/OffloadCap
TC/switchdev rule installed against stale lower_dev binding
LAG lower_dev update followed by forward without rebind
software/hardware forward after revoke
representor queue stop treated as lower QueueLease revoke
```

## Checked Invariants

```text
NoSoftwareForwardWithoutLowerDerivation
NoNetdevOnlyLowerForward
NoBridgeFdbAsLowerLease
NoVlanAsLowerLease
NoTcOffloadWithoutControlAndLowerLease
NoHardwareForwardWithoutRuleAndLease
NoLagForwardWithStaleLowerDev
NoLowerEffectAfterRevoke
NoRepresentorStopOnlyRevoke
```

## Scope Limit

This is not a real model of Linux bridge, TC flower, BPF redirect, LAG, or ice
hardware switch programming. It is a design filter:

```text
policy reachability and Linux-mutable forwarding metadata are not lower queue
authority.
```

The model intentionally does not choose hook placement.
