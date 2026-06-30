# Validation 0058: VF Mailbox Carrier TLC

Status: Safe model passed; unsafe models produced expected counterexamples

Date: 2026-06-30

Model:

```text
capsched/capsched-models/formal/0038-vf-mailbox-carrier-model/VfMailboxCarrier.tla
```

Related artifacts:

```text
capsched/capsched-models/analysis/0059-ice-vf-mailbox-carrier-source-map.md
capsched/capsched-models/analysis/ice-vf-mailbox-carrier-source-map-v1.json
capsched/capsched-models/validation/0053-monitor-irq-route-invalidation-tlc.md
capsched/capsched-models/validation/0054-monitor-dma-iommu-invalidation-tlc.md
capsched/capsched-models/validation/0057-modern-nic-servicework-carrier-tlc.md
```

TLC logs:

```text
/media/nia/scsiusb/dev/linux-cap/build/tlc/vf-mailbox-carrier-20260630T023200Z/VfMailboxCarrierSafe.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/vf-mailbox-carrier-20260630T023200Z/VfMailboxCarrierUnsafeValidationAsAuthority.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/vf-mailbox-carrier-20260630T023200Z/VfMailboxCarrierUnsafeDmaNoMemoryView.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/vf-mailbox-carrier-20260630T023200Z/VfMailboxCarrierUnsafeEnableNoConfig.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/vf-mailbox-carrier-20260630T023200Z/VfMailboxCarrierUnsafeIrqNoRoute.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/vf-mailbox-carrier-20260630T023200Z/VfMailboxCarrierUnsafeBudgetNoAuth.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/vf-mailbox-carrier-20260630T023200Z/VfMailboxCarrierUnsafeFdirNoOffload.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/vf-mailbox-carrier-20260630T023200Z/VfMailboxCarrierUnsafeFdirCompleteNoContext.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/vf-mailbox-carrier-20260630T023200Z/VfMailboxCarrierUnsafeEffectAfterRevoke.log
```

## Result Summary

Safe configuration:

```text
config: VfMailboxCarrierSafe.cfg
result: PASS
generated states: 42
distinct states: 23
search depth: 7
```

Unsafe configurations produced expected counterexamples:

```text
config: VfMailboxCarrierUnsafeValidationAsAuthority.cfg
target invariant: NoBadValidationAsAuthority
result: expected FAIL
generated states before violation: 4
distinct states before violation: 4

config: VfMailboxCarrierUnsafeDmaNoMemoryView.cfg
target invariant: NoDmaRingBaseWithoutMemoryView
result: expected FAIL
generated states before violation: 9
distinct states before violation: 9

config: VfMailboxCarrierUnsafeEnableNoConfig.cfg
target invariant: NoQueueEnableWithoutFrozenConfig
result: expected FAIL
generated states before violation: 9
distinct states before violation: 9

config: VfMailboxCarrierUnsafeIrqNoRoute.cfg
target invariant: NoIrqMapWithoutRouteAuthority
result: expected FAIL
generated states before violation: 9
distinct states before violation: 9

config: VfMailboxCarrierUnsafeBudgetNoAuth.cfg
target invariant: NoBudgetProgramWithoutBudgetCarrier
result: expected FAIL
generated states before violation: 9
distinct states before violation: 9

config: VfMailboxCarrierUnsafeFdirNoOffload.cfg
target invariant: NoFdirWriteWithoutOffloadCarrier
result: expected FAIL
generated states before violation: 9
distinct states before violation: 9

config: VfMailboxCarrierUnsafeFdirCompleteNoContext.cfg
target invariant: NoFdirCompletionWithoutFrozenContext
result: expected FAIL
generated states before violation: 9
distinct states before violation: 9

config: VfMailboxCarrierUnsafeEffectAfterRevoke.cfg
target invariant: NoEffectAfterRevoke
result: expected FAIL
generated states before violation: 20
distinct states before violation: 16
```

## Validated Claims

This validation supports these local constraints:

```text
1. Virtchnl payload validation and opcode allowlists are not VF request
   authority.

2. Queue configuration requires a frozen VF request carrier, fresh VF epoch,
   QueueLease, QueueControl authority, queue epoch, DMA MemoryView/IOMMU
   receipt, service authority, and service budget.

3. VF-provided descriptor-ring DMA base cannot be programmed without
   MemoryView/IOMMU authority.

4. Queue enable requires prior frozen queue configuration and live QueueLease.

5. IRQ queue-vector mapping requires IRQ route authority.

6. Queue bandwidth/quanta programming requires queue budget authority.

7. FDIR/offload hardware writes require OffloadCap or QueueControl authority.

8. FDIR async completion requires the frozen request context, fresh VF/rule
   generation, live service authority, and live offload/control authority.

9. Revoke clears active queue, DMA, IRQ, budget, and FDIR effects until fresh
   authorization exists.
```

## Unsafe Counterexample Meaning

`VfMailboxCarrierUnsafeValidationAsAuthority.cfg` demonstrates queue config by
virtchnl validation and opcode allowlist alone.

`VfMailboxCarrierUnsafeDmaNoMemoryView.cfg` demonstrates descriptor-ring DMA
base programming without a DMA MemoryView/IOMMU receipt.

`VfMailboxCarrierUnsafeEnableNoConfig.cfg` demonstrates queue enable before a
frozen queue configuration generation exists.

`VfMailboxCarrierUnsafeIrqNoRoute.cfg` demonstrates queue-vector IRQ mapping
without IRQ route authority.

`VfMailboxCarrierUnsafeBudgetNoAuth.cfg` demonstrates queue rate/quanta
programming without queue budget authority.

`VfMailboxCarrierUnsafeFdirNoOffload.cfg` demonstrates FDIR hardware rule
write without OffloadCap or QueueControl authority.

`VfMailboxCarrierUnsafeFdirCompleteNoContext.cfg` demonstrates FDIR async
completion without frozen request context.

`VfMailboxCarrierUnsafeEffectAfterRevoke.cfg` demonstrates queue/FDIR effects
after revoke without fresh authorization.

## Evidence Limits

This validation does not prove:

```text
real virtchnl parser correctness
real ice queue configuration safety
real MSI-X or interrupt-remapping safety
real DMA/IOMMU isolation
real FDIR hardware correctness
real service-domain budget charging
real HyperTag Monitor enforcement
```

Those remain implementation and monitor proof obligations.

## Design Consequence

The safe CapSched-H rule is:

```text
VF mailbox queue/DMA/IRQ/budget/offload effect =
  service Domain authority
  + VFRequestCarrier
  + fresh VF epoch
  + effect-specific cap
  + fresh queue/rule/device epoch
  + monitor-backed QueueLease, DMA MemoryView/IOMMU, IRQ route, queue budget,
    QueueControl, or Offload authority according to the effect
  + service budget or caller-charged service ticket
```

Any future implementation plan must name how it preserves this before
`ice_vc_cfg_qs_msg()`, `ice_vsi_cfg_single_txq()`, `ice_vsi_cfg_single_rxq()`,
`ice_vc_cfg_irq_map_msg()`, `ice_vc_ena_qs_msg()`, `ice_vc_cfg_q_bw()`,
`ice_vc_cfg_q_quanta()`, `ice_vc_add_fdir_fltr()`, `ice_vc_del_fdir_fltr()`,
and `ice_flush_fdir_ctx()` are treated as security-relevant enforcement points.
