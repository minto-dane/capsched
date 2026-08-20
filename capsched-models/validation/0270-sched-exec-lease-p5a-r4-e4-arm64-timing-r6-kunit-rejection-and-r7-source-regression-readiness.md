# SchedExecLease P5A-R4 E4 Arm64 Timing R6 KUnit Rejection and R7 Source-Regression Readiness

Date: 2026-07-23

## Decision

Arm64 timing r6 is rejected as `harness_failed/evidence_validation`. Exact
paused-QMP placement and QEMU exit zero passed, but the measurement KUnit suite
finished with five passes and two failures. Its 538 of 682 result rows and all
derived timing values receive no threshold, architecture, performance, or
x86_64 credit.

The canonical r6 result SHA-256 is
`28bd8b4cc8561a1b01a4fdcbbd3d584427ce5c7cf4b8bef55085745fce5f0c53`.
Two independent read-only failure closures over the exact 40 timing artifacts
and 26 job records produce result SHA-256 values
`62fc4950c46a77d9c51a45d7c24fb0ad3b4cbb25b6288de5e4729bff36fe303d`
and
`6f1c2231ecaa9f069ed6b3759f74603a25be619de5d74215a4f79921f2162795`.
Removing only `run_id` yields byte-identical normalized SHA-256
`1ed1c74331eb818ea355a6c8c3d7daa03362cc8d79c8e43a236d3b49757a3c3f`.

## Exact Failure Boundary

The guest emitted 538 typed rows and six summaries. Passed row families are
publication 288, picker 144, hard IRQ 9, notifier 48, and current 24. Recovery
emitted no accepted rows after setup returned `-EINVAL`; offline emitted 25
rows but reported 205,120 integrity errors. The QMP record maps guest vCPUs
0 and 1 to distinct TIDs and singleton host CPUs 0 and 1 before the first row.

The offline error count is exact, not stochastic:

```text
20 nonzero occupancy cells * (256 warmups + 10,000 measured pairs) = 205,120
```

Control observations intentionally have zero visits, while the old oracle
compared both treatment and control visits with treatment occupancy. The
correct relation is treatment visits equal occupancy and control visits equal
zero.

## Recovery Lost-Handoff Root Cause

The recovery failure is schedule-dependent. Re-running only the recovery case
from the exact r6 Image completed setup and emitted a row, disproving an
intrinsic `B_max=64` or static-fixture error.

The full suite exposes a future-progress hole. While the ordinary work item is
running, the hard-IRQ callback may observe `queue_work()` return false. The
worker can then observe `irq_work_queue()` coalesced while that callback is
still busy. Both owners subsequently finish with dirty projections remaining
and no future owner. A false queue return proves only a live or pending owner
at that instant; it does not prove a future handoff after both callbacks exit.

## R7 Correction

Disposable direct-R4-E3 child
`4077ba840f713979c29af64f405dbde39f845d93`, tree
`6ce127d738618fd356ed3533ac32e5796fa72d55`, and full-diff SHA-256
`a4886479f001ea3ef0dbc069ef44040f89df69cc9114421933a5592075bfe255`
make only the following synthetic default-off corrections:

- remaining bounded recovery quanta self-requeue the ordinary work item;
- the deterministic handoff fixture completes the IRQ callback before
  releasing the held worker and proves a second worker invocation drains
  dirty depth to zero;
- the offline oracle requires zero control visits rather than treatment
  occupancy.

Workqueue self-requeue remains non-reentrant and preserves one ordinary worker
owner. The initial rq-locked hard-IRQ-work to ordinary-work bridge is unchanged.
Strict format-patch checkpatch reports zero errors, warnings, and checks. Two
fresh arm64 `W=1` objects pass with zero diagnostics. The updated source-only
gate binds exact corrected source block SHA-256
`4c8e46fb3bb23bc5688f01f0e33eed4f381403a85ee42717105fefde8544a463`
and cleans every owned worktree.

## Next Gate and Claim Boundary

R7 is pushed on
`codex/p5a-r4-e4-local-quantum-measurement-r7`, but source acceptance is
reopened. A fresh six-object, six-profile, 216-case/receipt regression with
zero diagnostics and two independent read-only closures is mandatory before
any fresh arm64 timing run. R6 cannot be postprocessed or resumed.

No timing, x86_64, live scheduler correctness, bare-metal latency,
performance, runtime protection, monitor enforcement, production,
deployment, multi-node, multi-cluster, or datacenter-readiness claim is
accepted.
