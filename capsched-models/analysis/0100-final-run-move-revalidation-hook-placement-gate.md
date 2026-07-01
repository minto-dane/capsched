# Analysis 0100: Final Run/Move Revalidation Hook Placement Gate

Status: Draft hook-placement model gate with TLC-backed design filter; no
implementation approved

Date: 2026-07-01

## Purpose

N-145 established that ordinary Domain execution must use the intersection of
capability CPU envelope, Linux effective mask, active CPU mask, monitor CPU
binding, and MemoryView CPU binding.

N-146 tightens the next question:

```text
It is not enough to validate placement somewhere earlier.
The final run or queued-task move must consume a fresh validation tuple.
```

The tuple is a frozen authority use for one edge. It is not a reusable boolean
and it is not a Linux scheduler hint. A tuple validated for a move cannot later
authorize a run, and a tuple validated before a core-scheduling or sched_ext
custody change cannot be consumed after that change.

## Source Basis

Current Linux source:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
work commit: 7cf0b1e415bcead8a2079c8be94a9d41aad7d462
upstream ref: 665159e246749578d4e4bfe106ee3b74edcdab18
upstream freshness: `git fetch upstream master` on 2026-07-01 observed 0 commits after this ref
```

The current CapSched Linux integration remains inert:

```text
linux/kernel/sched/capsched.c
  no scheduler hook
  no endpoint hook
  no monitor activation
  no task layout change
  no ABI
```

## Linux Run and Move Surfaces

| Surface | Current upstream anchor | CapSched meaning |
| --- | --- | --- |
| common queued move | `kernel/sched/core.c:2546 move_queued_task()` | deactivates, rewrites CPU, reactivates; needs move tuple consumption |
| locked queued move wrapper | `kernel/sched/sched.h:4120 move_queued_task_locked()` | shared helper for late task migration |
| task CPU mutation | `kernel/sched/core.c:3341 set_task_cpu()` | CPU identity mutation is not authority |
| migration stop | `kernel/sched/core.c:2611 migration_cpu_stop()` | can repair affinity and flush wakeups; invalidates stale tuples |
| final schedule loop | `kernel/sched/core.c:7061 __schedule()` | final run boundary after class/core/proxy selection |
| next-task pick | `kernel/sched/core.c:7149 pick_next_task()` | selected state is only candidate custody |
| rq current commit | `kernel/sched/core.c:7201 RCU_INIT_POINTER(rq->curr, next)` | hook after this point is too late for fail-closed run denial |
| context switch | `kernel/sched/core.c:7234 context_switch()` | monitor activation must match tuple-owned Domain/MemoryView |
| context switch body | `kernel/sched/core.c:5451 context_switch()` | address-space and low-level switch boundary |
| fair detach | `kernel/sched/fair.c:10839 detach_task()` | load balancing can move runnable tasks outside wake path |
| fair attach | `kernel/sched/fair.c:11036 attach_tasks()` | destination enqueue after balancing must consume move tuple |
| active balance | `kernel/sched/fair.c:13606 active_load_balance_cpu_stop()` | stopper thread migration path |
| RT push | `kernel/sched/rt.c:1959 push_rt_task()` | RT priority pressure is placement, not authority |
| RT move | `kernel/sched/rt.c:2066` | queued RT move surface |
| RT pull | `kernel/sched/rt.c:2260 pull_rt_task()` | remote pull surface |
| RT pull move | `kernel/sched/rt.c:2342` | queued RT pull move surface |
| DL server pick | `kernel/sched/deadline.c:2827` | server lending can select execution, not mint authority |
| DL push | `kernel/sched/deadline.c:3135 push_dl_task()` | deadline push surface |
| DL push move | `kernel/sched/deadline.c:3195` | queued DL move surface |
| DL pull | `kernel/sched/deadline.c:3215 pull_dl_task()` | deadline pull surface |
| DL pull move | `kernel/sched/deadline.c:3281` | queued DL move surface |
| sched_ext remote local move | `kernel/sched/ext/ext.c:2264 move_remote_task_to_local_dsq()` | BPF DSQ custody is not authority |
| sched_ext remote eligibility | `kernel/sched/ext/ext.c:2311 task_can_run_on_remote_rq()` | Linux eligibility is compatibility input |
| sched_ext DSQ consume | `kernel/sched/ext/ext.c:2495 consume_dispatch_q()` | consume-time revalidation is required |
| sched_ext dispatch loop | `kernel/sched/ext/ext.c:2766 scx_dispatch_sched()` | dispatch is selected/custody state |
| sched_ext pick | `kernel/sched/ext/ext.c:3147 pick_task_scx()` | BPF scheduling result is not RunCap |
| core scheduling cached pick | `kernel/sched/core.c:6254` | cached sibling pick must be fresh at consumption |
| core scheduling consume | `kernel/sched/core.c:6447` | cached pick consumption edge |
| core cookie steal | `kernel/sched/core.c:6455 try_steal_cookie()` | late queued move must consume move tuple |
| hotplug balance stop | `kernel/sched/core.c:8403 __balance_push_cpu_stop()` | outgoing CPU evacuation invalidates tuples |
| hotplug balance push | `kernel/sched/core.c:8439 balance_push()` | Linux exception, not ordinary Domain authority |
| affinity update | `kernel/sched/core.c:3112 __set_cpus_allowed_ptr_locked()` | changes Linux mask and may force migration |
| cpuset task update | `kernel/cgroup/cpuset.c:1060 cpuset_update_tasks_cpumask()` | changes effective mask and invalidates tuples |

## Validation Tuple

The model treats final validation as a tuple with at least:

```text
task kind
Domain grant
SchedContext grant
RunCap grant
task generation
Domain epoch
SchedContext epoch
RunCap epoch
move sequence
core scheduling sequence
sched_ext DSQ/custody sequence
edge kind
destination/run CPU
derived fresh allowed CPU set
pending migration state
```

This is intentionally stricter than a boolean `fresh` bit. The tuple must match
the current task and scheduler state at commit time.

## Required Semantics

For ordinary Domain run commitment:

```text
ValidateRunEdge
  -> possible invalidation/race
  -> CommitRun
```

`CommitRun` must consume exactly one unconsumed run tuple whose edge, CPU,
generation, Domain epoch, SchedContext epoch, RunCap epoch, move sequence, core
sequence, sched_ext sequence, migration state, and fresh CPU set still match.
The hook must conceptually be before the runqueue `curr` commitment and before
`context_switch()`.

For ordinary Domain queued-task move:

```text
ValidateMoveEdge
  -> possible invalidation/race
  -> CommitMove
```

`CommitMove` must consume exactly one unconsumed move tuple for the target move
edge and destination CPU. A move tuple is not a run tuple.

## Invalidation Sources

The following must break old tuples:

```text
task generation change
Domain epoch change
SchedContext epoch change
RunCap epoch change
affinity or cpuset mask change
CPU hotplug active/online change
monitor CPU binding change
MemoryView CPU binding change
migration pending or source/destination rq change
class mutation
core scheduling cached-pick sequence change
sched_ext DSQ/custody sequence change
```

## Rejected Authority Substitutes

The model rejects treating these as authority:

```text
pick_next_task result
set_task_cpu
move_queued_task
attach_task / detach_task
fair load balance
RT push/pull
DL push/pull/server selection
sched_ext DSQ dispatch or consume
core scheduling cached pick or cookie steal
proxy migration
hotplug push
migration stop
Linux exception task kind for ordinary Domain execution
hook placement after rq->curr commit
```

## Model

New model:

```text
formal/0078-final-run-move-revalidation-hook-placement-gate-model/
```

Checked invariants:

```text
NoRunWithoutFinalRevalidation
NoMoveWithoutRevalidation
NoRunMoveWithoutGrantAuthority
NoRunOutsideFreshSet
NoMoveOutsideFreshSet
NoRunOrMoveWithPendingMigration
NoNoIntersectionRunMove
NoMoveTupleRunsTask
NoRunTupleMovesTask
NoTupleEdgeMismatch
NoHookAfterRqCurrCommit
NoLinuxSelectedOrMoveAsAuthority
NoLinuxExceptionAsOrdinaryAuthority
NoNonClaimOverreach
```

## Non-Claims

This gate does not approve a Linux hook location, Linux task fields, scheduler
behavior change, budget hook, public ABI, monitor ABI, monitor implementation,
monitor verification, runtime coverage, or production protection.

It supports only this claim shape:

```text
Any future Linux patch must preserve a final run/move tuple-consumption
boundary. Existing Linux selected-state and movement machinery cannot become
CapSched authority.
```
