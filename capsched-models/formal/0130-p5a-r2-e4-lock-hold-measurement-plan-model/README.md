# Formal 0130: P5A-R2 E4 Lock-Hold Measurement Plan

Date: 2026-07-14

Status: pre-source evidence model. It authorizes only creation of the exact
disposable two-file E4 measurement draft after validation/0214 passes.

The model separates frozen source boundary, measured irq-disabled rq-lock
interval, full matrix/statistics contract, and source-draft authorization.
`Safety` requires passed E3 evidence; exact disposable same-TU source; reuse of
the exact rebuild over real scheduler structures; explicit synthetic-fixture
claim limits; O(1) leaf callback and preallocation; actual irq/rq locking;
paired alternating controls and saturating difference; no locked side effect;
all 35 cells and 10,000 samples; full statistics; immutable 25/50 microsecond
gate and warning rejection; preserved negative evidence; malformed-evidence
failure; arm64 plus x86_64 same-source runs; virtualization limits; no range
reduction; and explicit production/performance non-claims.

Twenty-eight unsafe configurations remove one indispensable contract family
each and must produce an expected `Safety` counterexample.
