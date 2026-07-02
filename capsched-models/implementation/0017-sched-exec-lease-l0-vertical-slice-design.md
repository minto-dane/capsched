# Implementation 0017: SchedExecLease L0 Vertical Slice Design

Status: Draft design gate for first implementation slice; refined by 0018;
behavior-changing enforcement still blocked until the remaining validation and
coverage gates are satisfied

Date: 2026-07-02

## Goal

The first SchedExecLease implementation slice must introduce Linux-side
execution-lease plumbing without weakening compatibility or claiming
monitor-backed protection.

The design target is:

```text
CONFIG_SCHED_EXEC_LEASE=n:
  exactly current Linux behavior

CONFIG_SCHED_EXEC_LEASE=y:
  default allow-all execution-lease shadow state
  no runtime denial by default
  no user ABI
  no public tracepoint ABI
  no monitor ABI
  no production protection claim
```

## Slice Shape

The first acceptable implementation slice is split into three layers.

### Layer A: Internal Object Skeleton

Allowed:

```text
opaque internal objects for sched_exec_domain, sched_exec_grant,
sched_exec_lease, sched_budget_ctx, and sched_sealed_exec_token
internal helpers returning allow-all/default-root results
generation fields only if lifetime handling is explicit
KUnit-only or build-only checks if no ABI leaks
```

Forbidden:

```text
runtime denial
public user handles
tracepoint ABI
monitor calls
exported symbols
policy decisions
endpoint/device/memory authority
```

### Layer B: Placement-Only Scheduler Touch Points

Allowed:

```text
static inline no-op hooks under CONFIG_SCHED_EXEC_LEASE
comments documenting exact future authority points
compile-time structure only when no hot-path behavior changes
```

Candidate future attachment points:

```text
pre-TASK_WAKING admission preparation
final pre-rq->curr revalidation
tick/runtime donor-aware observation
fork child identity preparation before wake_up_new_task()
exec continuation generation update around point of no return
exit/revoke drain preparation before task death
```

Not allowed in the first runtime slice:

```text
making enqueue_task() fail
denying after rq->curr publication
charging only current when donor differs
treating sched_exec() as exec authority
treating core cached picks as already validated
treating sched_ext fallback as security policy
```

### Layer C: Validation Hooks For Future Runtime Slice

The first runtime-capable slice must come with validation covering:

```text
CONFIG_SCHED_EXEC_LEASE=n full vmlinux build
CONFIG_SCHED_EXEC_LEASE=y full vmlinux build
QEMU boot smoke
fork/exec/exit workload smoke
scheduler trace or kprobe observation for candidate hook coverage
targeted negative tests for denied candidates only after denial exists
```

Targeted subtree build is acceptable only for no-behavior preparation patches.

## Design Decisions

| ID | Decision |
| --- | --- |
| L0-DES-001 | Do not make `enqueue_task()` fallible. Admission must be prepared before wake publication or checked at final run with bounded retry. |
| L0-DES-002 | Do not treat `Run/ExecutionGrant` as budget, spawn, endpoint, monitor, or control authority. |
| L0-DES-003 | First runtime checks must use default allow-all semantics unless a task has explicit internal test state. |
| L0-DES-004 | Final validation must occur before `RCU_INIT_POINTER(rq->curr, next)`. |
| L0-DES-005 | Budget observation and eventual charging must account for `rq->donor`, not only `rq->curr`. |
| L0-DES-006 | Core scheduling cached picks require fresh lease validation or invalidation. |
| L0-DES-007 | sched_ext is a prototype policy mechanism only; it cannot be the enforcement root. |
| L0-DES-008 | `sched_exec()` is placement only and must not mutate DomainLease identity. |
| L0-DES-009 | fork must prepare child identity before `wake_up_new_task()`. |
| L0-DES-010 | exec keeps the isolation domain; code/mm/cred changes do not mint a new domain. |
| L0-DES-011 | exit/revoke completion requires pending authority inventory and drain semantics; Linux cleanup alone is not authority drain. |
| L0-DES-012 | No behavior-changing patch may claim hypervisor-grade isolation without Domain Monitor enforcement. |

## Minimal Future Patch Order

```text
P1: no-behavior internal helper skeleton
P2: task lifecycle identity preparation skeleton, still allow-all
P3: scheduler touch-point instrumentation or KUnit-only validation hooks
P4: final run revalidation with allow-all result and explicit bounded retry skeleton
P5: test-only denial mode after full build, QEMU smoke, and model alignment
```

P1 through P4 must not deny tasks. P5 is the first possible behavior-changing
slice and must be explicitly re-approved.

## Compatibility Rules

Compatibility is part of the security model:

```text
existing CFS, RT, deadline, idle, core scheduling, proxy execution, and
sched_ext behavior must not change by accident
cpuset/affinity/hotplug semantics remain Linux-owned until mapped
rlimits/cgroup/LSM policy inputs do not become authority by themselves
failure paths must not silently drop wakeups
retry paths must be bounded
```

## Open Items Before P5

```text
full vmlinux off/on validation
exact task-field lifetime placement
core scheduling cached-pick invalidation design
sched_ext support/disable/fail-closed decision
proxy execution donor/current test plan
fork/exec/exit identity KUnit or trace plan
negative denial tests
```

Current status:

```text
full vmlinux off/on validation: passed in validation/0130
QEMU boot smoke off/on validation: passed in validation/0131 for boot/workload smoke; hook coverage incomplete
P1-P4 blueprint: drafted in implementation/0018
```

## Non-Claims

This design is not an implementation patch, enforcement evidence, monitor
implementation, runtime coverage, production protection, or cost-efficiency
evidence.
