# Implementation 0032: SchedExecLease P5A0.P1 No-Behavior Implementation

Date: 2026-07-02

Status: Linux `0008` patch created and source/replay/formal validated; full
build, QEMU, object/layout, and final overclaim acceptance remain pending.

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

## Remaining Acceptance Work

The source gate, full `vmlinux` build, and object/layout checks are not full
implementation closure. Validation/0157 records successful
`CONFIG_SCHED_EXEC_LEASE=off/on` full builds. Validation/0158 records
object/symbol/section-size review, hot scheduler function-size review, and
build-only task layout probe evidence. Validation/0159 records
candidate-scoped upstream drift, merge-tree, strict checkpatch, and
get_maintainer evidence. Validation/0160 records QEMU off/on boot/workload
smoke. Before treating P5A0.P1 as fully accepted, still run and record:

```text
final overclaim/security review
```

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
