# Analysis 0172: SchedExecLease P5A-R4 Generation-Fenced Coalesced Pull Recovery

Date: 2026-07-16

Status: architecture/formal gate. This gate selects the R4 successor shape and
may authorize only an R4-E1 evidence plan. It does not authorize Linux source,
runtime behavior, or any protection, latency, performance, or production claim.

## Trigger and correction

The exact R3 arm64 E4 result is
`20260716T-p5a-r3-e4-arm64-measurement-r1`, SHA-256
`edba124b804beeaa7a2d723027fa3a6345f2d546fb0ab861428c6a4727b5cb7b`.
It is complete valid negative evidence: 19/42 cells and 26 fixed gates failed,
while QEMU, KUnit, warning, row, parser, and artifact-integrity gates passed.

R3 already separated trust from fanout: an acquire-read generation mismatch
made a local projection unusable before work arrived. The failed fanout matrix
was an availability experiment measuring publication to last settlement; it
was never the trust root. The successor therefore does not "remove fanout from
authority." It removes synchronous all-target settlement from the global
availability acceptance condition while retaining the generation fence as the
picker trust boundary.

## Selected architecture

R4 is **Generation-Fenced Coalesced Pull Recovery**:

1. authority publication release-publishes frozen bucket state and a new
   non-wrapping generation in an O(1) critical section;
2. the picker accepts a projection only when its local state is Fresh, its
   generation equals an acquire-read published generation, the bucket is
   eligible, the key matches the current selector configuration, and the final
   task-local check passes;
3. a mismatch fails closed and records at most one preallocated recovery kick;
4. per-rq recovery owners coalesce repeated publications to the newest desired
   generation and repair one projection per rq-lock acquisition; and
5. a separately coalesced bucket notifier accelerates active-rq recovery and
   requests reschedule for a current contribution without waiting for any rq
   to settle.

The authority-publication critical section may not walk an rq mask, acquire an
rq lock, acquire a work reference per rq, allocate, sleep, flush, cancel, or
wait. It may update frozen state, release-publish one generation, set an
idempotent notification bit, and queue one preallocated notifier. The notifier
and recovery owners are availability mechanisms only.

Generation reuse is forbidden. Saturation transitions the bucket to Blocked
until a separately proved replacement/retirement protocol completes.

## Picker and pull boundary

The picker remains O(1). For the candidate projection it may perform only
bounded local loads, the acquire generation/state check, the exact selector-key
check, a final task-local recheck, and an idempotent kick record. It may not
repair a projection, scan leaves or all buckets, allocate, call policy or the
monitor, wait for another rq, mint fallback authority, or trust a notification.

If dispatch cannot safely occur while the rq lock is held, the locked picker
records a preallocated kick and an evidenced post-lock seam performs the actual
queue operation. Until that dispatch and repair complete, the candidate stays
untrusted. R4-E1 must source-map this seam; this gate does not assume one.

The rq owns a bounded intrusive dirty queue of preallocated projection nodes.
A node has one pending/running owner and one `desired_generation`. A repeated
publication updates the desired generation monotonically but cannot add a
second node or a second owner. Queue size is bounded by the already required
finite per-rq bucket admission limit `B_max`; it is independent of the number
or rate of publications.

One recovery quantum:

```text
dequeue one dirty projection
take exactly one owning rq lock
take at most that bucket's membership lock in rq -> membership order
acquire-read newest bucket state/generation
update at most one outer projection; never scan an inner leaf
recheck state/generation before publishing Fresh
if raced, keep the node dirty at the newest desired generation
drop locks and refs, then requeue the single rq owner if work remains
```

No caller waits for this quantum. A queueing return value, pending bit, worker
completion, notification cursor, or stale local Fresh label is not authority.

## Bucket notifier and current execution

The bucket notifier is one preallocated, coalescing owner. It walks the bounded
active/current membership index in bounded quanta outside the publication
critical section. For each retained projection it may request the rq-local
dirty operation and, under the owning rq lock, call the scheduler's existing
reschedule mechanism when the current contribution has become ineligible.
It never waits for last settlement and never makes a projection trusted.

This separation does not prove instantaneous revocation of a task already
running when a generation changes. The projection generation fence governs a
future picker decision. Linux `resched_curr()` requests a scheduler rendezvous;
production protection still requires the separately modeled monitor-owned
interrupt/timer and a completion receipt. R4 may claim only eventual local
stop-request delivery under its liveness assumptions, not a wall-clock stop
deadline or monitor enforcement.

## Conditional liveness and deterministic work bounds

Unconditional recovery under infinitely repeated publication is impossible:
there may be no stable generation to install. R4 states the missing assumption
instead of hiding it.

A **stable window** begins after the final publication when:

- bucket generation/state and active/current membership stop changing;
- online rq owners and the bucket notifier are weakly fair;
- hotplug/retirement is not concurrently draining those owners; and
- the finite bounds `A = active_rq_count` and `B_max` hold.

If a notifier pass was already in flight at the final publication, its final
generation check restarts it. Therefore all stable active/current members are
visited within at most `2*A` notifier quanta. Each rq then settles or retains
Blocked every queued projection within at most the dirty count at the stable
boundary, which is at most `B_max` recovery quanta. Duplicate publications do
not increase either queue depth. These are logical work bounds, not time.

During continuous publication, safety remains fail-closed and queue depth
remains bounded, but availability may remain false. Any future wall-clock gate
must separately measure publication critical-section time, notifier dispatch,
per-rq demand recovery, current stop-request delivery, and monitor completion;
it may not restore the rejected R3 last-settlement gate under a new name.

## Race, lifetime, and hotplug obligations

- Enqueue establishes its contribution under the rq lock and performs a
  current-generation handshake; it either proves a complete Fresh projection
  for that generation or leaves the projection dirty.
- Dequeue/current/delayed transitions update contribution accounting under the
  rq lock and cannot clear another generation's dirty request.
- Migration removes the old contribution before old-rq unlock, has no interval
  of simultaneous source/destination contribution, and applies the destination
  generation handshake only after destination placement is settled.
- A notifier/recovery observation is followed by a final generation and
  membership recheck before Fresh; racing work remains dirty or Blocked.
- Offline first clears accepting, prevents new kicks, drains the bounded local
  dirty inventory under the rq lock, and flushes/cancels work only outside it.
- Bucket/projection/rq work has explicit queued/running references. Free
  requires zero task, projection, current, dirty, notifier, recovery, and
  callback references plus the required RCU grace period.

## Current Linux source anchors

The source basis remains primary Linux commit
`5e1ca3037e34823d1ba0cdd1dc04161fac170280`, tree
`54f685aad94f28f0027cbba18cf5e29aadce234a`.

Current source provides mechanisms, not an R4 implementation:

- `kernel/sched/core.c` requires the rq lock for `resched_curr()` and may send
  a remote reschedule IPI;
- `kernel/workqueue.c` coalesces a queued `work_struct` through
  `WORK_STRUCT_PENDING_BIT`, and `queue_work_on()` reports an already queued
  item as false;
- `kernel/irq_work.c` also claims one pending owner and explicitly requires
  offline flush discipline; and
- `kernel/sched/fair.c` exposes rq online/offline lifecycle callbacks.

Those primitives do not prove R4 lock ordering, latest-generation coalescing,
stable-window liveness, current-stop completion, or lifetime safety. R4-E1 must
map exact storage, post-lock dispatch, hotplug drain, work ownership, and
diagnostic evidence before any source draft.

## Rejected alternatives

- Raising or deleting the R3 thresholds is rejected.
- Synchronously waiting for chunked targeted settlement is rejected.
- Treating workqueue/irq-work pending state or completion as authority is
  rejected.
- Repairing or scanning multiple buckets in the picker is rejected.
- Claiming unconditional liveness during infinite publication is rejected.
- Claiming `resched_curr()` alone as instantaneous or monitor-backed revoke
  completion is rejected.
- Reusing the rejected R3 disposable fields/source without a new layout,
  locking, lifetime, and evidence plan is rejected.

## Decision and next gate

The architecture/formal/source-anchor validation may authorize only R4-E1:
an exact no-source evidence plan for storage bounds, post-lock kick dispatch,
one-owner coalescing, notifier cursor/restart, rq-lock quantum, current
stop-request observation, hotplug/lifetime drain, and safe/unsafe diagnostics.

Primary Linux, patch queue, R3 source promotion, R4 source, live scheduler
behavior, runtime denial, cross-path coverage, monitor enforcement, protection,
bounded wall-clock latency, performance, cost, deployment, and datacenter
readiness remain false.
