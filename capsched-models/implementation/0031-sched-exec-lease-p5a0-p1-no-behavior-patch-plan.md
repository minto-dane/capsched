# Implementation 0031: SchedExecLease P5A0.P1 No-Behavior Patch Plan

Date: 2026-07-02

Status: patch plan only; no Linux patch approved.

## Purpose

This is the implementation-facing P5A0.P1 plan. It does not create
`linux-patches` entry 0008 and does not modify Linux.

P5A0.P1 is allowed to be only a source-contract/internal-type-shape patch.

## File Allowlist

Default allowlist:

```text
include/linux/sched_exec_lease.h
kernel/sched/exec_lease.c
```

Any change outside this allowlist is not P5A0.P1 unless a new scope gate is
recorded first.

This is a delta rule for the future `0008` patch. The existing queue already
contains earlier scheduler/lifecycle/Kconfig/Makefile changes, so validating the
whole queue footprint is not enough for P5A0.P1.

## Allowed Future Content

Allowed:

```text
comments
contract prose
opaque forward declarations
private unused type declarations in kernel/sched/exec_lease.c
private constants not referenced from scheduler hot paths
```

Not allowed:

```text
changing sched_exec_task layout
changing static inline helper bodies used by scheduler hot paths
changing sched_exec_task_reset/prepare_fork/commit_exec/exit behavior
adding non-ALLOW helper returns
adding scheduler control-flow branches
adding runtime constructors or global runtime state
adding non-static symbols
adding ABI, monitor calls, tracepoints, static keys, printk, allocation, sleep,
locks, refcount transfer, or exported symbols
```

For P5A0.P1, no-overhead is part of the contract: the future acceptance record
must include object/symbol/section-size evidence for `exec_lease.o`, hot
scheduler function growth evidence for `core.o` and `fair.o`, and layout
evidence for `task_struct`, `rq`, `sched_entity`, and `cfs_rq`.

## Future Patch Queue Plan

Future patch slot:

```text
patches/capsched-linux-l0/0008-...
```

The patch cannot be accepted without a per-`0008` delta footprint manifest,
replay from the recorded base, disposable replay against an exact current
upstream commit, merge-tree against that commit, checkpatch, source checker,
off/on full builds, QEMU denial-disabled smoke, object/symbol/disassembly
review, section-size and hot-function growth review, layout review, and
overclaim/security review.

## Non-Claims

This plan does not approve Linux code, behavior changes, runtime denial,
runtime coverage, monitor verification, production protection,
hypervisor-grade isolation, cost-efficiency, deployment readiness, datacenter
readiness, or global all-angles freshness.
