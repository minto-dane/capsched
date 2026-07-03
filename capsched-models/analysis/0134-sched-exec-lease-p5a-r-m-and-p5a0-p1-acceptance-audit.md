# Analysis 0134: SchedExecLease P5A-R/M and P5A0.P1 Acceptance Audit

Date: 2026-07-02

Status: subagent-assisted design audit; no Linux code change approved.

## Purpose

This records the post-`0008` audit before any behavior-changing SchedExecLease
patch.

The audit covers three independent questions:

```text
P5A-R:
  Can we deny one ordinary CFS task and pick the next CFS task now?

P5A-M:
  Can we deny broad common queued moves now?

P5A0.P1:
  What evidence is still required before calling the concrete 0008 patch fully
  accepted?
```

The answer is deliberately conservative:

```text
P5A-R:
  not ready

P5A-M:
  not ready

P5A0.P1:
  source/replay/formal accepted, but full build and generated-code acceptance
  still pending
```

## P5A-R Finding

The current P4 run hook is not a CFS deny-and-repick hook.

The current final run validation call is after `pick_next_task()`, and some
ordinary/core scheduling paths can already perform class settlement before the
current P4 hook:

```text
kernel/sched/core.c:
  sched_exec_lease_validate_run_edge(prev, next)

kernel/sched/core.c:
  put_prev_set_next_task()

kernel/sched/sched.h:
  put_prev_task()
  set_next_task()
```

Therefore:

```text
pre-rq->curr != pre-settlement
```

CFS candidate choice happens inside:

```text
kernel/sched/fair.c:
  pick_task_fair()
  pick_next_entity()
  pick_eevdf()
  entity_eligible()
```

The P5A-R blocker is not merely missing a branch. The blocker is missing a
picker-visible denied-candidate state.

## P5A-R Hazards

A behavior patch must not:

```text
- deny after CFS has installed cfs_rq->curr unless rollback is proved;
- repick the same denied task in the same retry epoch;
- treat idle or newidle balance as authority when eligible CFS tasks remain;
- turn pick_next_entity() returning NULL with nr_queued > 0 into an unbounded
  loop;
- bypass singleton, buddy, protected-slice, delayed-dequeue, or cgroup
  hierarchy cases;
- claim coverage over core, proxy, sched_ext, RT, deadline, fair-server, or
  direct load-balance paths.
```

## P5A-R Required Artifacts

Before any P5A-R code:

```text
1. CFS picker eligibility source map.
2. Ordinary-CFS pre-settlement map.
3. CFS denied-candidate retry model.
4. Negative denial validation plan update.
5. Source checker proving denied tasks do not reach rq->curr, sched_switch, or
   context_switch in the supported scope.
```

## P5A-M Finding

The current move hooks are locally before mutation, but the helper return
values are discarded and caller graphs assume success.

Current shape:

```text
move_queued_task():
  validate result is cast to void
  deactivate_task()
  set_task_cpu()
  activate_task()
  wakeup_preempt()

move_queued_task_locked():
  validate result is cast to void
  deactivate_task()
  set_task_cpu()
  activate_task()
  wakeup_preempt()
```

This is sufficient for an allow-only anchor. It is not sufficient for denial.

## P5A-M Settlement Gaps

Broad move denial remains blocked for at least:

```text
migration:
  __migrate_task() returns only rq *.
  migration_cpu_stop() can complete pending waiters without a denied status.

affinity:
  allowed masks may already be mutated before affine move settlement.
  syscall-visible status must not be changed accidentally.

swap:
  migrate_swap_stop() moves two tasks.
  both directions need prevalidation or rollback proof.

push/pull/hotplug:
  RT, deadline, stop-machine, and hotplug push paths assume progress.

core-cookie-steal:
  try_steal_cookie() sets success and reschedules after a locked move.

fair load-balance:
  direct detach/set_cpu/attach paths bypass the common helpers.
```

## P5A-M Required Artifacts

Before any broad move-denial code:

```text
1. Move-result carrier design.
2. Caller settlement map for migration, affinity, swap, push, hotplug, RT, DL,
   and core-cookie-steal.
3. Decision on fair direct load-balance exclusion or coverage.
4. Model proving denied moves do not detach, mutate task_cpu, activate,
   wakeup-preempt, resched, complete waiters as success, or publish false
   migration/swap/syscall outcomes.
5. Source checker for function-scoped ordered patterns, not brittle line-only
   anchors.
```

## P5A0.P1 Acceptance Finding

The concrete `0008` patch is strong as a source-contract/no-behavior delta:

```text
source checker passed
patch queue replay matched exact head and tree
formal/0103 safe passed
11 unsafe configs produced expected counterexamples
```

It is not yet full acceptance.

Full acceptance still requires:

```text
CONFIG_SCHED_EXEC_LEASE=off/on full vmlinux builds
object equality or section-scoped equality evidence
symbol tables proving no callable/exported/static-key/trace/ABI surface
hot-function disassembly diffs
section-size diffs
layout evidence for task_struct, rq, sched_entity, cfs_rq, sched_exec_task
fresh upstream drift and merge-tree evidence
strict checkpatch and get_maintainer output
final overclaim/security review
```

## Allowed Claims After This Audit

Allowed:

```text
P5A-R and P5A-M blockers are sharper.
P5A0.P1 full acceptance evidence is enumerated.
No behavior-changing P5A patch is approved.
```

Forbidden:

```text
runtime denial
CFS deny-and-repick
broad move denial
runtime coverage
monitor verification
production protection
hypervisor-grade isolation
cost-efficiency
deployment readiness
datacenter readiness
```

## Next Work

If the P5A0.P1 full build completes successfully, record it separately as
validation evidence.

After P5A0.P1 full acceptance is closed, the next design-first work should be:

```text
P5A-R0:
  CFS picker eligibility and bounded retry model.

P5A-M0:
  no-behavior move-result/status plumbing design.
```
