# 0323 — Candidate-4 pending-hostile closure repair validation

## Durable failed capture

Run `candidate4-full-20260813T071653Z` used exact-input commit
`1d562546fce0fe58d9701a08b75edf114f3e433c`, installed TCB source
`65d9827916f669363f2a82118b90dee2a7ff664c`, installed manifest
`1c688a1017b59a0763fd0fec29b55b6f4f0a23ea0decffc149072215fe56eb7d`,
and capture contract
`d5a1b44fc61d3f52542c1596dfe01ed510201486be8b2768ccb4a8901e72effe`.

Independent SHA-256 checks bind:

- raw commit:
  `b22ab6d6e0b03f3c8b98c420073badfe7a47b86b72bef5d8d51cfbfad182be94`;
- capture manifest:
  `4898099a0ac33f32293be9d3d2d4e6dabc3eab42c16153e15f974c164f11b29c`;
- sealed plan:
  `1e8cf444af178a6652aba9f8459ab892090aee647e1061cebdb8506156416682`;
- child receipt:
  `6b054d0daa38ce16cfa2ccd4b0d5e04847eae417ae49a7a2e11d81ed9a0521da`;
- child stderr:
  `7ba5d2f18ee15b5a82b630d11f64252b0dce1a263480181264765b2ae5fe9d4e`.

The receipt records exit code 1, one PID, 8,053,063,680-byte peak memory,
41,017,641,086 microseconds of CPU, 39,191 `memory.max` hits, zero OOM
events, zero OOM kills, successful cgroup drain, and complete external-memory
cleanup.  The durable status is `RAW_CAPTURE_INCOMPLETE`; unit exit status is
not used as a positive semantic oracle.

## Counterexample and regression

The child stderr rejects
`ADV-023B-SUCCEED-HOSTILE-BYPASS` at `F05-SPV3-EFFECT-WF`.  Delta
minimization reproduces it in 17 actions.  The regression now proves:

- protection closure is unavailable while ATTACH is pending;
- observer rejection and adversarial bypass both remain available;
- bypass reaches a well-formed terminal `BREACHED` state;
- rejection clears the pending attempt and makes attempt/rejection ledgers
  equal; and
- protection closure becomes available only after that disposition.

The direct child test passes
`LOCAL_C4_CHILD_REGRESSION_PASS hostile_cases=285`; the unchanged parent and
runner tests pass 739 and 44 cases.  Committed-state validation passes for
`27ba274c859d271861a373decc4ecd51c9e0c7ce`.  Installation produces manifest
`c919f59195073205799806d6b75ce50a19f8a75d720ecbfc85d24a436d96943d`
and launcher
`7652adf9dce7a4ed6859582e1a8b3f5fa047644676cfeacd13927ca691cfde8d`.
The complete post-install suite passes 31 memory-policy, one storage
equivalence, 17 resource-policy, launcher basic/10 hostile/one idle, five
snapshot, five supervisor, three guardian, one external-recovery, three
reducer-binding, one toolchain-reuse, and three reduction-boundary cases.

## Current disposition

The observation record is
`f0-c4-g6-pending-attack-incomplete-observation-v1.json`.  G6 remains open,
the repaired exact inputs and capture TCB are clean-installed, retry eligibility
is true, and G7 remains blocked.  This record grants no external, protection,
performance, deployment, or model-completion claim.
