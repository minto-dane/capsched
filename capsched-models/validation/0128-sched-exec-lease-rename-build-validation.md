# Validation 0128: SchedExecLease Rename Build Validation

Status: Passed for targeted scheduler-subtree build; no behavior or protection
claim

Date: 2026-07-02

## Scope

This validation checks the N-156 Linux scaffold rename:

```text
CONFIG_CAPSCHED -> CONFIG_SCHED_EXEC_LEASE
include/linux/capsched.h -> include/linux/sched_exec_lease.h
kernel/sched/capsched.c -> kernel/sched/exec_lease.c
```

The rename is intentionally no-behavior:

```text
no scheduler hook
no task_struct field
no user ABI
no public tracepoint ABI
no monitor ABI
no runtime denial
no protection claim
```

## Command

```sh
JOBS=8 capsched/capsched-models/validation/run-sched-exec-lease-rename-build-validation.sh
```

## Evidence

Log:

```text
/media/nia/scsiusb/dev/linux-cap/build/logs/sched-exec-lease-rename-build-20260702T014802Z.log
```

Build outputs:

```text
OFF: /media/nia/scsiusb/dev/linux-cap/build/linux-l0-sched-exec-lease-off-targeted-x86_64
ON:  /media/nia/scsiusb/dev/linux-cap/build/linux-l0-sched-exec-lease-on-targeted-x86_64
```

Checks:

```text
OFF config state:
  SCHED_EXEC_LEASE = undef

ON config state:
  SCHED_EXEC_LEASE = y

OFF build:
  kernel/sched/built-in.a exists
  kernel/sched/exec_lease.o absent

ON build:
  kernel/sched/built-in.a exists
  kernel/sched/exec_lease.o exists

Source term check:
  old scaffold terms absent from init/, include/linux/sched_exec_lease.h,
  and kernel/sched/

New source anchors:
  init/Kconfig: config SCHED_EXEC_LEASE
  include/linux/sched_exec_lease.h: sched_exec_lease_enabled()
  kernel/sched/Makefile: obj-$(CONFIG_SCHED_EXEC_LEASE) += exec_lease.o
  kernel/sched/exec_lease.c: includes <linux/sched_exec_lease.h>
```

## Note On Full Build

An earlier N-156 full `vmlinux` run was stopped because it was broader than the
rename question. The accepted N-156 evidence is the targeted scheduler-subtree
build above. A later integration slice may run full `vmlinux` again after a
behavior-changing hook proposal exists.

## Result

The Linux scaffold rename is build-validated for the affected Kconfig/Kbuild
surface. It remains a no-behavior scaffold rename only.

## Non-Claims

This validation is not full `vmlinux` validation, runtime coverage, scheduler
enforcement, monitor implementation, monitor verification, production
protection, or cost-efficiency evidence.
