# Direct Call Reference ABI Model

Status: Draft, intended for tiny finite TLC checking

Date: 2026-06-30

Related artifacts:

```text
analysis/0071-direct-call-reference-abi-sketch.md
analysis/direct-call-reference-abi-sketch-v1.json
validation/0070-direct-call-reference-abi-tlc.md
```

## Purpose

This model checks the N-098 direct-call reference ABI sketch for
`LocalMonitorAdmissionABI-v0`.

It focuses on:

```text
monitor entry before success
monitor copy/freeze before validation
replay consume before success ledger write
monitor-owned ledger writes
response handle after ledger write
Linux shadow refresh from handle/ledger only
failure terminality for the same attempt
revoke slow path with in-flight direct call drain
derived receipt revoke and shadow invalidation before revoke complete
```

## Scope Limit

This is not a binary ABI, syscall/VM-call layout, register convention, shared
memory layout, Linux stub, monitor implementation, benchmark, or production
protection model.
