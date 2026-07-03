# Implementation 0033: SchedExecLease P5A-R Ordinary-CFS Patch Plan

Date: 2026-07-03

Status: behavior-patch draft plan only. Linux code is not modified by this
record.

## Purpose

This is the implementation-facing plan for the first P5A-R behavior patch:

```text
deny one ordinary CFS task and let ordinary CFS pick another ordinary CFS task
```

The plan exists to make the next Linux patch draftable without silently
approving runtime enforcement. It converts the preceding P5A-R gates into a
patch boundary, validation matrix, and claim ledger.

This is a narrow ordinary-CFS-only plan. It does not approve broad move denial,
RT, deadline, sched_ext, proxy execution, core scheduling, DL fair-server
settlement, monitor integration, or production protection.

## Source Basis

```text
linux_branch=capsched-linux-l0
linux_commit=d812f83c033a9f9b3d533e667e7106a5734eb30b
upstream_ref=upstream/master
upstream_commit=87320be9f0d24fce67631b7eef919f0b79c3e45c
next_patch_slot=linux-patches/patches/capsched-linux-l0/0009-...
```

Required prior gates:

```text
validation/0163 P5A-R picker ineligibility
validation/0164 P5A-R EEVDF return dominance
validation/0165 P5A-R group hierarchy settlement
validation/0166 P5A-R cross-path exclusion/settlement
validation/0167 P5A-R overhead/layout
validation/0168 P5A-R negative validation plan
```

## Patch Boundary

The future `0009` patch may be drafted only as an ordinary-CFS-only
behavior-candidate patch.

Default allowed files:

```text
include/linux/sched_exec_lease.h
kernel/sched/exec_lease.c
kernel/sched/fair.c
```

Conditionally allowed only if the patch cannot keep the boundary entirely in
`fair.c`:

```text
kernel/sched/core.c
kernel/sched/sched.h
```

Any touch outside this set requires a new scope gate before code review.

The future delta must remain private to the scheduler:

```text
no public syscall ABI
no public tracepoint ABI
no exported symbols
no monitor calls
no LSM hooks
no cgroup interface changes
no user-visible policy language
```

## Required Code Shape

The future code must make denial visible to the CFS picker before CFS selection
is settled.

Required shape:

```text
ordinary CFS fast path only
rq lock held
attempt-local carrier
fixed retry budget
fixed denied receipt capacity
pre-frozen identity tuple
candidate identity comparison only
pre-settle candidate rejection
same attempt must not repick the same task/generation
allowed sibling descendant must remain pickable
unsupported cross paths must be excluded or separately settled
```

The carrier may remember only a bounded set of denied identities for the current
pick attempt. It must not become persistent scheduler state.

The identity tuple must include at least:

```text
task stable identity
task generation
exec generation
domain epoch
grant epoch
attempt epoch
candidate CPU
candidate path/family
```

The future validation helper may answer:

```text
ALLOW
DENY_THIS_CANDIDATE_FOR_THIS_ATTEMPT
UNSUPPORTED_PATH
```

It may not use a non-ALLOW result to make claims outside the ordinary-CFS-only
test boundary.

## Forbidden Code Shape

The future patch must not:

```text
turn the existing P4 final-run hook into a denying hook
deny after put_prev_set_next_task()
deny after set_next_task_fair() / set_next_entity() settlement
deny after rq->curr publication
deny after sched_switch observation
use RETRY_TASK alone as denial
fall back to idle while an allowed ordinary-CFS candidate exists
linearly scan the rb-tree for an allowed task
scan full cgroup descendants as a denial path
use cfs_rq->nr_queued as child exhaustion proof
use delayed dequeue, sleep, throttle, yield, or EEVDF lag as authority proof
write persistent denial fields into task_struct, sched_entity, rq, or cfs_rq
allocate, sleep, call policy, or call a monitor from the picker
affect wakeup/preempt paths unless explicitly scoped and modeled
reuse stale carrier state across lock-drop/newidle attempts
```

## Cross-Path Boundary

The initial behavior candidate may claim only ordinary CFS final selection when
the support predicate proves:

```text
sched_ext inactive
core scheduling inactive for the rq
proxy execution not rewriting the chosen executor
DL server path not using fair pick under deadline server authority
class-loop non-fair selection not participating in the claim
```

If the predicate cannot prove this, the future patch must either refuse to
enable denial for that attempt or take an explicit unsupported-path result. It
must not silently apply ordinary-CFS semantics to those paths.

## Validation Required Before Accepting 0009

The future patch cannot be accepted without all of the following evidence:

```text
patch queue replay to exact Linux HEAD
upstream replay or merge-tree against recorded upstream/master
strict checkpatch/get_maintainer review
source checker for file allowlist and source anchors
source checker for pre-settle denial dominance
source checker for cross-path exclusion predicate
source checker for no public ABI or trace ABI
source checker for no monitor calls or exported symbols
source checker for no O(n), no unbounded retry, and no persistent hot layout
CONFIG_SCHED_EXEC_LEASE=off full vmlinux build
CONFIG_SCHED_EXEC_LEASE=on denial-disabled full vmlinux build
CONFIG_SCHED_EXEC_LEASE=on denial-test-mode build if test mode exists
object/function-size evidence for changed hot scheduler functions
layout evidence for task_struct, rq, sched_entity, and cfs_rq
QEMU denial-disabled boot/workload compatibility smoke
QEMU ordinary-CFS negative test: deny A, schedule B
QEMU negative test: denied A does not reach rq->curr or sched_switch
QEMU negative test: same task/generation is not repicked in same attempt
QEMU negative test: allowed sibling descendant remains schedulable
QEMU negative test: idle/fail-closed only when no supported allowed candidate exists
Codex Security diff scan or equivalent diff-scoped security review
final overclaim review
```

If any runtime negative test needs a long build or QEMU run, it should be run
under a durable systemd runner with the log path and resume command recorded.

## What This Plan Allows

This plan allows drafting the next Linux patch candidate:

```text
linux_behavior_patch_may_be_drafted=true
next_patch_slot=0009
ordinary_cfs_only=true
acceptance_requires_future_validation=true
```

## What This Plan Does Not Approve

This plan does not approve:

```text
accepting the 0009 patch
runtime denial as correct
CFS deny-and-repick as implemented
broad move denial
runtime coverage
benchmark evidence
budget enforcement
public ABI or trace ABI
monitor calls or monitor verification
production protection
hypervisor-grade isolation
cost-efficiency
deployment readiness
datacenter readiness
```

## Next

The next work may draft the `0009` Linux patch under this plan. The first draft
must be treated as unaccepted until the validation matrix above passes.
