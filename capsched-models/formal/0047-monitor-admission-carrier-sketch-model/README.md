# Monitor Admission Carrier Sketch Model

Status: Draft, intended for tiny finite TLC checking

Date: 2026-06-30

Related artifacts:

```text
analysis/0070-local-monitor-admission-carrier-sketch-comparison.md
analysis/local-monitor-admission-carrier-sketch-comparison-v1.json
validation/0069-monitor-admission-carrier-sketch-tlc.md
```

## Purpose

This model checks the N-097 comparison between a direct-call-first reference
sketch and a monitor-owned-ring-first throughput-refinement sketch.

It focuses on:

```text
carrier choice not changing authority
direct response requiring monitor entry and replay check
ring response requiring monitor slot claim
ring slots not being authority
batch epoch stability
shadow refresh from monitor ledger only
pending ring response drain before revoke complete
performance cost not acting as security authority
```

## Scope Limit

This is not a binary ABI, shared-ring layout, syscall/VM-call choice, monitor
implementation, Linux stub, or performance benchmark.
