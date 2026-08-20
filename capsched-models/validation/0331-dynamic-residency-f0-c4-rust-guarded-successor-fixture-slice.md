# 0331 — Candidate-4 Rust guarded-successor fixture validation

## Result

The guarded successor action/actor-multiset differential passes.  The exact
hostile corpus now contains 108 queries and conservatively maps 98 of 295
original child-regression credits, leaving 197 and all six refinement gates
open.

## Passing evidence

- `test_hostile_wf_differential.py`: two Rust runs match Python byte-for-byte
  for 10 grant, 49 state, 22 edge, and 27 successor queries;
- the successor query distinguishes invalid-state rejection from valid empty
  terminal sets and preserves action/actor multiplicity;
- fixture SHA-256 is
  `5a9efc84e9c4ab10cfcf3a43dd0f67836e11c717de174a3e21a80848776f292c`
  and result SHA-256 is
  `d96367e3f2ae5e16cc7d65d52a4bf36ae40226abf8f5eaeb1500870e7e98cf89`;
- 18 malformed transport cases fail closed;
- the normative Python regression remains exactly 295 cases and 10 release
  Rust unit tests pass; and
- two distinct source roots reproduce one zero-dependency 592,120-byte binary
  with SHA-256
  `6c1719155bb2321057a3dd0b28a6d5210e3b3b7ad545e56ea232905e386d4aaf`.

The structural validator binds 19 engine inputs and keeps six gates open; 24
checkpoint mutations fail closed.  Setup, 1,000-source exact BFS, 17 traces
covering all 56 actions, 1,000-source independent WF, and 10,000-source
multiplicity retain their prior exact counts and hashes.

## Nonclaims

The successor slice is not full hostile parity, exhaustive child closure,
commutation/projection equivalence, deterministic multiworker external memory,
parent refinement, result/capture integration, or clean installation.  Python
remains normative; Rust, G6/G7, and all external claims receive no new
authority.
