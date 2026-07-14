# Implementation 0043: SchedExecLease P5A-R2 E4 Disposable Lock-Hold Measurement

Date: 2026-07-14

Status: arm64 attempt 1 exposed a pre-measurement base-slice semantics error.
The exact two-file source is corrected and validation/0217 authorizes its
arm64 remeasurement only. No
measurement, latency, or production claim is accepted.

## Source Identity

```text
worktree: build/DomainLeaseLinux.volume/worktrees/p5a-r2-e4-lock-hold
branch:   codex/p5a-r2-e4-lock-hold
parent:   d1d5e78da8484c91eae70f22399c6901da680ea0
commit:   f6ad4e454778c52bcdaaecf684c148a3a8dae857
tree:     265e6357627490e51084979382ef34b2cfcc0cb8
diff sha: 3f52a2b2724bd795466ab1f344bf3d02fde7ee6a39bfde0945f7f8cf6ab8e3a3
delta:    362 additions, 0 deletions, exactly two files
```

The only changed files are `init/Kconfig` and `kernel/sched/fair.c`. The
primary Linux tree, patch queue, E2 fields and probe, E3 rebuild, scheduler
Makefile, and every live scheduler call path are unchanged.

## Default-Off Boundary

`CONFIG_SCHED_EXEC_LEASE_REBUILD_MEASURE_KUNIT_TEST` is a default-off bool
depending on the already validated E3 rebuild test and built-in KUnit. The E4
fixture, timing helper, statistics, output rows, case, and suite registration
remain in `fair.c` under this boundary. No ordinary lease configuration or
`KUNIT_ALL_TESTS` selects it.

## Fixed Measurement Shape

The fixture uses real `rq`, `cfs_rq`, `sched_entity`, rb-tree, bottom-up
cfs-rq iteration, IRQ disabling, and rq locking, but it is not registered with
a live scheduler runqueue. Every allocation and topology mutation happens
before sampling. The timed leaf callback is O(1) through `container_of` and
does not reuse the correctness fixture's linear lookup.

Each cell first performs an untimed rebuild and exact leaf-visit check. It then
collects at least 256 warm-up pairs and exactly 10,000 measured control/rebuild
pairs, alternating pair order. The interval is:

```text
local_irq_save
  start = local_clock
  raw_spin_rq_lock
    empty barrier OR exact E3 rebuild
  raw_spin_rq_unlock
  end = local_clock
local_irq_restore
```

Allocation, sorting, printing, sleeping, rescheduling, policy, monitoring,
and topology changes remain outside that interval. Additional cost is
`max(rebuild - control, 0)`.

The immutable matrix is seven queue sizes `{0,1,8,64,256,1024,4096}` by five
depths `{0,1,4,16,64}`, or 35 required result rows. Each control, rebuild, and
additional distribution reports minimum, p50, p95, p99, p999, and maximum.

## Base-Slice Semantics Correction

The fixed 700,000ns gate is the scheduler's normalized base-slice baseline,
`normalized_sysctl_sched_base_slice`. The live `sysctl_sched_base_slice` is
scaled by `1 + ilog2(num_online_cpus())` under the default logarithmic policy;
it is 1,400,000ns in the two-CPU QEMU guest. Runtime scaling is now recorded
separately with the scaling mode and online CPU count and may never relax the
25,000/50,000ns rejection thresholds or 700,000ns fixed basis.

The correction replaced the invalid runtime-value assertion without changing
the measured interval, fixture, matrix, sample counts, percentiles, warning
gate, or rejection classification. The amended commit remains a direct E3
child. Its correction-only diff from superseded source `dc3618e2bc56` changes
only `fair.c` (10 additions, 4 deletions), SHA-256
`22cb55c3a8a9841122820a467712c015ba761961676898160f941157fc3414ed`.

## Arm64 Attempt 1

Run `20260714T-p5a-r2-e4-arm64` built the full Image but failed before any
measurement row: the old source asserted the two-CPU runtime-scaled base slice
against 700,000ns. KUnit reported one failed case and zero `E4_RESULT` rows.
The run is preserved as `harness_failed`, not as threshold or design evidence.
Its result SHA-256 is
`12370a90745e94edd56a50ecf378c2bd7397d0dfd50805d579309b51bed4ee97`.

## Local Checks

Strict checkpatch passed with zero errors, warnings, and checks. An E4-enabled
arm64 `kernel/sched/fair.o` build passed without compiler warnings. The object
contains the E4 suite, cell, and timing symbols. `checkstack.pl` reports 384
bytes for the cell driver, 160 bytes for the matrix case, and 96 bytes for the
timed interval helper; the earlier 4,752-byte fixture frame was eliminated by
allocating the fixture before measurement.

Validation/0215 independently repeated the original identity, isolation, Kconfig,
matrix, measured-interval source-order, forbidden-operation, checkpatch,
enabled-object, symbol, and stack gates. Its result SHA-256 is
`e0895e883f50151b4d239165ad690e3a3a6587a591a0ee81665d33777d6d2b92`.
That gate is historical evidence for the superseded source and no longer
authorizes launch. Validation/0217 run
`20260714T-p5a-r2-e4-source-gate-r2` binds the corrected identity and
base-slice semantics, rebuilds the targeted arm64 object, and authorizes only
the corrected arm64 rerun. Its result SHA-256 is
`956007be42687193c9d3eeb29e5e0be80dcaeba16d22436c71e06a017a870adc`.

## Non-Claims

This source does not itself supply measurement evidence. It does not accept
the E2 layout for production, a full locked rebuild, bounded latency,
performance, live scheduler integration, runtime denial, protection, cost,
deployment, or datacenter readiness. A threshold breach must be preserved as
valid negative evidence and reject this full O(n) locked rebuild design.
