# Dynamic Residency R10 Machine Semantics

Status: retained rejected R10 machine artifact; no semantic freeze, TLA+
authorization, or model support

Requirement: `RESIDENCY-DYN-001`

Predecessor: Analysis 0209 and Validation 0296 reject the exact R9 snapshot
`f7e9f3df695af3015681da99a48bffcc44fe916588da66230fff82be5b411362`.

## Artifact Boundary

This directory replaces prose-completion by a typed, reproducible semantic
source:

```text
r10-schema.json       strict syntax schema
r10-source.json       only hand-edited normative semantic source
materialize-r10.py    typed validator and deterministic expander
r10-expanded.json     generated concrete locations/actions/frames
r10-lock.json         generated transitive digest lock
r10-generated.md      generated human review projection
```

Generated files are not edited. A review pins `r10-lock.json` and the raw
digest of every listed input. The human projection cannot supply semantics
missing from `r10-source.json`.

## Fixed Rules

1. JSON duplicate keys, floats, implicit null, unknown fields, unbounded
   quantifiers, unknown identifiers, and unexpanded wildcards reject.
2. `semantic_actor` is provenance only. It is never write authority.
3. Local protected locations are written only by the exact node/shard
   transaction engine. CPU, time, quorum, and external inputs have separate
   typed writers.
4. One atomic action touches authority-relevant mutable locations in one
   consistency domain and one transaction shard only.
5. A transaction is `Vacant -> Prepared -> CommitIntent|AbortIntent ->
   Applying -> Complete`; recovery has exactly one successor per state.
6. A commit intent linearizes all authoritative writes. Applying may update
   only declared derived indices or audit projections.
7. Every dynamic immutable object occupies a predeclared object-store slot.
8. Publication and admission are consumable only after exact sealing.
9. Dispatch preparation cannot refer to a future root claim. Physical entry
   binding is constructed after the claim.
10. Provider-owned CPU state is one registered product containing context,
    owner, entry result, quantum, gates, clock epoch, and incarnation.
11. The source states claims and nonclaims separately. A bounded witness is
    not a generic proof, a Linux refinement, physical isolation evidence, or
    a performance result.

## Promotion Order

```text
schema/source closure
  -> deterministic materialization
  -> structural and conservation validation
  -> bounded positive witness
  -> negative mutations
  -> exact hostile review
  -> semantic freeze
  -> decomposed TLA+ translation
```

TLA+ remains unauthorized until the exact expanded artifact survives review.

## Final Disposition

Analysis 0210 through 0213 and Validation 0297 through 0301 show that the R10
tooling and typed representation are useful negative evidence but permit
candidate-controlled semantic self-certification and vacuous acceptance.
ADR-0016 rejects R10 and requires the policy-derived R11 successor. These bytes
remain immutable regression input; this directory is not an active foundation
and must not be repaired into acceptance in place.
