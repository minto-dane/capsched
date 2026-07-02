# Analysis 0114: sched_ext, Core Scheduling, and Proxy Coverage Boundary

Status: Source-verified design boundary; no implementation approved

Date: 2026-07-02

## Purpose

Define the coverage decision required before any P3/P4/P5 implementation can
claim that a final run edge is covered.

The core problem:

```text
Linux selected-state is not SchedExecLease authority.
```

sched_ext, core scheduling, and proxy execution can all transform the apparent
"next task" relation after earlier scheduler decisions. A future
SchedExecLease hook must either cover these transformations or explicitly
exclude them from protection claims.

Source basis:

```text
linux_branch=capsched-linux-l0
linux_commit=a0f2676adda634391983e74f29fcba577a9c919e
linux_subject=sched/exec_lease: Add task identity shadow
```

## Coverage Decision

Current design decision:

```text
P3/P4 design may identify anchors, but runtime coverage is not approved.
P5 denial must not be proposed until sched_ext, core scheduling, and proxy
execution are each classified as supported, disabled, or excluded.
```

The default classification for protection claims is:

```text
uncovered until explicitly proved covered
```

## sched_ext Boundary

Source surfaces:

```text
file: kernel/sched/ext/ext.c
move_remote_task_to_local_dsq()
task_can_run_on_remote_rq()
consume_dispatch_q()
scx_dispatch_sched()
balance_one()
do_pick_task_scx()
pick_task_scx()
ext_server_pick_task()
scx_prio_less()
```

Design finding:

```text
sched_ext has its own custody, dispatch queue, bypass, fallback, local/global
DSQ, direct dispatch, retry, and server paths. DSQ custody is selected state,
not runnable authority.
```

Specific hazards:

```text
consume_dispatch_q() can migrate a remote task into the local DSQ.
move_remote_task_to_local_dsq() mutates sticky_cpu, deactivates, sets CPU, and
  reactivates the task.
task_can_run_on_remote_rq() is Linux eligibility and compatibility, not
  SchedExecLease authority.
scx_dispatch_sched() may consume global/bypass DSQs and loop around
  ops.dispatch().
do_pick_task_scx() can return RETRY_TASK when higher-priority classes appear.
ext_server_pick_task() means server-backed selection can force an SCX task.
scx_prio_less() lets core scheduling compare SCX tasks, including BPF
  ordering through core_sched_before().
```

Required future decision:

```text
Option A: disable sched_ext while test denial is enabled.
Option B: support sched_ext by validating DSQ consume, direct dispatch,
          bypass, fallback, and server pick edges.
Option C: exclude sched_ext from runtime coverage and forbid protection claims.
```

Until one option is chosen, sched_ext is not covered.

## Core Scheduling Boundary

Source surfaces:

```text
file: kernel/sched/core.c
pick_next_task()
rq->core_pick
rq->core_dl_server
rq->core->core_task_seq
rq->core->core_pick_seq
rq->core_sched_seq
sched_core_find()
try_steal_cookie()
move_queued_task_locked()
sched_core_balance()
```

Design finding:

```text
Core scheduling can cache sibling picks and later consume them if task sequence
state still matches. It can also steal a compatible cookie task and move it
through move_queued_task_locked().
```

Specific hazards:

```text
The fast path can use rq->core_pick instead of recomputing from class state.
Sibling picks are tied to core_pick_seq/core_task_seq/core_sched_seq, not to a
SchedExecLease tuple.
try_steal_cookie() can move a queued task across runqueues before later
execution.
Core force-idle behavior is a Linux side-channel mitigation and cannot stand in
for Domain co-tenancy authority.
```

Required future decision:

```text
Core cached picks must be invalidated or revalidated at final consumption.
Core sibling picks need tuple freshness bound to core_pick_seq/core_task_seq.
Cookie steal moves need move-edge validation before move_queued_task_locked().
```

Until this is modeled against current source and tested, core scheduling is not
covered by runtime protection claims.

## Proxy Execution Boundary

Source surfaces:

```text
file: kernel/sched/core.c
sched_proxy_exec()
rq_set_donor()
find_proxy_task()
proxy_resched_idle()
proxy_deactivate()
proxy_migrate_task()
proxy_release_rq_lock()
proxy_reacquire_rq_lock()
sched_tick()
```

Design finding:

```text
Proxy execution splits the scheduling context donor from the execution context.
sched_tick() accounts to rq->donor. __schedule() may pick a donor, set it on
the rq, then replace next with an owner/executor discovered through
find_proxy_task().
```

Specific hazards:

```text
Running authority for next is not necessarily budget authority for donor.
Charging rq->curr alone is wrong under proxy execution.
proxy_resched_idle() can deliberately switch the effective next task to idle.
proxy_migrate_task() deactivates, changes CPU with proxy_set_task_cpu(), drops
  rq lock, attaches to another rq, and returns to pick_again.
find_proxy_task() can return NULL to force a pick_again retry.
```

Required future decision:

```text
Run validation tuple must include donor, executor/current, and proxy relation.
Budget subject must be donor-aware and cannot be inferred from rq->curr alone.
Proxy migration must invalidate old run and move tuples.
Proxy retry must satisfy the same bounded retry/ineligibility design as
ordinary final denial.
```

Until this relation is modeled and tested, proxy execution is not covered by
runtime protection claims.

## Implementation-Ready Consequence

Before implementation scope reopens, the project needs one of:

```text
strict exclusion:
  test denial mode refuses sched_ext/core/proxy coverage claims and disables or
  blocks the relevant features when enabled.

full design support:
  source-specific tuple fields and negative tests cover sched_ext DSQ custody,
  core cached picks, and proxy donor/current/executor relations.
```

The project must not choose the ambiguous middle:

```text
run a final hook in __schedule() and assume all selected-state transformations
are covered.
```

## Non-Claims

This note is not implementation, hook approval, runtime coverage, sched_ext
support approval, core scheduling support approval, proxy support approval,
runtime denial approval, monitor verification, protection evidence, or
cost-efficiency evidence.
