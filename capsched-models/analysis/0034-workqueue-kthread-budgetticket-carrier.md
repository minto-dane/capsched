# Analysis 0034: Workqueue and kthread_work BudgetTicket Carrier

Status: Draft source map and design constraints, no implementation approved

Date: 2026-06-27

Linux source:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
commit: 7cf0b1e415bcead8a2079c8be94a9d41aad7d462
```

## Purpose

`analysis/0032` established that generic async wake paths do not carry typed
authority. `analysis/0033` handled ordinary task-local resumable-run state.

This note handles a different class:

```text
Domain-derived work that leaves the caller task and later executes inside a
generic worker, rescuer, or kthread worker.
```

The question is:

```text
How does CapSched prevent a worker from becoming a confused deputy that spends
service authority without a caller-frozen endpoint use and caller budget?
```

This is not an approval to patch workqueue or kthread code yet.

## Core Finding

Linux `work_struct` and `kthread_work` carry enough state to schedule a callback
but not enough state to preserve CapSched authority.

They carry:

```text
callback function
queue/list state
pending/running/cancel state
target worker/workqueue information
```

They do not carry:

```text
caller Domain
caller epoch
caller task/process generation
FrozenEndpointUse
BudgetTicket
service Domain
work authority generation
revocation epoch
```

Therefore generic workqueue or kthread worker execution must not be interpreted
as caller-authorized execution. For Domain-derived work:

```text
effective authority =
  service authority
  intersect caller frozen endpoint authority
  intersect live caller BudgetTicket
  intersect live caller/service epochs
```

The carrier must be attached before generic queue insertion, not discovered
inside `process_one_work()` or `kthread_worker_fn()`.

## Source Anchors

Generic work state:

```text
include/linux/workqueue_types.h:13 work_func_t takes struct work_struct *
include/linux/workqueue_types.h:16-23 struct work_struct has data, entry, func
include/linux/workqueue.h:114-119 struct delayed_work embeds work_struct,
  timer, target workqueue, and CPU
include/linux/workqueue.h:674-699 queue_work() wrapper and memory-order note
```

Queue insertion:

```text
kernel/workqueue.c:2220 insert_work()
kernel/workqueue.c:2275 __queue_work()
kernel/workqueue.c:2429 queue_work_on()
kernel/workqueue.c:2442-2456 queue_work_on() returns false if already pending
kernel/workqueue.c:2544 delayed_work_timer_fn()
kernel/workqueue.c:2552 queue_delayed_work_on()
kernel/workqueue.c:2630 mod_delayed_work_on()
```

Execution:

```text
kernel/workqueue.c:3207 process_one_work()
kernel/workqueue.c:3248-3249 worker->current_work/current_func are set
kernel/workqueue.c:3288 set_work_pool_and_clear_pending()
kernel/workqueue.c:3322 worker->current_func(work)
kernel/workqueue.c:3373-3379 current work/function are cleared and in-flight
  accounting is decremented
kernel/workqueue.c:3420 worker_thread()
kernel/workqueue.c:3562 rescuer_thread()
```

Cancel/flush:

```text
kernel/workqueue.c:4459 __cancel_work()
kernel/workqueue.c:4478 __cancel_work_sync()
kernel/workqueue.c:4505 cancel_work()
kernel/workqueue.c:4529 cancel_work_sync()
kernel/workqueue.c:4551 cancel_delayed_work()
kernel/workqueue.c:4566 cancel_delayed_work_sync()
```

kthread worker state:

```text
include/linux/kthread.h:144-158 struct kthread_worker and kthread_work
include/linux/kthread.h:263-270 kthread_queue_work and delayed variants
kernel/kthread.c:971 kthread_worker_fn()
kernel/kthread.c:1015 list_first_entry(work_list)
kernel/kthread.c:1021 worker->current_work = work
kernel/kthread.c:1027 work->func(work)
kernel/kthread.c:1155 queuing_blocked()
kernel/kthread.c:1163 kthread_insert_work_sanity_check()
kernel/kthread.c:1173 kthread_insert_work()
kernel/kthread.c:1199 kthread_queue_work()
kernel/kthread.c:1406 __kthread_cancel_work()
kernel/kthread.c:1490 __kthread_cancel_work_sync()
```

Adjacent mechanisms:

```text
kernel/task_work.c:59 task_work_add()
kernel/task_work.c:200 task_work_run()
kernel/irq_work.c:116 irq_work_queue()
```

`task_work` runs in the target task context and should be modeled separately.
`irq_work` can run in hard or deferred interrupt context and should not carry
sleepable authority discovery.

## Workqueue Properties That Matter

### 1. work_struct is a callback container, not an authority object

The type is intentionally minimal:

```text
atomic_long_t data
list_head entry
work_func_t func
optional lockdep map
```

The callback receives only:

```text
struct work_struct *work
```

So any CapSched authority must be recovered through a containing object or side
table. If no CapSched carrier was attached before queueing, the worker callback
cannot safely infer caller authority from `current`, because `current` is a
kworker/rescuer/kthread task.

### 2. queue_work() coalesces pending work

`queue_work_on()` sets `WORK_STRUCT_PENDING_BIT` and returns false if the work
was already pending. This is normal and important Linux behavior.

CapSched consequence:

```text
One work_struct pending instance cannot safely represent multiple callers with
different tickets unless the containing object has explicit merge semantics.
```

Rejected design:

```text
caller A queues work with ticket A
caller B queues same pending work and overwrites carrier with ticket B
worker executes once under ambiguous authority
```

Safe design options:

```text
per-invocation work object:
  each queued caller operation has its own work_struct and carrier

explicit merge object:
  the subsystem defines how multiple caller tickets/frozen endpoint uses merge,
  how budget is reserved, and how cancellation/revocation is handled

service-owned periodic work:
  no caller authority is claimed; it runs only as service/kernel maintenance
  work and cannot perform caller-attributed endpoint operations
```

### 3. delayed_work splits reservation from execution time

`delayed_work` stores a timer plus target workqueue and CPU. The timer later
queues the embedded work.

CapSched consequence:

```text
The delayed carrier must remain live across the timer interval, or the timer
must revalidate from already-local no-sleep state when it queues the work.
```

The timer callback cannot become a slow authority-discovery point.

Ticket policy must be explicit:

```text
reserve at submit:
  caller budget is held while delayed work waits

reserve at timer-fire:
  only allowed if a local preauthorized reservation object exists and timer
  context can fail closed without sleeping

service maintenance:
  delayed work is not caller-derived and uses service budget only
```

### 4. workers and rescuers are not caller Domains

`worker_thread()` and `rescuer_thread()` run kernel worker tasks. A rescuer may
execute work under memory pressure and may not be the same worker that would
normally process the work.

CapSched consequence:

```text
The carrier must travel with the work item, not with the chosen worker task.
```

Worker task authority alone is insufficient. A worker may provide service
authority, but caller-derived operations still require caller provenance and a
BudgetTicket.

### 5. process_one_work clears pending before callback

`process_one_work()` dequeues the work, sets `worker->current_work`, clears
pending with `set_work_pool_and_clear_pending()`, and then calls the callback.

CapSched consequence:

```text
The callback may requeue the same work or free its container.
```

The carrier consumption rule must tolerate:

```text
self-requeue
callback freeing the containing object
flush/cancel racing with execution
worker current_work used only for debug/flush, not authority
```

### 6. cancel and flush are lifecycle events, not authority transfer

`cancel_work()` may cancel pending work. `cancel_work_sync()` waits for
execution to finish. `cancel_delayed_work()` may not wait for a running
callback unless the sync form is used.

CapSched consequence:

```text
cancel pending:
  release or refund unused BudgetTicket according to endpoint policy

cancel running:
  cannot steal back authority already in execution; must wait, request stop,
  or rely on bounded ticket/epoch checks

flush:
  wait for completion only; it does not authorize the work
```

## kthread_work Properties That Matter

`kthread_work` is even more direct:

```text
struct kthread_work {
        list_head node;
        kthread_work_func_t func;
        struct kthread_worker *worker;
        int canceling;
};
```

`kthread_worker_fn()` removes a work from the list, stores
`worker->current_work`, and calls:

```text
work->func(work)
```

`kthread_queue_work()` returns false if queuing is blocked because the work is
already queued or canceling.

CapSched consequence:

```text
kthread_work has no native caller authority carrier.
```

For Domain-derived work:

```text
capsched_kthread_work_ctx must be part of the containing object or a checked
side table before kthread_queue_work().
```

The same no-overwrite rule applies:

```text
pending/canceling work cannot have its carrier overwritten by another caller
unless the subsystem has explicit merge semantics.
```

## Proposed Carrier Semantics

Conceptual carrier:

```c
struct capsched_work_ctx {
        u64 caller_domain;
        u64 caller_epoch;
        u64 caller_task_generation;
        u64 caller_process_generation;

        struct capsched_frozen_endpoint_use *endpoint_use;
        struct capsched_budget_ticket       *ticket;
        struct capsched_domain              *service_domain;

        u64 work_generation;
        u64 carrier_epoch;
        unsigned long flags;
};
```

This is a semantic shape, not an approved C layout.

Carrier states:

```text
Prepared:
  caller authority and budget are frozen before generic queue insertion

Queued:
  carrier is bound to one queued work instance or explicit merge object

Running:
  worker executes with service authority intersected with caller frozen use and
  caller BudgetTicket

Completed:
  ticket is consumed/settled, carrier is cleared, refs are released

Canceled:
  unused ticket is released/refunded according to endpoint policy

Revoked:
  queued work is rejected/canceled, running work is stopped or bounded by
  ticket/epoch checks
```

## Required Invariants

```text
NoWorkQueueWithoutCarrier:
  Domain-derived work must not enter generic workqueue/kthread_work pending
  state without a prepared carrier.

NoWorkerAmbientAuthority:
  worker task authority alone must not authorize caller-derived endpoint work.

NoRunWithoutBudgetTicket:
  caller-derived work cannot execute unless a live BudgetTicket is attached.

NoRunAfterCallerRevoke:
  caller epoch revocation invalidates queued/running caller-derived work before
  it can perform endpoint effects.

NoCarrierOverwriteWhilePending:
  pending work cannot have its carrier replaced by a different caller/ticket
  unless an explicit merge rule is modeled for that subsystem.

NoDeadCarrierRefs:
  completed, canceled, or dead work cannot retain caller authority refs.
```

## Accepted Categories

CapSched should classify queued work as one of:

```text
caller-derived work:
  requires capsched_work_ctx, FrozenEndpointUse, BudgetTicket, caller/service
  epoch checks

service maintenance work:
  uses service Domain authority only, must not perform caller-attributed work

kernel-internal exception:
  limited early boot, stop, idle, RCU, or core scheduler work that is outside
  user Domain attribution and must be explicitly audited

explicit merge work:
  subsystem-proven merge of multiple callers into one work item with defined
  ticket accounting and revocation semantics
```

The default must not be "ambient worker can do it."

## Full Internal Redesign Position

It is acceptable, and likely necessary for production CapSched-H, to redesign
the internal async substrate rather than merely wrapping today's generic
workqueue users.

The rejected idea is not:

```text
redesign Linux async execution
```

The rejected idea is:

```text
treat every workqueue callback as if it has one implicit caller authority
```

Those are different. A strong CapSched design may replace or heavily reshape
internal async execution, but the replacement must preserve typed authority
boundaries.

Target shape:

```text
CapSched async substrate:
  KernelCoreWork
  ServiceMaintenanceWork
  DomainRequestWork
  MergedDomainBatchWork
  InterruptDeferredWork
  ReclaimRescueWork
```

Required distinction:

```text
DomainRequestWork:
  has caller Domain, caller epoch, FrozenEndpointUse, BudgetTicket, service
  Domain, and work generation

MergedDomainBatchWork:
  has explicit multi-caller merge, accounting, revoke, and settlement rules

ServiceMaintenanceWork:
  uses service authority only and must not perform caller-attributed endpoint
  effects

KernelCoreWork:
  is a narrowly audited internal exception, not a hidden caller path
```

This lets CapSched eventually own the async substrate without falsely assigning
caller authority to maintenance, reclaim, RCU, stop, idle, or rescuer work.

Production implication:

```text
L0:
  wrappers and classification are enough to avoid unsafe first hooks

L1:
  Domain-derived work gets mandatory typed carriers

L2:
  per-Domain and per-service async queues become normal structure

CapSched-H:
  monitor-backed Domain activation, MemoryView, and root budget checks can be
  integrated into service/worker dispatch
```

So the long-term answer is:

```text
yes, redesign the internal async substrate deeply;
no, do not collapse all async work into one ambient caller-authority model.
```

## First Slice Implications

A behavior-changing L0 slice should not patch `process_one_work()` to perform
global lookup. The safer sequence is:

```text
1. Add type-only carrier names and helper contracts.
2. Choose one narrow caller-derived subsystem or synthetic test wrapper.
3. Prepare carrier before queue_work()/kthread_queue_work().
4. Assert carrier at worker callback entry.
5. Consume/release ticket on complete/cancel.
6. Keep generic unconverted work categorized as service or kernel-internal,
   with no caller-derived security claim.
```

This preserves Linux compatibility because most existing workqueue users are
not immediately forced into CapSched caller attribution.

## Hard Rejects

```text
generic kworker current task is treated as caller Domain
generic process_one_work() walks a global cap table to discover caller authority
pending work carrier is overwritten by a second caller
delayed work timer performs slow authority discovery
rescue worker bypasses caller ticket requirement
flush_work() is treated as authorization
cancel_work() frees a ticket while the callback can still run using it
kthread_work uses worker->task authority for caller endpoint effects
```

## Open Follow-Ups

```text
Q-025:
  Which first subsystem should exercise caller-derived work wrappers: a
  synthetic capsched validation work item, io_uring fallback work, net work, or
  a broker/service test endpoint?

Q-026:
  Should delayed caller-derived work reserve budget at submit time or use a
  local preauthorized reservation object at timer fire?

Q-027:
  What merge semantics are acceptable for existing single-work coalescing
  patterns such as "schedule once to process many accumulated events"?

Q-028:
  Which workqueue categories qualify as kernel-internal exceptions in L0, and
  how are they audited so the exception class does not swallow user-derived
  work?
```
