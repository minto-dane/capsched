# Analysis 0173: SchedExecLease P5A-R4 E1 Dispatch and Lifetime Evidence Plan

Date: 2026-07-16

Status: pre-source evidence plan. Passing validation authorizes only an exact,
disposable, default-off R4-E2 layout candidate. It does not authorize a picker
hook, recovery callback, notifier, CPU-hotplug callback, runtime denial, or
production use.

## Purpose

Analysis/0172 selected Generation-Fenced Coalesced Pull Recovery after the R3
measurement rejection. This E1 plan resolves the Linux-specific obligations
left open there before any R4 source is written:

```text
finite storage and admission
rq-lock-safe kick followed by post-lock dispatch
one cursor-based notifier with a no-lost-restart handshake
one coalescing recovery owner per rq
separate current stop-request observation
sleepable hotplug and lifetime drain
diagnostic and measurement rejection gates
```

The exact primary remains Linux commit
`5e1ca3037e34823d1ba0cdd1dc04161fac170280`, tree
`54f685aad94f28f0027cbba18cf5e29aadce234a`. R3 source and its measured
rejection are evidence, never an implementation parent.

## Decisive Source Conclusion: Balance Callbacks Are Not Post-Lock

`queue_balance_callback()` cannot be the R4 dispatch seam. It requires the rq
lock, and `do_balance_callbacks()` asserts that the rq lock is still held when
it invokes every callback. `__balance_callbacks()` only unpins lockdep state;
it does not unlock the runqueue. `balance_callbacks()` reacquires the rq lock
around the callbacks. A balance callback may update rq-locked scheduler state,
but it may not be represented as a post-rq-lock workqueue dispatch point.

Linux already contains the required two-stage pattern in MM CID maintenance:

```text
inside a path which may nest in rq::lock:
  record durable state
  irq_work_queue(preallocated hard irq_work)

after local IRQ/rq-lock exit, in the irq_work callback:
  unconditionally queue preallocated ordinary work

in process context:
  acquire the target rq lock and perform bounded repair
```

The MM CID source explicitly says that scheduling work while its lock nests in
`rq::lock` can end in wakeup, so its irq-work callback unconditionally calls
`schedule_work()`. `irq_work_queue()` atomically claims one pending item and
returns false for a duplicate. `irq_work_single()` clears PENDING and executes
the callback after a full memory barrier. This is the approved R4 bridge.

The later R4 hook must call the bridge only while the owning rq lock is held
with local IRQs disabled. The callback is dispatch-only: it may call
`queue_work()`, but it may not take an rq or membership lock, repair a
projection, allocate, free, wait, or emit monitor/policy work. The hard-IRQ
callback is not the recovery worker.

## Finite Admission and Storage

R4 retains the useful R3 admission proof but none of the rejected R3 fields or
ownership protocol:

```text
B_max                              = 64 projections per rq
outer bucket layers               = 1
feature-introduced inner layers   = 1
maximum outer red-black height    = 12
dirty nodes per rq                <= B_max
recovery owners per rq            = 1
dispatch irq_work items per rq    = 1
notifier owners per active bucket = 1
active rq count A                 <= nr_cpu_ids
total admitted projections        <= B_max * nr_cpu_ids
```

The `0 -> 1` contribution transition must already own a preconstructed
projection, dirty node, bucket reference, and rq slot before the task becomes
runnable. Slot 65 fails closed. It cannot evict, merge, alias, fall back to an
ordinary mixed tree, or allocate under rq/membership locks.

An active bucket has at least one admitted projection, so the number of
simultaneously owned notifier jobs is no greater than the total admitted
projection count. A bucket uses a variable cpumask active-rq index and a sparse
CPU-to-projection map; a dense `nr_cpu_ids` pointer/projection array is
forbidden. Bucket creation/retention remains charged process-context storage,
not unbounded preallocated rq storage.

The architecture-local R4-E2 envelopes are:

```text
frozen bucket key                         <=    64 bytes
bucket control plus notifier              <=   384 bytes
one projection plus one dirty node        <=   960 bytes
one rq state plus irq/work owner           <=   576 bytes
64 projections plus one rq state          <= 62016 bytes per rq
hard private-rq envelope                  <= 65536 bytes per rq
alignment of every private object         <=    64 bytes

ordinary sched_entity delta               == 0
ordinary cfs_rq delta                     == 0
ordinary rq delta                         == 0
ordinary task_struct delta                == 0
```

The projection candidate must embed the dominant inner `cfs_rq`, outer
`sched_entity`, generation/state, intrusive dirty node, and lifetime fields.
The rq candidate must embed the outer private `cfs_rq`, exactly one
`irq_work`, exactly one `work_struct`, and a bounded dirty-list head. Measuring
headers without these dominant objects is rejected.

## Exact R4-E2 Source Boundary

After E1 passes, R4-E2 may create a disposable direct child of the primary and
change exactly:

```text
init/Kconfig
kernel/sched/exec_lease.c
```

The new option is `CONFIG_SCHED_EXEC_LEASE_R4_LAYOUT_PROBE`, depends on the
existing lease/layout debug boundary plus SMP, fair-group scheduling, and IRQ
work, and defaults to `n`. Private types and object-local size/offset probe
arrays live only in `exec_lease.c`. They are never initialized or referenced
by a call site.

E2 adds no constructor, scheduler hook, callback, workqueue allocation, CPUHP
registration, static key, export, tracepoint, file, ABI, monitor/policy call,
or behavior. It changes no public or scheduler header. Arm64 and x86_64 each
compare a clean primary baseline with their own candidate build. All 51
existing expanded-probe values remain unchanged; config-off contains none of
the new symbols or relocations. A failed layout is discarded.

## Publisher and Notifier Protocol

Authority publication remains the O(1) R4 operation. Under the bucket
publication lock it freezes state, release-publishes a non-wrapping generation,
updates the notifier target generation/restart bit, and obtains at most one
notifier ownership reference. It releases the lock before `queue_work()`.
There is no rq-mask walk, rq lock, projection-ref loop, allocation, wait,
flush, or cancellation in the authority critical section.

The one bucket notifier owns these cursor fields:

```text
target_generation
pass_generation
pass_membership_sequence
next_cpu_cursor
restart_required
owned
```

Each notifier invocation performs at most one active projection visit. Under
the membership lock it uses `cpumask_next()` to select one CPU and acquires one
projection reference; it releases that lock before taking the target rq lock.
Under the rq lock with IRQs disabled it revalidates contribution/accepting,
updates the latest desired generation, inserts the preallocated dirty node if
absent, optionally calls `resched_curr()` for an ineligible current task, and
kicks the rq bridge. It then drops the rq lock and reference.

At end of pass, the notifier serializes with publication. A changed target
generation, changed membership sequence, or restart bit resets the cursor and
starts one newest pass. Otherwise it clears `owned`; a racing publisher either
observes ownership and sets restart or observes clear and becomes the new
owner. A `0 -> 1` projection admission after the cursor has passed performs its
own acquire-generation handshake and kick, so insertion cannot be lost.

After a final publication and final membership change, with `A` stable active
rqs, an old partial pass has at most `A` remaining visits and the newest pass
has at most `A` visits. The bound remains at most `2*A` projection-visit
quanta. End-of-pass bookkeeping is O(1). This is a logical work bound under
weak fairness, not a wall-clock deadline.

## Per-rq Recovery Protocol

Each rq has one durable dirty list, one hard `irq_work`, one ordinary recovery
`work_struct`, and one owner state. A mismatch under the rq lock:

```text
latest-wins update of projection.desired_generation
if node absent: add its preallocated node and take its dirty lifetime ref
irq_work_queue(rq_state.dispatch_irq_work)
```

Duplicate kicks and publications do not grow the list. `irq_work_queue()`
returning false means the one bridge item already covers the durable state.
The irq callback unconditionally calls `queue_work()` on a dedicated
`WQ_UNBOUND | WQ_HIGHPRI | WQ_MEM_RECLAIM` workqueue. A false `queue_work()`
return is valid only while the same rq owner is pending/running; durable dirty
state and its reference remain owned.

The worker locks exactly one target rq, removes/selects at most one dirty
projection, and takes at most that projection's bucket membership lock in the
only nested order `rq -> one membership lock`. It rebuilds/blocks one
projection, performs a final state plus acquire-generation recheck, and marks
Fresh only for the newest stable generation. A race retains/reinserts the
node. After all locks are released, the worker may requeue itself if more work
was observed; a concurrent rq-locked insertion always kicks irq-work, closing
the check-versus-insert race.

No callback scans inner leaves, hierarchy levels, all buckets, or all rqs. No
path holds two membership locks or two rq locks. Queueing ordinary work,
cancellation, allocation, free, RCU synchronization, and monitor/policy calls
are forbidden under scheduler locks.

## Current, Migration, and Admission Handshakes

The picker fence and current stop request remain distinct. A picker mismatch
fails closed and records one bridge kick; it does not prove that an already
running task stopped. The notifier/recovery path examines `rq->curr` under the
rq lock and calls `resched_curr()` when the current projection is no longer
eligible. Evidence must record both the request and a later scheduler
observation that current changed or revalidated; `resched_curr()` alone is not
a monitor interrupt, completion receipt, or instantaneous revocation.

Enqueue captures the acquire-published generation under rq lock, accounts
queued/delayed/current states, and publishes Fresh only after a final
generation/membership recheck. Migration is remove-neutral-add: the source
contribution is removed before source rq unlock, no simultaneous source and
destination contribution exists, and destination admission plus handshake
occurs only after placement settles. Destination overflow remains fail closed.

## CPU Hotplug and Lifetime Drain

Hotplug is a two-phase protocol because the fair rq callbacks hold the rq lock
while `irq_work_sync()` and `cancel_work_sync()` may sleep:

```text
rq-locked fair offline phase:
  clear accepting first
  disarm new dirty ownership/kicks
  migrate/remove normal contributions
  mark any bounded residual projection Blocked and keep its refs

sleepable CPUHP_AP_ONLINE_DYN teardown phase:
  require accepting false
  irq_work_sync(one rq bridge)
  cancel_work_sync(one rq recovery work)
  settle canceled owner state and dirty refs outside scheduler locks
  require empty dirty list and no callback ownership before completion
```

The ONLINE CPUHP section runs in the per-CPU hotplug thread with interrupts
and preemption enabled. Online reverses the order: initialize/reset private rq
state in sleepable context, then publish accepting under the rq-locked fair
online seam. Admission additionally requires `cpu_active`, `rq->online`, and
private accepting.

The current enum order is also part of the gate:

```text
CPUHP_AP_WORKQUEUE_ONLINE < CPUHP_AP_ONLINE_DYN < CPUHP_AP_ACTIVE
```

Offline invokes teardown in reverse. Therefore `sched_cpu_deactivate()` and
the fair rq-offline disarm run first, the dynamic R4 drain runs second while
ordinary workqueues are still online, and `workqueue_offline_cpu()` runs later.
The runner compares these source line positions; a reordered kernel blocks the
plan instead of silently changing the drain proof.

Bucket retirement first publishes Retiring/Blocked, prevents new notifier and
dirty ownership, and removes admission registries with RCU-safe unpublication.
It drains the notifier, every sparse projection/dirty reference, and affected
rq work outside scheduler locks. Only after zero task, contribution, notifier,
dirty, callback, and projection references, an empty active mask, and an RCU
grace period may objects be freed. Generation saturation blocks and requires a
quiescent replacement; generations never wrap into trust.

## R4-E3 Correctness Gate Fixed Here

Only dual-architecture R4-E2 closure may unlock a separate default-off,
same-translation-unit synthetic concurrency plan. Its independent oracle must
cover at least:

```text
B_max 0, 1, 63, 64, and rejected 65
duplicate irq kick and irq already pending
publication while irq pending, callback running, work pending, and work running
queue_work false with the one owner retained
worker self-requeue and insert racing its final empty check
two buckets dirty on one rq and one projection per quantum
old partial notifier pass, final republish, restart, and <= 2*A visits
member insert/remove before and after the cursor
enqueue/current/delayed accounting and destination-capacity migration failure
current stop request plus later current-change/revalidation observation
offline while irq pending, work queued, work running, and self-requeued
retirement racing publisher, notifier, picker kick, worker, and RCU readers
generation saturation and every pre-runnable allocation failure
```

KUnit, KASAN, KCSAN, lockdep, DEBUG_OBJECTS_WORK, IRQ-work diagnostics, RCU
diagnostics, CPU-hotplug stress, workqueue fault injection, and warning-free
boots are mandatory where supported. Tests must demonstrate that cancel/sync
run only after new ownership is disabled and outside rq/membership locks.

## R4-E4 Measurement Rejection Limits

Passing correctness permits a separate measurement plan, not behavior. It
must use real locks/callback contexts, paired empty controls, at least 10,000
samples per cell, and measure separately:

```text
O(1) authority publication critical section
O(1) picker mismatch plus irq kick
irq callback plus ordinary-work dispatch
one-projection recovery rq-lock quantum
one notifier projection-visit quantum
current stop-request issue to scheduler observation
offline irq/work drain
```

The earlier one-projection fixed limits remain `p99 <= 5,000ns`,
`p99.9 <= 25,000ns`, and `max <= 50,000ns`; the 700,000ns normalized base
slice is never a budget. Publication and picker experiments must prove work is
independent of A, B_max occupancy, leaf count, and publication burst length.
Notifier and recovery record logical counts separately from elapsed time.
No global publication-to-last-settlement acceptance threshold is restored.

Any lockdep, irqsoff, RCU-stall, workqueue, IRQ-work, KASAN, KCSAN, soft-lockup,
hard-lockup, hung-task, or CPU-hotplug warning rejects the candidate. Virtual
results cannot establish a bare-metal or production latency claim.

## Claim Boundary and Decision

E1 through E4 remain ordinary-CFS test evidence. They do not cover sched_ext,
core-cookie/forced-idle, proxy execution, deadline servers, RT/DL, idle, stop,
per-CPU kthreads, or monitor delivery. A later behavior gate must integrate or
explicitly exclude every path.

```text
R4-E1 validation: required now
R4-E2 exact disposable two-file layout candidate: allowed only after E1 passes
R4-E3 concurrency source: blocked on E2 dual-architecture closure and new plan
R4-E4 measurement source: blocked on E3 correctness and new plan
R4 behavior candidate: blocked on all earlier gates and cross-path closure
primary Linux or patch-queue modification: not allowed
```

This plan does not approve Linux source, runtime behavior, task admission,
denial correctness, fairness/PELT/cgroup compatibility, monitor enforcement,
revocation latency, production protection, performance, cost, deployment, or
datacenter readiness.
