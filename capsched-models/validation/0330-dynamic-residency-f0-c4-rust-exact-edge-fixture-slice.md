# 0330 — Candidate-4 Rust exact-edge fixture validation

## Result

The first exact before/action/actor/after differential slice passes.  The
checkpoint conservatively maps 71 of 295 original child-regression credits,
leaves 224 open, and keeps all six remaining Rust-refinement subgates open.

## Passing evidence

- `test_hostile_wf_differential.py`: 81 exact queries (10 grant, 49 state,
  22 edge) produce byte-identical Python/Rust result streams across two Rust
  runs; 12 hostile edges are mapped credits and 10 positive edges are
  supplemental;
- every decoded grant and 54-field state round-trips to the exact input bytes;
- fixture SHA-256 is
  `ef51241904b19bd01214222c331a41b46db14df2d06a9440b2551290b7c870e6`
  and result SHA-256 is
  `1aefbfbbfaf392feca95202025d3deb5e525e4e684b895175a0bde57e872f387`;
- 15 malformed fixture transports fail closed;
- the unchanged normative Python hostile regression passes exactly 295 cases;
- `cargo test --release --locked --offline`: 10 tests pass;
- setup closure, 1,000-source exact graph, 17 all-action traces, 1,000-source
  independent WF, and 10,000-source cardinality/action multiplicity reruns
  retain their prior exact counts and hashes;
- the structural checkpoint validator binds 19 engine inputs and keeps six
  gates open; 23 checkpoint mutations fail closed; and
- two distinct source roots reproduce the same zero-dependency 592,120-byte
  binary with SHA-256
  `3d6fabd4683017ae7480209ec6df6e548f3dc83dc31c10746dcfb3190970c309`.

## Nonclaims

This does not establish complete 295-case parity, exhaustive reachability or
commutation, deterministic multiworker/external-memory behavior,
parent/orchestrator refinement, result/capture integration, or a clean
authority-disjoint installation.  Python remains normative, Rust has no claim
authority, G6 retry remains false, G7 remains blocked, and no external or
production claim follows.
