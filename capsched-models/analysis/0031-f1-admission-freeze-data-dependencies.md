# Analysis 0031: F1 Admission-Freeze Data Dependencies

Status: Draft dependency map with TLC-backed design filter, no implementation approved

Date: 2026-06-27

Linux source:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
commit: 7cf0b1e415bcead8a2079c8be94a9d41aad7d462
```

## Purpose

`analysis/0030` established that fail-capable runnable admission belongs before
Linux writes `TASK_WAKING`.

This note asks the next question:

```text
What must already be locally available at F1 so CapSched can freeze authority
without allocation, sleep, remote service calls, monitor calls, or policy walks
under p->pi_lock?
```

This is still not an implementation approval.

## F1 Boundary

F1 is the region:

```text
kernel/sched/core.c:4292 p->pi_lock held
kernel/sched/core.c:4295 ttwu_state_match() succeeded
kernel/sched/core.c:4323 already-runnable path has not consumed the wake
kernel/sched/core.c:4349 smp_acquire__after_ctrl_dep()
kernel/sched/core.c:4357 TASK_WAKING not yet written
```

Relevant Linux guarantees:

```text
try_to_wake_up() comment says p->pi_lock stabilizes:
  p->sched_class
  p->cpus_ptr
  p->sched_task_group

select_task_rq() comment says:
  caller owns p->pi_lock
  p->cpus_ptr is stable
```

Source anchors:

```text
kernel/sched/core.c:4231-4237 p->pi_lock stabilizes scheduler fields
kernel/sched/core.c:3610-3616 select_task_rq() caller owns p->pi_lock
kernel/sched/core.c:3618-3636 select_task_rq() uses sched_class and cpus_ptr
```

## Hard Constraint

F1 is a spinlocked wake hot path. Therefore F1 must not:

```text
allocate memory
sleep
walk LSM or namespace policy
walk cgroup hierarchy for policy issuance
perform BPF/sched_ext policy computation for CapSched authority
take unrelated locks that can invert with waitqueue, futex, rtmutex, or rq locks
perform monitor calls or VM exits
perform cluster/remote authority acquisition
look up endpoint authority in a mutable global table
take slow refs that can block or depend on reclaim
```

This forces a design split:

```text
before F1:
  issue, revoke, pre-pin, and cache authority objects

at F1:
  only validate local fields and freeze a small preallocated use record

after F1:
  only nofail assertion, stale selected-use rejection before execution, or
  monitor fail-closed activation
```

## Required Local Data

F1 needs the following data to be already present and lifetime-stable.

| Data | Why needed | F1 access shape | If missing |
| --- | --- | --- | --- |
| task generation | bind FrozenRunUse to the exact task lifetime | scalar read under `p->pi_lock` or atomic | reject before `TASK_WAKING` |
| process generation | prevent stale process/thread-group authority | scalar read or stable task field | reject before `TASK_WAKING` |
| Domain pointer/id | bind execution to Domain | pre-pinned task pointer or stable task field | reject before `TASK_WAKING` |
| Domain epoch | revoke all Domain uses | atomic/READ_ONCE compare against frozen source | reject before `TASK_WAKING` |
| RunCap or resumable-run authority | prove task may become runnable | pre-resolved local pointer/slot | reject before `TASK_WAKING` |
| SchedContext pointer/id | bind CPU-time resource object | pre-pinned local pointer | reject before `TASK_WAKING` |
| SchedContext epoch | revoke CPU-time authority | atomic/READ_ONCE compare | reject before `TASK_WAKING` |
| budget state | reject clearly empty budget before enqueue | atomic read or pre-reservation | reject or mark throttled before `TASK_WAKING` |
| placement envelope | ensure later CPU selection cannot escape authority | precomputed cpumask or subset relation to `p->cpus_ptr` | reject before `TASK_WAKING` |
| FrozenRunUse storage | store the F1 result | embedded or preallocated per-task slot | reject before `TASK_WAKING` |
| revocation state | stop stale caps without global lookup | local epoch/generation bits | reject before `TASK_WAKING` |
| claim/trust mode | avoid L0 production claim confusion | compile-time/static branch/local mode | no enforcement claim |

## Placement Envelope Requirement

F1 happens before:

```text
kernel/sched/core.c:4393 select_task_rq()
kernel/sched/core.c:4402 set_task_cpu()
kernel/sched/core.c:4415 ttwu_queue()
```

After `TASK_WAKING`, ordinary rejection is forbidden. Therefore F1 must prove
one of:

```text
1. Linux cannot later select a CPU outside the FrozenRunUse placement envelope.
2. If Linux does select outside, the path is nofail repaired before enqueue
   without breaking wake ordering.
3. The post-WAKING path is explicitly fail-closed and modeled.
```

The first acceptable conservative rule is:

```text
p->cpus_ptr subset of FrozenRunUse.allowed_cpus at F1
```

Why:

```text
select_task_rq() ultimately constrains the selected CPU by is_cpu_allowed()
against p->cpus_ptr and fallback masks.
```

Source anchors:

```text
kernel/sched/core.c:3618-3623 select candidate from class or cpus_ptr
kernel/sched/core.c:3635-3636 fallback if !is_cpu_allowed(p, cpu)
kernel/sched/core.c:4005-4027 ttwu_queue_cond() checks p->cpus_ptr
```

Open risk:

```text
forced compatible CPU fallback may alter p->cpus_ptr outside CapSched intent
if CapSched placement is not integrated with affinity/cpuset/hotplug paths.
```

That belongs to the later placement-refresh model.

## Budget Requirement

F1 can cheaply reject an obviously empty SchedContext budget:

```text
atomic remaining budget <= 0
```

But F1 cannot by itself prove future nonzero budget at switch if:

```text
multiple tasks share one SchedContext
budget can be revoked or consumed after F1
root Domain budget can change in the monitor
```

Therefore the design must separate:

```text
F1 budget admission:
  cheap pre-WAKING reject or optional local reservation

Selected/switch budget validation:
  no execution if budget is stale or empty

Monitor-backed root budget:
  production hard cap independent of Linux
```

This preserves `No budget, no execution` without requiring `No budget, no
enqueue` as the final invariant.

## FrozenRunUse Storage

F1 cannot allocate:

```text
struct capsched_frozen_run_use *g = kmalloc(...)
```

Acceptable storage shapes:

```text
embedded task slot
preallocated per-task object from fork/clone
preallocated per-Domain/per-task small pool reserved outside F1
RCU-published pointer whose lifetime is already pinned by task lifetime
```

Rejected storage shapes:

```text
GFP allocation in try_to_wake_up()
slow mempool allocation under p->pi_lock
on-demand capability table lookup that may allocate
remote cluster lease materialization
monitor call to mint a fresh token
```

## Wake Queue Consequence

Wake queues make the precondition stronger.

Linux says:

```text
include/linux/sched/wake_q.h:31-33
  no guarantee the wakeup will happen later than wake_q_add()
  task must be ready to be woken at wake_q_add()

kernel/sched/core.c:1120-1125
  wake_q_add() must be used as-if it were wake_up_process()

kernel/sched/core.c:1156-1174
  wake_up_q() later calls wake_up_process()
```

CapSched implication:

```text
For wake_q users, authority readiness should hold by wake_q_add() time, not be
discovered for the first time in wake_up_q().
```

F1 may still observe revocation and reject before `TASK_WAKING`, but a missing
authority caused by lazy discovery is a design bug, not a normal hot-path
policy lookup.

## Waker Authority Is Not Generic F1 Input

Generic Linux wakeups include:

```text
waitqueue default_wake_function()
wake_q
futex wake
mutex/rtmutex/rwsem unlock
signal wake
kthread wake
IRQ thread wake
workqueue worker wake
freezer/thaw wake
timer wake
```

Most paths only pass:

```text
task pointer
state mask
wake_flags
optional waitqueue key
```

Therefore F1 cannot require a generic waker-side capability lookup. The
authority to resume execution must come from one of:

```text
target task resumable-run authority
pre-frozen wait/endpoint authority stored when the task blocked or registered
SpawnCap-derived initial authority for wake_up_new_task()
service/kernel-domain exception with explicit type
```

This is why endpoint provenance and async provenance remain separate tracks.

## Initial Implementation Consequence

The first behavior-changing slice must not start by adding a slow capability
lookup in `try_to_wake_up()`.

A realistic first enforcement-capable shape is:

```text
fork/clone:
  allocate or initialize task-local CapSched storage

block/wait/register:
  make resumable-run or endpoint-derived wake authority locally available

F1:
  read task-local authority, generation, epoch, SchedContext, placement
  write preallocated FrozenRunUse
  reject before TASK_WAKING if required local authority is absent or revoked

enqueue:
  nofail assert FrozenRunUse exists

pick/switch:
  revalidate epoch, generation, CPU, budget, and monitor token
```

## Hard Rejects

Future hook candidates are hard-rejected if they require:

```text
F1 allocation
F1 sleeping
F1 LSM policy lookup
F1 cgroup hierarchy walk for authority issuance
F1 remote cluster lease acquisition
F1 monitor call to mint authority
F1 BPF/sched_ext decision as security root
F1 cpumask allocation
post-TASK_WAKING ordinary denial because F1 data was missing
```

## Open Follow-Up

Next required refinements:

```text
1. Map block/wait/register points where resumable-run or endpoint-derived wake
   authority can be prepared before wake_q_add()/try_to_wake_up().
2. Model placement-refresh interaction with affinity/cpuset/hotplug so
   p->cpus_ptr cannot exceed FrozenRunUse.allowed_cpus.
3. Decide embedded-vs-preallocated FrozenRunUse storage shape with task_struct
   size, cacheline, and fork cost evidence.
4. Model wake_q revocation: authority ready at wake_q_add, revoked before
   wake_up_q, and pre-TASK_WAKING rejection semantics.
```

## Formal Evidence

Supporting tiny model and TLC record:

```text
formal/0014-f1-admission-data-model/
validation/0026-f1-admission-data-tlc.md
```

This evidence is a design filter only. It does not approve a Linux hook point
and does not prove the full Linux wakeup implementation.
