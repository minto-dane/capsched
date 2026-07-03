# Analysis 0135: SchedExecLease P5A-R CFS Picker Eligibility Source Map

Date: 2026-07-03

Status: source map and design blocker record only. No Linux behavior change is
approved.

## Purpose

P5A-R means:

```text
deny one CFS task and pick the next CFS task
```

This analysis records why the current P4 final-run allow-only hook is not a
sufficient shape for denial, and which current Linux picker surfaces must be
modeled before any behavior patch.

The accepted next step is still design/model work, not code.

## Current Source Basis

Linux work tree:

```text
branch=capsched-linux-l0
commit=d812f83c033a9f9b3d533e667e7106a5734eb30b
subject=sched/exec_lease: Document P5A0.P1 no-behavior boundary
upstream_ref=upstream/master
upstream_commit=87320be9f0d24fce67631b7eef919f0b79c3e45c
```

## Key Source Anchors

CFS EEVDF eligibility:

```text
linux/kernel/sched/fair.c:894
  vruntime_eligible()

linux/kernel/sched/fair.c:939
  entity_eligible()

linux/kernel/sched/fair.c:1136
  pick_eevdf()
```

`pick_eevdf()` chooses an eligible sched entity using the augmented RB-tree,
with special cases for the only queued entity, `cfs_rq->next`, current entity
protection, leftmost eligible entity, and heap search over `min_vruntime`.

CFS picker wrapper:

```text
linux/kernel/sched/fair.c:6376
  pick_next_entity()

linux/kernel/sched/fair.c:9912
  pick_task_fair()

linux/kernel/sched/fair.c:15363
  fair_sched_class.pick_task = pick_task_fair
```

`pick_next_entity()` wraps `pick_eevdf()` and may consume
`se->sched_delayed` by calling `dequeue_entities(..., DEQUEUE_DELAYED)` and
returning `NULL`. `pick_task_fair()` then restarts if a delayed entity was
dequeued.

Hierarchy walk:

```text
linux/kernel/sched/fair.c:9928
  pick_task_fair() walks cfs_rq hierarchy until group_cfs_rq(se) is NULL

linux/kernel/sched/sched.h:1708
  task_of()

linux/kernel/sched/sched.h:1726
  group_cfs_rq()
```

With group scheduling, a top-level entity can represent a task group, not a
task. A denial of the leaf task after descending the hierarchy can invalidate
the parent choice. Therefore P5A-R cannot be modeled as a leaf-only post-pick
check unless it proves rollback or retry over every ancestor `cfs_rq`.

Core/class picker:

```text
linux/kernel/sched/core.c:6128
  __pick_next_task()

linux/kernel/sched/core.c:6200
  pick_task()

linux/kernel/sched/core.c:6220
  pick_next_task() with CONFIG_SCHED_CORE

linux/kernel/sched/core.c:7152
  __schedule() pick_again loop
```

`__pick_next_task()` may directly call `pick_task_fair()` in the all-fair fast
path, or iterate active classes. Both paths install class state with
`put_prev_set_next_task()` before returning to `__schedule()`.

Current SchedExecLease P4 final-run hook:

```text
linux/kernel/sched/core.c:7199
  sched_exec_lease_validate_run_edge(prev, next)
```

This hook runs after `pick_next_task()` returns, after class state settlement,
and after proxy-exec donor selection. It is useful as an allow-only source
contract edge, but it is not enough for P5A-R denial because it does not make
the denied CFS candidate invisible to the fair picker and does not by itself
roll back `set_next_task_fair()` / `set_next_entity()` state.

## Existing Linux Mechanisms That Look Tempting

`sched_delayed` is not a ready-made lease denial bit.

```text
linux/include/linux/sched.h:586
linux/include/linux/sched.h:587
  sched_entity::on_rq and sched_entity::sched_delayed

linux/kernel/sched/fair.c:6194
  set_delayed()

linux/kernel/sched/fair.c:6213
  clear_delayed()

linux/kernel/sched/fair.c:6233
  dequeue_entity()

linux/kernel/sched/fair.c:7769
  requeue_delayed_entity()
```

Delayed dequeue is a fairness/sleep optimization. It adjusts hierarchical
`h_nr_runnable`, preserves entities until eligibility, and has lifetime rules
around `__block_task()`. P5A-R may study this shape, but must not collapse
`DeniedRunUse` into `sched_delayed` without proving separate capability
semantics, revocation semantics, and accounting effects.

`RETRY_TASK` is not enough by itself.

```text
linux/kernel/sched/sched.h:2575
linux/kernel/sched/core.c:6150
linux/kernel/sched/core.c:6166
linux/kernel/sched/core.c:6311
linux/kernel/sched/core.c:6346
```

Linux already uses `RETRY_TASK` to restart picker loops, but P5A-R also needs a
bounded denied-candidate carrier. Returning `RETRY_TASK` after a denial without
making the denied candidate unpickable can spin on the same entity.

## Cross-Path Blockers

Core scheduling caches picks:

```text
linux/kernel/sched/core.c:6259
  core_pick_seq/core_sched_seq cached-pick fast path

linux/kernel/sched/core.c:6345
  sibling rq pick_task()

linux/kernel/sched/core.c:6371
  idle fallback during cookie matching

linux/kernel/sched/core.c:6453
  out_set_next settlement
```

A CFS denial must either participate in the original core-wide pick before
`rq_i->core_pick` is stored, or invalidate cached picks and restart. A local
`pick_task_fair()` skip set alone is not enough for core-cookie search and
forced-idle replacement paths.

Sched class order and SCX:

```text
linux/kernel/sched/core.c:8928
  stop > dl > rt > fair > idle ordering check

linux/kernel/sched/core.c:8933
  fair > ext > idle when CONFIG_SCHED_CLASS_EXT

linux/kernel/sched/sched.h:2799
  next_active_class() skips fair when scx_switched_all()

linux/kernel/sched/ext/ext.c:4567
  ext_sched_class
```

A CFS-only P5A-R claim cannot be a global execution-denial claim while stop,
DL, RT, or SCX switched-all tasks can run outside CFS.

DL servers can nest fair picks:

```text
linux/kernel/sched/deadline.c:2827
  pick_task_dl() server path

linux/kernel/sched/fair.c:9957
  fair_server_pick_task()

linux/kernel/sched/ext/ext.c:3235
  ext server pick path
```

If lease denial returns `NULL` incorrectly from the fair server, DL may stop or
fall through instead of "pick next allowed CFS task". Server-borrow semantics
must remain separate from root authority.

Proxy execution splits donor and executor:

```text
linux/kernel/sched/core.c:7154
  pick_next_task()

linux/kernel/sched/core.c:7159
  rq_set_donor(rq, next)

linux/kernel/sched/core.c:7161
  find_proxy_task() entry condition

linux/kernel/sched/core.c:6876
  find_proxy_task()
```

The current post-proxy `validate_run_edge(prev, next)` sees the executor after
proxy resolution. P5A-R must define whether lease authority is checked on the
donor, executor, or both, and where retry state belongs if proxy resolution
changes `next`.

## Required P5A-R Design Shape

P5A-R must be picker-visible:

```text
candidate task selected by CFS
  -> validate SchedExecLease run authority before class state settlement
  -> if ALLOW: commit normal pick
  -> if DENY: record a bounded denied-candidate receipt
             make that candidate ineligible for this pick attempt
             retry CFS selection
```

The denied-candidate state must be:

```text
rq-lock protected
bounded by one scheduling attempt or explicit epoch
cleared on successful selection, enqueue/dequeue mutation, migration, and abort
visible to CFS entity selection before task_of(se) is committed
not counted as sleep, not counted as CFS bandwidth throttle, and not treated as
  ordinary EEVDF negative lag
```

The design must decide whether the ineligibility predicate is attached to:

```text
leaf task only:
  simplest authority check, but needs hierarchy rollback/proof

sched_entity path:
  can prune group paths but needs group-level aggregate denial semantics

cfs_rq attempt-local skip set:
  local to picker attempt, but must be bounded and cheap
```

## Source-Proven Blockers

P5A-R remains blocked until all of the following are modeled and validated:

```text
fair-picker-visible ineligibility:
  CFS must not repeatedly pick the same denied task in the same attempt.

hierarchical retry:
  group entities chosen before the denied leaf task must be safely retried or
  rolled back.

current/protect/buddy interaction:
  denial must not be bypassed through current protection, next buddy, or
  leftmost eligible shortcuts in pick_eevdf().

core-scheduling settlement:
  core_pick reuse, cookie search, sibling picks, and forced idle must not
  schedule a denied task after an enqueue/dequeue-stable cached pick.

DL-server nesting:
  fair-server picks must not convert lease denial into wrong DL server stop,
  fall-through, or borrowed-budget authority.

proxy donor/executor:
  lease authority subject must be defined for donor, executor, or both.

sched_ext boundary:
  SCX-enabled paths are outside P5A-R CFS-only claims unless a separate gate
  handles ext dispatch queues and BPF scheduler fallback.

bounded retry:
  every denied attempt needs a finite bound, a fallback, or explicit quarantine
  semantics. Silent spinning is forbidden.

accounting separation:
  denial is not sleep, throttle, delayed dequeue, yield, or fairness lag.
```

## Non-Claims

This analysis does not approve:

```text
Linux code changes
runtime denial
CFS deny-and-repick implementation
broad move denial
runtime coverage
budget enforcement
public ABI or trace ABI
monitor calls or monitor verification
production protection
hypervisor-grade isolation
cost-efficiency
deployment readiness
datacenter readiness
```

## Next Artifact

The next P5A-R artifact should be a small formal/source gate:

```text
P5A-R Picker Ineligibility Gate

Inputs:
  current source anchors from this analysis
  candidate denied-state placement choice
  bounded retry rule
  group hierarchy settlement rule
  core-scheduling exclusion or settlement rule
  DL-server exclusion or settlement rule
  proxy donor/executor authority rule
  sched_ext exclusion or settlement rule

Output:
  p5a_r_linux_behavior_patch_approved=false
  deny_one_cfs_pick_next_approved=false until the gate passes
```
