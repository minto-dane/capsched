# SchedExecLease P4 Static Final-Run Observability

Date: 2026-07-02

Status: static final-run anchor observability complete; runtime coverage and
P4 implementation remain unapproved.

## Purpose

N-169 closed the P4 anchor manifest. This note closes the next P4 blocker by
recording a static observability contract for the final-run anchor.

The previous runtime trace attempts could observe scheduler activity, but not
reliably observe `pick_next_task()` or `__schedule()` as kprobe targets. This
note does not paper over that limitation. It explicitly separates:

```text
static final-run anchor observability:
  source ordering proves where a future P4 allow-all helper can be placed.

runtime final-run coverage:
  not proven.
```

## Source Basis

```text
linux_branch: capsched-linux-l0
linux_commit: d5f77adb5a64f3b2545db6ab1dcdc4aa4442bab3
upstream_commit: 87320be9f0d24fce67631b7eef919f0b79c3e45c
anchor_manifest: analysis/sched-exec-lease-p4-anchor-manifest-v1.json
```

## Static Observation

The source checker verifies the A1 final-run allow-all join in
`kernel/sched/core.c::__schedule()`:

```text
picked:
clear_tsk_need_resched(prev);
clear_preempt_need_resched();
keep_resched:
rq->last_seen_need_resched_ns = 0;
is_switch = prev != next;
RCU_INIT_POINTER(rq->curr, next);
trace_sched_switch(...);
sched_exec_lease_note_switch(prev, next);
rq = context_switch(rq, prev, next, &rf);
```

Static insertion interval:

```text
after:  rq->last_seen_need_resched_ns = 0;
before: is_switch = prev != next;
```

This interval is before:

```text
RCU_INIT_POINTER(rq->curr, next);
trace_sched_switch(...);
sched_exec_lease_note_switch(prev, next);
context_switch(...)
```

Therefore, a future P4 allow-all helper can be placed at a statically
observable pre-`rq->curr` source interval.

## Important Negative Observation

The existing P3 marker:

```text
sched_exec_lease_note_switch(prev, next);
```

is after:

```text
RCU_INIT_POINTER(rq->curr, next);
trace_sched_switch(...)
```

and before:

```text
context_switch(...)
```

So it is useful as a post-publication compatibility marker only. It is not a
pre-`rq->curr` final-run anchor and must not be used as runtime coverage
evidence for P4 final-run validation.

## Checker

Machine-readable contract:

```text
analysis/sched-exec-lease-p4-static-final-run-observability-v1.json
```

Runner:

```text
validation/run-sched-exec-lease-p4-static-final-run-observability.sh
```

The runner verifies:

- the Linux work commit matches the contract;
- the A1 source window exists;
- the static insertion interval exists;
- the interval is before `rq->curr` publication;
- the interval is before `trace_sched_switch()`;
- the interval is before the existing P3 `sched_exec_lease_note_switch()`;
- the interval is before `context_switch()`;
- the existing P3 `note_switch` marker is after `rq->curr` publication;
- runtime coverage, monitor verification, and protection claims remain false.

## Decision

The static final-run anchor observability blocker is closed.

Remaining P4 blockers:

1. allow-all helper proof;
2. no reachable denial path proof;
3. generated-code review after the actual P4 patch;
4. build and QEMU validation after the actual P4 patch.

Runtime final-run coverage remains unproven. P4 may still use static
observability as the pre-implementation anchor evidence, but it may not claim
runtime coverage from it.

## Non-Claims

This note does not approve Linux code, P4 implementation, runtime denial,
runtime coverage, ABI, monitor calls, monitor verification, production
protection, hypervisor-grade isolation, cost-efficiency, or deployment
readiness.
