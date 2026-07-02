# Implementation 0015: Mainline Naming and Scope Review

Status: Accepted and targeted-build validated; no behavior-changing Linux patch
approved

Date: 2026-07-02

## Purpose

This review converts the private modeling vocabulary into mainline-facing
Linux vocabulary before any behavior-changing scheduler patch is proposed.

The first Linux-facing mechanism is not "a capability scheduler". It is a
small scheduler execution-lease scaffold:

```text
CONFIG_SCHED_EXEC_LEASE
include/linux/sched_exec_lease.h
kernel/sched/exec_lease.c
```

## Mainline-Facing Scope

The first upstream-discussable problem is:

```text
Can scheduler execution authority be represented as an explicit, frozen,
bounded execution lease without changing current Linux behavior?
```

Out of scope for the first Linux-facing slice:

```text
endpoint authority
io_uring/workqueue authority carriers
QueueLease and device queue enforcement
MemoryView implementation
Domain Monitor implementation
public user ABI
public tracepoint ABI
monitor ABI
production protection claims
```

## Name Decisions

| Private/model term | Linux-facing term | Rationale |
| --- | --- | --- |
| `CONFIG_CAPSCHED` | `CONFIG_SCHED_EXEC_LEASE` | Avoid confusion with Linux capabilities |
| `capsched_enabled()` | `sched_exec_lease_enabled()` | Mechanism name, not project name |
| `capsched_domain` | `sched_exec_domain` | Avoid unqualified `Domain`; avoid `sched_domain` collision |
| `capsched_run_cap` | `sched_exec_grant` | Avoid `Cap` in Linux code |
| `capsched_frozen_run_use` | `sched_exec_lease` | Main mechanism name |
| `capsched_sched_ctx` | `sched_budget_ctx` | CPU budget context, not generic scheduler context |
| `capsched_run_token` | `sched_sealed_exec_token` | Monitor-issued token, not Linux authority |

## No-ABI Rule

Until a concrete in-tree consumer and rollback/removal story exist:

```text
no user ABI
no public tracepoint ABI
no monitor ABI
no exported symbol
no behavior change
```

## Linux Patch Rule

The N-156 Linux patch is allowed to rename the existing inert scaffold only.
It may not add:

```text
task_struct fields
scheduler hook calls
enqueue/pick/switch/tick behavior
fork/exec/exit behavior
workqueue or io_uring behavior
syscalls, prctl, debugfs, procfs, sysfs, or tracepoints
security claims
```

## Validation

The Linux scaffold rename is validated by:

```text
validation/0128-sched-exec-lease-rename-build-validation.md
```

That validation checks:

```text
CONFIG_SCHED_EXEC_LEASE disabled state
CONFIG_SCHED_EXEC_LEASE enabled state
kernel/sched/built-in.a build in both states
exec_lease.o absent when disabled
exec_lease.o present when enabled
old Linux scaffold terms absent from the renamed source surface
```

## Follow-Up Gates

After the rename, the next implementation gate should be an execution-only
vertical slice review:

```text
wake publication classification
pick/core-scheduling validation classification
tick donor/current budget subject classification
context-switch activation classification
fork/exec/exit identity preparation classification
runtime trace coverage plan
```

This review is not Linux implementation approval, runtime coverage, monitor
verification, ABI approval, or production protection evidence.
