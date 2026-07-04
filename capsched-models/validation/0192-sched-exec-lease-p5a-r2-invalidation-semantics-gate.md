# Validation 0192: SchedExecLease P5A-R2 Invalidation Semantics Gate

Date: 2026-07-04

Status: passed for semantics/formal gate. No Linux patch is approved.

## Scope

Validate the P5A-R2 invalidation semantics gate after the source map in
validation/0191.

Artifacts:

```text
analysis/0149-sched-exec-lease-p5a-r2-invalidation-semantics-gate.md
analysis/sched-exec-lease-p5a-r2-invalidation-semantics-gate-v1.json
formal/0116-p5a-r2-invalidation-semantics-gate-model/
validation/run-sched-exec-lease-p5a-r2-invalidation-semantics-gate.sh
```

## Run

Command:

```text
RUN_ID=20260704T-p5a-r2-invalidation-semantics-gate \
  capsched/capsched-models/validation/run-sched-exec-lease-p5a-r2-invalidation-semantics-gate.sh
```

Result:

```text
status: passed
linux_commit: bd71af5daeae808ac948cbd12af2663151936f22
safe_passed: true
safe_states_generated: 6
safe_distinct_states: 5
safe_depth: 5
unsafe_expected_counterexamples: 23
```

Output directory:

```text
build/source-check/sched-exec-lease-p5a-r2-invalidation-semantics-gate/20260704T-p5a-r2-invalidation-semantics-gate/
```

## Validated Semantics

The gate defines four summary states:

```text
Fresh
Stale
Refreshing
Blocked
```

Only `Fresh` may be used as picker-visible eligibility proof.

The gate requires:

```text
leaf/current/group/monitor-revoke propagation
lock ownership for invalidation and refresh
refresh from frozen authority
generation/epoch recheck on refresh
budget/affinity recheck on refresh
stale/refreshing/blocked summaries block picker trust
group summary has no false positives
group summary has no silent false negatives
current entity is separate from rb-tree summary
no fresh summary means fail closed
stale cannot become fresh without refresh
enqueue/dequeue-only refresh is rejected
policy lookup and monitor calls in picker are rejected
outer Domain/SchedContext constraint is preserved
```

## Unsafe Counterexamples

The validator ran 23 unsafe configurations. Each produced the expected
`Safety` invariant violation:

```text
missing summary states
missing fresh/stale/blocked states
missing refreshing state
missing leaf propagation
missing current propagation
missing group propagation
missing monitor revoke propagation
missing lock ownership
missing frozen-authority refresh
missing epoch/generation refresh
missing budget/affinity refresh
picker trusts stale
picker trusts refreshing or blocked
group summary false positive
group summary silent false negative
current/tree collapse
missing fail-closed behavior
in-place stale-to-fresh
enqueue-only refresh
policy or monitor call in picker
missing outer Domain/SchedContext constraint
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

The next reviewable work is a P5A-R2 selector patch plan. It should remain a
source/design gate unless it also defines the object/layout/cost evidence and
negative runtime validation needed for any future Linux behavior patch.
