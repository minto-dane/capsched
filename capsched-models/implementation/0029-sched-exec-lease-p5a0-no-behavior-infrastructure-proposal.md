# Implementation 0029: SchedExecLease P5A0 No-Behavior Infrastructure Proposal

Date: 2026-07-02

Status: implementation proposal only; no Linux patch approved.

## Purpose

This is the implementation-facing proposal for P5A0. It follows:

```text
analysis/0131-sched-exec-lease-p5a0-no-behavior-infrastructure-proposal.md
```

P5A0 is not a denial patch. It is the last planning gate before considering a
no-behavior Linux infrastructure patch.

## Allowed Future Patch Shape

A future P5A0 Linux patch may be proposed only if it remains no-behavior:

```text
helpers still return ALLOW
scheduler still does not branch on validation result
no non-ALLOW path reachable
no retry
no fail-closed
no quarantine
no runtime denial
no ABI
no monitor call
```

The patch may prepare:

```text
move status plumbing shape
run observation status shape
internal negative-test observability shape
setup-time unsupported-path classification shape
claim ledger integration
```

## Candidate Patch Units

The safest future review order is:

```text
P5A0.E:
  prepatch evidence package; no Linux patch

P5A0.P1:
  source-only contract and internal type shapes, limited by default to
  include/linux/sched_exec_lease.h and kernel/sched/exec_lease.c

P5A0.P2:
  move status carrier plumbing with ALLOW-only behavior

P5A0.P3:
  internal negative-test harness skeleton with no public ABI

P5A0.P4:
  disabled-path setup skeleton with no behavior change until test-denial mode
  exists

P5A0.P5:
  source/object/build/QEMU validation and overclaim review
```

Any patch that changes scheduler behavior must be moved out of P5A0.

## Review Blockers

Before writing P5A0.P1:

```text
fresh upstream drift row
patch queue plan
source checker plan
build/QEMU plan
object/symbol plan
claim ledger row
explicit file allowlist
```

Before accepting any P5A0 patch:

```text
patch queue replay
checkpatch
source checker
CONFIG off/on build
QEMU denial-disabled smoke
object/symbol review
overclaim review
```

## Non-Claims

This proposal does not approve Linux code changes, behavior changes, runtime
denial, retry, fail-closed behavior, quarantine, ABI, monitor calls, monitor
verification, runtime coverage, production protection, hypervisor-grade
isolation, cost-efficiency, deployment readiness, or datacenter readiness.
