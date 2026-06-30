# Validation 0053: Monitor IRQ Route Invalidation TLC

Status: Safe model passed; unsafe models produced expected counterexamples

Date: 2026-06-29

Model:

```text
capsched/capsched-models/formal/0033-monitor-irq-route-invalidation-model/MonitorIrqRouteInvalidation.tla
```

Related artifacts:

```text
capsched/capsched-models/analysis/0054-monitor-irq-route-invalidation-source-map.md
capsched/capsched-models/analysis/monitor-irq-route-invalidation-source-map-v1.json
capsched/capsched-models/formal/0032-vf-irq-revoke-ownership-model/README.md
capsched/capsched-models/validation/0052-vf-irq-revoke-ownership-tlc.md
```

TLC logs:

```text
/media/nia/scsiusb/dev/linux-cap/build/tlc/monitor-irq-route-invalidation-20260630T005913Z/MonitorIrqRouteInvalidationSafe.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/monitor-irq-route-invalidation-20260630T005913Z/MonitorIrqRouteInvalidationUnsafeEventfdDelivery.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/monitor-irq-route-invalidation-20260630T005913Z/MonitorIrqRouteInvalidationUnsafeInterruptOverride.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/monitor-irq-route-invalidation-20260630T005913Z/MonitorIrqRouteInvalidationUnsafeReassignNoReceipt.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/monitor-irq-route-invalidation-20260630T005913Z/MonitorIrqRouteInvalidationUnsafeReceiptEventfd.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/monitor-irq-route-invalidation-20260630T005913Z/MonitorIrqRouteInvalidationUnsafeReceiptNoFlush.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/monitor-irq-route-invalidation-20260630T005913Z/MonitorIrqRouteInvalidationUnsafeReceiptPosted.log
```

## Result Summary

Safe configuration:

```text
config: MonitorIrqRouteInvalidationSafe.cfg
result: PASS
generated states: 14
distinct states: 12
search depth: 8
```

Unsafe configurations produced expected counterexamples:

```text
config: MonitorIrqRouteInvalidationUnsafeInterruptOverride.cfg
target invariant: NoUnsafeInterruptRoute
result: expected FAIL
generated states before violation: 4
distinct states before violation: 4

config: MonitorIrqRouteInvalidationUnsafeEventfdDelivery.cfg
target invariant: NoDeliveryAfterRevoke
result: expected FAIL
generated states before violation: 7
distinct states before violation: 7

config: MonitorIrqRouteInvalidationUnsafeReassignNoReceipt.cfg
target invariant: NoReassignWithoutReceipt
result: expected FAIL
generated states before violation: 7
distinct states before violation: 7

config: MonitorIrqRouteInvalidationUnsafeReceiptNoFlush.cfg
target invariant: NoReceiptWithoutFullInvalidation
result: expected FAIL
generated states before violation: 11
distinct states before violation: 11

config: MonitorIrqRouteInvalidationUnsafeReceiptPosted.cfg
target invariant: NoPostedStateAfterReceipt
result: expected FAIL
generated states before violation: 12
distinct states before violation: 11

config: MonitorIrqRouteInvalidationUnsafeReceiptEventfd.cfg
target invariant: NoEventfdAfterReceipt
result: expected FAIL
generated states before violation: 7
distinct states before violation: 7
```

## Validated Claims

This validation supports these local constraints:

```text
1. `allow_unsafe_interrupts` cannot be used for a production QueueLease IRQ
   route.

2. VFIO eventfd delivery after route revoke is unsafe unless the completion is
   quarantined and the old route epoch cannot deliver normally.

3. Queue reassignment requires a monitor-visible route invalidation receipt.

4. A route invalidation receipt requires all modeled pieces:
     isolated MSI predicate
     no unsafe interrupt override
     VFIO eventfd detached
     Linux IRQ path detached
     MSI/MSI-X vector no longer allocated for the old route
     IRTE or equivalent route entry cleared
     interrupt-entry-cache flush completed
     posted interrupt state cleared
     completion quarantined

5. IRTE clear without IEC flush is not sufficient.

6. Posted interrupt state must not survive the old route epoch.
```

## Unsafe Counterexample Meaning

`MonitorIrqRouteInvalidationUnsafeInterruptOverride.cfg` demonstrates accepting
an unsafe interrupt route despite missing isolated MSI.

`MonitorIrqRouteInvalidationUnsafeEventfdDelivery.cfg` demonstrates stale
eventfd delivery after route revoke.

`MonitorIrqRouteInvalidationUnsafeReassignNoReceipt.cfg` demonstrates queue
reuse before the route invalidation receipt exists.

`MonitorIrqRouteInvalidationUnsafeReceiptNoFlush.cfg` demonstrates treating
IRTE clear as sufficient without interrupt-entry-cache flush.

`MonitorIrqRouteInvalidationUnsafeReceiptPosted.cfg` demonstrates issuing a
receipt while posted interrupt state survives.

`MonitorIrqRouteInvalidationUnsafeReceiptEventfd.cfg` demonstrates issuing a
receipt while the VFIO eventfd delivery endpoint remains live.

## Evidence Limits

This validation does not prove:

```text
real interrupt-remapping implementation correctness
real Intel or AMD invalidation latency
real posted interrupt descriptor teardown
real VFIO/iommufd ownership correctness
real ice queue interrupt masking correctness
monitor implementation correctness
```

Those remain implementation and monitor proof obligations.

## Design Consequence

The safe CapSched-H rule is:

```text
IRQ revoked != eventfd detached
IRQ revoked != free_irq()
IRQ revoked != pci_free_irq_vectors()
IRQ revoked != IRTE cleared
IRQ revoked != irq_remapping_enabled

IRQ revoked =
  isolated interrupt route predicate
  + monitor-owned IrqRouteTag and epoch
  + delivery endpoint detached or quarantined
  + Linux IRQ/MSI substrate detached
  + IRTE or equivalent route entry cleared
  + interrupt-entry-cache flush completed
  + posted interrupt state cleared
  + monitor-visible invalidation receipt
```

Any future driver or monitor implementation plan must name how it obtains or
verifies each part of that receipt before old queue epoch reuse.
