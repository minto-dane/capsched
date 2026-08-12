# 0231 — Dynamic Residency F0 Candidate-4 Compact Exact State Store and Owner-Failure Snapshot

## Result

The G6 attempt `candidate4-full-20260812T170823Z` again ended
`RAW_CAPTURE_INCOMPLETE`. `child-bundle-producer` ran for 1,199.012 seconds,
used essentially one CPU continuously, produced no stdout or stderr, retained
one PID, and reached the sealed 8,053,063,680-byte component limit. The trusted
supervisor survived, drained the component cgroup, observed `populated 0`, and
durably committed a non-positive incomplete record. This is a canonical-state
residency failure, not log growth, process fan-out, or a semantic
counterexample.

The immutable observation is
`validation/f0-c4-g6-third-oom-incomplete-observation-v1.json` at SHA-256
`c25c4b1372ed889202f94daee071eebc7861536780c58700033efbdaefcce70c`.
G6 remains open and G7 remains blocked.

## Exact representation repair

A controlled child prefix retained 750,007 exact states after 86,117
expansions. The predecessor list-based canonical state vector used a maximum
RSS of 823,132,160 bytes at that same prefix. The successor stores each state
as exact field columns:

- low-cardinality immutable fields use equality-interned adaptive unsigned
  byte/word/dword codes;
- high-cardinality histories and typed receipts retain one direct reference
  per state;
- every hash match invokes equality for every state field;
- the canonical store is frozen before publication;
- the BFS frontier is a 32-bit array plus a cursor; and
- the post-graph unique-history counter reuses the collision-safe exact index
  rather than allocating a Python set.

The same prefix retains exactly 750,007 states, a 663,890-state frontier, and
920,973 edges with maximum RSS 539,049,984 bytes, a 34.5123% reduction. The
fixed column payload is at most 96 bytes per retained child state; this number
deliberately excludes shared value-pool objects and is not represented as a
whole-process memory bound. Exact histories, state identity, transitions,
CSR edges, the zero-swap policy, and all production hot paths remain intact.

## Parent contradictions exposed by deeper exploration

The smaller retained representation allowed parent exploration to pass code
that earlier child OOMs never reached. Two independent contradictions were
found through the real transition boundary.

First, `SUP-018-PREPARE-LOCAL-PUBLICATION` allowed a recovery guardian to
prepare generation-1 publication while the durable store still recognized
controller generation 0. The target failed its own well-formedness predicate.
The transition now requires the store-controller generation to equal the
recovery generation, so `STORE-018A-FENCE-PUBLICATION-CONTROLLER` must complete
first.

Second, a sealed parent ledger had no append position from which to recover the
exact owner-failure phase. The old predicate inferred historical state from
current capsule, commitment, durable-ack, and fence objects. Later store
fencing or abandonment could therefore make an authentic old failure appear
to have occurred in a later phase. `OwnerFailureNotice` now signs and binds the
pre-failure capsule, publication class, store-controller generation,
publication commitment, durable ack, and store-fence ack. One shared predicate
cross-checks that snapshot against retained current or superseded evidence.
Open-ledger failures still require the exact receipt position; sealed-ledger
failures use the authenticated snapshot and never reverse-infer history from
post-failure progress.

This is an intentional parent semantic repair, not a representation-only
change. The parent state schema and transition relation changed, while external
claim authority remains absent. The fast regression includes legitimate
generation-0 and generation-1 `LOCAL_DECIDED`, `PREPARED`, `DURABLE`,
`FENCE_PENDING`, and `FENCED` failures, plus coherently re-signed omissions and
post-failure generation substitution.

## Validation and disposition

The final exact input root is
`ab8bbed2cd376e2b24205c3bfe13adabf713ca1cc470e9546514ac53ff40a925`.
Linux fast validation passes child 275, parent 730, and runner 44 hostile cases;
the memory policy passes 24 cases. The semantic registry remains
`be5e95640d31ad19ff81f4fe313a7ab29d44fae18c0fff56cfdb99bd86d8b789`.

A final-source parent prefix completed 250,000 expansions, 545,925 exact
states, and 814,132 edges with maximum RSS 519,569,408 bytes. This exceeds the
earlier contradiction point at 31,822 expansions but is only a bounded prefix,
not full parent reachability.

The installed TCB predates these bytes. A clean reviewed commit, digest-checked
VM-native transfer, reinstall, and the complete short mechanism suite are
required before another G6 attempt. No F0, R11, K0/G0, full reachability,
protection, Linux/Monitor implementation, performance/cost, cluster, or
deployment claim is granted.
