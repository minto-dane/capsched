# Validation 0263: SchedExecLease P5A-R4 E4 Arm64 Timing R1 Build Rejection

Date: 2026-07-19

Status: timing attempt 1 is immutable harness-failed evidence. A real arm64
stack-frame warning was repaired without relaxing the compiler diagnostic
gate. The replacement direct-child source must pass a fresh combined source/E3
regression and independent double closure before another timing launch.

## Attempt 1 Evidence

```text
job:        p5a-r4-e4-arm64-timing-r1
run:        20260719T-p5a-r4-e4-arm64-timing-r1
source:     9e4cb44fd1a1f998fcc288df87dad60505e8bf18
result sha: cd39ae390f30f53823ee7898125d82d0f37a3cc670d235e09d52d0f418e51baf
build sha:  1d4ba9c743882f2ed0eddce1a63a8782ee8c7882faaa25efbc057bd85cc4e8eb
diag sha:   3d09028da7c49bf583a45f664a039a22ea246ed6aa65735df7d9bbdab8241227
```

The full arm64 Image build reached approximately 10,300 compiler/link steps.
GCC then emitted exactly one selected diagnostic:

```text
kernel/sched/exec_lease.c:4373:1: warning: the frame size of 2064 bytes is larger than 2048 bytes [-Wframe-larger-than=]
```

The runner correctly sealed `harness_failed`, stage `build`, before any QEMU
boot or timing row. Both run-owned VM-internal build scratch and candidate
worktree are absent after cleanup. The attempt authorizes no x86_64 run and no
measurement, runtime, performance, or production claim.

## Exact Repair

The 192-byte-axes `sched_exec_r4_measure_cell` in only the notifier measurement
case moves from the kernel stack to `kunit_kzalloc()` storage. The fixture,
sample arrays, setup/cleanup order, locks, refcounts, CPU pinning observations,
pair order, gates, and 682-cell manifest are unchanged. The correction is
squashed into the original feature commit so the plan-required topology stays
an exact direct child of `da9ce915...`:

```text
commit:       5857720dedc49f89d2367442f8fdb1a806ffa1cc
parent:       da9ce9159b3450c28c8faf8dceac671fb7bfeba2
tree:         ee6e329106327a302bf63c78f2ed4fe3ddea7865
two-file diff d3f56505379bdb08b36e265424aa886fc4f79d2a5a1e9426c2e52c3db0912a93
stack delta:  c1bc4008a522d8ec13b7b82d91fd18f5699e10ad3347119d7c860feeef2715d1
line boundary: +1744 -82
```

Strict checkpatch reports 0 errors, 0 warnings, and 0 checks. An exact r1 arm64
configuration W=1 object build and a separate x86_64 E4-on W=1 object build
both pass with zero compiler/skew diagnostics and retire all scratch.

## Re-authorization Boundary

Pre-fix attempt-3 regression and its double closure remain valid only for
`9e4cb44f...`; they cannot authorize the replacement identity. The next
permitted operation is fresh combined run
`20260719T-p5a-r4-e4-source-e3-regression-r4`, requiring all six source
objects, all six E3 profiles, 216/216 cases and receipts, zero diagnostics, and
complete cleanup. Two new independent read-only closures must then reproduce
one normalized decision before arm64 timing r2 can start.

Primary Linux and the patch queue remain unchanged. Live scheduler attachment,
N-136 runtime charge, bare-metal behavior, monitor delivery, production,
deployment, multi-node, multi-cluster, and datacenter claims remain false.
