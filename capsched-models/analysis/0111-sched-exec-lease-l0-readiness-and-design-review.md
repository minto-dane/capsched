# Analysis 0111: SchedExecLease L0 Readiness and Design Review

Status: Critical review integrated; implementation design may proceed, runtime
enforcement remains blocked

Date: 2026-07-02

## Purpose

This review integrates the N-157/N-158 critical path:

```text
Can we safely move from model-only work toward SchedExecLease Linux
implementation work?
```

The answer is intentionally split:

```text
yes:
  patch queue replay and design work are ready

yes:
  no-behavior preparation patches may be designed

no:
  behavior-changing runtime enforcement is not approved yet
```

## Evidence Integrated

```text
validation/0129-patch-queue-replay-and-freshness.md
implementation/0016-sched-exec-lease-l0-implementation-readiness-gate.md
implementation/0017-sched-exec-lease-l0-vertical-slice-design.md
```

## Critical Findings

The review identified four implementation traps that must shape the first
vertical slice.

### Wake Publication

`try_to_wake_up()` publishes `TASK_WAKING` before enqueue. Therefore a
fallible execution-lease decision cannot be first introduced inside
`enqueue_task()`.

Design consequence:

```text
admission preparation before TASK_WAKING
or final pre-run validation with bounded retry
or explicit quarantine model
```

### Enqueue Mutability

`enqueue_task()` is void and mutates uclamp, class state, PSI, scheduler info,
and core scheduling state. A naive `-EPERM` return from enqueue is not a safe
patch shape.

Design consequence:

```text
do not make enqueue_task() fallible in L0
```

### Final Pick Publication

`__schedule()` publishes `rq->curr` before context switch. Runtime denial after
that point would be too late.

Design consequence:

```text
final execution-lease validation must occur before rq->curr publication
denied candidates require bounded retry and ineligibility state
```

### Donor/Current Split

With proxy execution, runtime accounting is not simply "charge current." The
scheduler tick observes `rq->donor`, and fair accounting updates running task
state while donor and current can differ.

Design consequence:

```text
budget observation and future charging must be donor-aware
```

## Additional Hazards

```text
core scheduling cached picks need revalidation or invalidation
sched_ext fallback cannot be the security root
sched_exec() is placement only, not DomainLease identity authority
fork child identity must be prepared before wake_up_new_task()
exec does not mint a new isolation domain
exit cleanup is not revoke completion
```

## Readiness Result

The project is ready for the first no-behavior implementation-preparation
design. It is not ready for runtime denial.

Allowed next work:

```text
no-behavior internal helper skeleton
no-behavior identity preparation skeleton
no-behavior scheduler touch-point comments/static inline hooks
KUnit-only or build-only validation without ABI
```

Blocked next work:

```text
runtime denial
public user handles
public tracepoint ABI
monitor ABI
exported symbols
endpoint/device/memory authority
hypervisor-grade or production protection claims
```

## Non-Claims

This review is not Linux implementation, runtime coverage, monitor
verification, production protection, or cost-efficiency evidence.
