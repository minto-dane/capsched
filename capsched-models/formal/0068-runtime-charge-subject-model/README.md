# Formal 0068: Runtime Charge Subject Model

Status: Checked with safe pass and expected unsafe counterexamples

Date: 2026-07-01

## Purpose

This model checks the next scheduler authority refinement after N-135:

```text
NoUnspecifiedRuntimeCharge
```

Every runtime accounting surface that might inform CapSched budget semantics
must have an explicit charge target:

```text
current/executor
donor/scheduling context
cgroup donor accounting
class-local runtime
monitor root budget
typed proxy/server ticket
observation-only freshness
```

The model rejects designs that let class runtime, `task_sched_runtime()`, or a
current-only proxy path become authority.

## Source Facts

Current upstream source:

```text
upstream/master=665159e246749578d4e4bfe106ee3b74edcdab18
```

Key source facts:

```text
sched_tick():
  uses rq->donor->sched_class->task_tick()

hrtick():
  uses rq->donor->sched_class->task_tick()

sched_tick_remote():
  asserts rq->curr == rq->donor before remote full-dynticks task_tick()

update_curr_common():
  delegates to update_se(rq, &rq->donor->se)

CFS update_se():
  adds sum_exec_runtime and group/mm accounting to rq->curr
  adds cgroup CPU time to donor

RT/DL/SCX update_curr:
  call update_curr_common() and then class-specific runtime/slice/server logic

task_sched_runtime():
  refreshes accounting only if the queried task is task_current_donor()
```

## Claim Boundary

Allowed after TLC:

```text
Runtime charge subject selection is now a separately modeled blocker. A future
budget hook must define charge targets per runtime surface and proxy state.
```

Forbidden:

```text
Linux accounting is production root budget.
task_sched_runtime() is an enforcement boundary.
class runtime is CapSched authority.
remote tick is a proxy-safe root budget path.
current-only accounting is valid under proxy execution.
```
