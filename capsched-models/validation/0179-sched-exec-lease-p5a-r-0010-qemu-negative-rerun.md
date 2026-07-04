# Validation 0179: SchedExecLease P5A-R 0010 QEMU Negative Rerun

Date: 2026-07-04

Status: failed due to validation workload release ordering. This is not a
verdict on the intended allowed-sibling deny-and-repick property.

## Scope

Rerun the QEMU negative runtime validation after validation/0178 made
`trace_marker` optional.

```text
unit=capsched-p5a-r-0010-negative-qemu-rerun-20260704T045417Z.service
log=/media/nia/scsiusb/dev/linux-cap/build/logs/sched-exec-lease-p5a-r-0010-negative-qemu-rerun-20260704T045417Z.log
run_dir=build/qemu/sched-exec-lease-p5a-r-0010-negative/20260704T045417Z-on
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

The trace-marker issue was bypassed:

```text
NEGATIVE_TRACE_MARKER_SKIPPED errno=9
NEGATIVE_CHILDREN_READY denied_pid=71 allowed_pid=72 tracefs=/sys/kernel/tracing
```

The run then timed out:

```text
qemu_status=124
qemu_timeout_seconds=240
```

No `NEGATIVE_CHILDREN_RELEASED`, `NEGATIVE_ALLOWED_STARTED`,
`NEGATIVE_ALLOWED_DONE`, or `NEGATIVE_RESULT` marker appeared.

Hashes:

```text
log_sha256=34997b48640a4dc47a9ae94896600d34dae524b8b06c96f3750874938cbb2a6f
serial_sha256=f83e96f833f6bdc75c1b85950657ac1ec7659fd6fcfdc77928d1776659866342
summary_sha256=ed7152c00eb7eb3d68f26fc48490aec9cfc8344d320467950d5d5e87e738a4b1
counts_sha256=e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
```

## Diagnosis

The workload released the denied child, then yielded/slept, then released the
allowed sibling. That created the wrong test condition:

```text
denied child runnable
allowed child still blocked
parent may become not eligible after yielding
```

This can timeout before measuring the intended property, which is:

```text
denied child runnable
allowed sibling runnable
denied is not selected
allowed is selected
```

## Fix

The workload now releases both children before yielding:

```text
write denied_start
write allowed_start
print NEGATIVE_CHILDREN_RELEASED
sched_yield()
```

Updated workload hash:

```text
negative_workload_sha256=9739a225d7022dfed37359094d5e9247e172a16b8320a95dbcbe5e7babd4cb0b
```

## Non-Claims

This failed rerun does not prove:

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
