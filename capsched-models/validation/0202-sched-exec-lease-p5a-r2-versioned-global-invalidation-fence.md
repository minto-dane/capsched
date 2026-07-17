# Validation 0202: SchedExecLease P5A-R2 Versioned Global Invalidation Fence

Date: 2026-07-13

Status: passed for conservative shared-invalidation architecture only. No
Linux patch, runtime behavior, protection, latency, performance, or cost claim
is approved.

## Scope

Validate:

```text
analysis/0156-sched-exec-lease-p5a-r2-versioned-global-invalidation-fence.md
analysis/sched-exec-lease-p5a-r2-versioned-global-invalidation-fence-v1.json
formal/0123-p5a-r2-versioned-global-invalidation-fence-model/
validation/run-sched-exec-lease-p5a-r2-versioned-global-invalidation-fence.sh
```

## Run

Command:

```text
RUN_ID=20260713T-p5a-r2-global-invalidation-fence \
  validation/run-sched-exec-lease-p5a-r2-versioned-global-invalidation-fence.sh
```

Result:

```text
status: passed_global_conservative_architecture_only
linux_commit: 077c948be39432971e7273b16b728172251129aa
linux_tree: 7ef04bf73d26b2813b10016b7eb342a618a66570
source anchors: 15
source anchor failures: 0
future absence checks: 4
future absence check failures: 0
safe TLC: 12 generated states, 10 distinct states, depth 8
unsafe expected counterexamples: 24
global projection generation required: true
all-online-rq fanout required: true
targeted fanout approved: false
```

Output:

```text
build/source-check/sched-exec-lease-p5a-r2-versioned-global-invalidation-fence/
  20260713T-p5a-r2-global-invalidation-fence/result.json
```

## Validated Architecture

After a shared event becomes locally published:

```text
write frozen shared state
release-publish a non-reused global projection generation
picker acquire-loads that generation
picker trusts a summary only when state is Fresh and built generation matches
queue rebuild work to every online rq after generation publication
rebuild all leaves, rb aggregates, separate current, and groups under rq lock
recheck generation before Fresh publication
keep Stale/Blocked and retry if publication raced the rebuild
```

Generation mismatch prevents trust before asynchronous fanout reaches the rq.
This makes safety independent of fanout latency after local publication. The
reached task still receives final Fresh revalidation.

The safe model explores two commit paths:

```text
stable rebuild:
  complete target generation is published Fresh

publication racing rebuild:
  old target generation remains Stale and is not trusted
```

## Expected Absence

The source check confirms the proposed global generation, per-rq built
generation, all-rq fanout, and full summary rebuild helpers do not already
exist under their reserved names. This is a design gate, not an implementation
claim.

## Deliberate Tradeoff

The baseline invalidates every protected rq for any shared eligibility event.
It can temporarily block unrelated domains and requires a full O(n) rebuild
under each rq lock. That is conservative and easy to reason about, but is not
yet an acceptable production latency/cost result.

Targeted fanout remains rejected until a domain/SchedContext-to-rq membership
index, enqueue/dequeue accounting, publication/insertion handshake, migration
settlement, lifetime rules, and no-missed-rq proof exist.

The contract begins at local Linux publication. It does not prove external
monitor receipt authenticity or delivery latency.

## Unsafe Counterexamples

The 24 rejected families cover:

```text
missing generation fence or release/acquire ordering
picker skipping generation
missing all-rq fanout or rq lock
partial rebuild or missing post-rebuild generation recheck
generation wrap reuse
missing final entity recheck
picker scan or monitor call
per-pick selector generation
targeted fanout without index proof
non-conservative invalidation
domain, budget, monitor, or refill bypassing the fence
missing normal queue-mutation integration
missing fail-Blocked saturation
Linux patch, runtime, protection, or cost overclaim
```

## Non-Claims

This validation does not approve:

```text
Linux code changes
new hot scheduler fields
runtime behavior changes
cross-path runtime settlement
runtime denial correctness
runtime coverage
monitor delivery or enforcement
production protection
bounded rq-lock hold time
performance or cost efficiency
deployment readiness
datacenter readiness
```

## Next

Create the P5A-R2 global-fence data-layout and rebuild evidence plan before any
source prototype or behavior patch is reviewed.
