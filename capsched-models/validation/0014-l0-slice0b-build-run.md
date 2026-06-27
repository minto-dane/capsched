# Validation 0014: L0 Slice 0B Build Run

Status: Passed

Date: 2026-06-26

## Purpose

Validate Linux Slice 0B after adding type-only authority scaffolding.

This validation supports only this claim:

```text
Slice 0B remains build-compatible and inert when CONFIG_CAPSCHED is disabled or
enabled.
```

It does not prove scheduler capability enforcement, Domain isolation, monitor
authority, or any hypervisor-grade security property.

## Linux Commit Under Test

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
commit: 7cf0b1e415bcead8a2079c8be94a9d41aad7d462
subject: sched/capsched: Add type-only authority scaffolding
```

## Command

The existing Slice 0 build runner was used directly:

```sh
/media/nia/scsiusb/dev/linux-cap/capsched/capsched-models/validation/run-l0-slice0-build-validation.sh
```

The runner's log text still says `Slice 0A` in a few phase labels, but it
builds the current `linux/` worktree. For this run, that current worktree was
Slice 0B commit `7cf0b1e415bcead8a2079c8be94a9d41aad7d462`.

## Log

```text
/media/nia/scsiusb/dev/linux-cap/build/logs/l0-slice0-build-20260627T005252Z.log
```

Run timing:

```text
2026-06-26T20:52:52-04:00 validation started
2026-06-26T20:53:09-04:00 upstream baseline vmlinux build started
2026-06-26T20:53:48-04:00 CONFIG_CAPSCHED=n vmlinux build started
2026-06-26T20:56:10-04:00 CONFIG_CAPSCHED=y vmlinux build started
2026-06-26T20:57:50-04:00 validation completed
```

## Static Checks

Changed Linux files:

```text
include/linux/capsched.h
kernel/sched/capsched.c
```

`git diff --check` passed.

Forbidden helper/name grep found no matches for:

```text
capsched_check
capsched_activate
capsched_charge
struct capsched_cap
task_struct
enqueue
pick_next
```

## Build Evidence

Built vmlinux outputs:

```text
/media/nia/scsiusb/dev/linux-cap/build/linux-l0-baseline-base-x86_64/vmlinux
/media/nia/scsiusb/dev/linux-cap/build/linux-l0-capsched-off-x86_64/vmlinux
/media/nia/scsiusb/dev/linux-cap/build/linux-l0-capsched-on-x86_64/vmlinux
```

Disabled config evidence:

```text
CONFIG_CAPSCHED=n:
  no build/linux-l0-capsched-off-x86_64/kernel/sched/capsched.o
  no build/linux-l0-capsched-off-x86_64/kernel/sched/.capsched.o.cmd
```

Enabled config evidence:

```text
CONFIG_CAPSCHED=y:
  build/linux-l0-capsched-on-x86_64/.config:177:CONFIG_CAPSCHED=y
  build/linux-l0-capsched-on-x86_64/kernel/sched/capsched.o
  build/linux-l0-capsched-on-x86_64/kernel/sched/.capsched.o.cmd
```

## Interpretation

This validation passes for Slice 0B.

The patch is still inert:

```text
no scheduler hook
no endpoint hook
no monitor activation
no task layout change
no user ABI
no behavior change
```

The next validation should be attached to either the assurance-case subclaim
tree or a future trace-only Slice 0C, not to runtime enforcement.
