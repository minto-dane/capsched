# Formal 0069: Scheduler Server Ticket Model

Status: Checked with safe pass and expected unsafe counterexamples

Date: 2026-07-01

## Purpose

This model refines the scheduler class/server boundary after N-136.

Linux deadline servers can borrow runtime for fair and sched_ext work, and RT
bandwidth / sched_ext slices can narrow class policy. CapSched must not let any
of these class mechanisms mint execution authority.

The model requires:

```text
lower task authority
server-borrow ticket
fresh server epoch
monitor root budget
live server state
```

before a server-picked lower-class task can run.

## Source Facts

Current upstream source:

```text
upstream/master=665159e246749578d4e4bfe106ee3b74edcdab18
```

Key facts:

```text
sched.h documents DL server pick/update/start/stop/init.
fair enqueue starts rq->fair_server.
fair_server_pick_task() calls pick_task_fair().
sched_ext enqueue starts rq->ext_server.
ext_server_pick_task() calls do_pick_task_scx(force_scx=true).
deadline pick calls dl_se->server_pick_task() for server entities.
dl_server_update() and dl_server_update_idle() charge server runtime.
RT bandwidth updates rt_rq->rt_time but is not CapSched root authority.
sched_ext slice refill and ext_server runtime are not CapSched authority.
CPU teardown stops fair/ext servers.
```

## Claim Boundary

Allowed after TLC:

```text
Server runtime and class bandwidth are now modeled as non-authority unless a
typed server ticket, task authority, and root budget are present.
```

Forbidden:

```text
fair/ext/DL server runtime as RunCap
RT bandwidth as root budget
sched_ext slice refill as authority
server stop with live execution authority
server replenish without epoch refresh
lower-class task execution without its own authority
```
