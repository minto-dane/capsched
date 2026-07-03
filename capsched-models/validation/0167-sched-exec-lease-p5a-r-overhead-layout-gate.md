# Validation 0167: SchedExecLease P5A-R Overhead and Layout Gate

Date: 2026-07-03

Status: source/formal gate passed; safe model passed; 18 unsafe configs
produced expected counterexamples. No Linux behavior patch is approved.

## Scope

This validation checks:

```text
analysis/0140-sched-exec-lease-p5a-r-overhead-layout-gate.md
analysis/sched-exec-lease-p5a-r-overhead-layout-gate-v1.json
formal/0108-p5a-r-overhead-layout-gate-model/P5AROverheadLayoutGate.tla
```

## Runner

```text
validation/run-sched-exec-lease-p5a-r-overhead-layout-gate.sh
```

Run output:

```text
build/source-check/sched-exec-lease-p5a-r-overhead-layout-gate/20260703T221311Z/
```

## Checks

Claim checks:

```text
scope.linux_patch_approved=false
scope.behavior_change_approved=false
scope.runtime_denial_approved=false
scope.cfs_deny_and_repick_approved=false
scope.hot_layout_change_approved=false
scope.disabled_overhead_change_approved=false
scope.performance_claim_approved=false
all safety_flags are false
```

Source-shape checks:

```text
anchor_count=22
missing_anchor_count=0
line_drift_count=0
semantic_shape_ok=true
allow_return_count=3
non_allow_return_count=0
branch_on_validation_count=0
```

The runner verifies:

```text
current validation helpers return ALLOW only
current scheduler code does not branch on validation result
task_struct.sched_exec remains CONFIG_SCHED_EXEC_LEASE-gated
hot task/rq/cfs_rq/sched_entity structures are explicitly identified
pick_eevdf source shape remains current
prior P5A0.P1 object/layout evidence is referenced
```

Formal checks:

```text
safe_passed=true
safe_states_generated=6
safe_distinct_states=5
safe_depth=5
unsafe_expected_counterexamples=18
```

Unsafe cases reject:

```text
LinearRbTreeScan
FullHierarchyScan
DomainTableLookup
UnboundedRetry
PersistentTaskBit
PersistentEntityBit
PersistentRqField
PersistentCfsRqField
PerCgroupMap
AllocationInPicker
SleepOrMonitorInPicker
PolicyLookupInPicker
DisabledBranchNoEvidence
DisabledObjectGrowth
TaskLayoutChangeNoGate
HotFunctionGrowthNoEvidence
BehaviorOverclaim
CostProtectionClaim
```

## Result

P5A-R now has a pre-code overhead/layout gate:

```text
attempt-local carrier
fixed retry budget
fixed denied receipt capacity
pre-frozen authority tuple
candidate identity compare only
no unbounded scan
no persistent hot denial layout
no picker allocation/sleep/monitor/policy lookup
no disabled overhead or hot function/layout claim without object evidence
```

This closes the no-O(n)/no-hot-layout/disabled-overhead blocker at pre-code
design level only. It does not approve a Linux behavior patch.

## Non-Claims

This validation does not approve:

```text
Linux code changes
runtime denial
CFS deny-and-repick implementation
hot-layout changes
disabled-overhead changes
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
negative validation plan
implementation patch plan
```
