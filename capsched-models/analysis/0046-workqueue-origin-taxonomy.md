# Analysis 0046: Workqueue Origin Taxonomy

Status: Draft taxonomy and source map, no implementation approved

Date: 2026-06-27

Linux source:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
commit: 7cf0b1e415bcead8a2079c8be94a9d41aad7d462
```

Related notes:

```text
analysis/0034-workqueue-kthread-budgetticket-carrier.md
analysis/0045-workqueue-internal-redesign-boundary.md
validation/0041-workqueue-origin-observation-plan.md
analysis/workqueue-origin-taxonomy-v1.json
```

## Purpose

This note answers the next design question after `analysis/0045`:

```text
If generic internal worker authority is not enough, how do we classify Linux
async work before deciding where CapSched carriers are mandatory?
```

The goal is not to classify every callsite yet. The goal is to define the
taxonomy and evidence standard so that later source tagging and trace
validation can be mechanical and conservative.

## Source Survey

A source grep for common async APIs shows why a one-shot generic enforcement
hook would be unsafe. Workqueue-like APIs are spread across drivers,
filesystems, networking, block, scheduler, RCU, BPF, tracing, and core kernel
code.

Top-level rough grep counts from this source tree:

```text
drivers/net:        1440
drivers/gpu:         475
drivers/scsi:        277
drivers/usb:         234
sound/soc:           227
drivers/media:       222
drivers/power:       210
drivers/infiniband:  205
drivers/md:          127
drivers/hid:         109
fs/smb:               61
net/core:             25
kernel/sched:         25
kernel/workqueue.c:   22
```

These are not semantic counts. They are a warning: `queue_work()` and friends
are a substrate, not a single security meaning.

## Observation Facts

Generic workqueue tracepoints expose useful identity:

```text
include/trace/events/workqueue.h:
  workqueue_queue_work:
    work pointer, function pointer, workqueue name, requested CPU, pool CPU
  workqueue_activate_work:
    work pointer, function pointer
  workqueue_execute_start:
    work pointer, function pointer
  workqueue_execute_end:
    work pointer, function pointer
```

kthread work has tracepoints too:

```text
include/trace/events/sched.h:
  sched_kthread_work_queue_work
  sched_kthread_work_execute_start
  sched_kthread_work_execute_end
```

Task work is different:

```text
kernel/task_work.c:
  task_work_add(task, work, notify)
  task_work_run()
```

It executes in the target task context, but task identity is still not endpoint
authority. It needs task/process generation and endpoint derivation checks.

irq_work is different again:

```text
kernel/irq_work.c:
  irq_work_queue()
  irq_work_queue_on()
  irq_work_single()
  irq_work_run()
```

It can run in hard/deferred IRQ context or `irq_work/%u` context on some
configurations. It cannot be a slow authority discovery point.

## Taxonomy

### PerInvocation

Definition:

```text
One queued async item corresponds to one caller/resource operation.
```

Examples:

```text
fs/aio.c:
  aio_fsync() initializes req->work and schedule_work(&req->work)
  aio_fsync_work() performs vfs_fsync() under stored creds

drivers/iommu/iommu-sva.c:
  iommu_sva_iopf_handler() initializes group->work
  iommu_sva_handle_iopf() handles one I/O page fault group
```

CapSched meaning:

```text
If the operation is Domain-derived, the work item needs a per-operation
carrier: caller Domain, caller epoch, FrozenEndpointUse, BudgetTicket, service
Domain, work generation, and settlement rule.
```

Accepted carrier shape:

```text
one queued work item
one frozen endpoint use or typed request authority
one caller budget reservation or ticket
one completion/cancel settlement
```

Hard rejects:

```text
using worker current task as caller
using stored Linux creds as CapSched authority
using file reachability alone as endpoint authority
```

### ExplicitMerge

Definition:

```text
Multiple external events can intentionally coalesce into one pending work item.
The subsystem owns accumulated state and defines how repeated queue attempts
are represented.
```

Examples:

```text
block/blk-zoned.c:
  disk_zone_wplug_schedule_work() increments a plug ref before queue_work()
  and drops it if the work was already pending
  the work drains accumulated BIO state

fs/aio.c:
  aio_poll_wake() uses work_scheduled and work_need_resched to coalesce poll
  wakeups into one completion work path
```

CapSched meaning:

```text
A single work_struct cannot have "the caller" unless the merge object defines
the set or aggregate of caller tickets and endpoint uses.
```

Accepted merge object must specify:

```text
admission rule
budget reservation rule
endpoint-use aggregation rule
revocation rule
cancel/flush settlement
failure mode if any participant loses authority
whether one failed participant poisons the whole batch or only its item
```

Hard rejects:

```text
overwriting carrier while work is pending
last caller wins
first caller pays for everyone
one revocation silently ignored because the work remains queued
```

### ServiceOnly

Definition:

```text
Work is service or subsystem maintenance. It is not acting as a caller-derived
endpoint effect.
```

Examples:

```text
fs/timerfd.c:
  timerfd_resume() schedules timerfd_work after timekeeping resume
  timerfd_resume_work() runs timerfd_clock_was_set()

io_uring/io_uring.c:
  io_ring_ctx_wait_and_kill() queues ctx->exit_work for ring teardown

kernel/cgroup/cgroup.c:
  cgroup release and css destruction work paths
```

CapSched meaning:

```text
Runs under service authority only.
Must not perform caller-attributed endpoint effects unless it creates a
separate DomainRequestWork or PerInvocation carrier.
```

Hard rejects:

```text
service maintenance work spends caller budget
service work uses a surviving fd/resource as if it implies caller authority
service teardown completes new caller endpoint effects after revocation
```

### KernelException

Definition:

```text
Core kernel liveness or infrastructure work that is outside user Domain
attribution and cannot practically be charged to a caller.
```

Examples:

```text
kernel/workqueue.c:
  pool->idle_cull_work
  mayday cursor and rescuer infrastructure

kernel/rcu:
  RCU callback invocation and callback-driving work

kernel/sched:
  scheduler remote tick and core scheduler maintenance work
```

CapSched meaning:

```text
Explicitly audited exception.
No caller-attributed endpoint effect is allowed.
Exception scope must stay narrow and reviewable.
```

Hard rejects:

```text
using KernelException as a blanket bucket for unknown work
performing file/socket/device endpoint effects under exception authority
letting exceptions grow until they hide Domain-derived work
```

### InterruptDeferred

Definition:

```text
Work originates in interrupt, softirq, BH workqueue, or irq_work context and
defers processing out of the immediate interrupt path.
```

Examples:

```text
kernel/irq_work.c:
  irq_work_queue(), irq_work_queue_on(), irq_work_run()

kernel/workqueue.c:
  system_bh_wq and system_bh_highpri_wq are BH workqueues

drivers/vfio/virqfd.c:
  eventfd wakeup can schedule virqfd injection work
```

CapSched meaning:

```text
Interrupt context can signal readiness or request handoff, but it must not
perform slow capability discovery.
```

Allowed shape:

```text
interrupt/BH/irq_work observes event
records minimal already-authorized state
hands off to ServiceOnly, PerInvocation, or ExplicitMerge path
endpoint effect occurs only after typed authority is checked
```

Hard rejects:

```text
minting caller authority in interrupt context
charging arbitrary caller budget from IRQ context
assuming interrupt source equals Domain identity
```

### ReclaimRescue

Definition:

```text
Work may execute through WQ_MEM_RECLAIM rescue workers to guarantee forward
progress under memory pressure.
```

Source anchors:

```text
Documentation/core-api/workqueue.rst:
  WQ_MEM_RECLAIM workqueues must have a forward progress guarantee

kernel/workqueue.c:
  rescuer_thread()
  assign_rescuer_work()
  current_is_workqueue_rescuer()
```

CapSched meaning:

```text
Rescuer execution is a liveness mechanism, not an authority bypass.
```

Rules:

```text
rescue worker may provide service liveness
caller-derived endpoint effects still require the caller carrier
if the caller carrier is gone, work must fail closed or finish only service
cleanup that has no caller-attributed endpoint effect
```

Hard rejects:

```text
rescuer bypasses BudgetTicket
rescuer executes a Domain endpoint effect because normal workers are blocked
memory pressure turns service authority into caller authority
```

### TaskLocal

Definition:

```text
Callback is queued to a task and runs when that task returns through a task
work execution point or exits.
```

Examples:

```text
kernel/task_work.c:
  task_work_add()
  task_work_run()

fs/file_table.c:
  delayed fput can try task_work_add(..., TWA_RESUME)

io_uring:
  task_work paths drive io_uring completion and cancellation behavior
```

CapSched meaning:

```text
TaskLocal execution preserves task context better than kworker execution, but
task context is still not endpoint authority.
```

Required checks:

```text
target task generation
program/process generation where exec matters
Domain epoch
endpoint derivation or attenuation
budget source if doing broker/service work
exit/exec cancellation semantics
```

Hard rejects:

```text
task == authority
post-exec task_work uses old ProgramGeneration endpoint authority
task_work scheduled before revoke performs endpoint effects after revoke
```

## Cross-Cutting Tags

The taxonomy class is not enough by itself. Each work path also needs tags:

```text
origin_context:
  task, syscall, irq, softirq, timer, workqueue, kthread, device, remote,
  reclaim, rcu, suspend_resume

object_scope:
  per_request, per_task, per_mm, per_file, per_inode, per_socket, per_device,
  per_superblock, per_netns, global

coalescing:
  none, pending_bit, delayed_mod, explicit_flags, list_batch, refcount_batch,
  unknown

endpoint_effect:
  none, file, socket, mm, device_queue, iommu, scheduler, namespace, cred,
  bpf, mixed

authority_source:
  caller_carrier, service_only, kernel_exception, merge_object, task_context,
  unknown

reclaim_path:
  none, WQ_MEM_RECLAIM, rescuer_possible, memalloc_context, unknown

monitor_relevance:
  none, DomainTag, MemoryView, Budget, IOMMU, QueueLease, mixed
```

## Required Decision Rule

Before any generic workqueue enforcement hook, every candidate work path must
answer:

```text
1. Is this Domain-derived?
2. Can more than one caller/event coalesce into one pending work item?
3. Does the callback perform endpoint effects?
4. If yes, where is the FrozenEndpointUse created?
5. If yes, where is the BudgetTicket created, consumed, canceled, or refunded?
6. Can it execute through rescuer, BH, kthread, or task_work context?
7. What happens after exec, exit, revoke, namespace change, cgroup migration,
   CPU hotplug, memory pressure, or worker fallback?
```

If any answer is unknown:

```text
classification = unknown_or_mixed
enforcement = forbidden
next step = observe or instrument
```

## Immediate N-063 Result

The taxonomy is:

```text
PerInvocation
ExplicitMerge
ServiceOnly
KernelException
InterruptDeferred
ReclaimRescue
TaskLocal
```

The central design rule is:

```text
Only Domain-derived work can require caller carriers. Existing kernel-internal
work must first be classified. Unknown work is not a security boundary.
```

This preserves the final security goal because it avoids two false claims:

```text
false claim 1:
  every internal work item is safe because it is internal

false claim 2:
  every internal work item is caller-derived and can be forced through a
  single generic caller-carrier rule
```

Both false claims would make the protection argument weaker, not stronger.
