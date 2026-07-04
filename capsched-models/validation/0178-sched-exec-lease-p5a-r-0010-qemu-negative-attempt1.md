# Validation 0178: SchedExecLease P5A-R 0010 QEMU Negative Attempt 1

Date: 2026-07-04

Status: failed due to validation harness trace reset issue. This is not a
pass/fail result for the Linux deny-and-repick path.

## Scope

Run the first QEMU negative runtime validation for the test-only `0010`
ordinary-CFS denial harness.

```text
unit=capsched-p5a-r-0010-negative-qemu-20260704T043512Z.service
log=/media/nia/scsiusb/dev/linux-cap/build/logs/sched-exec-lease-p5a-r-0010-negative-qemu-20260704T043512Z.log
run_dir=build/qemu/sched-exec-lease-p5a-r-0010-negative/20260704T043512Z-on
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

The run then failed inside the guest validation workload:

```text
tracefs reset: Bad file descriptor
qemu_status=124
qemu_timeout_seconds=240
```

Hashes:

```text
log_sha256=73d63c972deba0c1fab94771a98a891861fe4c7047786833f27767d65c1ed0a4
serial_sha256=f19c83503539afd27e05dd8282b3221551b6fad2c71ec44026b572653583f2c4
summary_sha256=50b228cfbfb68593da05b93336df85a5fe45e1e99596133dc14ddc51aa2c6bf4
counts_sha256=e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
```

## Diagnosis

The workload made `trace_marker` part of the required trace reset sequence.
That was too strict. The validation decision only needs:

```text
1. disable tracing
2. clear trace
3. enable tracing
4. count sched_switch next_comm entries after the clear
```

`trace_marker` is useful as a human-readable marker, but it is not required for
the machine verdict because the workload clears trace immediately before
releasing the children.

## Fix

The workload was updated so `trace_marker` failure emits:

```text
NEGATIVE_TRACE_MARKER_SKIPPED errno=<n>
```

and does not fail the run. Required reset failures still fail the workload.

Updated workload hash:

```text
negative_workload_sha256=90e58321cb1204844fed6400993d88179f9ed39dbac9517202eff009d8f3d0b6
```

## Non-Claims

This failed attempt does not prove:

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
