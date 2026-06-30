# Direct-Call Schema Compatibility Model

Status: Draft, intended for tiny finite TLC checking

Date: 2026-06-30

Related artifacts:

```text
analysis/0075-direct-call-schema-compatibility.md
analysis/direct-call-schema-compatibility-v1.json
validation/0074-direct-call-schema-compatibility-tlc.md
```

## Purpose

This model checks the N-102 direct-call semantic schema compatibility candidate
for `LocalMonitorAdmissionABI-v0`.

It focuses on:

```text
supported semantic schema negotiation
monitor and caller minimum schema checks
mandatory field and critical optional field fail-closed behavior
ignored noncritical optional fields as non-authority
required feature coverage
downgrade rejection for required safety features
compatible response, ledger, and error namespace requirements
shadow refresh only from supported response interpretation
unknown success code rejection
transport observation as non-authority
carrier-neutral schema namespace for future ring refinement
```

## Scope Limit

This is not numeric schema ids, binary field encoding, endianness, alignment,
C struct layout, TLV selection, fixed-header selection, syscall or monitor-call
mechanism, Linux stub, monitor implementation, performance benchmark, liveness
proof, or production protection model.
