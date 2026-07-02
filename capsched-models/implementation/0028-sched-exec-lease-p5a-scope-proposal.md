# Implementation 0028: SchedExecLease P5A Scope Proposal

Date: 2026-07-02

Status: implementation scope proposal only; no Linux code approved.

## Purpose

This is the implementation-facing companion to:

```text
analysis/0130-sched-exec-lease-p5a-scope-proposal.md
```

It defines what the next implementation discussion may cover. It does not
authorize a Linux patch.

## Current Decision

The next implementation conversation may prepare P5A0 only:

```text
no-behavior status plumbing shape
no-behavior test harness shape
no-behavior setup-time path-disable shape
claim-ledger integration
```

P5A0 must not:

```text
branch on non-ALLOW
deny a task
retry selection
fail closed
quarantine a task
change scheduler behavior
add ABI
call a monitor
claim protection
```

## Why This Is First

P5A-R run denial needs pre-settle CFS-visible ineligibility. The current P4
run helper is too late for denial.

P5A-M move denial needs status plumbing. The current move helpers are locally
pre-mutation, but callers assume success. Broad common move denial is rejected
for first P5A; P5A-M0 is status plumbing only.

Therefore the first possible P5A implementation work is infrastructure and
evidence plumbing, not denial.

## Required Before Any P5A0 Patch

Before writing a P5A0 Linux patch:

```text
fresh upstream drift row for touched groups
patch queue plan
source checker plan
build matrix plan
QEMU disabled-behavior smoke plan
negative-test harness plan
claim ledger row
explicit non-claims
```

## Required Before Any P5A Behavior Patch

Before a behavior-changing test-only patch:

```text
P5A0 validated
P5A-R pre-settle run design validated
P5A-M move settlement design validated
P5A-V negative tests implemented
denial disabled by default
unsupported paths disabled or excluded
no-overclaim review complete
```

Additional blockers:

```text
deny-one-CFS-and-pick-next requires fair-picker eligibility integration
broad common move denial requires caller status settlement across migration,
  affinity, swap, push, and core-cookie-steal paths
```

## Non-Claims

This proposal does not approve Linux code changes, behavior changes, runtime
denial, retry, fail-closed behavior, task-field changes, ABI, monitor calls,
monitor verification, production protection, hypervisor-grade isolation,
cost-efficiency, deployment readiness, or datacenter readiness.
