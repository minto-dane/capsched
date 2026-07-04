# Validation 0181: SchedExecLease P5A-R 0010 QEMU Negative Allowed-First Run

Date: 2026-07-04

Status: manually stopped after RCU stall evidence in `pick_eevdf()`. This is a
draft-path failure signal, not an accepted denial-correctness result.

## Scope

Run the QEMU negative runtime validation after validation/0180 changed the
workload to release the allowed child before the denied child.

```text
unit=capsched-p5a-r-0010-negative-qemu-allowedfirst-20260704T051039Z.service
log=/media/nia/scsiusb/dev/linux-cap/build/logs/sched-exec-lease-p5a-r-0010-negative-qemu-allowedfirst-20260704T051039Z.log
run_dir=build/qemu/sched-exec-lease-p5a-r-0010-negative/20260704T051039Z-on
linux_commit=9f2b3996688849eb0ddc13531f735cc4eb16b63d
linux_subject=sched/fair: Add test-only CFS exec lease denial harness
```

## Observed

The guest booted into the intended kernel/config:

```text
CONFIG_SCHED_EXEC_LEASE=y
CONFIG_SCHED_EXEC_LEASE_CFS_DENY_TEST=y
sched_exec_lease: enabled test-only CFS denial harness
```

The workload reached:

```text
NEGATIVE_TRACE_MARKER_SKIPPED errno=9
NEGATIVE_CHILDREN_READY denied_pid=71 allowed_pid=72 tracefs=/sys/kernel/tracing
NEGATIVE_ALLOWED_RELEASED
```

The guest then reported an RCU stall with CPU 0 in the CFS picker path:

```text
rcu: INFO: rcu_preempt detected stalls on CPUs/tasks
RIP: 0010:pick_eevdf+0x16/0x680
__pick_task_fair+0x2dc/0x830
pick_task_fair_sched_exec_lease+0x54/0x80
```

The run was manually stopped rather than waiting for the full timeout.

Hashes:

```text
log_sha256=ec103b9c1e03b7cdb49f6c58f01ef0138b1c1c1e7e7e09ccc230df42b35b71a2
serial_sha256=e56236b8236fcee5e43b26e7d4d616b43ee872f44cf0a11f9cfa824ac6e28fc8
```

No `run-summary.txt` was produced before the manual stop.

## Diagnosis

The workload did establish that the allowed child was released before the
denied child. However, the allowed child still used low priority (`nice 19`),
while the denied child used high priority (`nice -20`). That can create a
runnable-but-not-eligible allowed sibling and therefore is not a clean test of
the intended property.

The RCU stall is still important evidence against accepting the current
`0009/0010` draft path: a denied candidate plus no immediately selectable
allowed candidate can keep the scheduler in the CFS pick path without forward
progress.

## Fix

The workload now gives both children the same high priority:

```text
setpriority(PRIO_PROCESS, 0, -20)
```

Updated workload hash:

```text
negative_workload_sha256=5989c84eefa1ca10600642baf015edad11e848189e517187d80b590913a00934
```

## Non-Claims

This stopped run does not prove:

```text
runtime denial correctness
CFS deny-and-repick correctness
runtime coverage
capability semantics
monitor enforcement
protection
cost efficiency
deployment readiness
datacenter readiness
```
