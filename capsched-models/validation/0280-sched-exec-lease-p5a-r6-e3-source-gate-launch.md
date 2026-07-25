# SchedExecLease P5A-R6 E3 Source-Gate Launch

Date: 2026-07-26

## Decision

The exact R6-E3 disposable KUnit candidate and its two fail-closed validation
runners are ready to be committed and launched. The source gate has not yet
passed, no diagnostic boot has started, and no R6-E3 source, correctness,
runtime, protection, or deployment claim is accepted.

## Candidate

```text
parent:
  66e2fd20fc85012d7dc03649fcf4c7af583cbb94
candidate:
  99287291f1c8e0d6c1b3ea86d121508c5547f424
tree:
  2b863b57dfe3f03609ad1a73c965874f71056e8f
diff:
  2ed265756c1cee52252bedc6cbfb3d651eed136be9dca98992496ee80ebfb715
branch:
  codex/p5a-r6-e3-correctness-prototype
files:
  init/Kconfig
  kernel/sched/exec_lease.c
delta:
  1516 insertions, 0 deletions
```

The candidate is a signed, pushed, direct R6-E2 child. Its
`CONFIG_SCHED_EXEC_LEASE_R6_KUNIT_TEST` option is default-off, depends on
`SCHED_EXEC_LEASE_R6_LAYOUT_PROBE && KUNIT=y`, and registers the exact
`sched_exec_lease_r6_correctness` same-translation-unit suite.

The suite contains all 55 ordered plan case families and emits one JSON
`R6_RECEIPT` after cleanup for every parameter case. It instantiates the E2
private types only inside a synthetic KUnit fixture and uses real raw
spinlocks, cpumasks, refcounts, and RCU without attaching to a live runqueue,
task, task group, or cgroup.

## Completed Preflight

The following checks pass before the long build:

```text
strict checkpatch                    0 errors / 0 warnings / 0 checks
required case names                  55 / 55, ordered and unique
allocation fault sites               3 / 3
arm64 W=1 target compile             passed
x86_64 W=1 target compile            passed
enabled object case strings          55 / 55
disabled suite/symbol/receipt data    absent
default-off object sections           unchanged from R6-E2
source-gate PREFLIGHT_ONLY            passed
four-profile config smoke             passed
warning-classifier self-test          passed
```

The four-profile config smoke used a temporary shape-only source-gate fixture.
That fixture and its output were deleted and receive no evidence credit. The
real diagnostic runner requires an explicit regular-file source-gate result
and exact caller-supplied SHA-256 before it will configure, build, or boot.

## Frozen Runners

```text
source gate:
  capsched-models/validation/run-sched-exec-lease-p5a-r6-e3-correctness-source-gate.sh
  2416b0e844385e9e7eb1142d4b3f04523e1af0fde6c401b254eeec0bed199c99

four-profile diagnostic matrix:
  capsched-models/validation/run-sched-exec-lease-p5a-r6-e3-four-profile-diagnostic-matrix.sh
  4b27719906ac0078ffed06af1931eff590bd05024bfbc736b3ddc0f860a4119d
```

The source gate binds the two independently reproduced R6-E3 plan results,
the R6-E2 source gate, dual-architecture result, and independent closure. It
checks the exact two-file direct-child diff, byte-preserved E2 private block,
55 cases, three fault sites, disabled artifact absence, and four fresh build
modes on both arm64 and x86_64 with `W=1`.

The later matrix builds and boots four fresh profiles sequentially on internal
ext storage, records all 55 KTAP parameter cases and 55 JSON receipts per
profile, rejects failure, skip, timeout, and classified kernel diagnostics,
and retires each build before starting the next:

```text
arm64 standard debug + lockdep + RCU + hotplug + faults
x86_64 standard debug + lockdep + RCU + hotplug + faults
arm64 generic KASAN + lockdep
x86_64 KCSAN + lockdep
```

## Claim Boundary

Passing the source gate only authorizes the diagnostic matrix. Passing the
matrix still requires an independent closure. Neither result establishes live
scheduler integration, monitor delivery, runtime denial correctness,
bare-metal behavior, performance, production protection, deployment,
multi-node, multi-cluster, or datacenter readiness.
