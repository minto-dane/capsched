# Validation 0174: SchedExecLease P5A-R 0009 Full Build

Date: 2026-07-04

Status: passed for full `vmlinux` build with `CONFIG_SCHED_EXEC_LEASE=off`
and `CONFIG_SCHED_EXEC_LEASE=on`. Linux patch `0009` remains unaccepted.

## Scope

This validation records full `vmlinux` build evidence for Linux patch `0009`
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

Final systemd state:

```text
Result=success
ExecMainStatus=0
InvocationID=f9b4db8339574e9fb88a90056ce6d989
```

## Log

```text
/media/nia/scsiusb/dev/linux-cap/build/logs/sched-exec-lease-full-build-20260704T032455Z.log
```

Completion markers:

```text
[2026-07-03T23:33:07-04:00] completed CONFIG_SCHED_EXEC_LEASE=off vmlinux
[2026-07-03T23:41:13-04:00] completed CONFIG_SCHED_EXEC_LEASE=on vmlinux
[2026-07-03T23:41:13-04:00] SchedExecLease full vmlinux build validation completed
```

## Build Outputs

Disabled configuration:

```text
build_dir=/media/nia/scsiusb/dev/linux-cap/build/linux-l0-sched-exec-lease-off-p5a-r-0009-x86_64
CONFIG_SCHED_EXEC_LEASE=undef
vmlinux=present
kernel/sched/exec_lease.o=absent
vmlinux_sha256=f76dbaed7fd47fe812475f26a10d43053911e0d4319a6eb4681db378ba26eb1f
```

Enabled configuration:

```text
build_dir=/media/nia/scsiusb/dev/linux-cap/build/linux-l0-sched-exec-lease-on-p5a-r-0009-x86_64
CONFIG_SCHED_EXEC_LEASE=y
vmlinux=present
kernel/sched/exec_lease.o=present
vmlinux_sha256=367103fd9d3bb1bdebcb87d1cbcf9ac47fee4639b76b06bb7934f9f3c5cd8281
exec_lease_o_sha256=75e4085156ebb0610edbef3af9bf281bfc560edc1a59c2246a79c26f6807dd1e
```

## Result

The full-build compatibility gate for `0009` is satisfied:

```text
CONFIG_SCHED_EXEC_LEASE=off vmlinux builds
CONFIG_SCHED_EXEC_LEASE=off exec_lease.o absent
CONFIG_SCHED_EXEC_LEASE=on vmlinux builds
CONFIG_SCHED_EXEC_LEASE=on exec_lease.o present
```

## Non-Claims

```text
0009_accepted=false
runtime_denial_correctness=false
cfs_deny_and_repick_correctness=false
runtime_coverage=false
qemu_compatibility=false
production_protection=false
cost_efficiency=false
datacenter_readiness=false
```

## Next

The next acceptance step is object/layout evidence for `0009`, followed by QEMU
denial-disabled compatibility, negative ordinary-CFS denial tests, security
diff review, and final overclaim review.
