# Analysis 0168: SchedExecLease P5A-R3 E3 Bucket Concurrency Evidence Plan

Date: 2026-07-15

Status: pre-source gate for one disposable, default-off, same-translation-unit
KUnit concurrency prototype. This plan does not approve E3 source, a scheduler
hook, runtime behavior, or production use.

## Decision

Validation/0223 closed the exact R3-E2 private layout on fresh arm64 and
x86_64 baselines. The next source may therefore exercise that layout, but only
inside a synthetic KUnit control plane that remains unreachable from normal
scheduler execution.

The prototype tests the bounded bucket-local publication, work-ownership,
migration, hotplug, and retirement protocols selected by analysis/0166 and
fixed by analysis/0167. It does not revive the R2 full-leaf rebuild rejected by
validation/0218. It does not add the real picker, publisher, task/cgroup hook,
fanout integration, monitor call, or enforcement decision.

## Immutable Predecessor and Source Boundary

The future source draft must be an exact direct child of:

```text
parent:    63313b329e1d44901acfce30698613c38615c8d5
tree:      8d51c596d3d73a6c6dc507b84fdcd4ac8aa7f8eb
worktree:  build/DomainLeaseLinux.volume/worktrees/
             p5a-r3-e3-bucket-concurrency-prototype
branch:    codex/p5a-r3-e3-bucket-concurrency-prototype

allowed files:
  init/Kconfig
  kernel/sched/exec_lease.c
```

Every other Linux file is frozen. In particular, the draft may not edit
`sched.h`, `fair.c`, `core.c`, a public header, the scheduler Makefile, or the
expanded layout-probe object. The existing E2 private types and all 43 private
layout probe values remain byte-for-byte and value-for-value fixed; the 51
expanded ordinary probe values and four zero-growth results remain fixed.

Primary Linux remains `5e1ca3037e34823d1ba0cdd1dc04161fac170280`.
The patch queue remains commit `2a022dce54679ce5ecb86581bf55199dc28c868b`,
series blob `298567f8e0bd18168222da4e64da32750b9ea818`, and tail 0014.
The E3 branch is disposable evidence, not a primary or patch-queue promotion.

## Configuration and Translation-Unit Boundary

Add exactly one configuration:

```text
CONFIG_SCHED_EXEC_LEASE_BUCKET_KUNIT_TEST
  bool
  default n
  depends on SCHED_EXEC_LEASE_BUCKET_LAYOUT_PROBE && KUNIT=y
```

It is not selected by the ordinary lease option, the layout probe, or
`KUNIT_ALL_TESTS`. All E3 includes, helpers, fixtures, fault controls, worker,
and suite registration are inside that option in `kernel/sched/exec_lease.c`.
The suite name is exactly `sched_exec_lease_bucket`. No Makefile or header
change is allowed.

This same-translation-unit rule lets KUnit use the actual E2-private bucket,
projection, and rq-state types without exporting them. The E3 code must
disappear completely when its option is disabled: no helper/suite symbol,
relocation, string, constructor, tracepoint, static key, debugfs/proc/sysfs
surface, or userspace ABI may remain.

## Synthetic Prototype Boundary

The prototype is a deterministic model of scheduler-side control state. It may
instantiate the real private types, real raw membership locks, refcounts,
cpumasks, XArray, RCU callbacks, and an actual dedicated workqueue. Synthetic
rq identifiers and contribution counters replace live runqueues and tasks.

The prototype may not:

```text
attach to struct rq, cfs_rq, sched_entity, task_struct, or task_group
call enqueue/dequeue, picker, migration, hotplug, or cgroup production seams
make a capability, policy, budget, monitor, or denial decision
publish a global registry reachable by non-test code
export a helper or create a trace/debug/userspace surface
use the rejected all-leaf rebuild or any leaf scan
```

Passing E3 proves only that the isolated control protocol matches its oracle
under the required finite schedules and diagnostics.

## Capacity and Pre-Runnable Allocation

The exact capacity cases are `0, 1, 63, 64, 65` active projections per rq.
Zero, one, 63, and 64 are valid. The 65th bucket fails closed before its first
queued, delayed, or current contribution. There is no eviction, merge, mixed-
tree fallback, or bound increase.

All storage is prepared in sleepable context before contribution state becomes
visible. The fault matrix injects failure at every named allocation boundary:

```text
dedicated workqueue creation
bucket control object
bucket active-rq cpumask
private rq-state object
bucket/rq projection object
XArray index reservation
```

Each failure must return `-ENOMEM`, leave no active bit, XArray projection,
contribution, pending/running work, or extra reference, and permit a clean
retry after the fault is removed. No allocation, free, XArray allocation, or
sleep occurs while a synthetic rq lock or membership lock is held.

## Locked State and Contribution Oracle

The independent oracle stores plain fixture records, not E2 structs, and does
not call prototype transition, ref, mask, generation, or work helpers. After
every forced schedule it snapshots the implementation under its documented
locks and compares:

```text
bucket state and non-wrapping generation
projection desired and observed generation
queued, delayed, and current contribution counts
active-rq bit and XArray membership
rq-state active-projection count and accepting state
bucket, projection, task, contribution, and work-owner references
pending/running/requeue/cancel state
unpublished, queue-disabled, RCU-reader, callback, and freed state
```

The reference equation is explicit. A projection has its base reference plus
one reference for each task/contribution owner and exactly one coalesced work
owner while pending, running, or requiring requeue. The active-rq bit is set
iff total queued+delayed+current contributions on that projection is nonzero.
No assertion is skipped merely because teardown follows a failed assertion.

## Publication and Work-Ownership Protocol

Publication uses the bucket membership lock only; it never takes an rq lock.
Every new generation takes a fresh active-rq snapshot. For each snapshotted
projection it raises `desired_generation`, acquires the single work-owner
reference if absent, releases the membership lock, and only then calls
`queue_work()` on the dedicated `WQ_UNBOUND|WQ_HIGHPRI|WQ_MEM_RECLAIM` queue.

`queue_work()==false` while pending or running is success only when a live
work-owner already covers that projection. The worker updates one projection
under one synthetic rq lock, releases it, then settles under the membership
lock. If desired generation changed while it ran, the same owner is retained
and work is requeued outside locks. Clearing ownership and republishing are
serialized under the membership lock. A stale worker never marks a newer
generation Fresh.

Generation zero is invalid. Reaching `U64_MAX` publishes Blocked and requires
quiescent replacement; generation never wraps or becomes trusted again.

## Migration and CPU Hotplug

Migration is remove-neutral-add:

```text
1. remove old-rq queued/delayed/current contribution under old synthetic rq
2. clear old active membership only after its total reaches zero
3. expose an oracle-visible neutral state with no rq contribution
4. add to the destination only after its projection/capacity is prepared
```

Destination-capacity or allocation failure leaves the task neutral and denied;
it does not restore an unverified source contribution or create a partial
destination contribution.

Online initializes private rq state before setting accepting. Offline clears
accepting first, then visits at most `B_max=64` sparse projections, settles all
queued/delayed/current contributions, and clears membership only at zero. The
unbound worker must not be stranded on the offline CPU. Publication, worker,
and offline interleavings are forced with completions, never timing sleeps.

## Retirement, Cancel, and RCU

Retirement follows this exact sleepable sequence:

```text
1. publish Retiring/Blocked and prohibit new work ownership
2. unpublish the bucket from the synthetic RCU registry
3. settle every task and contribution to zero
4. outside all scheduler and membership locks, cancel_work_sync() each work
5. under membership lock, settle canceled ownership and any required requeue
6. require empty active mask, empty XArray, and zero task/contribution/work refs
7. release projections only after pending/running/requeued work is drained
8. wait for every pre-unpublish RCU reader, then free the bucket
9. destroy the dedicated workqueue only after every bucket is drained
```

The tests cover cancel-before-run, cancel-while-running, and running-worker
requeue. `cancel_work_sync()` is not treated as a revocation receipt and is
never called while a racing enqueue is still permitted.

## Required Deterministic Cases

The suite contains exactly named cases covering at least these 20 families:

```text
bmax_0_1_63_64_and_65_reject
publish_empty_then_first_contribution
first_contribution_then_publish
rapid_republish_coalescing
worker_clear_vs_republish
queue_work_false_pending
queue_work_false_running
generation_saturation_blocked
queued_delayed_current_accounting
zero_to_nonzero_active_bit
nonzero_to_zero_active_bit
migration_success_remove_neutral_add
migration_destination_capacity_failure
cpu_online_publish_race
cpu_offline_publish_race
cpu_offline_worker_race
retire_publisher_race
retire_worker_dequeue_rcu_reader_race
cancel_pending_running_requeued
allocation_fault_every_pre_runnable_site
```

Race cases use completions/barriers to force every documented side of the
interleaving and have a five-second hard timeout. Timing-only sleeps, skipped
cases, probabilistic success, and reducing the matrix after failure are
forbidden. In addition, each diagnostic boot repeats the coalescing, migration,
hotplug, and retirement stress loop at least 1,024 times.

## Build, Boot, and Diagnostic Matrix

Fresh build directories are mandatory. Both arm64 and x86_64 build:

```text
exact E2 parent baseline
E3 source with ordinary lease/layout/test configs off
E3 source with layout on and E3 test off
E3 source with E3 KUnit test on
```

Disabled modes must contain zero E3 symbols, relocations, and strings. Enabled
modes must retain all E2 43-symbol values and all existing 51 expanded values.
Strict checkpatch and diff checks are 0/0/0 and the source remains exactly two
files.

Four QEMU boots are required:

```text
arm64   standard debug + KUnit + lockdep + DEBUG_OBJECTS_WORK + PROVE_RCU
x86_64  standard debug + KUnit + lockdep + DEBUG_OBJECTS_WORK + PROVE_RCU
arm64   generic KASAN diagnostic
x86_64  KCSAN diagnostic
```

Each boot filters exactly `sched_exec_lease_bucket`, completes every required
case with zero failure/skip/timeout, and records compiler, config, image/object
hashes, QEMU command, KTAP, and complete console log. Any KASAN, KCSAN,
lockdep, refcount, work-debug, RCU, warning, BUG, stall, soft-lockup, or
hard-lockup report rejects the source. Sanitizers are separate because KCSAN
depends on `!KASAN`.

## Authorization and Claim Boundary

If this plan gate passes, it authorizes only creation of the exact disposable
two-file E3 draft. It does not accept that source or its correctness. Those
claims require a separate source gate and the complete build/boot matrix above.

Even a later E3 source pass authorizes only an R3-E4 measurement plan. It does
not authorize a production scheduler hook, primary or patch-queue change,
runtime denial, monitor enforcement, cross-class coverage, bounded latency,
performance, cost, deployment, or datacenter readiness.

R3-E4 remains separately gated by the immutable one-projection, hotplug, and
fanout rejection limits from analysis/0167. R3-E5 must integrate or explicitly
exclude sched_ext, core forced-idle, proxy execution, deadline servers, RT/DL,
idle/stop/per-CPU kthreads, and monitor delivery before behavior is reviewable.

## Next

Run validation/0224. Only a reproducible pass of the exact source/identity
anchors, safe formal model, and every expected unsafe counterexample permits
creating the disposable R3-E3 worktree and source draft.
