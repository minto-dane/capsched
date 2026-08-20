# 0328 — Candidate-4 Rust independent well-formedness validation

## Result

The independent Rust child well-formedness subgate passes locally.  Python
remains normative, Rust remains non-authoritative, six refinement subgates
remain open, G6 retry remains false, and G7 remains blocked.

## Passing checks

- `cargo test --release --locked --offline`: eight unit tests pass, including
  250-source reachable-state WF checks for both roles and focused forged-state
  rejection cases, including constant-memory rejection of maximum-width
  corrupt sequence counters;
- `test_wf_differential.py --source-limit 1000`: both roles match Python at
  6,410 retained states, 12,212 edges, and 12,213 WF evaluations, with two
  deterministic Rust runs per role;
- `test_trace_differential.py`: all 17 traces and 56 declared actions remain
  byte-exact while the Rust emitter independently validates every intermediate
  and outgoing state;
- the setup and 1,000-source transition differentials remain byte-exact, so the
  WF integration did not change child semantics;
- `test_build_reproducibility.py`: two distinct source roots produce the same
  zero-dependency 526,584-byte binary with SHA-256
  `d1b6c96c209573893cab7fcffd1f166dafd6dbf615af310683056317206e8123`;
  and
- the structural checkpoint validator and 16 fail-closed checkpoint mutations
  bind the new source, result, build, closed-subgate, and remaining-open-gate
  facts.

## Mechanical nonclaims

The checkpoint keeps the complete 295-case child hostile parity, exhaustive
child reachability/commutation, deterministic multiworker external memory,
parent/orchestrator refinement, result/capture integration, and clean
authority-disjoint installation open.  No G6/G7, F0, R11, K0/G0, protection,
production performance, cost, Linux/Monitor implementation, cluster, or
deployment credit follows.
