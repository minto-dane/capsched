# 0240 — Candidate-4 Rust exact-edge fixture slice

## Disposition

The hostile differential now compares exact child transitions, not only
well-formed endpoint states.  Python remains the sole normative executable
model.  Rust independently enumerates `next_states(before)` and accepts an edge
query only when action, actor, and every byte of the complete successor state
match.  The slice passes, but it is deliberately partial: 71 of 295 original
child-regression credits are mapped and 224 remain.  G6 retry remains false and
G7 remains blocked.

## Exact representation boundary

The fixture transport now carries one of three query types:

- a complete 17-field `RunGrant`;
- all 54 `EnvelopeState` fields, including ordered evidence, sequence and
  authentication representation, recovery, seal, and decision objects; or
- `(before, action, actor, after)` with two complete states.

Rust re-encodes every decoded grant and state and requires byte identity with
the input.  Edge equality therefore uses the full audit representation, not
the behavioral quotient used only for bounded graph interning.  The fixture
does not transport an expected verdict: Python evaluates `grant_wf`,
`evidence_wf`, `instance_wf`, or `_edge`, while Rust evaluates its handwritten
predicates or exact successor membership.

## Edge slice

The transport contains 81 queries: 10 grant, 49 state, and 22 edge queries.
Twelve hostile edge queries cover takeover-phase binding, stale-controller
fencing, non-stall no-op rejection, action relabeling, mandatory writer
closure, mandatory pending hidden work, and exact final-counter measurement.
Ten additional valid edges pair those attacks with positive takeover, stream,
exit, candidate, and final-counter witnesses.

Only the 12 hostile edges advance the original-case mapping.  The 10 positive
edges are recorded separately as supplemental evidence, so `case_count=81`
does not inflate `mapped_original_case_credits=71`.  Fifteen malformed
transport variants fail closed.  Fixture SHA-256 is
`ef51241904b19bd01214222c331a41b46db14df2d06a9440b2551290b7c870e6`;
result SHA-256 is
`1aefbfbbfaf392feca95202025d3deb5e525e4e684b895175a0bde57e872f387`.

## Performance and authority

The added checks execute only in the offline hostile-refinement command.  They
do not change Linux, Monitor, the normative Python model, or the Rust bounded
graph hot path.  The zero-dependency release binary remains 592,120 bytes and
is byte-identical from two source roots at SHA-256
`3d6fabd4683017ae7480209ec6df6e548f3dc83dc31c10746dcfb3190970c309`.
No F0, R11, K0/G0, protection, performance, cost, cluster, deployment, or
capture-completion authority follows.

## Next refinement order

1. Map the remaining positive transition/action-set and terminal-certificate
   assertions without embedding oracle verdicts.
2. Add order-distinct exact/behavioral/outcome commutation queries and
   representation-boundary attacks.
3. Require all 295 mappings before closing hostile parity.
4. Then close exhaustive child reachability/commutation and deterministic
   multiworker external-memory enumeration.
