# Analysis 0028: Tick and Runtime Budget Source Map

Status: Draft source map, no implementation approved

Date: 2026-06-27

Linux source:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
commit: 7cf0b1e415bcead8a2079c8be94a9d41aad7d462
```

## Purpose

This note maps Linux runtime accounting and timer-tick budget pressure into the
CapSched authority model.

It is a prerequisite for any future `budget_charge` hook because CapSched must
not accidentally claim that existing Linux accounting is a production security
root. Linux accounting is valuable L0 evidence. Monitor-backed CapSched-H still
requires a lower root budget source that compromised Linux cannot forge.

## Core Runtime Spine

The generic HZ tick enters:

```text
kernel/sched/core.c:5762 sched_tick()
kernel/sched/core.c:5777 rq_lock()
kernel/sched/core.c:5782 update_rq_clock()
kernel/sched/core.c:5789 donor->sched_class->task_tick(rq, donor, 0)
kernel/sched/core.c:5793 sched_core_tick(rq)
kernel/sched/core.c:5794 scx_tick(rq)
kernel/sched/core.c:5801 perf_event_task_tick()
kernel/sched/core.c:5803 wq_worker_tick(donor)
```

Important detail:

```text
accounting goes to rq->donor, not blindly to rq->curr
```

This matters for proxy execution and any future Domain accounting. A naive
`current task spent time` rule is wrong when donor/current can diverge.

`task_sched_runtime()` is the read-side runtime path:

```text
kernel/sched/core.c:5674 task_sched_runtime()
kernel/sched/core.c:5692 fast return if !p->on_cpu or !task_on_rq_queued(p)
kernel/sched/core.c:5696 task_rq_lock()
kernel/sched/core.c:5702 task_current_donor(rq, p) && task_on_rq_queued(p)
kernel/sched/core.c:5704 update_rq_clock(rq)
kernel/sched/core.c:5705 p->sched_class->update_curr(rq)
kernel/sched/core.c:5707 read p->se.sum_exec_runtime
```

This is not a budget-enforcement point by itself. It can force accounting
freshness for a queried task, but it is not a guaranteed execution boundary.

## Class Runtime Sources

### Fair

```text
kernel/sched/fair.c:1985 update_curr()
kernel/sched/fair.c:2001 delta_exec = update_se(rq, curr)
kernel/sched/fair.c:2005 curr->vruntime += calc_delta_fair(...)
kernel/sched/fair.c:6412 entity_tick()
kernel/sched/fair.c:6417 update_curr(cfs_rq)
kernel/sched/fair.c:14851 task_tick_fair()
kernel/sched/fair.c:14856 for_each_sched_entity()
kernel/sched/fair.c:14858 entity_tick()
```

CapSched implication:

```text
CFS tick accounting is class-local policy/accounting, not a hard security
budget. A CapSched SchedContext can use it for L0 measurement, but production
budget exhaustion must be enforced below or beside Linux scheduler policy.
```

### RT

```text
kernel/sched/rt.c:974 update_curr_rt()
kernel/sched/rt.c:982 delta_exec = update_curr_common(rq)
kernel/sched/rt.c:996 sched_rt_runtime(rt_rq) != RUNTIME_INF
kernel/sched/rt.c:998 rt_rq->rt_time += delta_exec
kernel/sched/rt.c:999 sched_rt_runtime_exceeded(rt_rq)
kernel/sched/rt.c:1001 resched_curr(rq)
kernel/sched/rt.c:1004 do_start_rt_bandwidth(...)
kernel/sched/rt.c:2540 task_tick_rt()
kernel/sched/rt.c:2544 update_curr_rt(rq)
kernel/sched/rt.c:2553-2560 SCHED_RR time-slice decrement/reset
```

CapSched implication:

```text
RT already has runtime throttling machinery, but it is policy state owned by
Linux. CapSched must treat it as a compatibility substrate and must not merge
RunCap/SchedContext authority with RT priority or RR slice state.
```

### Deadline

```text
kernel/sched/deadline.c:2128 update_curr_dl()
kernel/sched/deadline.c:2134 require dl_task() and on_dl_rq()
kernel/sched/deadline.c:2145 delta_exec = update_curr_common(rq)
kernel/sched/deadline.c:2146 update_curr_dl_se(rq, dl_se, delta_exec)
kernel/sched/deadline.c:2876 task_tick_dl()
kernel/sched/deadline.c:2878 update_curr_dl(rq)
kernel/sched/deadline.c:2886 start_hrtick_dl(...) if leftmost and runtime > 0
```

CapSched implication:

```text
Deadline runtime semantics are closest in shape to CPU budget, but the
SchedContext authority object must remain separate. Deadline admission,
CBS/runtime, and hrtick behavior need a class-specific refinement before any
CapSched budget hook touches deadline tasks.
```

### sched_ext

```text
kernel/sched/ext/ext.c:1321 update_curr_scx()
kernel/sched/ext/ext.c:1326 delta_exec = update_curr_common(rq)
kernel/sched/ext/ext.c:1330-1333 scx.slice decrement/touch
kernel/sched/ext/ext.c:3480 scx_tick()
kernel/sched/ext/ext.c:3497 scx_exit(... SCX_EXIT_ERROR_STALL ...)
kernel/sched/ext/ext.c:3505 task_tick_scx()
kernel/sched/ext/ext.c:3509 update_curr_scx(rq)
kernel/sched/ext/ext.c:3518 SCX_CALL_OP_TASK(sch, tick, rq, curr)
kernel/sched/ext/ext.c:4587 .task_tick = task_tick_scx
kernel/sched/ext/ext.c:4595 .update_curr = update_curr_scx
```

CapSched implication:

```text
sched_ext is useful for policy experimentation and measuring cluster/domain
placement cost, but its fallback/exit behavior means it cannot be the root of
the production "No budget, no execution" invariant.
```

### Stop and Idle

```text
kernel/sched/stop_task.c:74 task_tick_stop()
kernel/sched/stop_task.c:92 update_curr_stop()
kernel/sched/idle.c:532 task_tick_idle()
kernel/sched/idle.c:551 update_curr_idle()
kernel/sched/idle.c:563 dl_server_update_idle(&rq->fair_server, delta_exec)
```

CapSched implication:

```text
stop and idle tasks need explicit exception treatment. They are not normal
Domain workload execution. A future model must state whether they are root
management Domain execution, monitor-owned execution, or non-Domain CPU service
time.
```

## CapSched Budget Authority Map

### L0 Prototype Budget

L0 may use:

```text
rq clock and update_curr paths
class task_tick callbacks
hrtick or timer-driven preemption
trace counters and schedstat/perf observations
```

L0 must not claim:

```text
protection against compromised Linux scheduler code
hard root budget enforcement across malicious Domain kernel-context execution
non-forgeable budget depletion
```

### CapSched-H Production Budget

Production needs:

```text
monitor-owned root Domain budget
monitor-owned or sealed SchedContext epoch
bounded local overrun after Linux stops cooperating
preemption, trap, or CPU isolation on root-budget exhaustion
IOMMU/queue budget coupling for I/O leases
audit record that Linux cannot rewrite
```

Linux may still keep:

```text
fairness policy
latency policy
class-specific compatibility state
performance counters
best-effort early preemption
```

## Proof Obligations

Future `budget_charge` work must prove:

```text
1. No task reaches Running without a SchedContext and nonzero budget.
2. Budget depletion cannot be hidden by queued, selected, or running state.
3. Tickless and hrtick behavior has a bounded overrun rule.
4. Proxy execution charges donor/current authority intentionally.
5. RT and deadline throttling are not confused with CapSched authority.
6. sched_ext fallback cannot remove production budget enforcement.
7. stop/idle/kthread service time has an explicit Domain or monitor exception.
```

## Immediate Design Consequence

The likely semantic split is:

```text
Linux scheduler:
  class policy, latency, fairness, low-cost early charge, L0 measurements

CapSched SchedContext:
  typed authority and accounting object

HyperTag Monitor:
  hard root budget and fail-closed CPU stop/transition authority
```

This keeps Linux compatibility and performance while preserving the production
threat model.
