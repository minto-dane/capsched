# Validation 0165: SchedExecLease P5A-R Group Hierarchy Settlement

Date: 2026-07-03

Status: source/formal gate passed; safe model passed; 13 unsafe configs
produced expected counterexamples. No Linux behavior patch is approved.

## Scope

This validation checks:

```text
analysis/0138-sched-exec-lease-p5a-r-group-hierarchy-settlement.md
analysis/sched-exec-lease-p5a-r-group-hierarchy-settlement-v1.json
formal/0106-p5a-r-group-hierarchy-settlement-model/P5ARGroupHierarchySettlement.tla
```

## Runner

```text
validation/run-sched-exec-lease-p5a-r-group-hierarchy-settlement.sh
```

Run output:

```text
build/source-check/sched-exec-lease-p5a-r-group-hierarchy-settlement/20260703T214938Z/
```

## Checks

Machine-readable checks:

```text
jq empty analysis/sched-exec-lease-p5a-r-group-hierarchy-settlement-v1.json
```

Claim checks:

```text
scope.linux_patch_approved=false
scope.behavior_change_approved=false
scope.runtime_denial_approved=false
scope.cfs_deny_and_repick_approved=false
scope.group_hierarchy_implementation_approved=false
all safety_flags are false
```

Source-shape checks:

```text
anchor_count=21
missing_anchor_count=0
line_drift_count=0
semantic_shape_ok=true
```

The runner verifies the current Linux hierarchy shape:

```text
entity_is_task(se) defines task-vs-group by se->my_q
task_of(se) warns on group entity
group_cfs_rq(se) returns child runqueue
pick_task_fair() starts at rq->cfs
pick_task_fair() descends through group_cfs_rq(se)
task_of(se) occurs only after hierarchy descent
pick_next_entity() delayed-dequeue NULL remains separate from child exhaustion
put_prev_set_next_task() settlement follows pick_task_fair()
set_next_task_fair() walks ancestors
set_next_entity() writes cfs_rq->curr
```

Formal checks:

```text
safe_passed=true
safe_states_generated=9
safe_distinct_states=7
safe_depth=5
unsafe_expected_counterexamples=13
```

Unsafe cases reject:

```text
ParentOverDenied
SkipWithoutExhaustion
SameDeniedLeafRepicked
TaskOfGroupEntity
NrQueuedAlias
SleepAlias
ThrottleAlias
DelayedDequeueAlias
YieldAlias
EevdfLagAlias
PathEvidenceAuthority
CrossPathOverclaim
BehaviorOverclaim
```

## Result

P5A-R now has a model/source gate for group hierarchy settlement:

```text
leaf denial does not imply parent group skip
parent skip requires explicit child cfs_rq exhaustion
allowed sibling descendants must remain pickable
child exhaustion cannot be represented by Linux accounting aliases
```

This closes the hierarchy-settlement blocker at pre-code design level only. It
does not approve a Linux behavior patch.

## Non-Claims

This validation does not approve:

```text
Linux code changes
runtime denial
CFS deny-and-repick implementation
group hierarchy implementation
core/DL/proxy/SCX settlement
broad move denial
runtime coverage
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
core/DL/proxy/SCX exclusion-or-settlement gate
no-O(n)/no-hot-layout/disabled-overhead gate
negative validation plan
implementation patch plan
```
