# Analysis 0130: SchedExecLease P5A Scope Proposal

Date: 2026-07-02

Status: scope proposal recorded; P5 Linux implementation still not approved.

## Purpose

P4 is complete as an allow-only compatibility slice. P5 readiness has been
refreshed against the actual P4 code and remains blocked:

```text
analysis/0129-sched-exec-lease-p5-readiness-refresh-after-p4.md
validation/0151-sched-exec-lease-p5-readiness-after-p4.md
```

This note defines the first reviewable P5A scope shape. It does not approve a
Linux patch. Its job is to prevent the next work from collapsing several
different problems into one behavior-changing scheduler patch.

## Core Decision

P5A must be split into four sub-slices:

```text
P5A0:
  no-behavior infrastructure proposal
  status plumbing shape
  negative-test harness shape
  setup-time path-disable shape

P5A-R:
  run denial design
  ordinary CFS only
  non-core, non-proxy, non-sched_ext
  pre-settle candidate ineligibility
  no "deny one CFS task and choose next CFS task" until fair-picker
    ineligibility is designed

P5A-M:
  move status-plumbing design
  broad common move denial rejected for first P5A
  explicit status plumbing
  caller settlement rules

P5A-V:
  validation and claim ledger
  negative tests
  build and QEMU matrix
  no-overclaim review
```

No single first P5 patch may implement run denial, move denial, path disables,
negative instrumentation, and claim evidence all at once.

## Why P5A0 Comes First

The current P4 run hook is:

```text
before rq->curr
before context_switch
after pick_next_task
after known class settlement sources
```

Therefore it is not a denial hook.

The current move hooks are:

```text
before local deactivate_task
before local set_task_cpu
```

but they do not return denial status and callers assume success.

Therefore P5A0 must not add denial. It may only prepare reviewable plumbing and
testability, after a separate patch proposal:

```text
no behavior change
no non-ALLOW branch
no runtime denial
no retry
no fail-closed
no quarantine
no ABI
no monitor call
```

## P5A-R: Run Denial Design Scope

Allowed first run-denial design target:

```text
ordinary CFS final run
non-core
non-proxy
non-sched_ext
test-only
off by default
```

The plausible pre-settle source region is the ordinary all-CFS fast path:

```text
kernel/sched/core.c:6146 ordinary fair fast-path condition
kernel/sched/core.c:6149 p = pick_task_fair(rq, rf)
kernel/sched/core.c:6157 put_prev_set_next_task(rq, rq->donor, p)
```

or a fair-picker-internal point after the final leaf task is resolved:

```text
kernel/sched/fair.c:9939 p = task_of(se)
kernel/sched/fair.c:9942 return p
```

Required design shape:

```text
validate before put_prev_set_next_task()
make denied candidate invisible to the picker for the retry epoch
retry is bounded
same task/generation cannot be selected again in the same retry epoch
fail-closed only after supported eligible set is exhausted
idle fallback is not authority
```

The current `__schedule()` P4 helper may remain as a final observation or
assertion point, but it must not be the first denial point.

P5A-R remains blocked until a CFS-visible ineligibility plan exists. A simple
post-`pick_task_fair()` rejection is not enough if the same entity can be
selected again without changing picker-visible state.

The only behavior-changing run experiment that may be considered before full
fair-picker ineligibility is a narrow deny-to-idle smoke test, and even that is
not approved here. It would require all of:

```text
ordinary all-CFS fast path only
no sched_ext
no core scheduling
no proxy execution
no RT/DL/generic class loop
no DL fair-server use
no CFS bandwidth/throttle complexity
explicit evidence that it is a smoke test, not coverage
```

If the goal is:

```text
deny one CFS task and select the next eligible CFS task
```

then P5A-R must wait for real fair-picker eligibility integration.

## P5A-M: Move Denial Design Scope

Allowed first move-design target:

```text
move_queued_task()
move_queued_task_locked()
status plumbing only
no behavior change
```

Required design shape:

```text
validation status is returned or otherwise settled
callers do not report success after denied move
affinity and migration waiters are not completed as success after denial
destination reschedule is not requested after denied move
two-way swap prevalidates both moves before either movement or has rollback
core cookie steal cannot mark success after denied move
```

Broad common queued move denial is rejected for first P5A. The current helpers
are locally pre-mutation, but the caller graph assumes success. P5A-M0 may only
design or later implement no-behavior status plumbing.

P5A-M remains blocked until status propagation is designed for at least:

```text
__migrate_task()
migration_cpu_stop()
affine_move_task()
push_cpu_stop()
migrate_swap_stop()
try_steal_cookie()
```

Direct fair load-balance detach/attach remains excluded from the first P5A-M
scope because it does not pass through the current common move helpers.

If a behavior-changing move experiment is later desired, the first candidate is
not broad common move denial. It must be a tightly fenced optional movement
test such as a sched-exec-only movement path with no pending affinity object,
no hotplug, no RT/DL, no core, no proxy, and no sched_ext involvement. That is
not approved by this proposal.

## Disabled and Excluded Paths

P5A must preserve the existing initial classification:

```text
disabled for test-denial setup:
  sched_ext
  core scheduling
  proxy execution

excluded from first P5A runtime coverage:
  RT
  deadline
  fair direct load-balance detach/attach
  idle as authority
  stopper/hotplug/migration kthreads as ordinary Domain execution
  generic kthreads and workqueues
  io_uring workers
```

If any patch touches a disabled or excluded path, it must first update the path
classification, formal gate, validation plan, and claim ledger.

## Required Negative Tests

P5A-V must map every test to an observable. Minimum obligations:

```text
NDENY-001: post-settle denial without rollback is rejected
NDENY-002: denied candidate never reaches rq->curr, sched_switch, or context_switch
NDENY-003: same task/generation is not re-picked in the retry epoch
NDENY-004: CFS picker-visible ineligibility exists before run denial
NDENY-005: denied move does not detach or mutate task CPU
NDENY-006: denied move does not complete affinity/migration waiters as success
NDENY-007: fail-closed is rejected while supported eligible candidate exists
NDENY-008: disabled/excluded paths cannot be used for coverage or protection claims
NDENY-009: runtime/protection/cost claims remain false
```

These observables may be internal test instrumentation. They must not become
public tracepoint ABI without a separate gate.

## Review Order

P5A review must proceed in this order:

```text
1. P5A scope gate
2. P5A0 no-behavior infrastructure proposal
3. P5A0 implementation patch, if approved separately
4. P5A-R run-denial design model
5. P5A-M move-denial settlement model
6. P5A-V negative validation harness
7. first test-only behavior patch, if all previous gates pass
```

This ordering is intentionally slower than writing an immediate denial patch.
It is the price of not corrupting scheduler state while pretending to enforce
authority.

## Non-Claims

This proposal does not approve Linux code changes, behavior changes, runtime
denial, retry, fail-closed behavior, quarantine, task-field changes, public ABI,
tracepoint ABI, monitor ABI, monitor calls, monitor verification, production
protection, hypervisor-grade isolation, cost-efficiency, deployment readiness,
or datacenter readiness.
