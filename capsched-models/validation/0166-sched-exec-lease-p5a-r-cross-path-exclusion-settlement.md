# Validation 0166: SchedExecLease P5A-R Cross-Path Exclusion/Settlement

Date: 2026-07-03

Status: source/formal gate passed; safe model passed; 18 unsafe configs
produced expected counterexamples. No Linux behavior patch is approved.

## Scope

This validation checks:

```text
analysis/0139-sched-exec-lease-p5a-r-cross-path-exclusion-settlement.md
analysis/sched-exec-lease-p5a-r-cross-path-exclusion-settlement-v1.json
formal/0107-p5a-r-cross-path-exclusion-settlement-model/P5ARCrossPathExclusionSettlement.tla
```

## Runner

```text
validation/run-sched-exec-lease-p5a-r-cross-path-exclusion-settlement.sh
```

Run output:

```text
build/source-check/sched-exec-lease-p5a-r-cross-path-exclusion-settlement/20260703T220432Z/
```

## Checks

Machine-readable checks:

```text
jq empty analysis/sched-exec-lease-p5a-r-cross-path-exclusion-settlement-v1.json
```

Claim checks:

```text
scope.linux_patch_approved=false
scope.behavior_change_approved=false
scope.runtime_denial_approved=false
scope.cfs_deny_and_repick_approved=false
scope.cross_path_behavior_patch_approved=false
scope.core_settlement_approved=false
scope.deadline_server_settlement_approved=false
scope.proxy_settlement_approved=false
scope.sched_ext_settlement_approved=false
all safety_flags are false
```

Source-shape checks:

```text
anchor_count=34
missing_anchor_count=0
line_drift_count=0
semantic_shape_ok=true
```

The runner verifies the current Linux cross-path shape:

```text
__pick_next_task() avoids the fair fast path when scx_enabled()
ordinary fair fast path calls pick_task_fair() and then put_prev_set_next_task()
the class loop can call arbitrary active class pick_task()
pick_next_task() wraps __pick_next_task() under sched_core_enabled()
core scheduling can reuse rq->core_pick
core scheduling can pick sibling runqueues and replace picks by cookie
try_steal_cookie() can move a queued task
deadline server entities call server_pick_task()
fair_server_pick_task() calls pick_task_fair()
ext_server_pick_task() calls do_pick_task_scx(..., force_scx=true)
put_prev_set_next_task() propagates rq->dl_server into next->dl_server
proxy execution sets rq->donor and can rewrite next via find_proxy_task()
scx_switched_all() can skip fair_sched_class
ext_sched_class.pick_task is pick_task_scx()
```

Formal checks:

```text
safe_passed=true
safe_states_generated=5
safe_distinct_states=4
safe_depth=4
unsafe_expected_counterexamples=18
```

Unsafe cases reject:

```text
CoreUnsettled
CoreCachedPick
CoreSiblingPick
CoreCookieReplacement
CoreCookieSteal
DlUnsettled
DlFairBorrow
DlExtBorrow
ProxyUnsettled
ProxyMismatch
ScxUnsettled
ScxSwitchedAll
ScxAuthorityRoot
ClassLoopUnsettled
ClassLoopUnsupported
RetryTaskDenial
BehaviorOverclaim
ProtectionCostClaim
```

## Result

P5A-R now has a model/source gate requiring every non-ordinary-CFS scheduler
path to be excluded or separately settled before ordinary-CFS deny-one-pick-next
semantics are claimed.

This closes the core/DL/proxy/SCX exclusion-or-settlement blocker at pre-code
design level only. It does not approve a Linux behavior patch.

## Non-Claims

This validation does not approve:

```text
Linux code changes
runtime denial
CFS deny-and-repick implementation
core scheduling settlement
deadline server settlement
proxy execution settlement
sched_ext settlement
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
no-O(n)/no-hot-layout/disabled-overhead gate
negative validation plan
implementation patch plan
```
