# Validation 0133: SchedExecLease P2 Full Build and Task Layout

Status: Passed for patch queue replay evidence, full `vmlinux` build in
disabled and enabled SchedExecLease configurations, and build-only
`task_struct` layout probe; QEMU runtime smoke is tracked separately in
validation/0134

Date: 2026-07-02

## Purpose

Validate the P2 no-denial lifecycle shadow Linux implementation patch:

```text
sched/exec_lease: Add task identity shadow
```

P2 touches `task_struct`, fork, exec, and exit lifecycle code. This validation
therefore proves more than targeted object compilation: the patched tree builds
as a full kernel with SchedExecLease disabled and enabled, and the enabled
configuration contains the intended CONFIG-gated task-local shadow.

This remains compatibility and build/layout evidence only. It is not runtime
enforcement, scheduler hook coverage, denial evidence, monitor verification, or
protection evidence.

## Source State

```text
linux_branch=capsched-linux-l0
linux_commit=a0f2676adda634391983e74f29fcba577a9c919e
linux_subject=sched/exec_lease: Add task identity shadow
```

Changed Linux source:

```text
include/linux/sched.h
include/linux/sched_exec_lease.h
kernel/fork.c
fs/exec.c
kernel/exit.c
kernel/sched/exec_lease.c
```

## Patch Queue Replay

Earlier P2 replay command:

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
applying 0005-sched-exec-lease-Add-task-identity-shadow.patch
final HEAD: a0f2676adda634391983e74f29fcba577a9c919e
```

The patch queue currently records:

```text
linux-patches/patches/capsched-linux-l0/0005-sched-exec-lease-Add-task-identity-shadow.patch
linux-patches/patches/capsched-linux-l0/series
linux-patches/upstream/base.txt
work_commit=a0f2676adda634391983e74f29fcba577a9c919e
```

## Full Build Command

Systemd user unit:

```text
capsched-p2-full-build-20260702T043624Z.service
```

Command:

```sh
BUILD_TAG=p2-n164-current JOBS=8 \
  bash capsched/capsched-models/validation/run-sched-exec-lease-full-build-validation.sh
```

Log:

```text
/media/nia/scsiusb/dev/linux-cap/build/logs/sched-exec-lease-full-build-20260702T043624Z.log
```

## Build Outputs

Disabled configuration:

```text
build_dir=/media/nia/scsiusb/dev/linux-cap/build/linux-l0-sched-exec-lease-off-p2-n164-current-x86_64
CONFIG_SCHED_EXEC_LEASE=undef
vmlinux=/media/nia/scsiusb/dev/linux-cap/build/linux-l0-sched-exec-lease-off-p2-n164-current-x86_64/vmlinux
kernel/sched/exec_lease.o=absent
```

Enabled configuration:

```text
build_dir=/media/nia/scsiusb/dev/linux-cap/build/linux-l0-sched-exec-lease-on-p2-n164-current-x86_64
CONFIG_SCHED_EXEC_LEASE=y
vmlinux=/media/nia/scsiusb/dev/linux-cap/build/linux-l0-sched-exec-lease-on-p2-n164-current-x86_64/vmlinux
kernel/sched/exec_lease.o=present
```

Completion markers:

```text
[2026-07-02T00:45:57-04:00] completed CONFIG_SCHED_EXEC_LEASE=off vmlinux
[2026-07-02T00:55:15-04:00] completed CONFIG_SCHED_EXEC_LEASE=on vmlinux
[2026-07-02T00:55:15-04:00] SchedExecLease full vmlinux build validation completed
```

## Task Layout Probe

Runner:

```text
capsched/capsched-models/validation/run-sched-exec-lease-task-layout-probe.sh
```

Command:

```sh
BUILD_TAG=p2-n164-current \
  bash capsched/capsched-models/validation/run-sched-exec-lease-task-layout-probe.sh
```

Log:

```text
/media/nia/scsiusb/dev/linux-cap/build/logs/sched-exec-lease-task-layout-probe-20260702T045623Z.log
```

Output root:

```text
/media/nia/scsiusb/dev/linux-cap/build/task-layout/sched-exec-lease-p2-n164-current-20260702T045623Z
```

The probe compiles a tiny external object against each prepared build tree and
reads symbol sizes from the object. It does not load a module or run kernel
code.

Disabled symbols:

```text
sched_exec_no_config_probe              0x0000000000000001
sched_exec_task_struct_size_probe       0x0000000000000cc0
```

Enabled symbols:

```text
sched_exec_field_size_probe             0x0000000000000028
sched_exec_field_offset_plus_one_probe  0x0000000000000591
sched_exec_task_struct_size_probe       0x0000000000000d00
```

Interpretation:

```text
CONFIG_SCHED_EXEC_LEASE=off:
  sched_exec field is absent from task_struct.

CONFIG_SCHED_EXEC_LEASE=on:
  sched_exec field is present.
  sizeof(task_struct.sched_exec) is 0x28 bytes.
  offsetof(task_struct, sched_exec) + 1 is 0x591.
  sizeof(struct task_struct) increases from 0xcc0 to 0xd00 in this config.
```

The first post-full chain run attempted to build a full external `.ko` for the
layout probe and failed during module finalization. The probe runner was then
corrected to compile only `sched_exec_layout_probe.o`, which is the only
artifact needed for build-only symbol-size evidence.

## Interpretation

This validates P2 at build and layout level:

```text
CONFIG_SCHED_EXEC_LEASE=n builds a full vmlinux with exec_lease.o absent.
CONFIG_SCHED_EXEC_LEASE=y builds a full vmlinux with exec_lease.o present.
The P2 task-local shadow is compiled out when disabled.
The P2 task-local shadow is present when enabled.
The lifecycle helper declarations and call sites compile in full-kernel builds.
```

P2 still preserves no-denial semantics:

```text
no scheduler enqueue/pick/switch/tick hook
no runtime denial
no budget charging
no policy frontend
no ABI
no exported symbol
no monitor call
no MemoryView/IOMMU/device change
```

## Remaining Validation

P2 still requires QEMU runtime compatibility evidence because it touches
lifecycle code. That is tracked separately:

```text
validation/0134-sched-exec-lease-p2-qemu-boot-smoke.md
```

## Non-Claims

This validation is not runtime enforcement, runtime coverage, hook approval,
negative denial evidence, user ABI approval, public tracepoint ABI approval,
monitor ABI approval, monitor implementation, monitor verification,
exploit-containment evidence, hypervisor-grade isolation, production
protection, cost-efficiency evidence, or datacenter deployment readiness.
