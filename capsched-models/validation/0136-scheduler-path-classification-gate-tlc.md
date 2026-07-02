# Validation 0136: Scheduler Path Classification Gate TLC

Status: Safe model passed; unsafe models produced expected counterexamples; no
implementation or protection claim

Date: 2026-07-02

## Scope

Validate `formal/0089-scheduler-path-classification-gate-model/` for the P5
scheduler path classification in `analysis/0117`.

This check verifies claim scope only. It does not approve Linux code, runtime
denial, runtime coverage, or production protection.

## Safe Run

Command:

```sh
java -cp /home/nia/tools/tla/tla2tools.jar tlc2.TLC \
  -metadir build/tlc/scheduler-path-classification-gate-<timestamp>/safe \
  -config SchedulerPathClassificationGateSafe.cfg \
  SchedulerPathClassificationGate.tla
```

Result:

```text
exit_code: 0
states_generated: 2
distinct_states: 1
depth: 1
error: none
```

## Unsafe Runs

All unsafe configs exited with code 12 and produced the expected
`Safety` invariant counterexample:

```text
SchedulerPathClassificationGateUnsafeUnknownPathOpen.cfg
SchedulerPathClassificationGateUnsafeSupportedWithoutEvidence.cfg
SchedulerPathClassificationGateUnsafeCoverageOverExcluded.cfg
SchedulerPathClassificationGateUnsafeDisabledPathRuns.cfg
SchedulerPathClassificationGateUnsafeFallbackAuthority.cfg
SchedulerPathClassificationGateUnsafeWorkqueueCallerAuthority.cfg
SchedulerPathClassificationGateUnsafeInternalKthreadOrdinaryAuthority.cfg
SchedulerPathClassificationGateUnsafeImplementationApproval.cfg
SchedulerPathClassificationGateUnsafeProductionProtectionClaim.cfg
SchedulerPathClassificationGateUnsafeCostEfficiencyClaim.cfg
```

## Interpretation

The checked classification permits only this initial P5 test-only support set:

```text
ordinary CFS final run in non-core, non-proxy, non-sched_ext configuration
common queued move through move_queued_task() / move_queued_task_locked()
```

It rejects:

```text
open scheduler paths
supported paths without evidence
runtime coverage over excluded paths
disabled path execution
fallback authority
workqueue or internal kthread identity as caller authority
implementation approval
production protection claim
cost-efficiency claim
```

## Non-Claims

This validation does not approve implementation, P3/P4/P5 code, runtime denial,
runtime coverage, ABI, monitor implementation, monitor verification,
production protection, hypervisor-grade isolation, or cost-efficiency claims.
