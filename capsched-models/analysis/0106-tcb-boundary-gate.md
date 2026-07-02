# Analysis 0106: TCB Boundary Gate

Status: Draft model gate with TLC-backed design filter; no implementation or
production TCB measurement approved

Date: 2026-07-01

## Purpose

N-152 closes the model-only blocker for `TCB-001` by defining what may belong
to the production trusted computing base.

The goal is not to claim a measured line count. The goal is to prevent the
architecture from quietly moving Linux drivers, parsers, policy engines, or
mutable Linux state into the protection root.

## Required Boundary

HyperTag Monitor:

```text
owns non-forgeable roots only:
  Domain registry
  epochs
  sealed RunToken / root budget / MemoryView roots
  page ownership
  IOMMU and queue ownership roots

exposes typed/sealed interfaces only:
  activation
  root budget expiry/receipt
  MemoryView/page ownership transition
  IOMMU/IRQ/QueueLease transition
  revoke completion receipt

excludes:
  device drivers
  filesystem/network/protocol parsers
  policy engines
  Linux scheduler policy
  cgroup/namespace/LSM policy logic
  Linux mutable metadata as a trust root
```

Service Domains:

```text
enter through typed endpoints
hold least authority for the requested service
intersect service authority with caller frozen authority
do not expose raw monitor, PF/VF, IOMMU, MSI/MSI-X, devlink, netdev, or ring
  handles as authority
do not become ambient deputies for caller or target Domains
```

Comparison envelope:

```text
declare a TCB budget
compare monitor interfaces, parser exposure, driver exposure, service endpoints,
  privileged code volume, and reachable attack surface against KVM/VMM-style
  baselines
```

## Model

New model:

```text
formal/0084-tcb-boundary-gate-model/
```

Checked invariant group:

```text
Safety
```

with component obligations:

```text
NoModelSupportWithoutMonitorScope
NoModelSupportWithoutServiceScope
NoModelSupportWithoutMeasurementEnvelope
NoImplementationClaim
NoProductionProtectionClaim
NoCostEfficiencyClaim
```

## Rejected Designs

The model rejects:

```text
unbounded monitor core
untyped monitor interface
driver, parser, or policy engine inside the Monitor TCB
Linux mutable state as a trusted root
service Domain ambient authority
raw handle exposure across the boundary
missing TCB budget
missing VM/VMM comparison envelope
implementation claim from model evidence
production protection claim from model evidence
cost-efficiency claim from model evidence
```

## Assurance Effect

This gate moves `TCB-001` from open to model-supported. It does not make
`TOP-001` production-supported.

## Non-Claims

This gate does not provide monitor code, service-domain code, line counts,
interface counts, runtime coverage, exploit-containment evidence, monitor
verification, cost-efficiency evidence, or production protection.
