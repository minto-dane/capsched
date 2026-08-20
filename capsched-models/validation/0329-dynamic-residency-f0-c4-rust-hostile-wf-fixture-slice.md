# 0329 — Candidate-4 Rust hostile-WF fixture validation

## Result

The first named hostile-WF fixture slice passes.  It maps 59 of 295 original
child-regression credits and deliberately leaves the complete hostile parity
subgate open with 236 credits remaining.

## Passing evidence

- `test_hostile_wf_differential.py`: 10 grant and 49 complete-state fixtures
  produce byte-identical Python/Rust results; fixture SHA-256 is
  `e6b974694d79f210bce7d9d79f598433951b708b377f696ea24d2babdf7edc21`
  and result SHA-256 is
  `5d8155140245051b6e1d0308d910dbfe1e321490d253530aeefe20600bef7c90`;
- two Rust evaluations are deterministic and 11 malformed fixture transports
  fail closed;
- `cargo test --release --locked --offline`: 10 unit tests pass, including
  canonical decoder rejection and the prior independent-WF checks;
- `test-f0-supervisor-lts-v3-mutations.py`: the unchanged normative Python
  child regression still reports exactly 295 cases; and
- `test_build_reproducibility.py`: two source roots produce the same
  zero-dependency 592,120-byte binary with SHA-256
  `2fd58730d3bf2884eb436177fc996f4b857d44307427051ca052e22ad8bfbe36`.

The structural checkpoint validator binds 19 engine inputs and keeps six
subgates open.  Its mutation suite rejects 19 policy and evidence drifts.

## Nonclaims

The 59 fixtures do not represent complete 295-case parity, exhaustive child
reachability or commutation, multiworker/external-memory determinism,
parent/orchestrator refinement, result/capture integration, or clean
authority-disjoint installation.  G6 retry remains false, G7 remains blocked,
and no external or production claim follows.
