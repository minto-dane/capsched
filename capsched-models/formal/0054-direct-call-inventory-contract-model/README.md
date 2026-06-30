# Direct-Call Inventory Contract Model

Status: Draft, intended for tiny finite TLC checking

Date: 2026-06-30

Related artifacts:

```text
analysis/0077-direct-call-trace-source-inventory-contract.md
analysis/direct-call-trace-source-inventory-contract-v1.json
validation/0076-direct-call-inventory-contract-tlc.md
```

## Purpose

This model checks the N-104 no-code direct-call trace/source inventory contract.
It requires source-only inventory mode, complete output fields, required safety
flags, missing future anchors recorded as gaps, current source anchors treated
as observations only, and tracefs entries treated as future-plan suggestions
only.

It rejects inventory states that modify Linux, require root for source-only
mode, write tracefs, create public tracepoint ABI, attach probes, hide missing
anchors as unnecessary obligations, treat source or trace observations as
authority, claim runtime observation, expose raw handles, claim monitor
verification, claim production protection, or change behavior.

## Scope Limit

This is not a runner implementation, Linux patch, tracefs execution, QEMU run,
monitor implementation, binary ABI, public tracepoint ABI, user ABI,
performance benchmark, liveness model, or production protection proof.
