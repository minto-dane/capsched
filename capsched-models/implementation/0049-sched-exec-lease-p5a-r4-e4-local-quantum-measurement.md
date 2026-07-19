# Implementation 0049: SchedExecLease P5A-R4 E4 Local-Quantum Measurement

Date: 2026-07-18

Status: exact disposable source is committed and pushed as a direct R4-E3
child. Strict style and short arm64/x86_64 W=1 object checks pass. The separate
source/object plus six-profile R4-E3 regression is prepared but not yet passed;
timing remains blocked.

## Source Identity

```text
branch:    codex/p5a-r4-e4-local-quantum-measurement
parent:    da9ce9159b3450c28c8faf8dceac671fb7bfeba2
commit:    1dac9953b1b5c326a27285b1f2a6e4fac9960a1d
tree:      7d7f14800c9696b131ef7363cd8fb4cdd33a05b7
diff sha:  f8aa2ea40ef4041d3c1fcf6d9503f814aecf2e16b384688af6d196fc70009393
files:     init/Kconfig, kernel/sched/exec_lease.c
line diff: +1663 -82
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

The E3 worker paths and measurement paths share extracted dispatch,
publication, one-projection recovery, notifier, current-request, and offline
helpers. The 36 E3 case/oracle/receipt bodies remain byte-identical. Measurement
brackets, fixtures, and hard-IRQ timestamps remain inside the default-off test
block.

## Short Verification

```text
git diff --check:                       passed
strict checkpatch:                      0 errors, 0 warnings, 0 checks
arm64 E4-enabled W=1 object:            passed
x86_64 E4-enabled W=1 object:           passed
arm64 E4-disabled W=1 object:           passed
source-only independent gate smoke r4: passed, cleanup verified
```

The short checks are implementation feedback, not source acceptance. The
canonical combined runner must still produce six fresh source objects and six
fresh diagnostic builds/boots at 216/216 E3 cases and receipts with zero
diagnostic, then receive an independent read-only closure before timing.

## Claim Boundary

This source measures only virtual synthetic protocol quanta. It does not prove
live scheduler correctness, CPU hotplug integration, real stop/revocation,
monitor delivery, bare-metal latency, performance, cost, N-136 runtime charge,
production protection, deployment, multi-node, multi-cluster, or datacenter
readiness.
