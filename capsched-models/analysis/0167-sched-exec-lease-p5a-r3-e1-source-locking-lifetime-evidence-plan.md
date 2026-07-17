# Analysis 0167: SchedExecLease P5A-R3 E1 Source, Locking, and Lifetime Evidence Plan

Date: 2026-07-15

Status: pre-source evidence plan. Passing its validation authorizes only an
exact disposable, default-off R3-E2 layout candidate. It does not authorize a
picker hook, task admission, runtime denial, or production use.

## Purpose

Analysis/0166 and validation/0219 replaced the E4-rejected all-leaf rebuild
with bucket-local targeted projection. This E1 plan turns that architecture
into a finite Linux engineering boundary before any new source is written.

The plan must make four failures impossible to hide in a later prototype:

```text
unbounded buckets or hierarchy depth
CPU-offline or callback lifetime leaks
an rq/membership/workqueue lock inversion
a layout-only patch that silently changes an ordinary scheduler object
```

The exact primary remains Linux commit
`5e1ca3037e34823d1ba0cdd1dc04161fac170280`, tree
`54f685aad94f28f0027cbba18cf5e29aadce234a`. The rejected E2/E3/E4 line is
evidence only and is not an implementation parent.

## Source Conclusions

The current Linux source provides the required integration boundaries, but not
the bucket implementation:

- `set_rq_online()` and `set_rq_offline()` call each scheduler class while
  holding the target rq lock. Fair's `rq_online_fair()` and
  `rq_offline_fair()` are therefore the only approved later hotplug seams.
- `sched_cpu_deactivate()` clears `cpu_active_mask`, waits for earlier RCU
  readers, and then takes the rq offline. New bucket admission must require
  both the rq-local accepting state and the ordinary CPU/rq state.
- `move_queued_task()` already has the required old-deactivate, CPU-change,
  destination-activate split. A bucket move must refine that interval as
  remove-neutral-add.
- workqueue cancellation is a sleepable drain: `cancel_work_sync()` guarantees
  no pending or executing work only when racing enqueues have first stopped.
  It may never run under an rq or bucket membership lock.
- task-group allocation and RCU retirement prove useful Linux mechanics, but a
  cgroup/task-group identity is still not execution authority.

No existing source implements the proposed bucket generation, active-rq
index, sparse projection map, or callback ownership handshake.

## Finite Admission and Depth

The first L0 bucket implementation fixes:

```text
B_max = 64 active bucket projections on one rq
outer bucket layers = exactly 1
inner scheduler layers introduced by this feature = exactly 1
maximum red-black height for the outer 64-entry set = 12
```

`B_max` is an admission limit, not a tuning suggestion. The `0 -> 1`
contribution transition must already own a preconstructed projection and an rq
slot before the task becomes runnable. Slot 65 fails closed; it may not evict,
merge, alias, scan for a substitute, or fall back to the ordinary mixed tree.

Placement and migration must consider destination capacity. If an unavoidable
CPU-offline move has no destination slot, the task remains non-runnable for
later settlement; old and new projections may never both count it.

The limit is deliberately small enough to provide a hard memory and tree-depth
proof, while large enough for a useful L0 experiment. Raising it requires a
new layout, memory, lock-hold, offline-drain, and workload gate.

## Private Representation Envelope

R3 does not reuse the rejected global-fence fields. A future layout-only
candidate may describe these private objects under a new default-off config:

```text
sched_exec_bucket_key:
  eight u64-equivalent frozen identity/generation words

sched_exec_bucket:
  immutable key
  raw membership lock
  non-wrapping generation and Fresh/Stale/Blocked/Retiring state
  refcount and RCU head
  cpumask_var_t active-rq index
  sparse xarray-like CPU -> projection map

sched_exec_bucket_rq_projection:
  embedded inner cfs_rq and one outer sched_entity
  target CPU/rq identity
  contribution count and observed/desired generation
  preinitialized work_struct and work-ownership state
  owning bucket reference

sched_exec_bucket_rq_state:
  one private per-CPU outer cfs_rq
  accepting flag and active-projection count
```

The sparse map is mandatory. A dense `nr_cpu_ids` projection or pointer array
per bucket is rejected because its memory cost scales with every possible CPU
rather than the bucket's placement.

Architecture-local E2 envelopes are:

```text
bucket key                            <=    64 bytes
bucket control object                 <=   256 bytes
one bucket/rq projection              <=   896 bytes
one private rq state                  <=   448 bytes
64 projections plus one rq state      <= 65536 bytes per rq
alignment of each private object      <=    64 bytes

ordinary sched_entity delta           == 0
ordinary cfs_rq delta                 == 0
ordinary rq delta                     == 0
ordinary task_struct delta            == 0
```

Embedding a real `cfs_rq` and `sched_entity` in the measurement candidate is
intentional. Measuring only a small control header would hide the dominant
Candidate C storage. Passing the envelope is still not proof that fair-group
semantics, PELT, cgroup movement, or EEVDF behavior are correct.

## Exact R3-E2 Source Boundary

After this plan passes, R3-E2 may create a disposable direct child of the
primary Linux commit and change exactly:

```text
init/Kconfig
kernel/sched/exec_lease.c
```

The new option is `CONFIG_SCHED_EXEC_LEASE_BUCKET_LAYOUT_PROBE`, depends on the
existing lease/layout-probe debug boundary plus SMP and fair-group scheduling,
and defaults to `n`. Private type definitions and object-local size/offset
symbols live in `exec_lease.c`; there are no constructors, call sites, static
keys, exported symbols, tracepoints, sysfs/proc/debugfs files, monitor calls,
or userspace ABI.

E2 must rebuild arm64 and x86_64 baselines and compare each architecture with
itself. All 51 existing expanded-probe values remain unchanged. With the new
option disabled, every new type/probe symbol and relocation is absent and all
ordinary structure sizes/observed offsets remain unchanged.

No E2 change is allowed in `include/linux/sched.h`, `kernel/sched/sched.h`,
`kernel/sched/fair.c`, `kernel/sched/core.c`, the public lease header, or the
patch queue. A failed layout is discarded, not promoted or explained away.

## Locking Contract

The only scheduler mutation order is:

```text
rq lock with IRQ state handled by the existing caller
  -> at most one bucket raw membership lock
```

The publisher takes the membership lock with IRQ save as needed, publishes
state/generation and a fresh active-rq snapshot, obtains work ownership, then
releases the lock before queueing. It never takes an rq lock.

The worker:

```text
take exactly one target rq lock
update exactly one projection
release the rq lock
then, if needed, take the membership lock to settle/requeue ownership
```

It never holds rq and membership in the reverse order. No path holds two
membership locks. Allocation, xarray mutation, `queue_work()`,
`cancel_work_sync()`, RCU synchronization, monitor/policy work, or object free
is forbidden while either scheduler lock is held.

The later hotplug slow path may visit at most `B_max` projections while its rq
lock is held, one membership lock at a time. This is not an exception to the
ordinary one-projection worker bound and is measured separately.

## Work Ownership and Coalescing

R3 uses a dedicated unbound, high-priority, reclaim-safe workqueue. Work is
queued with `queue_work()`, not `queue_work_on()`: the projection stores the
target CPU/rq, and the callback may run on any online worker CPU before locking
that target rq. CPU offline therefore cannot strand CPU-bound callback work.

There is at most one work ownership reference per projection:

```text
publisher under membership lock:
  update desired_generation
  if work_owned is false:
    set work_owned
    acquire projection and bucket work refs
    remember this projection for queueing after unlock
  else:
    coalesce into the existing owner

worker after one rq-locked update:
  take membership lock only after rq unlock
  if desired_generation changed or projection still needs settlement:
    retain work_owned and requeue after unlock
  else:
    clear work_owned and release refs after unlock
```

Serialization by the membership lock closes the worker-clear versus publisher-
republish race. A false return from `queue_work()` is allowed only while the
same live work ownership already covers the pending/running item; it may not
drop the sole reference.

## CPU Hotplug

The later live integration must refine the existing fair-class callbacks:

```text
online under rq lock:
  initialize private rq state and outer queue
  publish accepting only after initialization

deactivation/admission:
  reject new contribution when cpu_active is false, rq is offline,
  or private accepting is false

offline under rq lock:
  clear accepting first
  require normal task migration to have removed contributions
  detach/block at most B_max residual projections one at a time
  never clear a bucket active-rq bit while its contribution count is nonzero
```

A residual contribution is an error and remains referenced/Blocked; it is not
forgotten to make teardown pass. Offline/online, affinity, cpuset, and cgroup
movement are mandatory E3 race families before real scheduler hooks.

## Retirement and Drain

Bucket retirement is a sleepable, ordered protocol:

```text
1. publish Retiring/Blocked and disable all new work ownership
2. unpublish from admission registries with RCU-safe removal
3. settle every task and per-rq contribution to zero
4. outside all rq/membership locks, cancel_work_sync() every sparse projection
5. under membership lock, clear any canceled work_owned state and release refs
6. require empty active-rq mask, zero task/contribution/work refs, and no timer
7. remove/free projections only after their callbacks are drained
8. call_rcu() for the bucket; free only after the grace period
```

`cancel_work_sync()` is not itself a revocation receipt and is insufficient
without step 1. The dedicated workqueue is destroyed only after all buckets
are unpublished and all projection work is drained.

Generation saturation publishes Blocked and forces quiescent replacement.
Generation values never wrap or become trusted again.

## R3-E3 Correctness Gate Fixed Here

Only after dual-architecture E2 closure may a separate default-off, same-TU
synthetic concurrency prototype be planned. It must cover at least:

```text
B_max values 0, 1, 63, 64 and rejected 65
publish before/after first contribution and rapid republish
worker clear versus publisher coalescing race
queue_work false while pending/running
generation saturation
queued, delayed, and current contribution accounting
remove-neutral-add migration and destination-capacity failure
CPU online/offline racing publication and work
retire racing publisher, worker, dequeue, and RCU readers
cancel of pending work and drain of running/requeued work
fault injection for every allocation before first runnable use
```

The oracle checks references, active masks, projection state, generation, work
ownership, and absence of use-after-free. KASAN, KCSAN, lockdep, DEBUG_OBJECTS,
RCU diagnostics, and KUnit are required where supported.

## R3-E4 Measurement Rejection Limits

Passing E3 allows a separate measurement plan, not a behavior patch. The
future experiment must use real rq locking and the exact one-projection update,
with paired empty controls and at least 10,000 samples per required cell.

Required one-projection cells vary bucket occupancy `{1, 8, 32, 64}`, inner
runnable count `{0, 1, 64, 4096}`, and stable/raced generation. Leaf count may
change cache state but may not change algorithmic work.

For every cell, additional rq-lock hold is rejected when:

```text
p99   >  5,000 ns
p99.9 > 25,000 ns
max   > 50,000 ns
any sample reaches the normalized 700,000 ns base slice
```

The bounded hotplug drain is measured at occupancy `{0, 1, 8, 32, 64}` and is
rejected above the earlier 25,000ns p99 or 50,000ns maximum limits. Targeted
fanout at active-rq counts `{1, 2, 8, 32, 64}` records publication-to-last-
settlement; in a controlled idle environment it is rejected above 10ms p99 or
100ms maximum. Fanout completion is an availability gate because picker
generation mismatch already fails closed before work arrives.

Any lockdep, irqsoff, RCU-stall, workqueue, KASAN, KCSAN, soft-lockup, or hard-
lockup warning rejects the candidate. Virtual results cannot establish a bare-
metal latency claim. Shrinking a failed matrix is forbidden unless a smaller
deployment bound is independently enforced and regated.

## Cross-Path and Claim Boundary

E1 through E4 are ordinary-CFS test evidence only. They do not cover
sched_ext, core-cookie/forced-idle, proxy execution, deadline servers, RT/DL,
idle, stop, per-CPU kthreads, or monitor delivery. A future E5 must either
integrate or explicitly exclude each path before behavior is reviewable.

This plan does not approve Linux source, a hot field, task admission, picker
behavior, runtime denial correctness, monitor enforcement, revocation latency,
fairness, PELT/cgroup compatibility, production protection, performance, cost,
deployment, or datacenter readiness.

## Decision

```text
R3-E1 evidence-plan validation: required now
R3-E2 exact disposable two-file layout candidate: allowed only after E1 passes
R3-E3 concurrency source: blocked on E2 dual-architecture closure and new plan
R3-E4 measurement source: blocked on E3 correctness and new plan
R3-E5 behavior candidate: blocked on every prior gate and cross-path closure
primary Linux or patch-queue modification: not allowed
```
