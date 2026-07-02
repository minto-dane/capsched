# Implementation 0022: SchedExecLease P2 Task Identity Shadow Implementation

Status: Applied and validated as a no-denial P2 lifecycle shadow patch; P2
acceptance is limited to compatibility/build/layout/QEMU evidence and does not
approve runtime enforcement

Date: 2026-07-02

## Purpose

This records the first SchedExecLease patch that touches `task_struct` and
task lifecycle code.

The patch adds a CONFIG-gated Linux-local task identity shadow so later
execution-lease validation has a stable identity anchor for fork, exec, and
exit reasoning. It still does not enforce leases, deny scheduling, allocate
runtime authority, expose ABI, charge budget, call a monitor, or claim
protection.

## Linux Patch

```text
linux_branch=capsched-linux-l0
linux_commit=a0f2676adda634391983e74f29fcba577a9c919e
linux_subject=sched/exec_lease: Add task identity shadow
```

Patch queue:

```text
linux-patches/patches/capsched-linux-l0/0005-sched-exec-lease-Add-task-identity-shadow.patch
linux-patches/patches/capsched-linux-l0/series
linux-patches/upstream/base.txt
```

The patch queue records:

```text
work_commit=a0f2676adda634391983e74f29fcba577a9c919e
```

## Patch Surface

Changed Linux files:

```text
include/linux/sched.h
include/linux/sched_exec_lease.h
kernel/fork.c
fs/exec.c
kernel/exit.c
kernel/sched/exec_lease.c
```

No scheduler enqueue, pick, switch, tick, runqueue, workqueue, io_uring, LSM,
cgroup, namespace, MM, IOMMU, device, tracepoint, debugfs, procfs, sysfs,
syscall, ioctl, exported-symbol, or monitor-call surface changed.

## Added State

P2 adds this CONFIG-gated task-local shadow:

```c
struct sched_exec_task {
        sched_exec_domain_id_t          domain_id;
        sched_exec_epoch_t              domain_epoch;
        sched_exec_generation_t         task_generation;
        sched_exec_generation_t         exec_generation;
        unsigned long                   flags;
};
```

and embeds it in `struct task_struct` only under:

```c
#ifdef CONFIG_SCHED_EXEC_LEASE
        struct sched_exec_task          sched_exec;
#endif
```

This state is not authority. It is not an ExecutionGrant, BudgetContext,
ExecutionLease, SpawnGrant, ThreadControlGrant, MemoryView, endpoint
capability, monitor token, root budget, or IOMMU/queue ownership proof.

## Lifecycle Anchors

The implementation chooses the anchors required by implementation/0021:

```text
raw copy reset:
  file: kernel/fork.c
  function: dup_task_struct()
  anchor: after RCU_INIT_POINTER(tsk->exec_state, NULL)
  effect: sched_exec_task_reset(tsk)

child identity preparation:
  file: kernel/fork.c
  function: copy_process()
  anchor: after copy_creds() succeeds, before the no-more-failure-paths
          boundary and before wake_up_new_task() can publish the child
  effect: sched_exec_task_prepare_fork(p)

exec identity:
  file: fs/exec.c
  function: begin_new_exec()
  anchor: after exec_mmap(bprm) succeeds
  effect: sched_exec_task_commit_exec(me)
  meaning: exec_generation is bumped only after the new mm is visible

exit invalidation:
  file: kernel/exit.c
  function: do_exit()
  anchor: immediately after exit_signals(tsk), which sets PF_EXITING
  effect: sched_exec_task_exit(tsk)
```

`sched_exec()` in `bprm_execve()` remains placement-only and does not mutate
SchedExecLease identity.

## Helper Contract

The P2 helpers are nofail and behavior-free:

```text
sched_exec_task_reset():
  clears the task-local shadow to the default Linux-local domain shadow.

sched_exec_task_prepare_fork():
  assigns the default Linux-local domain shadow and a placeholder
  task_generation of 1.

sched_exec_task_commit_exec():
  increments exec_generation with saturation.

sched_exec_task_exit():
  marks the task-local EXITING flag.
```

The placeholder generation is intentionally not a protection-quality freshness
source. Before any runtime denial is allowed, generation allocation and
freshness must be replaced or refined so reuse, stale grants, and cross-task
confusion cannot be hidden by a constant local value.

## Review Checklist

```text
Every new task_struct field under CONFIG_SCHED_EXEC_LEASE: yes
Raw-copy inheritance sanitized after arch_dup_task_struct(): yes
Child identity prepared before any wake_up_new_task() path: yes
create_io_thread() inactive-return path receives shadow identity: yes
sched_exec() remains placement-only: yes
Exec mutation is after point of no return: yes
Exec mutation is after exec_mmap() succeeds: yes
Exit invalidation is do_exit()/PF_EXITING time: yes
Helpers are nofail: yes
Scheduler hooks, denial, ABI, exports, and monitor calls absent: yes
CONFIG_SCHED_EXEC_LEASE=n keeps P2 fields compiled out: yes
```

## Validation

Validation is split because P2 touches lifecycle code and task layout:

```text
validation/0133-sched-exec-lease-p2-full-build-and-layout.md
validation/0134-sched-exec-lease-p2-qemu-boot-smoke.md
```

P2 acceptance evidence:

```text
patch queue replay reaches a0f2676adda634391983e74f29fcba577a9c919e: passed
CONFIG_SCHED_EXEC_LEASE=off full vmlinux build: passed
CONFIG_SCHED_EXEC_LEASE=on full vmlinux build: passed
task layout inspection off/on: passed
QEMU boot/workload smoke off/on: passed
fork/exec/exit workload smoke: passed
```

Targeted object builds have passed for the changed lifecycle files in disabled
and enabled configurations, after using the project-local build tool area for
`libelf` headers required by host `objtool`.

Validation/0134 records that the enabled QEMU guest booted with
`CONFIG_SCHED_EXEC_LEASE=y`, completed `forkexec 100` with `WORKLOAD_RET 0`,
and observed fork/exec/exit counts of 101 each. The same record also preserves
the known observation gap: `pick_next_task` and `__schedule` remain unavailable
to the current function/kprobe smoke, and `dlease_pick_next_task` kprobe setup
failed. That is not a P2 acceptance blocker because P2 adds no scheduler hook
or denial path.

## Remaining Gates

P3 may add only placement-only scheduler touch points. P4 may add only
allow-all final revalidation scaffolding. P5 remains the first possible
behavior-changing denial slice and is still blocked by:

```text
wake/enqueue/final-pick hook coverage
sched_ext support/disable/fail-closed decision
core cached-pick revalidation or invalidation
proxy donor/current/executor authority and budget accounting
workqueue/kthread classification
bounded retry and ineligibility behavior
negative denial tests
claim ledger overclaim guard
monitor-backed authority design
```

## Non-Claims

This implementation is not runtime enforcement, hook approval, runtime
coverage, negative denial evidence, user ABI approval, public tracepoint ABI
approval, monitor ABI approval, monitor implementation, monitor verification,
exploit containment, hypervisor-grade isolation, production protection,
cost-efficiency evidence, or datacenter deployment readiness.
