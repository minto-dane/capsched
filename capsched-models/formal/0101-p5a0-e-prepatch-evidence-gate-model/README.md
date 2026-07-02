# P5A0.E Prepatch Evidence Gate Model

Status: checked gate model for the P5A0.E evidence package.

This model is still a small review gate, not a full scheduler semantics model,
but it is stronger than a single constant record: the safe spec includes a
transition from `Start` to `EvidenceRecorded`.

The safe configuration accepts only evidence that has:

- a fresh source-drift run for the candidate groups;
- explicit recording of stale non-candidate groups;
- patch queue, source checker, build/QEMU, object/symbol, negative harness, and
  claim ledger plans;
- exact naming separation between P5A0.E evidence and future P5A0.P1/P5A0.P2
  patches;
- a file allowlist for P5A0.P1 and a rule that scheduler control-flow file
  touches reopen scope;
- no behavior, denial, non-ALLOW reachability, scheduler branch, fair-picker
  ineligibility, move-settlement, layout, object, hot-path, public ABI, monitor,
  runtime coverage, protection, cost, deployment, or datacenter claim.

Unsafe configurations encode the review mistakes P5A0.E is meant to reject
before any new Linux patch is written.
