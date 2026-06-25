# Analysis 0005: Async Provenance Risk Map

Status: Draft

Date: 2026-06-25

Linux base:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
commit: 4edcdefd4083ae04b1a5656f4be6cd83ae919ef4
```

## Purpose

This note records where Linux execution continues after the originating task
has returned from a syscall, blocked, exited, or changed credentials. This is
the main confused-deputy risk for CapSched.

## Core Observation

The scheduler can enforce "who may run" only for tasks it can identify. Linux
also has many mechanisms that run work later under a worker, softirq, timer, or
target task context. If those paths do not carry caller provenance, CapSched can
make direct task execution safe while still allowing authority to leak through
asynchronous execution.

The invariant is:

```text
ASYNC-001:
  No async work without caller provenance and frozen authority.
```

## Workqueue

Evidence:

- `__queue_work()` in `kernel/workqueue.c` around lines 2275-2411 queues a work
  item into a pool/workqueue structure.
- `queue_work_on()` around lines 2442-2458 marks work pending and delegates to
  `__queue_work()`.
- `create_worker()` around lines 2836-2895 creates worker kthreads.
- `process_one_work()` around lines 3220-3285 claims a work item, records
  current work state, deletes it from the list, and runs the callback.
- `worker_thread()` around lines 3431-3485 processes any pool work under a
  worker task.

Risk:

Generic workqueue execution carries subsystem and worker identity, not a
CapSched caller authority tuple. A Domain can trigger work that later runs with
service or kernel authority unless the work item has a frozen caller context or
is explicitly classified as service-domain work.

Model need:

```c
struct capsched_work_ctx {
        u64 caller_domain;
        u64 caller_epoch;
        u64 caller_generation;
        struct capsched_frozen_authority frozen;
        struct capsched_domain *service_domain;
        struct capsched_budget_ticket *budget;
};
```

Effective authority:

```text
effective = frozen caller authority ∩ service-domain authority
```

## task_work

Evidence:

- `kernel/task_work.c` around lines 23-59 documents that task work executes on
  a target task transition or at exit.
- `task_work_add()` around lines 59-104 pushes callbacks into
  `task->task_works` and sets a notification mode.
- `task_work_run()` around lines 200-237 executes callbacks under `current`,
  permits callbacks to add more work, and may call `cond_resched()`.
- `exit_task_work()` in `include/linux/task_work.h` calls `task_work_run()` at
  task exit.

Risk:

task_work is closer to task identity than generic workqueue, but the queuer and
the executor are not necessarily the same authority. CapSched must know whether
the callback is:

```text
self-work: queued and executed by the same Domain
cross-task control: requires ThreadControlCap or EndpointCap
subsystem completion: requires service authority plus caller frozen context
```

## kthreads and kthread Work

Evidence:

- `kernel/kthread.c` around lines 451-501 creates kthreads through `kthreadd`
  and `kernel_thread()`.
- The documentation around lines 528-537 states kthreads are created stopped
  and default to `SCHED_NORMAL` on all CPUs before being woken.
- `kthread_insert_work()` around lines 1172-1184 wakes a worker task.
- `kthread_queue_work()` around lines 1199-1213 queues work.

Risk:

Kernel threads are not ordinary Domain user tasks. They often hold global
service authority. Under CapSched, they need explicit classification:

```text
root management Domain
driver service Domain
filesystem service Domain
network service Domain
per-Domain helper
```

Without that classification, a Domain can cause a kernel worker to perform
operations with authority broader than the caller should possess.

## io_uring

Evidence:

- `io_uring/tctx.c` around lines 16-44 initializes io-wq offload with
  `data.task = task`.
- Around lines 77-109, per-task io_uring context creates `io_wq`,
  fallback work, and task work.
- `io_uring/io-wq.c` around lines 48-70 defines `struct io_worker`; around
  lines 116-135 defines `struct io_wq`.
- Worker creation and task_work-based creation appear around lines 387-430.
- Worker execution around lines 598-650 obtains work and calls the submission
  path.
- `create_io_thread()` in `kernel/fork.c` around lines 2672-2684 creates
  io worker tasks with shared process resources and `PF_IO_WORKER`.
- `fs/exec.c` around line 1142 cancels io_uring task state on exec.
- `kernel/exit.c` around line 944 cancels io_uring files on exit.

Risk:

io_uring is a high-value async boundary because it can register resources once
and consume them later from worker context. CapSched must distinguish:

```text
registration-time authority
submission-time authority
worker execution authority
completion authority
budget charged to caller versus service
```

Potential rule:

```text
registered fd/resource authority must be frozen at registration or submission
io worker execution must carry caller Domain provenance
worker service authority must be intersected with frozen caller authority
```

## Softirq and Timers

Evidence:

- `handle_softirqs()` in `kernel/softirq.c` around lines 579-652 borrows the
  current task context, clears some flags, and runs softirq action callbacks.
- `__do_softirq()` around lines 654-657 invokes that handler.
- `ksoftirqd_run()` around lines 1063-1078 executes pending softirq work in a
  kernel thread context.
- `include/linux/timer.h` around lines 35-42 warns that irqsafe timer callbacks
  are not for arbitrary heavy work.
- `call_timer_fn()` in `kernel/time/timer.c` around lines 1722-1764 invokes a
  timer callback and checks preempt count behavior.
- `expire_timers()` around lines 1766-1802 calls timer functions with base lock
  handling.
- `run_timer_softirq()` around lines 2401-2410 runs timers from softirq.

Risk:

Softirq and timer callbacks often represent device, network, block, or kernel
subsystem progress, not a normal task. Provenance can be:

```text
device queue owner
network namespace/service Domain
block service Domain
root kernel service
specific caller that armed the timer
```

CapSched should not pretend all timer/softirq work has user caller identity.
Some of it should be service-domain authority with explicit endpoint and budget
semantics.

## Risk Matrix

| Path | Execution context | Current carried identity | CapSched risk | Likely model |
| --- | --- | --- | --- | --- |
| workqueue | worker kthread | work item and workqueue, no general caller Domain | service confused deputy | `capsched_work_ctx` required for Domain-derived work |
| task_work | target task/current | target task plus callback | cross-task callback authority ambiguity | self vs external control distinction |
| kthread work | kernel worker | subsystem worker identity | global kernel service authority leaks | service Domain classification |
| io_uring worker | io worker sharing process resources | io_wq/task link, registered resources | registered authority consumed later without fresh caller check | freeze resource authority and budget |
| softirq | interrupted context or ksoftirqd | subsystem/action identity | borrowed current or global service confusion | device/service Domain provenance |
| timer | softirq callback | timer owner implicit in object | stale callback after authority changes | frozen owner or service classification |

## Existing Positives

Linux gives several handles that can help:

- Workqueue queue and execute paths are centralized.
- `PF_WQ_WORKER`, `PF_IO_WORKER`, and kthread flags identify worker-like tasks.
- io_uring has explicit per-task context and exec/exit cancellation paths.
- task_work is target-task scoped.
- Timers and softirqs have central dispatch points.

These are useful for instrumentation and modeling. They do not solve
provenance by themselves.

## Preliminary Conclusion

Async provenance is probably more dangerous than the first scheduler hook. A
CapSched prototype can measure scheduler overhead in L0, but any security story
must treat async work as first-class. The first formal models should include at
least one async path before claims move beyond performance and semantic
exploration.
