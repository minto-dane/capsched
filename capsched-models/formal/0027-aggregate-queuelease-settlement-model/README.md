# Aggregate QueueLease Settlement Model

Status: Draft, intended for tiny finite TLC configurations

Date: 2026-06-27

Related analysis:

```text
capsched/capsched-models/analysis/0048-usbnet-workqueue-source-map.md
capsched/capsched-models/analysis/0049-e1000e-queuelease-source-map.md
```

## Purpose

This model captures the local safety rule for merged device completion work:

```text
merged completion callbacks are settlement paths, not caller authority roots.
```

A submit path may publish descriptors and ring a doorbell only after a live
QueueLease, budget, IOMMU permission, and IRQ ownership are established. Later
completion may be merged by NAPI, IRQ coalescing, or a shared work item, but it
must settle against an existing ledger entry rather than overwrite a single
caller BudgetTicket on the shared callback object.

## Modeled Hazards

```text
tail doorbell without live QueueLease
submit after budget exhaustion
device DMA without live IOMMU permission and ledger
merged completion without ledger or service budget
delivery after queue revoke
overwriting ledger state while completion is pending
ambient worker/service completion authority
foreign completion delivery
```

## Checked Invariants

```text
NoTailWithoutLiveQueueLease
NoSubmitWithoutBudget
NoDmaWithoutIommuAndLedger
NoCompletionWithoutLedgerAndServiceBudget
NoDeliveryAfterRevoke
NoLedgerOverwrite
NoAmbientCompletionAuthority
NoForeignCompletion
NoOutstandingAfterRevoke
```

## Scope Limit

This is not a full NIC model. It does not model exact ring sizes, descriptor
wraparound, NAPI fairness, packet contents, real IRQ remapping, or hardware
ordering beyond the abstract submit/completion boundary.

It is a design filter for the CapSched rule:

```text
submit authority belongs at QueueLease/DMA/doorbell boundaries;
merged completion work performs aggregate settlement only.
```
