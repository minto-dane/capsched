# Validation 0131: SchedExecLease QEMU Boot Smoke

Status: Passed for QEMU boot/workload smoke; hook coverage remains incomplete

Date: 2026-07-02

## Purpose

Validate that the renamed inert SchedExecLease scaffold boots under QEMU in
both disabled and enabled configurations after full `vmlinux` validation.

This is compatibility evidence only. It is not runtime enforcement, hook
coverage, ABI approval, monitor verification, production protection, or
cost-efficiency evidence.

## Runner

```text
script:
  capsched-models/validation/run-sched-exec-lease-qemu-boot-smoke.sh

systemd unit:
  capsched-n159-qemu-after-full-build-20260702T0320Z.service

log:
  /media/nia/scsiusb/dev/linux-cap/build/logs/sched-exec-lease-qemu-after-full-build-20260702T0320Z.log
```

The unit waited for the full-build marker from validation/0130, then ran:

```text
SCHED_EXEC_LEASE_QEMU_MODE=off
SCHED_EXEC_LEASE_QEMU_ENABLE_KPROBES=0

SCHED_EXEC_LEASE_QEMU_MODE=on
SCHED_EXEC_LEASE_QEMU_ENABLE_KPROBES=1
```

## Linux Version

```text
linux_commit=3bb2a5821ffdcc0fa6d451cbf259ef82a9ea9a9c
linux_subject=sched/exec_lease: Rename inert scheduler lease scaffold
```

## Off Result

```text
run:
  build/qemu/sched-exec-lease-boot-smoke/20260702T031917Z-off

mode:
  off

qemu_status:
  0

workload:
  forkexec 100

workload result:
  WORKLOAD_RET 0
  SCHED_EXEC_LEASE_QEMU_END workload_ret=0

kprobes:
  disabled
```

Selected counts:

```text
COUNT try_to_wake_up 207
COUNT wake_up_new_task 202
COUNT enqueue_task 264
COUNT sched_tick 156
COUNT sched_exec 1039
COUNT sched_switch 505
COUNT sched_process_fork 101
COUNT sched_process_exec 101
COUNT sched_process_exit 101
WORKLOAD_RET 0
```

## On Result

```text
run:
  build/qemu/sched-exec-lease-boot-smoke/20260702T033357Z-on

mode:
  on

qemu_status:
  0

CONFIG_SCHED_EXEC_LEASE:
  y

workload:
  forkexec 100

workload result:
  WORKLOAD_RET 0
  SCHED_EXEC_LEASE_QEMU_END workload_ret=0

kprobes:
  enabled where accepted by tracefs
```

Selected counts:

```text
COUNT try_to_wake_up 361
COUNT wake_up_new_task 303
COUNT enqueue_task 530
COUNT sched_tick 172
COUNT sched_exec 1251
COUNT sched_switch 496
COUNT sched_process_fork 101
COUNT sched_process_exec 101
COUNT sched_process_exit 101
KPROBE_COUNT dlease_enqueue_task 265
KPROBE_COUNT dlease_try_to_wake_up 160
KPROBE_COUNT dlease_wake_up_new_task 101
KPROBE_COUNT dlease_sched_tick 86
WORKLOAD_RET 0
```

## Coverage Limits

The on run explicitly records missing or rejected observation points:

```text
KPROBE_ADD_FAILED p:domainlease/dlease_pick_next_task pick_next_task
KPROBE_MISSING domainlease/dlease_pick_next_task
FUNCTION_MISSING ttwu_runnable
FUNCTION_MISSING __ttwu_queue_wakelist
FUNCTION_MISSING ttwu_queue
FUNCTION_MISSING pick_next_task
FUNCTION_MISSING __schedule
```

Therefore this validation proves only:

```text
CONFIG_SCHED_EXEC_LEASE=off boots and runs fork/exec/exit smoke
CONFIG_SCHED_EXEC_LEASE=on boots and runs fork/exec/exit smoke
enabled scaffold does not prevent this workload from completing
selected observable scheduler events/functions fire in QEMU
```

It does not prove:

```text
final run hook coverage
core cached-pick coverage
sched_ext coverage
proxy execution coverage
fair/RT/deadline move coverage
workqueue/kthread authority classification
negative denial behavior
runtime protection
```

## Result

The QEMU boot-smoke gate for no-behavior SchedExecLease scaffold compatibility
is passed for off/on configurations.

Behavior-changing runtime enforcement remains blocked by the design gates in
implementation/0016 through implementation/0018.

## Non-Claims

This validation is not Linux enforcement, runtime coverage, hook approval,
negative denial evidence, ABI approval, monitor ABI approval, monitor
implementation, monitor verification, exploit-containment evidence,
hypervisor-grade isolation, production protection, or cost-efficiency evidence.
