# Analysis 0133: SchedExecLease P5A0.P1 No-Behavior Patch Plan

Date: 2026-07-02

Status: patch plan only; no Linux patch approved.

## Purpose

P5A0.E recorded the evidence package. P5A0.P1 is the future first
no-behavior Linux patch proposal, but this note still does not write or approve
that patch.

The purpose of P5A0.P1 is narrow:

```text
prepare source-only contract and internal type shapes
without changing scheduler behavior, hot-path codegen, task layout, public ABI,
or monitor surface
```

## Source Basis

Linux work tree:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
commit: a937c67f51d1b82297c4f8b7c471f63e8f1a4fe8
subject: sched/exec_lease: Add allow-only validation skeleton
```

P5A0.E evidence:

```text
analysis/0132-sched-exec-lease-p5a0-e-prepatch-evidence.md
validation/0154-sched-exec-lease-p5a0-e-prepatch-evidence.md
```

## File Scope

Default P5A0.P1 file allowlist:

```text
include/linux/sched_exec_lease.h
kernel/sched/exec_lease.c
```

P5A0.P1 must not touch:

```text
include/linux/sched.h
kernel/sched/core.c
kernel/sched/sched.h
kernel/sched/fair.c
kernel/sched/rt.c
kernel/sched/deadline.c
kernel/sched/ext/ext.c
kernel/fork.c
fs/exec.c
kernel/exit.c
init/Kconfig
kernel/sched/Makefile
```

Touching any scheduler control-flow file reopens scope and is not P5A0.P1.

The allowlist is necessary but not sufficient. `kernel/sched/exec_lease.c`
already contains task lifecycle helpers called from fork, exec, and exit paths.
P5A0.P1 therefore also freezes observable lifecycle helper behavior.

## Allowed Diff Classes

Allowed in `include/linux/sched_exec_lease.h`:

```text
comments
documentation-only contract text
opaque forward declarations
enum names only if not consumed by scheduler control flow
compile-time constants only if not used by hot-path code
```

Allowed in `kernel/sched/exec_lease.c`:

```text
comments
private unused type declarations
private unused static inline helpers that are not called
private constants not referenced from hot paths
documentation-only contract text
```

The future patch may not add runtime state transitions. It may only make later
P5A0.P2/P5A-R/P5A-M reviews less ambiguous.

The future patch must be evaluated as the `0008` delta, not as the entire
existing `capsched-linux-l0` queue. The already existing queue touches
scheduler, lifecycle, Kconfig, and Makefile paths; that historical footprint
does not license new P5A0.P1 footprint.

## Forbidden Diff Classes

P5A0.P1 must not change:

```text
struct sched_exec_task layout
task_struct layout
rq layout
sched_entity layout
cfs_rq layout
Kconfig defaults
Makefile object inclusion
scheduler callsites
scheduler helper call order
static inline helper bodies used by scheduler hot paths
validation helper return values
validation result consumption
lifecycle helper body changes
runtime constructor or global runtime state additions
external layout exposure
non-static symbols
```

P5A0.P1 must not add:

```text
runtime denial
non-ALLOW reachable result
retry loop
fail-closed path
quarantine state
denied receipt
runtime status publication
allocation
sleeping or blocking call
new lock or refcount transfer
static key
tracepoint
printk
syscall/ioctl/sysfs/procfs/debugfs ABI
exported symbol
monitor call
monitor ABI
```

The following lifecycle helpers are frozen for P5A0.P1 except comments:

```text
sched_exec_task_reset()
sched_exec_task_prepare_fork()
sched_exec_task_commit_exec()
sched_exec_task_exit()
```

Changing their statements, state transitions, call graph, lock/refcount effects,
or externally visible results is not P5A0.P1.

## Hot-Path Rule

The header is dangerous because current scheduler hot paths call static inline
helpers from it. P5A0.P1 therefore treats the following as frozen unless a new
scope gate is opened:

```text
sched_exec_lease_prepare_wake()
sched_exec_lease_prepare_new_task()
sched_exec_lease_note_queued_move()
sched_exec_lease_observe_tick()
sched_exec_lease_note_switch()
sched_exec_lease_validate_run_edge()
sched_exec_lease_validate_move_edge()
sched_exec_lease_validate_move_edge_locked()
```

Changing comments around them is allowed. Changing statements, return values,
called functions, branches, or observable side effects is not P5A0.P1.

## Patch Queue Plan

If later written, the patch queue entry should be:

```text
patches/capsched-linux-l0/0008-...
```

P5A0.P1 plan does not create that patch.

Before any P5A0.P1 patch acceptance:

```text
per-0008 delta footprint manifest
patch queue replay from recorded base
disposable replay against exact current upstream commit
upstream merge-tree check against current upstream
checkpatch
source checker
CONFIG_SCHED_EXEC_LEASE=n full vmlinux build
CONFIG_SCHED_EXEC_LEASE=y full vmlinux build
QEMU denial-disabled boot/workload smoke
object/symbol/disassembly review
exec_lease.o section-size review
hot scheduler function growth review
task_struct/rq/sched_entity/cfs_rq layout review
overclaim/security review
```

The acceptance record must include exact base/upstream/work metadata: recorded
base commit, parent work commit, future work commit, future `0008` patch file,
patch hash, series hash, `linux-patches` commit, exact upstream ref/commit,
drift run id, merge-tree result, and replay log path.

## Required Source Checker

The checker for a future P5A0.P1 patch must fail if:

- any file outside the allowlist changes;
- any forbidden scheduler/lifecycle/Kconfig/Makefile file changes;
- the `0008` delta footprint is missing or is inferred from the whole queue;
- `struct sched_exec_task` changes size or fields;
- any hot-path static inline helper body changes semantically;
- any lifecycle helper body changes semantically;
- any validation helper returns non-ALLOW;
- scheduler branches on validation result;
- any new exported symbol or public ABI appears;
- `kernel/sched/exec_lease.c` adds a non-static symbol not already present;
- any allocation, sleep, lock transfer, refcount transfer, tracepoint, printk,
  static key, or monitor call appears;
- any object-size, section-size, relocation, or hot scheduler function-growth
  evidence is missing;
- patch queue replay or source-drift basis is stale.

## Claim Ledger Row

Allowed claim:

```text
P5A0.P1 patch plan recorded
```

Forbidden claims:

```text
P5A0.P1 Linux patch approved
behavior change
runtime denial
runtime coverage
monitor verification
production protection
hypervisor-grade isolation
cost efficiency
deployment readiness
datacenter readiness
global all-angles freshness
```

## Decision

P5A0.P1 patch planning may proceed under this narrow scope. The actual Linux
patch remains unapproved.

P5A0.P2 move-status plumbing is not part of P5A0.P1. P5A-R CFS denial and
P5A-M broad move denial remain blocked by the already recorded picker and
caller-settlement gaps.

## Non-Claims

This note does not approve Linux code, behavior changes, runtime denial,
retry, fail-closed behavior, quarantine, public ABI, tracepoint ABI, monitor
calls, monitor verification, runtime coverage, production protection,
hypervisor-grade isolation, cost-efficiency, deployment readiness, datacenter
readiness, or global all-angles freshness.
