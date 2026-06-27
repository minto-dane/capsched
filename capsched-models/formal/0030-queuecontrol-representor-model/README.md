# QueueControl and RepresentorForward Model

Status: Checked for tiny finite TLC configurations

Date: 2026-06-27

Related artifacts:

```text
capsched/capsched-models/analysis/0052-ice-modern-nic-queuelease-source-map.md
capsched/capsched-models/validation/0047-ice-modern-nic-readiness-result.md
capsched/capsched-models/formal/0028-modern-nic-queuelease-model/README.md
```

## Purpose

This model separates modern NIC control-plane authority from execution and
ordinary netdev reachability.

The modeled design rules are:

```text
RunCap is not QueueControlCap.
netdev reachability is not QueueControlCap.
representor transmit requires RepresentorForwardCap plus a live lower
QueueLease.
```

## Modeled Hazards

```text
devlink queue/rate/scheduler control through RunCap
devlink queue/rate/scheduler control through plain netdev reachability
representor forwarding without RepresentorForwardCap
representor forwarding without lower QueueLease
representor forwarding with stale lower queue epoch
representor forwarding by plain netdev reachability
representor forwarding without service budget
queue control after revoke
representor forwarding after revoke
```

## Checked Invariants

```text
NoQueueControlWithoutCap
NoRunCapAsQueueControl
NoNetdevReachabilityAsQueueControl
NoRepresentorForwardWithoutDerivation
NoPlainNetdevRepresentorForward
NoControlOrForwardAfterRevoke
```

## Scope Limit

This model does not implement devlink policy, actual VF/SF lifecycle, bridge
FDB/VLAN semantics, TC flower, or hardware eswitch behavior. It only checks the
authority separation that must hold before those details are modeled.
