# Analysis 0094: Server Epoch Relation

Status: Draft model gate with TLC-backed design filter; no implementation
approved

Date: 2026-07-01

## Purpose

This note refines N-137. The earlier server-ticket model established:

```text
Server runtime is not authority.
```

This note adds the lifecycle rule needed before a future scheduler hook can use
server-borrow tickets safely:

```text
Server lifecycle changes invalidate server-borrow tickets.
```

Linux deadline servers are valid scheduler machinery. They may start, stop,
replenish, detach, attach, swap fair/ext reservations, update parameters, and
run a nested lower-class pick. CapSched must not turn those mutable Linux
states into durable authority. A `ServerBorrowTicket` is live only for the
server kind, server epoch, lower-task authority, and monitor-root budget that
were frozen at issue time.

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
| DL server interface | `kernel/sched/sched.h:366` | nested scheduling API is existing Linux machinery |
| Server pick field | `include/linux/sched.h:739` | lower-class pick callback is mutable Linux selection, not authority |
| DL trace declarations | `include/trace/events/sched.h:908`, `:917`, `:921` | replenish/start/stop are observable but not authority roots |
| New period replenish | `kernel/sched/deadline.c:724 replenish_dl_new_period()` | runtime/deadline refresh must refresh or invalidate ticket epoch |
| CBS replenish | `kernel/sched/deadline.c:799 replenish_dl_entity()` | replenishment is a lifecycle boundary, not ticket extension |
| Server timer | `kernel/sched/deadline.c:1140 dl_server_timer()` | timer can stop idle server or enqueue replenish |
| Server timer current update | `kernel/sched/deadline.c:1159` | donor update before timer decision is accounting, not authority |
| Idle server stop from timer | `kernel/sched/deadline.c:1162` | timer can force stop and invalidate tickets |
| Timer replenish enqueue | `kernel/sched/deadline.c:1186` | timer can requeue server after replenish boundary |
| Runtime exceeded path | `kernel/sched/deadline.c:1501` | runtime exhaustion throttles server/task |
| Server immediate replenish path | `kernel/sched/deadline.c:1519` | fallback replenish remains an epoch boundary |
| Server update | `kernel/sched/deadline.c:1584 dl_server_update()` | background runtime depletion is not ticket authority |
| Server state-machine comment | `kernel/sched/deadline.c:1654` through `:1779` | start/update/timer/pick/stop/replenish lifecycle is explicit |
| Server start | `kernel/sched/deadline.c:1795 dl_server_start()` | start creates a server-active interval |
| Server active set | `kernel/sched/deadline.c:1813` | active bit is Linux mutable state, not non-forgeable authority |
| Server stop | `kernel/sched/deadline.c:1819 dl_server_stop()` | stop must invalidate ticket and picked lower task |
| Server active clear | `kernel/sched/deadline.c:1831` | inactive server cannot carry live ticket |
| Initial fair/ext server params | `kernel/sched/deadline.c:1860`, `:1871` | boot-time runtime setup is not authority |
| Initial ext detach | `kernel/sched/deadline.c:1882` | detached server has no executable ticket |
| Server params | `kernel/sched/deadline.c:1905 dl_server_apply_params()` | debug/parameter update is an epoch boundary |
| Runtime/deadline reset | `kernel/sched/deadline.c:1936` through `:1941` | parameter update resets runtime/deadline state |
| Detach stops active server | `kernel/sched/deadline.c:1993` | detach must invalidate tickets before bandwidth removal |
| Attach kick-start | `kernel/sched/deadline.c:2056` | attach may start server after missed 0->running transition |
| Server swap | `kernel/sched/deadline.c:2093 dl_server_swap_bw()` | fair/ext bandwidth movement is a server-kind/epoch boundary |
| Swap detach/attach | `kernel/sched/deadline.c:2107` and `:2113` | old server authority cannot be reinterpreted as new server authority |
| Swap start | `kernel/sched/deadline.c:2119` | attach side may start a new active interval |
| Enqueue replenish | `kernel/sched/deadline.c:2431` | ENQUEUE_REPLENISH calls `replenish_dl_entity()` |
| Server pick | `kernel/sched/deadline.c:2827` | nested server pick selects lower-class task |
| Pick-empty stop | `kernel/sched/deadline.c:2830` | empty nested pick stops server and invalidates ticket |
| Fair server update/start/pick | `kernel/sched/fair.c:2019`, `:7891`, `:9957` | fair server runtime and pick are server-borrow contexts |
| Ext server update/start/pick | `kernel/sched/ext/ext.c:1336`, `:2042`, `:3235` | sched_ext server runtime and pick are server-borrow contexts |
| Ext/fair swap | `kernel/sched/ext/ext.c:6099` | switched-all disable swaps ext reservation back to fair |
| Ext attach | `kernel/sched/ext/ext.c:7169` | sched_ext enable attaches ext server before commit |
| Fair detach | `kernel/sched/ext/ext.c:7347` | switched-all enable detaches fair server |
| Debug param update | `kernel/sched/debug.c:423` through `:425` | stop/apply/start sequence is an epoch boundary |
| CPU teardown stop | `kernel/sched/core.c:8846`, `:8848` | dying CPU stops fair/ext servers |
| Idle update | `kernel/sched/idle.c:563`, `:565` | idle accounting can move server lifecycle |

## Required Subject Split

Use these distinct subjects:

```text
ServerKind:
  fair server, ext server, or ordinary DL server context

ServerEpoch:
  freshness generation for server active interval, replenish, stop, detach,
  attach, swap, parameter update, and CPU teardown

ServerBorrowTicket:
  frozen right to use a specific server kind at a specific epoch to run a
  lower-class task

LowerTaskAuthority:
  the selected task's own FrozenRunUse/SchedContext/Domain epoch/generation

MonitorRootBudget:
  production root budget below Linux

ServerRuntime:
  Linux DL server runtime/deadline/bandwidth state
```

## Gate Rule

A future scheduler authority implementation is blocked unless:

```text
ticket.server_kind == current_server_kind
ticket.server_epoch == current_server_epoch
server is active
lower task authority is live
monitor root budget is live
```

and unless all of the following invalidate or force revalidation of any live
server-borrow ticket:

```text
dl_server_start()
dl_server_stop()
dl_server_timer() replenish/idle-stop transitions
replenish_dl_new_period()
replenish_dl_entity()
dl_server_apply_params()
dl_server_attach_bw()
dl_server_detach_bw()
dl_server_swap_bw()
debugfs stop/apply/start parameter update
CPU teardown server stop
fair/ext server kind switch
```

The implementation strategy can later choose between eager invalidation and
fresh reissue. The semantic requirement is stricter than either mechanism:
stale server-kind or stale server-epoch tickets cannot pick or run.

## Model

New model:

```text
formal/0072-server-epoch-relation-model/
```

Checked invariants:

```text
NoRunWithoutLowerTaskAuthority
NoRunWithoutMonitorRootBudget
NoPickWithoutFreshTicket
NoRunWithStaleServerEpoch
NoLiveTicketAcrossEpochChange
NoTicketKindMismatch
NoStoppedServerWithLiveTicket
NoLinuxRuntimeAsAuthority
NoFailClosedRunning
NoProtectionClaim
```

## Hard Rejections

Reject:

```text
server ticket surviving replenish as executable authority
server ticket surviving fair/ext swap as executable authority
server ticket surviving stop/detach/CPU teardown
server ticket surviving debug parameter stop/apply/start
server kind mismatch between ticket and current server
server pick without fresh ticket
lower-class task run without its own authority
Linux server runtime treated as root budget or ticket refresh authority
tracepoint observation treated as protection evidence
```

## Compatibility Note

This does not require changing Linux's server accounting model. It requires
CapSched metadata to track a stricter authority epoch around the existing
server lifecycle. Linux may continue to use CBS/GRUB, fair/ext servers,
sched_ext attach/detach, and debug parameter updates as compatibility policy.
CapSched rejects only stale authority interpretation.

## Non-Claims

This note does not approve scheduler hooks, budget hooks, task fields,
tracepoints, public ABI, monitor implementation, runtime coverage, behavior
change, or production protection.
