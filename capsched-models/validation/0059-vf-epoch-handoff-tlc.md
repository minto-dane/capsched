# Validation 0059: VF Epoch Handoff TLC

Status: Safe model passed; unsafe models produced expected counterexamples

Date: 2026-06-30

Model:

```text
capsched/capsched-models/formal/0039-vf-epoch-handoff-model/VfEpochHandoff.tla
```

Related artifacts:

```text
capsched/capsched-models/analysis/0060-ice-vf-epoch-handoff-source-map.md
capsched/capsched-models/analysis/ice-vf-epoch-handoff-source-map-v1.json
capsched/capsched-models/validation/0058-vf-mailbox-carrier-tlc.md
```

TLC logs:

```text
/media/nia/scsiusb/dev/linux-cap/build/tlc/vf-epoch-handoff-20260630T024639Z/VfEpochHandoffSafe.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/vf-epoch-handoff-20260630T024639Z/VfEpochHandoffUnsafeVfIdReuse.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/vf-epoch-handoff-20260630T024639Z/VfEpochHandoffUnsafeVsiReuse.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/vf-epoch-handoff-20260630T024639Z/VfEpochHandoffUnsafeQueueReassignStaleDma.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/vf-epoch-handoff-20260630T024639Z/VfEpochHandoffUnsafeIrqReassignStaleRoute.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/vf-epoch-handoff-20260630T024639Z/VfEpochHandoffUnsafeFdirContextSurvives.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/vf-epoch-handoff-20260630T024639Z/VfEpochHandoffUnsafeMailboxAfterReset.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/vf-epoch-handoff-20260630T024639Z/VfEpochHandoffUnsafeAllowlistSurvives.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/vf-epoch-handoff-20260630T024639Z/VfEpochHandoffUnsafeServiceReplayOldEpoch.log
```

## Result Summary

Safe configuration:

```text
config: VfEpochHandoffSafe.cfg
result: PASS
generated states: 9
distinct states: 9
search depth: 9
```

Unsafe configurations produced expected counterexamples:

```text
config: VfEpochHandoffUnsafeVfIdReuse.cfg
target invariant: NoNewDomainEffectFromOldVfEpoch
result: expected FAIL
generated states before violation: 4
distinct states before violation: 4

config: VfEpochHandoffUnsafeVsiReuse.cfg
target invariant: NoVsiReuseWithoutGeneration
result: expected FAIL
generated states before violation: 6
distinct states before violation: 6

config: VfEpochHandoffUnsafeQueueReassignStaleDma.cfg
target invariant: NoQueueReassignBeforeDmaIrqRevoke
result: expected FAIL
generated states before violation: 5
distinct states before violation: 5

config: VfEpochHandoffUnsafeIrqReassignStaleRoute.cfg
target invariant: NoQueueReassignBeforeDmaIrqRevoke
result: expected FAIL
generated states before violation: 5
distinct states before violation: 5

config: VfEpochHandoffUnsafeFdirContextSurvives.cfg
target invariant: NoFdirCompletionAfterEpochChange
result: expected FAIL
generated states before violation: 6
distinct states before violation: 6

config: VfEpochHandoffUnsafeMailboxAfterReset.cfg
target invariant: NoMailboxAcceptedDuringResetOrOldEpoch
result: expected FAIL
generated states before violation: 4
distinct states before violation: 4

config: VfEpochHandoffUnsafeAllowlistSurvives.cfg
target invariant: NoAllowlistSurvivalAcrossReset
result: expected FAIL
generated states before violation: 6
distinct states before violation: 6

config: VfEpochHandoffUnsafeServiceReplayOldEpoch.cfg
target invariant: NoServiceReplayWithoutFreshAuth
result: expected FAIL
generated states before violation: 4
distinct states before violation: 4
```

## Validated Claims

This validation supports these local constraints:

```text
1. Reusing a visible vf_id cannot authorize effects in a new Domain unless the
   old VF epoch is dead, a new VF epoch is live, and the Domain binding is
   fresh.

2. Reusing a VSI index requires a new VSI generation before it can support a
   new Domain effect.

3. Queue reassignment requires queue quiescence plus stale DMA/IOMMU and IRQ
   route revocation before a new effect is allowed.

4. FDIR completion cannot cross a VF epoch change unless the old pending context
   was cleared or replaced by an epoch-tagged completion carrier.

5. Mailbox messages cannot be accepted during reset embargo or under an old
   epoch.

6. Virtchnl allowlist/capability state must be reset or rederived before it can
   influence a new Domain effect.

7. Service reset/rebuild replay requires fresh service authority and fresh VF
   epoch, not just queued service work or driver context.
```

## Unsafe Counterexample Meaning

`VfEpochHandoffUnsafeVfIdReuse.cfg` demonstrates a new Domain effect produced
from the same visible `vf_id` while the old VF epoch is still the only epoch.

`VfEpochHandoffUnsafeVsiReuse.cfg` demonstrates a new Domain effect using the
old VSI generation.

`VfEpochHandoffUnsafeQueueReassignStaleDma.cfg` demonstrates queue reassignment
while stale DMA/IOMMU state is still live.

`VfEpochHandoffUnsafeIrqReassignStaleRoute.cfg` demonstrates queue/interrupt
reassignment while the old IRQ route is still live.

`VfEpochHandoffUnsafeFdirContextSurvives.cfg` demonstrates an FDIR async
completion delivered into a new VF epoch while old FDIR context remains
pending.

`VfEpochHandoffUnsafeMailboxAfterReset.cfg` demonstrates mailbox processing
during reset embargo.

`VfEpochHandoffUnsafeAllowlistSurvives.cfg` demonstrates old virtchnl
allowlist/capability state influencing a new Domain effect after reset.

`VfEpochHandoffUnsafeServiceReplayOldEpoch.cfg` demonstrates reset/rebuild
service replay under the old epoch.

## Evidence Limits

This validation does not prove:

```text
real Intel ice reset correctness
real virtchnl parser correctness
real FDIR hardware correctness
real MSI-X or interrupt-remapping isolation
real DMA/IOMMU invalidation
real service-domain authority enforcement
real HyperTag Monitor implementation
real cluster migration or remote queue handoff correctness
```

Those remain implementation, tracing, and monitor proof obligations.

## Design Consequence

The safe CapSched-H rule is:

```text
VF reset/reassignment =
  mailbox embargo
  + queue quiescence
  + DMA/IOMMU revoke receipt
  + IRQ route revoke receipt
  + FDIR context clear or epoch-tagged completion carrier
  + VF epoch bump
  + VSI and QueueLease generation bump
  + fresh Domain binding
  + fresh service replay authority
  + mailbox reopen under a new VFRequestCarrier
```

Linux-only CapSched may tag and audit this sequence. HyperTag-backed CapSched
must enforce the receipt chain below Linux.
