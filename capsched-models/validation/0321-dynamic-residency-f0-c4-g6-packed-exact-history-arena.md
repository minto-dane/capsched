# 0321 — Dynamic Residency F0 Candidate-4 G6 Packed Exact History Arena

## Durable failed-run evidence

- Run: `candidate4-full-20260812T184826Z`
- RAW_COMMIT SHA-256: `b81355f1286cc9d006ebc12663f10f65d93ce4e7249e42485d73ca360b968d1c`
- Capture manifest SHA-256: `666588a88d43fbe8ac4cac8e1f7cabb330d0630321e3b20bf845cf6c06934e59`
- Sealed plan SHA-256: `aeb74f6355656b1302e8406855c2fe5735428a1aae164678eacffdd6be5a8f15`
- Failed component receipt SHA-256: `182c8386307609e4f529e1f81773a2383c85826f77337101cb4237cb56e07f6b`
- Status: `RAW_CAPTURE_INCOMPLETE`
- Positive eligibility: false
- Reduction performed: false
- Failed component: `child-bundle-producer`
- Elapsed: 2,271,212,395,837 monotonic ns
- CPU: 2,271,177,176 us
- Memory peak: 8,053,063,680 bytes
- PID peak: 1
- stdout/stderr: 0/0 bytes
- cgroup killed, drained, and `populated 0`: true

The capture unit completed after fail-closed finalization and the host launcher
returned status 1. The trusted supervisor survived the component OOM. The
immutable observation is
`f0-c4-g6-fourth-oom-incomplete-observation-v1.json` at SHA-256
`9956feff9988d7cf1de4fb8bdfe1f92b770c6556e42f8aa2490feaee52a252b5`.

## Successor exact inputs

Input root:
`da4cdb80b3688c7e0de93bdaaae60c773f2410e20b3316b8d3a452bcf32a9fbc`.

```text
LOCAL_C4_CHILD_REGRESSION_PASS hostile_cases=284
LOCAL_C4_PARENT_REGRESSION_PASS hostile_cases=739
LOCAL_C4_RUNNER_REGRESSION_PASS hostile_cases=44
F0_C4_MODEL_MEMORY_POLICY_PASS cases=30
COMPLETE_LOCAL_C4_FAST_REGRESSION_ONLY
```

The static semantic registry remains
`be5e95640d31ad19ff81f4fe313a7ab29d44fae18c0fff56cfdb99bd86d8b789`.
The reducer and reduction fixture require the successor's exact four changed
input hashes and exact success markers.

## Exactness regressions

The suite demonstrates:

- list-backed and packed child BFS prefixes have identical state order, state
  hashes, frontier, target, action, and ordered-history values for 2,000
  expansions;
- the same equality holds for a 1,500-expansion parent prefix;
- forced record-hash collisions cannot merge unequal histories;
- an exact history repeated while resident in the bounded cache reuses its
  node, while cache collision or eviction only misses deduplication;
- canonical lowercase digests and noncanonical or surrogate-bearing values
  round-trip exactly;
- decode and intern caches are independently fixed at 8,192 entries;
- adaptive state references remain one-byte exact codes for the measured
  low-cardinality fields and have a tested direct-reference promotion path;
- the exact state index preserves full collision equality at an 80% maximum
  load; and
- a frozen compact state store still rejects mutation.

## Bounded memory profiles

The child profile reproduces 86,117 expansions, 750,007 states, a 663,890-state
pending frontier, and 920,973 edges. Maximum RSS is 252,858,368 bytes, down
53.0919% from the prior compact store and 69.2810% from the original list
vector. Fixed state/history/receipt payloads are 62/17/55 bytes.

The parent profile reproduces 250,000 expansions, 545,925 states, a
295,925-state pending frontier, and 814,132 edges. Maximum RSS is 224,624,640
bytes, down 56.7672% from the predecessor. Fixed state/history/receipt payloads
are 72/17/54 bytes.

These are bounded prefixes, not full reachability results. A linear capacity
projection is favorable but is explicitly non-authoritative.

## Gate result

G1-G5 remain locally closed at EC0. The source repair is not installed yet, so
G6 retry eligibility is false until a clean reviewed VM-native install and the
complete short mechanism recheck pass. G6 remains open and G7 remains blocked
by `NO_COMPLETE_G6_CAPTURE`.

No F0/R11/G0, external attestation, Linux/Monitor behavior, protection,
performance/cost, cluster, datacenter, or deployment claim is granted.
