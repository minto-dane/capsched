# Validation 0176: SchedExecLease P5A-R 0009 QEMU Runner

Date: 2026-07-04

Status: Running under systemd user runner.

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

The unit runs:

```text
off:
  SCHED_EXEC_LEASE_QEMU_MODE=off
  SCHED_EXEC_LEASE_QEMU_BUILD=/media/nia/scsiusb/dev/linux-cap/build/linux-l0-sched-exec-lease-off-p5a-r-0009-qemu-x86_64

on:
  SCHED_EXEC_LEASE_QEMU_MODE=on
  SCHED_EXEC_LEASE_QEMU_BUILD=/media/nia/scsiusb/dev/linux-cap/build/linux-l0-sched-exec-lease-on-p5a-r-0009-qemu-x86_64
```

## Resume Commands

```sh
systemctl --user status capsched-p5a-r-0009-qemu-matrix.service --no-pager
tail -f /media/nia/scsiusb/dev/linux-cap/build/logs/sched-exec-lease-p5a-r-0009-qemu-matrix-20260704T035139Z.log
find /media/nia/scsiusb/dev/linux-cap/build/qemu/sched-exec-lease-p5a-r-0009-matrix -maxdepth 2 -name run-summary.txt -o -name counts.tsv -o -name serial.log
```

## Acceptance Boundary

This runner can close only:

```text
QEMU denial-disabled boot/workload compatibility
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

When the unit completes, inspect the unit result, the matrix log, both
`run-summary.txt` files, both `serial.log` files, and the `counts.tsv` files.
Then either replace this running record with a passed/failed QEMU result or add
a follow-up failure record.
