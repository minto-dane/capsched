# SchedExecLease P4 Allow-Only Validation Skeleton Implementation

Date: 2026-07-02

Status: applied to Linux; validation in progress.

## Linux Commit

```text
commit: a937c67f51d1b82297c4f8b7c471f63e8f1a4fe8
subject: sched/exec_lease: Add allow-only validation skeleton
branch: capsched-linux-l0
```

## Patch Scope

Touched files:

```text
include/linux/sched_exec_lease.h
kernel/sched/core.c
kernel/sched/exec_lease.c
kernel/sched/sched.h
```

The patch adds a P4 validation result type and three allow-only helper entry
points:

```text
sched_exec_lease_validate_run_edge(prev, next)
sched_exec_lease_validate_move_edge(p, dest_cpu)
sched_exec_lease_validate_move_edge_locked(p, dest_cpu)
```

Each helper is `static inline` and returns only:

```text
SCHED_EXEC_VALIDATION_ALLOW
```

## Call Sites

The call sites are deliberately before the corresponding irreversible scheduler
mutation for P4's no-denial scope:

```text
__schedule():
  after rq->last_seen_need_resched_ns = 0
  before is_switch = prev != next
  before rq->curr publication

move_queued_task():
  before deactivate_task()
  before set_task_cpu()

move_queued_task_locked():
  before deactivate_task()
  before set_task_cpu()
```

## Non-Claims

This patch does not:

- deny execution;
- retry selection;
- mark tasks ineligible;
- quarantine tasks;
- charge budget;
- allocate;
- sleep;
- take locks;
- call a monitor;
- call a policy front end;
- add ABI, tracepoint ABI, debugfs, procfs, sysfs, syscall, or ioctl surface;
- prove runtime coverage;
- prove protection;
- approve P5 denial.

## Next Validation

Validation must record:

1. patch queue replay to the exact Linux work commit;
2. checkpatch result for patch queue `0007`;
3. source checker result for helper return set, callsite count, and no
   scheduler branching on validation results;
4. targeted `CONFIG_SCHED_EXEC_LEASE=off/on` scheduler build result;
5. object/symbol review for no emitted validation helper symbols;
6. explicit non-claims for protection, runtime denial, runtime coverage,
   monitor verification, cost-efficiency, and deployment readiness.
