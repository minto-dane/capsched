# ADR-0014: Separate Finite and Dynamic Residency Claims

Status: Accepted

Date: 2026-08-09

## Context

Analysis 0188 and Formal 0148 establish a useful residency lower bound, but
their executable scope is deliberately finite. Every modeled Domain is already
Monitor-admitted in the initial state, and the admission scenario issues one
residency request per guaranteed Domain.

Plan 0006 requires more:

```text
dynamic Domain join, leave, admission, rejection, and class change
recurring request identity, cancellation, and coalescing
bounded work under best-effort churn and overflow
generation saturation, quarantine, and safe rekey
```

Treating the finite result as closure of those transitions would turn a sound
small model into an overclaim.

## Decision

Keep `RESIDENCY-001` as the exact finite, fixed pre-admitted, one-shot reference
claim validated by Evidence Capsule v1 and Validation 0289.

Create `RESIDENCY-DYN-001` as a separate mandatory claim for dynamic admission
and recurring residency service. It remains Open and is the immediate next
semantic model before `ENTRY-001 + CODE-001`.

The finite result is gap/refinement evidence for `RESIDENCY-DYN-001`; it is not
supporting evidence for that broader claim. A future positive transition needs
its own frozen contract, negative cases, claim-specific Validator, capsule, and
approval decision.

Do not rename or reinterpret the accepted capsule, decision id, claim target,
or historical model. The existing `RESIDENCY-001` wording is narrowed only to
state the scope the contract already encoded.

## Consequences

- Plan 0006 cannot complete until both residency claims close.
- The next model must preserve every finite-reference invariant while adding
  the dynamic transitions.
- Production directory or replacement choices still wait for semantic
  requirements; the dynamic model need not prematurely choose a data structure.
- Linux behavior-changing work remains paused.
- `ENTRY-001 + CODE-001` moves one step later rather than inheriting an
  unmodeled residency assumption.

## Non-Claims

This decision does not invalidate Validation 0289, prove a dynamic residency
algorithm, select a production cache or rekey mechanism, change Linux, or
support implementation, protection, performance, cost, cluster, or deployment
claims.
