# 0320 — Dynamic Residency F0 Candidate-4 G6 Compact State Store and Owner-Failure Snapshot

## Durable failed-run evidence

- Run: `candidate4-full-20260812T170823Z`
- RAW_COMMIT SHA-256: `a09184c13f72b4c92f83e38066207adfb5c82aa88dbe9081c71519198527fedb`
- Capture manifest SHA-256: `07e1dcefe01e026092f9bf0bca4498fb6abf748c83de73a3d1d8d08f869fba0b`
- Sealed plan SHA-256: `6f23e5473cc1f654c18ddef145cb6d2b359d301cf1f059b2ec3475dcb055a24f`
- Failed component receipt SHA-256: `f3a6c4b724b8e600f7aeeef6eaba81f57a2e3bd109930b1b47bcd37ccd33b125`
- Status: `RAW_CAPTURE_INCOMPLETE`
- Positive eligibility: false
- Reduction performed: false
- Failed component: `child-bundle-producer`
- Elapsed: 1,199,011,887,929 monotonic ns
- CPU: 1,198,996,955 us
- Memory peak: 8,053,063,680 bytes
- PID peak: 1
- stdout/stderr: 0/0 bytes
- cgroup drained and `populated 0`: true

The capture unit completed successfully after fail-closed finalization; only
the host launch unit returned status 1. The trusted supervisor was not killed
by the component OOM.

## Successor exact inputs

Input root:
`ab8bbed2cd376e2b24205c3bfe13adabf713ca1cc470e9546514ac53ff40a925`.

```text
LOCAL_C4_CHILD_REGRESSION_PASS hostile_cases=275
LOCAL_C4_PARENT_REGRESSION_PASS hostile_cases=730
LOCAL_C4_RUNNER_REGRESSION_PASS hostile_cases=44
F0_C4_MODEL_MEMORY_POLICY_PASS cases=24
COMPLETE_LOCAL_C4_FAST_REGRESSION_ONLY
```

The static semantic registry remains
`be5e95640d31ad19ff81f4fe313a7ab29d44fae18c0fff56cfdb99bd86d8b789`.
The reducer and its independent boundary fixture are rebound to the exact
successor input hashes and the 730-case parent success marker.

## Security closure checks

The regression suite demonstrates:

- exact reconstruction and all-field equality from compact columns;
- adaptive code-width promotion without truncation;
- forced hash collisions cannot merge unequal states;
- a frozen canonical store rejects appends;
- canonical BFS and unique-history counting use fixed-width exact indexes;
- a recovery controller cannot prepare publication before the durable-store
  controller fence;
- sealed owner-failure evidence binds the exact pre-failure capsule,
  publication, generation, commitment, durable ack, and fence ack;
- later fencing and abandonment preserve the signed historical phase; and
- coherently re-signed omission or generation substitution remains rejected.

The final-source child prefix reproduced 750,007 exact states and 920,973
edges at 86,117 expansions with maximum RSS 539,049,984 bytes. The final-source
parent prefix passed 250,000 expansions, 545,925 exact states, and 814,132 edges
with maximum RSS 519,569,408 bytes. Neither bounded prefix grants full-run
credit.

## Gate result

G1-G5 remain locally closed at EC0. G6 remains open and G7 remains blocked by
`NO_COMPLETE_G6_CAPTURE`. The current status is `REINSTALL_REQUIRED`: the
installed TCB commit `1fccacab7a94248fba443adc6b2de746a3565701` contains the
predecessor input bytes, so another G6 launch is forbidden until the successor
is clean-installed and the short post-install suite passes.

No F0/R11/G0, external attestation, Linux/Monitor behavior, protection,
performance/cost, cluster, datacenter, or deployment claim is granted.
