# Validation 0050: Modern NIC Queue Revoke TLC

Status: Safe model passed; unsafe models produced expected counterexamples

Date: 2026-06-29

Model:

```text
capsched/capsched-models/formal/0031-modern-nic-queue-revoke-model/ModernNicQueueRevoke.tla
```

Related artifacts:

```text
capsched/capsched-models/assurance/0002-modern-nic-queuelease-assurance-map.md
capsched/capsched-models/formal/0028-modern-nic-queuelease-model/README.md
capsched/capsched-models/formal/0029-xdp-afxdp-memory-ownership-model/README.md
capsched/capsched-models/formal/0030-queuecontrol-representor-model/README.md
```

TLC logs:

```text
/media/nia/scsiusb/dev/linux-cap/build/tlc/modern-nic-queue-revoke-20260630T001016Z/ModernNicQueueRevokeSafe.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/modern-nic-queue-revoke-20260630T001016Z/ModernNicQueueRevokeUnsafeCompletionAfterRevoke.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/modern-nic-queue-revoke-20260630T001016Z/ModernNicQueueRevokeUnsafeControlAfterRevoke.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/modern-nic-queue-revoke-20260630T001016Z/ModernNicQueueRevokeUnsafeLedgerClearBeforeDrain.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/modern-nic-queue-revoke-20260630T001016Z/ModernNicQueueRevokeUnsafeQuarantineDelivery.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/modern-nic-queue-revoke-20260630T001016Z/ModernNicQueueRevokeUnsafeReassignWithoutDrain.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/modern-nic-queue-revoke-20260630T001016Z/ModernNicQueueRevokeUnsafeReassignWithoutIommu.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/modern-nic-queue-revoke-20260630T001016Z/ModernNicQueueRevokeUnsafeRepresentorAfterRevoke.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/modern-nic-queue-revoke-20260630T001016Z/ModernNicQueueRevokeUnsafeServiceAfterRevoke.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/modern-nic-queue-revoke-20260630T001016Z/ModernNicQueueRevokeUnsafeSubmitAfterRevoke.log
```

## Result Summary

Safe configuration:

```text
config: ModernNicQueueRevokeSafe.cfg
result: PASS
generated states: 7
distinct states: 7
search depth: 5
```

Unsafe configurations produced expected counterexamples:

```text
config: ModernNicQueueRevokeUnsafeSubmitAfterRevoke.cfg
target invariant: NoSubmitAfterRevoke
result: expected FAIL
generated states before violation: 4
distinct states before violation: 4

config: ModernNicQueueRevokeUnsafeCompletionAfterRevoke.cfg
target invariant: NoDeliveryAfterRevoke
result: expected FAIL
generated states before violation: 4
distinct states before violation: 4

config: ModernNicQueueRevokeUnsafeControlAfterRevoke.cfg
target invariant: NoControlAfterRevoke
result: expected FAIL
generated states before violation: 4
distinct states before violation: 4

config: ModernNicQueueRevokeUnsafeRepresentorAfterRevoke.cfg
target invariant: NoRepresentorForwardAfterRevoke
result: expected FAIL
generated states before violation: 4
distinct states before violation: 4

config: ModernNicQueueRevokeUnsafeServiceAfterRevoke.cfg
target invariant: NoServiceWorkAfterRevoke
result: expected FAIL
generated states before violation: 4
distinct states before violation: 4

config: ModernNicQueueRevokeUnsafeLedgerClearBeforeDrain.cfg
target invariant: NoLedgerClearBeforeDrain
result: expected FAIL
generated states before violation: 4
distinct states before violation: 4

config: ModernNicQueueRevokeUnsafeReassignWithoutDrain.cfg
target invariant: NoReassignBeforeDrainOrQuarantine
result: expected FAIL
generated states before violation: 4
distinct states before violation: 4

config: ModernNicQueueRevokeUnsafeReassignWithoutIommu.cfg
target invariant: NoReassignWithoutIommuAndIrqInvalidation
result: expected FAIL
generated states before violation: 4
distinct states before violation: 4

config: ModernNicQueueRevokeUnsafeQuarantineDelivery.cfg
target invariant: NoQuarantineDelivery
result: expected FAIL
generated states before violation: 5
distinct states before violation: 5
```

## Validated Claims

This validation supports these local constraints:

```text
1. Revoke blocks new queue submit before stale descriptor or doorbell effects
   can be accepted.

2. Completion delivery after revoke is unsafe unless it is part of a
   monitor-visible drain/settlement rule.

3. QueueControl and RepresentorForward cannot continue after revoke.

4. Service work cannot create caller-attributed effects after revoke.

5. Submit or descriptor ledgers must not be cleared while DMA is still in
   flight.

6. Queue reassignment requires drain or quarantine of outstanding submit,
   descriptor, DMA, completion, control, representor, and service work.

7. Queue reassignment also requires IOMMU invalidation and IRQ masking.

8. Quarantined work cannot later deliver as a normal completion.

9. Old QueueControl, RepresentorForward, and queue budget authority disappear
   after revoke until a new queue epoch is assigned.
```

## Unsafe Counterexample Meaning

`ModernNicQueueRevokeUnsafeSubmitAfterRevoke.cfg` demonstrates descriptor or
doorbell publication after revoke.

`ModernNicQueueRevokeUnsafeCompletionAfterRevoke.cfg` demonstrates stale
completion delivery after revoke.

`ModernNicQueueRevokeUnsafeControlAfterRevoke.cfg` demonstrates QueueControl
continuing after revoke.

`ModernNicQueueRevokeUnsafeRepresentorAfterRevoke.cfg` demonstrates
representor forwarding after revoke.

`ModernNicQueueRevokeUnsafeServiceAfterRevoke.cfg` demonstrates service work
creating an effect after revoke.

`ModernNicQueueRevokeUnsafeLedgerClearBeforeDrain.cfg` demonstrates clearing
the ledger while DMA is still in flight.

`ModernNicQueueRevokeUnsafeReassignWithoutDrain.cfg` demonstrates queue reuse
while typed outstanding state still exists.

`ModernNicQueueRevokeUnsafeReassignWithoutIommu.cfg` demonstrates queue reuse
without IOMMU/IRQ invalidation.

`ModernNicQueueRevokeUnsafeQuarantineDelivery.cfg` demonstrates quarantined
state later delivering as a normal completion.

## Evidence Limits

This validation does not prove:

```text
real ice reset/down ordering
real descriptor ring drain correctness
real NAPI/IRQ race freedom
real AF_XDP/page-pool quarantine correctness
real IOMMU invalidation latency
monitor-backed QueueTag implementation
```

Those remain future proof obligations.

## Design Consequence

The modern NIC revoke gate is now stricter:

```text
revoke != netdev down/reset
revoke != clearing Linux ring state
revoke != disabling a queue in driver-visible state

revoke =
  block new submit
  bump queue epoch
  mask or redirect IRQ
  drain or quarantine typed outstanding state
  invalidate IOMMU/DMA reachability
  prevent stale completion/control/representor/service effects
  only then reassign the queue under a new epoch
```

Any future source map or implementation plan must name where each of these
steps is observed or enforced.
