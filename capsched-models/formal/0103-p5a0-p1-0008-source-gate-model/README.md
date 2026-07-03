# P5A0.P1 0008 Source Gate Model

Status: checked source-acceptance model for the concrete P5A0.P1 `0008`
patch. Safe TLC passed and 11 unsafe configs produced expected
counterexamples on 2026-07-02.

This model is intentionally narrower than full implementation acceptance. It
checks the source/replay/checkpatch evidence for the concrete `0008` delta and
keeps full build, QEMU, object/layout, runtime coverage, protection, cost, and
datacenter claims out of scope.

The safe configuration requires:

- exactly one `0008` patch with parent/future/patch/series identity recorded;
- delta files exactly equal to the two-file P5A0.P1 allowlist;
- comment-only delta;
- checkpatch clean;
- exact replay head and tree;
- frozen hot-path helper bodies;
- frozen lifecycle helper bodies;
- ALLOW-only validation helpers;
- no scheduler branch on validation;
- no fair-picker ineligibility;
- no layout, ABI, monitor, allocation, lock/refcount, runtime-denial, runtime
  coverage, protection, cost, deployment, or datacenter claim.

The unsafe configurations are expected to fail `Safety`.
