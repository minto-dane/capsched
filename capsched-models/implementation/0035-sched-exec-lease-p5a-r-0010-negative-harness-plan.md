# Implementation 0035: SchedExecLease P5A-R 0010 Negative Harness Plan

Date: 2026-07-04

Status: plan only. Linux code is not modified by this record.

## Purpose

Create a test-only harness overlay after Linux patch `0009` so the dormant
ordinary-CFS denial path can be exercised in QEMU without adding production
policy, ABI, monitor calls, or protection claims.

## Planned Patch

```text
patch_slot=0010
name=sched/fair: Add test-only CFS exec lease denial harness
base_linux_commit=7a402107fd63faf7063c2dea05e88e7f8a23f4bf
```

Allowed files:

```text
init/Kconfig
kernel/sched/fair.c
```

Allowed validation files:

```text
capsched/capsched-models/validation/workloads/
capsched/capsched-models/validation/run-sched-exec-lease-*-negative*.sh
```

## Linux Patch Shape

Add:

```text
CONFIG_SCHED_EXEC_LEASE_CFS_DENY_TEST
```

Properties:

```text
depends on CONFIG_SCHED_EXEC_LEASE
depends on DEBUG_KERNEL / EXPERT style test context
default n
compiled out unless explicitly enabled
```

Under that config only:

```text
static_branch_enable(&sched_exec_cfs_candidate_key)
deny task->comm prefix "seldeny" in sched_exec_cfs_validate_candidate()
```

The patch must not add:

```text
syscall ABI
tracepoint ABI
debugfs/sysctl/proc control
monitor call
LSM/cgroup interface
persistent denial fields
allocator or sleeping operation in picker
```

## QEMU Validation Shape

Add a workload that creates:

```text
seldenyA:
  synthetic denied ordinary-CFS child

selallowB:
  allowed ordinary-CFS sibling child
```

The workload resets tracefs after both children are ready, releases both
children, waits for `selallowB` to complete bounded CPU work, then terminates
`seldenyA`.

The QEMU runner should require:

```text
CONFIG_SCHED_EXEC_LEASE=y
CONFIG_SCHED_EXEC_LEASE_CFS_DENY_TEST=y
WORKLOAD_RET=0
next_comm=selallowB observed
next_comm=seldenyA not observed after trace reset/start
```

## Claim Boundary

If this passes, the project may claim:

```text
test-only synthetic denial exercises the 0009 ordinary-CFS deny-and-repick path
```

It may not claim:

```text
0009 accepted
production runtime denial correctness
capability semantics
monitor enforcement
runtime coverage beyond the observed synthetic path
protection
cost efficiency
datacenter readiness
```

## Next

Draft Linux patch `0010` and the QEMU negative workload/runner. Any long
build or QEMU run should be handed to systemd and recorded before chat
monitoring stops.
