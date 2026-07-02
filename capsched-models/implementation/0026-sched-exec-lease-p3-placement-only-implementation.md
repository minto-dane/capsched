# Implementation 0026: SchedExecLease P3 Placement-Only Implementation

Status: Applied; validation recorded separately in validation/0140; no
runtime denial, ABI, monitor call, or protection claim

Date: 2026-07-02

## Purpose

P3 is the first SchedExecLease patch that touches scheduler files. It places
source-level markers at scheduler edges that future execution-lease validation
must reason about.

P3 intentionally does not enforce anything. The marker helpers are static
inline `void` no-ops. They cannot deny, retry, quarantine, charge budget,
allocate a grant, call a monitor, or expose user ABI.

## Source State

```text
linux_branch=capsched-linux-l0
linux_commit=d5f77adb5a64f3b2545db6ab1dcdc4aa4442bab3
linux_subject=sched/exec_lease: Add placement-only scheduler touchpoints
```

Patch queue:

```text
linux-patches/patches/capsched-linux-l0/0006-sched-exec_lease-Add-placement-only-scheduler-touchp.patch
linux-patches/patches/capsched-linux-l0/series
linux-patches/upstream/base.txt
work_commit=d5f77adb5a64f3b2545db6ab1dcdc4aa4442bab3
```

## Changed Linux Source

```text
include/linux/sched_exec_lease.h
kernel/sched/core.c
kernel/sched/sched.h
```

No change was made to:

```text
fork
exec
exit
workqueue
io_uring
LSM
cgroup
namespace
MM
device
IOMMU
tracepoint
debugfs/procfs/sysfs
syscall/ioctl
```

## Added Marker Helpers

The public header now contains static inline no-op markers:

```text
sched_exec_lease_prepare_wake(p)
sched_exec_lease_prepare_new_task(p)
sched_exec_lease_note_queued_move(p, dest_cpu)
sched_exec_lease_observe_tick(donor)
sched_exec_lease_note_switch(prev, next)
```

The helper names deliberately use `prepare`, `note`, and `observe`, not
`validate`. P3 does not add a validation result object. Fallible validation
remains a later P4/P5 concern.

## Marker Placement

`kernel/sched/core.c`:

```text
move_queued_task()
  before deactivate_task(rq, p, DEQUEUE_NOCLOCK)

try_to_wake_up()
  before WRITE_ONCE(p->__state, TASK_WAKING)

wake_up_new_task()
  before WRITE_ONCE(p->__state, TASK_RUNNING)

sched_tick()
  after donor = rq->donor

__schedule()
  before context_switch(rq, prev, next, &rf)
```

`kernel/sched/sched.h`:

```text
move_queued_task_locked()
  before deactivate_task(src_rq, task, 0)
```

## Semantics

This implementation establishes source-level placement only:

```text
wake marker:
  names the future pre-TASK_WAKING edge.

new-task marker:
  names the future child runnable publication edge.

queued-move marker:
  names a future pre-detach/pre-CPU-mutation movement edge.

tick marker:
  observes the donor task selected by current Linux accounting.

switch marker:
  observes the switch tuple before context_switch().
```

The switch marker is not final run validation. It is too late for future
denial because `rq->curr` has already been published before `context_switch()`.
The future final run validation edge remains P4 or later and must be reviewed
separately.

## No-Behavior Constraints

P3 preserves:

```text
no runtime denial
no retry/quarantine path
no sleeping allocation
no grant allocation
no budget charging
no task wake failure
no task migration failure
no runqueue field
no per-rq authority state
no monitor call
no LSM/cgroup/namespace policy coupling
no tracepoint ABI
no debugfs/procfs/sysfs ABI
no syscall/ioctl ABI
no exported symbols
no workqueue/io_uring provenance propagation
no MemoryView/IOMMU/device ownership change
```

## Validation Pointer

Validation is recorded in:

```text
capsched/capsched-models/validation/0140-sched-exec-lease-p3-validation.md
```

That validation covers patch queue replay, full `vmlinux` off/on builds, QEMU
off/on no-behavior smoke, object/symbol checks, and overclaim review.

## Non-Claims

This implementation does not prove runtime coverage, hook correctness, denial
behavior, budget enforcement, monitor verification, exploit containment,
hypervisor-grade isolation, production protection, cost efficiency, or
datacenter deployment readiness.
