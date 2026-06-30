# Validation 0052: VF IRQ Revoke Ownership TLC

Status: Safe model passed; unsafe models produced expected counterexamples

Date: 2026-06-29

Model:

```text
capsched/capsched-models/formal/0032-vf-irq-revoke-ownership-model/VFIrqRevokeOwnership.tla
```

Related artifacts:

```text
capsched/capsched-models/analysis/0053-ice-modern-nic-revoke-source-map.md
capsched/capsched-models/validation/0051-ice-revoke-readiness-result.md
capsched/capsched-models/formal/0031-modern-nic-queue-revoke-model/README.md
```

TLC logs:

```text
/media/nia/scsiusb/dev/linux-cap/build/tlc/vf-irq-revoke-ownership-20260630T003143Z/VFIrqRevokeOwnershipSafe.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/vf-irq-revoke-ownership-20260630T003143Z/VFIrqRevokeOwnershipUnsafeHostNoSync.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/vf-irq-revoke-ownership-20260630T003143Z/VFIrqRevokeOwnershipUnsafeMonitorNoInvalidate.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/vf-irq-revoke-ownership-20260630T003143Z/VFIrqRevokeOwnershipUnsafeReassignWithoutOwnerQuiesce.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/vf-irq-revoke-ownership-20260630T003143Z/VFIrqRevokeOwnershipUnsafeVFAssumeHostSync.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/vf-irq-revoke-ownership-20260630T003143Z/VFIrqRevokeOwnershipUnsafeVFCompletionAfterRevoke.log
```

## Result Summary

Safe configuration:

```text
config: VFIrqRevokeOwnershipSafe.cfg
result: PASS
generated states: 25
distinct states: 22
search depth: 6
```

Unsafe configurations produced expected counterexamples:

```text
config: VFIrqRevokeOwnershipUnsafeVFAssumeHostSync.cfg
target invariant: NoVFHostSyncAssumption
result: expected FAIL
generated states before violation: 10
distinct states before violation: 10

config: VFIrqRevokeOwnershipUnsafeVFCompletionAfterRevoke.cfg
target invariant: NoDeliveryAfterRevoke
result: expected FAIL
generated states before violation: 9
distinct states before violation: 9

config: VFIrqRevokeOwnershipUnsafeReassignWithoutOwnerQuiesce.cfg
target invariant: NoReassignWithoutOwnerIrqQuiesce
result: expected FAIL
generated states before violation: 9
distinct states before violation: 9

config: VFIrqRevokeOwnershipUnsafeHostNoSync.cfg
target invariant: NoHostOwnedReassignWithoutSync
result: expected FAIL
generated states before violation: 9
distinct states before violation: 9

config: VFIrqRevokeOwnershipUnsafeMonitorNoInvalidate.cfg
target invariant: NoMonitorOwnedReassignWithoutInvalidation
result: expected FAIL
generated states before violation: 11
distinct states before violation: 11
```

## Validated Claims

This validation supports these local constraints:

```text
1. Host-owned IRQ quiescence and VF/monitor-owned IRQ quiescence are different
   authority cases.

2. The `ice_vsi_dis_irq()` VF path must not be modeled as if host
   synchronize_irq() quiesced the VF interrupt authority.

3. Queue reassignment after revoke requires owner-specific IRQ quiescence.

4. Host-owned IRQ reassignment requires host synchronize_irq() or a stronger
   monitor-owned quiescence rule.

5. VF-owned or monitor-owned IRQ reassignment requires monitor-visible IRQ
   route invalidation or an equivalent non-forgeable route proof.

6. Completion delivery after revoke is unsafe unless it is drained or
   quarantined under the owner-specific IRQ quiescence rule.
```

## Unsafe Counterexample Meaning

`VFIrqRevokeOwnershipUnsafeVFAssumeHostSync.cfg` demonstrates treating the VF
path as if host `synchronize_irq()` had authority.

`VFIrqRevokeOwnershipUnsafeVFCompletionAfterRevoke.cfg` demonstrates a stale
IRQ/completion path delivering after revoke.

`VFIrqRevokeOwnershipUnsafeReassignWithoutOwnerQuiesce.cfg` demonstrates queue
reuse before the current IRQ owner is quiesced.

`VFIrqRevokeOwnershipUnsafeHostNoSync.cfg` demonstrates host-owned queue reuse
without host IRQ synchronization.

`VFIrqRevokeOwnershipUnsafeMonitorNoInvalidate.cfg` demonstrates monitor-owned
queue reuse without monitor IRQ route invalidation.

## Evidence Limits

This validation does not prove:

```text
real ice IRQ race freedom
MSI-X or interrupt-remapping correctness
VFIO/iommufd interrupt ownership
posted interrupt or IOMMU interrupt-remap behavior
NAPI completion drain correctness
monitor-backed IRQ implementation
```

Those remain implementation and monitor proof obligations.

## Design Consequence

The `ICE_VSI_VF` branch in `ice_vsi_dis_irq()` is now a named design hazard,
not an implementation blocker by itself.

The safe CapSched rule is:

```text
PF/host-owned IRQ:
  host synchronization may be useful observation/substrate.

VF or monitor-owned IRQ:
  host synchronization must not be assumed; revoke requires monitor-visible
  IRQ route invalidation or a separately modeled VF route handoff.

Any queue reassignment:
  old IRQ completion authority must be owner-quiesced before old queue epoch
  state can be reused, delivered, or treated as drained.
```
