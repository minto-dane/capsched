# Validation 0020: Slice 0C QEMU Boot Validation Plan

Status: Ready for execution

Date: 2026-06-27

## Purpose

Boot the CapSched Linux worktree under QEMU and run the Slice 0C scheduler
observation workload inside that guest.

This moves Slice 0C evidence from host-kernel observation toward reproducible
CapSched-kernel runtime validation.

## Boundary

This validation may support only these claims:

```text
The CapSched L0 kernel build boots under QEMU.
The guest can run the Slice 0C workload.
The guest can observe selected scheduler tracepoints and, when configured,
dynamic ftrace function entries.
```

It must not claim:

```text
RunCap enforcement
FrozenRunUse enforcement
DomainTag activation
monitor-backed authority
hypervisor-grade isolation
```

QEMU is a validation harness here, not the production security boundary.

## Inputs

Linux source:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
expected current commit: 7cf0b1e415bcead8a2079c8be94a9d41aad7d462
```

Validation script:

```text
capsched-models/validation/run-slice0c-qemu-boot-smoke.sh
```

Workload source:

```text
capsched-models/validation/workloads/slice0c_sched_workload.c
```

## Method

The runner creates a validation-specific out-of-tree build directory:

```text
build/linux-l0-capsched-on-qemu-x86_64
```

The config is derived from `x86_64_defconfig`, then enables:

```text
CONFIG_EXPERT=y
CONFIG_CAPSCHED=y
CONFIG_FUNCTION_TRACER=y
```

The runner then builds:

```text
arch/x86/boot/bzImage
```

It creates a temporary initramfs with:

```text
static busybox
the Slice 0C workload binary
the guest init script
the guest kernel config snapshot
```

Inside the guest, `/init` mounts proc, sysfs, devtmpfs, and tracefs, enables
scheduler tracepoints, enables function tracing if available, runs a small
`forkexec` workload, prints target counts to the serial console, and powers off.

## Output

Each run writes:

```text
build/qemu/slice0c-boot-smoke/<timestamp>/
  serial.log
  counts.tsv
  run-summary.txt
  initramfs.cpio.gz
  initramfs/
  slice0c_sched_workload
```

## Exit Criteria

Pass requires:

```text
QEMU exits cleanly or reaches the explicit guest end marker before shutdown.
The serial log contains CAPSCHED_QEMU_BEGIN and CAPSCHED_QEMU_END.
The workload return code is 0.
The guest reports CONFIG_CAPSCHED=y.
At least sched_switch and one wake/fork category are observed or the gap is
  explicitly recorded.
```

Incomplete means:

```text
QEMU boots but trace coverage is insufficient.
Function tracing is unavailable or selected ftrace symbols are missing.
The workload runs but the guest cannot mount tracefs.
```

Blocked means:

```text
bzImage cannot be built.
QEMU cannot boot the kernel.
The guest initramfs cannot execute.
```

## Result Record

Do not overwrite this plan. Record execution results in:

```text
capsched-models/validation/0021-slice0c-qemu-boot-smoke-result.md
```

## Reason

Host trace output is useful for tool debugging, but it is not evidence about
the CapSched Linux worktree unless that worktree kernel is running. QEMU gives
us a repeatable boot boundary before any behavior-changing scheduler hook is
approved.

