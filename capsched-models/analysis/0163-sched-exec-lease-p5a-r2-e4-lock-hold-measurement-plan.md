# Analysis 0163: SchedExecLease P5A-R2 E4 Lock-Hold Measurement Plan

Date: 2026-07-14

Status: pre-source gate for an exact disposable, default-off measurement
descendant. No E4 source or measurement claim is approved by this document.

## Decision

Validation/0213 accepts the E3 full rebuild only as synthetic-fixture
correctness evidence. E4 must now answer the separate question: can that exact
clear-then-rebuild shape fit inside the fixed irq-disabled rq-lock rejection
envelope over the complete required size/depth matrix?

E4 is a rejection experiment, not a performance demonstration. A threshold
breach is a valid completed result and rejects the full O(n) locked rebuild.
The harness must not lower sample counts, remove large cells, change the
thresholds, or report only successful cells after observing a failure.

## Exact Source Boundary

Only after this plan passes may E4 be created as a new direct descendant:

```text
parent:    d1d5e78da8484c91eae70f22399c6901da680ea0
worktree:  build/DomainLeaseLinux.volume/worktrees/p5a-r2-e4-lock-hold
branch:    codex/p5a-r2-e4-lock-hold

allowed files:
  init/Kconfig
  kernel/sched/fair.c
```

The E2 four fields, E3 rebuild helper/oracle/correctness suite, primary Linux
commit `5e1ca3037e34823d1ba0cdd1dc04161fac170280`, and patch queue 0014 are
frozen. E4 is disposable evidence and is not the future 0015 patch.

## Configuration and Suite Boundary

Add exactly one default-off bool:

```text
CONFIG_SCHED_EXEC_LEASE_REBUILD_MEASURE_KUNIT_TEST
  depends on SCHED_EXEC_LEASE_REBUILD_KUNIT_TEST && KUNIT=y
```

The measurement suite is `sched_exec_lease_rebuild_measure`, remains in
`fair.c`, is not selected by ordinary lease or KUNIT_ALL_TESTS, and adds no
object, export, ABI, tracepoint, debugfs, sysfs, procfs, or runtime call site.
It reuses the exact E3 rebuild helper; it must not introduce an optimized or
weakened second implementation.

## Controlled Fixture

The harness uses real kernel `rq`, `cfs_rq`, `sched_entity`, rb-tree, bottom-up
leaf-list, rq-lock, irq-disable, and rebuild code, but the queue topology is
synthetic and never registered with the live scheduler. This is kernel-live
lock execution on controlled synthetic fixtures, not proof about concurrent
production runqueues.

All leaves, groups, sample arrays, and result rows are allocated and initialized
before entering any measured interval. A measurement leaf embeds its
`sched_entity`, allowing the callback to recover immutable validity/vruntime in
O(1) with `container_of`. The linear-search E3 correctness callback is forbidden
from E4 timing because it would turn the experiment into O(n^2).

For depth `d`, construct exactly `d` group levels in the actual child-before-
parent cfs_rq list. Runnable count `n` means exactly `n` task leaves at the
deepest queue (or root at depth zero); group entities are recorded separately.
Every cell performs one untimed correctness/visit-count check before warmup.

## Measured Interval and Control

Each pair uses the same prebuilt fixture and CPU. The measured raw interval is:

```text
local_irq_save
local_clock start
raw_spin_rq_lock
empty compiler barrier OR exact E3 full rebuild
raw_spin_rq_unlock
local_clock end
local_irq_restore
```

Thus raw samples include the irq-disabled lock acquisition/body/release
interval plus identical clock boundaries. Rebuild and empty-control order
alternates each iteration. The paired additional sample is
`max(rebuild_ns - control_ns, 0)`; negative clock/noise differences are not
wrapped or converted into large unsigned values.

No allocation/free, sorting, percentile calculation, KUnit assertion,
printing, tracing emission, sleep, reschedule, policy/monitor call, topology
mutation, extra task/rq lock, or generation publication occurs inside the
measured interval. Sorting and output occur only after interrupts are restored.

## Matrix and Sampling

Every architecture run must contain all 35 cells:

```text
runnable entities: 0, 1, 8, 64, 256, 1024, 4096
hierarchy depths:  0, 1, 4, 16, 64
warmup pairs:      at least 256 per cell
measured pairs:    exactly 10,000 per cell
generation races: 0 during timing, recorded explicitly
```

For raw control, raw rebuild, and paired additional arrays, record sample
count, minimum, median, p95, p99, p99.9, and maximum. Percentile indices use a
documented nearest-rank rule over independently sorted arrays. Emit exactly one
machine-readable `E4_RESULT` row per cell and a 35-row table from the runner.

## Fixed Rejection Gate

The measured base slice is recorded from the same kernel and must equal the
current 700,000 ns baseline. For every cell:

```text
paired additional p99 <= 25,000 ns
paired additional max <= 50,000 ns
paired additional max < 700,000 ns
zero lockdep, irqsoff, RCU-stall, soft-lockup, or hard-lockup warnings
```

Any breach produces a complete `rejected_full_locked_rebuild` result, names
every failed cell and reason, and sets all E4/performance approval flags false.
It is not a harness failure. Missing cells, fewer samples, malformed statistics,
KUnit failure, build/boot failure, clock regression, corruption, or unavailable
warning evidence are harness failures and produce no accepted measurement.

## Architecture and Environment Split

E4A runs arm64 under the available Apple Container/QEMU path and records the
host machine, outer virtualization, QEMU accelerator/CPU, guest architecture,
compiler, config and Image hashes, CPU count, frequency/governor availability,
mitigations, clock source, and warning configuration. Nested TCG evidence is
compatibility/calibration evidence and cannot support a bare-metal claim.

E4B must run the identical E4 source identity and matrix in an x86_64
environment comparable to the prior x86_64 evidence. Full E4 acceptance
requires both architecture records. A virtualized pass cannot create a
bare-metal latency, performance, energy, density, or cost claim.

## Evidence Classification

The KUnit case checks harness integrity and emits measurements; it does not
fail merely because the fixed latency gate rejects the design. The external
runner validates all rows and classifies exactly one of:

```text
passed_e4_architecture_measurement
rejected_full_locked_rebuild
harness_failed (no accepted E4 evidence)
```

A pass on arm64 alone permits only the separately gated x86_64 run. A rejection
requires the next design to model chunked rebuild, bucket-local summary, or a
proven targeted fanout before new behavior source.

## Non-Claims

Even a two-architecture E4 gate pass does not approve the four fields for
production, real generation publication/fanout, picker integration,
incremental update closure, runtime denial correctness, monitor enforcement,
production protection, representative workload latency/throughput/energy/cost,
deployment, or datacenter readiness.

## Next

Run validation/0214. Only if its source/formal plan gate passes may the exact
E4 two-file disposable descendant be created.
