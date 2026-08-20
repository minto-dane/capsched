# Validation 0261: SchedExecLease P5A-R4 E4 Source-Gate Attempt 2 Scope Rejection

Date: 2026-07-19

Status: attempt 2 is rejected without source, regression, closure, or timing
credit. A corrected fresh attempt 3 is launch-ready.

## Attempt 2 Boundary

Detached job `p5a-r4-e4-source-e3-regression-r2`, run
`20260719T-p5a-r4-e4-source-e3-regression-r2`, exited 1 before any object build,
configuration smoke, or QEMU boot. The source gate stopped at 28% with:

```text
error: hard-IRQ CPU observation missing
```

The combined runner emitted no result. The source runner emitted no result and
retained only 15 pre-build diagnostic artifacts (232,913 bytes), whose
canonical relative-path/content manifest hashes to:

```text
e82de9266f268024e164559f7ec5aa5201472c8441e30e9b3e353c5da2c4886c
```

The external job log SHA-256 is
`2a549c710ad5d3d5b2cb8a9e075ece0632f1ebcbc0aa460312230720295be6d5`.
All attempt-owned Git worktrees and VM-internal build scratch were retired.
There is no partial pass to reuse.

## Root Cause

The corrected Linux candidate is unchanged and contains all three required
hard-IRQ observations inside the shared `sched_exec_r4_dispatch_irq()` helper:

```c
rq->measure_irq_irqs_disabled = irqs_disabled();
rq->measure_irq_preempt_depth = preempt_count();
rq->measure_irq_cpu = raw_smp_processor_id();
```

That helper precedes the E4-only KUnit block. The attempt-2 source runner
correctly extracted the E4-only block to `e4-block.c`, but incorrectly searched
that narrower artifact for the three shared-helper assignments. The failure is
a validator-scope false negative, not evidence that the candidate omitted the
observations.

## Corrected Gate

The source runner now independently extracts the exact shared dispatch-helper
region to `hard-irq-dispatch.c`, requires the artifact to be non-empty, and
requires each CPU, IRQ-disabled, and preemption-depth assignment exactly once
inside that region. It continues to inspect all seven per-family sample
observations and the E4 result-row fields inside `e4-block.c`.

```text
corrected source runner:
  8458c7ec6ea8ea8c38d2cee0e358fdfb6eff4e3bf6ec7c53ecf9cbe8241561c5
unchanged E3 regression runner:
  e4712c30926e2364af9354db88bd5adca9d1b0afc7df0b79428f1621642d7e9c
unchanged combined runner:
  cbadfbcb179029102d54482991c586785765839d4f8bd8d200ae186215c4467a
```

`bash -n` and VM ShellCheck pass. Source-only run
`20260719T-p5a-r4-e4-source-gate-r3-hard-irq-scope` passes exact repository and
candidate identity, two-file/diff/style/default-off/E3-byte-preservation
boundaries, all 682 cells, all CPU/state/result-row checks, and cleanup without
starting an object build. It retained 16 artifacts (252,213 bytes) with
canonical relative-path/content manifest SHA-256
`c88e76ce9cf65d661ecc50b03ad9906a631bac29f179d033309f1e5974aafb3c`.
The extracted dispatch artifact SHA-256 is
`90aea1666fe5f20631529e5b0855cc975605e85345bf802329e792121b2601c9`.

## Fresh Retry Only

Only fresh job `p5a-r4-e4-source-e3-regression-r3`, run
`20260719T-p5a-r4-e4-source-e3-regression-r3`, may retry the indivisible six
source-object and six-profile/216-case regression. It must use corrected Linux
candidate `9e4cb44fd1a1f998fcc288df87dad60505e8bf18`; attempts 1 and 2 remain
immutable rejected evidence.

A successful attempt 3 still cannot authorize timing directly. A newly
hash-bound independent read-only closure must audit every retained artifact
twice and reproduce one normalized decision first.

## Claim Boundary

This correction validates gate scope only. It establishes no source
acceptance, E3 regression pass, timing compatibility, real scheduler
attachment, runtime correctness, bare-metal latency, performance, monitor
enforcement, production protection, deployment, multi-node, multi-cluster, or
datacenter readiness claim.
