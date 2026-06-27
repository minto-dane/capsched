# Validation 0021: Slice 0C QEMU Boot Smoke Result

Status: Passed for QEMU boot smoke; trace coverage incomplete

Date: 2026-06-27

## Boundary

This run validates a reproducible QEMU boot and scheduler observation path for
the CapSched Linux worktree.

It does not validate:

```text
RunCap enforcement
FrozenRunUse enforcement
SchedContext budget enforcement
DomainTag activation
monitor-backed authority
cross-Domain isolation
hypervisor-grade protection
```

QEMU is used here as a validation harness, not as the CapSched production
security boundary.

## Kernel

```text
guest uname:
  Linux (none) 7.1.0-14065-g7cf0b1e415bc #1 SMP PREEMPT_DYNAMIC Fri Jun 26 22:41:24 EDT 2026 x86_64 GNU/Linux

linux worktree commit:
  7cf0b1e415bcead8a2079c8be94a9d41aad7d462

linux worktree subject:
  sched/capsched: Add type-only authority scaffolding

guest config:
  CONFIG_CAPSCHED=y
  CONFIG_FUNCTION_TRACER=y
```

## Commands

The successful run was launched under a transient systemd user unit:

```sh
CAPSCHED_QEMU_TIMEOUT=180 \
CAPSCHED_QEMU_WORKLOAD_MODE=forkexec \
CAPSCHED_QEMU_WORKLOAD_ITERS=100 \
./capsched/capsched-models/validation/run-slice0c-qemu-boot-smoke.sh
```

The wrapper used:

```sh
systemd-run --user --unit=capsched-slice0c-qemu-boot-smoke --collect ...
```

Because `--collect` was used, `systemctl --user status` may report the unit as
not found after completion. The run result is therefore recorded from the log
and run artifacts, not from a persistent unit object.

## Artifacts

```text
log:
  /media/nia/scsiusb/dev/linux-cap/build/logs/slice0c-qemu-boot-smoke-20260627T033853Z.log

run directory:
  /media/nia/scsiusb/dev/linux-cap/build/qemu/slice0c-boot-smoke/20260627T033853Z

serial log:
  /media/nia/scsiusb/dev/linux-cap/build/qemu/slice0c-boot-smoke/20260627T033853Z/serial.log

counts:
  /media/nia/scsiusb/dev/linux-cap/build/qemu/slice0c-boot-smoke/20260627T033853Z/counts.tsv

summary:
  /media/nia/scsiusb/dev/linux-cap/build/qemu/slice0c-boot-smoke/20260627T033853Z/run-summary.txt

kernel:
  /media/nia/scsiusb/dev/linux-cap/build/linux-l0-capsched-on-qemu-x86_64/arch/x86/boot/bzImage

initramfs:
  /media/nia/scsiusb/dev/linux-cap/build/qemu/slice0c-boot-smoke/20260627T033853Z/initramfs.cpio.gz
```

## Result Markers

The guest serial log contains:

```text
CAPSCHED_QEMU_BEGIN
CONFIG_CAPSCHED=y
CONFIG_FUNCTION_TRACER=y
TRACEFS /sys/kernel/tracing
TRACER function
WORKLOAD_RET 0
CAPSCHED_QEMU_END workload_ret=0
```

QEMU runner summary:

```text
qemu_status=0
qemu_timeout_seconds=180
workload_mode=forkexec
workload_iters=100
kvm=enabled
```

## Enabled Trace Targets

All requested scheduler tracepoints were present:

```text
sched/sched_waking
sched/sched_wakeup
sched/sched_wakeup_new
sched/sched_switch
sched/sched_migrate_task
sched/sched_process_fork
sched/sched_process_exec
sched/sched_process_exit
```

Function tracer targets enabled:

```text
try_to_wake_up
ttwu_do_activate
sched_ttwu_pending
wake_up_new_task
move_queued_task
enqueue_task
```

Function targets missing:

```text
ttwu_runnable
__ttwu_queue_wakelist
ttwu_queue
__pick_next_task
pick_next_task
__schedule
```

## Counts

| Target | Count |
| --- | ---: |
| `try_to_wake_up` | 190 |
| `ttwu_runnable` | 0 |
| `ttwu_do_activate` | 294 |
| `sched_ttwu_pending` | 222 |
| `__ttwu_queue_wakelist` | 0 |
| `ttwu_queue` | 0 |
| `wake_up_new_task` | 202 |
| `move_queued_task` | 2 |
| `enqueue_task` | 253 |
| `__pick_next_task` | 0 |
| `pick_next_task` | 0 |
| `__schedule` | 0 |
| `sched_waking` | 150 |
| `sched_wakeup` | 251 |
| `sched_wakeup_new` | 101 |
| `sched_switch` | 476 |
| `sched_migrate_task` | 15 |
| `sched_process_fork` | 101 |
| `sched_process_exec` | 101 |
| `sched_process_exit` | 101 |

## Interpretation

Observed in a CapSched worktree kernel guest:

```text
QEMU boot of CONFIG_CAPSCHED=y kernel
tracefs mount and use
function tracer activation
fork/exec/exit workload completion
wakeup and new-task tracepoints
sched_switch events
migration events
selected wake/enqueue function entries
```

Still incomplete:

```text
already-runnable wake path
remote wakelist enqueue path
pick internal function path
__schedule function-entry path
delayed fair requeue distinction
core scheduling branch distinction
argument/flag-level enqueue classification
```

The missing function symbols are not proof that the paths are irrelevant. They
may be unavailable due to inlining, symbol visibility, config, compiler shape,
or workload coverage.

## Decision

This passes the first QEMU boot smoke gate.

Next work should keep Slice 0C in observation mode and improve coverage through
one or more of:

```text
broader guest workloads: futex cross-CPU, affinity migration, pressure, all
guest-side trace result parser compatible with analyze-slice0c-trace.sh
dynamic kprobe events for branch/argument details
minimal CONFIG_CAPSCHED internal observation patch only if no-code tracing
  cannot resolve critical coverage questions
```

Do not proceed to RunCap enforcement from this evidence alone.

