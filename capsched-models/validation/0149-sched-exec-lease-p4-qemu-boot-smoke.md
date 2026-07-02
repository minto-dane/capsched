# SchedExecLease P4 QEMU Boot Smoke

Date: 2026-07-02

Status: passed for `CONFIG_SCHED_EXEC_LEASE=off` and
`CONFIG_SCHED_EXEC_LEASE=on` with the `all` workload and kprobe observation
enabled where available.

## Scope

Validate that the P4 allow-only validation skeleton boots and runs the existing
scheduler workload under QEMU with the feature disabled and enabled.

This is boot/workload compatibility evidence. It is not runtime coverage,
runtime denial, budget enforcement, monitor verification, production
protection, hypervisor-grade isolation, cost-efficiency, or deployment
readiness evidence.

## Linux Commit

```text
commit: a937c67f51d1b82297c4f8b7c471f63e8f1a4fe8
subject: sched/exec_lease: Add allow-only validation skeleton
```

## Command

Launched under a transient systemd user unit:

```sh
systemd-run --user \
  --unit=capsched-p4-qemu-matrix-20260702T220800Z \
  --collect \
  --working-directory=/media/nia/scsiusb/dev/linux-cap \
  /usr/bin/bash -lc '... run off then on ...'
```

Log:

```text
build/logs/sched-exec-lease-p4-qemu-matrix-20260702T220800Z.log
```

The matrix used:

```text
SCHED_EXEC_LEASE_QEMU_WORKLOAD_MODE=all
SCHED_EXEC_LEASE_QEMU_ENABLE_KPROBES=1
JOBS=8
```

The `all` workload runs fork/exec, cross-CPU futex ping-pong, affinity
migration, and CPU pressure.

## Disabled Configuration

Run directory:

```text
build/qemu/sched-exec-lease-p4-allow-only-matrix/20260702T220800Z-off
```

Summary:

```text
mode=off
linux_commit=a937c67f51d1b82297c4f8b7c471f63e8f1a4fe8
qemu_status=0
workload_mode=all
workload_args=all
kprobes_enabled=1
kvm=enabled
WORKLOAD_RET 0
SCHED_EXEC_LEASE_QEMU_END workload_ret=0
```

Counts:

```text
try_to_wake_up=14934
ttwu_do_activate=14856
sched_ttwu_pending=14716
wake_up_new_task=27
enqueue_task=14960
sched_tick=1168
sched_exec=45905
sched_waking=7431
sched_wakeup=7439
sched_wakeup_new=9
sched_switch=15097
sched_migrate_task=44
sched_process_fork=9
sched_process_exec=0
sched_process_exit=12
kprobe:dlease_enqueue_task=7480
kprobe:dlease_try_to_wake_up=7431
kprobe:dlease_wake_up_new_task=9
kprobe:dlease_sched_tick=584
```

## Enabled Configuration

Run directory:

```text
build/qemu/sched-exec-lease-p4-allow-only-matrix/20260702T221639Z-on
```

Summary:

```text
mode=on
linux_commit=a937c67f51d1b82297c4f8b7c471f63e8f1a4fe8
CONFIG_SCHED_EXEC_LEASE=y
qemu_status=0
workload_mode=all
workload_args=all
kprobes_enabled=1
kvm=enabled
WORKLOAD_RET 0
SCHED_EXEC_LEASE_QEMU_END workload_ret=0
```

Counts:

```text
try_to_wake_up=14902
ttwu_do_activate=14832
sched_ttwu_pending=14702
wake_up_new_task=27
enqueue_task=14932
sched_tick=1179
sched_exec=45860
sched_waking=7416
sched_wakeup=7426
sched_wakeup_new=9
sched_switch=15078
sched_migrate_task=44
sched_process_fork=9
sched_process_exec=0
sched_process_exit=12
kprobe:dlease_enqueue_task=7466
kprobe:dlease_try_to_wake_up=7418
kprobe:dlease_wake_up_new_task=9
kprobe:dlease_sched_tick=589
```

## Coverage Limits

The same observation limits remain:

```text
FUNCTION_MISSING pick_next_task
FUNCTION_MISSING __schedule
KPROBE_ADD_FAILED p:domainlease/dlease_pick_next_task pick_next_task
```

Therefore this validation must not be used as runtime coverage for the P4
final-run helper or as evidence for P5 denial safety.

## Decision

The P4 allow-only validation skeleton passes QEMU off/on boot/workload smoke.

Together with validation/0147 and validation/0148, the P4 allow-only skeleton
has now passed patch queue replay, checkpatch, targeted build, source/object
checks, formal gate, full `vmlinux` off/on build, and QEMU off/on compatibility
validation.

P4 still needs final overclaim/security review before its compatibility slice
is closed.

P5 remains blocked.

## Non-Claims

This validation does not claim runtime denial, runtime coverage, behavior
equivalence, budget enforcement, monitor call, monitor verification, production
protection, hypervisor-grade isolation, cost-efficiency, deployment readiness,
or P5 denial approval.
