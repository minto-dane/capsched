# Validation 0190: SchedExecLease P5A-R2 Selector Model Gate

Date: 2026-07-04

Status: passed for source/design/formal gate. No Linux patch is approved.

## Scope

Validate the P5A-R2 selector model gate after analysis/0146 and validation/0189.

Artifacts:

```text
analysis/0147-sched-exec-lease-p5a-r2-selector-model-gate.md
analysis/sched-exec-lease-p5a-r2-selector-model-gate-v1.json
formal/0114-p5a-r2-selector-model-gate-model/
validation/run-sched-exec-lease-p5a-r2-selector-model-gate.sh
```

## Run

Command:

```text
RUN_ID=20260704T-p5a-r2-selector-model-gate \
  capsched/capsched-models/validation/run-sched-exec-lease-p5a-r2-selector-model-gate.sh
```

Result:

```text
status: passed
linux_commit: bd71af5daeae808ac948cbd12af2663151936f22
anchor_count: 16
anchor_failures: 0
safe_passed: true
safe_states_generated: 6
safe_distinct_states: 5
safe_depth: 5
unsafe_expected_counterexamples: 21
```

Output directory:

```text
build/source-check/sched-exec-lease-p5a-r2-selector-model-gate/20260704T-p5a-r2-selector-model-gate/
```

## Validated Gate

The gate requires:

```text
picker-visible-before-selection
frozen-before-enqueue
task-local cache only
caller-independent cache
full invalidation model
task/exec/domain/grant generation and epoch model
budget/refill model
affinity/cpuset model
migration/group refresh model
monitor receipt/exit invalidation model
group hierarchy summary model
EEVDF-compatible min-pickable summary model
boolean-only summary rejection
current entity handling
fail-closed settlement
cross-path settlement or exclusion
CFS accounting separation
outer Domain/SchedContext constraint
no post-filter production design
no unbounded scan
no synthetic authority
no pick-time policy lookup
layout evidence requirement
benchmark evidence requirement
```

The EEVDF-compatible summary requirement is important: a boolean
"subtree has pickable work" is not enough for the current pruning structure.
The future design needs a `min_pickable_vruntime`-style infinite-sentinel
summary, or equivalent proof, before it can replace `0012`'s fallback shape.

## Unsafe Counterexamples

The validator ran 21 unsafe configurations. Each produced the expected
`Safety` invariant violation. The rejected families include:

```text
missing frozen-before-enqueue
caller-dependent cache
missing invalidation
missing generation/epoch
missing budget/affinity
missing migration/group refresh
missing receipt/exit invalidation
missing group summary
missing EEVDF min summary
boolean-only summary
missing current entity
missing fail-closed settlement
missing cross-path settlement
missing outer Domain/SchedContext constraint
post-filter production
unbounded scan
synthetic authority
pick-time policy lookup
Linux patch approval at this gate
hot layout approval at this gate
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

The next model-side step is a P5A-R2 invalidation source map. It should tie
each required invalidation event to concrete Linux source surfaces before any
new selector patch is drafted.
