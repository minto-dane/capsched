# Direct-Call Carrier Requirements Model

Status: Draft, intended for tiny finite TLC checking

Date: 2026-06-30

Related artifacts:

```text
analysis/0074-direct-call-carrier-requirements.md
analysis/direct-call-carrier-requirements-v1.json
validation/0073-direct-call-carrier-requirements-tlc.md
```

## Purpose

This model checks the N-101 direct-call carrier requirements gate for
`LocalMonitorAdmissionABI-v0`.

It focuses on:

```text
direct-call selection as reference carrier, not approval
bounded monitor copy before validation
canonical request image before decision
shared replay consume before ledger or success
same-nonce different-digest rejection
response handle backed by monitor ledger state
shared shadow generation
Linux timeout as transport observation, not monitor terminality
transport observations as non-authority
control/revoke priority without replay, budget, or epoch bypass
carrier sequence numbers as non-replay authority
future ring compatibility through carrier-neutral namespaces
```

## Scope Limit

This is not a binary ABI layout, C struct definition, endianness decision,
syscall/VM-call/SMC/HVC mechanism, Linux stub, monitor implementation,
performance benchmark, liveness proof, or production protection model.
