# SchedExecLease P4 Anchor Manifest

Date: 2026-07-02

Status: anchor manifest complete; P4 implementation still not approved.

## Purpose

N-168 closed the candidate-scoped drift blocker for `P4SchedulerAllowAll`.
This note closes the next blocker: an exact source anchor manifest for the P4
allow-all skeleton.

This is not a Linux patch. It records where a future P4 patch may place
allow-all helper calls and what source ordering must remain true.

## Source Basis

```text
linux_branch: capsched-linux-l0
linux_commit: d5f77adb5a64f3b2545db6ab1dcdc4aa4442bab3
upstream_ref: upstream/master
upstream_commit: 87320be9f0d24fce67631b7eef919f0b79c3e45c
```

The candidate-scoped drift gate says the P4 scheduler candidate groups remain
fresh against this upstream. The global all-angles gate is still not fresh
because `device_queue_iommu` remains D4 stale.

## P4 Candidate Anchors

### A1: final run allow-all join

```text
path: kernel/sched/core.c
function: __schedule()
anchor window:
  picked:
  clear_tsk_need_resched(prev);
  clear_preempt_need_resched();
  keep_resched:
  rq->last_seen_need_resched_ns = 0;
  is_switch = prev != next;
  RCU_INIT_POINTER(rq->curr, next);
  rq = context_switch(rq, prev, next, &rf);
```

P4 may place an allow-all helper between:

```text
after:  rq->last_seen_need_resched_ns = 0;
before: is_switch = prev != next;
```

Rationale:

- this join is after ordinary pick/proxy/donor resolution;
- it is before `rq->curr` publication;
- it covers the normal `picked` path and the `keep_resched` join;
- it is source-shape evidence only.

Hard limit:

```text
This is not a P5 denial-safe anchor.
```

By this point, scheduler-class state may already be settled by
`put_prev_set_next_task()` and normal-path resched state may already be
cleared. P4 may observe and call an always-allow helper here. P5 denial must
use a separate pre-settle or rollback-proven design.

### A2: common queued move allow-all edge

```text
path: kernel/sched/core.c
function: move_queued_task()
anchor window:
  sched_exec_lease_note_queued_move(p, new_cpu);
  deactivate_task(rq, p, DEQUEUE_NOCLOCK);
  set_task_cpu(p, new_cpu);
  rq_unlock(rq, rf);
  activate_task(rq, p, 0);
```

P4 may place an allow-all helper between:

```text
after:  sched_exec_lease_note_queued_move(p, new_cpu);
before: deactivate_task(rq, p, DEQUEUE_NOCLOCK);
```

Rationale:

- the task is still attached to the source runqueue;
- destination CPU is known;
- the hook is before detach and before CPU mutation.

Hard limit:

```text
move_queued_task() is not authority.
```

It is only a source edge where an allow-all P4 skeleton can later be upgraded
under a separate P5 move-denial design.

### A3: double-rq locked queued move allow-all edge

```text
path: kernel/sched/sched.h
function: move_queued_task_locked()
anchor window:
  sched_exec_lease_note_queued_move(task, dst_rq->cpu);
  deactivate_task(src_rq, task, 0);
  set_task_cpu(task, dst_rq->cpu);
  activate_task(dst_rq, task, 0);
```

P4 may place an allow-all helper between:

```text
after:  sched_exec_lease_note_queued_move(task, dst_rq->cpu);
before: deactivate_task(src_rq, task, 0);
```

Rationale:

- both runqueue locks are asserted held;
- source detach has not happened;
- destination CPU is known through `dst_rq->cpu`.

Hard limit:

```text
The common move helper does not cover this locked path.
```

P4 must keep the common and double-rq move concepts separate.

## Explicit Non-Coverage

This manifest does not cover:

- fair direct detach/attach load balancing;
- active balance stopper migration;
- sched_ext DSQ custody, dispatch, consume, or fallback;
- core scheduling cached pick freshness;
- proxy execution migration;
- RT/DL final denial semantics;
- kthreads, workqueues, io_uring workers, or async provenance;
- hotplug exception semantics;
- monitor activation or monitor receipts.

These paths remain excluded or future work. P4 must not claim runtime
coverage.

## Static Check

Machine-readable manifest:

```text
analysis/sched-exec-lease-p4-anchor-manifest-v1.json
```

Source checker:

```text
validation/run-sched-exec-lease-p4-anchor-manifest-check.sh
```

The checker verifies:

- the expected Linux work commit;
- each anchor file exists;
- each source window exists;
- required patterns occur in order;
- the proposed insertion interval exists;
- the helper point is before `rq->curr` publication for A1;
- the move helper points are before detach and CPU mutation for A2/A3.

## Decision

The P4 anchor manifest is complete.

P4 implementation is still not approved. Remaining P4 blockers:

1. runtime or static final-run anchor observability record;
2. allow-all helper proof;
3. no reachable denial path proof;
4. generated-code review after the actual P4 patch;
5. build and QEMU validation after the actual P4 patch.

## Non-Claims

This note does not approve Linux code, runtime denial, runtime coverage, ABI,
monitor calls, monitor verification, production protection, hypervisor-grade
isolation, cost-efficiency, or deployment readiness.
