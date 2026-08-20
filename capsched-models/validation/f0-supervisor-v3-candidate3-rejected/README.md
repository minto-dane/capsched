# Supervisor v3 Candidate 3 Rejection

Status: `REJECTED`. These bytes are immutable counterexample evidence and must
not be edited in place. No full campaign was authorized or launched.

This directory preserves the exact six-input candidate reviewed after the C2 parent rejection. Reviewers must identify the candidate by `MANIFEST.sha256`; conclusions about other bytes do not apply to this snapshot.

Local evidence before freezing:

- child hostile and ordered-trace regression: 252 cases passed
- parent hostile regression: 559 cases passed
- fast mutation/static validator: passed with immutable input hashes
- child and parent reachability: not run
- external authentication, attack-context-key refinement, durable-store refinement, F0, G0, Linux behavior, and protection claims: not established

The first-attempt-per-abstract-context rule was described as a partial-order
reduction, but review showed that it is only an unproved repetition cutoff. It
removes ordered histories that cannot be recovered by commuting independent
actions.

Independent local review sessions:

- `019fec37-d764-7d92-82f9-904c60914305`: publication/store/WF review
- `019fec37-d863-7b13-9329-b16f85cf6ac1`: attack-context and cutoff review
- `019fec37-da3c-7b23-bd8a-77dab8e46db6`: assurance runner review
- `019fec37-dbd4-7f60-8b90-f3a5a9767997`: parent-child composition review

Blocking findings include:

1. Guardian-local generation changes do not fence an in-flight old durable-store CAS.
2. Tombstone success and a synthetic unattributed conflict branch from the same recorded head state.
3. `OrchestratorWF` admits phase/disposition states whose generated transitions reject or assert.
4. An active owner can be mutated into an accepted owner-failure abandonment path.
5. Coherently substituted context digests can suppress an attack class never attempted.
6. The first-context cutoff is not an exact-history POR equivalence.
7. Terminal abandonment can retain an accepted but unretired child grant.
8. Post-failover child certificates are not bound to parent controller generation.
9. Newly written capsules can be coherently relabeled with a stale controller generation.
10. Child actions still accept non-stall no-ops and cross-action relabeling.
11. `PYTHONOPTIMIZE=1` strips the mutation assertions while reporting a pass.
12. The runner's unqualified `PASS` and incomplete failure finalization can obscure authorization scope.

The successor must address these findings without claiming durable-store,
authentication, parent-child continuity, external review, F0, G0, Linux, or
protection refinement.
