# Validation 0132: SchedExecLease P1 Full Build

Status: Passed for patch queue replay and full `vmlinux` build in disabled and
enabled SchedExecLease configurations; no behavior or protection claim

Date: 2026-07-02

## Purpose

Validate the first P1 no-behavior Linux implementation patch:

```text
sched/exec_lease: Add private no-behavior object vocabulary
```

This validation proves only that the patch queue reproduces the new Linux
commit and that the resulting kernel builds in both disabled and enabled
SchedExecLease configurations.

## Source State

```text
linux_branch=capsched-linux-l0
linux_commit=95b8c509043d755ad77801315beec94c09059777
linux_subject=sched/exec_lease: Add private no-behavior object vocabulary
```

Changed Linux source:

```text
kernel/sched/exec_lease.c
```

No `task_struct`, runqueue, scheduler hook, lifecycle hook, ABI, tracepoint,
exported symbol, or monitor-call path was added.

## Patch Queue Replay

Command:

```sh
DOMAINLEASE_RECREATE_FETCH=0 \
  ./linux-patches/scripts/recreate-capsched-linux-l0.sh ./linux
```

Result:

```text
applying 0001-sched-capsched-Add-inert-scaffolding.patch
applying 0002-sched-capsched-Add-type-only-authority-scaffolding.patch
applying 0003-sched-exec-lease-Rename-inert-scheduler-lease-scaffold.patch
applying 0004-sched-exec-lease-Add-private-no-behavior-object-vocabulary.patch
final HEAD: 95b8c509043d755ad77801315beec94c09059777
```

## Full Build Command

```sh
BUILD_TAG=p1-n162-current JOBS=8 \
  capsched/capsched-models/validation/run-sched-exec-lease-full-build-validation.sh
```

Runner:

```text
capsched/capsched-models/validation/run-sched-exec-lease-full-build-validation.sh
```

Log:

```text
/media/nia/scsiusb/dev/linux-cap/build/logs/sched-exec-lease-full-build-20260702T035916Z.log
```

## Build Outputs

Disabled configuration:

```text
build_dir=/media/nia/scsiusb/dev/linux-cap/build/linux-l0-sched-exec-lease-off-p1-n162-current-x86_64
CONFIG_SCHED_EXEC_LEASE=undef
vmlinux=/media/nia/scsiusb/dev/linux-cap/build/linux-l0-sched-exec-lease-off-p1-n162-current-x86_64/vmlinux
kernel/sched/exec_lease.o=absent
```

Enabled configuration:

```text
build_dir=/media/nia/scsiusb/dev/linux-cap/build/linux-l0-sched-exec-lease-on-p1-n162-current-x86_64
CONFIG_SCHED_EXEC_LEASE=y
vmlinux=/media/nia/scsiusb/dev/linux-cap/build/linux-l0-sched-exec-lease-on-p1-n162-current-x86_64/vmlinux
kernel/sched/exec_lease.o=present
```

The log contains both completion markers:

```text
[2026-07-02T00:09:26-04:00] completed CONFIG_SCHED_EXEC_LEASE=off vmlinux
[2026-07-02T00:19:23-04:00] completed CONFIG_SCHED_EXEC_LEASE=on vmlinux
[2026-07-02T00:19:23-04:00] SchedExecLease full vmlinux build validation completed
```

## Interpretation

This validates the P1 no-behavior implementation at build and replay level:

```text
CONFIG_SCHED_EXEC_LEASE=n still compiles out exec_lease.o
CONFIG_SCHED_EXEC_LEASE=y builds and links exec_lease.o
the private vocabulary compiles without warnings in the observed build
the patch queue can recreate the Linux work commit
```

QEMU boot smoke was not rerun for this N because P1 adds no runtime caller,
hook, task layout, scheduler path, lifecycle path, or user-visible behavior.
Fresh QEMU validation is required before accepting any later patch that adds
runtime call sites.

## Remaining Gates

This validation does not approve P2/P3/P4 behavior. The next implementation
stage must still satisfy the lifecycle and hook-placement gates documented in
implementation/0018 and implementation/0019.

Behavior-changing runtime enforcement remains blocked by:

```text
hook coverage
sched_ext support/disable/fail-closed decision
core cached-pick revalidation or invalidation
proxy execution donor/current/executor accounting
workqueue/kthread classification
bounded retry/ineligibility behavior
negative denial tests
claim ledger overclaim guard
```

## Non-Claims

This validation is not runtime coverage, scheduler enforcement, denial
correctness, ABI approval, monitor ABI approval, monitor implementation,
monitor verification, exploit-containment evidence, hypervisor-grade isolation,
production protection, cost-efficiency evidence, or datacenter deployment
readiness.
