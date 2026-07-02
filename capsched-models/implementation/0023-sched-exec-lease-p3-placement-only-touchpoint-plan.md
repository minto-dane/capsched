# Implementation 0023: SchedExecLease P3 Placement-Only Touchpoint Plan

Status: Draft P3 patch plan; implementation not applied; blocked until P2
full-build, layout, and QEMU validation are recorded

Date: 2026-07-02

## Purpose

P3 is the first planned SchedExecLease patch that may touch Linux scheduler
files. Its purpose is to place source-level, no-denial touch points at the
edges that future execution-lease enforcement must reason about.

P3 must not implement enforcement. It must not deny, retry, block, allocate,
charge budget, mutate runqueue authority, change placement, call a monitor,
expose ABI, or claim protection. It is an implementation-readiness patch only.

## Current Source Basis

```text
linux_branch=capsched-linux-l0
linux_commit=a0f2676adda634391983e74f29fcba577a9c919e
linux_subject=sched/exec_lease: Add task identity shadow
```

P3 must not be applied until P2 validation records are complete:

```text
validation/0133-sched-exec-lease-p2-full-build.md
validation/0134-sched-exec-lease-p2-qemu-boot-smoke.md
```

## Allowed Patch Surface

P3 may touch only:

```text
include/linux/sched_exec_lease.h
kernel/sched/core.c
kernel/sched/sched.h
kernel/sched/exec_lease.c
```

P3 must not touch fork, exec, exit, workqueue, io_uring, LSM, cgroup,
namespace, MM, device, IOMMU, tracepoint, debugfs, procfs, sysfs, syscall, or
ioctl surfaces.

## Allowed Implementation Shape

The safest P3 shape is source-visible but behavior-free:

```text
static inline no-op helpers in include/linux/sched_exec_lease.h
optional private allow-all helper vocabulary in kernel/sched/exec_lease.c
call sites in scheduler code whose generated behavior is empty or trivially
predictable
```

The helper names must describe the edge being marked, not a generic
"scheduler check":

```text
sched_exec_lease_prepare_wake()
  future pre-TASK_WAKING preparation point.

sched_exec_lease_prepare_new_task()
  future child runnable publication preparation point.

sched_exec_lease_observe_tick()
  future donor-aware runtime observation point.

sched_exec_lease_note_switch()
  future Domain/monitor switch observation point.
```

P3 may also define names for future P4 validation, but it must not wire
fallible validation in P3:

```text
sched_exec_lease_validate_run_edge()
sched_exec_lease_validate_move_edge()
```

Those names must return allow-all only when they are later wired by P4.

## Candidate Anchors From Current Source

### Wake Preparation

Current source:

```text
kernel/sched/core.c
function: try_to_wake_up()
anchor: before WRITE_ONCE(p->__state, TASK_WAKING)
```

Reason:

```text
TASK_WAKING publication is a Linux state transition. Future fallible admission
must not discover denial only after mutating the task into TASK_WAKING. P3 is
no-op, but it should mark the future pre-publication edge.
```

P3 must not make this path fail, sleep, allocate, or drop a wakeup.

### New Task Publication

Current source:

```text
kernel/sched/core.c
function: wake_up_new_task()
anchor: after raw_spin_lock_irqsave(&p->pi_lock, rf.flags)
        before WRITE_ONCE(p->__state, TASK_RUNNING)
```

Reason:

```text
P2 prepares child identity in copy_process(). P3 should mark the first runnable
publication edge before TASK_RUNNING and before activate_task(). Future denial
cannot be inserted here without a separate spawn/child publication failure
model, because wake_up_new_task() currently returns void.
```

P3 must not make child publication fail or change fork/clone semantics.

### Runtime Tick Observation

Current source:

```text
kernel/sched/core.c
function: sched_tick()
anchor: after donor = rq->donor
```

Reason:

```text
Current Linux accounts tick work to the donor task under proxy execution.
SchedExecLease budget observation must therefore observe donor identity, not
only rq->curr. P3 observation is no-op and must not charge budget.
```

### Switch Boundary Observation

Current source:

```text
kernel/sched/core.c
function: __schedule()
anchor: before context_switch(rq, prev, next, &rf)
```

Reason:

```text
Future monitor activation belongs on a switch boundary, but P3 must not call a
monitor. This marker must not substitute for final run validation. It observes
only the selected switch tuple after Linux has decided to switch.
```

### Future Final Run Validation

Current source:

```text
kernel/sched/core.c
function: __schedule()
anchor: at keep_resched join, before is_switch and before
        RCU_INIT_POINTER(rq->curr, next)
```

Reason:

```text
The final enforcement point must be before rq->curr publication. It must cover
the ordinary pick path, proxy execution, and the keep_resched join. P3 may name
this future edge but should not wire a fallible result. P4 is the first
allow-all validation skeleton for this edge.
```

### Future Queued Move Validation

Current source:

```text
kernel/sched/core.c
function: move_queued_task()
anchor: before deactivate_task(rq, p, DEQUEUE_NOCLOCK)

kernel/sched/sched.h
function: move_queued_task_locked()
anchor: before deactivate_task(src_rq, task, 0)
```

Reason:

```text
CPU movement authority must be checked before Linux detaches or commits a task
to a destination runqueue. P3 may name this edge, but P4 must handle the actual
allow-all validation skeleton. Later runtime denial must be bounded and cannot
leave tasks half-moved.
```

## Rejected Anchors

P3 must not treat these as authority roots:

```text
enqueue_task():
  void, already mutates uclamp/class/PSI/core scheduling state; too late and
  structurally unsuitable as the first fallible authority boundary.

context_switch():
  too late for final run denial because rq->curr has already been published.

set_task_cpu():
  CPU mutation primitive, not an authority boundary.

attach_task():
  too late because detach and CPU mutation have already happened.

sched_exec():
  placement only; it can run before exec is committed and must not mutate
  DomainLease identity or authority.

sched_ext dispatch queues:
  policy/dispatch state only; sched_ext fallback cannot be the security root.
```

## Forbidden Content

P3 must not add:

```text
runtime denial
retry or quarantine behavior
sleeping allocation
grant allocation
budget charging
task wake failure
task migration failure
runqueue field
per-rq authority state
monitor call
LSM/cgroup/namespace policy coupling
tracepoint ABI
debugfs/procfs/sysfs ABI
syscall or ioctl ABI
exported symbols
workqueue/io_uring provenance propagation
MemoryView/IOMMU/device ownership changes
```

P3 must not claim:

```text
runtime coverage
negative denial behavior
hook correctness
monitor verification
hypervisor-grade isolation
production protection
cost efficiency
datacenter deployment readiness
```

## Validation Required Before Accepting P3

Because P3 touches scheduler hot paths, it needs at least:

```text
P2 validation complete and recorded
git diff --check
patch queue replay
CONFIG_SCHED_EXEC_LEASE=off full vmlinux build
CONFIG_SCHED_EXEC_LEASE=on full vmlinux build
QEMU boot/workload smoke off/on
function/kprobe trace evidence for the touched anchors when observable
explicit generated-code or object-size note showing no unexpected enabled/disabled behavior change
claim ledger non-overclaim review
```

If any helper remains as an out-of-line call in hot paths when
`CONFIG_SCHED_EXEC_LEASE=y`, the validation must explicitly record that this is
intentional no-denial overhead and not a behavior or protection claim.

## Non-Claims

This plan is not implementation, runtime enforcement, hook approval, negative
denial evidence, user ABI approval, public tracepoint ABI approval, monitor ABI
approval, monitor implementation, monitor verification, exploit containment,
hypervisor-grade isolation, production protection, cost-efficiency evidence, or
datacenter deployment readiness.
