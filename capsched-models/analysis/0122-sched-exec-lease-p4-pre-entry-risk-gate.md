# Analysis 0122: SchedExecLease P4 Pre-Entry Risk Gate

Status: Passed for P4 allow-all/no-denial pre-entry review; P4 implementation
is not applied; P5 denial remains blocked

Date: 2026-07-02

## Purpose

This gate decides whether the project may move from the validated P3
placement-only scheduler touchpoint patch toward the P4 allow-all final
run/move revalidation skeleton.

It does not approve a behavior-changing patch. It narrows what P4 may do and
records which evidence is strong, which evidence is negative, and which claims
remain forbidden.

## Source State

```text
linux_branch=capsched-linux-l0
linux_commit=d5f77adb5a64f3b2545db6ab1dcdc4aa4442bab3
linux_subject=sched/exec_lease: Add placement-only scheduler touchpoints
```

P4 must use this P3 HEAD as its current source basis. The older P4 plan text
that named the P2 commit as the basis is superseded by this gate.

## Inputs Reviewed

```text
validation/0140-sched-exec-lease-p3-validation.md
implementation/0024-sched-exec-lease-p4-allow-all-revalidation-skeleton-plan.md
analysis/0114-sched-ext-core-proxy-coverage-boundary.md
analysis/0115-bounded-retry-ineligibility-source-design.md
analysis/0117-scheduler-path-classification-for-p5.md
analysis/0118-implementation-claim-ledger-gate.md
analysis/0121-sched-exec-lease-p3-overclaim-review.md
```

Codex Security plugin preflight was also run for a diff-oriented scan profile.
The preflight returned ready, including delegated worker and goal-tool
availability. A full canonical Codex Security scan was not launched because
the current P3 diff has no user input parser, memory copy, ABI, allocation,
monitor call, credential path, or new privilege boundary. The security review
for this gate is therefore a scoped diff review, not a repository-wide
security finding report.

## Main Findings

### P4 May Proceed Only As Allow-All Skeleton

The next implementation candidate may introduce named validation-result
helpers for final run and queued move edges only if every production result is
allow:

```text
runtime denial: forbidden
retry/ineligibility/quarantine: forbidden
fail-closed idling: forbidden
monitor activation/receipt: forbidden
budget charge/enforcement: forbidden
user ABI or public tracepoint ABI: forbidden
production protection claim: forbidden
```

The allowed P4 objective is source-shape and compatibility evidence only:

```text
Can Linux carry explicit run/move validation call sites without changing
behavior?
```

### P3 Is Not Byte-Identical To P2

The P2-vs-P3 `kernel/sched/core.o` comparison produced identical section
sizes and identical relocations, but not byte-identical objects.

Observed differences:

```text
try_to_wake_up:
  test %ebp,%eax
  test %eax,%ebp

__schedule:
  two independent mov loads were reordered before switch_mm_irqs_off
```

Marker symbols were absent in both disabled and enabled P3 scheduler objects.
The practical interpretation is:

```text
P3 no-behavior compatibility is supported by source review, no-op inline
helpers, identical section sizes, identical relocations, semantic disassembly
review, and QEMU workload success.

P3 is not supported by byte-for-byte object identity.
```

P4 validation must therefore avoid requiring byte identity as the only
generated-code criterion. It should require generated-code review that
separates harmless compiler scheduling noise from real control-flow or data
dependency changes.

### Runtime Coverage Still Must Not Be Claimed

Broader QEMU workload evidence exercised fork/exec, cross-CPU futex wakeups,
affinity migration, scheduler ticks, enqueue, wakeup, migration, and switches.
It still did not make `pick_next_task` or `__schedule` visible through the
current ftrace/kprobe runner:

```text
FUNCTION_MISSING pick_next_task
FUNCTION_MISSING __schedule
KPROBE_ADD_FAILED p:domainlease/dlease_pick_next_task pick_next_task
```

This is useful compatibility evidence. It is not runtime coverage for future
P4 validation helpers and not negative-denial evidence.

### P4 Final Run Hook Is Not A P5 Denial Hook

analysis/0115 remains binding. In current Linux, some scheduler class state
may already be settled by the time a selected candidate is visible near the
P4 conceptual final-run edge. Therefore:

```text
P4 allow-all observation can be useful.
P4 cannot be upgraded into P5 denial by changing return values.
P5 denial still needs pre-settle validation or a source-proved rollback path.
```

### P5 Path Classification Remains Binding

The initial P5 support set is narrower than the Linux scheduler:

```text
supported for future P5 review:
  ordinary CFS final run in non-core, non-proxy, non-sched_ext configurations
  common queued move helpers

disabled for future P5 review:
  sched_ext
  core scheduling
  proxy execution

excluded from runtime coverage claims:
  fair direct load balance
  RT
  deadline
  idle exception paths
  stopper/hotplug/migration kthreads
  generic kthreads/workqueues
  io_uring workers
```

P4 may still be source-compatible with those paths as an allow-all skeleton,
but it must not use that compatibility to claim enforcement coverage.

## Checkpatch and Upstream Readiness

`git diff --check` passed for the P3 diff.

`checkpatch.pl --strict --no-tree` against patch queue 0006 reported:

```text
WARNING: Missing commit description
ERROR: Missing Signed-off-by
```

This is not a semantic blocker for P4 pre-entry because changing the P3 commit
now would invalidate existing evidence hashes. It is an upstream-readiness
blocker before an RFC/mainline-style patch series.

## P4 Entry Decision

P4 may be planned and implemented only under this scope:

```text
slice: P4
mode: allow-all
behavior_change: false
runtime_denial: false
claim_class: compatibility/source-shape only
required_before_acceptance:
  patch queue replay
  git diff --check
  full vmlinux off/on build
  QEMU off/on workload smoke
  generated-code review
  non-overclaim review
```

The P4 plan and machine-readable JSON basis have been updated to this P3 HEAD
as part of this pre-entry gate.

## Non-Claims

This gate does not approve runtime enforcement, runtime denial, retry,
quarantine, fail-closed behavior, runtime coverage, ABI, public tracepoint ABI,
monitor ABI, monitor verification, budget enforcement, policy frontend
integration, hypervisor-grade isolation, production protection, cost
efficiency, or datacenter deployment readiness.
