# Implementation 0049: SchedExecLease P5A-R4 E4 Local-Quantum Measurement

Date: 2026-07-21

Status: arm64 timing attempt 2 is sealed as `harness_failed/qemu_boot`, not a
timing result. The guest emitted one row before the old name-based vCPU-thread
discovery could pin either thread. Two independent read-only failure closures
reproduce that decision. The corrected runner starts QEMU paused, obtains exact
vCPU index/TID mappings through QMP, pins and revalidates singleton affinity,
then resumes. Focused real-QEMU, negative-fixture, config, and cleanup tests
pass. Exact clean/pushed preflight then passed twice, and arm64 timing r3 is
running under detached 30-second monitoring. No timing result or broader
runtime/production claim is accepted.

## Source Identity

```text
branch:    codex/p5a-r4-e4-local-quantum-measurement
parent:    da9ce9159b3450c28c8faf8dceac671fb7bfeba2
commit:    5857720dedc49f89d2367442f8fdb1a806ffa1cc
tree:      ee6e329106327a302bf63c78f2ed4fe3ddea7865
diff sha:  d3f56505379bdb08b36e265424aa886fc4f79d2a5a1e9426c2e52c3db0912a93
files:     init/Kconfig, kernel/sched/exec_lease.c
line diff: +1744 -82
```

Linux Draft PR: `minto-dane/linux#4`, based on the exact R4-E3 branch.

## Implemented Boundary

`CONFIG_SCHED_EXEC_LEASE_R4_MEASURE_KUNIT_TEST` is default off, depends on the
R4-E3 KUnit suite and built-in KUnit, and registers
`sched_exec_lease_r4_measure` only in the existing private translation unit.
No Makefile, header, scheduler, CPUHP, ABI, primary-Linux, or patch-queue change
is present.

The suite implements the exact seven families and 682 cells:

```text
publication       288
picker/kick       144
hard-IRQ dispatch   9
recovery          144
notifier           48
current stop       24
offline/drain      25
```

Every cell uses 256 warmup pairs and 10,000 alternating treatment/control
pairs. Additional time is saturating subtraction; minimum, p50, p95, p99,
p99.9, and maximum use nearest rank. The source retains the fixed local,
offline-lock, asynchronous-availability, and 700,000ns rejection markers.
There is no all-rq fanout or last-settlement wall-clock gate.

Each complete cell executes under `migrate_disable()`, records its guest CPU,
and compares every control/treatment sample against that CPU. The hard-IRQ
callback records its own CPU, IRQ-disabled state, and preemption depth; the
other six families record the same state at their timing boundary. Every
result row emits the selected CPU, migration count, control/treatment IRQ and
preemption state, and state-error count. Any CPU change or state drift is a
harness error. The later timing runner must additionally record its QEMU/vCPU
placement command and environment.

The E3 worker paths and measurement paths share extracted dispatch,
publication, one-projection recovery, notifier, current-request, and offline
helpers. The 36 E3 case/oracle/receipt bodies remain byte-identical. Measurement
brackets, fixtures, and hard-IRQ timestamps remain inside the default-off test
block.

## Short Verification

```text
git diff --check:                       passed
strict checkpatch:                      0 errors, 0 warnings, 0 checks
arm64 fixed E4-enabled W=1 object:       passed, zero diagnostics
x86_64 fixed E4-enabled W=1 object:      passed, zero diagnostics
source-only corrected contract smoke:      passed, complete cleanup verified
source-only shared-hard-IRQ scope smoke:    passed, complete cleanup verified
```

The short checks are implementation feedback, not source acceptance. Attempt
1 produced six fresh objects and six clean diagnostic boots at 216/216 E3
cases and receipts, but receives no source or timing credit because the gate
was incomplete. The predecessor canonical runner reproduced the entire matrix
at commit `9e4cb44f...` and received an independent read-only closure before
attempt 1. That closure does not transfer to replacement `5857720d...`.

Attempt 2 started no object build or boot and emitted no result. The gate now
preserves `sched_exec_r4_dispatch_irq()` as a separate evidence artifact and
requires each hard-IRQ CPU/IRQ/preemption assignment exactly once in that
shared-helper region. Source-only run
`20260719T-p5a-r4-e4-source-gate-r3-hard-irq-scope` passes this corrected
boundary and retires its worktrees.

## Pre-fix Source and Regression Closure

Canonical combined run
`20260719T-p5a-r4-e4-source-e3-regression-r3` passed all six fresh
arm64/x86_64 source-object modes, all six standard/fault/KASAN/KCSAN E3
profiles, 216/216 cases, and 216/216 typed receipts with zero compiler, final
clock-skew, kernel-warning, case, timeout, QEMU, or network-device failure. Its
combined result SHA-256 is
`9896e12b2882ac88c7b4d57f53c59f7d245b5d3b78717df7d39097af64de8b72`.

Independent closures r1 and r2 snapshot all 267 retained artifacts read-only,
recompute exact object/profile/case/receipt and observability contracts, and
produce result SHA-256 values
`c1d9afa02f516e893e0dd0f910b7d1a60a56f2c1389b9426878545ef6a691325`
and
`9c19029ca7c18d44ec873374c9e85327a7a81d94221b1e10538f19cd16e8633e`.
After removing only `run_id`, both decisions are byte-identical at SHA-256
`ff91f2517b460b4d60322ea1670aab94058a8db4246bf2e2b63b7454250f528f`.
This accepted only predecessor commit `9e4cb44f...` and authorized attempt 1;
it does not transfer to replacement commit `5857720d...` or accept a
measurement result. The separate replacement closure below is authoritative
for timing r2.

## Arm64 Timing Attempt 1 Rejection and Repair

Detached run `20260719T-p5a-r4-e4-arm64-timing-r1` completed approximately
10,300 compiler/link steps, then the build diagnostic gate rejected
`kernel/sched/exec_lease.c:4373`: the notifier KUnit case used a 2,064-byte
stack frame, exceeding the 2,048-byte arm64 warning boundary. No QEMU boot or
measurement row started. The result is `harness_failed` at stage `build`, and
both run-owned build scratch and worktree were retired.

The repair moves only the 192-byte-axes measurement cell to KUnit-managed
memory; fixture lifetime, arrays, synchronization, sample order, thresholds,
and all 682 cells are unchanged. Strict checkpatch remains 0/0/0. Exact arm64
r1-config and x86_64 E4-on W=1 object builds emit zero diagnostics and retire
their scratch. The correction was squashed into a single exact direct child of
R4-E3, so the original source-plan topology remains intact. Fresh full source
and E3 evidence was nevertheless required and has now passed.

## Replacement Source and Regression Closure

Fresh detached run `20260719T-p5a-r4-e4-source-e3-regression-r4` exited zero
after six exact source objects and all six standard/fault/KASAN/KCSAN E3
profiles. It sealed 216/216 cases and 216/216 typed receipts with zero compiler
diagnostic, final clock-skew warning, kernel warning, case failure, skip,
timeout, or nonzero QEMU exit. Combined result SHA-256 is
`2b90c47e69c4c190029bc0fb2b25e66db68f87ec16f0a4d4034f4741caf5d7ea`.

The replacement closure fixes 267 regular artifacts totaling 10,880,574
bytes. Independent closure runs
`20260720T-p5a-r4-e4-source-e3-final-closure-r1` and
`20260720T-p5a-r4-e4-source-e3-final-closure-r2` produce result SHA-256 values
`5e3ff71d2fea01b29e20b23a9bb8e1a8479d70cc847fa49aa3d33295c8040f3f`
and
`bac2aca6649c40fdf21665a0f801be1f0751ef03c437d1b506f78ba77f04f720`.
Deleting only `run_id` yields byte-identical SHA-256
`767d2f9ab1bfb6e0c918c2ba0b51147ba79f236085e6985097b14e5a8da43d21`.
All 536 copied inputs are read-only; result, symlink, hard-IRQ observation,
config, receipt, and artifact-removal mutations fail closed.

## Arm64 Timing Attempt 2 QMP Rejection and Harness Repair

Detached run `20260720T-p5a-r4-e4-arm64-timing-r2` completed the full arm64
Image build and booted QEMU, but sealed `harness_failed` at `qemu_boot`. The
guest emitted exactly one result row at guest time 5.264269 seconds before the
runner could prove complete vCPU placement. The pin record contains only the
QEMU PID and parent CPU allowance; it contains no vCPU entry. No cell, gate,
threshold, performance, or x86_64 credit is accepted. Build/worktree scratch
was retired and the Image plus `exec_lease.o` remain losslessly archived.

The root cause is exact: QEMU 8.2.2 truncated every default Linux task name to
`qemu-system-aar`, while the runner searched for `CPU */TCG`. Diagnostic
`debug-threads=on` restores readable names, but the corrected contract does not
trust names. QEMU now starts with `-S` and a run-owned QMP socket. A hash-bound
Python helper requires paused status, obtains exactly indexes 0 and 1 with
distinct positive TIDs from `query-cpus-fast`, and rejects malformed,
duplicate, missing, or drifting mappings. The shell proves the TIDs belong to
the active QEMU, pins each to a distinct allowed host CPU, and reads back exact
singleton affinity. Immediately before `cont`, the helper re-queries the same
mapping and revalidates each `/proc` Tgid and affinity. Zero result rows are
allowed before resume.

Independent read-only closures
`20260721T-p5a-r4-e4-arm64-timing-r2-failure-closure-r1` and
`20260721T-p5a-r4-e4-arm64-timing-r2-failure-closure-r2` audit 68 copied inputs
and produce result SHA-256 values
`749777dbd6e9310538f76146650eca52d6c9d6c721645cb21c99cda196a0b705`
and
`83ec59df2275ab6d6b8c6a9fe2aed9ecb12156ae318b991a9fa1829d47b37e66`.
After removing only `run_id`, both decisions are byte-identical at SHA-256
`9c079b47fae1b7ae45baa6cd7517a9b02af2d6b3f4a9780f180366932e3178ef`.
Result mutation and symlink substitution fail closed.

## Arm64 Timing Harness

The timing runner creates the exact candidate worktree and build output only
on VM-internal ext4, builds one arm64 Image, losslessly preserves and
restore-verifies the Image and `exec_lease.o`, and boots network-disabled QEMU
TCG paused. QMP must return exactly two vCPU indexes and distinct Linux TIDs.
Each TID is singleton-pinned one-to-one to the Apple Container VM's two
distinct allowed host CPUs, and the same QMP mapping plus `/proc` affinity is
reverified before QMP resume. Any result row before resume, mapping/affinity
drift, guest migration, IRQ/preemption-state drift, malformed/missing/duplicate
cell, KUnit failure, compiler/skew/kernel diagnostic, missing artifact, or
cleanup failure is a harness failure. A valid fixed-threshold breach remains
complete negative architecture evidence and stops x86_64.

The independent parser requires exactly 682 unique cells, 6,820,000 recorded
pairs, seven exact summaries, monotonic statistics, source-reported gates equal
to independently recomputed gates, zero migration/state/harness errors, and
hard-IRQ context proof. Its synthetic suite accepts a complete clean matrix and
a valid threshold rejection, while rejecting missing rows, migration, gate
mismatch, unknown fields, and summary mismatch. The QMP helper's 15 negative
fixtures and a real stopped-QEMU integration test verify exact mapping,
singleton affinity, tamper rejection, and paused-to-running transition. Final
replacement config smoke r7 resolves the exact two-vCPU diagnostic
configuration with zero builds and boots, snapshots the corrected runner and
helper, and retires all scratch. A forced insufficient-space control fails
after worktree creation and proves both worktree and build-root retirement.

## Claim Boundary

This accepted-for-timing replacement source and runner measure only virtual
synthetic protocol quanta. They do not prove
live scheduler correctness, CPU hotplug integration, real stop/revocation,
monitor delivery, bare-metal latency, performance, cost, N-136 runtime charge,
production protection, deployment, multi-node, multi-cluster, or datacenter
readiness.
