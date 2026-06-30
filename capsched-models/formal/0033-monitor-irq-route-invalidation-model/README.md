# Monitor IRQ Route Invalidation Model

Status: Checked with safe pass and expected unsafe counterexamples

Date: 2026-06-29

Related artifacts:

```text
analysis/0054-monitor-irq-route-invalidation-source-map.md
analysis/monitor-irq-route-invalidation-source-map-v1.json
formal/0032-vf-irq-revoke-ownership-model/
validation/0052-vf-irq-revoke-ownership-tlc.md
validation/0053-monitor-irq-route-invalidation-tlc.md
```

## Purpose

This model refines N-081:

```text
Map a monitor-backed IRQ route invalidation protocol to Linux ice,
VFIO/iommufd, MSI-X, and interrupt-remapping substrate before any driver or
monitor implementation plan.
```

The model separates:

```text
IrqRouteTag:
  monitor-owned route identity and epoch

VFIO eventfd:
  user-visible delivery endpoint

Linux IRQ/MSI allocation:
  host-visible interrupt substrate

IRTE / interrupt remapping:
  platform route table substrate

IEC flush:
  stale interrupt-entry-cache invalidation

Posted interrupt state:
  optional posted route target that must not survive old epoch revoke
```

## Modeled Hazards

```text
allow_unsafe_interrupts used for production route authority
eventfd delivery after route revoke
queue reassignment without invalidation receipt
receipt issued after IRTE clear but before IEC flush
receipt issued while posted interrupt state survives
receipt issued while VFIO eventfd delivery endpoint remains live
```

## Checked Invariants

```text
NoUnsafeInterruptRoute
NoDeliveryAfterRevoke
NoDeliveryWithoutFreshEpoch
NoReceiptWithoutFullInvalidation
NoReassignWithoutReceipt
NoRouteTagAfterReassign
NoPostedStateAfterReceipt
NoEventfdAfterReceipt
```

## Scope Limit

This is not a real x86, VFIO, iommufd, or `ice` implementation model. It does
not model APIC vector allocation, irqdomain locking, interrupt moderation,
posted interrupt descriptor internals, irq-bypass, KVM irqfd, or real hardware
latency.

It is a design filter:

```text
VFIO eventfd detach, free_irq(), pci_free_irq_vectors(), iommufd isolated-MSI
checks, IRTE clear, and IEC flush are separate proof events.
None may be collapsed into "IRQ revoked" by itself.
```
