# Validation 0157: SchedExecLease P5A0.P1 Full vmlinux Build

Date: 2026-07-02

Status: passed for full `vmlinux` build with `CONFIG_SCHED_EXEC_LEASE=off`
and `CONFIG_SCHED_EXEC_LEASE=on`; object/symbol/disassembly/layout,
QEMU-denial-disabled smoke, upstream-maintenance, and final overclaim/security
acceptance remain pending.

## Scope

This validates that the concrete P5A0.P1 `0008` source-contract patch builds
as a full x86_64 kernel with SchedExecLease disabled and enabled.

It remains build compatibility evidence only. It is not runtime coverage,
runtime denial, monitor verification, production protection, cost-efficiency,
deployment readiness, or datacenter readiness evidence.

## Source State

```text
linux_branch=capsched-linux-l0
linux_commit=d812f83c033a9f9b3d533e667e7106a5734eb30b
linux_subject=sched/exec_lease: Document P5A0.P1 no-behavior boundary
```

The concrete patch is recorded in:

```text
linux-patches/patches/capsched-linux-l0/0008-sched-exec_lease-Document-P5A0.P1-no-behavior-bounda.patch
```

## Command

Systemd user unit:

```text
capsched-p5a0-p1-0008-full-build.service
```

Command:

```sh
systemd-run --user \
  --unit=capsched-p5a0-p1-0008-full-build \
  --collect \
  --property=WorkingDirectory=/media/nia/scsiusb/dev/linux-cap \
  /usr/bin/env BUILD_TAG=p5a0-p1-0008 JOBS=8 \
  /media/nia/scsiusb/dev/linux-cap/capsched/capsched-models/validation/run-sched-exec-lease-full-build-validation.sh
```

Log:

```text
/media/nia/scsiusb/dev/linux-cap/build/logs/sched-exec-lease-full-build-20260703T003100Z.log
```

Systemd final state:

```text
ActiveState=inactive
SubState=dead
Result=success
ExecMainStatus=0
```

## Build Outputs

Disabled configuration:

```text
build_dir=/media/nia/scsiusb/dev/linux-cap/build/linux-l0-sched-exec-lease-off-p5a0-p1-0008-x86_64
CONFIG_SCHED_EXEC_LEASE=undef
vmlinux=present
kernel/sched/exec_lease.o=absent
vmlinux_sha256=13059a6108afc87ee829506a91502033bf008ed5544e3bd3d32c88dc9d3fd896
```

Enabled configuration:

```text
build_dir=/media/nia/scsiusb/dev/linux-cap/build/linux-l0-sched-exec-lease-on-p5a0-p1-0008-x86_64
CONFIG_SCHED_EXEC_LEASE=y
vmlinux=present
kernel/sched/exec_lease.o=present
vmlinux_sha256=9673dd514ee5b7b35cf54459ac610d6c09f0b0d0889ce373fe940522b526aed9
exec_lease_o_sha256=75e4085156ebb0610edbef3af9bf281bfc560edc1a59c2246a79c26f6807dd1e
```

Completion markers:

```text
[2026-07-02T20:39:17-04:00] completed CONFIG_SCHED_EXEC_LEASE=off vmlinux
[2026-07-02T20:47:39-04:00] completed CONFIG_SCHED_EXEC_LEASE=on vmlinux
[2026-07-02T20:47:39-04:00] SchedExecLease full vmlinux build validation completed
```

## Interpretation

This closes the full-build part of P5A0.P1 acceptance:

```text
CONFIG_SCHED_EXEC_LEASE=off:
  full vmlinux builds
  exec_lease.o is absent

CONFIG_SCHED_EXEC_LEASE=on:
  full vmlinux builds
  exec_lease.o is present
```

The result is consistent with the source gate: the patch is comment-only and
does not introduce a new runtime behavior path.

## Remaining P5A0.P1 Acceptance Work

Still required before final P5A0.P1 acceptance:

```text
QEMU denial-disabled boot/workload smoke
object/symbol/disassembly review
section-size and hot-function growth review
layout evidence
fresh upstream drift and merge-tree evidence
strict checkpatch and get_maintainer output
final overclaim/security review
```

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
