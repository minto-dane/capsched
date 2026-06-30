# VF Mailbox Carrier Model

Status: Draft, intended for tiny finite TLC checking

Date: 2026-06-30

Related artifacts:

```text
analysis/0059-ice-vf-mailbox-carrier-source-map.md
analysis/ice-vf-mailbox-carrier-source-map-v1.json
formal/0033-monitor-irq-route-invalidation-model/
formal/0034-monitor-dma-iommu-invalidation-model/
formal/0037-modern-nic-servicework-carrier-model/
```

## Purpose

This model checks the N-086 authority separation for VF mailbox operations:

```text
virtchnl validation is not VF request authority
opcode allowlist is not QueueControl authority
VF-provided ring DMA address requires DMA MemoryView/IOMMU authority
queue enable requires prior frozen queue config and live QueueLease
IRQ map requires IRQ route authority
queue bandwidth/quanta requires queue budget authority
FDIR write and completion require OffloadCap and frozen async context
revoke clears active queue/IRQ/budget/FDIR effects until fresh auth
```

## Checked Invariants

```text
NoQueueConfigFromValidationOnly
NoDmaRingBaseWithoutMemoryView
NoQueueEnableWithoutFrozenConfig
NoIrqMapWithoutRouteAuthority
NoBudgetProgramWithoutBudgetCarrier
NoFdirWriteWithoutOffloadCarrier
NoFdirCompletionWithoutFrozenContext
NoEffectAfterRevoke
NoBadValidationAsAuthority
NoBadDmaNoMemoryView
NoBadEnableNoConfig
NoBadIrqNoRoute
NoBadBudgetNoAuth
NoBadFdirNoOffload
NoBadFdirCompleteNoContext
NoBadEffectAfterRevoke
```

## Modeled Hazards

```text
queue config authorized by virtchnl validation and opcode allowlist alone
descriptor-ring DMA base programmed without DMA MemoryView receipt
queue enable before frozen queue config generation
IRQ map without IRQ route authority
queue bandwidth/quanta without queue budget authority
FDIR hardware write without OffloadCap
FDIR async completion without frozen request context
queue or FDIR effect after revoke
```

## Scope Limit

This is not a model of virtchnl, SR-IOV, MSI-X, FDIR hardware, or Intel ice
correctness. It is a design filter:

```text
VF mailbox effects must preserve separate request, queue, DMA, IRQ, budget,
offload, async, epoch, and service-budget authority.
```

The model intentionally does not choose hook placement.
