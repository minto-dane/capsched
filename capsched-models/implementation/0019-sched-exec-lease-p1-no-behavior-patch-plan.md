# Implementation 0019: SchedExecLease P1 No-Behavior Patch Plan

Status: Draft patch plan; implementation not applied

Date: 2026-07-02

## Purpose

This plan defines the first implementation patch that may follow the P1-P4
blueprint.

P1 is intentionally boring. Its job is to create a scheduler-private namespace
for future SchedExecLease objects while preserving Linux behavior exactly.

## Allowed Patch Surface

P1 may touch only:

```text
include/linux/sched_exec_lease.h
kernel/sched/exec_lease.c
```

It may not touch:

```text
include/linux/sched.h
kernel/sched/core.c
kernel/sched/sched.h
kernel/fork.c
fs/exec.c
kernel/exit.c
kernel/workqueue.c
io_uring/
security/
mm/
drivers/
```

Any patch that needs those files is not P1. It must move to a later P2-P4
review.

## Allowed Content

P1 may add:

```text
internal struct definitions inside kernel/sched/exec_lease.c
internal enum/result names for allow-all validation shape
static helper functions with default allow-all/root-domain semantics
compile-time only invariants such as BUILD_BUG_ON where useful
comments that preserve authority separation
```

P1 must keep the public header opaque:

```text
struct sched_exec_domain;
struct sched_exec_grant;
struct sched_budget_ctx;
struct sched_exec_lease;
```

The public header may add function declarations only if they are:

```text
static inline
non-exported
no-op or allow-all
not callable from user space
not a tracepoint or ABI
```

Preferred P1 shape:

```c
enum sched_exec_validation_result {
        SCHED_EXEC_VALIDATION_ALLOW,
        SCHED_EXEC_VALIDATION_RETRY,
        SCHED_EXEC_VALIDATION_INELIGIBLE,
        SCHED_EXEC_VALIDATION_QUARANTINE,
};
```

Non-allow values may exist as future control-flow names, but P1 must not return
them in production code.

## Forbidden Content

P1 must not add:

```text
task_struct fields
rq fields
per-task allocation
per-rq allocation
scheduler hook calls
lifecycle hook calls
runtime denial
budget charging
generation mutation
policy decisions
LSM calls
cgroup calls
namespace coupling
tracepoints
debugfs/procfs/sysfs
syscalls
ioctls
exported symbols
module parameters
monitor calls
user-visible handles
```

P1 must not make claims about:

```text
runtime coverage
negative denial behavior
Domain isolation
HyperTag/Domain Monitor verification
hypervisor-grade protection
production protection
cost efficiency
```

## Authority Separation Requirements

P1 names must keep these separate:

```text
ExecutionGrant:
  runnable authority placeholder only

ExecutionLease:
  future frozen use placeholder only

BudgetContext:
  budget placeholder only

Domain shadow:
  Linux-local label/shadow only, not authority

Monitor token:
  opaque placeholder only, not Linux-minted authority
```

P1 must not introduce a universal "capability object" that collapses execution,
budget, spawn, thread control, endpoint, memory, device, and monitor authority.

## Upstream-Drift Contract

P1 is intentionally low-drift because it touches only the existing
SchedExecLease scaffold files.

Required drift checks before applying P1:

```text
patch queue recreates current work commit
source-drift freshness is clean or explicitly reviewed
include/linux/sched_exec_lease.h still exists
kernel/sched/exec_lease.c still exists
kernel/sched/Makefile still builds exec_lease.o only under CONFIG_SCHED_EXEC_LEASE
CONFIG_SCHED_EXEC_LEASE still depends on EXPERT and defaults n
```

If any scaffold path changes, P1 must be rebased as a naming/scaffold update
before adding new types.

## Validation Required

Before accepting P1:

```text
jq checks for updated project JSON
JSONL event validation
bash -n validation runners if touched
git diff --check
patch queue replay
CONFIG_SCHED_EXEC_LEASE=off full vmlinux build
CONFIG_SCHED_EXEC_LEASE=on full vmlinux build
QEMU boot/workload smoke off/on if any compiled behavior changes
```

If P1 only changes `exec_lease.c` and the header but adds no hook, no task
field, and no runtime state, validation/0130 and validation/0131 are precedent
for the expected compatibility evidence class, not a substitute for rerunning
after the actual patch.

## Review Checklist

Reviewers must answer yes to all:

```text
Does CONFIG_SCHED_EXEC_LEASE=n compile out exec_lease.o?
Does CONFIG_SCHED_EXEC_LEASE=y preserve allow-all behavior?
Are all object layouts either private to exec_lease.c or opaque?
Are there no task_struct or rq changes?
Are there no scheduler or lifecycle hooks?
Are there no exported symbols or ABI surfaces?
Are non-allow results unreachable?
Are all non-claims preserved?
Can this patch be dropped without changing Linux scheduler behavior?
```

If any answer is no, the patch is not P1.

## Non-Claims

This plan is not implementation, behavior change approval, hook approval,
runtime coverage, negative-test evidence, user ABI approval, public tracepoint
ABI approval, monitor ABI approval, monitor implementation, monitor
verification, production protection, or cost-efficiency evidence.
