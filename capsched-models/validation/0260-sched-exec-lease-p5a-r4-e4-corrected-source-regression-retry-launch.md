# Validation 0260: SchedExecLease P5A-R4 E4 Corrected Source and Regression Retry Launch

Date: 2026-07-19

Status: corrected full retry is launch-ready under detached 30-second
monitoring. No source, regression, closure, or timing pass is claimed.

## Corrected Source Seal

```text
branch:   codex/p5a-r4-e4-local-quantum-measurement
parent:   da9ce9159b3450c28c8faf8dceac671fb7bfeba2
commit:   9e4cb44fd1a1f998fcc288df87dad60505e8bf18
tree:     e6feb28a29fc8c37bc46af0fbf37de30f3401a4f
diff sha: bb115b371cd18551b93c09ae9b3d0cf458e70c9964927ff08d1bd3f586dd4cd2
files:    init/Kconfig, kernel/sched/exec_lease.c
line diff: +1743 -82
```

The candidate remains the exact direct R4-E3 child and is pushed to the
existing Linux Draft PR. Validation/0259 permanently rejects the superseded
attempt for an incomplete observability contract; this retry cannot reuse its
source or closure credit.

## Corrected Gate Seal

```text
source runner:
  6d78a39e4655b05923993c0282e9ac49742c4c47e5be8503f862a54efae1a85e
E3 regression runner:
  e4712c30926e2364af9354db88bd5adca9d1b0afc7df0b79428f1621642d7e9c
combined runner:
  cbadfbcb179029102d54482991c586785765839d4f8bd8d200ae186215c4467a
```

The source gate now requires, rather than merely documents:

- one `migrate_disable()`/`migrate_enable()` interval per complete cell;
- a selected guest CPU and seven per-family CPU comparisons;
- hard-IRQ CPU, IRQ-disabled, and preemption-depth observations;
- IRQ/preemption observations for the other six families;
- result-row CPU, migration, IRQ/preemption, and state-error fields; and
- explicit result claims that migration rejection and state recording were
  enforced.

Strict checkpatch passes at 0 errors, 0 warnings, and 0 checks over all 1,954
patch lines. Corrected source-only run
`20260719T-p5a-r4-e4-source-gate-r2-source-only` passes exact identity,
two-file boundary, style, matrix, observability, and cleanup checks. Fresh
short arm64 and x86_64 E4-enabled `W=1` objects compile at the exact corrected
commit and their VM-internal scratch is retired.

## Canonical Retry

```text
job:    p5a-r4-e4-source-e3-regression-r2
run:    20260719T-p5a-r4-e4-source-e3-regression-r2
watch:  ./tools/long-job.sh watch p5a-r4-e4-source-e3-regression-r2 30
```

The detached launcher must recheck clean root, capsched, primary Linux, and
patch-queue repositories; exact local/fork candidate identity; immutable
runner hashes; absence of every run-owned output/worktree/internal-build path;
running Apple Container state; VM-internal ext4 storage; free-space floors;
and absence of a competing R4-E4 build or QEMU process.

The combined retry is indivisible:

1. build six fresh arm64/x86_64 E3-parent, E4-off, and E4-on objects;
2. resolve all six preserved E3 configs without boot;
3. build and boot all six standard/fault/KASAN/KCSAN profiles from fresh
   VM-internal outputs;
4. require 216/216 cases and typed receipts with zero failures, skips,
   timeouts, compiler/final-skew/kernel warnings, or matrix reduction; and
5. retain sealed artifacts while retiring all successful build scratch.

A successful combined result still says
`timing_measurement_may_start=false`. A new immutable-input, read-only,
reproduced closure bound to the corrected result is mandatory before timing.

## Claim Boundary

This record launches validation only. It establishes no R4-E4 source
acceptance, timing compatibility, real scheduler attachment, runtime
correctness, bare-metal latency, performance, cost, monitor enforcement,
production protection, deployment, multi-node, multi-cluster, or datacenter
readiness claim.
