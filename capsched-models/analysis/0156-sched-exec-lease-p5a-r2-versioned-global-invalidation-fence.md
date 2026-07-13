# Analysis 0156: SchedExecLease P5A-R2 Versioned Global Invalidation Fence

Date: 2026-07-13

Status: shared-invalidation architecture gate. No Linux patch, hot field, or
runtime/protection claim is approved.

## Decision

Validation/0201 found that a task-local rb/current/group refresh path cannot
close domain/grant epoch, shared budget, future monitor-revoke, or outer
selector-configuration changes. This gate chooses a conservative L0 baseline:

```text
one locally published global projection generation
per-rq built generation and semantic state
O(1) generation fence before picker trust
all-online-rq rebuild fanout outside the picker
full rq-locked rebuild before Fresh publication
```

The baseline deliberately invalidates more work than necessary. It does not
require a domain-to-runnable index and does not pretend to have targeted
fanout. This trades availability and control-path cost for a simple safety
boundary that can be modeled before a production bucket/index design exists.

## Scope Boundary

The fence starts when a shared event is *locally published* to the Linux
scheduler projection. It does not prove how quickly an external monitor
delivers a revoke to Linux. Monitor delivery authenticity, latency, and
independent enforcement remain future DomainLease-H obligations.

The generation is a cache-coherence fence, not authority. Frozen task-local
state, domain/grant receipts, budget state, and final task validation remain
the decision inputs.

## Publication Protocol

A serialized publisher handles these eligibility-boundary events:

```text
domain epoch or grant generation change
shared SchedContext/root budget exhausted or refilled
locally received future monitor revoke/refresh receipt
outer bucket/topology/configuration generation change
```

Only transitions that can change Fresh eligibility require a generation bump.
Ordinary budget decrements above the eligibility threshold do not.

Publication order:

```text
1. serialize the shared-state update
2. write the new frozen receipt/budget/configuration state
3. compute next projection generation without wrap reuse
4. release-publish the new generation
5. queue rebuild work for every online rq
```

The generation must not wrap to a previously trusted value. At saturation the
projection enters `Blocked` and requires an explicitly quiescent reinitialization
protocol; it must not silently roll over.

## Picker Fence

Each rq owns provisional state equivalent to:

```text
built_generation
summary_state = Fresh | Stale | Refreshing | Blocked
```

Before any SchedExecLease summary is used as pruning proof, the picker performs
an acquire load of the locally published projection generation and requires:

```text
summary_state == Fresh
and
built_generation == published_generation
```

A mismatch is effectively `Stale` even if the asynchronous per-rq worker has
not yet changed the stored semantic state. Therefore safety does not depend on
fanout latency. The picker fails closed for that protected projection; it does
not scan, rebuild, allocate, sleep, call policy, or call the monitor.

The reached task is still revalidated against the same frozen generation and
task-local identity. The generation fence prevents trust in an old aggregate;
the final check prevents an aggregate from becoming authority.

When the feature/static key is inactive, ordinary Linux scheduling remains
outside this proposed fence. No disabled-overhead claim is made until a
concrete patch is measured.

## Per-rq Rebuild

After global publication, work is queued for every online rq. The baseline
does not use targeted domain fanout.

For each rq:

```text
lock rq
snapshot published_generation as target_generation
mark the protected projection Refreshing and untrusted
revalidate every contributing leaf from frozen local inputs
rebuild rb-node aggregates bottom-up
recompute the separate current witness
recompute child-to-parent group projections to the root
re-read published_generation
if generation changed:
  keep Stale/Blocked, unlock, and retry later
else if the complete rebuild succeeded:
  publish built_generation = target_generation and state = Fresh or Blocked
unlock rq
```

No partial tree may be published Fresh. The rebuild path may not call external
policy or monitor code, allocate with sleeping semantics, or reuse PELT
propagation as Fresh propagation.

A full O(n) rebuild while holding the rq lock is intentionally only a safety
baseline. It is not approved as a performance design. Chunked rebuild would
need its own cursor lifetime, mutation sequence, restart, and partial-state
model before it could replace this baseline.

## Concurrent Queue Mutation

Normal enqueue, dequeue, current, group, cgroup, affinity, and migration paths
remain rq-lock owned. They may incrementally maintain a Fresh summary only
when:

```text
rq.summary_state == Fresh
and
rq.built_generation == acquire_load(published_generation)
```

If generations do not match, the mutation must preserve Stale/Refreshing/
Blocked and must not make one node or ancestor Fresh. A destination migration
publication uses the destination rq's current generation after locked
activation. The old rq loses its contribution before unlock as required by
validation/0201.

Because the global fence invalidates every rq immediately by generation
mismatch, an enqueue racing publication cannot create a trusted old-generation
node even before its rq worker runs.

## Why Global Before Targeted

Targeted fanout would need all of the following:

```text
domain/SchedContext-to-runnable-rq membership index
enqueue/dequeue reference accounting
publication-versus-index insertion handshake
migration old/new-rq settlement
object lifetime and RCU/refcount ownership
proof that no affected rq is missed
```

None exists in the current scaffold. A guessed cpumask is not a safety proof.
Until that protocol is separately modeled, a targeted event is rejected. The
L0 baseline broadcasts to every online rq and accepts explicit false negatives
while summaries are Stale or Refreshing.

## Outer Selector Constraint

The global generation is bumped for changes to outer bucket topology,
membership rules, or frozen selector configuration. It is **not** bumped for
each ordinary choice of a Domain/SchedContext at pick time.

The long-horizon Candidate C shape remains:

```text
outer selector chooses an already constructed execution bucket
inner CFS summary belongs to that bucket/configuration generation
```

Using the global generation as a per-pick selector key would invalidate every
rq continuously and is rejected. The current Candidate A work remains a local
projection only; it does not implement Candidate C.

## Safety and Liveness Boundary

The fence guarantees only the modeled cache rule after local publication:

```text
old-generation summary is never trusted as Fresh
partial or raced rebuild is never published Fresh
```

It intentionally allows explicit temporary false negatives:

```text
unaffected domains can be blocked by a global generation bump
an rq remains unavailable to the protected projection until rebuild completes
rapid publications can repeatedly restart rebuild
```

These are availability and cost problems, not hidden correctness. Production
work must later choose between bounded global rebuild, bucket-local summaries,
or a proven targeted index/fanout. No liveness, latency, throughput, or cost
claim is approved here.

## Rejected Variants

```text
trusting only summary_state without comparing generation
relaxed publication without a release/acquire receipt order
generation wrap reuse
fanout first and generation publication later
picker trust while built_generation differs
partial rebuild published Fresh
Fresh publication without rechecking generation after rebuild
picker-side scan or rebuild
monitor or policy call in picker/rebuild
targeted fanout without a proven membership index and insertion handshake
using selector generation as a per-pick counter
silently flipping Stale/Refreshing to Fresh
```

## Non-Claims

This architecture gate does not approve:

```text
Linux code changes
new hot scheduler fields
runtime behavior changes
accepting experimental patches 0009-0012 as production design
cross-path runtime settlement
runtime denial correctness
runtime coverage
monitor delivery or enforcement
production protection
rebuild latency or bounded lock hold time
performance or cost efficiency
deployment readiness
datacenter readiness
```

## Next

Create a P5A-R2 global-fence data-layout and rebuild evidence plan. It must
measure the proposed per-rq fields, define a source-only full-rebuild prototype
boundary, place generation checks on every relevant selection path, and set an
explicit maximum acceptable rq-lock hold time before any behavior patch is
reviewable.
