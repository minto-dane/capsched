# Validation 0180: SchedExecLease P5A-R 0010 QEMU Negative Release-Fix Run

Date: 2026-07-04

Status: manually stopped after reproducing release-order wakeup issue. This is
not a verdict on the intended allowed-sibling deny-and-repick property.

## Scope

Run the QEMU negative runtime validation after validation/0179 changed the
workload to release both children before an explicit yield.

```text
unit=capsched-p5a-r-0010-negative-qemu-releasefix-20260704T050521Z.service
log=/media/nia/scsiusb/dev/linux-cap/build/logs/sched-exec-lease-p5a-r-0010-negative-qemu-releasefix-20260704T050521Z.log
run_dir=build/qemu/sched-exec-lease-p5a-r-0010-negative/20260704T050521Z-on
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
NEGATIVE_CHILDREN_READY denied_pid=72 allowed_pid=73 tracefs=/sys/kernel/tracing
```

It did not reach:

```text
NEGATIVE_CHILDREN_RELEASED
NEGATIVE_ALLOWED_STARTED
NEGATIVE_ALLOWED_DONE
NEGATIVE_RESULT
```

The run was manually stopped rather than waiting for the full timeout because
the log showed the same pre-release stall shape.

Hashes:

```text
log_sha256=91e7431a8816dbc409f7eb4e5d7947ebba0af80356b001f5b34e9a62ecf4ff5a
serial_sha256=4d0edf1f93df3e7e13fa9477413b3eea358b5f8bd3352f0378ff45eb80d71acf
```

No `run-summary.txt` was produced before the manual stop.

## Diagnosis

Releasing both children before an explicit yield was still insufficient
because the workload woke the denied child first:

```text
write denied_start
write allowed_start
```

The denied child is intentionally high priority. Waking it can preempt the
parent before the allowed child's start pipe is written, so the intended
condition is still not established.

## Fix

The workload now releases the allowed child first, then the denied child:

```text
write allowed_start
print NEGATIVE_ALLOWED_RELEASED
write denied_start
print NEGATIVE_CHILDREN_RELEASED
sched_yield()
```

Updated workload hash:

```text
negative_workload_sha256=21e7baafcb56ec5a92d6ee1b1e49b2aa4ad246d71ab420b17851e5825d994739
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
