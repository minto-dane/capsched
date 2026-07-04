# Validation 0191: SchedExecLease P5A-R2 Invalidation Source Map

Date: 2026-07-04

Status: passed for source/design/formal gate. No Linux patch is approved.

## Scope

Validate the P5A-R2 invalidation source map after the selector model gate in
validation/0190.

Artifacts:

```text
analysis/0148-sched-exec-lease-p5a-r2-invalidation-source-map.md
analysis/sched-exec-lease-p5a-r2-invalidation-source-map-v1.json
formal/0115-p5a-r2-invalidation-source-map-model/
validation/run-sched-exec-lease-p5a-r2-invalidation-source-map.sh
```

## Run

Command:

```text
RUN_ID=20260704T-p5a-r2-invalidation-source-map \
  capsched/capsched-models/validation/run-sched-exec-lease-p5a-r2-invalidation-source-map.sh
```

Result:

```text
status: passed
linux_commit: bd71af5daeae808ac948cbd12af2663151936f22
anchor_count: 41
anchor_failures: 0
safe_passed: true
safe_states_generated: 7
safe_distinct_states: 6
safe_depth: 6
unsafe_expected_counterexamples: 17
```

Output directory:

```text
build/source-check/sched-exec-lease-p5a-r2-invalidation-source-map/20260704T-p5a-r2-invalidation-source-map/
```

## Validated Source Families

The source map covers:

```text
lifecycle reset
fork generation
exec generation
exit invalidation
affinity mask changes
queued moves
set_task_cpu
fair migration
cgroup task movement
cpuset effective-cpumask update
budget charge
CFS throttle
CFS unthrottle/refill
current entity handling
group summary handling
future monitor receipt revoke
locking boundary
no enqueue/dequeue-only assumption
```

## Design Result

The important result is negative and useful:

```text
updating a future picker-visible lease summary only on enqueue/dequeue is
not sufficient
```

A future P5A-R2 selector patch must either update affected leaf/current/group
summaries or mark them stale across all mapped source families before the CFS
picker can trust the summary.

## Unsafe Counterexamples

The validator ran 17 unsafe configurations. Each produced the expected
`Safety` invariant violation:

```text
missing lifecycle map
missing fork/exec/exit map
missing affinity map
missing queued move map
missing set_task_cpu map
missing fair migration map
missing cgroup movement map
missing cpuset update map
missing budget charge map
missing throttle/refill map
missing current entity map
missing group summary map
missing monitor receipt future map
missing lock boundary
enqueue/dequeue-only assumption
Linux patch approval at this gate
runtime/protection/cost/datacenter overclaim
```

## Non-Claims

This validation does not approve:

```text
Linux code changes
accepting 0009-0012
runtime denial correctness
complete CFS deny-and-repick correctness
runtime coverage
hot layout changes
new public ABI
monitor enforcement
production protection
cost efficiency
deployment readiness
datacenter readiness
```

## Next

The next model-side step is the P5A-R2 invalidation semantics gate:

```text
define stale versus refreshed summary states
define affected leaf/current/group propagation
define lock ownership per invalidation family
define future monitor receipt revoke integration
```
