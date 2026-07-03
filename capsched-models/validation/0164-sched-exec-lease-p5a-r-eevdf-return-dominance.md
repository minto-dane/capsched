# Validation 0164: SchedExecLease P5A-R EEVDF Return Dominance

Date: 2026-07-03

Status: source-shape checker passed; safe model passed; 11 unsafe configs
produced expected counterexamples. No Linux behavior patch is approved.

## Scope

This validation checks:

```text
analysis/0137-sched-exec-lease-p5a-r-eevdf-return-dominance.md
analysis/sched-exec-lease-p5a-r-eevdf-return-dominance-v1.json
formal/0105-p5a-r-eevdf-return-dominance-model/P5AREevdfReturnDominance.tla
```

## Runner

```text
validation/run-sched-exec-lease-p5a-r-eevdf-return-dominance.sh
```

Run output:

```text
build/source-check/sched-exec-lease-p5a-r-eevdf-return-dominance/20260703T085043Z/
```

## Checks

Machine-readable checks:

```text
jq empty analysis/sched-exec-lease-p5a-r-eevdf-return-dominance-v1.json
```

Claim checks:

```text
scope.linux_patch_approved=false
scope.behavior_change_approved=false
scope.runtime_denial_approved=false
scope.cfs_deny_and_repick_approved=false
scope.group_hierarchy_settlement_approved=false
all safety_flags are false
```

Source-shape checks:

```text
anchor_count=17
missing_anchor_count=0
line_drift_count=0
pick_eevdf_direct_return_count=4
pick_eevdf_semantic_candidate_families=6
forbidden_scan_count=0
semantic_shape_ok=true
```

The runner verifies that current `pick_eevdf()` has four syntactic direct
returns:

```text
singleton curr/first
next buddy
protected current
final best funnel
```

and six semantic candidate families:

```text
singleton curr/first
next buddy
protected current
leftmost eligible through best/found
heap-search result through best/found
final current override through best/found
```

It also verifies:

```text
pick_next_entity() calls pick_eevdf() before delayed dequeue handling
pick_next_entity() has a separate wakeup-preempt call context
pick_task_fair() schedule-pick path descends group_cfs_rq(se) before task_of(se)
line drift is diagnostic, not the main semantic gate
semantic drift blocks future P5A-R behavior patches
```

Formal checks:

```text
safe_passed=true
safe_states_generated=13
safe_distinct_states=7
safe_depth=2
unsafe_expected_counterexamples=11
```

## Result

P5A-R now has an executable source-shape checker for current EEVDF return
dominance. This closes the source half of the next gate:

```text
The current Linux commit has a known EEVDF return shape, and any future
deny-one-CFS-and-pick-next design must dominate singleton, buddy, protected
current, leftmost, heap-search, and final-current-override candidate families.
```

This does not approve implementation. Group hierarchy settlement remains the
next blocker.

## Non-Claims

This validation does not approve:

```text
Linux code changes
runtime denial
CFS deny-and-repick implementation
group hierarchy settlement
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

Next P5A-R model/design work:

```text
P5A-R group hierarchy settlement gate:
  LeafDenied
  PathDenied
  ChildCfsRqExhausted
  ParentSkipJustified
  ParentOverDenied as an explicit unsafe state
```
