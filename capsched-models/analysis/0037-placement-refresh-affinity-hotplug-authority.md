# Analysis 0037: Placement Refresh, Affinity, cpuset, Hotplug Authority

Status: Draft source map with TLC-backed design filter, no implementation approved

Date: 2026-06-27

Linux source:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
commit: 7cf0b1e415bcead8a2079c8be94a9d41aad7d462
```

## Purpose

This note refines the placement side of `FrozenRunUse`:

```text
If a run use freezes an allowed CPU envelope, later affinity, cpuset,
CPU-hotplug, migration, sched_ext, or fallback paths must not let the task run
outside that envelope.
```

Linux has a rich and dynamic placement system. CapSched must preserve Linux
compatibility while not treating mutable Linux placement state as authority to
expand a capability.

This is not an approval to patch scheduler placement yet.

## Core Finding

Linux placement is intentionally mutable:

```text
task->cpus_ptr:
  effective CPU mask used by scheduler placement

task->cpus_mask:
  configured task mask

task->user_cpus_ptr:
  user-requested affinity mask, if present

cpuset effective_cpus:
  cgroup-derived effective placement mask

cpu_active_mask:
  CPUs available for ordinary scheduler placement and migration

cpu_online_mask:
  CPUs online, including some hotplug transitional/per-CPU kthread cases
```

CapSched consequence:

```text
Linux p->cpus_ptr is an input to placement authority, not the authority root.
```

The runnable CPU set for a Domain task must be the intersection of:

```text
RunCap/SchedContext placement envelope
FrozenRunUse.allowed_cpus
current task affinity/cpuset effective mask
CPU active/online policy for the task type
Domain co-tenancy and isolation policy
monitor MemoryView / CPU ownership constraints in CapSched-H
```

If the intersection becomes empty, Linux may need a compatibility fallback, but
CapSched must not silently expand the capability envelope.

## Source Anchors

Task placement fields:

```text
include/linux/sched.h:
  task_struct::nr_cpus_allowed
  task_struct::cpus_ptr
  task_struct::user_cpus_ptr
```

Generic CPU-allowed test:

```text
kernel/sched/core.c:
  is_cpu_allowed()
    rejects CPUs outside p->cpus_ptr
    ordinary user tasks require cpu_active()
    migrate_disabled tasks can finish on online CPUs
    per-CPU kthreads have special online CPU allowance

kernel/sched/sched.h:
  task_allowed_on_cpu()
    tests p->cpus_ptr and task_cpu_possible()
```

Affinity update and migration:

```text
kernel/sched/core.c:
  set_cpus_allowed_common()
    updates p->cpus_ptr / p->cpus_mask / nr_cpus_allowed

  __set_cpus_allowed_ptr_locked()
    checks task_cpu_possible_mask()
    chooses destination from cpu_active_mask or cpu_online_mask
    calls do_set_cpus_allowed()
    then affine_move_task()

  affine_move_task()
    blocks until a valid affinity change has migrated or completed
    has migrate_disable and TASK_WAKING special handling

  migration_cpu_stop()
    flushes pending wakeups before enforcing cpus_ptr
    moves queued tasks with __migrate_task()

  move_queued_task()
    deactivates, set_task_cpu(), then reactivates on the new rq
```

Wake and fork placement:

```text
kernel/sched/core.c:
  select_task_rq()
    called with p->pi_lock held
    calls class select_task_rq when migratable
    otherwise chooses cpumask_any(p->cpus_ptr)
    falls back through select_fallback_rq() if !is_cpu_allowed()

  try_to_wake_up()
    uses select_task_rq() before ttwu_queue()

  wake_up_new_task()
    calls select_task_rq() after TASK_RUNNING, noting cpus_ptr can change
    during fork and selected CPU can disappear through hotplug

  sched_exec()
    uses class select_task_rq() as a migration opportunity
```

Fallback and cpuset:

```text
kernel/sched/core.c:
  select_fallback_rq()
    searches allowed online CPUs
    can call cpuset_cpus_allowed_fallback()
    can call set_cpus_allowed_force()

kernel/cgroup/cpuset.c:
  cpuset_attach_task()
    computes cpus_attach and calls set_cpus_allowed_ptr()

  cpuset_cpus_allowed()
    returns a non-empty active subset if possible

  cpuset_cpus_allowed_fallback()
    last-resort fallback; comments acknowledge temporary wrong masks during
    races and later set_cpus_allowed_ptr() repair
```

CPU hotplug:

```text
kernel/sched/core.c:
  sched_cpu_deactivate()
    clears cpu_active()
    installs balance_push
    relies on ttwu/is_cpu_allowed no longer targeting the CPU

  balance_push()
    pushes ordinary tasks off a dying CPU

  __balance_push_cpu_stop()
    uses select_fallback_rq() and __migrate_task()

  sched_cpu_activate()
    sets cpu_active()
    rebuilds cpuset/scheduler domains
```

Class-specific placement:

```text
kernel/sched/fair.c:
  select_task_rq_fair()
    uses p->cpus_ptr and wake/energy/affine paths

kernel/sched/rt.c:
  select_task_rq_rt()
    can choose a lower-priority rq through find_lowest_rq()

kernel/sched/deadline.c:
  select_task_rq_dl()
    can choose a later rq through find_later_rq()

kernel/sched/ext/ext.c:
  select_task_rq_scx()
    may call BPF ops.select_cpu()
    records p->scx.selected_cpu
  set_cpus_allowed_scx()
    reports the effective p->cpus_ptr to the BPF scheduler
```

Core scheduling:

```text
kernel/sched/core.c:
  sched_core_find() / try_steal_cookie paths use is_cpu_allowed() before
  moving a queued task.
```

## Authority Boundary

### PlacementEnvelope

CapSched needs a placement envelope separate from Linux's current effective
mask:

```text
PlacementEnvelope:
  CPUs allowed by RunCap/SchedContext/Domain policy
  epoch
  co-tenancy constraints
  task type exceptions
```

`FrozenRunUse.allowed_cpus` is derived from:

```text
PlacementEnvelope ∩ p->cpus_ptr ∩ active CPU policy
```

It must never be expanded by:

```text
cpuset fallback
set_cpus_allowed_force()
sched_ext select_cpu()
class-specific select_task_rq()
queued migration
CPU hotplug rescue
```

### PlacementEpoch

Any event that can change the intersection must invalidate or refresh frozen
placement:

```text
set_cpus_allowed_common()
cpuset attach / cpuset effective_cpus update
CPU active/online transition
Domain placement policy change
SchedContext allowed CPU change
core co-tenancy cookie change
sched_ext selected_cpu change
```

The cheap hot-path check should be:

```text
FrozenRunUse.placement_epoch == task/domain placement_epoch
cpu ∈ FrozenRunUse.allowed_cpus
cpu ∈ current p->cpus_ptr
is_cpu_allowed(p, cpu)
```

If false, do not run that frozen use. Refresh before admission, migrate within
the envelope, or fail closed.

### Fallback Is Not Authority

Linux fallback is compatibility machinery. It can save the system from a task
with no current cpuset CPU during hotplug or cpuset races.

CapSched cannot treat that fallback as capability expansion:

```text
Linux fallback:
  may temporarily broaden p->cpus_ptr to keep Linux alive

CapSched:
  must not broaden FrozenRunUse.allowed_cpus or SchedContext placement
```

If no CPU remains in the CapSched envelope:

```text
Linux-only L0:
  fail closed, block/quarantine, or mark Domain unschedulable

Monitor-backed CapSched-H:
  monitor root placement/CPU ownership wins; Linux fallback cannot create a
  CPU right
```

### Selected-State Staleness

`select_task_rq()` happens before enqueue, and selected state can become stale:

```text
affinity changed
cpuset changed
CPU went inactive
sched_ext returned a bad/stale selected CPU
migration moved a queued task
core scheduling stole a compatible cookie task
```

Therefore `selected_cpu` is an optimization hint, not authority. The final run
check must revalidate against the frozen envelope and current placement epoch.

### Migration Disabled and Per-CPU kthreads

Linux deliberately allows special cases:

```text
migrate_disabled:
  may finish on an online CPU even when ordinary migration is restricted

per-CPU kthread:
  may run on online but not-yet-active / hotplug transitional CPUs
```

CapSched must classify these as task-type exceptions:

```text
KernelCoreWork / per-CPU service work:
  exceptional placement authority from service/kernel domain policy

Domain user task:
  no silent exception; if it cannot satisfy the envelope, it stops or is
  migrated before running
```

## Required Invariants

```text
NoRunOutsideCurrentPlacement:
  running implies live FrozenRunUse, fresh PlacementEpoch, CPU in frozen
  envelope, CPU in current effective mask, and task allowed on CPU

NoSelectedOutsideFrozenEnvelope:
  selected state cannot be treated as authority if it is outside the frozen
  envelope or stale placement epoch

NoQueuedMoveOutsideFrozenEnvelope:
  queued migration/core stealing cannot move an authority-bearing task to a CPU
  outside FrozenRunUse.allowed_cpus

NoFallbackExpansionCreatesAuthority:
  cpuset/fallback/force-affinity can repair Linux placement but cannot create
  CapSched execution authority

NoRunOnInactiveCpu:
  ordinary Domain execution cannot run on inactive CPUs; exceptions require
  explicit kernel/service classification

NoMigrationPendingRuns:
  while placement is invalid and migration/refresh is pending, the task must
  not continue as ordinary Domain execution
```

## Compatibility Consequences

This argues for a two-layer placement rule:

```text
Linux compatibility layer:
  keep existing p->cpus_ptr, cpuset, hotplug, class, and sched_ext behavior

CapSched authority layer:
  validate or refresh the frozen placement envelope around those decisions
```

The L0 prototype can avoid deep hotplug surgery by starting with:

```text
1. Track a placement epoch in task/domain/SchedContext scaffolding.
2. Mark frozen run use stale on affinity/cpuset/SchedContext placement changes.
3. Validate selected CPU against FrozenRunUse.allowed_cpus at admission and
   before execution.
4. Treat cpuset fallback as fail-closed for CapSched authority if it would
   expand the capability envelope.
```

No behavior-changing patch should claim protection unless it covers queued,
selected, running, migration-pending, and fallback states.

## Open Questions

```text
1. Should placement_epoch be per task, per Domain, per SchedContext, or split?

2. How should migrate_disable current-continuation be represented in RunCap:
   bounded continuation ticket or service/kernel exception?

3. Should sched_ext be allowed to see CapSched effective placement, or should
   it receive only a narrowed p->cpus_ptr view?

4. What fail-closed action is acceptable for no-intersection placement in
   Linux-only L0 without breaking compatibility too badly?

5. How should core scheduling cookie changes interact with Domain co-tenancy
   and PlacementEnvelope epochs?
```

## Design Consequence

Placement authority should be modeled as:

```text
selected CPU:
  hint

p->cpus_ptr:
  mutable Linux effective placement input

FrozenRunUse.allowed_cpus:
  frozen authority envelope

PlacementEpoch:
  freshness check connecting frozen authority to current Linux placement and
  CapSched policy
```

The scheduler may use Linux's placement machinery to choose efficient CPUs, but
CapSched must validate that choice against a fresh capability envelope before
execution.
