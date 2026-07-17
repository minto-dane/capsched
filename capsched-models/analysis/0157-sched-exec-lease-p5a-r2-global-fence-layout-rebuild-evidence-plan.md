# Analysis 0157: SchedExecLease P5A-R2 Global-Fence Layout and Rebuild Evidence Plan

Date: 2026-07-13

Status: implementation-evidence plan. No Linux patch, hot field, rebuild
prototype, runtime behavior, or performance claim is approved.

## Purpose

Analysis/0156 selected a conservative global projection generation and
all-online-rq rebuild as the first complete shared-invalidation safety shape.
That shape is not yet implementable: it adds state to hot scheduler objects
and can perform O(n) work while holding `rq->lock` with interrupts disabled.

This plan fixes the exact evidence gates that must reject an oversized layout
or excessive lock hold before a behavior patch is drafted.

## Existing Baselines

Validation/0198 records the x86_64 layout baseline:

```text
sched_entity: 320 bytes
cfs_rq: 384 bytes
rq: 3392 bytes
task_struct: 3328 bytes
task_struct.sched_exec: offset 1424, size 40
```

The recreated arm64 build `20260713T140445Z` passed the explicit 0013 probe.
Its raw probe symbols mechanically encode:

```text
sched_entity: 320 bytes
cfs_rq: 384 bytes
rq: 3520 bytes
task_struct: 4160 bytes
task_struct.sched_exec: offset 1232, size 40
```

The architectures must be compared against their own baselines. Cross-
architecture byte equality is neither expected nor evidence.

The current source also exposes two useful rebuild primitives:

```text
rbtree_postorder_for_each_entry_safe(): child-before-parent rb traversal
for_each_leaf_cfs_rq_safe(): cfs_rq hierarchy list maintained bottom-up
```

Neither is currently a SchedExecLease rebuild implementation. A future
prototype must prove that its traversal covers every contributing tree,
separate current entity, and group projection exactly once.

## Candidate Representation Envelope

The names and placement remain provisional. A disposable no-behavior layout
candidate may model at most:

```text
struct sched_entity:
  one u64 wrap-aware minimum
  one validity bit/byte using the existing explicit flag-area hole

struct cfs_rq:
  no new field in the global-fence baseline

struct rq:
  one u64 built generation
  semantic state and pending flags
  at most one scheduler-internal callback record if proven necessary

global/private state:
  one published generation plus serialization state

struct task_struct:
  no additional field beyond the existing sched_exec shadow
```

Logical validity and numeric minimum remain inseparable even if layout places
the byte in an existing hole. The rq lock is the synchronization boundary; a
spare bit must not be stolen from an unrelated field.

Hard layout envelope, checked separately on x86_64 and arm64:

```text
sizeof(sched_entity) delta: 0..8 bytes
sizeof(cfs_rq) delta: exactly 0
sizeof(rq) delta: 0..32 bytes
sizeof(task_struct) delta: exactly 0

unchanged offsets:
  sched_entity.run_node
  sched_entity.min_vruntime
  rq.nr_running
  rq.curr
  rq.cfs
  rq.clock_task
  task_struct.sched_exec
```

The candidate rq fields must be placed after existing dedicated hot regions;
they may not shift the first hot cacheline or `rq.cfs`. If compiler layout,
configuration, or architecture causes any limit to be exceeded, the candidate
is rejected rather than justified after the fact.

## Evidence Stages

No patch number is reserved by this plan.

### E1: Expanded Build-Only Probe

Extend build-only measurement, without runtime call sites, to record:

```text
sched_entity flag-area fields, exec_start, and avg offsets
candidate summary field offset/size when present
rq.clock_task and candidate generation/state/callback offsets
cfs_rq unchanged baseline
task_struct.sched_exec unchanged baseline
cacheline index for every observed hot field
```

Probe symbols stay object-local and default-off. They create no exported,
userspace, trace, sysfs, proc, debugfs, policy, or monitor ABI.

### E2: Disposable Layout-Only Candidate

On a disposable branch, add provisional CONFIG-gated fields without picker,
update, publication, fanout, or rebuild call sites. Build and compare:

```text
CONFIG_SCHED_EXEC_LEASE=n
CONFIG_SCHED_EXEC_LEASE=y, selector/fence disabled
CONFIG_SCHED_EXEC_LEASE=y, layout probe enabled
```

This is measurement material, not an accepted patch. A failed envelope removes
the candidate.

### E3: Test-Only Rebuild Prototype

Only after E1/E2 pass may a default-off, scheduler-internal test configuration
prototype the rebuild. It must not expose a new production ABI or be selected
by ordinary `CONFIG_SCHED_EXEC_LEASE`.

Correctness is checked against a brute-force oracle for:

```text
empty and singleton trees
mixed Fresh/invalid leaves
vruntime values near wrap boundaries
tree-only, curr-only, and tree-plus-curr queues
nested group entities and throttled children
enqueue, dequeue, current, cgroup, affinity, and migration changes
publication before fanout
publication racing rebuild
rapid repeated generation bumps
generation saturation
```

Every complete aggregate must match the oracle's validity plus wrap-aware
minimum. A partial or raced traversal must remain Stale/Blocked.

Postorder rb traversal and bottom-up cfs_rq ordering must be source-proved.
Unbounded recursive group traversal is rejected unless a separate maximum
depth and kernel-stack proof exists. No allocation, sleep, monitor call, policy
lookup, exported helper, or tree mutation is allowed while rebuilding.

### E4: Live Lock-Hold Measurement

A default-off in-tree test module or equivalent non-production harness may
trigger rebuild on controlled runqueues. Existing tracing facilities measure
the live locked interval; the candidate does not add a tracing ABI.

Required queue sizes:

```text
0, 1, 8, 64, 256, 1024, 4096 runnable entities per rq
```

Required hierarchy depths or nearest constructible equivalents:

```text
0, 1, 4, 16, 64
```

Required distributions:

```text
minimum 10,000 samples where practical
median, p95, p99, p99.9, raw maximum
empty-handler/control cost
additional rebuild cost after subtracting the control
```

Record CPU model, architecture, frequency/governor, virtualization mode,
kernel config, compiler, mitigations, runnable count, hierarchy depth, and
generation-race rate. Run on both Apple Container arm64 for compatibility and
an x86_64 environment comparable to the prior baseline. Virtualized results
cannot alone support a bare-metal latency claim.

## Explicit Lock-Hold Gate

The current base slice is 700,000 ns. For every required queue-size/depth
combination, the full locked rebuild is reviewable only if:

```text
p99 additional irq-disabled rq-lock hold
  <= min(25 microseconds, base_slice / 20)

raw maximum additional irq-disabled rq-lock hold
  <= min(50 microseconds, base_slice / 10)

and:
  no sample reaches one base slice
  no lockdep, irqsoff, RCU stall, soft-lockup, or hard-lockup warning
```

At the current 700 microsecond base slice the limits are 25 microseconds p99
and 50 microseconds raw maximum. These are rejection limits for this specific
full-rebuild baseline, not performance claims.

Failure at any required size/depth rejects full O(n) rebuild as a behavior
candidate. The project must then model chunked rebuild, bucket-local summary,
or proven targeted fanout. Reducing the test range after a failure is not an
acceptable fix unless the deployment has an enforced runnable/hierarchy bound
with separate evidence.

## Build and Disassembly Gates

Controlled same-path builds must record sizes, hashes, sections, relocations,
and function-size/disassembly tables for:

```text
fair.o
core.o
exec_lease.o
vmlinux

min_vruntime_update
__enqueue_entity
__dequeue_entity
pick_eevdf
pick_next_entity
__pick_task_fair
set_next_entity
put_prev_entity
update_curr
future summary rebuild/publication helpers
```

Hard source/object rules:

```text
CONFIG=n:
  candidate fields/symbols/branches absent; same-path hot objects require an
  explained zero semantic delta

CONFIG=y, fence disabled:
  no generation load or rebuild execution in the ordinary picker path

fence enabled:
  one O(1) generation trust check at the selection boundary, not per rb node
  no picker scan, rebuild, allocation, sleep, monitor call, or policy lookup

rebuild path:
  O(n) only outside the picker and only while explicit semantic state is
  Refreshing; no partial Fresh publication
```

Object byte identity is asserted only for controlled builds with normalized
paths and metadata. Otherwise section, symbol, relocation, and reviewed
disassembly evidence is used.

## Runtime and Workload Evidence

Passing layout and lock-hold gates still does not prove scheduling behavior.
Any later behavior candidate separately requires:

```text
negative stale-generation execution tests
fanout-delayed mismatch tests
rebuild-race tests
ordinary CONFIG off/on compatibility
cross-path settlement/exclusion
QEMU boot/workload coverage
stress with fork/exec/exit, affinity, cpuset, migration, and cgroup movement
security diff review
final overclaim review
```

Any latency, throughput, energy, density, or cost claim additionally requires
representative workload benchmarks against the exact baseline and confidence
intervals. The lock-hold rejection gate is necessary but not sufficient.

## Non-Claims

This plan does not approve:

```text
Linux code changes
new hot scheduler fields
layout-only or rebuild test patch
full O(n) rebuild as production design
runtime behavior or denial correctness
cross-path correctness
runtime coverage
monitor delivery or enforcement
production protection
latency, performance, energy, or cost efficiency
deployment readiness
datacenter readiness
```

## Next

First extract and record the structured arm64 0013 layout table from the
already completed probe build. Then define the expanded build-only probe patch
plan; do not add candidate fields or rebuild code yet.
