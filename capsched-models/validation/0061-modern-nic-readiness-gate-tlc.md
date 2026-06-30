# Validation 0061: Modern NIC HyperTag Readiness Gate TLC

Status: Safe model passed; unsafe models produced expected counterexamples

Date: 2026-06-30

Model:

```text
capsched/capsched-models/formal/0041-modern-nic-readiness-gate-model/NicHypertagReadinessGate.tla
```

Related artifacts:

```text
capsched/capsched-models/analysis/0062-modern-nic-hypertag-readiness-probe-map.md
capsched/capsched-models/analysis/modern-nic-hypertag-readiness-probe-map-v1.json
capsched/capsched-models/implementation/0007-modern-nic-hypertag-readiness-gate.md
```

TLC logs:

```text
/media/nia/scsiusb/dev/linux-cap/build/tlc/nic-hypertag-readiness-gate-20260630T042432Z/NicHypertagReadinessGateSafe.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/nic-hypertag-readiness-gate-20260630T042432Z/NicHypertagReadinessGateUnsafeBehaviorBeforeGate.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/nic-hypertag-readiness-gate-20260630T042432Z/NicHypertagReadinessGateUnsafeProbeAsAuthority.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/nic-hypertag-readiness-gate-20260630T042432Z/NicHypertagReadinessGateUnsafeStubEnforces.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/nic-hypertag-readiness-gate-20260630T042432Z/NicHypertagReadinessGateUnsafeMissingCoverage.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/nic-hypertag-readiness-gate-20260630T042432Z/NicHypertagReadinessGateUnsafeRawEndpointStub.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/nic-hypertag-readiness-gate-20260630T042432Z/NicHypertagReadinessGateUnsafeProtectionClaim.log
```

## Result Summary

Safe configuration:

```text
config: NicHypertagReadinessGateSafe.cfg
result: PASS
generated states: 8
distinct states: 7
search depth: 7
```

Unsafe configurations produced expected counterexamples:

```text
config: NicHypertagReadinessGateUnsafeBehaviorBeforeGate.cfg
target invariant: NoBehaviorPatchBeforeGate
result: expected FAIL
generated states before violation: 3
distinct states before violation: 3
search depth before violation: 2

config: NicHypertagReadinessGateUnsafeProbeAsAuthority.cfg
target invariant: NoProbeAsAuthority
result: expected FAIL
generated states before violation: 5
distinct states before violation: 5
search depth before violation: 4

config: NicHypertagReadinessGateUnsafeStubEnforces.cfg
target invariant: NoStubEnforces
result: expected FAIL
generated states before violation: 6
distinct states before violation: 6
search depth before violation: 5

config: NicHypertagReadinessGateUnsafeMissingCoverage.cfg
target invariant: NoMissingReceiptCoverage
result: expected FAIL
generated states before violation: 4
distinct states before violation: 4
search depth before violation: 3

config: NicHypertagReadinessGateUnsafeRawEndpointStub.cfg
target invariant: NoRawEndpointStub
result: expected FAIL
generated states before violation: 6
distinct states before violation: 6
search depth before violation: 5

config: NicHypertagReadinessGateUnsafeProtectionClaim.cfg
target invariant: NoProtectionClaim
result: expected FAIL
generated states before violation: 4
distinct states before violation: 4
search depth before violation: 3
```

## Validated Claims

This validation supports these local readiness constraints:

```text
1. Behavior-changing implementation approval is not allowed before receipt and
   carrier inventory, observation probe mapping, inert stub rules, model gate,
   and assurance linkage are complete.

2. Observation probes must remain observation-only and cannot become authority.

3. Stubs must be inert and cannot change driver, queue, DMA, IRQ, mailbox,
   devlink, VFIO, iommufd, scheduler, or user-visible behavior.

4. Missing receipt/carrier coverage blocks the gate.

5. Stubs must not expose raw PF/VF/IOMMU/MSI/devlink/lower_dev authority to
   target Domains.

6. Readiness evidence must not be described as monitor-backed protection.
```

## Unsafe Counterexample Meaning

`NicHypertagReadinessGateUnsafeBehaviorBeforeGate.cfg` demonstrates a behavior
patch being approved before the gate is satisfied.

`NicHypertagReadinessGateUnsafeProbeAsAuthority.cfg` demonstrates an
observation probe being treated as authority.

`NicHypertagReadinessGateUnsafeStubEnforces.cfg` demonstrates an inert stub
silently changing behavior.

`NicHypertagReadinessGateUnsafeMissingCoverage.cfg` demonstrates gate passage
with missing receipt or carrier coverage.

`NicHypertagReadinessGateUnsafeRawEndpointStub.cfg` demonstrates a stub that
exposes raw endpoint authority.

`NicHypertagReadinessGateUnsafeProtectionClaim.cfg` demonstrates describing
readiness evidence as protection evidence.

## Evidence Limits

This validation does not prove:

```text
real HyperTag Monitor receipt minting
real Linux service/driver Domain isolation
real NIC driver enforcement
real IOMMU or IRQ route enforcement
real packet data-plane safety
real compatibility of a future Linux patch
real performance or cost-efficiency
```

Those remain future implementation, validation, and evaluation obligations.

## Design Consequence

The next safe action remains:

```text
observation-only probe/stub design or no-code trace runner
```

not:

```text
behavior-changing QueueLease enforcement
monitor-backed security claim
target Domain queue exposure
```
