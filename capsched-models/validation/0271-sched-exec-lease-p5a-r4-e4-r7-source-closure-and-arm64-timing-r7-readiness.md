# SchedExecLease P5A-R4 E4 R7 Source Closure and Arm64 Timing R7 Readiness

Date: 2026-07-23

## Decision

The corrected R7 disposable source passes the complete fresh source and R4-E3
regression gate and two independent read-only closures. Exact virtual-synthetic
R4-E4 source acceptance is restored for candidate
`4077ba840f713979c29af64f405dbde39f845d93`, tree
`6ce127d738618fd356ed3533ac32e5796fa72d55`, and full-diff SHA-256
`a4886479f001ea3ef0dbc069ef44040f89df69cc9114421933a5592075bfe255`.

Only one fresh arm64 timing r7 attempt is authorized. This does not accept a
measurement result or any live-runtime, bare-metal, performance, production,
or datacenter claim.

## Fresh Combined Regression

Detached run
`20260723T-p5a-r4-e4-owner-oracle-correction-source-e3-regression-r7`
finished in 7,059 seconds with exit zero. Its combined result SHA-256 is
`643eceae277f6f419a0d9ecaa82c183d073ca7c6c228dec5d3190661a6bd3714`.
The source result SHA-256 is
`ac6fb29e154375fd7c35c36d0f78fb96394ef4861166a6cccec2b0fe37fd2995`;
the config-smoke result is
`8b62af9fab6275a071898ac1c3de46c71b487b492b147cc03fce00d1fccaf26d`;
and the six-profile result is
`ccfceaccd0bcd1107d9c94532b3c2b075c756780fca63c9e8d069f6b821b898a`.

The run passed:

- six fresh arm64/x86_64 `W=1` source objects with zero diagnostics;
- all six standard, hotplug/fault, KASAN, and KCSAN profiles;
- 216 of 216 KUnit cases and 216 of 216 typed receipts;
- all six corrected handoff receipts with seven oracle checkpoints and drained
  cleanup;
- zero failures, skips, timeouts, warning reports, nonzero QEMU exits, or
  retained build/worktree scratch.

## Independent Double Closure

Closure runner SHA-256
`5a321628da8d53894bed76f0df590ba05ba4b92860405bccc6f8084399aeadfa`
snapshots and race-checks 272 retained artifacts totaling 10,899,033 bytes.
It independently audits the ordinary-work self-requeue, absence of the old
IRQ requeue handoff, deterministic IRQ-complete-before-worker-release case,
offline zero-control oracle, six corrected receipts, source identity, every
config/object, KTAP, receipt, seed, fault ledger, QEMU command, warning scan,
and scratch retirement.

- closure r1 result SHA-256:
  `0224be91981b36a74ba0d3389c7e5a357a76bf7329bfb19de74c206d0bb4a3a4`;
- closure r2 result SHA-256:
  `b2317a4d80a4b3cfbc5f1e7d140fe50d60b9f4b79d8fe18e214d49f04382e99b`;
- byte-identical normalized SHA-256:
  `f8e184c16c4fa5315532cb067d3b66dea3a21b277942d9728a2132384a3d4ba2`.

Focused closure tests accept the exact fixture and reject eight mutations:
combined result, source symlink, hard-IRQ observation, recovery self-requeue,
offline oracle, E4 config enablement, receipt, and artifact removal.

## Timing R7 Preflight Boundary

Timing runner SHA-256
`54e1ee16fdd55c57e306ecb582420455c6e088ac150c39b3f66c8432439a8a50`
binds both R7 source closures and both exact R6 KUnit-failure closures. The R6
partial result cannot be resumed, combined, or reclassified. The measurement
matrix remains exactly 682 cells and 6,820,000 paired samples under paused-QMP
two-vCPU singleton placement. Fixed thresholds, parser, warning classifier,
storage reserve, and per-progress capacity gates are unchanged.

Config-only smoke
`20260723T-p5a-r4-e4-arm64-timing-config-smoke-r10` resolves config SHA-256
`2cbf3e910322ee65f39074a551fd61a14cbe457608358e6a76608ae6d25cf07b`
with zero builds and boots, exact source/R6 closure copies, and complete scratch
retirement. Forced-capacity control
`20260723T-p5a-r4-e4-host-capacity-negative-r4` fails before build at the
artificial floor, seals result SHA-256
`3b2102412bff0371845c90d4e9ce589375ef8caef7c2cdda256a9a23071eec0c`,
releases the reserve, and retires both owned paths.

## Claim Boundary

A complete clean arm64 r7 result still requires an independent timing closure
before exact same-source x86_64 work. A valid fixed-threshold rejection stops
x86_64. Any harness failure receives no partial credit.

No real scheduler attachment, runtime denial, monitor delivery, bare-metal
latency, performance, cost, N-136 runtime charge, production protection,
deployment, multi-node, multi-cluster, or datacenter readiness is accepted.
