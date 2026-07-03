# Validation 0160: SchedExecLease P5A0.P1 QEMU Boot Smoke

Date: 2026-07-03

Status: passed for `CONFIG_SCHED_EXEC_LEASE=off` and
`CONFIG_SCHED_EXEC_LEASE=on` with the `all` workload and kprobe observation
enabled where available. Final overclaim/security acceptance remains pending.

## Scope

Validate that the concrete P5A0.P1 `0008` no-behavior source-contract patch
boots and runs the existing scheduler workload under QEMU with the feature
disabled and enabled.

This is boot/workload compatibility evidence. It is not runtime coverage,
runtime denial, budget enforcement, monitor verification, production
protection, hypervisor-grade isolation, cost-efficiency, or deployment
readiness evidence.

## Linux Commit

```text
commit: d812f83c033a9f9b3d533e667e7106a5734eb30b
subject: sched/exec_lease: Document P5A0.P1 no-behavior boundary
```

## Command

Launched under a transient systemd user unit:

```sh
systemd-run --user \
  --unit=capsched-p5a0-p1-0008-qemu-matrix \
  --collect \
  --property=WorkingDirectory=/media/nia/scsiusb/dev/linux-cap \
  /usr/bin/bash -lc '... run off then on ...'
```

Log:

```text
build/logs/sched-exec-lease-p5a0-p1-0008-qemu-matrix-20260703T010812Z.log
```

Final service state:

```text
ActiveState=inactive
SubState=dead
Result=success
ExecMainStatus=0
```

The matrix used:

```text
SCHED_EXEC_LEASE_QEMU_WORKLOAD_MODE=all
SCHED_EXEC_LEASE_QEMU_ENABLE_KPROBES=1
JOBS=8
KVM=enabled
```

The `all` workload runs fork/exec, cross-CPU futex ping-pong, affinity
migration, and CPU pressure.

## Disabled Configuration

Run directory:

```text
build/qemu/sched-exec-lease-p5a0-p1-0008-matrix/20260703T010812Z-off
```

Summary:

```text
mode=off
linux_commit=d812f83c033a9f9b3d533e667e7106a5734eb30b
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
try_to_wake_up=14916
ttwu_do_activate=14840
sched_ttwu_pending=14702
wake_up_new_task=27
enqueue_task=14938
sched_tick=1156
sched_exec=45855
sched_waking=7422
sched_wakeup=7430
sched_wakeup_new=9
sched_switch=15083
sched_migrate_task=42
sched_process_fork=9
sched_process_exec=0
sched_process_exit=12
kprobe:dlease_enqueue_task=7469
kprobe:dlease_try_to_wake_up=7423
kprobe:dlease_wake_up_new_task=9
kprobe:dlease_sched_tick=576
```

## Enabled Configuration

Run directory:

```text
build/qemu/sched-exec-lease-p5a0-p1-0008-matrix/20260703T011459Z-on
```

Summary:

```text
mode=on
linux_commit=d812f83c033a9f9b3d533e667e7106a5734eb30b
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
try_to_wake_up=14921
ttwu_do_activate=14850
sched_ttwu_pending=14721
wake_up_new_task=27
enqueue_task=14948
sched_tick=1154
sched_exec=45882
sched_waking=7427
sched_wakeup=7436
sched_wakeup_new=9
sched_switch=15091
sched_migrate_task=40
sched_process_fork=9
sched_process_exec=0
sched_process_exit=12
kprobe:dlease_enqueue_task=7474
kprobe:dlease_try_to_wake_up=7428
kprobe:dlease_wake_up_new_task=9
kprobe:dlease_sched_tick=576
```

## Coverage Limits

The same observation limits remain:

```text
FUNCTION_MISSING pick_next_task
FUNCTION_MISSING __schedule
KPROBE_ADD_FAILED p:domainlease/dlease_pick_next_task pick_next_task
```

Therefore this validation must not be used as runtime coverage for final-run
helper behavior or as evidence for P5 denial safety.

## Decision

The P5A0.P1 `0008` no-behavior source-contract patch passes QEMU off/on
boot/workload smoke.

Together with validations 0156, 0157, 0158, and 0159, P5A0.P1 has now passed
source/replay/formal, full build, object/layout, upstream-maintenance, and QEMU
compatibility evidence.

P5A0.P1 still needs final overclaim/security review before full acceptance.

P5A-R and P5A-M remain blocked.

## Non-Claims

This validation does not approve:

```text
runtime denial
CFS deny-and-repick
broad move denial
runtime coverage
budget enforcement
public ABI or trace ABI
monitor calls or monitor verification
production protection
hypervisor-grade isolation
cost-efficiency
deployment readiness
datacenter readiness
```
