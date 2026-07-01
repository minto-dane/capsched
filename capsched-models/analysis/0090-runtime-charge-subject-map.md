# Analysis 0090: Runtime Charge Subject Map

Status: Draft model gate with TLC-backed design filter; no implementation
approved

Date: 2026-07-01

## Purpose

This note refines the scheduler budget model after N-135.

The rule is:

```text
NoUnspecifiedRuntimeCharge:
  every runtime delta that may influence CapSched budget semantics must name
  the charge subject and evidence class.
```

The charge subject is not automatically `current`, not automatically `donor`,
and never simply "whatever Linux class runtime updated".

## Source Basis

Current Linux source:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
work commit: 7cf0b1e415bcead8a2079c8be94a9d41aad7d462
upstream ref: 665159e246749578d4e4bfe106ee3b74edcdab18
```

Key source anchors:

| Surface | Current upstream anchor | Charge-subject meaning |
| --- | --- | --- |
| Hrtick | `kernel/sched/core.c:907 hrtick()` | calls `rq->donor->sched_class->task_tick()` |
| Runtime read | `kernel/sched/core.c:5674 task_sched_runtime()` | observation/freshness path; updates only when task is current donor |
| Scheduler tick | `kernel/sched/core.c:5762 sched_tick()` | calls `donor->sched_class->task_tick()` |
| Remote tick | `kernel/sched/core.c:5849 sched_tick_remote()` | source asserts `rq->curr == rq->donor` before task tick |
| Common update | `kernel/sched/fair.c:1977 update_curr_common()` | delegates to `update_se(rq, &rq->donor->se)` |
| CFS runtime split | `kernel/sched/fair.c:1355 update_se()` | `rq->curr` gets exec runtime/group/mm accounting; donor gets cgroup CPU time |
| CFS update | `kernel/sched/fair.c:1985 update_curr()` | warns that `cfs_rq->curr` may be donor, not actual running task |
| CFS tick | `kernel/sched/fair.c:14851 task_tick_fair()` | can be called by local or remote tick |
| RT update | `kernel/sched/rt.c:974 update_curr_rt()` | donor class check then `update_curr_common()` and RT runtime |
| RT tick | `kernel/sched/rt.c:2540 task_tick_rt()` | update_curr_rt plus RR slice policy |
| Deadline update | `kernel/sched/deadline.c:2128 update_curr_dl()` | donor deadline entity, `update_curr_common()`, deadline runtime |
| Deadline tick | `kernel/sched/deadline.c:2876 task_tick_dl()` | update_curr_dl plus hrtick deadline behavior |
| sched_ext update | `kernel/sched/ext/ext.c:1321 update_curr_scx()` | `update_curr_common()`, then `rq->curr` slice and ext server updates |
| Idle service | `kernel/sched/idle.c:551 update_curr_idle()` | idle/server accounting, not Domain execution authority |
| Stop service | `kernel/sched/stop_task.c:61 put_prev_task_stop()` | stop class uses common accounting but is not ordinary Domain execution |

## Runtime Subject Classes

Use these subject classes:

```text
ExecutorCurrent:
  actual execution context, usually rq->curr

SchedulingDonor:
  scheduling/accounting donor, rq->donor

CgroupDonor:
  cgroup CPU accounting subject in CFS update_se()

ClassRuntime:
  CFS/RT/DL/SCX local policy runtime or slice/server state

MonitorRootBudget:
  non-forgeable production root budget

ProxyTicket:
  typed relation allowing donor budget and executor authority to compose

ObservationOnly:
  runtime read or service/non-Domain accounting that cannot enforce authority
```

## Gate Rule

A future budget hook or runtime model is blocked unless it states:

```text
which subject is charged
which Linux accounting surface is only observation
which class runtime may narrow policy but not mint authority
which monitor event provides production root budget
which proxy/server ticket binds donor and executor when they differ
```

## Model

New model:

```text
formal/0068-runtime-charge-subject-model/
```

The model checks:

```text
NoUnspecifiedRuntimeCharge
NoClassRuntimeAsRootAuthority
NoProxyRuntimeWithoutTicket
NoRemoteTickProxyAuthority
NoObservationOnlyAsAuthority
NoCfsProxyWithoutDonorCgroup
```

## Hard Rejections

Reject:

```text
current-only budget under proxy execution
donor-only model that ignores CFS current runtime accounting
class runtime treated as root budget
task_sched_runtime() treated as an enforcement boundary
remote tick treated as proxy-safe root enforcement
CFS proxy update without donor/cgroup charge accounting
idle/stop/service time treated as ordinary Domain budget evidence
```

## Non-Claims

This note does not approve Linux budget hooks, task fields, tracepoint ABI,
monitor implementation, runtime coverage, behavior change, or production
protection.

