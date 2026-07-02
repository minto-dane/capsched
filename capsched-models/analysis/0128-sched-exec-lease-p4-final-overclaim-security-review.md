# SchedExecLease P4 Final Overclaim and Security Review

Date: 2026-07-02

Status: passed for the P4 allow-only compatibility slice.

## Scope

Review the applied P4 Linux patch:

```text
commit: a937c67f51d1b82297c4f8b7c471f63e8f1a4fe8
subject: sched/exec_lease: Add allow-only validation skeleton
```

This review is scoped to the P4 compatibility slice. It does not validate P5
denial, runtime coverage, budget enforcement, monitor verification, production
protection, hypervisor-grade isolation, cost-efficiency, or deployment
readiness.

## Evidence Reviewed

Implementation evidence:

```text
implementation/0027-sched-exec-lease-p4-allow-only-validation-skeleton-implementation.md
implementation/sched-exec-lease-p4-allow-only-validation-skeleton-implementation-v1.json
```

Validation evidence:

```text
validation/0147-sched-exec-lease-p4-allow-only-skeleton-validation.md
validation/0148-sched-exec-lease-p4-full-vmlinux-build.md
validation/0149-sched-exec-lease-p4-qemu-boot-smoke.md
formal/0097-p4-allow-only-skeleton-gate-model/
```

Linux patch evidence:

```text
linux-patches/patches/capsched-linux-l0/0007-sched-exec-lease-Add-allow-only-validation-skel.patch
```

## Code Review

The P4 patch adds:

```text
enum sched_exec_validation_result
sched_exec_lease_validate_run_edge()
sched_exec_lease_validate_move_edge()
sched_exec_lease_validate_move_edge_locked()
```

The helpers are `static inline`, return only
`SCHED_EXEC_VALIDATION_ALLOW`, and do not mutate state.

Scheduler call sites:

```text
kernel/sched/core.c:
  move_queued_task()
  __schedule()

kernel/sched/sched.h:
  move_queued_task_locked()
```

The scheduler discards the result:

```text
(void)sched_exec_lease_validate_...(...)
```

No scheduler control flow branches on validation results.

## Security Review Findings

No P4 security finding is reported.

Rationale:

- no new user-controlled input path;
- no new allocation, sleeping path, lock acquisition, or refcount operation;
- no new syscall, ioctl, sysfs, procfs, debugfs, tracepoint ABI, or exported
  symbol;
- no monitor call or policy frontend call;
- no budget charging or resource accounting;
- no deny/retry/quarantine/ineligible behavior;
- no fallible scheduler path;
- no object lifetime ownership transfer;
- no cross-domain or cross-task authority claim;
- no new direct memory, IOMMU, device, async, workqueue, or io_uring authority.

The non-ALLOW enum values are type vocabulary only. They are not returned or
used for control flow in P4.

## Compatibility Review

Accepted compatibility evidence:

```text
patch queue replay: exact HEAD a937c67f51d1b82297c4f8b7c471f63e8f1a4fe8
checkpatch: 0 errors, 0 warnings
targeted scheduler build: CONFIG_SCHED_EXEC_LEASE off/on passed
source/object checker: passed
formal/0097: safe passed, 12 unsafe configs produced expected counterexamples
full vmlinux: CONFIG_SCHED_EXEC_LEASE off/on passed
QEMU boot/workload smoke: CONFIG_SCHED_EXEC_LEASE off/on passed
```

Important limits:

```text
core.o byte identity is not claimed.
QEMU runtime coverage is not claimed.
pick_next_task and __schedule remain unavailable to the current ftrace/kprobe
observation runner.
```

## Overclaim Review

Allowed claim:

```text
P4 allow-only compatibility slice is closed.
```

Forbidden claims remain forbidden:

```text
runtime denial
runtime coverage
budget enforcement
monitor call
monitor verification
production protection
hypervisor-grade isolation
cost-efficiency
deployment readiness
P5 denial approval
```

## Decision

P4 allow-only compatibility slice is closed.

This means:

```text
The no-denial P4 validation skeleton is implemented, replayable, buildable,
boot-smoke-tested, and overclaim-reviewed.
```

This does not mean:

```text
The system enforces scheduler capabilities.
The system provides security isolation.
P5 denial is safe.
Runtime coverage is complete.
The monitor-backed production boundary is verified.
```

## Next Gate

The next gate is not to turn P4 into denial directly.

Before P5, reopen the P5 readiness gates:

```text
analysis/0115-bounded-retry-ineligibility-source-design.md
analysis/0116-negative-denial-validation-plan.md
analysis/0117-scheduler-path-classification-for-p5.md
formal/0088-final-deny-source-shape-gate-model/
formal/0089-scheduler-path-classification-gate-model/
implementation/0025-sched-exec-lease-p5-test-only-denial-readiness-gate.md
```

P5 remains blocked until the denial source shape, negative tests, path
classification, and runtime evidence are refreshed against the actual P4 code.
