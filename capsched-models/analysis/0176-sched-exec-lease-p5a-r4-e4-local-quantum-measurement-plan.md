# Analysis 0176: SchedExecLease P5A-R4 E4 Local-Quantum Measurement Plan

Date: 2026-07-18

Status: source-free pre-source rejection plan. Passing validation/0257 may
authorize only an exact disposable, default-off, same-translation-unit R4-E4
measurement source draft. It does not authorize a measurement launch, a live
scheduler hook, R4 behavior source, or a latency/performance claim.

## Decision

Analysis/0175 accepts candidate `da9ce915...` and its concurrency semantics
only for the closed six-boot virtual synthetic protocol. The next question is
not whether global settlement is fast. R3 already showed why a virtual
publication-to-last-settlement threshold is the wrong trust boundary. R4-E4
instead attempts to reject any implementation whose supposedly bounded local
quanta exceed the fixed envelopes selected in analysis/0173.

The seven measurement families are:

```text
O(1) authority-publication critical section
O(1) picker mismatch plus irq-work kick
hard-IRQ callback plus ordinary-work dispatch
one-projection recovery rq-lock quantum
one notifier projection-visit or end-of-pass quantum
current stop-request issue and later synthetic scheduler observation
offline rq-lock phase and sleepable irq/work drain
```

This is compatibility and rejection evidence for the exact test-only
candidate. A threshold breach is a valid completed negative result. Missing,
reduced, malformed, or mutated evidence is a harness failure and receives no
engineering classification.

## Locked Prerequisite and Direct-Child Boundary

The plan binds both canonical post-N-135 authorization results and the exact
candidate they accepted:

```text
candidate parent:       a429fc30252ac6af94c51d96cd4ac24e72d9f83b
candidate commit:       da9ce9159b3450c28c8faf8dceac671fb7bfeba2
candidate tree:         58c6510c6f517004e37107786d006bb8333b79b8
candidate diff SHA-256: 096d99b527bd1b433ecd07165696830f9316d07cc67484687d95cd2c2a846f08
authorization r7:       160efd76ed083df880747685a861a1b920e5fa9a265a4946749f87da44e09d37
authorization r8:       d736b698cc056bea41d671c61b5c5a9a98024327642ff79c19f6dfb42f60f905
authorization normalized:
  541d72676f97741c40ed3a50b4f524c63a9530fc9984bfc88ed6675415d1fb4f
```

Only after this plan gate passes may an exact direct child be drafted:

```text
branch:    codex/p5a-r4-e4-local-quantum-measurement
worktree:  build/DomainLeaseLinux.volume/worktrees/
             p5a-r4-e4-local-quantum-measurement

allowed files:
  init/Kconfig
  kernel/sched/exec_lease.c
```

The E2 layout, all 58 private layout values, the E3 protocol, 36 case
families, six fault sites, independent oracle, receipts, and 2,048-iteration
stress contract remain frozen. Primary Linux and the patch queue do not
change. A later E4 draft may add measurement-only timestamp/result storage and
brackets around the exact E3 operations. It may not substitute a cheaper
timing implementation. If a helper must be extracted, both the unchanged E3
suite and E4 suite must call the same helper, and a separate source gate must
prove semantic and diagnostic preservation before measurement starts.

The plan refreshed Torvalds master from the authorization-gate observation
`1229e2e57a5c...` to `f2ec6312bf71...`, an ancestry-preserving advance of 22
commits. Neither `init/Kconfig` nor the private
`kernel/sched/exec_lease.c` changed. The latter remains absent upstream. The
candidate merge base remains `4edcdefd4083...`, and a merge-tree against the
refreshed tip completes without conflict at tree `6c5fff5aaf6b...`. This is
touched-path freshness only, not a claim that every project source map is
globally current.

## Configuration and Non-Attachment Boundary

The only future configuration is:

```text
CONFIG_SCHED_EXEC_LEASE_R4_MEASURE_KUNIT_TEST
  bool
  default n
  depends on SCHED_EXEC_LEASE_R4_KUNIT_TEST && KUNIT=y
```

The exact suite is `sched_exec_lease_r4_measure` in
`kernel/sched/exec_lease.c`. It is not selected by ordinary lease support,
either layout probe, the E3 test, or `KUNIT_ALL_TESTS`. With it disabled there
must be zero E4 symbols, relocations, strings, initcalls, timestamp writes, or
result rows.

E4 adds no object, header, export, static key, runtime caller, scheduler hook,
CPUHP registration, tracepoint, debugfs/proc/sysfs/securityfs entry, netlink
family, device, userspace ABI, monitor call, policy decision, admission, or
denial path. Fixtures remain private synthetic shells; no task, cgroup,
`struct rq`, `cfs_rq`, `sched_entity`, or `task_group` is attached to the live
scheduler.

## Common Measurement Contract

All fixtures, projections, bucket/rq shells, work items, controls, sample
arrays, sort buffers, result rows, deterministic schedules, and cache ballast
are allocated and initialized before timing. Each cell first performs an
untimed oracle/operation-count check and returns to the same quiescent state
after every pair.

Local locked samples use `local_clock()` with local IRQ state and the exact
locks required by the operation. Each treatment has an empty control that
takes the same locks, executes the same timestamp stores and compiler
barriers, and differs only in the bounded operation. Treatment/control order
alternates. The paired additional sample is:

```text
max(treatment_ns - control_ns, 0)
```

Negative clock noise never wraps. Sorting, statistics, KUnit assertions,
printing, row emission, allocation/free, tracing, sleeping, rescheduling,
topology mutation, policy/monitor work, and cancellation are outside local
measured intervals. Each required cell has at least 256 warmup pairs and
exactly 10,000 recorded pairs. Independently sorted treatment, control, and
additional arrays report minimum, p50, p95, p99, p99.9, and maximum with a
documented nearest-rank rule.

The runner records raw rows, clock source, vCPU pinning/migration observations,
interrupt/preemption state, compiler, config, object and Image hashes, QEMU
command, console, KTAP, environment, warnings, and exact source identity. A
cell with clock regression, observed vCPU migration, missing pair, or an
operation-count mismatch is a harness failure.

## Fixed Local Rejection Envelope

For publication, picker kick, IRQ dispatch, one recovery quantum, one notifier
quantum, and current-request issue, every cell must satisfy:

```text
paired additional p99   <=  5,000 ns
paired additional p99.9 <= 25,000 ns
paired additional max   <= 50,000 ns
every paired additional sample < 700,000 ns
```

The normalized 700,000ns CFS base slice is a rejection marker, never an R4
budget, deadline, production SLO, or monitor timer.

## Publication Matrix: 288 Cells

The full Cartesian matrix is:

```text
active-rq bits:       0, 1, 2
rq bucket occupancy:  1, 8, 32, 64
synthetic inner load: 0, 1, 64, 4096
prior burst length:   1, 64, 4096
notifier owner:       clear, owned-restart
```

The timed interval contains only the existing membership-lock critical section
that freezes state, release-publishes the non-wrapping generation, updates the
target, and either acquires one notifier owner or sets restart. Workqueue
queueing occurs after timing. Source/operation-count checks require zero
active-rq, XArray, leaf, bucket, or publication-history iteration and exactly
one generation transition. Occupancy and burst dimensions may perturb cache
state but may not change work count.

## Picker Mismatch and irq-work Kick Matrix: 144 Cells

The full Cartesian matrix is:

```text
rq bucket occupancy:  1, 8, 32, 64
synthetic inner load: 0, 1, 64, 4096
desired-generation burst: 1, 64, 4096
owner state: idle, dirty-plus-irq-pending, work-running
```

The treatment holds the one synthetic rq raw lock with IRQs disabled, performs
latest-wins desired-generation update, inserts at most one preallocated dirty
node on the `0 -> 1` edge, retains one recovery owner, and calls the real hard
`irq_work_queue()`. It may not inspect another bucket/projection or an inner
leaf. Cleanup and callback settlement occur outside timing. Duplicate/pending
outcomes must keep dirty depth and owner count unchanged.

## IRQ Dispatch Matrix: 9 Cells

The Cartesian matrix is:

```text
queue_work outcome: queued, false-pending, false-running
unrelated workqueue depth: 0, 1, 64
```

Treatment and control execute as real hard irq-work callbacks. Treatment does
only the exact `queue_work()` dispatch and owner classification; control uses
the same callback/timestamp shell without dispatch. It takes no scheduler or
membership lock, allocates nothing, repairs nothing, and waits for nothing.
The false outcomes are valid only while the same recovery owner is provably
pending or running.

## One-Projection Recovery Matrix: 144 Cells

The full Cartesian matrix is:

```text
dirty depth:         1, 8, 32, 64
rq bucket occupancy: 1, 8, 32, 64
contribution class:  queued, delayed, current
outcome:             settle, republished-race, blocked
```

One treatment takes one rq lock, removes at most the first unique dirty node,
takes at most its one membership lock in `rq -> membership` order, revalidates,
and either publishes Fresh, retains/requeues stale work, or blocks it. Exactly
one projection visit and at most one current request are allowed. It never
scans the remaining dirty nodes, other buckets, inner leaves, hierarchy, or
rqs. Logical counts are emitted separately from elapsed time.

## One-Notifier-Quantum Matrix: 48 Cells

The full Cartesian matrix is:

```text
active synthetic rqs: 1, 2
cursor quantum:       first, last, end-of-pass
membership outcome:  stable, changed-restart
contribution class:   queued, current
kick owner:           idle, coalesced
```

A projection quantum performs at most one `cpumask_next()`, takes one
projection reference under the membership lock, releases it before taking one
rq lock, revalidates, updates one desired generation, and performs one kick.
An end-of-pass quantum performs only O(1) generation/membership/restart/owner
bookkeeping. No invocation may visit a second projection. Separately, the
oracle checks that a final publication and membership change settle in at
most `2*A` projection visits for every deterministic active-rq schedule. That
is a logical work bound under forced weak fairness, not a wall-clock bound.

## Current Stop-Request Matrix: 24 Cells

The full Cartesian matrix is:

```text
request source:      recovery, notifier
observation outcome: current-changed, same-current-revalidated
owner state:         idle, coalesced
publication burst:   1, 64, 4096
```

The local request issue is measured under the one rq lock and uses the fixed
local envelope. A second timestamp records the later, distinct synthetic
scheduler-observation transition. Request and observation sequences must be
strictly ordered and one-to-one; setting need-resched or incrementing a
request sequence is not completion.

The virtual request-to-observation interval is an availability calibration.
Its fixed rejection limits are p99 `10,000,000ns` and maximum
`100,000,000ns`. Passing them is not a real stop, revocation, monitor-delivery,
or bare-metal latency claim.

## Offline Drain Matrix: 25 Cells

The full Cartesian matrix is:

```text
rq bucket occupancy: 0, 1, 8, 32, 64
callback state:      idle, irq-pending, work-pending, work-running,
                     self-requeue
```

The rq-lock phase clears accepting first, disables new ownership, visits at
most `B_max=64` prepared projections, accounts queued/delayed/current
contributions, retains residual state Blocked, and releases all scheduler
locks. Its paired additional limits are p99 `25,000ns`, p99.9 `40,000ns`,
maximum `50,000ns`, and no sample may reach `700,000ns`.

The sleepable phase then performs the real `irq_work_sync()` and
`cancel_work_sync()` outside every scheduler lock, settles canceled ownership
and dirty references, and proves an empty terminal state. Its virtual
availability limits are p99 `10,000,000ns` and maximum `100,000,000ns`.
These limits reject this disposable design only; they do not establish live
CPUHP or bare-metal bounds.

## No Global Settlement Gate

R4-E4 deliberately has no publication-to-last-rq-settlement latency threshold
and no all-rq fanout benchmark. Publication remains safe by making stale
projections untrusted immediately; the notifier/recovery chain is bounded as
local quanta plus logical counts. A future source or harness that reintroduces
an all-rq scan, global completion trust, or a global settlement SLO violates
this plan.

## Build, Boot, and Diagnostics

A separate source gate must prove, for arm64 and x86_64:

```text
E4-disabled source has zero E4 artifacts and preserves all E2/E3 manifests
E4-enabled source builds with strict W=1 and strict checkpatch
all 36 E3 cases and receipts remain byte-semantically equivalent
the six E3 diagnostic profiles remain warning-free after any helper change
every E4 bracket/control maps to the exact operation it claims to measure
```

Only then may timing run first on arm64 and, if arm64 passes all fixed gates,
on x86_64 at identical source identity. Timing boots use KUnit, lockdep,
DEBUG_OBJECTS_WORK, PROVE_RCU, DEBUG_IRQFLAGS, irq-work/workqueue diagnostics,
and CPU-hotplug diagnostics. KASAN/KCSAN remain separate diagnostic evidence,
not timing environments.

Any compiler diagnostic, final clock-skew warning, lockdep, irqsoff, RCU,
workqueue, irq-work, refcount, KASAN, KCSAN, WARNING, BUG, Oops, panic, stall,
hung-task, soft/hard-lockup, or CPUHP report rejects the candidate. Missing
artifacts, cells, samples, controls, raw rows, hashes, environment metadata, or
warning evidence is `harness_failed`, not a threshold rejection.

## Classification

Each executed architecture produces exactly one of:

```text
passed_r4_e4_architecture_measurement
rejected_r4_local_quantum_measurement
harness_failed
```

A complete valid threshold rejection stops the candidate and preserves all
raw evidence; the second architecture need not run. Full virtual E4
compatibility requires both architectures at one source identity and a later
independent artifact closure. It may unlock only a separate post-E4 review;
it does not authorize R4 behavior source.

## N-136 and Claim-Ledger Boundary

This plan carries the mandatory 14-field claim-ledger row. The measurement
suite observes protocol costs only. It must not add or infer a runtime budget
hook, choose `current` or `donor` as budget authority, treat class runtime as a
root budget, consume a monitor event, or claim runtime coverage. Analysis/0090
and validation/0107 remain a separate N-136 blocker.

Virtual synthetic measurement may support only compatibility or rejection of
the exact candidate under the recorded environments. It cannot support real
scheduler correctness, runtime denial, monitor enforcement, bounded
bare-metal latency, performance/cost, production protection, deployment,
multi-node, multi-cluster, or datacenter readiness.

## Authorization After Plan Pass

```text
exact disposable E4 two-file source drafting: allowed
E4 measurement launch: blocked on separate source/diagnostic gate
E4 measurement acceptance: false
R4 behavior source: false
primary Linux or patch queue change: false
N-136 runtime charge/coverage: false
all runtime, monitor, production, cluster claims: false
```

## Next

Run validation/0257. Only two reproducible plan-gate runs with identical
normalized results, the safe formal trace, all expected unsafe
counterexamples, exact prerequisite hashes, complete matrices, immutable
thresholds, and negative-claim checks may authorize drafting the disposable
R4-E4 source.
