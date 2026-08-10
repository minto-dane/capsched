# Dynamic Residency R10 Machine-IR Tooling Hostile Audit

## Status

R10 remains a draft. This audit rejects machine-IR readiness, architecture freeze, TLA+ translation, and model-supported claims.

The review was read-only but not snapshot-exact: `r10-source.json` changed while it was being inspected. It is therefore valid negative evidence, but it can never authorize a successor snapshot.

The lossless machine-readable finding and disposition ledger is
`dynamic-residency-r10-machine-ir-tooling-hostile-audit-v1.json`.

## Essential Result

The reviewer constructed 18 hostile in-memory variants that the then-current materializer accepted. The failures were not cosmetic. They allowed counterfeit status promotion, hidden cross-shard authority reads, aliased transaction recovery, temporal operators in action guards, concrete double writes, untyped recovery, invented proof coverage, and torn lock bundles.

Fourteen normalized findings are retained as `R10-TOOL-001` through `R10-TOOL-014`. Current repair work has closed only bounded structural portions. Variant safety, executable witness/mutation semantics, source-derived imports, instance-universe completeness, allocator construction, provider fault partitions, rank obligations, and external promotion evidence remain open.

## Fixed Architectural Rules

1. The normative source cannot promote itself. Until an external content-addressed review manifest exists, the schema accepts only `draft`.
2. Function calls contribute their transitive read footprint, and the function graph must be acyclic.
3. Transaction identity is unique in `TxnID`, `OutcomeID`, and `TombstoneID`; physical slot reuse is keyed by an explicit expected slot generation.
4. Init, metadata, state, action, location, and temporal AST contexts are distinct.
5. Concrete writes are unique after parameter substitution; the linearization location must be exactly one written location.
6. Every read and write participates in consistency-domain and shard closure. A source Boolean cannot exempt a read.
7. Every invariant names every action template it claims to preserve, and proof claims resolve to declared claims.
8. Input hashes are computed from the bytes actually validated. Generated artifacts are fsynced and the lock manifest is published last.

## Nonclaims

Passing the current materializer means only that the bounded draft satisfies the checks implemented at that exact materializer digest. It does not establish safety, liveness, refinement, complete action coverage, Linux compatibility, monitor isolation, multi-cluster correctness, or performance.

The next valid readiness decision requires executable hostile mutations for every repaired rule and a fresh exact review of one immutable bundle.
