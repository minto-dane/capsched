# 0327 — Candidate-4 Rust child-transition refinement validation

## Result

The bounded child-transition refinement checkpoint passes locally.  Python
remains normative, Rust remains non-authoritative, G6 is open with retry
disabled, and G7 remains blocked by `NO_COMPLETE_G6_CAPTURE`.

## Passing checks

- `cargo test --release --locked`: six unit checks, including NIST SHA-256,
  setup cardinality, bounded-stat equivalence, and a forced digest collision
  resolved by full canonical equality;
- `test_setup_differential.py`: both 57-state/58-edge setup closures match
  byte-for-byte and four repeated Rust outputs per role are deterministic;
- `test_bounded_differential.py`: both 1,000-source prefixes match complete
  canonical state and edge bytes at 6,410 states and 12,212 edges;
- `test_trace_differential.py`: 17 traces, all 56 declared actions, every
  intermediate state and outgoing edge, and two Rust runs per trace match;
- `test_bounded_stats_differential.py`: both 10,000-source diagnostics match at
  52,764 states, 118,552 edges, and every action multiplicity;
- `test_build_reproducibility.py`: zero dependencies and byte-identical
  461,048-byte binaries from two source roots; and
- `validate-f0-c4-rust-child-refinement.py` plus
  `test-f0-c4-rust-child-refinement-mutations.py`: exact input binding and 14
  fail-closed policy mutations.

The 10,000-source Rust diagnostic used 107,380 KiB peak RSS after immutable
shared histories and the compact collision-chain index, versus 1,271,768 KiB
for the rejected naive representation.  The recorded timing is diagnostic
only; no production performance claim follows.

## Mechanical nonclaims

The machine checkpoint requires all seven remaining subgates to stay open:
independent Rust well-formedness/evidence checks, all 295 child hostile cases,
exhaustive child reachability and commutation, deterministic multiworker
external memory, parent/orchestrator refinement, result/capture integration,
and clean authority-disjoint installation.  It rejects G6 eligibility, Rust
model authority, claim credit, and Linux/Monitor hot-path credit.
