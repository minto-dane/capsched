# Validation 0060: Modern NIC HyperTag Split TLC

Status: Safe model passed; unsafe models produced expected counterexamples

Date: 2026-06-30

Model:

```text
capsched/capsched-models/formal/0040-modern-nic-hypertag-split-model/NicHypertagSplit.tla
```

Related artifacts:

```text
capsched/capsched-models/analysis/0061-modern-nic-hypertag-interface-map.md
capsched/capsched-models/analysis/modern-nic-hypertag-interface-map-v1.json
capsched/capsched-models/validation/0059-vf-epoch-handoff-tlc.md
```

TLC logs:

```text
/media/nia/scsiusb/dev/linux-cap/build/tlc/nic-hypertag-split-20260630T040652Z/NicHypertagSplitSafe.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/nic-hypertag-split-20260630T040652Z/NicHypertagSplitUnsafeServiceMint.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/nic-hypertag-split-20260630T040652Z/NicHypertagSplitUnsafeLinuxDma.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/nic-hypertag-split-20260630T040652Z/NicHypertagSplitUnsafeLinuxIrq.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/nic-hypertag-split-20260630T040652Z/NicHypertagSplitUnsafeRawEndpoint.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/nic-hypertag-split-20260630T040652Z/NicHypertagSplitUnsafeActivateNoDmaIrq.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/nic-hypertag-split-20260630T040652Z/NicHypertagSplitUnsafeServiceReplay.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/nic-hypertag-split-20260630T040652Z/NicHypertagSplitUnsafeRemoteLeaseDirect.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/nic-hypertag-split-20260630T040652Z/NicHypertagSplitUnsafeAuditOnly.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/nic-hypertag-split-20260630T040652Z/NicHypertagSplitUnsafePacketTrap.log
```

## Result Summary

Safe configuration:

```text
config: NicHypertagSplitSafe.cfg
result: PASS
generated states: 10
distinct states: 10
search depth: 10
```

Unsafe configurations produced expected counterexamples:

```text
config: NicHypertagSplitUnsafeServiceMint.cfg
target invariant: NoServiceMintedMonitorRoot
result: expected FAIL
generated states before violation: 3
distinct states before violation: 3

config: NicHypertagSplitUnsafeLinuxDma.cfg
target invariant: NoLinuxDmaAsReceipt
result: expected FAIL
generated states before violation: 7
distinct states before violation: 7

config: NicHypertagSplitUnsafeLinuxIrq.cfg
target invariant: NoLinuxIrqAsReceipt
result: expected FAIL
generated states before violation: 7
distinct states before violation: 7

config: NicHypertagSplitUnsafeRawEndpoint.cfg
target invariant: NoRawEndpointToTarget
result: expected FAIL
generated states before violation: 8
distinct states before violation: 8

config: NicHypertagSplitUnsafeActivateNoDmaIrq.cfg
target invariant: NoQueueActivationWithoutDmaIrq
result: expected FAIL
generated states before violation: 7
distinct states before violation: 7

config: NicHypertagSplitUnsafeServiceReplay.cfg
target invariant: NoServiceReplayOldEpoch
result: expected FAIL
generated states before violation: 7
distinct states before violation: 7

config: NicHypertagSplitUnsafeRemoteLeaseDirect.cfg
target invariant: NoRemoteLeaseDirectUse
result: expected FAIL
generated states before violation: 3
distinct states before violation: 3

config: NicHypertagSplitUnsafeAuditOnly.cfg
target invariant: NoAuditOnlyMonitor
result: expected FAIL
generated states before violation: 6
distinct states before violation: 6

config: NicHypertagSplitUnsafePacketTrap.cfg
target invariant: NoPerPacketMonitorTrap
result: expected FAIL
generated states before violation: 11
distinct states before violation: 11
```

## Validated Claims

This validation supports these local constraints:

```text
1. A target Domain data-plane effect requires local monitor lease compilation,
   device-root receipt, service policy, VF epoch receipt, QueueLease receipt,
   fresh queue epoch, DMA receipt, IRQ receipt, ledger root receipt, typed
   endpoints, and fresh service carrier.

2. Linux service/driver Domains may parse policy and program hardware, but must
   not mint monitor QueueLease/DMA/IRQ/VF epoch roots.

3. Linux DMA map/unmap and IRQ setup/teardown are substrate, not monitor
   receipts.

4. Target Domains must receive typed endpoints, not raw PF/VF/IOMMU/MSI/devlink
   authority.

5. Queue activation requires matching DMA, IRQ, and ledger root receipts.

6. Reset/rebuild service replay must not use old epoch state.

7. Cluster leases must be compiled into local monitor roots before local queue
   use.

8. Monitor calls cannot be audit-only; the side effect must be gated before
   Linux-visible identifiers are reused or hardware-mutating effects occur.

9. Normal packet submission should not require per-packet monitor traps after
   QueueLease, DMA, IRQ, endpoint, and ledger roots are established.
```

## Unsafe Counterexample Meaning

`NicHypertagSplitUnsafeServiceMint.cfg` demonstrates the service Domain minting
QueueLease-like authority.

`NicHypertagSplitUnsafeLinuxDma.cfg` demonstrates Linux DMA state being treated
as a monitor DMA receipt.

`NicHypertagSplitUnsafeLinuxIrq.cfg` demonstrates Linux IRQ state being treated
as a monitor IRQ receipt.

`NicHypertagSplitUnsafeRawEndpoint.cfg` demonstrates exposing raw PF/VF/IOMMU/
MSI/devlink authority to a target Domain.

`NicHypertagSplitUnsafeActivateNoDmaIrq.cfg` demonstrates queue activation
without matching DMA and IRQ receipts.

`NicHypertagSplitUnsafeServiceReplay.cfg` demonstrates reset/rebuild service
replay under an old queue epoch.

`NicHypertagSplitUnsafeRemoteLeaseDirect.cfg` demonstrates using a signed
cluster lease directly without local monitor compilation.

`NicHypertagSplitUnsafeAuditOnly.cfg` demonstrates a monitor interface that
observes effects only after Linux has already performed them.

`NicHypertagSplitUnsafePacketTrap.cfg` demonstrates a design that requires
monitor entry on ordinary packet submission, violating the cost-efficiency
fast-path rule.

## Evidence Limits

This validation does not prove:

```text
real HyperTag Monitor implementation
real NIC hardware correctness
real IOMMU/interrupt-remapping correctness
real Linux service Domain isolation
real driver TCB size
real packet throughput or latency
real cluster control-plane safety
```

Those remain implementation, trace, hardware, and evaluation obligations.

## Design Consequence

The safe CapSched-H modern NIC split is:

```text
HyperTag Monitor:
  owns roots and receipt minting

Linux service/driver Domain:
  parses policy and programs hardware only after receipts

Target Domain:
  receives typed endpoints and direct data-plane queues within monitor leases

Root/cluster management:
  admits and compiles remote policy into local monitor roots
```

Any future behavior-changing implementation plan must name the consumed monitor
receipt and typed service/endpoint carrier for each queue, DMA, IRQ, offload,
representor, reset, mailbox, and completion effect.
