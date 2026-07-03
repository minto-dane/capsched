# Validation 0163: SchedExecLease P5A-R Picker Ineligibility Gate

Date: 2026-07-03

Status: source/JSON gate passed; safe model passed; 28 unsafe configs produced
expected counterexamples. No Linux behavior patch is approved.

## Scope

This validation checks:

```text
analysis/0136-sched-exec-lease-p5a-r-picker-ineligibility-gate.md
analysis/sched-exec-lease-p5a-r-picker-ineligibility-gate-v1.json
formal/0104-p5a-r-picker-ineligibility-gate-model/P5ARPickerIneligibilityGate.tla
```

## Runner

```text
validation/run-sched-exec-lease-p5a-r-picker-ineligibility-gate.sh
```

Run output:

```text
build/source-check/sched-exec-lease-p5a-r-picker-ineligibility-gate/20260703T032258Z/
```

## Checks

Machine-readable checks:

```text
jq empty analysis/sched-exec-lease-p5a-r-picker-ineligibility-gate-v1.json
```

Claim checks:

```text
scope.linux_patch_approved=false
scope.behavior_change_approved=false
scope.runtime_denial_approved=false
scope.cfs_deny_and_repick_approved=false
all safety_flags are false
```

Required-shape checks:

```text
attempt-local denied-candidate carrier
rq-lock protected attempt
pre-class-state settlement
pre-rq-curr publication
picker-visible ineligibility
fresh allowed candidate requirement
bounded retry
fail-closed or explicit quarantine when no allowed candidate exists
no linear candidate search
no unbounded retry
no persistent hot denial layout in first candidate
wakeup-preempt bleed prevention
newidle lock-drop carrier clear/version rule
task/exec/domain/grant generation keys
hierarchy and cgroup mutation settlement
all pick_eevdf return paths covered
core sequence and hotplug settlement or exclusion
DL-server settlement, including RETRY_TASK/rq->dl_server leakage
proxy and sched_ext settlement or exclusion
accounting/lifetime separation from delayed dequeue and throttling limbo
Linux-local state cannot mint positive run authority
```

Source-anchor checks:

```text
anchor_count=15
anchor_failures=0
```

Formal checks:

```text
safe_passed=true
safe_states_generated=6
safe_distinct_states=5
safe_depth=5
unsafe_expected_counterexamples=28
```

## Result

P5A-R now has a stronger pre-code gate for the narrow question:

```text
Can a future ordinary-CFS-only patch deny one CFS candidate and pick another
without using late denial, Linux retry sentinels, scheduler accounting aliases,
hot persistent layout state, or unsupported core/DL/proxy/SCX paths as
authority?
```

The answer is still not implementation approval. The gate only records the
minimum conditions that a later patch must satisfy.

## Non-Claims

This validation does not approve:

```text
Linux code changes
runtime denial
CFS deny-and-repick implementation
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

The next P5A-R model/design work should produce:

```text
source-shape checker for EEVDF return dominance
group hierarchy settlement model
core/DL/proxy/SCX path classification update
future Linux patch plan with exact touched files and upstream drift gate
```
