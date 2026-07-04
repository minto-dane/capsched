# Analysis 0144: SchedExecLease P5A-R 0009 Negative Runtime Harness

Date: 2026-07-04

Status: design record. No Linux patch is approved by this note.

## Purpose

Validation/0176 closed only denial-disabled QEMU compatibility for Linux patch
`0009`. The next blocker is negative ordinary-CFS denial validation.

The current `0009` patch intentionally has no enable site for
`sched_exec_cfs_candidate_key`, so the denial path is dormant in normal
builds. Negative runtime tests therefore need a separate test-only harness.

## Required Boundary

The harness must not become production policy:

```text
no default enablement
no public syscall ABI
no public tracepoint ABI
no debugfs/sysctl/proc control surface
no monitor call
no LSM/cgroup/namespace policy hook
no persistent hot denial fields in task_struct, sched_entity, rq, or cfs_rq
no claim that synthetic denial is real capability semantics
```

The acceptable shape is a build-time test config:

```text
CONFIG_SCHED_EXEC_LEASE_CFS_DENY_TEST
```

with all test behavior compiled out unless the config is enabled.

## Synthetic Denial Subject

The safest first negative harness is not a policy API. It is a synthetic
test predicate:

```text
task->comm starts with "seldeny"
```

When the test config is enabled, `fair.c` may enable the existing candidate
static key at init time and make `sched_exec_cfs_validate_candidate()` return
`SCHED_EXEC_VALIDATION_INELIGIBLE` for the synthetic denied task name.

This deliberately validates only picker mechanics:

```text
denied candidate is recorded
same identity is not repicked in the same attempt
allowed ordinary-CFS sibling can still run
idle is not selected while an allowed ordinary-CFS candidate exists
```

It does not validate:

```text
ExecutionGrant semantics
Domain epoch semantics
grant epoch semantics
monitor-backed budget enforcement
capability issuance
production protection
```

## QEMU Workload Shape

The workload should run as root inside the existing initramfs test environment.
It should create two ordinary CFS processes pinned to the same CPU:

```text
seldenyA:
  synthetic denied task

selallowB:
  allowed sibling task
```

Sequence:

```text
1. Parent creates both children.
2. Each child sets PR_SET_NAME to its role and blocks on a start pipe.
3. Parent waits for both ready signals.
4. Parent clears tracefs and writes a start marker.
5. Parent releases both children.
6. Allowed child performs bounded CPU work and exits.
7. Parent kills denied child if it is still alive.
8. Parent exits success only if allowed child completed.
```

The QEMU shell should inspect tracefs after the workload:

```text
next_comm=selallowB must be observed
next_comm=seldenyA should not be observed after the start marker
WORKLOAD_RET must be 0
```

If trace slicing after the marker is too fragile in busybox, the workload may
clear trace immediately before releasing the children and then use whole-trace
counts.

## Limitations

This harness can close only the first runtime-mechanical subset of
validation/0168:

```text
ND-P5AR-002 denied reaches execution
ND-P5AR-003 same candidate repick
ND-P5AR-005 idle fallback with allowed candidate
```

It does not yet close:

```text
ND-P5AR-006 all EEVDF return families
ND-P5AR-007 parent over-denial
ND-P5AR-008 child exhaustion alias
ND-P5AR-009 cross-path settlement beyond ordinary-CFS predicate
ND-P5AR-010 stale identity semantics
ND-P5AR-011 wakeup/preempt bleed
ND-P5AR-012 newidle/lock-drop leak
ND-P5AR-013 overhead/layout final acceptance
ND-P5AR-014 claim overreach final review
```

## Next

Draft a separate test-only Linux patch after `0009`, provisionally `0010`, and
validate it as a harness overlay. The production claim for `0009` must remain
unaccepted until the negative evidence and later security/overclaim gates are
complete.
