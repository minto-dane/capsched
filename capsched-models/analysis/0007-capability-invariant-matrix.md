# Analysis 0007: Capability Invariant Matrix

Status: Draft

Date: 2026-06-25

Linux base:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
commit: 4edcdefd4083ae04b1a5656f4be6cd83ae919ef4
```

## Purpose

This matrix records what the current upstream source reading suggests about
each accepted CapSched invariant. It separates:

- what Linux already does well
- what CapSched can reuse as policy or structure
- what is missing for a capability security claim
- what must be modeled before implementation

## Matrix

| Invariant | Existing Linux asset | Missing for CapSched | First model question |
| --- | --- | --- | --- |
| EXEC-001 No RunCap, no enqueue | wakeup/activation path, `p->on_rq`, scheduler locking | non-ambient authorization before all runnable paths, including already-runnable and delayed cases | What exact state transition requires FrozenRunUse? |
| EXEC-002 No SchedContext, no execution | scheduler classes, pick path, cgroups, cpuset | class-crossing explicit CPU-time authority object | Can a task be selected if SchedContext is absent, exhausted, or revoked? |
| EXEC-003 No budget, no execution | CFS/RT/DL/scx runtime accounting and throttling | security-semantic budget not forgeable by mutable Linux state | Is budget consumed at tick, context switch, class update, or monitor timer? |
| EXEC-004 No FrozenRunUse, no runqueue entry | enqueue/dequeue and `p->on_rq` state | frozen lease tied to task generation and domain epoch | How are delayed, throttled, migrating, and remote-wake states represented? |
| EXEC-005 No valid epoch/generation, no execution | exec `self_exec_id`, task lifetime, RCU release | explicit task/process/domain generation semantics | Can stale runqueue entries be invalidated lazily and safely? |
| EXEC-006 No DomainTag activation, no cross-Domain context switch | context switch, mm/TLB path, core scheduling | explicit DomainTag activation and monitor token validation | What must be true before `next` becomes CPU-local authority? |
| ASYNC-001 No async work without provenance | centralized workqueue/task_work/kthread/io_uring dispatch | caller frozen authority and service-domain intersection | Which async paths require caller authority versus pure service authority? |
| BROKER-001 No caller budget, no broker/service execution | cgroups, io workers, kernel workers, service-like subsystems | budget donation tied to endpoint request | Does broker work charge caller, service, or both? |
| BOUNDARY-001 No raw pointer authority across Domains | refcounting, RCU, fd tables, namespaces | typed object endpoints and per-Domain mutable state | Which kernel references are authority and must not cross Domains raw? |
| MONITOR-001 Linux-only prototypes must not claim hypervisor isolation | none, this is a project discipline rule | explicit claim boundary and later HyperTag Monitor | What exact L0 claims are allowed after prototype benchmarks? |

## Good Existing Structures

The source reading found real assets:

- `TASK_NEW` and staged fork setup reduce premature execution hazards.
- Scheduler locking rules give a place to define fast validation constraints.
- `enqueue_task()` and class callbacks expose runnable-state transitions.
- Class runtime accounting provides tested policy behavior.
- cpuset and scheduler topology already express local placement and partitioning.
- core scheduling already models a narrow form of co-tenancy.
- LSM and credentials provide rich policy inputs.
- workqueue, task_work, kthread, timer, softirq, and io_uring have central
  dispatch points that can be instrumented or modeled.

## Structural Problems

The same source reading found problems that CapSched cannot hand-wave away:

- Linux authority is mostly ambient once code runs in kernel context.
- Existing controls are mutable Linux state, not monitor-protected roots.
- Wakeup and enqueue are not one path.
- "Runnable" is not one state: queued, delayed, throttled, migrating,
  wake-pending, and selected differ.
- Budget accounting differs by scheduler class.
- `rq->donor` and proxy execution can differ from a simple "current task"
  budget model.
- Core scheduling can force idle even when runnable tasks exist.
- sched_ext can fall back or bypass, which is incompatible with a security root.
- Fork/clone copies or shares large amounts of authority by Linux semantics.
- Exec changes code/mm/cred but should not mint DomainTag.
- Async work can execute after the caller task changed or disappeared.
- A single shared mutable kernel address space cannot support the final
  hypervisor-equivalent claim.

## Formal Model Candidates

The reading suggests three early model candidates.

### Model A: Runnable Lease

Objects:

```text
Task
TaskGeneration
DomainEpoch
RunCap
SchedContext
FrozenRunUse
RunqueueState
```

Safety properties:

```text
No queued task lacks FrozenRunUse.
No selected task has mismatched task generation.
No selected task has mismatched domain epoch.
No selected task has exhausted SchedContext.
```

Reason to choose first:

It directly covers EXEC-001 through EXEC-005.

### Model B: Domain Switch

Objects:

```text
CPU
CurrentDomainTag
PrevTask
NextTask
MemoryView
RunToken
MonitorState
```

Safety properties:

```text
Cross-domain switch requires valid token.
CPU-local active DomainTag equals next task Domain before user/kernel execution resumes.
Failed monitor activation cannot run next task.
```

Reason to choose first:

It links scheduler semantics to the eventual HyperTag boundary.

### Model C: Async Provenance

Objects:

```text
CallerTask
ServiceWorker
WorkItem
FrozenAuthority
BudgetTicket
EndpointCap
Completion
```

Safety properties:

```text
No Domain-derived work executes without provenance.
Service execution is bounded by caller budget and service authority.
Revoked caller epoch invalidates queued work.
```

Reason to choose first:

It targets the most dangerous confused-deputy path.

## Current Recommendation

Start formal modeling with Model A, but include an explicit placeholder relation
for async work so the model does not accidentally imply that all execution
comes from direct task enqueue. Then model C should follow before any security
claim beyond L0 performance measurement.

## Open Questions

1. Does `FrozenRunUse` attach to task state, a runqueue entry abstraction, or a
   scheduler-class-specific entity?
2. Is budget depletion represented as dequeue, throttle, failed pick, or forced
   context switch?
3. How does a Domain epoch revoke queued work on remote CPUs without breaking
   wakeup scalability?
4. Which Linux worker paths can be classified as pure service authority, and
   which must carry caller frozen authority?
5. How should cluster leases interact with local cpuset fallback behavior?
