# 0239 — Candidate-4 Rust hostile-WF fixture slice

## Disposition

The first hostile-case refinement slice maps 59 of the normative Python child
regression's 295 credited cases onto a common exact-value transport.  Python
and Rust independently evaluate the same grant or complete child-state bytes.
All 59 results match byte-for-byte.  This is useful progress, but it does not
close `full_295_child_hostile_fixture_parity`: 236 original credits remain,
principally action/effect rejection, positive transition facts, commutation,
and representation boundaries.  G6 retry therefore remains false and G7
remains blocked.

## Exact transport boundary

Each named fixture contains either a complete `RunGrant` or all 54 fields of an
`EnvelopeState`, including the ordered receipt chain, recovery receipts,
evidence root, and decision receipt.  Values use the existing typed,
length-framed, hash-independent canonical encoding.  Expected booleans are not
carried in the fixture stream: the Python oracle and the handwritten Rust
`grant_wf`, `evidence_wf`, and `instance_wf` predicates calculate them
independently.

The Rust decoder has no third-party dependencies and rejects:

- noncanonical tags, integers, frame lengths, hex, or case identifiers;
- duplicate identifiers, declared/actual count mismatch, CRLF, missing final
  newline, truncated frames, and extra fields;
- oversized files, case sets, tuples, nesting, or enum-like atoms; and
- exact-state field-count or type mismatch.

The fixture file is opened once and read through that descriptor with a fixed
upper bound.  Fixture-only enum atoms have process lifetime, but their total
source bytes are bounded and this path is not used by BFS enumeration.  The
compact shared-receipt representation and production model hot path are
unchanged.

## Mapped cases

The slice contains 10 grant cases and 49 full-state cases.  It includes all
existing child-regression `assert_not_wf` scenarios: forged and mismatched
grants or receipts, duplicate and future receipts, lifecycle rollback,
candidate/digest mismatch, reordered drain and completion evidence, resource
and arbitration inconsistency, hostile-attempt/fault stickiness, failover
prefix and controller fencing, and sealed/decision corruption.  One positive
state-WF case deliberately preserves the original distinction between a state
that is internally well formed and an edge that must still be rejected by its
write/effect policy.

The fixture stream SHA-256 is
`e6b974694d79f210bce7d9d79f598433951b708b377f696ea24d2babdf7edc21`;
the exact result stream SHA-256 is
`5d8155140245051b6e1d0308d910dbfe1e321490d253530aeefe20600bef7c90`.
Two Rust evaluations are identical, and 11 malformed transport cases fail
closed.  The original Python regression still passes exactly 295 credits.

## Reproducibility and authority

Two distinct source roots produce the same zero-dependency 592,120-byte
release binary with SHA-256
`2fd58730d3bf2884eb436177fc996f4b857d44307427051ca052e22ad8bfbe36`.
Python remains the sole normative executable model.  The Rust result is an
implementation-refinement check only; it grants no F0, R11, K0/G0, G6/G7,
Linux/Monitor, protection, performance, cost, cluster, or deployment credit.

## Next refinement order

1. Extend the neutral fixture query types to before/after edge semantics and
   protocol rejection, covering the original mutation test's effect-policy
   cases without embedding Python verdicts.
2. Map positive state/action-set and terminal-certificate assertions.
3. Add exact and order-distinct commutation queries plus behavioral/outcome
   representation relations.
4. Require all 295 named mappings before closing the hostile parity subgate,
   then proceed to exhaustive child reachability and commutation.
