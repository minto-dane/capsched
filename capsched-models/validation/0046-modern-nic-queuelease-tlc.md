# Validation 0046: Modern NIC QueueLease TLC

Status: Safe model passed; unsafe models produced expected counterexamples

Date: 2026-06-27

Model:

```text
capsched/capsched-models/formal/0028-modern-nic-queuelease-model/ModernNicQueueLease.tla
```

Related analysis:

```text
capsched/capsched-models/analysis/0052-ice-modern-nic-queuelease-source-map.md
capsched/capsched-models/analysis/0050-aggregate-queuelease-settlement-semantics.md
capsched/capsched-models/analysis/0045-workqueue-internal-redesign-boundary.md
```

TLC logs:

```text
/media/nia/scsiusb/dev/linux-cap/build/tlc/modern-nic-queuelease-20260627T112613Z/ModernNicQueueLeaseSafe.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/modern-nic-queuelease-20260627T112613Z/ModernNicQueueLeaseUnsafeAFXDPNoXSK.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/modern-nic-queuelease-20260627T112613Z/ModernNicQueueLeaseUnsafeAmbientCompletion.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/modern-nic-queuelease-20260627T112613Z/ModernNicQueueLeaseUnsafeDeliverAfterRevoke.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/modern-nic-queuelease-20260627T112613Z/ModernNicQueueLeaseUnsafeDevlinkViaRunCap.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/modern-nic-queuelease-20260627T112613Z/ModernNicQueueLeaseUnsafeRepresentorNoDerive.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/modern-nic-queuelease-20260627T112613Z/ModernNicQueueLeaseUnsafeSKBNoIommu.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/modern-nic-queuelease-20260627T112613Z/ModernNicQueueLeaseUnsafeServiceLastCaller.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/modern-nic-queuelease-20260627T112613Z/ModernNicQueueLeaseUnsafeSubmitNoBind.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/modern-nic-queuelease-20260627T112613Z/ModernNicQueueLeaseUnsafeSubmitNoBudget.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/modern-nic-queuelease-20260627T112613Z/ModernNicQueueLeaseUnsafeXDPUsesSKBLedger.log
```

## Result Summary

Safe configuration:

```text
config: ModernNicQueueLeaseSafe.cfg
result: PASS
generated states: 1474
distinct states: 701
search depth: 12
```

Unsafe configurations produced expected counterexamples:

```text
config: ModernNicQueueLeaseUnsafeSubmitNoBind.cfg
target invariant: NoSubmitWithoutQueueBind
result: expected FAIL
generated states before violation: 3
distinct states before violation: 3

config: ModernNicQueueLeaseUnsafeSubmitNoBudget.cfg
target invariant: NoSubmitWithoutBudget
result: expected FAIL
generated states before violation: 11
distinct states before violation: 11

config: ModernNicQueueLeaseUnsafeSKBNoIommu.cfg
target invariant: NoSubmitClassCollapse
result: expected FAIL
generated states before violation: 11
distinct states before violation: 11

config: ModernNicQueueLeaseUnsafeXDPUsesSKBLedger.cfg
target invariant: NoDescriptorDoorbellWithoutTypedLedger
result: expected FAIL
generated states before violation: 11
distinct states before violation: 11

config: ModernNicQueueLeaseUnsafeAFXDPNoXSK.cfg
target invariant: NoSubmitClassCollapse
result: expected FAIL
generated states before violation: 11
distinct states before violation: 11

config: ModernNicQueueLeaseUnsafeRepresentorNoDerive.cfg
target invariant: NoRepresentorForwardWithoutDerivation
result: expected FAIL
generated states before violation: 11
distinct states before violation: 11

config: ModernNicQueueLeaseUnsafeDevlinkViaRunCap.cfg
target invariant: NoQueueControlWithoutQueueControlCap
result: expected FAIL
generated states before violation: 11
distinct states before violation: 11

config: ModernNicQueueLeaseUnsafeServiceLastCaller.cfg
target invariant: NoServiceWorkAsCallerEffect
result: expected FAIL
generated states before violation: 11
distinct states before violation: 11

config: ModernNicQueueLeaseUnsafeAmbientCompletion.cfg
target invariant: NoCompletionWithoutTypedLedgerAndServiceBudget
result: expected FAIL
generated states before violation: 351
distinct states before violation: 197

config: ModernNicQueueLeaseUnsafeDeliverAfterRevoke.cfg
target invariant: NoDeliveryAfterRevoke
result: expected FAIL
generated states before violation: 117
distinct states before violation: 75
```

## Validated Claims

This validation supports these local constraints:

```text
1. Queue-adjacent work cannot submit descriptors unless QueueBind is live:
   queue, epoch, IRQ route, NAPI ownership, and budget must be present.

2. SKB, XDP frame, XDP_TX page-pool, and AF_XDP zero-copy submissions are
   different submit classes. A common queue ledger may exist only if it records
   the operation class and the class-specific authority proof.

3. SKB submit needs IOMMU/DMA authority for the SKB/frags path.

4. XDP frame and XDP_TX page-pool paths must not borrow SKB submit authority.

5. AF_XDP zero-copy submit needs XSK/UMEM ownership authority rather than plain
   SKB or XDP frame authority.

6. Completion execution is settlement against a typed ledger and service
   budget. Worker, NAPI, IRQ, or service context is not caller authority.

7. Representor forwarding requires a derived representor authority and lower
   QueueLease. It is not plain local netdev transmit.

8. Devlink queue/rate/scheduler changes require QueueControl authority and
   cannot be authorized by RunCap.

9. Service/reset/PTP/DPLL/eswitch maintenance work is service authority. It
   cannot be charged to the last packet submitter and cannot create caller
   endpoint effects by ambient authority.

10. Revocation prevents stale delivery and clears outstanding submit,
    descriptor, doorbell, in-flight, and completion state.
```

## Unsafe Counterexample Meaning

`ModernNicQueueLeaseUnsafeSubmitNoBind.cfg` demonstrates a descriptor submit
without a live queue binding.

`ModernNicQueueLeaseUnsafeSubmitNoBudget.cfg` demonstrates a descriptor submit
after queue budget is absent.

`ModernNicQueueLeaseUnsafeSKBNoIommu.cfg` demonstrates SKB submit without the
DMA/IOMMU proof required by the SKB path.

`ModernNicQueueLeaseUnsafeXDPUsesSKBLedger.cfg` demonstrates XDP submit being
collapsed into the SKB ledger class.

`ModernNicQueueLeaseUnsafeAFXDPNoXSK.cfg` demonstrates AF_XDP zero-copy submit
without XSK/UMEM ownership.

`ModernNicQueueLeaseUnsafeRepresentorNoDerive.cfg` demonstrates representor
forwarding without representor and lower-queue derivation.

`ModernNicQueueLeaseUnsafeDevlinkViaRunCap.cfg` demonstrates devlink
queue-control authorized by RunCap instead of QueueControlCap.

`ModernNicQueueLeaseUnsafeServiceLastCaller.cfg` demonstrates service work
being treated as a caller effect charged to the last submitter.

`ModernNicQueueLeaseUnsafeAmbientCompletion.cfg` demonstrates completion
running by ambient worker/service authority without the typed ledger and
service budget.

`ModernNicQueueLeaseUnsafeDeliverAfterRevoke.cfg` demonstrates delivery after
queue revoke.

## Evidence Limits

This validation does not prove:

```text
real descriptor ring wraparound
NAPI fairness or busy-poll behavior
AF_XDP UMEM layout safety
XDP BPF program safety
real devlink policy correctness
real VF/SF/representor lifecycle correctness
hardware IRQ remapping or IOMMU invalidation latency
monitor-backed queue ownership
```

Those remain future proof obligations.

## Design Consequence

The modern NIC model strengthens the QueueLease direction:

```text
QueueBind:
  queue/ring/q_vector/IRQ/NAPI/epoch ownership

SubmitLedger:
  typed by operation class: SKB, XDP frame, XDP_TX page-pool, AF_XDP

DescriptorLedger:
  descriptor publication, doorbell, in-flight DMA, completion class

CompletionSettlement:
  service-budgeted aggregate settlement, not caller authority

QueueControl:
  devlink/rate/scheduler/VF/SF/representor control-plane authority

ServiceWork:
  reset, PTP, DPLL, eswitch, LAG, DIM, firmware/control work
```

The next safe step is an observation-only readiness checker for `ice` source
anchors and tracepoint/probe coverage. No behavior-changing NIC or workqueue
enforcement is justified by this model alone.
