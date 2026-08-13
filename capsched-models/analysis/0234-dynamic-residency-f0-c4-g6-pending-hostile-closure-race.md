# 0234 — Candidate-4 pending-hostile closure race

## Decision

The eighth authority-disjoint G6 attempt,
`candidate4-full-20260813T071653Z`, proved that the disk-backed exact
enumerator crosses the former RAM boundary without OOM, then found a real child
transition contradiction.  The child ran for 41,029,516,563,519 monotonic
nanoseconds, peaked at the sealed 7.5-GiB memory boundary, allocated
12,220,313,600 bytes in its private ext4 spill image, and exited with
`oom=0` and `oom_kill=0`.  The root supervisor drained the cgroup, removed
the spill boundary, and committed `RAW_CAPTURE_INCOMPLETE`.  No captured
bytes are positive-eligible and G7 remains blocked.

The minimized 17-action trace observes an ATTACH attempt, completes ordinary
exit and authority revocation, closes attach and asynchronous admission, and
then publishes `MON-039C-PROTECTION-CLOSED` while the ATTACH attempt still
lacks a rejection or breach disposition.  The next explicit
`ADV-023B-SUCCEED-HOSTILE-BYPASS` correctly changes protection to
`BREACHED`, but the premature closure receipt makes that successor violate
`InstanceWF`.

## Minimal semantic repair

`MON-039C-PROTECTION-CLOSED` now additionally requires:

- `pending_attack == NONE`; and
- `attack_attempts == attack_rejections`.

The same precondition is present in both executable successor generation and
action-effect checking.  The repair does not weaken `InstanceWF`, erase the
hostile branch, or force a favorable outcome.  An unresolved attempt still has
both explicit outcomes: observer rejection and adversarial bypass.  Rejection
re-enables protection closure; bypass remains a well-formed terminal
`BREACHED` state.  This intentionally changes the child transition relation
and reachable graph by removing only premature closure edges.

The exact state representation, ordered receipts, packed histories,
disk-backed store, private ext4 spill boundary, OOM isolation, guardian
cleanup, parent model, Linux scheduler hot path, and Monitor dispatch hot path
are unchanged.

## Disposition

The child hostile suite now passes 285 cases, including the delayed-attempt
trace.  Parent and runner baselines remain 739 and 44.  Current exact-input
root `1edf170ad29edc8b450023f4d88acb160733471bcd69f29f81fa8b4ab18cc91d`
has not completed a full campaign.  Clean reviewed commit
`27ba274c859d271861a373decc4ecd51c9e0c7ce` was reconstructed from verified
Git bundle
`4dc37363a0cafa2f02b06f595f854de81c30ac198955f9b3e7e31fb61cae15d5`,
installed under manifest
`c919f59195073205799806d6b75ce50a19f8a75d720ecbfc85d24a436d96943d`,
and passed the complete short suite.  A fresh G6 retry is eligible.  F0, R11,
K0/G0, protection, performance, cost, deployment, and model-completion
authority remain false.
