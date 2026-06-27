# Validation 0041: Workqueue Origin Observation Plan

Status: Planned trace-only validation, not executed

Date: 2026-06-27

Related analysis:

```text
analysis/0046-workqueue-origin-taxonomy.md
analysis/workqueue-origin-taxonomy-v1.json
analysis/0045-workqueue-internal-redesign-boundary.md
```

## Purpose

This validation plan turns the workqueue origin taxonomy into an observation
workflow. It is not an enforcement plan and not a protection proof.

The purpose is to classify observed async paths as:

```text
PerInvocation
ExplicitMerge
ServiceOnly
KernelException
InterruptDeferred
ReclaimRescue
TaskLocal
unknown_or_mixed
```

before any generic workqueue behavior hook is proposed.

## Non-Claims

This plan does not prove:

```text
caller endpoint authority is protected
BudgetTicket accounting is correct
worker execution is safe
all callsites are classified
unknown work is harmless
```

It only produces trace evidence and source anchors for classification.

## Trace Inputs

Enable generic workqueue tracepoints:

```text
workqueue/workqueue_queue_work
workqueue/workqueue_activate_work
workqueue/workqueue_execute_start
workqueue/workqueue_execute_end
```

Enable kthread work tracepoints:

```text
sched/sched_kthread_work_queue_work
sched/sched_kthread_work_execute_start
sched/sched_kthread_work_execute_end
```

Enable adjacent async evidence:

```text
io_uring/io_uring_task_work_run
raw_syscalls/sys_enter
raw_syscalls/sys_exit
sched/sched_process_exec
sched/sched_process_exit
```

Potential kprobes or fprobes:

```text
queue_work_on
__queue_work
process_one_work
kthread_queue_work
kthread_worker_fn
task_work_add
task_work_run
irq_work_queue
irq_work_queue_on
irq_work_single
irq_work_run
current_is_workqueue_rescuer
```

`queue_work()` itself is inline and should not be assumed kprobeable.

## Stack Evidence

Tracepoints identify:

```text
work pointer
callback function
workqueue name
requested CPU
pool CPU
```

They do not identify the semantic caller by themselves.

For queue-site classification, use one of:

```text
trace event stacktrace option
targeted fprobe with stack capture
function graph around selected callback families
static source map from callback function to INIT_WORK and queue callsites
```

Without a queueing stack or source map:

```text
classification = unknown_or_mixed
```

## Output Schema

The observation output should be a TSV file:

```text
work_ptr
callback_symbol
workqueue_name
queue_site
execute_site
taxonomy_class
origin_context
object_scope
coalescing
endpoint_effect
authority_source
reclaim_path
monitor_relevance
confidence
reason
```

Allowed confidence:

```text
observed
partially_observed
source_inferred
unknown_or_mixed
not_trace_provable
```

## Workload Seeds

Use narrow workloads that intentionally drive different classes:

```text
PerInvocation:
  AIO fsync or IOMMU SVA fault group if available

ExplicitMerge:
  AIO poll repeated wakeup, block zoned plug path where available, or a
  synthetic observation-only kernel path if hardware coverage is absent

ServiceOnly:
  io_uring ring teardown, timerfd/timekeeping resume if triggerable, cgroup
  release work

KernelException:
  workqueue idle cull, RCU callback driving, scheduler remote tick maintenance

InterruptDeferred:
  irq_work users, BH workqueue users, VFIO virqfd/eventfd injection where
  available

ReclaimRescue:
  WQ_MEM_RECLAIM workqueue presence and rescuer detection; avoid claiming
  actual rescuer execution unless current_is_workqueue_rescuer or trace
  evidence proves it

TaskLocal:
  task_work_add/task_work_run paths from io_uring, delayed fput, namespace
  cleanup, perf, or scheduler task work
```

Hardware-dependent paths should be optional. Missing hardware coverage is a
coverage gap, not a reason to weaken the taxonomy.

## Classification Rules

PerInvocation requires:

```text
unique work object for one resource operation
no intentional pending coalescing
callback source shows one request or one fault group
```

ExplicitMerge requires:

```text
pending-bit, delayed-mod, list, refcount, or flag evidence that multiple events
can share one pending work item
```

ServiceOnly requires:

```text
source shows maintenance, cleanup, teardown, or subsystem lifecycle work
and no caller-attributed endpoint effect claim
```

KernelException requires:

```text
source is core kernel liveness or infrastructure
exception reason is recorded
endpoint effect is none or delegated separately
```

InterruptDeferred requires:

```text
source originates from IRQ, softirq, BH workqueue, timer, or irq_work
and any endpoint effect is deferred to another classified path
```

ReclaimRescue requires:

```text
WQ_MEM_RECLAIM or rescuer_possible evidence
and a rule that rescuer execution is liveness, not authority
```

TaskLocal requires:

```text
task_work_add or task-local execution evidence
and generation/exec/revoke considerations recorded
```

Unknown/mixed is mandatory when:

```text
queue site is unknown
callback can be reused by multiple containers with different meanings
callback performs mixed endpoint and maintenance effects
source depends on hardware not present in the trace
tracepoint evidence lacks source correlation
```

## Safety Gate

Before implementation:

```text
No generic workqueue enforcement hook may be proposed from tracepoint evidence
alone.
```

The minimum evidence is:

```text
trace evidence
+ source queue-site map
+ taxonomy class
+ endpoint effect map
+ merge/coalescing rule
+ revoke/cancel/settlement rule
```

If that evidence is missing:

```text
next step = add observation-only instrumentation or narrow source analysis
```

## Expected Next Artifact

The next executable artifact should be a QEMU trace runner or source inventory
tool that emits:

```text
workqueue-origin-classification.tsv
workqueue-origin-gaps.tsv
```

The result should be recorded as a new validation record before any
behavior-changing async work hook.
