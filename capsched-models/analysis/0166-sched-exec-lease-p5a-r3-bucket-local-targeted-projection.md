# Analysis 0166: SchedExecLease P5A-R3 Bucket-Local Targeted Projection

Date: 2026-07-15

Status: successor architecture gate. The bucket-local targeted-projection
direction is selected for an evidence plan only. No Linux source, hot field,
runtime behavior, or protection claim is approved.

## Trigger

Analysis/0165 and validation/0218 closed P5A-R2 E4 with valid arm64 negative
evidence. Exact source `f6ad4e454778c52bcdaaecf684c148a3a8dae857`
completed all 35 cells, but 20 cells produced 36 fixed-gate breaches. The worst
additional rq-lock hold was 2,440,048ns against a 50,000ns limit. The full O(n)
all-leaf rebuild while interrupts and `rq->lock` are held is therefore closed
as an implementation direction; x86_64 was deliberately not launched.

The successor must preserve the safety rule from analysis/0156:

```text
after local shared-state publication, an old projection is never trusted
```

It must replace the rejected work shape rather than weaken its measurement
range or thresholds.

## Rejected Immediate Alternatives

### Chunking the same full rebuild

Unlocking between chunks makes a cursor into an rb-tree or cfs-rq hierarchy
unsafe across enqueue, dequeue, migration, cgroup movement, delayed dequeue,
and current transitions. A correct design would need stable cursor lifetime,
mutation sequencing, dirty-set settlement, restart rules, and a separate
unpublished aggregate. Repeated mutation can force unbounded restart. This is
not the smallest sound successor and is not authorized by E4.

### Targeted rq mask plus all-leaf rebuild

A Domain-to-rq mask narrows CPU fanout but does not narrow work within an
affected rq. Rebuilding every leaf on each selected rq preserves the rejected
O(n) locked interval. A cpumask alone is therefore insufficient.

### Per-task targeted list under one mixed CFS tree

Walking every task for a revoked Domain and propagating each leaf through the
mixed tree is O(k log n), needs task/list lifetime across lock breaks, and can
still monopolize one rq for a large bucket. Final-task revalidation prevents a
false allow but does not make stale mixed-tree pruning progress bounded.

## Decision

P5A-R3 selects a bucket-local Candidate C projection:

```text
outer:
  choose an already constructed, locally Fresh execution bucket

inner:
  ordinary CFS/EEVDF among tasks admitted to that exact bucket

shared revoke/refill/configuration transition:
  change one bucket generation/state
  target only rqs where that bucket has a runnable/current contribution
  update at most one bucket projection per rq-lock acquisition
  never rebuild or scan the bucket's leaves
```

The bucket is a Linux-local projection of frozen authority. It is not an
authority root and may not mint a Domain, grant, budget, MemoryView, or monitor
receipt.

## Bucket Equivalence Key

Tasks may share an execution bucket only when all picker-relevant shared inputs
are equivalent:

```text
Domain identity and epoch
SchedContext identity and budget root
ExecutionGrant identity/generation class
MemoryView identity/generation projection
CPU placement class
outer selector/topology configuration generation
```

Task generation, exec generation, exiting state, and final CPU settlement stay
task-local. A task-local invalidation removes or quarantines that one task
under its owning rq lock; it must not invalidate or rebuild the whole bucket.

The bucket key holds identifiers and locally frozen receipts, not raw
capabilities. A cgroup or `task_group` identity is not Domain/SchedContext
authority. Existing CFS group machinery may be studied as an implementation
mechanism only after a source plan proves that cgroup movement cannot mint,
merge, or silently change the bucket key.

## Conceptual State

No layout is approved here. The next evidence plan may evaluate a private
shape equivalent to:

```text
sched_exec_bucket:
  immutable equivalence key
  serialized locally frozen shared state
  non-wrapping projection generation
  Fresh | Stale | Blocked eligibility state
  membership lock
  active-rq mask
  lifetime refcount plus RCU retirement
  preallocated per-CPU projection records

sched_exec_bucket_rq_projection:
  owning bucket and CPU/rq identity
  runnable/current contribution refcount
  observed bucket generation and state
  pending-work/work-reference state
  one outer scheduling entity and inner queue linkage, if later proven
```

Current/queued/delayed contributions must all participate in the per-rq
reference count. A currently running entity is not in `tasks_timeline`; it may
not disappear from membership merely because it is outside the rb-tree.

No allocation, ref acquisition that can sleep, or object construction may
happen while an rq or membership lock is held. Bucket and per-CPU projection
storage must exist before the first task becomes runnable.

## Publication and Index-Insertion Handshake

The required lock order is deliberately one-way:

```text
enqueue/dequeue/migration settlement:
  rq lock -> one bucket membership lock

publisher:
  bucket membership lock only while publishing and snapshotting
  release it before queueing work or taking any rq lock

worker:
  one rq lock; acquire-read bucket generation/state
  no membership lock needed for the projection update
```

The publisher performs:

```text
1. take bucket membership lock
2. write new frozen state and eligibility
3. advance the non-wrapping generation
4. release-publish generation/state
5. snapshot active_rqs and acquire one work reference per selected projection
6. release bucket membership lock
7. queue targeted work and reschedule notification outside the lock
```

Every later generation repeats steps 1-7 even when an older projection worker
is already running. A republish cannot reuse the earlier active-rq snapshot;
new contributions that joined after it must be selected by the new snapshot.

First enqueue on an rq performs, while its rq lock is held:

```text
1. take the bucket membership lock
2. read the current published generation/state
3. increment the preallocated projection's contribution count
4. on 0 -> 1, set the active-rq bit
5. publish a local Fresh projection only for the generation just observed
6. if the bucket is Stale/Blocked, keep the local projection untrusted
7. release the bucket membership lock
```

This closes the snapshot race:

- enqueue before publisher lock release is represented in the snapshot; or
- enqueue after the snapshot observes the new generation/state and cannot
  publish an old Fresh projection.

Dequeue may leave a harmless extra snapshot bit, but it may never clear the
bit while a queued, delayed, or current contribution remains. False-positive
fanout is allowed; a missed affected rq is not.

The publisher must never hold the membership lock while acquiring an rq lock.
No path may hold two bucket membership locks simultaneously. A cross-bucket
task transition first removes the old contribution, keeps the task neutral
under the rq lock, then attaches the new contribution.

## Migration and Placement

Queued migration remains a two-boundary transaction:

```text
old rq locked:
  remove the old bucket contribution before old-rq unlock

TASK_ON_RQ_MIGRATING / neutral interval:
  contribution belongs to neither rq

destination rq locked:
  after CPU, affinity, cfs_rq, bucket key, and activation settle,
  insert using the destination generation handshake
```

There may be no state in which the same task contributes to both old and new
bucket projections. Cgroup movement and affinity/cpuset changes inherit the
same remove-neutral-add discipline.

## Per-rq Work Bound

One work invocation may change at most one bucket projection while holding one
rq lock:

```text
lock rq
acquire-read current bucket generation/state
mark only this projection non-Fresh
insert/remove/update at most one outer bucket entity
if current belongs to a newly Blocked bucket, request reschedule
re-read generation before any Fresh publication
if raced, leave Stale and requeue this one projection
unlock rq
```

Forbidden inside the interval:

```text
leaf or cfs-rq hierarchy scan
all-bucket loop
allocation/free or sleeping ref operation
monitor/policy call
task migration or topology mutation
more than one bucket projection update
partial Fresh publication
```

The initial R3 shape has exactly one outer bucket layer; recursively nested
execution buckets are excluded. Updating one outer entity may use a normal
balanced-tree operation, but a later evidence plan must freeze a finite
admission bound `B_max`, prove the resulting tree/group depth, and measure the
locked interval. Until then, “one bucket” is a work-shape bound, not a latency
or performance claim.

## Picker Boundary

The outer selector may trust a local projection only when:

```text
local state == Fresh
local observed generation == acquire_load(bucket generation)
bucket published state is eligible
bucket key matches the frozen selector/configuration context
```

The reached task still receives final task-local generation, exec, affinity,
CPU, and exiting-state revalidation. A mismatch fails closed and schedules
settlement; the picker may not scan leaves, rebuild, call policy/monitor code,
or manufacture a fallback bucket.

Before targeted work arrives, a stale selected bucket may temporarily block an
rq even if another bucket is usable. This explicit false negative is allowed
at the architecture gate. Availability, fairness among buckets, wakeup/load
accounting, and bounded fanout completion remain evidence obligations.

## Lifetime Contract

The task, each nonzero per-rq contribution, and each queued/running work item
hold explicit bucket references. A publisher snapshot obtains work references
under the membership lock before queueing outside it. Retirement requires:

```text
no task reference
all per-rq contribution counts zero
active-rq mask empty
no current contribution
no queued or running work reference
all timer/callback references cancelled or drained
RCU grace period after unpublication
```

Generation saturation blocks the bucket and requires a quiescent replacement;
generation values never wrap into a trusted value.

## Shared and Local Event Split

Bucket-wide publication is required for:

```text
Domain or grant epoch transition affecting the equivalence key
SchedContext/root budget eligibility transition
locally received monitor revoke/refresh receipt
MemoryView generation projection transition
outer bucket topology/configuration transition
```

Single-task locked settlement is required for:

```text
fork/exec/exit generation
task-local grant replacement
affinity/cpuset/CPU movement
cgroup movement that changes placement but not authority
enqueue/dequeue/delayed/current transitions
```

An ordinary budget decrement above the eligibility threshold does not publish
a new bucket generation. Crossing exhausted/refilled eligibility does.

## Evidence Stages and Source Boundary

Passing this architecture gate allows only a separate R3-E1 evidence plan.
That plan must narrow and source-map these possible private boundaries:

```text
include/linux/sched_exec_lease.h  opaque bucket/projection contracts only
kernel/sched/exec_lease.c         private lifetime/publication prototype
kernel/sched/sched.h              scheduler-private projection boundary
kernel/sched/fair.c               outer/inner queue and one-bucket update map
kernel/sched/core.c               migration/reschedule settlement map
include/linux/sched.h             conditional only after fresh layout proof
init/Kconfig                      default-off test boundary only
```

Required later stages are:

```text
R3-E1: exact source/locking/lifetime/B_max evidence plan
R3-E2: disposable default-off layout-only candidate on arm64 and x86_64
R3-E3: test-only publication/index/migration/lifetime concurrency prototype
R3-E4: one-bucket rq-lock and targeted-fanout measurement
R3-E5: separately gated behavior candidate, only if every earlier gate passes
```

The R3-E1 plan must prove exact file scope, no hot-field reuse from the rejected
E2/E3/E4 line, configuration-off absence, object lifetime, CPU hotplug and
offline settlement, finite `B_max`, single outer depth, workqueue/callback
drain, cross-path exclusions, and measurement rejection limits. Until that
plan passes, no disposable Linux source may be created.

## Decision Boundary

```text
selected successor: bucket-local targeted projection
R3-E1 evidence plan drafting: allowed after validation/0219 passes
disposable Linux source: not allowed
behavior patch: not allowed
reuse of full locked rebuild: rejected
chunked full rebuild: not approved
targeted per-task leaf walk: not approved
production bucket/cgroup binding: not approved
```

Runtime denial correctness, live monitor delivery/enforcement, revocation
latency, cross-class coverage, fairness, bounded latency, performance, cost,
production protection, deployment, and datacenter readiness remain false.
