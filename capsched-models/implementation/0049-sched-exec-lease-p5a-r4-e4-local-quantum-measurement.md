# Implementation 0049: SchedExecLease P5A-R4 E4 Local-Quantum Measurement

Date: 2026-07-19

Status: the exact disposable source is accepted only for the virtual synthetic
R4-E4 timing boundary. Corrected attempt 3 passed six fresh source objects and
six preserved E3 diagnostic profiles at 216/216 cases and receipts. Two
independent read-only closures reproduced one normalized decision. The arm64
timing runner, exact 682-row parser, parser tamper suite, config-only smoke, and
failure-cleanup control pass. Arm64 timing is launch-ready; no timing result or
broader runtime claim is accepted yet.

## Source Identity

```text
branch:    codex/p5a-r4-e4-local-quantum-measurement
parent:    da9ce9159b3450c28c8faf8dceac671fb7bfeba2
commit:    9e4cb44fd1a1f998fcc288df87dad60505e8bf18
tree:      e6feb28a29fc8c37bc46af0fbf37de30f3401a4f
diff sha:  bb115b371cd18551b93c09ae9b3d0cf458e70c9964927ff08d1bd3f586dd4cd2
files:     init/Kconfig, kernel/sched/exec_lease.c
line diff: +1743 -82
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
arm64 exact-corrected E4-enabled W=1 object: passed
x86_64 exact-corrected E4-enabled W=1 object: passed
source-only corrected contract smoke:      passed, complete cleanup verified
source-only shared-hard-IRQ scope smoke:    passed, complete cleanup verified
```

The short checks are implementation feedback, not source acceptance. Attempt
1 produced six fresh objects and six clean diagnostic boots at 216/216 E3
cases and receipts, but receives no source or timing credit because the gate
was incomplete. The corrected canonical runner must reproduce the entire
matrix at commit `9e4cb44f...`, then receive a new independent read-only
closure before timing.

Attempt 2 started no object build or boot and emitted no result. The gate now
preserves `sched_exec_r4_dispatch_irq()` as a separate evidence artifact and
requires each hard-IRQ CPU/IRQ/preemption assignment exactly once in that
shared-helper region. Source-only run
`20260719T-p5a-r4-e4-source-gate-r3-hard-irq-scope` passes this corrected
boundary and retires its worktrees.

## Corrected Source and Regression Closure

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
This accepts only the exact virtual synthetic source and authorizes arm64
timing; it does not accept a measurement result.

## Arm64 Timing Harness

The timing runner creates the exact candidate worktree and build output only
on VM-internal ext4, builds one arm64 Image, losslessly preserves and
restore-verifies the Image and `exec_lease.o`, boots network-disabled QEMU TCG,
and pins both guest-vCPU threads one-to-one to the Apple Container VM's two
allowed host CPUs. Any result row before complete pinning, guest migration,
IRQ/preemption-state drift, malformed/missing/duplicate cell, KUnit failure,
compiler/skew/kernel diagnostic, missing artifact, or cleanup failure is a
harness failure. A valid fixed-threshold breach remains complete negative
architecture evidence and stops x86_64.

The independent parser requires exactly 682 unique cells, 6,820,000 recorded
pairs, seven exact summaries, monotonic statistics, source-reported gates equal
to independently recomputed gates, zero migration/state/harness errors, and
hard-IRQ context proof. Its synthetic suite accepts a complete clean matrix and
a valid threshold rejection, while rejecting missing rows, migration, gate
mismatch, unknown fields, and summary mismatch. Final config smoke r5 resolves the
exact two-vCPU diagnostic configuration with zero builds and boots and retires
all scratch. A forced insufficient-space control fails after worktree creation
and proves both worktree and build-root retirement.

## Claim Boundary

This source and runner measure only virtual synthetic protocol quanta. They do not prove
live scheduler correctness, CPU hotplug integration, real stop/revocation,
monitor delivery, bare-metal latency, performance, cost, N-136 runtime charge,
production protection, deployment, multi-node, multi-cluster, or datacenter
readiness.
