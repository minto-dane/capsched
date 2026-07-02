# Scheduler Path Classification Gate Model

Status: Checked with safe pass and expected unsafe counterexamples

Date: 2026-07-02

## Purpose

This model checks the P5 scheduler path classification from analysis/0117.

It ensures that the first test-only denial slice does not:

```text
leave paths open
mark paths supported without evidence
claim runtime coverage over disabled/excluded paths
run disabled paths under denial mode
treat fallback as authority
treat workqueue/kthread identity as caller authority
claim implementation, production protection, or cost efficiency
```

## Safe Classification

```text
supported:
  ordinary CFS final run
  common queued move

disabled:
  sched_ext
  core scheduling
  proxy execution

excluded:
  fair direct load balance
  RT
  deadline
  async workqueue/io_uring
  internal kthreads
```

## Rejected Behaviors

Unsafe configs reject:

```text
open path
supported path without evidence
runtime coverage over excluded paths
disabled path execution
fallback authority
workqueue caller authority
internal kthread as ordinary authority
implementation approval
production protection claim
cost-efficiency claim
```

## TLC Result

Safe model:

```text
config: SchedulerPathClassificationGateSafe.cfg
result: pass
states_generated: 2
distinct_states: 1
depth: 1
```

Unsafe configs:

```text
SchedulerPathClassificationGateUnsafeUnknownPathOpen.cfg: expected counterexample
SchedulerPathClassificationGateUnsafeSupportedWithoutEvidence.cfg: expected counterexample
SchedulerPathClassificationGateUnsafeCoverageOverExcluded.cfg: expected counterexample
SchedulerPathClassificationGateUnsafeDisabledPathRuns.cfg: expected counterexample
SchedulerPathClassificationGateUnsafeFallbackAuthority.cfg: expected counterexample
SchedulerPathClassificationGateUnsafeWorkqueueCallerAuthority.cfg: expected counterexample
SchedulerPathClassificationGateUnsafeInternalKthreadOrdinaryAuthority.cfg: expected counterexample
SchedulerPathClassificationGateUnsafeImplementationApproval.cfg: expected counterexample
SchedulerPathClassificationGateUnsafeProductionProtectionClaim.cfg: expected counterexample
SchedulerPathClassificationGateUnsafeCostEfficiencyClaim.cfg: expected counterexample
```

The first TLC attempt exposed an action/temporal-formula mismatch in the unsafe
spec wrappers. The model was corrected to make each unsafe case a reachable bad
transition from the safe initial classification.

## Non-Claims

This model does not approve Linux implementation, scheduler hooks, runtime
denial, runtime coverage, public ABI, monitor ABI, monitor verification,
production protection, or cost-efficiency claims.
