# Validation 0057: Modern NIC ServiceWork Carrier TLC

Status: Safe model passed; unsafe models produced expected counterexamples

Date: 2026-06-30

Model:

```text
capsched/capsched-models/formal/0037-modern-nic-servicework-carrier-model/ModernNicServiceWork.tla
```

Related artifacts:

```text
capsched/capsched-models/analysis/0058-ice-servicework-carrier-source-map.md
capsched/capsched-models/analysis/ice-servicework-carrier-source-map-v1.json
capsched/capsched-models/formal/0017-workqueue-budgetticket-carrier-model/README.md
capsched/capsched-models/formal/0036-representor-lower-queuelease-model/README.md
capsched/capsched-models/validation/0056-representor-lower-queuelease-tlc.md
```

TLC logs:

```text
/media/nia/scsiusb/dev/linux-cap/build/tlc/modern-nic-servicework-carrier-20260630T015518Z/ModernNicServiceWorkSafe.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/modern-nic-servicework-carrier-20260630T015518Z/ModernNicServiceWorkUnsafeServiceAmbient.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/modern-nic-servicework-carrier-20260630T015518Z/ModernNicServiceWorkUnsafeVfNoCarrier.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/modern-nic-servicework-carrier-20260630T015518Z/ModernNicServiceWorkUnsafeLastCallerMerge.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/modern-nic-servicework-carrier-20260630T015518Z/ModernNicServiceWorkUnsafePtpNoControl.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/modern-nic-servicework-carrier-20260630T015518Z/ModernNicServiceWorkUnsafeDpllNoControl.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/modern-nic-servicework-carrier-20260630T015518Z/ModernNicServiceWorkUnsafeBridgeNoOffload.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/modern-nic-servicework-carrier-20260630T015518Z/ModernNicServiceWorkUnsafeLagNoLowerLease.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/modern-nic-servicework-carrier-20260630T015518Z/ModernNicServiceWorkUnsafeResetReplay.log
```

## Result Summary

Safe configuration:

```text
config: ModernNicServiceWorkSafe.cfg
result: PASS
generated states: 29
distinct states: 18
search depth: 5
```

Unsafe configurations produced expected counterexamples:

```text
config: ModernNicServiceWorkUnsafeServiceAmbient.cfg
target invariant: NoServiceAmbientQueueEffect
result: expected FAIL
generated states before violation: 11
distinct states before violation: 11

config: ModernNicServiceWorkUnsafeVfNoCarrier.cfg
target invariant: NoVfMailboxEffectWithoutCarrier
result: expected FAIL
generated states before violation: 11
distinct states before violation: 11

config: ModernNicServiceWorkUnsafeLastCallerMerge.cfg
target invariant: NoMergedLoopLastCallerAuthority
result: expected FAIL
generated states before violation: 11
distinct states before violation: 11

config: ModernNicServiceWorkUnsafePtpNoControl.cfg
target invariant: NoPtpControlWithoutCarrier
result: expected FAIL
generated states before violation: 8
distinct states before violation: 8

config: ModernNicServiceWorkUnsafeDpllNoControl.cfg
target invariant: NoDpllControlWithoutCarrier
result: expected FAIL
generated states before violation: 8
distinct states before violation: 8

config: ModernNicServiceWorkUnsafeBridgeNoOffload.cfg
target invariant: NoBridgeOffloadWithoutPolicyAndControl
result: expected FAIL
generated states before violation: 8
distinct states before violation: 8

config: ModernNicServiceWorkUnsafeLagNoLowerLease.cfg
target invariant: NoLagRebindWithoutFreshLowerLease
result: expected FAIL
generated states before violation: 28
distinct states before violation: 19

config: ModernNicServiceWorkUnsafeResetReplay.cfg
target invariant: NoResetReplayAfterRevokeWithoutFreshAuth
result: expected FAIL
generated states before violation: 19
distinct states before violation: 16
```

## Validated Claims

This validation supports these local constraints:

```text
1. Worker/kthread execution is service authority, not caller authority.

2. Service authority alone cannot produce caller-attributed queue, control,
   offload, DMA, IRQ, or lower-lease effects.

3. VF mailbox queue/control requests need a VF/Domain request carrier, a fresh
   VF epoch, and typed queue, DMA, IRQ, budget, or control authority according
   to the effect being applied.

4. Coalesced service loops such as pf->serv_task cannot use a mutable
   last-caller field as authority. Authority must be checked per effect.

5. PTP and DPLL deferred work that applies a caller-visible control effect must
   retain caller control authority; the worker identity is not enough.

6. Bridge/FDB/switchdev/TC/LAG policy events are policy facts. They do not mint
   OffloadCap, QueueControlCap, or lower QueueLease authority.

7. Reset/rebuild replay after revoke needs fresh reauthorization before any
   queue, control, representor, offload, or lower-lease effect is restored.
```

## Unsafe Counterexample Meaning

`ModernNicServiceWorkUnsafeServiceAmbient.cfg` demonstrates queue effects by
plain service worker authority.

`ModernNicServiceWorkUnsafeVfNoCarrier.cfg` demonstrates VF mailbox queue or
control effects without a VF/Domain request carrier.

`ModernNicServiceWorkUnsafeLastCallerMerge.cfg` demonstrates coalesced service
work using a mutable last-caller carrier.

`ModernNicServiceWorkUnsafePtpNoControl.cfg` demonstrates PTP control work
without a caller control carrier.

`ModernNicServiceWorkUnsafeDpllNoControl.cfg` demonstrates DPLL control work
without a caller control carrier.

`ModernNicServiceWorkUnsafeBridgeNoOffload.cfg` demonstrates bridge or
switchdev offload effects without policy plus offload/control authority.

`ModernNicServiceWorkUnsafeLagNoLowerLease.cfg` demonstrates LAG lower_dev
rebind without a fresh lower QueueLease.

`ModernNicServiceWorkUnsafeResetReplay.cfg` demonstrates reset/rebuild replay
after revoke without fresh queue/control/offload authorization.

## Evidence Limits

This validation does not prove:

```text
real ice service task correctness
real virtchnl queue-control safety
real PTP or DPLL subsystem correctness
real bridge, switchdev, TC, or LAG policy correctness
real service-domain budget charging
real cancellation of stale Linux work items
real HyperTag Monitor enforcement
```

Those remain implementation and monitor proof obligations.

## Design Consequence

The safe CapSched-H rule is:

```text
caller-derived service work effect =
  service Domain authority
  + per-effect caller/request carrier
  + typed endpoint cap for the effect
  + fresh caller/request/service/queue/device epochs
  + QueueLease, QueueControl, Offload, PTP, DPLL, IRQ, DMA, or lower-lease
    authority as required by the effect
  + service budget or explicit caller-charged service budget

pure maintenance service work =
  service Domain authority
  + maintenance class allowlist
  + device epoch freshness
  + service budget
```

Any future implementation plan must name how it preserves per-effect authority
through `ice_service_task()`, `ice_vc_process_vf_msg()`,
`ice_vc_cfg_qs_msg()`, PTP/DPLL deferred workers, bridge/eswitch work, LAG
event work, reset/rebuild replay, and workqueue coalescing. Generic workqueue
execution is not a production security hook by itself.
