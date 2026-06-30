# VF IRQ Revoke Ownership Model

Status: Checked with safe pass and expected unsafe counterexamples

Date: 2026-06-29

Related artifacts:

```text
analysis/0053-ice-modern-nic-revoke-source-map.md
validation/0051-ice-revoke-readiness-result.md
formal/0031-modern-nic-queue-revoke-model/
validation/0052-vf-irq-revoke-ownership-tlc.md
```

## Purpose

This model refines the `ice_vsi_dis_irq()` VF synchronization exception:

```text
/* don't call synchronize_irq() for VF's from the host */
if (vsi->type == ICE_VSI_VF)
        return;
```

The source behavior may be valid for Linux's current ownership model. It is not
by itself a CapSched QueueLease revoke proof. CapSched must distinguish:

```text
Host-owned IRQ:
  Linux host requested the IRQ and host synchronize_irq() can quiesce the host
  handler path.

VF-owned IRQ:
  host synchronize_irq() is not the authority root; revoke needs monitor-owned
  interrupt routing invalidation or an equivalent non-forgeable VF route proof.

Monitor-owned IRQ:
  the monitor owns interrupt routing/quiescence and must invalidate the route
  before queue reassignment.
```

## Modeled Hazards

```text
VF path assumes host synchronize_irq() authority.
completion delivery occurs after revoke because a stale IRQ path remains live.
queue reassignment happens without owner-specific IRQ quiescence.
host-owned IRQ is reassigned without host synchronize_irq() or monitor quiesce.
monitor-owned IRQ is reassigned without monitor invalidation.
```

## Checked Invariants

```text
NoVFHostSyncAssumption
NoDeliveryAfterRevoke
NoReassignWithoutOwnerIrqQuiesce
NoHostOwnedReassignWithoutSync
NoVFReassignWithoutMonitorInvalidation
NoMonitorOwnedReassignWithoutInvalidation
NoIrqRouteLiveAfterTerminal
NoCompletionRunningAfterTerminal
```

## Scope Limit

This model does not claim real `ice` IRQ correctness. It does not model MSI-X,
interrupt remapping tables, VFIO/iommufd, posted interrupts, NAPI budget,
hardware moderation, or threaded IRQ details.

It is a design filter:

```text
The fact that Linux skips host synchronize_irq() for ICE_VSI_VF must not be
interpreted as QueueLease revoke safety. For CapSched-H, the missing authority
has to be supplied by monitor-owned IRQ route invalidation or a separately
proved VF-owned route protocol.
```
