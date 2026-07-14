# Implementation 0043: SchedExecLease P5A-R2 E4 Disposable Lock-Hold Measurement

Date: 2026-07-14

Status: validation/0215 passed the exact two-file disposable source and
targeted arm64 compile. The exact arm64 measurement may now be launched; no
measurement, latency, or production claim is accepted yet.

## Source Identity

```text
worktree: build/DomainLeaseLinux.volume/worktrees/p5a-r2-e4-lock-hold
branch:   codex/p5a-r2-e4-lock-hold
parent:   d1d5e78da8484c91eae70f22399c6901da680ea0
commit:   dc3618e2bc56d3ede9b8d1378099c7b9ad15e08f
tree:     b8a7023993560bcc40077a5db25288c3fdf4765a
diff sha: 9d33d848b13f01e15d6ff6369c465964ca0682829eafbaa3906bbf17e3b18709
delta:    356 additions, 0 deletions, exactly two files
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

## Local Checks

Strict checkpatch passed with zero errors, warnings, and checks. An E4-enabled
arm64 `kernel/sched/fair.o` build passed without compiler warnings. The object
contains the E4 suite, cell, and timing symbols. `checkstack.pl` reports 384
bytes for the cell driver, 144 bytes for the matrix case, and 96 bytes for the
timed interval helper; the earlier 4,752-byte fixture frame was eliminated by
allocating the fixture before measurement.

Validation/0215 independently repeated the identity, isolation, Kconfig,
matrix, measured-interval source-order, forbidden-operation, checkpatch,
enabled-object, symbol, and stack gates. Its result SHA-256 is
`e0895e883f50151b4d239165ad690e3a3a6587a591a0ee81665d33777d6d2b92`.

## Non-Claims

This source does not itself supply measurement evidence. It does not accept
the E2 layout for production, a full locked rebuild, bounded latency,
performance, live scheduler integration, runtime denial, protection, cost,
deployment, or datacenter readiness. A threshold breach must be preserved as
valid negative evidence and reject this full O(n) locked rebuild design.
