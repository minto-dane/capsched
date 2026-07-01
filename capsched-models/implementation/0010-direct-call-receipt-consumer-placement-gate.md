# Implementation 0010: Direct-Call Receipt Consumer Placement Gate

Status: proposed implementation-facing gate, no Linux patch approved yet

Date: 2026-06-30

Related artifacts:

```text
analysis/0080-direct-call-receipt-consumer-source-map.md
analysis/direct-call-receipt-consumer-source-map-v1.json
formal/0057-direct-call-receipt-consumer-placement-model/
validation/0089-direct-call-receipt-consumer-placement-tlc.md
implementation/direct-call-receipt-consumer-placement-gate-v1.json
```

## Purpose

This gate translates the N-118 placement model into preconditions for any
future Linux direct-call carrier patch.

Passing this gate means:

```text
The patch proposal has separated hot-path bounded checks, policy/lifecycle
request shaping, generic async exclusion, future gaps, revoke invalidation, and
evidence classes before code changes.
```

It does not mean:

```text
direct-call stubs exist
ABI is approved
tracepoints are approved
monitor verification occurred
production protection exists
```

## Gate Rows

### DCPGATE-001: Receipt Provenance Root

Required:

```text
Linux may carry opaque receipt ids or derived shadows.
Linux may not mint request, schema, entry, response, or revoke receipts.
Linux shadow state is cache only.
```

Forbidden fallback:

```text
opaque Linux type, pointer, return code, or cached shadow as receipt authority
```

### DCPGATE-002: Hot-Path Bounded Consumption

Required:

```text
scheduler hot-path candidates may only do bounded generation/epoch-style checks
against already frozen monitor-owned shadow state.
```

Forbidden fallback:

```text
enqueue, wake, pick, schedule, or context-switch path performs direct monitor
calls, copies requests, negotiates schema, or mints receipt authority
```

### DCPGATE-003: Policy and Lifecycle Separation

Required:

```text
sched syscalls, fork, exec, and exit may shape requests, preserve identity, and
invalidate stale state, but remain policy/lifecycle surfaces.
```

Forbidden fallback:

```text
Linux policy success, clone inheritance, exec credential transition, or exit
cleanup as schema acceptance, receipt renewal, or revoke completion
```

### DCPGATE-004: Generic Async Exclusion

Required:

```text
generic workqueue and io_uring worker surfaces remain excluded as direct
receipt consumers unless a typed Domain-originated async carrier has been
separately modeled.
```

Forbidden fallback:

```text
work_struct pending state, worker task identity, or io-wq worker loop as caller
receipt provenance
```

### DCPGATE-005: Future Gap Preservation

Required:

```text
DCRCV-021 through DCRCV-027 remain gap/plan rows until their own patch gates
exist.
```

Forbidden fallback:

```text
future gap row treated as implemented helper, ABI, tracepoint, or monitor proof
```

### DCPGATE-006: Revoke and Shadow Invalidation

Required:

```text
no stale Linux shadow or in-flight response can be consumed after monitor revoke
invalidation.
```

Forbidden fallback:

```text
timeout, retry, local cleanup, or cached status as renewed response or revoke
completion
```

### DCPGATE-007: Evidence Class Split

Required:

```text
source-only, compile-only, trace-only, TLC/model, monitor-backed runtime, and
production protection evidence are separate classes.
```

Forbidden fallback:

```text
source-map ok rows, trace plans, TLC passes, or inert stubs as runtime coverage,
monitor verification, ABI approval, behavior approval, or production protection
```

## Required Evidence Before Patch

Before any direct-call carrier patch:

```text
1. Gate rows DCPGATE-001 through DCPGATE-007 must be satisfied or explicitly
   carried as blockers.
2. Every Linux source anchor must have symbol/pattern drift tracking or be an
   explicit future gap.
3. Hot-path checks must have a bounded-operation statement.
4. Policy/lifecycle paths must list exactly which request fields they shape and
   which receipt fields they cannot decide.
5. Async paths must either remain excluded or reference a separate typed-carrier
   model.
6. Revoke ordering must cover stale shadow, in-flight response, timeout, retry,
   and re-entry.
7. Non-claims for ABI, tracepoints, runtime coverage, monitor verification,
   behavior change, and production protection must remain explicit.
```

## Exit Rule

This gate can only permit a future candidate patch proposal. It cannot approve
a patch by itself.

