# Validation 0176: SchedExecLease P5A-R 0009 QEMU Boot Smoke

Date: 2026-07-04

Status: Passed for denial-disabled QEMU boot/workload compatibility.

## Purpose

Run the denial-disabled QEMU compatibility matrix for Linux patch `0009`.
This is boot/workload smoke evidence for the dormant ordinary-CFS candidate
with `CONFIG_SCHED_EXEC_LEASE=off` and `CONFIG_SCHED_EXEC_LEASE=on`.

This is not negative denial validation and not protection evidence.

## Runner

```text
unit=capsched-p5a-r-0009-qemu-matrix.service
invocation_id=ea20a9d013034ee886e89ecfced9104e
log=/media/nia/scsiusb/dev/linux-cap/build/logs/sched-exec-lease-p5a-r-0009-qemu-matrix-20260704T035139Z.log
out_root=/media/nia/scsiusb/dev/linux-cap/build/qemu/sched-exec-lease-p5a-r-0009-matrix
linux_commit=7a402107fd63faf7063c2dea05e88e7f8a23f4bf
linux_subject=sched/fair: Draft ordinary CFS exec lease candidate
workload_mode=all
kprobes_enabled=1
jobs=8
```

Systemd result:

```text
ActiveState=inactive
SubState=dead
Result=success
ExecMainStatus=0
```

The unit runs:

```text
off:
  SCHED_EXEC_LEASE_QEMU_MODE=off
  SCHED_EXEC_LEASE_QEMU_BUILD=/media/nia/scsiusb/dev/linux-cap/build/linux-l0-sched-exec-lease-off-p5a-r-0009-qemu-x86_64

on:
  SCHED_EXEC_LEASE_QEMU_MODE=on
  SCHED_EXEC_LEASE_QEMU_BUILD=/media/nia/scsiusb/dev/linux-cap/build/linux-l0-sched-exec-lease-on-p5a-r-0009-qemu-x86_64
```

## Results

```text
off_run=build/qemu/sched-exec-lease-p5a-r-0009-matrix/20260704T035139Z-off
off_qemu_status=0
off_workload_ret=0
off_kvm=enabled
off_serial_sha256=7428f3b851010dacfb739b1d91091947776dd33e3894e402cfcec15245af514d
off_counts_sha256=3b676b05455f69109899acf966fc882db3554c33db89392193b2054b0fa7a5b0
off_summary_sha256=1053e91fc52fa7a8dea6f29aaad3ccd32f94bcc2c6b36c6d53e7a9230ea516a1

on_run=build/qemu/sched-exec-lease-p5a-r-0009-matrix/20260704T035938Z-on
on_qemu_status=0
on_workload_ret=0
on_kvm=enabled
on_config_sched_exec_lease=y
on_serial_sha256=603aa90b3f3c3af0ef629c7e4a05075540c60604d37040a95a27acba6c0e96a9
on_counts_sha256=7d3ad3e7d3f4523f3390eb408657b5b8d411d35fbe446e8e752c9af39658d2f4
on_summary_sha256=56a88b561e850128c2a0e870dc3f20200edabf267844706b4e2676d7d7c647f3
```

Observed counts:

```text
off_sched_switch=15088
on_sched_switch=15112
off_enqueue_task=14942
on_enqueue_task=14962
off_wake_up_new_task=27
on_wake_up_new_task=27
off_sched_tick=1139
on_sched_tick=1156
off_sched_migrate_task=40
on_sched_migrate_task=43
off_sched_process_fork=9
on_sched_process_fork=9
off_sched_process_exit=12
on_sched_process_exit=12
```

Trace coverage limitation:

```text
pick_next_task function observation unavailable in both guests
__schedule function observation unavailable in both guests
dlease_pick_next_task kprobe failed/missing in both guests
sched_process_exec count was 0 in both guests for workload_mode=all
```

## Acceptance Boundary

This runner can close only:

```text
QEMU denial-disabled boot/workload compatibility: passed
```

It cannot close:

```text
0009 acceptance
runtime denial correctness
CFS deny-and-repick correctness
negative denied-task non-publication tests
runtime coverage
production protection
hypervisor-grade isolation
cost-efficiency
deployment readiness
datacenter readiness
monitor-backed enforcement
```

## Next

Proceed to negative ordinary-CFS denial validation. `0009` remains unaccepted
until negative denial tests, security diff review, and final overclaim review
are complete.
