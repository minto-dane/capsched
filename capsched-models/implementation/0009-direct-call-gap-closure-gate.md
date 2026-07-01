# Implementation 0009: Direct-Call Gap Closure Gate

Status: proposed implementation-facing gate, no Linux patch approved yet

Date: 2026-06-30

Related artifacts:

```text
analysis/0078-direct-call-gap-closure-design.md
formal/0055-direct-call-gap-closure-model/
validation/0086-direct-call-gap-closure-tlc.md
implementation/direct-call-gap-closure-gate-v1.json
```

## Purpose

This gate translates the N-114 `DirectCallGapClosure` model into preconditions
for any future direct-call Linux/monitor patch.

Passing this gate means:

```text
The direct-call implementation proposal has named every required Linux-facing
surface, every monitor-owned receipt/epoch/replay responsibility, and every
forbidden fallback before code changes.
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

### DCGATE-004: Request Envelope

Required:

```text
Linux-facing surface:
  internal envelope builder candidate only

Monitor-owned semantics:
  canonical request image
  bounded copy source
  request digest
  replay key / nonce
  caller Domain epoch

Forbidden fallback:
  Linux-built envelope as canonical monitor authority
```

### DCGATE-005: Direct-Call Entry

Required:

```text
Linux-facing surface:
  arch-independent wrapper candidate
  arch backend candidate

Monitor-owned semantics:
  entry/exit register contract
  memory clobber contract
  terminal failure ordering
  replay consume before success

Forbidden fallback:
  wrapper return code as monitor approval
```

### DCGATE-006: Schema Negotiation

Required:

```text
Linux-facing surface:
  internal schema query/cache candidate

Monitor-owned semantics:
  accepted schema version
  required feature set
  critical field handling
  downgrade rejection

Forbidden fallback:
  Linux-visible schema support as acceptance authority
```

### DCGATE-007: Response Shadow

Required:

```text
Linux-facing surface:
  response-handle shadow/cache candidate

Monitor-owned semantics:
  monitor-minted response handle
  response handle generation
  Domain epoch
  timeout meaning
  revoke invalidation ordering

Forbidden fallback:
  timeout, retry, or cached shadow refresh as renewed authority
```

### DCGATE-008: Control Revoke Lane

Required:

```text
Linux-facing surface:
  internal control/revoke lane candidate

Monitor-owned semantics:
  control priority bound
  replay budget interaction
  Domain epoch check
  revoke completion receipt
  no new response during revoke

Forbidden fallback:
  control priority bypassing replay, budget, or epoch
```

## Side Gates

Test-only failure injection:

```text
May exist only behind test/KUnit-style configuration.
Must not change live monitor or Linux decisions.
Must not become a production control path.
```

Trace-only observation:

```text
May use existing tracepoints or dynamic probes only under a separate runbook.
Must not imply runtime coverage until executed.
Must not create public tracepoint ABI without a separate gate.
```

## Required Evidence Before Patch

Before any direct-call stub or behavior-changing patch:

```text
1. Machine-readable gate row for each DCGATE item.
2. Source-map anchors for proposed Linux-facing surfaces, or explicit future
   gap rows if still absent.
3. Monitor responsibility statement for every receipt, epoch, replay, schema,
   response, and revoke field.
4. Failure-mode table covering terminal reject, retry, timeout, revoke, stale
   response, schema mismatch, and replay collision.
5. Validation plan that separates source-only, compile-only, trace-only, and
   monitor-backed evidence.
6. Explicit non-claims for ABI, runtime coverage, monitor verification, and
   production protection.
```

## Exit Rule

This gate can only permit the design of a candidate patch series. It cannot
itself approve a patch.

A future patch gate must still answer:

```text
Does this patch change behavior?
Does it expose ABI?
Does it rely on Linux mutable state as authority?
Does the monitor mint every receipt being consumed?
Can stale response/shadow/replay state survive revoke?
Can trace/test-only paths affect production decisions?
```
