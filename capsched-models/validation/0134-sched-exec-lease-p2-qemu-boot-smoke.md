# Validation 0134: SchedExecLease P2 QEMU Boot Smoke

Status: Passed for P2 QEMU boot/workload smoke in disabled and enabled
SchedExecLease configurations; observation coverage remains incomplete and no
runtime protection claim is made

Date: 2026-07-02

## Purpose

Validate that the P2 no-denial task identity shadow patch boots and runs a
fork/exec/exit workload in QEMU with `CONFIG_SCHED_EXEC_LEASE` disabled and
enabled.

This is runtime compatibility evidence for a lifecycle-touching no-denial
patch. It is not scheduler enforcement, hook coverage, denial evidence, budget
charging, monitor verification, exploit containment, production protection, or
cost-efficiency evidence.

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

## Systemd Unit

```text
unit=capsched-p2-qemu-boot-smoke-20260702T045650Z.service
result=success
exec_main_status=0
```

Log:

```text
/media/nia/scsiusb/dev/linux-cap/build/logs/capsched-p2-qemu-boot-smoke-20260702T045650Z.log
```

## Patch Queue Recheck

After the QEMU result, the current patch queue was replayed again into a fresh
reference-backed tree:

```sh
DOMAINLEASE_RECREATE_FETCH=0 \
DOMAINLEASE_LINUX_REFERENCE=/media/nia/scsiusb/dev/linux-cap/linux \
  ./linux-patches/scripts/recreate-capsched-linux-l0.sh \
  build/replay/n164-p2-patch-queue-20260702T051858Z
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

Completion markers:

```text
[2026-07-02T01:06:01-04:00] SchedExecLease QEMU boot smoke completed
[2026-07-02T01:15:23-04:00] SchedExecLease QEMU boot smoke completed
[2026-07-02T01:15:23-04:00] P2 QEMU boot smoke chain completed
```

## Disabled Configuration

Run directory:

```text
/media/nia/scsiusb/dev/linux-cap/build/qemu/sched-exec-lease-p2-boot-smoke/20260702T045650Z-off
```

Summary:

```text
mode=off
linux_commit=a0f2676adda634391983e74f29fcba577a9c919e
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
sched_switch 480
enqueue_task 256
wake_up_new_task 202
sched_exec 1027
```

## Enabled Configuration

Run directory:

```text
/media/nia/scsiusb/dev/linux-cap/build/qemu/sched-exec-lease-p2-boot-smoke/20260702T050601Z-on
```

Summary:

```text
mode=on
linux_commit=a0f2676adda634391983e74f29fcba577a9c919e
qemu_status=0
workload_mode=forkexec
workload_args=forkexec 100
kprobes_enabled=1
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
sched_switch 501
enqueue_task 550
wake_up_new_task 303
sched_exec 1280
```

Kprobe observation in the enabled run:

```text
kprobe:dlease_enqueue_task 275
kprobe:dlease_try_to_wake_up 169
kprobe:dlease_wake_up_new_task 101
kprobe:dlease_sched_tick 121
kprobe:dlease_pick_next_task 0
```

The enabled guest serial log confirms:

```text
CONFIG_SCHED_EXEC_LEASE=y
CONFIG_FUNCTION_TRACER=y
CONFIG_KPROBE_EVENTS=y
TRACEFS /sys/kernel/tracing
```

## Coverage Limits

This validation intentionally preserves the coverage limits observed in earlier
QEMU smoke tests:

```text
FUNCTION_MISSING pick_next_task
FUNCTION_MISSING __schedule
KPROBE_ADD_FAILED p:domainlease/dlease_pick_next_task pick_next_task
KPROBE_MISSING domainlease/dlease_pick_next_task
```

Therefore this proves boot/workload compatibility for P2, not final scheduler
hook coverage. The missing final-pick/schedule visibility remains a P3/P4/P5
design and validation issue, not a P2 acceptance blocker, because P2 adds no
scheduler hook or denial path.

## Interpretation

P2 acceptance evidence is now complete for the no-denial lifecycle shadow:

```text
patch queue replay reached a0f2676adda634391983e74f29fcba577a9c919e
CONFIG_SCHED_EXEC_LEASE=off full vmlinux build passed
CONFIG_SCHED_EXEC_LEASE=on full vmlinux build passed
task layout probe showed the shadow compiled out when disabled
task layout probe showed the shadow present when enabled
QEMU off boot/workload smoke passed
QEMU on boot/workload smoke passed with CONFIG_SCHED_EXEC_LEASE=y
fork/exec/exit workload completed successfully in both modes
```

The result supports only this narrow claim:

```text
The P2 task identity shadow patch is compatible with full builds, task layout
expectations, QEMU boot, and a fork/exec/exit smoke workload in disabled and
enabled configurations.
```

It does not support:

```text
runtime enforcement
runtime denial
complete scheduler hook coverage
negative denial behavior
budget enforcement
policy frontend integration
user ABI approval
public tracepoint ABI approval
monitor ABI approval
monitor implementation
monitor verification
MemoryView, IOMMU, or device ownership enforcement
workqueue or io_uring authority propagation
hypervisor-grade isolation
production protection
cost-efficiency claims
```
