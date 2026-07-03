# Implementation 0032: SchedExecLease P5A0.P1 No-Behavior Implementation

Date: 2026-07-02

Status: accepted as P5A0.P1 no-behavior source-contract slice only.

## Purpose

This records the concrete P5A0.P1 Linux patch produced under
`implementation/0031`.

The patch is intentionally a source-contract boundary. It documents that
future non-ALLOW statuses, denied receipts, status plumbing, monitor roots, and
lifecycle-visible changes require later gates.

It does not change scheduler behavior.

## Linux Patch

Linux commit:

```text
d812f83c033a9f9b3d533e667e7106a5734eb30b
```

Parent:

```text
a937c67f51d1b82297c4f8b7c471f63e8f1a4fe8
```

Patch queue entry:

```text
linux-patches/patches/capsched-linux-l0/0008-sched-exec_lease-Document-P5A0.P1-no-behavior-bounda.patch
```

Changed files:

```text
include/linux/sched_exec_lease.h
kernel/sched/exec_lease.c
```

Delta:

```text
21 inserted comment lines
0 removed lines
0 non-comment code lines
```

## Accepted Source Facts

The `0008` delta satisfies the P5A0.P1 source gate:

```text
checkpatch_clean=true
delta_files_exact_allowlist=true
delta_comment_only=true
hot_helper_bodies_unchanged=true
lifecycle_helper_bodies_unchanged=true
sched_exec_task_layout_changed=false
helper_return_set_allow_only=true
scheduler_branch_on_validation_result=false
fair_picker_ineligibility=false
public_abi_or_monitor=false
runtime_denial=false
runtime_coverage_claim=false
production_or_cost_claim=false
```

Patch queue replay from the recorded base reconstructs the same Linux HEAD and
tree as the local Linux work tree.

## Non-Claims

This patch does not approve:

```text
runtime denial
fair-picker ineligibility
broad move denial
retry/fail-closed/quarantine behavior
runtime coverage
budget enforcement
public ABI or trace ABI
monitor calls or monitor verification
production protection
hypervisor-grade isolation
cost-efficiency
deployment or datacenter readiness
```

## Acceptance Closure

P5A0.P1 is closed as a no-behavior source-contract slice. The closure evidence
is:

```text
validation/0156: source checker, patch replay, and formal source gate
validation/0157: full vmlinux CONFIG_SCHED_EXEC_LEASE=off/on builds
validation/0158: object, symbol, section-size, hot function-size, and layout
validation/0159: candidate-scoped upstream drift and maintenance evidence
validation/0160: QEMU off/on boot/workload compatibility smoke
validation/0161: final overclaim and Codex Security diff review
```

This closure does not approve behavior-changing enforcement, runtime denial,
runtime coverage, public ABI, trace ABI, monitor calls, monitor verification,
production protection, cost-efficiency, deployment readiness, or datacenter
readiness.

## Next Design Direction

P5A0 remains no-behavior. The first behavior-changing work is still split:

```text
P5A-R:
  deny one CFS task and pick the next CFS task; requires fair-picker
  eligibility integration before code.

P5A-M:
  broad common move denial; requires status settlement across migration,
  affinity, swap, push, and core-cookie-steal paths before code.
```
