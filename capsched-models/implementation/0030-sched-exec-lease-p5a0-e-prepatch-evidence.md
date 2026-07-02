# Implementation 0030: SchedExecLease P5A0.E Prepatch Evidence

Date: 2026-07-02

Status: prepatch evidence only; no Linux patch approved.

## Purpose

This translates analysis/0132 into the implementation-facing gate before any
P5A0 no-behavior Linux patch is written.

P5A0.E does not add code. It records the review package that a later P5A0.P1
patch must satisfy.

## Candidate Scope

Candidate:

```text
P5A0EPrepatchEvidence
```

Allowed scope:

```text
source-only evidence
source checker contract
patch queue plan
build/QEMU plan
object/symbol plan
negative harness plan
claim ledger row
```

Touched or claimed drift groups:

```text
l0_footprint
scheduler_authority_core
```

Unclaimed groups must reopen scope if touched:

```text
task_lifecycle_identity
async_workqueue
async_io_uring
policy_frontend_security
memory_and_mm_state
device_queue_iommu
```

## Future Patch Queue Plan

If a P5A0.P1 patch is later proposed, it should be the next patch queue entry:

```text
patches/capsched-linux-l0/0008-...
```

The recommended P5A0.P1 Linux file allowlist is:

```text
include/linux/sched_exec_lease.h
kernel/sched/exec_lease.c
```

Touching scheduler control-flow files such as `kernel/sched/core.c`,
`kernel/sched/sched.h`, `kernel/sched/fair.c`, `kernel/sched/rt.c`,
`kernel/sched/deadline.c`, or `kernel/sched/ext/ext.c` requires a new
scheduler-settlement scope gate.

Required properties:

```text
no behavior change
no runtime denial
no non-ALLOW branch
no retry
no fail-closed path
no quarantine
no public ABI
no monitor call
exact patch queue replay before acceptance
clean checkpatch before acceptance
```

## Source Checker Plan

The future checker must prove:

```text
Linux HEAD matches the recorded contract
candidate groups are fresh for the recorded upstream drift run
non-candidate stale groups are explicitly barred from broad claims
helper return set remains ALLOW-only
scheduler does not branch on validation result
expected validation helper and callsite counts are preserved or explicitly
  refreshed
run helper is not a denial hook
move helpers do not create reachable non-ALLOW behavior
no public ABI or monitor ABI appears
no allocation, sleep, lock transfer, refcount transfer, or monitor call appears
no task_struct/rq/sched_entity/cfs_rq layout change appears
```

## Acceptance Plan

A later P5A0.P1 patch cannot be accepted without:

```text
patch queue replay
checkpatch
source checker
CONFIG_SCHED_EXEC_LEASE=n full vmlinux build
CONFIG_SCHED_EXEC_LEASE=y full vmlinux build
QEMU denial-disabled boot/workload smoke
object/symbol review
overclaim/security review
```

## Claim Ledger Row

Allowed:

```text
p5a0_e_prepatch_evidence_recorded
candidate_scoped_drift_fresh_for_l0_footprint_and_scheduler_authority_core
```

Forbidden:

```text
linux_patch_approved
behavior_change
runtime_denial
runtime_coverage
monitor_verification
production_protection
hypervisor_grade_isolation
cost_efficiency
deployment_readiness
datacenter_readiness
global_all_angles_freshness
```

## Non-Claims

This implementation note does not approve Linux code, behavior changes,
runtime denial, retry, fail-closed behavior, quarantine, public ABI, tracepoint
ABI, monitor calls, monitor verification, runtime coverage, production
protection, hypervisor-grade isolation, cost-efficiency, deployment readiness,
datacenter readiness, or global all-angles freshness.
