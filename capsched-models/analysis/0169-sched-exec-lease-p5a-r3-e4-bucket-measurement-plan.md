# Analysis 0169: SchedExecLease P5A-R3 E4 Bucket Measurement Plan

Date: 2026-07-16

Status: pre-source rejection plan. It authorizes only an exact disposable,
default-off measurement draft after validation/0228 passes. It does not
authorize E4 measurement, scheduler behavior, or a latency/performance claim.

## Decision

Validation/0226 closes the corrected R3-E3 same-translation-unit concurrency
prototype on four independent diagnostic boots. That pass proves the synthetic
publication, work ownership, migration, hotplug, and retirement protocol only.
E4 asks three narrower engineering questions fixed by analysis/0167:

```text
Can one projection update remain inside the immutable rq-lock envelope?
Can the bounded B_max=64 hotplug drain remain inside its larger envelope?
Can targeted publication settle 1..64 active rqs inside its availability bound?
```

E4 is a rejection experiment. Any fixed-threshold breach is a complete valid
negative result and rejects promotion to E5. The harness may not lower sample
counts, drop a cell, relax a threshold, or report only passing cells.

## Immutable Predecessor and Source Scope

Only after this plan passes may the following disposable child be created:

```text
parent:    be9339363a99fb31a5b7d03f3d70430d64a45593
tree:      a92d096ef4779f20c5e652de3c21b8f85b2476c7
worktree:  build/DomainLeaseLinux.volume/worktrees/
             p5a-r3-e4-bucket-measurement
branch:    codex/p5a-r3-e4-bucket-measurement

allowed files:
  init/Kconfig
  kernel/sched/exec_lease.c
```

The E2 layout, 43 private layout probe values, E3 suite and 20 case families,
primary Linux, and patch queue are frozen. The E4 draft may extract the exact
one-projection state transition into a same-TU helper only if the E3 worker and
its unchanged suite use that same helper. A timing-only substitute is rejected.
No header, Makefile, `sched.h`, `fair.c`, `core.c`, primary-tree, or patch-queue
change is allowed.

## Configuration and Non-Attachment Boundary

Add exactly one default-off bool:

```text
CONFIG_SCHED_EXEC_LEASE_BUCKET_MEASURE_KUNIT_TEST
  depends on SCHED_EXEC_LEASE_BUCKET_KUNIT_TEST && KUNIT=y
```

The suite name is `sched_exec_lease_bucket_measure`. It stays in
`exec_lease.c`, is not selected by the lease option, layout probe, E3 test, or
`KUNIT_ALL_TESTS`, and adds no export, static key, object, ABI, tracepoint,
debugfs/proc/sysfs surface, or ordinary runtime caller.

Fixtures may use real private E2 bucket/projection/rq-state objects, a real
`struct rq` lock, actual rb-tree operations on synthetic outer entities, the
E3 dedicated workqueue protocol, and synthetic inner runnable state. They may
not register with a live runqueue, attach to a task or cgroup, call a live
picker/hotplug/migration seam, make a policy/monitor/denial decision, or modify
ordinary scheduler state.

## Common Measurement Method

All fixture storage, sample arrays, sort buffers, projections, entities,
workqueue items, and result rows are allocated and initialized before timing.
Each cell first performs an untimed structural/oracle check. Measured code has
no allocation/free, printing, assertion, sorting, tracing, sleep, reschedule,
topology mutation, policy/monitor call, or second rq lock.

Every lock-hold sample is paired with an empty control on the same prebuilt
fixture and CPU. Treatment/control order alternates. The raw interval is:

```text
local_irq_save
local_clock start
raw_spin_rq_lock
empty control OR the exact bounded operation
raw_spin_rq_unlock
local_clock end
local_irq_restore
```

Where the treatment requires one membership lock, the paired control takes
and releases the same lock with only a compiler barrier. The additional sample
is `max(treatment_ns - control_ns, 0)`; negative noise never wraps. All arrays
are sorted only after interrupts are restored. Statistics use documented
nearest-rank indices and include minimum, p50, p95, p99, p99.9, and maximum.
Every required cell has at least 256 warmup pairs and exactly 10,000 recorded
pairs.

## One-Projection Matrix

The 32 cells are the Cartesian product:

```text
outer bucket occupancy: 1, 8, 32, 64
inner runnable count:    0, 1, 64, 4096
generation outcome:      stable, raced
```

The fixture contains exactly one outer bucket layer. One treatment invocation
may acquire the target rq lock and at most one membership lock, acquire-read
the bucket generation/state, update at most one outer projection/entity, and
publish Fresh only after a stable final generation read. The raced outcome is
forced by a measurement-only generation transition whose control performs the
same injection; it must leave the projection Stale and request only that
projection's requeue. It may not scan an inner leaf, cfs-rq hierarchy, all
buckets, or any second projection. Inner runnable count may perturb cache
state but may not change the operation count.

Each cell is rejected when paired additional time has:

```text
p99   >  5,000 ns
p99.9 > 25,000 ns
max   > 50,000 ns
any sample >= normalized 700,000 ns base slice
```

## Hotplug Drain Matrix

The five occupancy cells are `0, 1, 8, 32, 64`. The treatment uses one real
rq lock and visits exactly the prebuilt projections on that rq, in a bounded
loop of at most `B_max`. It may take only one membership lock at a time and
must clear accepting before drain. Every residual queued, delayed, and current
contribution is accounted; a nonzero residual is retained Blocked, never
forgotten. No callback cancellation, workqueue drain, allocation, or RCU wait
occurs under the rq lock.

Paired additional hotplug drain is rejected when p99 exceeds 25,000 ns, max
exceeds 50,000 ns, or any sample reaches the 700,000 ns base slice.

## Targeted Fanout Matrix

The five cells use active-rq counts `1, 2, 8, 32, 64`. Each iteration starts
from a quiescent prebuilt fixture, publishes one generation under the bucket
membership lock, snapshots only `active_rqs`, obtains one existing work owner
per selected projection, releases the lock, queues the selected unbound work,
and measures publication-to-last-settlement. No all-online-rq scan or CPU-bound
work is allowed. A paired dispatch/completion control records workqueue and
clock overhead, but the gate applies to absolute publication-to-last-settlement
latency because stale projections fail closed before work arrives.

In a controlled idle guest, each fanout cell is rejected when p99 exceeds
10,000,000 ns or maximum exceeds 100,000,000 ns. This is an availability gate,
not a trust gate. A local generation mismatch already prevents Fresh trust.

## Build, Boot, and Diagnostic Evidence

The source gate must rebuild arm64 and x86_64 with E4 disabled and enabled,
prove complete E4 symbol/relocation/string absence while disabled, preserve all
E2/E3 manifests, re-run the unchanged E3 suite, and check the E4 source shape.
Measurement then boots the identical candidate on arm64 and x86_64 with KUnit,
lockdep, DEBUG_OBJECTS_WORK, and PROVE_RCU. Timing runs do not use KASAN/KCSAN;
the predecessor's sanitizer evidence remains bound to the unchanged E3 helper
and a separately required diagnostic boot must reject any helper drift.

Each environment records architecture, host/outer virtualization, QEMU
accelerator and CPU, vCPU count, compiler, config/image/object hashes, clock
source, frequency/governor availability, mitigations, complete console, KTAP,
and every machine-readable row. Virtual evidence is compatibility and
rejection evidence only; it cannot establish bare-metal latency, throughput,
energy, density, or cost.

Any lockdep, irqsoff, RCU-stall, workqueue, KASAN, KCSAN, WARNING, BUG,
soft-lockup, or hard-lockup report rejects the candidate. Missing cells,
insufficient samples, malformed statistics, clock regression, incomplete
warning evidence, build/boot/KUnit failure, or source identity drift is a
harness failure and produces no accepted E4 result.

## Classification and Claim Boundary

Each architecture produces exactly one classification:

```text
passed_r3_e4_architecture_measurement
rejected_r3_bucket_measurement
harness_failed (no accepted measurement evidence)
```

Full virtual E4 compatibility requires both architectures at the same source
identity. A threshold rejection stops E5. A two-architecture pass authorizes
only a separately gated R3-E5 evidence plan; it does not authorize E5 source.

E4 does not cover sched_ext, core forced-idle, proxy execution, deadline
servers, RT/DL, idle/stop/per-CPU kthreads, monitor delivery, real publisher
binding, live hotplug, cgroup/affinity movement, fairness, PELT, or production
workloads. E5 must integrate or explicitly exclude every cross-path before any
behavior candidate is reviewable.

Primary Linux, patch queue, production layout, live scheduler behavior,
runtime denial, monitor enforcement, protection, bounded bare-metal latency,
performance, cost, deployment, and datacenter readiness remain false.

## Next

Run validation/0228. Only a reproducible source/identity/JSON/formal pass may
create the exact disposable E4 draft. Measurement remains blocked on a later
source gate.
