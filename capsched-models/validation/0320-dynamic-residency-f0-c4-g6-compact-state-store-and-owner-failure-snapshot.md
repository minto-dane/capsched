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

## Clean-install qualification

Clean reviewed commit
`1c076a94988ae4385212230e6c19acf905bb63ea` passed the committed-state checker.
Its complete-history Git bundle has SHA-256
`b18352db1dc74dc743289f520eff2d02bbfc1af003a296612f11da46ccaeae76`
and was reconstructed under the VM-native root-owned reviewed-source root. The
installed artifact manifest SHA-256 is
`75d17ee9b9cd24237d953b768e36559bab5eba8ce40f8bdc7526a9b359dcda85`;
the installed launcher SHA-256 is
`d231c12e8ad243ec74577b89d99bb19b9ddf112e950739efebe3c28e2b0903c9`.

Post-install checks pass: launcher basic 1, launcher hostile 10, snapshot
hostile 5, capture-resource 7, model-memory 24, current reducer binding 3,
immutable-toolchain reuse 1, supervisor smoke 5 components, guardian recovery
3, and reduction boundary 3. The EROFS toolchain remains read-only at SHA-256
`b3ed1553c9b40a48a27ce8ad792a0add387f82f49afc0edec7563234f2e78cce`.

## Gate result

G1-G5 remain locally closed at EC0. G6 remains open and G7 remains blocked by
`NO_COMPLETE_G6_CAPTURE`. The exact successor TCB is now clean-installed and a
fresh G6 retry is eligible. This does not close G6 or make any incomplete bytes
eligible for reduction.

No F0/R11/G0, external attestation, Linux/Monitor behavior, protection,
performance/cost, cluster, datacenter, or deployment claim is granted.
