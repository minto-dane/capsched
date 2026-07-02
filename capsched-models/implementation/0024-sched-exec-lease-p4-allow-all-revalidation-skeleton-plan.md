# Implementation 0024: SchedExecLease P4 Allow-All Revalidation Skeleton Plan

Status: Draft P4 patch plan; implementation not applied; pre-entry validation
passed for allow-all/no-denial scope in validation/0141; P5 denial remains
blocked by analysis/0115 and analysis/0117 constraints

Date: 2026-07-02

## Purpose

P4 is the first planned slice that may wire explicit SchedExecLease
revalidation helper calls into final run and queued move edges. It is still
strictly no-denial and allow-all.

The purpose is to create a future-proof control-flow skeleton without making
Linux behavior depend on SchedExecLease policy. P4 must prove only that the
future validation edges can be represented in source and build/run
compatibility; it must not claim runtime protection.

## Current Source Basis

```text
linux_branch=capsched-linux-l0
linux_commit=d5f77adb5a64f3b2545db6ab1dcdc4aa4442bab3
linux_subject=sched/exec_lease: Add placement-only scheduler touchpoints
```

P4 prerequisites:

```text
P2 full build/layout/QEMU validation recorded
P3 placement-only touchpoint patch implemented and validated
P4 pre-entry risk/validation gate recorded in analysis/0122 and validation/0141
analysis/0100 final run/move gate remains applicable to current source
analysis/0101 final deny retry/ineligibility gate remains applicable to current source
analysis/0114 sched_ext/core/proxy coverage classification is consciously scoped
analysis/0115 blocks upgrading the P4 allow-all final edge into P5 denial
analysis/0117 path classification remains binding for any later P5 scope
```

## Allowed Patch Surface

P4 may touch only:

```text
include/linux/sched_exec_lease.h
kernel/sched/core.c
kernel/sched/sched.h
kernel/sched/exec_lease.c
```

If fair load-balance direct movement must be represented in P4, a separate
plan amendment is required before touching:

```text
kernel/sched/fair.c
```

P4 must not touch fork, exec, exit, workqueue, io_uring, LSM, cgroup,
namespace, MM, device, IOMMU, tracepoint, debugfs, procfs, sysfs, syscall, or
ioctl surfaces.

## Allowed Result Shape

P4 may introduce an internal validation result type if all non-allow results
are unreachable in production code:

```c
enum sched_exec_validation_result {
        SCHED_EXEC_VALIDATION_ALLOW,
        SCHED_EXEC_VALIDATION_RETRY,
        SCHED_EXEC_VALIDATION_INELIGIBLE,
        SCHED_EXEC_VALIDATION_QUARANTINE,
};
```

P4 production helpers must always return:

```text
SCHED_EXEC_VALIDATION_ALLOW
```

Any non-allow value must be limited to model text, comments, build-only static
assertions, or later P5 test-only code after explicit approval.

analysis/0115 adds an important constraint: the P4 conceptual final run hook is
not automatically a safe P5 denial hook. In current Linux, `pick_next_task()`
often returns after `put_prev_set_next_task()` has already settled
class-specific state. P4 may still observe and shape an allow-all final edge,
but P5 denial must use pre-settle validation or a source-proved rollback
mechanism.

## Required Edge Separation

P4 must keep these validation concepts separate:

```text
run edge:
  selected task, donor task, rq, CPU, task generation, domain epoch,
  future grant epoch, future budget context epoch, core sequence, sched_ext
  custody sequence, proxy relation, and current fresh CPU envelope.

move edge:
  task, source rq, destination rq, destination CPU, task generation, domain
  epoch, future grant epoch, future budget context epoch, move sequence,
  migration state, and fresh CPU envelope.
```

A move validation result must not authorize a run. A run validation result must
not authorize a queued move.

## Candidate P4 Hooks

### Final Run Revalidation

Current source:

```text
kernel/sched/core.c
function: __schedule()
anchor: keep_resched join, before is_switch and before
        RCU_INIT_POINTER(rq->curr, next)
```

P4 may call an allow-all helper here:

```text
sched_exec_lease_validate_run_edge(rq, prev, next, rq->donor)
```

Required constraints:

```text
must be before rq->curr publication
must be after ordinary pick and proxy resolution
must not deny or retry in P4
must not clear resched state differently
must not alter scheduler class state
must not bypass core cached-pick freshness requirements in future P5
```

### Common Queued Move Revalidation

Current source:

```text
kernel/sched/core.c
function: move_queued_task()
anchor: before deactivate_task(rq, p, DEQUEUE_NOCLOCK)
```

P4 may call an allow-all helper here:

```text
sched_exec_lease_validate_move_edge(rq, NULL, p, new_cpu)
```

Required constraints:

```text
must be before deactivate_task()
must be before set_task_cpu()
must not fail or reroute in P4
must not treat move_queued_task() itself as authority
```

### Double-RQ Queued Move Revalidation

Current source:

```text
kernel/sched/sched.h
function: move_queued_task_locked()
anchor: before deactivate_task(src_rq, task, 0)
```

P4 may call an allow-all helper here:

```text
sched_exec_lease_validate_move_edge_locked(src_rq, dst_rq, task)
```

Required constraints:

```text
must be before source detach
must not fail or reroute in P4
must not assume the common move helper covers this locked path
```

## Denial Is Still Forbidden

P4 must not implement:

```text
denial receipts
ineligibility marks
retry epochs
retry budgets
quarantine queues
fail-closed CPU idling
class-state rollback
balance-callback neutralization
idle fallback
sched_ext fallback control
core cached-pick invalidation
monitor activation or monitor receipts
```

Those belong to P5 or later and require a separate implementation plan derived
from analysis/0101 and validation/0118.

## Compatibility Constraints

P4 must preserve:

```text
CONFIG_SCHED_EXEC_LEASE=n behavior
CONFIG_SCHED_EXEC_LEASE=y behavior
CFS/RT/deadline/idle/sched_ext/proxy/core scheduling semantics
fork/exec/exit behavior already touched by P2
task migration and hotplug behavior
no user-visible ABI
no public tracepoint ABI
no exported symbols
no monitor ABI
```

If P4 leaves out a known movement path, such as a fair direct detach path or a
sched_ext custody path, it must record that omission explicitly and must not
claim runtime coverage.

## Required Validation

Before accepting P4:

```text
P2 validation complete
P3 validation complete
git diff --check
patch queue replay
CONFIG_SCHED_EXEC_LEASE=off full vmlinux build
CONFIG_SCHED_EXEC_LEASE=on full vmlinux build
QEMU boot/workload smoke off/on
trace/kprobe evidence that final run and move anchors remain observable where
  possible
object or generated-code review for disabled no-op behavior
claim ledger non-overclaim review
```

If `CONFIG_SCHED_EXEC_LEASE=y` introduces measurable hot-path overhead, that
must be recorded as compatibility/performance evidence only, not as protection
evidence.

## Non-Claims

This plan is not implementation, runtime denial approval, negative denial
evidence, retry approval, fail-closed approval, user ABI approval, public
tracepoint ABI approval, monitor ABI approval, monitor implementation, monitor
verification, exploit containment, hypervisor-grade isolation, production
protection, cost-efficiency evidence, or datacenter deployment readiness.
