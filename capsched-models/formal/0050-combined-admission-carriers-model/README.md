# Combined Admission Carriers Model

Status: Draft, intended for tiny finite TLC checking

Date: 2026-06-30

Related artifacts:

```text
analysis/0073-combined-admission-carriers-plan.md
analysis/combined-admission-carriers-plan-v1.json
validation/0072-combined-admission-carriers-tlc.md
```

## Purpose

This model checks the N-100 combined direct-call plus monitor-owned-ring carrier
plan for `LocalMonitorAdmissionABI-v0`.

It focuses on:

```text
canonical monitor-owned admission attempts
shared replay namespace across direct and ring carriers
shared receipt ledger across both carriers
shared shadow generation
carrier fallback without duplicate success
ring full/drop accounting before monitor claim
revoke ordering across both carriers
epoch consistency across carrier-visible request state and ledger state
```

## Scope Limit

This is not a binary ABI layout, direct-call trap mechanism, ring memory layout,
doorbell mechanism, Linux stub, monitor implementation, performance benchmark,
cluster-scale liveness proof, or production protection model.

The model is deliberately small. It checks semantic failure classes that would
make a later high-throughput carrier weaker than the direct-call reference
semantics.
