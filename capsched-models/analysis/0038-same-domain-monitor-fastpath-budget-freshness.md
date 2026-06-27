# Analysis 0038: Same-Domain Monitor Fast Path and Budget Freshness

Status: Draft source map with TLC-backed design filter, no implementation approved

Date: 2026-06-27

Linux source:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
commit: 7cf0b1e415bcead8a2079c8be94a9d41aad7d462
```

## Purpose

CapSched-H wants to avoid monitor transitions for same-Domain thread switches:

```text
if prev Domain == next Domain:
  do not switch MemoryView or RunToken in the monitor
```

That optimization is only safe if the monitor-owned context is still fresh:

```text
Domain epoch
MemoryView ID
root CPU budget
SchedContext budget
side/co-tenancy policy
FrozenRunUse generation
```

This note models the condition under which the same-Domain fast path can be an
optimization without becoming stale authority.

## Core Finding

The Linux scheduler has several "selected but not yet safely running" windows:

```text
pick_next_task()
  selects next under rq->lock

rq->curr = next
  stores current task before architectural switch

context_switch()
  prepare_task_switch()
  switch_mm_irqs_off()
  switch_to()
  finish_task_switch()

same-task continuation:
  no context switch at all
```

It also has tick and runtime paths:

```text
sched_tick()
hrtick()
sched_tick_remote() under NO_HZ_FULL
task_sched_runtime()
class update_curr()
```

CapSched consequence:

```text
Same-Domain fast path is not "no check".
It is "local proof that monitor-owned authority is still fresh".
```

If freshness cannot be proved, the kernel must either call the monitor, fail
closed, preempt/quarantine the task, or use a monitor-owned timer/interrupt.

## Source Anchors

Switch preparation and context switch:

```text
kernel/sched/core.c:
  prepare_task_switch()
    called with rq lock held and interrupts off before switch

  context_switch()
    calls prepare_task_switch()
    switches mm through switch_mm_irqs_off()
    switch_to() changes register/stack state
    finish_task_switch() completes after switch

  finish_task_switch()
    calls tick_nohz_task_switch()
    runs sched-in notifiers
    drops rq lock through finish_lock_switch()
```

Pick and selected state:

```text
kernel/sched/core.c:
  __pick_next_task()
    class pick_task()
    put_prev_set_next_task()

  pick_next_task()
    core-scheduling version can cache core_pick/core_pick_seq
    selected sibling tasks may be rescheduled later

  __schedule()
    pick_next_task()
    rq_set_donor()
    RCU_INIT_POINTER(rq->curr, next)
    trace_sched_switch()
    context_switch()
```

Runtime accounting:

```text
kernel/sched/core.c:
  sched_tick()
    updates rq clock
    calls donor->sched_class->task_tick()

  hrtick()
    hardirq timer
    calls rq->donor->sched_class->task_tick()

  task_sched_runtime()
    updates current class runtime before reading sum_exec_runtime

  sched_tick_remote()
    NO_HZ_FULL offloaded tick
    runs roughly once per second and comments that missing or extra ordinary
    scheduler ticks are acceptable for Linux scheduler statistics
```

NO_HZ and bandwidth:

```text
kernel/sched/core.c:
  sched_can_stop_tick()
    can stop ordinary tick for single fair task unless CFS bandwidth requires
    the tick

kernel/sched/fair.c:
  sched_fair_update_stop_tick()
    sets TICK_DEP_BIT_SCHED when CFS bandwidth requires a tick on nohz_full CPU
```

Class-specific runtime:

```text
kernel/sched/deadline.c:
  update_curr_dl()
  task_tick_dl()
  hrtick_start_dl()

kernel/sched/ext/ext.c:
  update_curr_scx()
  task_tick_scx()
  SCX_SLICE_INF can imply nohz-like unlimited slice behavior
```

## Authority Boundary

### MonitorActiveContext

CapSched-H needs a per-CPU monitor active context:

```text
MonitorActiveContext {
  domain_id
  domain_epoch
  memory_view_id
  root_budget_epoch
  root_budget_remaining
  side_policy_epoch
}
```

The Linux-visible `task->capsched_domain` pointer cannot be the production
authority root. Same-Domain comparison is a fast-path key, not a proof by
itself.

### Same-Domain Fast Path

The fast path is safe only if:

```text
prev.domain == next.domain
active_context.domain_id == next.domain_id
active_context.domain_epoch == next.domain_epoch
active_context.memory_view_id == next.memview_id
active_context.root_budget_epoch == next.root_budget_epoch
root budget remains positive
next FrozenRunUse is live and generation/epoch fresh
next SchedContext budget remains positive
side/co-tenancy policy epoch is fresh
```

If any check fails:

```text
call monitor
or fail closed
or preempt/quarantine
```

It must not silently continue because the domains compare equal in Linux memory.

### Same-Task Continuation

The scheduler may not switch at all:

```text
prev == next
```

or may continue running until an interrupt/preemption point. Therefore
revocation and root budget exhaustion cannot rely only on context-switch hooks.

Required mechanisms:

```text
monitor timer
reschedule IPI
fail-closed current continuation check
tick/hrtick dependency for Linux-only prototype
```

### Selected Budget

Budget can become stale after selection:

```text
pick selected task
budget/epoch revoked
context switch uses stale selected use
```

The implementation must have a cheap last-mile check:

```text
selected FrozenRunUse budget_epoch == current budget_epoch
remaining budget > 0
root budget > 0
```

before making `next` the active execution context. In CapSched-H, the monitor
timer must also enforce the root budget if Linux fails to reschedule.

### NO_HZ

Linux's ordinary scheduler tick may stop. That is acceptable for Linux's
fairness/accounting in configured cases, but it cannot be the only root-budget
enforcer for CapSched-H.

For capped Domains:

```text
NO_HZ tick stopped
requires monitor-owned budget timer
or CapSched hrtick/tick dependency that cannot be suppressed by the Domain
```

The production claim cannot depend on `sched_tick_remote()` alone because its
own comment allows missing or extra ordinary scheduler ticks for statistics.

## Required Invariants

```text
NoFastPathWithStaleMonitor:
  same-Domain fast path implies active monitor context, fresh epoch, fresh
  MemoryView, and fresh side/root-budget epochs

NoRunWithStaleMonitor:
  running implies monitor active context matches the task's Domain epoch and
  MemoryView

NoRunWithoutBudget:
  running implies root budget and SchedContext budget remain positive

NoNoHzBudgetWithoutMonitorTimer:
  capped Domain execution with ordinary tick stopped requires monitor-owned or
  unsuppressible budget timer

NoRevokePendingRun:
  pending epoch/MemoryView/budget revoke cannot coexist with ordinary Domain
  execution

NoSelectedBudgetStaleRun:
  selected-state budget/epoch changes must force monitor revalidation,
  refresh, or fail-closed before run
```

## Compatibility Consequences

For Linux-only L0:

```text
1. Keep same-Domain monitor logic inert or instrumented only.
2. Model selected-state budget freshness before enforcing.
3. If budget enforcement is prototyped, do not rely on ordinary tick alone
   under NO_HZ_FULL.
4. Do not treat same-Domain pointer equality as authority.
```

For monitor-backed CapSched-H:

```text
1. Domain switch requires monitor activation.
2. Same-Domain fast path requires local freshness proof.
3. Revoke/budget exhaustion needs monitor interrupt/IPI/timer coverage even
   if Linux never schedules away.
4. Linux shadow state may be compromised; active monitor context and sealed
   tokens remain the authority root.
```

## Open Questions

```text
1. Is active context freshness represented per CPU, per core, or per
   SMT/core-scheduling group?

2. Should same-Domain fast path compare a compact sealed fast-token rather than
   several Linux-visible epoch fields?

3. What exact budget split is used for root budget vs SchedContext budget in
   Linux-only L0?

4. How should proxy execution charge monitor root budget when donor and owner
   are in the same Domain but different SchedContexts?

5. Which timer is the first acceptable L0 approximation for budget enforcement:
   hrtick, sched tick, perf event, or a CapSched-specific hrtimer?
```

## Design Consequence

The fast path should be framed as:

```text
same Domain:
  skip monitor transition only after freshness proof

different Domain:
  monitor activation required

same task/no switch:
  still requires revoke and budget interrupt coverage
```

This prevents "optimization" from becoming ambient authority.
