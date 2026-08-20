# 0238 — Candidate-4 Rust independent well-formedness refinement

## Disposition

The Rust child engine now independently implements the complete normative
`RunGrant`, receipt, ordered evidence-chain, recovery, decision, and
`InstanceWF` predicates.  The implementation is handwritten Rust in
`validation/f0-c4-rust-engine/src/model/wf.rs`; it does not invoke Python,
consume a generated truth table, or acquire model authority.  Python remains
the sole normative executable specification.

This closes the narrow
`rust_instance_wf_and_evidence_wf_independent_checks` subgate.  It does not
close the separate 295-case hostile-fixture gate, exhaustive reachability or
commutation, multiworker/external-memory determinism, parent/orchestrator
refinement, result integration, or clean authority-disjoint installation.
Consequently G6 retry remains disabled and G7 remains blocked.

## Independent predicate boundary

The Rust predicate checks:

- grant role, ordinal, nonce-derived child identity, scope/subject/budget
  binding, positive budget, issuer, nonempty policy roots, and abstract owner
  authentication;
- every receipt schema, run/binding/scope/subject identity, sequence,
  payload digest, authorized issuer/channel, previous hash, and authentication
  tag;
- setup and runtime causal order, active-controller handoff, singleton and
  repeatable receipt cardinality, generation/observation sequences, hostile
  attempt/rejection pairing, first-fault stickiness, and seal/root closure;
- recovery prefix/phase reconstruction and post-seal guardian takeover;
- decision receipt binding and expected local decision; and
- every operational phase, authority, population, stream, arbitration,
  resource, teardown, evidence, and local-decision invariant in Python
  `instance_wf`.

Receipt histories remain immutable shared nodes.  WF checks reconstruct their
chronological view explicitly; they do not reuse the order-erasing behavioral
receipt multiset.  This preserves the distinction between ordered audit
implementation validity and behavioral quotient identity.

## Differential evidence

For each of PRODUCER and CHECKER, the WF-prefix test expands the first 1,000
behavioral BFS representatives and evaluates the initial state plus every
successor candidate.  Each role produces 6,410 states, 12,212 edges, and
12,213 independent WF checks.  Python and Rust emit byte-identical compact
records with SHA-256:

- PRODUCER: `d0931cf52edbcd20a972d58992496a29bd6d064378cc9075bb9c18698a7707bf`;
- CHECKER: `6de6408a7aca02229687c8394f1d72f47ba7e95d15304e9c76e0500befea6903`.

The 17-trace all-action corpus also runs independent Rust WF over every
intermediate state and every outgoing successor.  It therefore covers the late
reclamation, seal, decision, quota, failure, failover, hostile-rejection, and
terminal-breach paths that the 1,000-source prefix has not necessarily reached.
All 56 declared child actions remain byte-exact against Python.

Eight Rust unit checks now include a bounded two-role reachable-state pass and
focused negative mutations for forged grants and receipts, duplicated receipts,
controller/phase rollback, receipt-free candidate and winner states, and
premature scope release.  Corrupt maximum-width event, drain-generation, and
visible-observation counters are rejected without constructing ranges sized by
those untrusted values.  These are focused implementation regressions; they
must not be represented as parity with the complete 295-case Python hostile
suite.

## Reproducibility and performance scope

The zero-dependency crate still builds byte-identically from two distinct
source roots.  With the independent predicates and WF command included, the
stripped binary is 526,584 bytes with SHA-256
`d1b6c96c209573893cab7fcffd1f166dafd6dbf615af310683056317206e8123`.
This is offline validation code.  It changes no Linux scheduler or Domain
Monitor production hot path and grants no production performance claim.

## Next refinement order

1. Turn the 295 Python child hostile cases into an exact, named cross-language
   fixture corpus covering invalid states, action rejection, commutation, and
   representation boundaries without hard-coding expected success.
2. Add deterministic worker partitioning and a crash-safe exact disk-backed
   graph store, then require identical results at one and multiple workers.
3. Close exhaustive child reachability, coaccessibility, and declared
   commutation before porting the parent/orchestrator relation.
4. Integrate the exact result schema and only then prepare a reviewed immutable
   authority-disjoint installation for a possible fresh G6 campaign.
