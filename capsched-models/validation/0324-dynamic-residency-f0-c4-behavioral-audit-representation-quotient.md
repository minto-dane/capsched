# 0324 — Candidate-4 behavioral audit quotient validation

## Durable failed-capture evidence

Run `candidate4-full-20260813T223812Z` is bound by:

- raw commit `1f0ec4dc394a2860aec3a5da788a616c34c8da43ca99965a924cc8b8fed7ea8c`;
- capture manifest `a6f0dca8d2aa1f26df3792500bac85d8a4006096d668b16ef13f5d93dbf21427`;
- sealed plan `178b3d203a898c918b4ccd1c8753b7298cf46751586c346cf659cc646bc60d77`;
- failed producer receipt `56ff5e3be9b046f6e9fb5afe47c32d1c3cd92dd629f36b6cd0711410501d37d3`; and
- public-safe observation
  `f0-c4-g6-exact-history-timeout-observation-v1.json`, SHA-256
  `0e26bf127292138a722dfdd6f91ba46b12bf968547d4880014a03431b1da201c`.

The receipt proves `DEADLINE_EXCEEDED`, 43,200,554,052,465 elapsed monotonic
nanoseconds, 7.5-GiB peak memory, 68,215 `memory.max` events, zero OOM events,
zero OOM kills, successful cgroup drain, and complete external-memory cleanup.
The durable status remains `RAW_CAPTURE_INCOMPLETE`; G7 is not authorized.

## Mechanical validation

The repaired exact input set passes:

- child hostile regression: 295 cases;
- parent hostile regression: 739 cases;
- fail-closed runner regression: 48 cases;
- behavioral projection boundary/congruence regression: 9 boundary cases,
  2,000 exact expanded sources, 20,510 exact states, 24,920 edges, and 669
  representation-equivalent expanded sources;
- compact memory policy: 33 cases, including forced projection-hash collision
  resolution;
- RAM/ext4 equivalence: both exact and quotient prefixes, two cases; and
- static action/authority registries: 56 child actions, 46 parent actions, six
  declared independence IDs, and unchanged semantic registry
  `be5e95640d31ad19ff81f4fe313a7ab29d44fae18c0fff56cfdb99bd86d8b789`.

Runner schema version 5 rejects receipt-semantic erasure, simultaneous exact
and quotient identity claims, commutation identity disagreement, audit-chain
refinement overclaim, unknown fields, non-finite/duplicate JSON, impossible
cardinalities, unbound component bytes, and claim/evidence drift.  The
independent post-run reducer applies the same schema, cardinality, action,
claim, and quotient boundaries.  Its positive child predicate also requires
the hostile test component to have passed.

## Exact input binding

The exact input root is
`522a053e506e6702dbcd798bc3ccbcf6fdda046ddf414bcc4242794100fb299c`.
The claim registry contains 12 claims and has SHA-256
`2a0420ed570ee1ac4f618fea32a4237345dfdb8e3d3333fd565789000c1fd438`.
The full child claim is explicitly
`F0-C4-REACH-CHILD-BEHAVIORAL-AUDIT-QUOTIENT-BOUNDED-v1`; ordered audit-chain
implementation refinement is separately `OPEN_REFINEMENT`.

## Disposition

The code and fixtures are locally coherent, but these bytes have not yet been
installed as a clean reviewed VM TCB and have not completed G6.  Clean commit,
VM-native installation, the complete post-install short suite, and a fresh
authority-disjoint capture are required next.  F0, R11, K0/G0, protection,
performance, deployment, and model-completion authority remain false.
