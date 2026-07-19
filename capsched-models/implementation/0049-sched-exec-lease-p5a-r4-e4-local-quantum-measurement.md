# Implementation 0049: SchedExecLease P5A-R4 E4 Local-Quantum Measurement

Date: 2026-07-19

Status: corrected exact disposable source is committed and pushed as a direct
R4-E3 child. Strict style, source-only contract, and short arm64/x86_64 W=1
object checks pass. Attempt 1 completed the build/regression matrix but is
rejected by validation/0259 because its source gate omitted plan-required
CPU-migration and IRQ/preemption observability. Attempt 2 then failed before
build because its corrected gate searched the E4-only extract for observations
located in a shared helper. Validation/0261 corrects that validator scope and
authorizes only a fresh attempt 3. A complete corrected retry and independent
closure remain required; timing is blocked.

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
boundary and retires its worktrees. Only fresh combined attempt 3 may proceed.

## Claim Boundary

This source measures only virtual synthetic protocol quanta. It does not prove
live scheduler correctness, CPU hotplug integration, real stop/revocation,
monitor delivery, bare-metal latency, performance, cost, N-136 runtime charge,
production protection, deployment, multi-node, multi-cluster, or datacenter
readiness.
