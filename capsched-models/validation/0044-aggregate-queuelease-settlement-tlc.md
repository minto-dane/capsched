# Validation 0044: Aggregate QueueLease Settlement TLC

Status: Safe model passed; unsafe models produced expected counterexamples

Date: 2026-06-27

Model:

```text
capsched/capsched-models/formal/0027-aggregate-queuelease-settlement-model/AggregateQueueSettlement.tla
```

Related analysis:

```text
capsched/capsched-models/analysis/0050-aggregate-queuelease-settlement-semantics.md
capsched/capsched-models/analysis/0048-usbnet-workqueue-source-map.md
capsched/capsched-models/analysis/0049-e1000e-queuelease-source-map.md
```

TLC logs:

```text
/media/nia/scsiusb/dev/linux-cap/build/tlc/aggregate-queue-settlement-20260627T104755Z/AggregateQueueSettlementSafe.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/aggregate-queue-settlement-20260627T104755Z/AggregateQueueSettlementUnsafeDoorbell.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/aggregate-queue-settlement-20260627T104755Z/AggregateQueueSettlementUnsafeSubmitNoBudget.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/aggregate-queue-settlement-20260627T104755Z/AggregateQueueSettlementUnsafeDmaNoIommu.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/aggregate-queue-settlement-20260627T104755Z/AggregateQueueSettlementUnsafeCompleteNoLedger.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/aggregate-queue-settlement-20260627T104755Z/AggregateQueueSettlementUnsafeCompleteNoServiceBudget.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/aggregate-queue-settlement-20260627T104755Z/AggregateQueueSettlementUnsafeDeliverAfterRevoke.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/aggregate-queue-settlement-20260627T104755Z/AggregateQueueSettlementUnsafeOverwrite.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/aggregate-queue-settlement-20260627T104755Z/AggregateQueueSettlementUnsafeAmbient.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/aggregate-queue-settlement-20260627T104755Z/AggregateQueueSettlementUnsafeForeign.log
```

## Result Summary

Safe configuration:

```text
config: AggregateQueueSettlementSafe.cfg
result: PASS
generated states: 16
distinct states: 11
search depth: 7
```

Unsafe configurations produced expected counterexamples:

```text
config: AggregateQueueSettlementUnsafeDoorbell.cfg
target invariant: NoTailWithoutLiveQueueLease
result: expected FAIL
generated states before violation: 3
distinct states before violation: 3
depth: 2

config: AggregateQueueSettlementUnsafeSubmitNoBudget.cfg
target invariant: NoSubmitWithoutBudget
result: expected FAIL
generated states before violation: 5
distinct states before violation: 5
depth: 3

config: AggregateQueueSettlementUnsafeDmaNoIommu.cfg
target invariant: NoDmaWithoutIommuAndLedger
result: expected FAIL
generated states before violation: 7
distinct states before violation: 6
depth: 4

config: AggregateQueueSettlementUnsafeCompleteNoLedger.cfg
target invariant: NoCompletionWithoutLedgerAndServiceBudget
result: expected FAIL
generated states before violation: 10
distinct states before violation: 8
depth: 5

config: AggregateQueueSettlementUnsafeCompleteNoServiceBudget.cfg
target invariant: NoCompletionWithoutLedgerAndServiceBudget
result: expected FAIL
generated states before violation: 10
distinct states before violation: 8
depth: 5

config: AggregateQueueSettlementUnsafeDeliverAfterRevoke.cfg
target invariant: NoDeliveryAfterRevoke
result: expected FAIL
generated states before violation: 7
distinct states before violation: 6
depth: 4

config: AggregateQueueSettlementUnsafeOverwrite.cfg
target invariant: NoLedgerOverwrite
result: expected FAIL
generated states before violation: 10
distinct states before violation: 8
depth: 5

config: AggregateQueueSettlementUnsafeAmbient.cfg
target invariant: NoAmbientCompletionAuthority
result: expected FAIL
generated states before violation: 10
distinct states before violation: 8
depth: 5

config: AggregateQueueSettlementUnsafeForeign.cfg
target invariant: NoForeignCompletion
result: expected FAIL
generated states before violation: 7
distinct states before violation: 6
depth: 4
```

## Validated Claims

This validation supports these local constraints:

```text
1. Tail doorbell requires live QueueLease, fresh epoch, descriptor publication,
   and submit authorization.

2. Submit requires live queue budget/rate allowance.

3. Device DMA/completion observation requires live IOMMU permission and an
   in-flight ledger entry.

4. Merged completion execution requires a live ledger entry and service budget.

5. Queue revoke must prevent delivery under stale queue ownership.

6. Pending merged completion must not overwrite ledger state with a later caller.

7. Worker, IRQ, NAPI, or service context does not provide ambient caller
   completion authority.

8. Foreign completion delivery is forbidden.

9. Revocation must clear outstanding descriptor, DMA, ledger, pending work, and
   running completion state before ordinary delivery can continue.
```

## Unsafe Counterexample Meaning

`AggregateQueueSettlementUnsafeDoorbell.cfg` demonstrates descriptor/tail
publication without a live QueueLease.

`AggregateQueueSettlementUnsafeSubmitNoBudget.cfg` demonstrates descriptor
submission after queue budget is removed.

`AggregateQueueSettlementUnsafeDmaNoIommu.cfg` demonstrates device DMA
observation after IOMMU permission disappears.

`AggregateQueueSettlementUnsafeCompleteNoLedger.cfg` demonstrates merged
completion running after the per-submit ledger has been lost.

`AggregateQueueSettlementUnsafeCompleteNoServiceBudget.cfg` demonstrates
completion running without service budget.

`AggregateQueueSettlementUnsafeDeliverAfterRevoke.cfg` demonstrates stale
delivery after queue revoke.

`AggregateQueueSettlementUnsafeOverwrite.cfg` demonstrates the exact workqueue
coalescing hazard: replacing pending settlement state instead of merging
against a ledger.

`AggregateQueueSettlementUnsafeAmbient.cfg` demonstrates treating worker or
service context as completion authority.

`AggregateQueueSettlementUnsafeForeign.cfg` demonstrates completion delivery
for the wrong queue/domain.

## Evidence Limits

This validation does not prove:

```text
real descriptor-ring wraparound
multi-queue sharing
XDP/page-pool memory recycling
RX endpoint demux
real interrupt remapping hardware behavior
IOMMU invalidation latency
all NAPI busy-poll or netpoll paths
NVMe/GPU-specific completion semantics
```

Those remain future proof obligations.

## Design Consequence

The next behavior-changing device/network prototype must not begin by changing
generic workqueue semantics.

The next safe device-facing design work is:

```text
per-submit or per-descriptor QueueLease ledger
service-domain completion budget
revoke/drop/quarantine ordering
observation-only Linux tags before enforcement
```
