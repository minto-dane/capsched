# Implementation 0021: SchedExecLease P2 Task Identity Shadow Plan

Status: Draft P2 patch plan; implementation not applied

Date: 2026-07-02

## Purpose

P2 is the first planned SchedExecLease patch that may touch task lifecycle
state. Its job is to add a Linux-local task identity shadow that later
execution-lease validation can refer to.

P2 must still preserve Linux behavior. It must not enforce leases, deny
execution, allocate runtime authority, call a monitor, expose ABI, or change
which task can run.

## Current Source Basis

```text
linux_branch=capsched-linux-l0
linux_commit=95b8c509043d755ad77801315beec94c09059777
linux_subject=sched/exec_lease: Add private no-behavior object vocabulary
```

Relevant current source anchors:

```text
include/linux/sched.h:
  struct task_struct contains scheduling fields, mm/active_mm, exec_state,
  exit_state, and flags. Any P2 field must be under CONFIG_SCHED_EXEC_LEASE.

kernel/fork.c:
  dup_task_struct() raw-copies the parent through arch_dup_task_struct().
  dup_task_struct() already resets exec_state after the raw copy.
  copy_process() creates and initializes the child before wake_up_new_task().
  create_io_thread() returns an inactive task from copy_process().
  kernel_clone() calls wake_up_new_task() after copy_process() returns.
  copy_process() marks "No more failure paths after this point."

fs/exec.c:
  bprm_execve() calls sched_exec() before security_bprm_creds_for_exec() and
  before exec can still fail or be check-only.
  begin_new_exec() is documented as the point of no return.
  exec_mmap() makes the new mm visible to the task.

kernel/exit.c:
  do_exit() calls exit_signals(), which sets PF_EXITING.
  release_task() reaps an already-dead task.

kernel/fork.c final release:
  __put_task_struct() and free_task() release storage after task death.
```

## Allowed Patch Surface

P2 may touch only:

```text
include/linux/sched.h
include/linux/sched_exec_lease.h
kernel/fork.c
fs/exec.c
kernel/exit.c
kernel/sched/exec_lease.c
```

Any patch that needs scheduler enqueue/pick/switch/tick files is P3 or P4, not
P2.

## Allowed Object Shape

Preferred P2 task-local state:

```c
struct sched_exec_task {
        sched_exec_domain_id_t          domain_id;
        sched_exec_epoch_t              domain_epoch;
        sched_exec_generation_t         task_generation;
        sched_exec_generation_t         exec_generation;
        unsigned long                   flags;
};
```

Allowed task_struct addition:

```c
#ifdef CONFIG_SCHED_EXEC_LEASE
        struct sched_exec_task          sched_exec;
#endif
```

This is a Linux-local shadow only. It is not an ExecutionGrant, BudgetContext,
ExecutionLease, SpawnGrant, ThreadControlGrant, monitor token, MemoryView, or
endpoint authority.

## Required Lifecycle Semantics

### Raw Copy Reset

`dup_task_struct()` raw-copies parent bytes. Therefore P2 must reset or
sanitize the embedded `sched_exec` state immediately after the raw copy and
before the child can be published.

Preferred anchor:

```text
kernel/fork.c:
  after RCU_INIT_POINTER(tsk->exec_state, NULL)
  before setup_thread_stack(tsk, orig)
```

Reason:

```text
parent frozen state, stale generation, future pointer placeholders, and
revoked flags must never survive arch_dup_task_struct().
```

### Child Identity Preparation

`copy_process()` is the place where the child identity becomes meaningful.

Preferred anchor:

```text
kernel/fork.c:
  after copy_creds() succeeds and after PF_KTHREAD/PF_IO_WORKER/PF_USER_WORKER
  flags have been derived
  before the "No more failure paths after this point" boundary
  before kernel_clone() can call wake_up_new_task()
```

The helper must be nofail in P2. If a future version needs fallible allocation,
that allocation must happen before the no-more-failure-paths boundary and must
have an explicit cleanup path.

`create_io_thread()` is covered because it returns the inactive child created
by `copy_process()`. P2 must not rely on `kernel_clone()` after return, because
some callers wake the returned task later.

### Exec Identity

`sched_exec()` in `bprm_execve()` is placement-only and must not mutate
SchedExecLease identity.

P2 may add only a no-denial exec shadow transition in `begin_new_exec()`, after
the point of no return. The patch plan prefers a helper that can later be moved
or refined, but P2 must not change isolation domain, mint authority, or alter
credentials.

Candidate anchors, in increasing semantic strength:

```text
after bprm->point_of_no_return = true:
  allowed for marking fatal-commit progress only.

after de_thread(me) succeeds:
  preferred if exec_generation must not be bumped for de_thread failure.

after exec_mmap(bprm) succeeds:
  preferred if future semantics require "new mm is visible" before generation
  bump.
```

P2 must document which one it chooses. It must not use `sched_exec()` as the
mutation point.

### Exit Invalidation

`release_task()` and `free_task()` are too late for authority invalidation.

Preferred anchor:

```text
kernel/exit.c:
  immediately after exit_signals(tsk), because it sets PF_EXITING
```

P2 may set a task-local exited flag or invalidate the local shadow there. It
must not rely on final storage release as a revoke receipt.

## Forbidden Content

P2 must not add:

```text
scheduler enqueue/pick/switch/tick hooks
runqueue fields
per-rq state
heap-allocated grant objects
runtime denial
budget charging
generation checks that can block execution
policy decisions
LSM/cgroup/namespace coupling
tracepoints
debugfs/procfs/sysfs
syscalls
ioctls
exported symbols
monitor calls
MemoryView changes
IOMMU or device ownership changes
workqueue/io_uring authority propagation
```

P2 must not claim:

```text
runtime coverage
hook coverage
negative denial behavior
Domain isolation
monitor verification
hypervisor-grade protection
production protection
cost efficiency
```

## Review Checklist

Reviewers must answer yes to all before accepting a P2 patch:

```text
Is every new task_struct field under CONFIG_SCHED_EXEC_LEASE?
Is raw-copy inheritance sanitized after arch_dup_task_struct()?
Is child identity prepared before any wake_up_new_task() path?
Does create_io_thread() receive valid shadow identity before returning?
Does sched_exec() remain placement-only?
Is exec mutation after the point of no return?
Is exit invalidation at do_exit()/PF_EXITING time, not release_task/free_task?
Are all helpers nofail or before the no-more-failure-paths boundary?
Is there still no scheduler hook, denial, ABI, export, or monitor call?
Does CONFIG_SCHED_EXEC_LEASE=n preserve task layout and behavior?
```

## Validation Required

Before accepting P2:

```text
jq checks for updated JSON
JSONL event validation
git diff --check
patch queue replay
CONFIG_SCHED_EXEC_LEASE=off full vmlinux build
CONFIG_SCHED_EXEC_LEASE=on full vmlinux build
task layout inspection for off/on
QEMU boot/workload smoke off/on
fork/clone/exec/exit trace smoke
create_io_thread/io_uring worker source audit or trace smoke if touched
```

Because P2 changes `task_struct` when enabled and touches lifecycle code,
QEMU off/on is required even if runtime behavior remains allow-all.

## Non-Claims

This plan is not implementation, behavior change approval, hook approval,
runtime coverage, negative denial evidence, user ABI approval, public tracepoint
ABI approval, monitor ABI approval, monitor implementation, monitor
verification, production protection, or cost-efficiency evidence.
