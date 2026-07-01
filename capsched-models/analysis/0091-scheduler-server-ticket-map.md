# Analysis 0091: Scheduler Server Ticket Map

Status: Draft model gate with TLC-backed design filter; no implementation
approved

Date: 2026-07-01

## Purpose

This note refines the scheduler runtime/budget model around Linux class
servers and class-local bandwidth.

The core rule is:

```text
Server runtime is not authority.
```

Linux deadline servers can schedule fair or sched_ext work, and class-local RT
bandwidth / sched_ext slice state can narrow execution. CapSched must not let
those mechanisms mint runnable authority or root budget.

## Source Basis

Current Linux source:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
work commit: 7cf0b1e415bcead8a2079c8be94a9d41aad7d462
upstream ref: 665159e246749578d4e4bfe106ee3b74edcdab18
```

Key source anchors:

| Surface | Current upstream anchor | CapSched meaning |
| --- | --- | --- |
| DL server API | `kernel/sched/sched.h:366` | server pick/update/start/stop/init are nested scheduling machinery |
| Server pick field | `include/linux/sched.h:739` | `server_pick_task` selects lower-class work |
| DL server update | `kernel/sched/deadline.c:1584 dl_server_update()` | server runtime accounting, not authority mint |
| DL server idle update | `kernel/sched/deadline.c:1578 dl_server_update_idle()` | idle/server accounting, not Domain authority |
| DL server pick use | `kernel/sched/deadline.c:2814 __pick_task_dl()` | server entity can call `server_pick_task()` |
| Fair server start | `kernel/sched/fair.c:7891 dl_server_start(&rq->fair_server)` | fair work starts server machinery |
| Fair server update | `kernel/sched/fair.c:2019 dl_server_update(&rq->fair_server)` | fair runtime accounted against server |
| Fair server pick | `kernel/sched/fair.c:9957 fair_server_pick_task()` | nested pick calls `pick_task_fair()` |
| Ext server start | `kernel/sched/ext/ext.c:2042 dl_server_start(&rq->ext_server)` | sched_ext work starts server machinery |
| Ext server update | `kernel/sched/ext/ext.c:1336 dl_server_update(&rq->ext_server)` | sched_ext runtime accounted against ext server |
| Ext server pick | `kernel/sched/ext/ext.c:3235 ext_server_pick_task()` | nested pick calls `do_pick_task_scx(force_scx=true)` |
| sched_ext slice refill | `kernel/sched/ext/ext.c:3198` and `kernel/sched/ext/ext.c:3207` | slice refill is not authority |
| Ext/fair bandwidth swap | `kernel/sched/ext/ext.c:6099 dl_server_swap_bw()` | bandwidth ownership changes need epoch/freshness treatment |
| RT bandwidth | `kernel/sched/rt.c:974 update_curr_rt()` | RT runtime can throttle policy but is not root budget |
| CPU teardown stop | `kernel/sched/core.c:8846 dl_server_stop(&rq->fair_server)` and `kernel/sched/core.c:8848 dl_server_stop(&rq->ext_server)` | server stop invalidates live server-borrow use |

## Subject Classes

Use these subject classes:

```text
LowerTaskAuthority:
  the selected lower-class task's own FrozenRunUse/SchedContext/Domain epoch

ServerBorrowTicket:
  typed right to use server runtime to run lower-class work

ServerEpoch:
  freshness generation for server start/stop/replenish/swap

ServerRuntime:
  Linux DL server runtime state

ClassRuntime:
  CFS/RT/DL/SCX local runtime, slice, or bandwidth state

MonitorRootBudget:
  production budget root below Linux
```

## Gate Rule

A future scheduler authority implementation is blocked unless server-picked
execution satisfies:

```text
LowerTaskAuthority
ServerBorrowTicket
fresh ServerEpoch
MonitorRootBudget
live server state
```

Class runtime may narrow scheduling decisions. It may not create authority,
refresh stale authority, or replace monitor root budget.

## Model

New model:

```text
formal/0069-scheduler-server-ticket-model/
```

Checked invariants:

```text
NoRunWithoutTaskAuthority
NoServerBorrowWithoutTicket
NoServerRuntimeAsRootAuthority
NoRtBandwidthAsRootAuthority
NoScxSliceAsRootAuthority
NoRunWithStaleServerEpoch
NoStoppedServerWithLiveRun
NoFailClosedRunning
```

## Hard Rejections

Reject:

```text
server_pick_task() result treated as RunCap
DL server runtime treated as monitor root budget
RT bandwidth treated as root budget
sched_ext slice refill treated as authority
server replenish/swap without epoch refresh
server stop with live server-borrow ticket
lower-class task run without its own authority
```

## Non-Claims

This note does not approve scheduler hooks, budget hooks, task fields,
tracepoints, public ABI, monitor implementation, runtime coverage, behavior
change, or production protection.

