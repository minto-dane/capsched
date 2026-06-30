# Modern NIC HyperTag Readiness Gate Model

Status: Draft, intended for tiny finite TLC checking

Date: 2026-06-30

Related artifacts:

```text
analysis/0062-modern-nic-hypertag-readiness-probe-map.md
implementation/0007-modern-nic-hypertag-readiness-gate.md
validation/0061-modern-nic-readiness-gate-tlc.md
```

## Purpose

This model checks the N-089 implementation-readiness gate. It ensures that
behavior-changing modern NIC HyperTag work cannot be approved before:

```text
receipt/carrier inventory is complete
observation probes are mapped
probes are explicitly observation-only
probe rows do not claim authority
stubs are inert
stubs do not expose raw endpoints
receipt coverage is complete
the model gate passed
the assurance case was linked
```

It also rejects the claim that probes or stubs provide protection.

## Checked Invariants

```text
NoBehaviorPatchBeforeGate
NoProbeAsAuthority
NoStubEnforces
NoMissingReceiptCoverage
NoRawEndpointStub
NoProtectionClaim
NoBadBehaviorBeforeGate
NoBadProbeAsAuthority
NoBadStubEnforces
NoBadMissingCoverage
NoBadRawEndpointStub
NoBadProtectionClaim
```

## Unsafe Configurations

```text
NicHypertagReadinessGateUnsafeBehaviorBeforeGate.cfg
NicHypertagReadinessGateUnsafeProbeAsAuthority.cfg
NicHypertagReadinessGateUnsafeStubEnforces.cfg
NicHypertagReadinessGateUnsafeMissingCoverage.cfg
NicHypertagReadinessGateUnsafeRawEndpointStub.cfg
NicHypertagReadinessGateUnsafeProtectionClaim.cfg
```

## Scope Limit

This model is not a NIC, IOMMU, IRQ, service Domain, or HyperTag Monitor
implementation. It is a pre-implementation design filter.

Passing this model means that a future observation-only probe/stub proposal is
better scoped. It does not mean the system provides device isolation or
hypervisor-grade protection.
