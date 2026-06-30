# Modern NIC ServiceWork Carrier Model

Status: Draft, intended for tiny finite TLC checking

Date: 2026-06-30

Related artifacts:

```text
analysis/0058-ice-servicework-carrier-source-map.md
analysis/ice-servicework-carrier-source-map-v1.json
formal/0017-workqueue-budgetticket-carrier-model/
formal/0036-representor-lower-queuelease-model/
```

## Purpose

This model checks the N-085 authority separation for modern NIC service work:

```text
service worker execution is not caller authority
merged service loops cannot use a mutable last-caller carrier
VF mailbox queue/control requests need a VF/Domain carrier
PTP/DPLL deferred control work needs caller control authority
bridge/LAG/offload work needs policy/offload/lower-lease authority
reset/rebuild replay after revoke needs fresh reauthorization
```

## Checked Invariants

```text
NoQueueEffectWithoutServiceCallerQueueIntersection
NoControlEffectWithoutServiceCallerControlIntersection
NoOffloadEffectWithoutPolicyOffloadLowerIntersection
NoResetReplayWithoutFreshReauthorization
NoServiceAmbientQueueEffect
NoVfMailboxEffectWithoutCarrier
NoMergedLoopLastCallerAuthority
NoPtpControlWithoutCarrier
NoDpllControlWithoutCarrier
NoBridgeOffloadWithoutPolicyAndControl
NoLagRebindWithoutFreshLowerLease
NoResetReplayAfterRevokeWithoutFreshAuth
```

## Modeled Hazards

```text
service-only worker produces a queue effect
VF mailbox request configures queues without a carrier
coalesced service loop authorizes by last caller
PTP deferred worker applies control without caller cap
DPLL deferred worker applies control without caller cap
bridge/FDB event installs offload without OffloadCap/lower lease
LAG lower_dev rebind proceeds without fresh lower QueueLease
reset/rebuild replay restores old state after revoke
```

## Scope Limit

This is not a real model of `ice`, virtchnl, PTP, DPLL, switchdev, LAG, or
firmware. It is a design filter:

```text
deferred service execution must preserve the distinction between service
authority, caller authority, policy facts, QueueLease, QueueControl, and
fresh replay authorization.
```

The model intentionally does not choose hook placement.
