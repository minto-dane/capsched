# Analysis 0148: SchedExecLease P5A-R2 Invalidation Source Map

Date: 2026-07-04

Status: source map defined. No Linux patch is approved.

## Purpose

Validation/0190 established the P5A-R2 selector model gate. The gate requires
future picker-visible lease eligibility to be invalidated on:

```text
task generation change
exec generation change
domain/grant epoch change
budget exhaustion/refill
affinity/cpuset change
migration
group movement
task exit
monitor receipt revoke
```

This note maps those abstract invalidation events to concrete Linux source
surfaces. It does not approve a selector patch. It only records where a future
implementation must refresh or invalidate a `min_pickable_vruntime`-style
summary.

## Core Observation

Invalidation cannot be limited to `enqueue_entity()` and `dequeue_entity()`.
P5A-R2 cache freshness can be broken by events that do not look like ordinary
rb-tree insertion or removal:

```text
fork identity initialization
exec generation bump
exit flagging
affinity mask rewrite
queued migration
load-balance migration
cgroup task-group movement
cpuset effective-cpumask updates
CFS bandwidth exhaustion/refill
current entity entering/leaving the tree
future monitor receipt revoke
```

That is the key architectural result of this map.

## Source Families

### Lifecycle And Identity

SchedExecLease already has private lifecycle helpers:

```text
linux/kernel/sched/exec_lease.c:102  sched_exec_task_reset
linux/kernel/sched/exec_lease.c:110  sched_exec_task_prepare_fork
linux/kernel/sched/exec_lease.c:119  sched_exec_task_commit_exec
linux/kernel/sched/exec_lease.c:125  sched_exec_task_exit
```

Current callsites are:

```text
linux/kernel/fork.c:954    reset after task-struct allocation
linux/kernel/fork.c:2153   prepare fork after creds copy
linux/fs/exec.c:1171       commit exec generation after exec_mmap
linux/kernel/exit.c:948    mark task exiting
```

Future P5A-R2 must treat these as cache invalidation boundaries. A cached
pickable summary derived from an old task or exec generation must not survive
fork, exec, or exit.

### Affinity And CPU Placement

Affinity and migration paths can make a task no longer valid for a CPU-local
summary:

```text
linux/kernel/sched/core.c:3114  __set_cpus_allowed_ptr_locked
linux/kernel/sched/core.c:3180  do_set_cpus_allowed
linux/kernel/sched/core.c:3343  set_task_cpu
linux/kernel/sched/core.c:3392  __set_task_cpu
linux/kernel/sched/fair.c:9874  select_task_rq_fair
linux/kernel/sched/fair.c:9946  migrate_task_rq_fair
linux/kernel/sched/fair.c:10015 set_cpus_allowed_fair
```

Queued moves are separate source surfaces:

```text
linux/kernel/sched/core.c:2546      move_queued_task
linux/kernel/sched/core.c:2555      set_task_cpu in move_queued_task
linux/kernel/sched/sched.h:4122     move_queued_task_locked
linux/kernel/sched/sched.h:4130     set_task_cpu in locked move
```

Load-balance migration surfaces include:

```text
linux/kernel/sched/fair.c:11080 can_migrate_task
linux/kernel/sched/fair.c:11209 detach_task
linux/kernel/sched/fair.c:11406 attach_tasks
```

Future P5A-R2 must invalidate or recompute summaries across source rq,
destination rq, and affected group hierarchy. CPU-local budget or affinity
cannot be treated as task-global state.

### Group And Cpuset Movement

Group movement can change the `cfs_rq` hierarchy that owns a `sched_entity`:

```text
linux/kernel/sched/core.c:9485  sched_move_task
linux/kernel/sched/core.c:9596  cpu_cgroup_attach
linux/kernel/sched/core.c:9602  sched_move_task call from cpu cgroup attach
linux/kernel/sched/fair.c:15452 task_change_group_fair
linux/kernel/cgroup/cgroup.c:896  css_set_move_task
linux/kernel/cgroup/cgroup.c:3015 cgroup_attach_task
```

Cpuset updates can rewrite allowed CPUs for many tasks:

```text
linux/kernel/cgroup/cpuset.c:1060 cpuset_update_tasks_cpumask
linux/kernel/cgroup/cpuset.c:2395 update_cpumask
linux/kernel/cgroup/cpuset.c:3114 cpuset_attach_task
```

Therefore the P5A-R2 summary must not be only leaf-local. Parent group entities
need refreshed "child has immediately selectable pickable descendant" state
after group and cpuset movement.

### Budget, Throttle, And Refill

Budget-style eligibility can change during tick/runtime accounting and CFS
bandwidth changes:

```text
linux/kernel/sched/fair.c:2311 update_curr
linux/kernel/sched/fair.c:6742 entity_tick
linux/kernel/sched/fair.c:6889 account_cfs_rq_runtime body
linux/kernel/sched/fair.c:7205 throttle_cfs_rq runtime assignment check
linux/kernel/sched/fair.c:7240 unthrottle_cfs_rq
linux/kernel/sched/fair.c:7676 sched_cfs_period_timer
```

CapSched/DomainLease budget is not identical to CFS bandwidth, but these
surfaces are proof that runtime and refill events can happen outside ordinary
enqueue/dequeue. Future root budget and SchedContext budget must have equally
explicit invalidation/refill hooks.

### Current Entity

`cfs_rq->curr` is outside the rb-tree:

```text
linux/kernel/sched/sched.h:703  cfs_rq->curr
linux/kernel/sched/fair.c:6651 set_next_entity
linux/kernel/sched/fair.c:6721 put_prev_entity
```

Future P5A-R2 must include current-entity freshness separately from rb-subtree
metadata. A tree-only summary cannot prove that `curr` is safe or unsafe.

### Future Monitor Receipt

There is no monitor receipt implementation yet. The map still reserves it as
an explicit source family:

```text
monitor receipt revoke / epoch revoke / root budget revoke:
  future HyperTag-owned invalidation source
```

The absence of a current Linux source anchor is not permission to ignore it.
It is a future integration gap that must remain visible.

## Required Consequence

The next selector design cannot say:

```text
we update the summary on enqueue/dequeue
```

and stop there.

It must instead say:

```text
every event family in this source map either:
  updates the affected leaf/group/current summaries under the right lock
or:
  explicitly marks them stale and prevents picker trust until refresh
```

## Non-Claims

This source map does not approve:

```text
Linux code changes
accepting 0009-0012
runtime denial correctness
complete CFS deny-and-repick correctness
runtime coverage
hot layout changes
new public ABI
monitor enforcement
production protection
cost efficiency
deployment readiness
datacenter readiness
```
