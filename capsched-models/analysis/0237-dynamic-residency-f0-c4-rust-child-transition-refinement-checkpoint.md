# 0237 — Candidate-4 Rust child-transition refinement checkpoint

## Disposition

The first Rust refinement checkpoint implements the complete Candidate-4 child
transition function while retaining
`validation/f0_supervisor_lts_v3.py` as the sole normative executable model.
Rust has no model, decision, claim, or capture authority.  G6 retry remains
disabled because exhaustive child reachability/commutation, the complete 295
hostile-case mapping, independent well-formedness checks, deterministic
multiworker external-memory enumeration, parent/orchestrator refinement, result
integration, and clean authority-disjoint installation remain open.

This checkpoint is nevertheless materially stronger than a setup prototype.
It covers setup, stream framing, hostile activity, failover, revocation,
resource arbitration, exit, descendant and asynchronous drain, protection
closure, final counters, evidence sealing, and local decision.

## Exact refinement evidence

The comparison wire format is typed, length-framed, and independent of Python
object hashes.  The behavioral state bytes retain every operational field,
the sorted receipt semantic multiset with multiplicity and issuer/channel, and
decision and recovery semantics.  Rust emits the same action ID, actor, target
state, and outgoing-edge multiset as Python.

The following locally pass:

- complete setup closure for both roles: 57 states and 58 edges, with canonical
  SHA-256 `62e4e05e...1069ffca` for PRODUCER and
  `6bb8f88c...c01ce69f` for CHECKER;
- byte-exact BFS prefixes through 1,000 expanded representatives per role:
  6,410 states and 12,212 edges, with canonical SHA-256
  `aa8e94a9...e6d3e7` and `ac92d54c...95e9d3`;
- 17 witness traces whose every intermediate state and complete outgoing edge
  set match byte-for-byte, observe all 56 declared child actions, and reproduce
  identically across two Rust runs per trace;
- a wider 10,000-source compact diagnostic with 52,764 states, 118,552 edges,
  and exact action multiplicities for both roles; and
- 14 fail-closed checkpoint mutations covering authority, source/hash drift,
  dependency injection, collision weakening, coverage/count inflation, hidden
  open gates, and G6/Rust-authority overclaims.

The exact Python child source remains
`033170ef47e877890dfbb9f31f7bc32e0a3a0e0d0277499f81582d2f69c07888`.
All Rust and oracle inputs are individually digest-bound by
`f0-c4-rust-child-transition-refinement-checkpoint-v1.json`.

## Memory and collision boundary

The rejected naive Rust representation cloned each complete receipt vector and
retained every canonical state byte as a hash-table key.  At 10,000 expanded
sources it peaked at 1,271,768 KiB.  Immutable shared receipt nodes plus a
compact digest-head/collision-link index reduce the measured peak to 107,380
KiB while preserving the same graph statistics.

No SHA-256 match is accepted as identity.  On every match Rust reconstructs and
compares the complete canonical behavioral bytes.  A forced identical-digest
unit case requires two unequal states to occupy distinct collision-chain
entries and a later equal state to resolve to its original representative.
This costs throughput but preserves the full-equality gate.

## Reproducible tool boundary

The crate has zero third-party dependencies.  Debian/Ubuntu Rust 1.75.0 and
Cargo 1.75.0 build byte-identical stripped release binaries from two distinct
private source roots.  The current binary is 461,048 bytes with SHA-256
`d8065e5a3fa8a359e379fa2161ae1d08e866ab95a0d1992031fe0cdc0604c2e4`.
Tool executable hashes are recorded, but this is not yet an immutable capture
toolchain installation.

## Next refinement order

1. Port and independently check child `InstanceWF`, evidence, authority, and
   write-set predicates; map all 295 Python hostile cases to differential
   outcomes.
2. Add deterministic layer/batch partitioning and an exact disk-backed graph
   store, then require equality across one and multiple worker counts.
3. Complete exhaustive child reachability, coaccessibility, declared
   commutation, and result-schema production without changing Python results.
4. Port the parent/orchestrator relation and its 739 hostile cases, then bind
   child and parent results through the existing runner contract.
5. Only after a clean reviewed immutable installation may readiness be
   reconsidered and a fresh authority-disjoint G6 campaign be launched.

This work is offline validation only.  It changes no Linux scheduler or Domain
Monitor production path and grants no F0, R11, K0/G0, protection, performance,
cost, cluster, or deployment claim.
