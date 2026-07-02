# Validation 0130: SchedExecLease Full vmlinux Build

Status: Passed for full `vmlinux` build in disabled and enabled
SchedExecLease configurations; no behavior or protection claim

Date: 2026-07-02

## Purpose

N-159 strengthens the implementation-readiness gate from targeted
scheduler-subtree build evidence to full Linux `vmlinux` build evidence.

This validation checks that the inert SchedExecLease scaffold is compatible
with a broad x86_64 build when disabled and when enabled.

## Command

The full build was run through a systemd user unit:

```sh
systemd-run --user \
  --unit=capsched-n159-full-build-20260702T0310Z \
  --collect \
  --same-dir \
  env JOBS=8 BUILD_TAG=n159-current \
  bash capsched/capsched-models/validation/run-sched-exec-lease-full-build-validation.sh
```

Runner:

```text
capsched/capsched-models/validation/run-sched-exec-lease-full-build-validation.sh
```

Log:

```text
/media/nia/scsiusb/dev/linux-cap/build/logs/sched-exec-lease-full-build-20260702T030457Z.log
```

## Source State

```text
linux_commit=3bb2a5821ffdcc0fa6d451cbf259ef82a9ea9a9c
linux_subject=sched/exec_lease: Rename inert scheduler lease scaffold
```

## Build Outputs

Disabled configuration:

```text
build_dir=/media/nia/scsiusb/dev/linux-cap/build/linux-l0-sched-exec-lease-off-n159-current-x86_64
CONFIG_SCHED_EXEC_LEASE=undef
vmlinux=/media/nia/scsiusb/dev/linux-cap/build/linux-l0-sched-exec-lease-off-n159-current-x86_64/vmlinux
kernel/sched/exec_lease.o=absent
```

Enabled configuration:

```text
build_dir=/media/nia/scsiusb/dev/linux-cap/build/linux-l0-sched-exec-lease-on-n159-current-x86_64
CONFIG_SCHED_EXEC_LEASE=y
vmlinux=/media/nia/scsiusb/dev/linux-cap/build/linux-l0-sched-exec-lease-on-n159-current-x86_64/vmlinux
kernel/sched/exec_lease.o=present
```

The log contains both completion markers:

```text
[2026-07-01T23:07:13-04:00] completed CONFIG_SCHED_EXEC_LEASE=off vmlinux
[2026-07-01T23:19:15-04:00] completed CONFIG_SCHED_EXEC_LEASE=on vmlinux
[2026-07-01T23:19:15-04:00] SchedExecLease full vmlinux build validation completed
```

## Interpretation

This passes the full-build part of `L0-RDY-014`.

The result is stronger than validation 0128 because it verifies full
`vmlinux` linkage for both disabled and enabled configurations rather than
only the scheduler subtree.

## Remaining Gates

The following remain required before any behavior-changing runtime enforcement
patch is accepted:

```text
QEMU boot smoke off/on validation
hook coverage observation for first runtime attachment points
negative denial tests once denial behavior exists
```

## Non-Claims

This validation is not runtime coverage, scheduler enforcement, denial
correctness, ABI approval, monitor verification, production protection, or
cost-efficiency evidence.
