# Validation 0174: SchedExecLease P5A-R 0009 Full Build Runner

Date: 2026-07-04

Status: running under systemd user runner. This is not yet a passed validation.

## Scope

This runner is collecting full `vmlinux` build evidence for Linux patch `0009`
with:

```text
CONFIG_SCHED_EXEC_LEASE=off
CONFIG_SCHED_EXEC_LEASE=on
```

It is build compatibility evidence only. It does not validate runtime denial,
CFS deny-and-repick correctness, QEMU boot compatibility, protection, or cost.

## Unit

```text
unit=capsched-p5a-r-0009-full-build.service
invocation_id=f9b4db8339574e9fb88a90056ce6d989
```

Started with:

```sh
systemd-run --user \
  --unit=capsched-p5a-r-0009-full-build \
  --collect \
  --property=WorkingDirectory=/media/nia/scsiusb/dev/linux-cap \
  /usr/bin/env BUILD_TAG=p5a-r-0009 JOBS=8 \
  /media/nia/scsiusb/dev/linux-cap/capsched/capsched-models/validation/run-sched-exec-lease-full-build-validation.sh
```

## Log

```text
/media/nia/scsiusb/dev/linux-cap/build/logs/sched-exec-lease-full-build-20260704T032455Z.log
```

Expected build outputs:

```text
build/linux-l0-sched-exec-lease-off-p5a-r-0009-x86_64/vmlinux
build/linux-l0-sched-exec-lease-on-p5a-r-0009-x86_64/vmlinux
```

## Resume Commands

Check status:

```sh
systemctl --user status capsched-p5a-r-0009-full-build.service --no-pager
```

Follow log:

```sh
tail -f /media/nia/scsiusb/dev/linux-cap/build/logs/sched-exec-lease-full-build-20260704T032455Z.log
```

After completion, collect:

```sh
systemctl --user show capsched-p5a-r-0009-full-build.service \
  --property=ActiveState,SubState,Result,ExecMainStatus,ExecMainPID,InvocationID

sha256sum \
  /media/nia/scsiusb/dev/linux-cap/build/linux-l0-sched-exec-lease-off-p5a-r-0009-x86_64/vmlinux \
  /media/nia/scsiusb/dev/linux-cap/build/linux-l0-sched-exec-lease-on-p5a-r-0009-x86_64/vmlinux \
  /media/nia/scsiusb/dev/linux-cap/build/linux-l0-sched-exec-lease-on-p5a-r-0009-x86_64/kernel/sched/exec_lease.o
```

## Non-Claims

Until the unit finishes successfully and this record is updated:

```text
full_vmlinux_build_passed=false
0009_accepted=false
runtime_denial_correctness=false
cfs_deny_and_repick_correctness=false
runtime_coverage=false
qemu_compatibility=false
production_protection=false
cost_efficiency=false
datacenter_readiness=false
```
