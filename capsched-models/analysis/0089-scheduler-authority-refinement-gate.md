# Analysis 0089: Scheduler Authority Refinement Gate

Status: Draft model gate with TLC-backed design filter; no implementation
approved

Date: 2026-07-01

## Purpose

This note turns the refreshed scheduler authority source map into a blocking
refinement gate before any behavior-changing scheduler authority patch.

It connects three facts that must not be analyzed in isolation:

```text
TASK_WAKING is a one-way Linux wakeup boundary unless rollback is proven.
sched_tick() and task_sched_runtime() account through rq->donor.
__pick_next_task() and __schedule() can retry, settle class state, and diverge
donor from the actual execution context through proxy execution.
```

The consequence is:

```text
No single "current task has a RunCap" check is a sufficient scheduler
capability model.
```

## Source Basis

Current Linux source:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
work commit: 7cf0b1e415bcead8a2079c8be94a9d41aad7d462
upstream ref: 665159e246749578d4e4bfe106ee3b74edcdab18
```

Key source anchors:

| Obligation | Current upstream anchor | Meaning |
| --- | --- | --- |
| Pre-WAKING failability | `kernel/sched/core.c:4295 ttwu_state_match()` to `kernel/sched/core.c:4357 WRITE_ONCE(p->__state, TASK_WAKING)` | fail-capable admission belongs before `TASK_WAKING` |
| Already-runnable wake | `kernel/sched/core.c:3865 ttwu_runnable()` | existing custody; not new RunCap mint |
| Enqueue assertion | `kernel/sched/core.c:2172 enqueue_task()` and `kernel/sched/core.c:2219 activate_task()` | nofail/assertion point unless class rollback is modeled |
| Donor tick accounting | `kernel/sched/core.c:5762 sched_tick()` | tick uses `rq->donor` |
| Donor hrtick accounting | `kernel/sched/core.c:907 hrtick()` | high-resolution tick calls `rq->donor->sched_class->task_tick()` |
| Runtime freshness | `kernel/sched/core.c:5674 task_sched_runtime()` | update path checks `task_current_donor()` |
| CFS runtime split | `kernel/sched/fair.c:1355 update_se()` | `sum_exec_runtime` is added to `rq->curr`, cgroup time to donor |
| Donor/current split | `kernel/sched/sched.h:2449 task_current()` and `kernel/sched/sched.h:2460 task_current_donor()` | execution context and scheduling context can differ |
| Proxy execution | `kernel/sched/core.c:6871 find_proxy_task()` and `kernel/sched/core.c:7151` | donor-selected task can lead to different executable owner |
| Pick retry and settlement | `kernel/sched/core.c:6124 __pick_next_task()` | fair fast path, class iteration, `RETRY_TASK`, `put_prev_set_next_task()` |
| Fair retry | `kernel/sched/fair.c:9912 pick_task_fair()` | newidle balance can return `RETRY_TASK` |
| sched_ext retry/slice | `kernel/sched/ext/ext.c:3148 do_pick_task_scx()` | lock drop, higher-class modification retry, keep-prev, and slice refill |
| Switch commit | `kernel/sched/core.c:7061 __schedule()` and `kernel/sched/core.c:7201 RCU_INIT_POINTER(rq->curr, next)` | final activation/commit region |
| sched_ext tick | `kernel/sched/ext/ext.c:3505 task_tick_scx()` | BPF/slice state cannot be authority |

## Gate Rule

A future scheduler authority implementation is blocked unless it preserves all
of the following:

```text
1. FrozenRunUse is created before TASK_WAKING for fail-capable normal wakes.
2. Post-TASK_WAKING checks are nofail assertions, fail-closed stops, or a
   separately proven rollback/quarantine protocol.
3. Already-runnable and delayed requeue paths cannot mint RunCap.
4. Budget charge subject is explicit: donor, current/executor, both, or a
   typed proxy relation.
5. Proxy execution requires a ProxyExecutionTicket or equivalent typed
   owner/donor budget rule.
6. selected state is not execution authority until class/core/proxy/sched_ext
   settlement is revalidated.
7. sched_ext slice refill, watchdog fallback, or BPF policy cannot be the root
   of production "No RunCap, no run".
8. `rq->curr` update and context switch are commit points, not places for
   ordinary fallible policy calls after the wrong Domain was activated.
```

## Refinement Model

New model:

```text
formal/0067-scheduler-authority-refinement-gate-model/
```

The model intentionally composes only the three currently highest-risk
integration obligations:

```text
TaskWakingFreeze:
  `taskWaking => frozen`

DonorProxyBudget:
  `running => donorBudgetFresh`
  `(running /\ donor != current) => proxyTicket`

SelectedSettlement:
  `running => selected /\ classSettled /\ ~retryPending`
```

It does not replace the earlier detailed models:

```text
formal/0013: TASK_WAKING failability boundary
formal/0022: root/SchedContext/class runtime split and NO_HZ overrun
formal/0023: class selected-state boundary
```

Instead, it acts as a return-to-core gate: those obligations must all hold at
the same execution boundary before patch movement.

It deliberately does not yet model the exact Linux runtime accounting
equations across CFS, RT, deadline, sched_ext, hrtick, `task_sched_runtime()`,
cgroup CPU time, remote tick, and proxy execution. That remains the next
budget-specific refinement obligation.

## Hard Rejections

Reject these designs:

```text
post-TASK_WAKING ordinary -EPERM path
enqueue_task() returns error without full class rollback
current-only budget charge under proxy execution
class runtime or sched_ext slice treated as CapSched root budget
class->pick_task() treated as final authority
RETRY_TASK or core cached pick consumed without freshness revalidation
same-task continuation treated as free from budget/revoke/timer checks
Linux-only fields treated as HyperTag Monitor authority
```

## New Blocking Gap After This Gate

This gate closes the immediate current-only collapse hazard but leaves a
stronger budget equation gap:

```text
NoUnspecifiedRuntimeCharge:
  every delta_exec-like runtime update must have an explicit charge target:
  current/executor, donor, both, or a typed proxy/server ticket.
```

Known current upstream sources already show multiple accounting surfaces:

```text
sched_tick():
  donor task_tick

hrtick():
  donor task_tick

task_sched_runtime():
  update_curr only when queried task is task_current_donor

CFS update_se():
  sum_exec_runtime/account_group_exec_runtime/account_mm_sched use rq->curr
  cgroup_account_cputime uses donor
```

Therefore the next model must not merely say "budget charges donor". It must
define which budget ledger each Linux accounting surface can inform, and which
monitor-owned root budget event remains authoritative under a hostile Linux
scheduler.

## Patch Consequence

This gate keeps patch movement blocked:

```text
no task_struct authority field use
no enqueue hook
no pick hook
no switch hook
no budget hook
no tracepoint ABI
no direct-call stub
no monitor call
no behavior change
```

Allowed next work:

```text
source-only refinement
bounded semantic model checks
trace-only runtime coverage plan/result
assurance-case bookkeeping
```

## Non-Claims

This note does not prove Linux runtime behavior and does not approve a concrete
hook location.

It does not provide:

```text
production protection
monitor verification
HyperTag MemoryView activation
root budget timer
endpoint enforcement
async provenance implementation
Linux ABI
behavior-changing scheduler patch
```
