# Analysis 0129: SchedExecLease P5 Readiness Refresh After P4

Date: 2026-07-02

Status: P5 remains blocked; current P4 hooks are not denial-ready.

## Purpose

P4 is now closed as an allow-only compatibility slice at:

```text
linux_commit: a937c67f51d1b82297c4f8b7c471f63e8f1a4fe8
subject: sched/exec_lease: Add allow-only validation skeleton
```

This refresh reopens the P5 denial-readiness question against the actual P4
code rather than the earlier prepatch design. The result is deliberately
conservative:

```text
P4 helper placement is useful for source pressure and no-denial compatibility.
It is not sufficient to approve behavior-changing denial.
```

## Reviewed Evidence

Local source:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
work_commit: a937c67f51d1b82297c4f8b7c471f63e8f1a4fe8
```

Existing model basis:

```text
analysis/0100-final-run-move-revalidation-hook-placement-gate.md
analysis/0101-final-deny-retry-ineligibility-gate.md
analysis/0102-task-frozen-run-lifetime-locking-gate.md
analysis/0115-bounded-retry-ineligibility-source-design.md
analysis/0116-negative-denial-validation-plan.md
analysis/0117-scheduler-path-classification-for-p5.md
implementation/0025-sched-exec-lease-p5-test-only-denial-readiness-gate.md
```

Independent read-only reviews:

```text
subagent Pasteur:
  current run-edge hook is after class/proxy/blocking state changes; move
  helpers are locally pre-mutation but caller-unsafe without status plumbing.

subagent Zeno:
  upstream refresh must use function-scoped order checks rather than line
  anchors; move anchors are more stable than the final-run anchor.

subagent Banach:
  P5 must be test-only, off by default, path-classified, pre-settle where
  possible, and forbidden from monitor/production/security claims.
```

## Current P4 Hook Facts

### Run Edge

The P4 run-edge helper is at:

```text
kernel/sched/core.c:7199
  (void)sched_exec_lease_validate_run_edge(prev, next);
```

It is before:

```text
kernel/sched/core.c:7200 is_switch = prev != next
kernel/sched/core.c:7207 RCU_INIT_POINTER(rq->curr, next)
kernel/sched/core.c:7241 context_switch(rq, prev, next, &rf)
```

That is sufficient for P4 no-denial source observability.

It is not sufficient for P5 denial because the same schedule pass may already
have performed class or proxy settlement before the helper runs:

```text
kernel/sched/core.c:7147 try_to_block_task(...)
kernel/sched/core.c:7154 next = pick_next_task(rq, &rf)
kernel/sched/core.c:7159 rq_set_donor(rq, next)
kernel/sched/core.c:7190 rq_set_donor(rq, next)
kernel/sched/core.c:7194 clear_tsk_need_resched(prev)
kernel/sched/core.c:7195 clear_preempt_need_resched()
```

`pick_next_task()` can call `put_prev_set_next_task()` before returning:

```text
kernel/sched/core.c:6157 put_prev_set_next_task(rq, rq->donor, p)
kernel/sched/core.c:6169 put_prev_set_next_task(rq, rq->donor, p)
kernel/sched/core.c:6453 put_prev_set_next_task(rq, rq->donor, next)
```

and that helper mutates scheduler-class state:

```text
kernel/sched/sched.h:2764 __put_prev_set_next_dl_server(...)
kernel/sched/sched.h:2769 prev->sched_class->put_prev_task(...)
kernel/sched/sched.h:2770 next->sched_class->set_next_task(...)
```

Therefore:

```text
pre-rq->curr != pre-class-settle
```

The current P4 run-edge helper must not be turned into a denying hook without
either moving validation before class settlement or proving a class/proxy/core
rollback path.

### Common Queued Move

The common queued move helper is locally pre-mutation:

```text
kernel/sched/core.c:2552 validate_move_edge(p, new_cpu)
kernel/sched/core.c:2554 deactivate_task(rq, p, DEQUEUE_NOCLOCK)
kernel/sched/core.c:2555 set_task_cpu(p, new_cpu)
kernel/sched/core.c:2562 activate_task(rq, p, 0)
```

This is a better P5 candidate than the current run hook, but the function
currently returns only the new runqueue pointer:

```text
static struct rq *move_queued_task(...)
```

Callers assume the move has succeeded. For example:

```text
kernel/sched/core.c:2603 rq = move_queued_task(...)
kernel/sched/core.c:2659 p->migration_pending = NULL
kernel/sched/core.c:2722 complete_all(&pending->done)
kernel/sched/core.c:3081 rq = move_queued_task(...)
kernel/sched/core.c:3084 p->migration_pending = NULL
kernel/sched/core.c:3091 complete_all(&pending->done)
```

So P5 move denial requires status plumbing before behavior changes. A denial
must not complete affinity or migration waiters as if a move succeeded.

### Locked Queued Move

The locked double-rq helper is also locally pre-mutation:

```text
kernel/sched/sched.h:4125 validate_move_edge_locked(task, dst_rq->cpu)
kernel/sched/sched.h:4127 deactivate_task(src_rq, task, 0)
kernel/sched/sched.h:4128 set_task_cpu(task, dst_rq->cpu)
kernel/sched/sched.h:4129 activate_task(dst_rq, task, 0)
```

But it is currently:

```text
void move_queued_task_locked(...)
```

Callers therefore assume success. Relevant examples:

```text
kernel/sched/core.c:2755 move_queued_task_locked(rq, lowest_rq, p)
kernel/sched/core.c:3409 move_queued_task_locked(src_rq, dst_rq, p)
kernel/sched/core.c:3456 __migrate_swap_task(arg->src_task, arg->dst_cpu)
kernel/sched/core.c:3457 __migrate_swap_task(arg->dst_task, arg->src_cpu)
kernel/sched/core.c:6499 move_queued_task_locked(src, dst, p)
kernel/sched/core.c:6502 success = true
```

For `migrate_swap_stop()`, P5 cannot safely deny one half after the other half
has moved. Both directions must be prevalidated before either movement, or the
operation needs an explicit rollback and error return.

## P5 Readiness Decision

P5 remains blocked.

The current code supports only this claim:

```text
P4 allow-only compatibility is closed.
```

It does not support:

```text
branching on non-ALLOW
runtime denial
runtime coverage
budget enforcement
monitor call
monitor verification
production protection
hypervisor-grade isolation
cost-efficiency
deployment readiness
```

## Preconditions Before Any P5 Patch

Before a behavior-changing P5 patch is reviewable:

1. Run denial must be pre-settle, or every touched CFS/RT/DL/sched_ext/core/proxy
   path must have a source-proved rollback.
2. Denied candidates must become visible to the picker as ineligible in the
   current retry epoch.
3. Retry must be bounded and progress-making.
4. Fail-closed must be allowed only when no supported eligible candidate
   remains.
5. `move_queued_task()` and `move_queued_task_locked()` need status plumbing or
   an equivalent settlement protocol before move denial.
6. Affinity and migration completion paths must not report success after a
   denied move.
7. `migrate_swap_stop()` must prevalidate both directions or provide atomic
   rollback.
8. sched_ext, core scheduling, proxy execution, RT, deadline, direct fair
   detach/attach, kthreads, workqueues, and io_uring must be disabled, excluded,
   or separately supported with negative tests.
9. Negative tests must show denied tasks do not reach `rq->curr`,
   `sched_switch`, or `context_switch`.
10. All evidence must remain test-only and off by default until the claim
    ledger is explicitly reopened.

## Upstream-Resilience Rule

Future refresh must not depend on exact line numbers. The stable form is:

```text
function-scoped ordered-pattern checks
```

Required semantic checks:

```text
run validate precedes rq->curr publication and context_switch
run validate is not treated as denial-ready unless pre-settle or rollback proof exists
move validate precedes deactivate_task and set_task_cpu
locked move validate precedes deactivate_task and set_task_cpu
move helpers expose denial status before any non-ALLOW branch is introduced
missing/renamed anchors fail closed for manual review
```

## Next Reviewable Work

The next work is still not a P5 Linux patch. The next reviewable work is:

```text
formal/0098-p5-readiness-after-p4-gate-model/
validation/run-sched-exec-lease-p5-readiness-after-p4.sh
validation/0151-sched-exec-lease-p5-readiness-after-p4.md
```

Only after that gate is closed may we design the first no-production,
test-only P5 denial patch.

## Non-Claims

This refresh does not approve Linux code changes, scheduler behavior changes,
P5 denial, runtime coverage, task-field changes, public ABI, monitor ABI,
monitor verification, production protection, hypervisor-grade isolation,
cost-efficiency, or deployment readiness.
