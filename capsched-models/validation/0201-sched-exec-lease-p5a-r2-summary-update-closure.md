# Validation 0201: SchedExecLease P5A-R2 Summary Update Closure

Date: 2026-07-13

Status: passed for source/locking/formal closure map, with shared invalidation
mechanism unresolved and the Linux behavior patch blocked.

## Scope

Validate:

```text
analysis/0155-sched-exec-lease-p5a-r2-summary-update-closure-map.md
analysis/sched-exec-lease-p5a-r2-summary-update-closure-map-v1.json
formal/0122-p5a-r2-summary-update-closure-model/
validation/run-sched-exec-lease-p5a-r2-summary-update-closure.sh
```

The gate covers rb mutation, current transitions, hierarchy projection,
lifecycle/generation, budget, placement/migration, throttle/refill,
domain/grant epoch, future monitor revoke, and outer selector generation.

## Run

Command:

```text
RUN_ID=20260713T-p5a-r2-summary-update-closure \
  validation/run-sched-exec-lease-p5a-r2-summary-update-closure.sh
```

Result:

```text
status: passed_with_shared_invalidation_blocker
linux_commit: 077c948be39432971e7273b16b728172251129aa
linux_tree: 7ef04bf73d26b2813b10016b7eb342a618a66570
source anchors: 32
source anchor failures: 0
future absence checks: 4
future absence check failures: 0
event families: 10
safe TLC: 71 generated states, 61 distinct states, depth 7
unsafe expected counterexamples: 24
shared invalidation missing mechanisms: 6
shared invalidation mechanism resolved: false
behavior patch blocked: true
```

Output:

```text
build/source-check/sched-exec-lease-p5a-r2-summary-update-closure/
  20260713T-p5a-r2-summary-update-closure/result.json
```

## Proven Source Boundary

The source checker pins the current EEVDF augmentation, separate-current
transitions, group descent and parent linkage, task birth, exec/exit identity
mutations, affinity and queued movement, cgroup movement, CFS runtime charge,
and throttle/unthrottle publication to the recreated Linux commit.

The absence checks confirm that the following proposed mechanisms are not
already present under the reserved names:

```text
sched_exec_refresh_cfs_summary
sched_exec_apply_monitor_receipt
sched_exec_receipt_generation
sched_exec_domain_runnable
```

This absence is expected. It prevents the source map from being mistaken for
an implemented closure.

## Validated Contract

The gate requires:

```text
on-rq summary mutation under the owning rq lock
node aggregate distinct from cfs_rq tree-or-current witness
child cfs_rq witness projected through every parent group entity
validity and wrap-aware numeric minimum compared together
old-rq invalidation before migration unlock
no contribution during the moving interval
destination publication only after locked activation and Fresh validation
exec/exit identity mutation followed by scheduler-owned locked invalidation
budget/throttle invalidation before picker trust
refill/unthrottle revalidation only after state settlement
summary keyed or generation-stamped for its outer selector
final reached-task Fresh revalidation
no picker repair scan, policy lookup, or monitor call
```

The model's 24 unsafe configurations independently remove one closure or add a
forbidden shortcut/claim. Each produced the expected `Safety` counterexample.

## Discovered Blocker

The current scaffold has no runtime authority publication, domain-to-runnable
membership index, per-rq receipt generation, shared budget fanout, monitor
revoke fanout, or outer-selector generation protocol. A task-local rb/current
refresh helper cannot close a shared domain/grant/budget/revoke event by
itself.

Therefore an implementation that adds only hot summary fields and picker
checks is not reviewable. The shared event needs a versioned per-rq receipt or
indexed fanout contract that makes affected summaries conservatively invalid
before they can be trusted again.

## Non-Claims

This validation does not approve:

```text
Linux code changes
new hot scheduler fields
runtime behavior changes
accepting experimental patches 0009-0012 as production design
runtime denial correctness
complete CFS deny-and-repick correctness
runtime coverage
monitor enforcement
production protection
performance or cost efficiency
deployment readiness
datacenter readiness
```

## Next

Define and model the P5A-R2 versioned shared invalidation and fanout contract
for domain/grant epochs, shared budget transitions, future monitor receipts,
and outer Domain/SchedContext selector generations.
