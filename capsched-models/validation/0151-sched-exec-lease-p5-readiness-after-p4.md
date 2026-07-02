# Validation 0151: SchedExecLease P5 Readiness After P4

Date: 2026-07-02

Status: source-order checker passed; safe model passed; unsafe models produced
expected counterexamples; P5 remains blocked.

## Scope

This validation checks:

```text
analysis/0129-sched-exec-lease-p5-readiness-refresh-after-p4.md
analysis/sched-exec-lease-p5-readiness-refresh-after-p4-v1.json
formal/0098-p5-readiness-after-p4-gate-model/
validation/run-sched-exec-lease-p5-readiness-after-p4.sh
```

It validates the actual post-P4 Linux tree:

```text
linux_commit: a937c67f51d1b82297c4f8b7c471f63e8f1a4fe8
subject: sched/exec_lease: Add allow-only validation skeleton
```

## Source-Order Checker

Command:

```sh
DOMAINLEASE_RUN_ID=20260702T-p5-readiness-after-p4 \
  capsched/capsched-models/validation/run-sched-exec-lease-p5-readiness-after-p4.sh
```

Result:

```text
run_dir=build/source-check/sched-exec-lease-p5-readiness-after-p4/20260702T-p5-readiness-after-p4
work_commit_matches=true
helpers_allow_only=true
scheduler_branches_on_validation_result=false
run_hook_before_rq_curr=true 7199<7207
run_hook_before_context_switch=true 7199<7241
run_hook_after_pick_next_task=true 7154<7199
run_hook_after_resched_clear=true 7194<7199
known_class_settlement_before_run_hook_source=true 6157,6453<7199
run_hook_p5_deny_ready=false
common_move_hook_before_mutation=true 2552<2554,2555
locked_move_hook_before_mutation=true 4125<4127,4128
common_move_returns_status=false
locked_move_returns_status=false
common_move_call_count=2
locked_move_call_count=4
p5_approved=false
runtime_denial_approved=false
runtime_coverage_claim=false
production_protection_claim=false
```

## Formal Gate

Model:

```text
formal/0098-p5-readiness-after-p4-gate-model/
```

Safe command:

```sh
java -cp /home/nia/tools/tla/tla2tools.jar \
  tlc2.TLC \
  -metadir build/tlc/p5-readiness-after-p4-20260702T1842Z/safe \
  -config P5ReadinessAfterP4GateSafe.cfg \
  P5ReadinessAfterP4Gate.tla
```

Safe result:

```text
Model checking completed. No error has been found.
2 states generated, 1 distinct state found.
```

Unsafe configs:

```text
P5ReadinessAfterP4GateUnsafeCostOrDeploymentClaim.cfg
P5ReadinessAfterP4GateUnsafeNoSourceCheck.cfg
P5ReadinessAfterP4GateUnsafeP5ApprovedWithPostSettleRunHook.cfg
P5ReadinessAfterP4GateUnsafeP5ApprovedWithoutMoveStatus.cfg
P5ReadinessAfterP4GateUnsafeP5ApprovedWithoutNegativeTests.cfg
P5ReadinessAfterP4GateUnsafeP5ApprovedWithoutPathClassification.cfg
P5ReadinessAfterP4GateUnsafeProtectionClaim.cfg
P5ReadinessAfterP4GateUnsafeRunDenyAtCurrentP4Hook.cfg
P5ReadinessAfterP4GateUnsafeRuntimeCoverageClaim.cfg
```

Unsafe result:

```text
expected_counterexamples=9
unexpected=0
```

## Meaning

This validation closes the immediate post-P4 readiness refresh:

```text
P4 allow-only compatibility remains closed.
P5 has been checked against the actual P4 code.
P5 denial is not approved.
```

The decisive source facts are:

```text
run validate:
  before rq->curr and context_switch
  after pick_next_task, resched clear, and known class settlement sources
  therefore not P5 denial-ready

move validate:
  before local dequeue/CPU mutation
  but helpers do not return denial status
  callers assume success
  therefore not P5 denial-ready
```

## Required Before Reopening P5 Implementation

Before any P5 behavior-changing patch:

```text
run denial must be pre-settle or rollback-proved
move denial needs status plumbing or equivalent settlement protocol
negative tests must prove denied candidates never reach rq->curr/sched_switch/context_switch
path classification must be enforced for sched_ext/core/proxy/RT/DL/fair-direct/kthreads/workqueues/io_uring
P5 must remain test-only and off by default
```

## Non-Claims

This validation does not approve Linux code changes, scheduler behavior
changes, runtime denial, runtime coverage, budget enforcement, monitor calls,
monitor verification, production protection, hypervisor-grade isolation,
cost-efficiency, deployment readiness, or P5 implementation.
