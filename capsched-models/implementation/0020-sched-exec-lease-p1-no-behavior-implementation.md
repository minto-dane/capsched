# Implementation 0020: SchedExecLease P1 No-Behavior Implementation

Status: Applied to Linux as no-behavior P1 patch

Date: 2026-07-02

## Purpose

This records the first SchedExecLease P1 Linux implementation patch.

The patch implements only private scheduler execution-lease vocabulary inside
the existing inert scaffold. It does not connect that vocabulary to any Linux
execution path.

## Linux Patch

```text
linux_branch=capsched-linux-l0
linux_commit=95b8c509043d755ad77801315beec94c09059777
linux_subject=sched/exec_lease: Add private no-behavior object vocabulary
```

Patch queue:

```text
linux-patches/patches/capsched-linux-l0/0004-sched-exec-lease-Add-private-no-behavior-object-vocabulary.patch
linux-patches/patches/capsched-linux-l0/series
linux-patches/upstream/base.txt
```

The patch queue now records:

```text
work_commit=95b8c509043d755ad77801315beec94c09059777
```

## Patch Surface

Changed Linux file:

```text
kernel/sched/exec_lease.c
```

Unchanged P1-allowed file:

```text
include/linux/sched_exec_lease.h
```

No other Linux source file changed.

## Added Vocabulary

Private to `kernel/sched/exec_lease.c`:

```text
enum sched_exec_validation_result
struct sched_exec_domain
struct sched_exec_grant
struct sched_budget_ctx
struct sched_exec_lease
sched_exec_allow_all_validation()
```

Authority separation preserved:

```text
sched_exec_domain:
  Linux-local domain shadow only, not monitor-backed authority.

sched_exec_grant:
  runnable authority placeholder only.

sched_budget_ctx:
  CPU-time budget placeholder only.

sched_exec_lease:
  future frozen-use placeholder only.

sched_exec_allow_all_validation():
  private allow-all shape only; no external caller and no runtime denial.
```

## Behavior Contract

The patch adds no:

```text
task_struct field
runqueue field
scheduler hook
lifecycle hook
allocation path
runtime state mutation
runtime denial
budget charging
generation mutation
policy frontend call
LSM/cgroup/namespace coupling
tracepoint
debugfs/procfs/sysfs entry
syscall/ioctl
exported symbol
monitor call
user-visible handle
```

Because the new helper and object layouts are private and uncalled, the patch
is compiled and linked when `CONFIG_SCHED_EXEC_LEASE=y` but has no scheduler
behavior effect.

## Review Checklist

```text
CONFIG_SCHED_EXEC_LEASE=n compiles out exec_lease.o: yes
CONFIG_SCHED_EXEC_LEASE=y compiles exec_lease.o: yes
object layouts private or opaque: yes
task_struct or rq changes: no
scheduler or lifecycle hooks: no
exported symbols or ABI surfaces: no
non-allow results reachable: no
patch can be dropped without changing scheduler behavior: yes
```

## Validation

Validation is recorded in:

```text
validation/0132-sched-exec-lease-p1-full-build.md
```

Completed evidence:

```text
patch queue replay reaches linux_commit 95b8c509043d755ad77801315beec94c09059777
CONFIG_SCHED_EXEC_LEASE=off full vmlinux build passes
CONFIG_SCHED_EXEC_LEASE=off keeps kernel/sched/exec_lease.o absent
CONFIG_SCHED_EXEC_LEASE=on full vmlinux build passes
CONFIG_SCHED_EXEC_LEASE=on builds kernel/sched/exec_lease.o
```

QEMU boot smoke was not rerun for this N because no runtime call site, hook,
task layout, or behavior path changed. Existing validation/0131 remains the
boot/workload compatibility precedent for the inert scaffold; a fresh QEMU run
is required before accepting any later patch that adds runtime call sites.

## Remaining Gates

P2 may not proceed without preserving the lifecycle requirements in
implementation/0018:

```text
reset after dup_task_struct raw copy
prepare child identity before wake_up_new_task
keep sched_exec placement-only
stage exec mutation after point of no return
invalidate in do_exit/PF_EXITING
```

Behavior-changing enforcement remains blocked until P5 gates are satisfied:

```text
hook coverage
sched_ext support/disable/fail-closed decision
core cached-pick revalidation or invalidation
proxy donor/current/executor authority and budget tests
kthread/workqueue classification
bounded retry/ineligibility behavior
negative denial tests
claim ledger overclaim guard
```

## Non-Claims

This implementation is not runtime enforcement, hook approval, runtime
coverage, negative denial evidence, user ABI approval, public tracepoint ABI
approval, monitor ABI approval, monitor implementation, monitor verification,
exploit containment, hypervisor-grade isolation, production protection,
cost-efficiency evidence, or datacenter deployment readiness.
