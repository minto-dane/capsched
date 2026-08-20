# 0232 — Dynamic Residency F0 Candidate-4 Packed Exact History Arena

## Result

G6 attempt `candidate4-full-20260812T184826Z` again finalized
`RAW_CAPTURE_INCOMPLETE`. The isolated `child-bundle-producer` used one PID,
kept stdout and stderr empty, consumed 2,271.177 CPU seconds, and reached the
sealed 8,053,063,680-byte component limit. The trusted supervisor survived,
killed and drained the component cgroup to `populated 0`, and durably published
a non-positive commit. This is not a semantic counterexample and none of the
captured bytes is eligible for reduction.

The prior compact state columns were effective, but retained evidence still
contained 718,300 Python `Receipt` objects, 685,533 predecessor objects, and
their distinct digest/payload strings at a controlled 750,007-state prefix.
Shallow object accounting alone assigned about 98 MB to receipts and 44 MB to
history nodes; unique string payloads accounted for the remaining dominant
gap. External scratch storage would violate the current read-only candidate
boundary and a second implementation of roughly 5,000 lines of transition
semantics would create semantic drift. The narrow repair therefore changes
only the accepted-state representation.

## Exact packed representation

`PersistentSequence` now has two exact forms. Transition expansion creates a
small transient predecessor view. Once `ExactStateIndex` accepts a state,
`CompactExactStateStore` serializes its receipt sequence into a store-owned
arena:

- predecessor, record, and cached-hash columns are fixed-width C-backed
  arrays;
- history length uses an adaptive exact code column;
- repeated schema, run, binding, scope, subject, sequence, kind, payload,
  payload digest, issuer, channel, and previous-hash values use equality-based
  exact codes;
- canonical lowercase authentication tags use reversible 32-byte storage;
- noncanonical digests, derived string classes, and surrogate text remain
  exact fallback values;
- state reference columns retain exact codes while values are reused and
  promote to direct references only if cardinality exceeds both 4,096 values
  and one quarter of rows;
- bounded 8,192-entry direct-mapped decode and exact-intern caches may miss or
  evict but cannot merge values: every hit checks the complete record or the
  exact parent/record pair; and
- the state index uses at most an 80% load factor, but every hash match still
  checks every state field and complete ordered history.

Packing is lossless storage, not state quotienting. The child and parent
transition relations are unchanged from the predecessor. Forced record-hash
collisions remain distinct, uppercase/non-digest values round-trip, and the
cache changes only whether an equal value gets duplicate storage.

## Mechanical equivalence and capacity

The mutation suites now enumerate both the old list-backed canonical store and
the packed store in the same BFS order. For 2,000 child and 1,500 parent source
expansions, every state, state hash, frontier index, target index, action index,
and ordered receipt value is identical. Child hostile regression passes 284
cases, parent passes 739, runner passes 44, and the expanded memory policy
passes 30 cases. Fast validation reports
`COMPLETE_LOCAL_C4_FAST_REGRESSION_ONLY`; it does not grant full-run credit.

At the exact historical child boundary, both representations retain 750,007
states and 920,973 edges after 86,117 expansions. Maximum RSS falls from the
predecessor's 539,049,984 bytes to 252,858,368 bytes, a 53.0919% reduction.
The original list state vector required 823,132,160 bytes, so the cumulative
reduction is 69.2810%. Fixed state payload is 62 bytes per row, history payload
17 bytes per node, and receipt payload 55 bytes per record. The bounded run
retains 648,982 arena nodes and 633,416 records.

The parent reproduces the predecessor's 250,000 expansions, 545,925 retained
states, and 814,132 edges. Maximum RSS falls from 519,569,408 to 224,624,640
bytes, a 56.7672% reduction. The full child and parent graphs remain unrun.

Applying the measured same-prefix RSS and elapsed ratios to the latest failed
run gives a non-authoritative projection of roughly 3.78 GB and 1.54 hours,
inside the sealed 7.5-GiB and 12-hour component bounds. This is capacity
engineering evidence only; a fresh authority-disjoint G6 capture must prove
completion.

## Disposition

The current exact-input root is
`da4cdb80b3688c7e0de93bdaaae60c773f2410e20b3316b8d3a452bcf32a9fbc`.
The static semantic registry remains
`be5e95640d31ad19ff81f4fe313a7ab29d44fae18c0fff56cfdb99bd86d8b789`.
The trusted reducer and its independent fixture are rebound to these exact
inputs and the 284/739/44 markers.

Clean reviewed commit
`14f6deecca06ce2f23b5faeb335100af952100ea` passed committed-state validation.
Its complete-history Git bundle has SHA-256
`3249567c86ab8e7bffc0cb74b1f3c29b9b58ca29df3b922a36df0f43752241cc`
and was reconstructed in VM-native root-owned storage. Installation produced
artifact manifest
`f434c7d704e4d1c5ea6aac5024121436b70af8526b3280a7e596eb1bcebb4029`
and launcher
`6c85d7822db8012c870e0c6f1940f509bb38b183dd4257ddecf1c96dc1a21f80`.
The complete short post-install suite passes, so a fresh G6 retry is eligible.
G6 remains open, G7 remains blocked, and no F0, R11, K0/G0, Linux/Monitor
implementation, protection, performance/cost, cluster, datacenter, or
deployment claim is granted.
