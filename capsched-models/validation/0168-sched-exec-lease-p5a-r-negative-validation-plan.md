# Validation 0168: SchedExecLease P5A-R Negative Validation Plan

Date: 2026-07-03

Status: source/formal validation-plan gate passed; safe model passed; 17 unsafe
configs produced expected counterexamples. No Linux behavior patch is approved.

## Scope

This validation checks:

```text
analysis/0141-sched-exec-lease-p5a-r-negative-validation-plan.md
analysis/sched-exec-lease-p5a-r-negative-validation-plan-v1.json
formal/0109-p5a-r-negative-validation-plan-model/P5ARNegativeValidationPlan.tla
```

## Runner

```text
validation/run-sched-exec-lease-p5a-r-negative-validation-plan.sh
```

Run output:

```text
build/source-check/sched-exec-lease-p5a-r-negative-validation-plan/20260703T222038Z/
```

## Checks

Source/plan checks:

```text
anchor_count=5
missing_anchor_count=0
line_drift_count=0
prior_missing_count=0
semantic_shape_ok=true
negative_test_family_count=14
required_observable_count=19
```

The runner verifies:

```text
P5A-R prior gates 0163..0167 are present
current P4 run edge is before rq->curr and sched_switch observations
current P4 run edge remains late relative to fair pick
negative families and observables are complete
claim flags remain false
```

Formal checks:

```text
safe_passed=true
safe_states_generated=6
safe_distinct_states=5
safe_depth=5
unsafe_expected_counterexamples=17
```

Unsafe cases reject missing:

```text
LateDenial
DeniedNotCurr
SameCandidate
RetryVisibility
IdleFallback
Eevdf
GroupHierarchy
ChildAlias
CrossPath
StaleIdentity
WakeupNewidle
Overhead
Observables
Layers
BehaviorBeforePlan
RuntimeClaim
CostProtectionClaim
```

## Result

P5A-R now has a negative validation plan requiring future behavior tests to
prove that denied candidates do not reach `rq->curr` or `sched_switch`, cannot
be repicked in the same attempt, do not over-deny parents, do not bypass EEVDF
return families, do not rely on unsupported cross paths, and do not introduce
unbounded/hot-layout regressions or claim overreach.

This closes the negative validation plan blocker at pre-code design level only.

## Non-Claims

This validation does not approve:

```text
Linux code changes
test instrumentation
runtime denial
CFS deny-and-repick implementation
runtime coverage
benchmark evidence
budget enforcement
public ABI or trace ABI
monitor calls or monitor verification
production protection
hypervisor-grade isolation
cost-efficiency
deployment readiness
datacenter readiness
```

## Next

Next P5A-R implementation-ready work:

```text
implementation patch plan
```
