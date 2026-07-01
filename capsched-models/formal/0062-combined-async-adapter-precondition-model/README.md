# Combined Async Adapter Precondition Model

This model checks the N-129 combined async-adapter precondition gate.

It does not model Linux implementation. It models only the ordering pressure
for when a future candidate Linux patch proposal may be drafted.

Safe design pressure:

```text
shared async carrier core checked
workqueue adapter refinement checked
io_uring adapter refinement checked
adapter mechanics kept separate
authority intersection preserved
caller-scoped budget and settlement preserved
revoke/freshness separated from Linux cleanup
source/drift and evidence-class non-claims preserved
candidate patch proposal allowed only after all gates
```

Unsafe configurations reject:

```text
candidate patch before workqueue refinement
candidate patch before io_uring refinement
broad N-126 model alone as implementation gate
shared core as generic Linux async subsystem
cross-adapter lifecycle collapse
Linux object authority allowed
missing evidence split
ABI approval
behavior change
monitor verification claim
production protection claim
```

This is not Linux implementation, runtime coverage, ABI approval, monitor
verification, behavior change, or production protection.
