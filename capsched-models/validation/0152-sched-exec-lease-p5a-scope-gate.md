# Validation 0152: SchedExecLease P5A Scope Gate

Date: 2026-07-02

Status: source/JSON gate passed; safe model passed; unsafe models produced
expected counterexamples; P5 Linux implementation remains unapproved.

## Scope

This validation checks:

```text
analysis/0130-sched-exec-lease-p5a-scope-proposal.md
analysis/sched-exec-lease-p5a-scope-proposal-v1.json
implementation/0028-sched-exec-lease-p5a-scope-proposal.md
implementation/sched-exec-lease-p5a-scope-proposal-v1.json
formal/0099-p5a-scope-gate-model/
validation/run-sched-exec-lease-p5a-scope-gate.sh
```

It records a scope gate only. It does not approve Linux code.

## Source / JSON Gate

Command:

```sh
DOMAINLEASE_RUN_ID=20260702T-p5a-scope \
  capsched/capsched-models/validation/run-sched-exec-lease-p5a-scope-gate.sh
```

Result:

```text
run_dir=build/source-check/sched-exec-lease-p5a-scope-gate/20260702T-p5a-scope
work_commit_matches=true
p5a_scope_recorded=true
p5a_decomposed=true
first_patch_may_change_behavior=false
p5_linux_implementation_approved=false
runtime_denial_approved=false
deny_one_cfs_pick_next_approved=false
broad_common_move_denial_approved=false
production_protection=false
cost_efficiency_claim=false
```

## Formal Gate

Model:

```text
formal/0099-p5a-scope-gate-model/
```

Safe result:

```text
Model checking completed. No error has been found.
2 states generated, 1 distinct state found.
```

Unsafe configs:

```text
P5AScopeGateUnsafeBehaviorInP5A0.cfg
P5AScopeGateUnsafeBroadMoveDenialWithoutStatusSettlement.cfg
P5AScopeGateUnsafeCostOrDeploymentClaim.cfg
P5AScopeGateUnsafeDenyOnePickNextWithoutFairEligibility.cfg
P5AScopeGateUnsafeLinuxImplementationApproved.cfg
P5AScopeGateUnsafeMissingNegativeTests.cfg
P5AScopeGateUnsafeNoDecomposition.cfg
P5AScopeGateUnsafeProtectionClaim.cfg
P5AScopeGateUnsafeRunDenyAtP4Hook.cfg
P5AScopeGateUnsafeUnsupportedPathClaim.cfg
```

Unsafe result:

```text
expected_counterexamples=10
unexpected=0
```

## Meaning

The scope proposal is accepted as a planning artifact:

```text
P5A is decomposed into P5A0, P5A-R, P5A-M, and P5A-V.
P5A0 is no-behavior only.
Linux implementation is not approved.
Runtime denial is not approved.
```

Additional sharpened conclusions:

```text
deny-one-CFS-and-pick-next requires fair-picker eligibility integration.
broad common move denial requires status settlement across migration, affinity,
swap, push, and core-cookie-steal paths.
```

## Next Reviewable Work

The next reviewable work is a P5A0 no-behavior infrastructure proposal:

```text
status plumbing shape
test harness shape
setup-time disabled-path shape
claim ledger shape
fresh upstream drift row
```

It is not a behavior-changing patch.

## Non-Claims

This validation does not approve Linux code changes, behavior changes, runtime
denial, retry, fail-closed behavior, quarantine, ABI, monitor calls, monitor
verification, runtime coverage, production protection, hypervisor-grade
isolation, cost-efficiency, deployment readiness, or datacenter readiness.
