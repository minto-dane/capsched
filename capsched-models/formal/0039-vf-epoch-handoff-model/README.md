# VF Epoch Handoff Model

Status: Draft, intended for tiny finite TLC checking

Date: 2026-06-30

Related artifacts:

```text
analysis/0060-ice-vf-epoch-handoff-source-map.md
analysis/ice-vf-epoch-handoff-source-map-v1.json
formal/0038-vf-mailbox-carrier-model/
```

## Purpose

This model checks the N-087 handoff boundary for a VF that is reset, removed,
reassigned, or reopened under the same visible VF id.

It models the rule:

```text
visible id reuse must not carry authority across Domain binding epochs
```

## Checked Invariants

```text
NoNewDomainEffectFromOldVfEpoch
NoVsiReuseWithoutGeneration
NoQueueReassignBeforeDmaIrqRevoke
NoFdirCompletionAfterEpochChange
NoMailboxAcceptedDuringResetOrOldEpoch
NoAllowlistSurvivalAcrossReset
NoServiceReplayWithoutFreshAuth
NoBadVfIdReuse
NoBadVsiReuse
NoBadQueueReassignStaleDma
NoBadIrqReassignStaleRoute
NoBadFdirContextSurvives
NoBadMailboxAfterReset
NoBadAllowlistSurvives
NoBadServiceReplayOldEpoch
```

## Modeled Hazards

```text
vf_id reused as identity without a fresh VF epoch
VSI index reused without a new VSI generation
queue reassignment before stale DMA/IOMMU state is revoked
IRQ vector reassignment before stale IRQ route is revoked
FDIR ctx_done/ctx_irq completion survives into a new VF epoch
mailbox message is accepted during reset embargo
virtchnl allowlist/capability state survives reset as authority
service work replays reset/rebuild effects under the old epoch
```

## Scope Limit

This is not a model of SR-IOV, virtchnl, FDIR hardware, MSI-X hardware, or the
Intel `ice` driver implementation. It is a design filter:

```text
reset/reassignment must compile into embargo, quiesce, revoke, epoch bump,
fresh binding, fresh receipts, and reopen.
```

The model intentionally does not choose Linux hook placement.
