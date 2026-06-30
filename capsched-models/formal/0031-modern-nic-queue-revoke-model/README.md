# Modern NIC Queue Revoke Model

Status: Checked with safe pass and expected unsafe counterexamples

Date: 2026-06-29

Related artifacts:

```text
assurance/0002-modern-nic-queuelease-assurance-map.md
formal/0028-modern-nic-queuelease-model/
formal/0029-xdp-afxdp-memory-ownership-model/
formal/0030-queuecontrol-representor-model/
validation/0050-modern-nic-queue-revoke-tlc.md
```

## Purpose

This model refines DEV-NIC-009:

```text
Queue revoke invalidates submit, descriptor, doorbell, in-flight DMA,
completion, control, representor, and service work before authority can be
reused or delivered to another Domain.
```

The modeled design rule is:

```text
revoke is not netdev down/reset
revoke = block new submit + bump epoch + mask IRQ + drain or quarantine all
typed outstanding state + invalidate IOMMU/IRQ before queue reuse
```

## Modeled Hazards

```text
new submit after revoke
completion/delivery after revoke
QueueControl after revoke
RepresentorForward after revoke
service work after revoke
ledger clear while DMA is still in flight
queue reassignment before drain/quarantine
queue reassignment without IOMMU/IRQ invalidation
quarantined completion delivery
```

## Checked Invariants

```text
NoSubmitAfterRevoke
NoDeliveryAfterRevoke
NoControlAfterRevoke
NoRepresentorForwardAfterRevoke
NoServiceWorkAfterRevoke
NoLedgerClearBeforeDrain
NoReassignBeforeDrainOrQuarantine
NoReassignWithoutIommuAndIrqInvalidation
NoQuarantineDelivery
NoOutstandingAfterTerminal
NoOldControlAuthorityAfterRevoke
```

## Scope Limit

This is not an `ice` implementation model. It does not model real descriptor
ring wraparound, interrupt moderation, NAPI poll limits, page-pool recycling,
AF_XDP UMEM layout, or hardware invalidation latency.

It is a design filter for the first revoke rule:

```text
no old queue epoch effect may complete, control, forward, or reassign after
revoke unless it has been drained or quarantined under monitor-visible state.
```
