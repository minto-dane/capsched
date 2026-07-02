# Validation 0140: SchedExecLease P3 Validation

Status: Passed for patch queue replay, `CONFIG_SCHED_EXEC_LEASE=off/on` full
`vmlinux` build, QEMU no-behavior boot/workload smoke, object/symbol note, and
overclaim review; no runtime protection claim is made

Date: 2026-07-02

## Purpose

Validate the P3 placement-only scheduler touchpoint patch:

```text
sched/exec_lease: Add placement-only scheduler touchpoints
```

P3 touches scheduler hot paths, so it needs stronger compatibility evidence
than P1. This validation proves that the patch queue replays, both disabled and
enabled configurations build, and both configurations boot and complete the
existing fork/exec/exit QEMU smoke workload.

This is still no-behavior compatibility evidence. It is not runtime denial,
hook correctness, budget enforcement, monitor verification, exploit
containment, production protection, or cost-efficiency evidence.

## Source State

```text
linux_branch=capsched-linux-l0
linux_commit=d5f77adb5a64f3b2545db6ab1dcdc4aa4442bab3
linux_subject=sched/exec_lease: Add placement-only scheduler touchpoints
```

Changed Linux source:

```text
include/linux/sched_exec_lease.h
kernel/sched/core.c
kernel/sched/sched.h
```

P3 adds only static inline no-op marker helpers and source-level call sites.

## Patch Queue Replay

Command:

```sh
rm -rf build/replay/p3-patch-queue
DOMAINLEASE_RECREATE_FETCH=0 \
DOMAINLEASE_LINUX_REFERENCE=/media/nia/scsiusb/dev/linux-cap/linux \
  ./linux-patches/scripts/recreate-capsched-linux-l0.sh \
  /media/nia/scsiusb/dev/linux-cap/build/replay/p3-patch-queue
```

Result:

```text
applying 0001-sched-capsched-Add-inert-scaffolding.patch
applying 0002-sched-capsched-Add-type-only-authority-scaffolding.patch
applying 0003-sched-exec-lease-Rename-inert-scheduler-lease-scaffold.patch
applying 0004-sched-exec-lease-Add-private-no-behavior-object-vocabulary.patch
applying 0005-sched-exec-lease-Add-task-identity-shadow.patch
applying 0006-sched-exec_lease-Add-placement-only-scheduler-touchp.patch
final HEAD: d5f77adb5a64f3b2545db6ab1dcdc4aa4442bab3
```

Replay tree:

```text
/media/nia/scsiusb/dev/linux-cap/build/replay/p3-patch-queue
```

The replayed HEAD matches the local Linux work commit exactly.

## Full Build

Command:

```sh
BUILD_TAG=p3 JOBS=8 \
  /media/nia/scsiusb/dev/linux-cap/capsched/capsched-models/validation/run-sched-exec-lease-full-build-validation.sh
```

Clear exit-0 log:

```text
/media/nia/scsiusb/dev/linux-cap/build/logs/sched-exec-lease-full-build-20260702T075408Z.log
```

Completion markers:

```text
[2026-07-02T03:54:14-04:00] checking CONFIG_SCHED_EXEC_LEASE=off evidence
undef
[2026-07-02T03:54:29-04:00] completed CONFIG_SCHED_EXEC_LEASE=off vmlinux
[2026-07-02T03:54:35-04:00] checking CONFIG_SCHED_EXEC_LEASE=on evidence
y
[2026-07-02T03:54:51-04:00] completed CONFIG_SCHED_EXEC_LEASE=on vmlinux
[2026-07-02T03:54:51-04:00] SchedExecLease full vmlinux build validation completed
```

Disabled configuration:

```text
build_dir=/media/nia/scsiusb/dev/linux-cap/build/linux-l0-sched-exec-lease-off-p3-x86_64
CONFIG_SCHED_EXEC_LEASE=undef
vmlinux=present
kernel/sched/exec_lease.o=absent
```

Enabled configuration:

```text
build_dir=/media/nia/scsiusb/dev/linux-cap/build/linux-l0-sched-exec-lease-on-p3-x86_64
CONFIG_SCHED_EXEC_LEASE=y
vmlinux=present
kernel/sched/exec_lease.o=present
```

## Object and Symbol Note

P3 marker helpers compile away as inline no-ops. The scheduler object size is
identical in the full-build disabled and enabled configurations:

```text
off kernel/sched/core.o:
  text=73924 data=29289 bss=704 dec=103917
  sched_exec_lease_prepare/note/observe symbols absent

on kernel/sched/core.o:
  text=73924 data=29289 bss=704 dec=103917
  sched_exec_lease_prepare/note/observe symbols absent

on kernel/sched/exec_lease.o:
  text=289 data=32 bss=0 dec=321
  sched_exec_lease_prepare/note/observe symbols absent
```

Interpretation:

```text
P3 does not leave out-of-line marker symbols in scheduler objects.
P3 does not add enabled-only scheduler text in the checked full-build objects.
```

This is a generated-code sanity note only. It is not a formal performance or
cost-efficiency result.

## QEMU No-Behavior Smoke

Runner:

```text
capsched/capsched-models/validation/run-sched-exec-lease-qemu-boot-smoke.sh
```

Workload:

```text
forkexec 100
```

### Disabled Configuration

Command:

```sh
SCHED_EXEC_LEASE_QEMU_MODE=off \
SCHED_EXEC_LEASE_QEMU_ENABLE_KPROBES=0 \
JOBS=8 \
  /media/nia/scsiusb/dev/linux-cap/capsched/capsched-models/validation/run-sched-exec-lease-qemu-boot-smoke.sh
```

Run directory:

```text
/media/nia/scsiusb/dev/linux-cap/build/qemu/sched-exec-lease-boot-smoke/20260702T075510Z-off
```

Summary:

```text
mode=off
linux_commit=d5f77adb5a64f3b2545db6ab1dcdc4aa4442bab3
qemu_status=0
workload_mode=forkexec
workload_args=forkexec 100
kprobes_enabled=0
kvm=enabled
```

Key workload evidence:

```text
WORKLOAD_RET 0
SCHED_EXEC_LEASE_QEMU_END workload_ret=0
sched_process_fork 101
sched_process_exec 101
sched_process_exit 101
sched_switch 488
enqueue_task 261
wake_up_new_task 202
sched_tick 82
sched_exec 1044
```

### Enabled Configuration

Systemd launch:

```text
unit=capsched-p3-qemu-on-20260702T081121Z.service
log=/media/nia/scsiusb/dev/linux-cap/build/logs/sched-exec-lease-p3-qemu-on-20260702T081121Z.log
```

Run directory:

```text
/media/nia/scsiusb/dev/linux-cap/build/qemu/sched-exec-lease-boot-smoke/20260702T081121Z-on
```

Summary:

```text
mode=on
linux_commit=d5f77adb5a64f3b2545db6ab1dcdc4aa4442bab3
qemu_status=0
workload_mode=forkexec
workload_args=forkexec 100
kprobes_enabled=0
kvm=enabled
CONFIG_SCHED_EXEC_LEASE=y
```

Key workload evidence:

```text
WORKLOAD_RET 0
SCHED_EXEC_LEASE_QEMU_END workload_ret=0
sched_process_fork 101
sched_process_exec 101
sched_process_exit 101
sched_switch 497
enqueue_task 262
wake_up_new_task 202
sched_tick 100
sched_exec 1041
```

The enabled serial log confirms:

```text
CONFIG_SCHED_EXEC_LEASE=y
CONFIG_FUNCTION_TRACER=y
CONFIG_KPROBE_EVENTS=y
TRACEFS /sys/kernel/tracing
```

## Trace and Coverage Limits

Function tracing in both QEMU runs still reports:

```text
FUNCTION_MISSING pick_next_task
FUNCTION_MISSING __schedule
```

P3 marker helpers are static inline no-ops and are not expected to appear as
traceable functions or kprobe targets.

Therefore this validation proves:

```text
QEMU boot compatibility
fork/exec/exit workload compatibility
common scheduler activity during the workload
CONFIG_SCHED_EXEC_LEASE=y guest boot/workload compatibility
```

It does not prove:

```text
complete runtime hook coverage
final run validation coverage
queued move validation coverage
negative denial behavior
production scheduler authority enforcement
```

## Overclaim Review

Overclaim review is recorded in:

```text
capsched/capsched-models/analysis/0121-sched-exec-lease-p3-overclaim-review.md
```

Result:

```text
passed: the accepted P3 claim is placement-only/no-denial/no-ABI compatibility.
```

## Acceptance

P3 validation accepts this narrow claim:

```text
The P3 placement-only scheduler touchpoint patch replays from the patch queue,
builds as a full kernel with CONFIG_SCHED_EXEC_LEASE disabled and enabled,
boots in QEMU in both configurations, and completes the fork/exec/exit smoke
workload without adding denial, ABI, monitor calls, or protection evidence.
```

P3 validation rejects these claims:

```text
runtime enforcement
runtime denial
complete scheduler hook coverage
negative denial behavior
budget enforcement
policy frontend integration
monitor verification
hypervisor-grade isolation
production protection
cost efficiency
datacenter deployment readiness
```
