# Analysis 0183: SchedExecLease P5A-R6 E4 Local-Quantum Measurement Plan

Date: 2026-07-27

Status: source-free pre-source rejection plan. Passing this plan gate may
authorize only an exact disposable, default-off, same-translation-unit R6-E4
measurement source draft. It does not authorize a measurement launch, live
scheduler attachment, R6 behavior source, or latency/performance claim.

## Decision

The post-E3 authorization gate accepts the exact R6-E3 candidate and its
four-profile virtual synthetic correctness evidence. It permits this
source-free plan and nothing broader.

R6-E4 asks whether the additional local work proposed by the sealed masked
domain forest stays inside fixed rejection envelopes. It does not ask whether
global settlement is fast and does not convert a virtual timing result into a
budget, deadline, service-level objective, or bare-metal claim.

The nine required measurement families are:

```text
constant-work sealed descriptor publication
one leaf plus six fixed ancestors
127-node masked aggregate phase
127-node masked candidate phase
254-node complete top query
64-slot allowed-mask reconciliation
selected-slot handoff plus final task-local authority check
revoked-current request plus later distinct observation
offline visibility removal plus sleepable drain
```

A completed threshold breach is valid negative evidence and stops R6. Missing,
reduced, malformed, mutated, or warning-bearing evidence is a harness failure
and receives no timing classification.

## Immutable Inputs and Threat Boundary

The plan binds:

- repository threat model
  `262f609a04b1da7b87562b48e42e9674e91151ed8ccdaaef3bc88596795e997d`;
- post-E3 authorization results
  `7fe89e294603a5fc1b33b03d55087b8f0619db862d5a24ec5f0fa3b201119fb6`
  and
  `d8b420d729ae75243328eae183210b410daf812780cfd420a7b0f43a0f481c4b`;
- their normalized result
  `4104da3da3ad8f76b160d45f3ffe371aa70d2c2c0d06663194989d77999e3920`;
- the R6-E3 plan, implementation record, source gate, four-profile result,
  profile manifest, and two independent closure results; and
- the exact global claim-ledger row and separate runtime-charge boundary.

The threat model separates private synthetic scheduler evidence from runtime
Linux, monitor/hardware, async/service, MemoryView/TLB, DMA/IOMMU, and cluster
boundaries. Nothing measured here crosses those boundaries. The monitor is
not implemented.

## Refreshed Upstream and Source Boundary

The upstream observation advanced 108 commits from
`3dab139d4795f688e4f243e40c7474df00d329d9` to Linux 7.2-rc5 commit
`f5098b6bae761e346ebcd9da7f95622c04733cff`. Neither candidate path changed
during that interval. The previously classified unrelated `init/Kconfig`
drift remains outside the private `SCHED_EXEC_LEASE` block.

The candidate merge base remains
`4edcdefd4083ae04b1a5656f4be6cd83ae919ef4`. The clean merge tree is
`2c227949b04877f404dd8beff0012fdcf05c39b2`. The candidate and merged private
Kconfig blocks are byte-identical, and `kernel/sched/exec_lease.c` remains
absent upstream.

This is exact touched-path freshness only, not global upstream freshness.

After the plan gate passes, only this direct child may be drafted:

```text
parent:   99287291f1c8e0d6c1b3ea86d121508c5547f424
branch:   codex/p5a-r6-e4-local-quantum-measurement
worktree: build/DomainLeaseLinux.volume/worktrees/
            p5a-r6-e4-local-quantum-measurement

allowed files:
  init/Kconfig
  kernel/sched/exec_lease.c
```

All E2 layout values, E3 helpers, 55 correctness cases, independent oracle,
receipts, four diagnostic profiles, and 4,096 stress repetitions remain
frozen. A measurement source may add timestamp/result storage and measurement
shells only. It may not substitute cheaper implementations. If a helper must
be extracted, both E3 and E4 must call the same helper and the full E3 source
gate and four-profile matrix must pass again before timing.

Primary Linux and the patch queue remain unchanged.

## Configuration and Non-Attachment Boundary

The only future configuration is:

```text
CONFIG_SCHED_EXEC_LEASE_R6_MEASURE_KUNIT_TEST
  bool
  default n
  depends on SCHED_EXEC_LEASE_R6_KUNIT_TEST && KUNIT=y
```

The suite is `sched_exec_lease_r6_measure` in
`kernel/sched/exec_lease.c`. It is not selected by ordinary lease support,
layout probes, the E3 test, or `KUNIT_ALL_TESTS`. With it disabled there must
be zero E4 symbols, relocations, strings, initcalls, timestamp writes, raw
rows, or result rows.

E4 adds no public header, export, static key, live caller, scheduler hook,
CPUHP registration, tracepoint, debugfs/proc/sysfs/securityfs file, netlink
family, device, userspace ABI, monitor call, policy decision, admission, or
denial path. Fixtures remain private synthetic shells. No live `rq`,
`cfs_rq`, task, task group, or cgroup is attached.

## Common Measurement Contract

All fixtures, descriptors, trees, masks, tasks, cache ballast, control
states, sample arrays, sort buffers, and result rows are allocated and
initialized before timing. Each cell first passes an untimed oracle and exact
operation-count check. Treatment and control return to an identical quiescent
state after every pair.

Local samples use `local_clock()` on one pinned vCPU. The treatment and its
paired empty control execute with identical local IRQ state, raw-lock shell,
timestamp stores, compiler barriers, and pair order. Treatment/control order
alternates. The additional sample is:

```text
max(treatment_ns - control_ns, 0)
```

Negative clock noise never wraps. Allocation, free, sorting, statistics,
printing, KUnit assertions, tracing, sleeping, rescheduling, topology change,
RCU waiting, cancellation, and monitor/policy work are outside local measured
intervals.

Every cell has at least 256 warmup pairs and exactly 10,000 recorded pairs.
Treatment, control, and additional arrays independently report minimum, p50,
p95, p99, p99.9, and maximum using documented nearest-rank selection. A
clock regression, vCPU migration, missing pair, operation-count mismatch, or
warning is a harness failure.

Exact raw triples are retained. The host may convert them to a deterministic
binary stream and compress it only after hashing and independent closure.
Compression may not replace, round, aggregate, or discard raw evidence.
Build outputs are retired sequentially only after their source identities and
required evidence are sealed.

## Fixed Rejection Envelopes

Publication, leaf update, aggregate, candidate, complete query, reconciliation,
selected-slot handoff/final check, and current-stop request must satisfy in
every cell:

```text
paired additional p99   <=  5,000 ns
paired additional p99.9 <= 25,000 ns
paired additional max   <= 50,000 ns
every additional sample < 700,000 ns
```

Offline visibility removal uses:

```text
paired additional p99   <= 25,000 ns
paired additional p99.9 <= 40,000 ns
paired additional max   <= 50,000 ns
every additional sample < 700,000 ns
```

Later current observation and sleepable offline drain are availability
calibrations only:

```text
p99 <= 10,000,000 ns
max <= 100,000,000 ns
```

The normalized 700,000ns CFS base slice is a rejection marker, never an R6
runtime budget, deadline, monitor timer, or production SLO.

## Exact 855-Cell Matrix

### Descriptor publication: 135 cells

```text
active slots:         0, 1, 8, 32, 64
allowed-mask pattern: empty, singleton-low, singleton-high,
                      sparse-quartile, alternating-even, alternating-odd,
                      contiguous-low-32, contiguous-high-32, all-64
prior publication burst: 1, 64, 4096
```

The interval publishes one already sealed immutable descriptor and fixed O(1)
control fields. It performs no slot, task, tree, cgroup, rq, history, ref
drain, grace-period, allocation, or retry walk. Burst and occupancy may
perturb cache state but may not change operation count.

### Leaf plus six ancestors: 80 cells

```text
active slots:    1, 8, 32, 64
slot position:   0, 1, 31, 62, 63
transition:      runnable-on, runnable-off, deadline-advance,
                 current-settlement
```

The interval recomputes one leaf and exactly six fixed ancestors under one
synthetic rq raw lock. It cannot visit a sibling branch, reconcile the
allowed mask, allocate, publish authority, or scan inner tasks.

### Aggregate phase: 45 cells

```text
active slots:         0, 1, 8, 32, 64
allowed-mask pattern: the same nine patterns
```

The existing E3 aggregate helper is timed unchanged. It visits at most 127
unique fixed tree nodes and never enters a slot-local task queue.

### Candidate phase: 180 cells

```text
active slots:         0, 1, 8, 32, 64
allowed-mask pattern: the same nine patterns
current slot:         none, 0, 31, 63
```

The existing E3 candidate helper is timed unchanged. It visits at most 127
unique fixed tree nodes, uses stable slot-id tie breaking, and never returns a
denied or ineligible slot.

### Complete top query: 45 cells

```text
active slots:         0, 1, 8, 32, 64
allowed-mask pattern: the same nine patterns
```

The interval invokes the unchanged aggregate and candidate helpers once each.
The combined bound is 254 visits. It is not a logarithmic arbitrary-mask
claim.

### Allowed-mask reconciliation: 120 cells

```text
newly allowed bits:   0, 1, 8, 32, 63, 64
active slots:         0, 1, 8, 32, 64
placement pattern:    low, high, alternating, deterministic-scattered
```

Reconciliation visits exactly 64 slots under one raw lock. Only newly allowed
slots may be clamped to current virtual time and update their fixed
leaf-to-root path. There is no task, cgroup, arbitrary rq, or history scan.

### Selected-slot handoff and final task check: 96 cells

```text
inner task count:          1, 8, 64, 4096
descendant cgroup depth:   0, 1, 4, 8
final check outcome:       valid, generation-mismatch, domain-mismatch,
                           slot-mismatch, mask-denied, cpu-denied
```

Ordinary Linux EEVDF selection is unchanged baseline work and is outside the
R6 additional interval. E4 must not claim to measure or improve
`pick_eevdf()`. The measured addition begins with an already selected
slot-local candidate and ends after the exact descriptor, generation, domain,
slot, root, mask, CPU, online, and accepting check. Inner count and cgroup
depth perturb state/cache but cannot change authorization-check work count.

### Revoked current request and observation: 54 cells

```text
current slot:          0, 31, 63
observation outcome:   current-changed, same-current-revalidated
publication burst:     1, 64, 4096
allowed-mask class:    singleton, alternating, all-64
```

The local interval measures request issue under one synthetic rq lock. A
separate timestamp records the later distinct observation. Request and
observation sequence numbers must be strictly ordered and one-to-one.
`resched_curr()` or a sequence increment is not a monitor interrupt,
completion receipt, revocation guarantee, or wall-clock bound.

### Offline visibility and drain: 100 cells

```text
active slots:     0, 1, 8, 32, 64
current slot:     none, 0, 31, 63
ownership state:  empty, reader, task-ref, current, all
```

The locked interval first clears accepting and visibility. It performs no
sleepable wait. Drain, RCU unpublish, grace period, and free occur later
outside scheduler locks. Every terminal cell requires zero contributions,
readers, refs, transitions, and current ownership before free.

## Execution and Diagnostic Order

The future source gate must prove:

1. exact direct-child/two-file scope and strict checkpatch;
2. disabled E4 zero artifacts;
3. enabled/off/release builds on arm64 and x86_64 with no compiler diagnostic;
4. unchanged E2 values and E3 source identity/semantics;
5. the complete E3 four-profile matrix after any shared-helper refactor; and
6. exact 855-cell, 8,550,000-pair parser self-tests before measurement.

Timing runs arm64 first. A complete arm64 threshold rejection stops R6 and
x86_64. Only a passed arm64 run may authorize the exact same source identity
on x86_64. Sanitizers and lockdep run as separate diagnostics, not inside
timing runs.

Both architectures must record compiler, config, object, Image, QEMU command,
console, KTAP, raw rows, environment, clock, vCPU pinning/migration,
interrupt/preemption state, warning classification, and exact source
identity. Two independent immutable closures are required before any
post-E4 review.

## Classification and Claim Boundary

Valid completed classifications are:

```text
passed_virtual_r6_e4_local_quantum_compatibility
rejected_r6_e4_local_quantum_measurement
```

The invalid classification is `harness_failed`. A rejection is evidence to
stop or redesign R6, not permission to reduce the matrix or relax thresholds.

Passing this plan gate accepts the plan and may authorize only drafting the
exact disposable E4 source. Measurement may not start before a separate
source gate. No R6 source, live scheduler integration, runtime denial,
cross-class coverage, monitor delivery, N-136 runtime charge, async/service,
MemoryView/TLB, DMA/IOMMU, cluster authority, flat-CFS equivalence,
bare-metal latency, performance, cost, production protection, deployment,
multi-node, multi-cluster, or datacenter readiness is accepted.
