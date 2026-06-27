# Validation 0022: Slice 0C QEMU Broader Workload Result

Status: Passed for broader QEMU workload execution; trace coverage still incomplete

Date: 2026-06-27

## Boundary

This run extends the QEMU Slice 0C observation harness beyond the initial
fork/exec smoke.

It validates:

```text
CapSched worktree kernel boots repeatedly under QEMU.
The guest workload runner accepts workload-specific arguments.
futex cross-CPU, affinity migration, scheduler pressure, and combined workloads
  complete with WORKLOAD_RET 0.
Scheduler tracepoints and available function tracer targets produce counts.
```

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

## Runner Change

The QEMU runner now supports workload-specific arguments:

```text
CAPSCHED_QEMU_WORKLOAD_ARGS
CAPSCHED_QEMU_FUTEX_PLACEMENT
CAPSCHED_QEMU_PRESSURE_THREADS
CAPSCHED_QEMU_WORKLOAD_ITERS
```

This is needed because `futex cross`, `affinity`, `pressure`, and `all` do not
all share the same argument shape.

## Kernel

All runs used:

```text
linux commit:
  7cf0b1e415bcead8a2079c8be94a9d41aad7d462

linux subject:
  sched/capsched: Add type-only authority scaffolding

guest config:
  CONFIG_CAPSCHED=y
  CONFIG_FUNCTION_TRACER=y

tracefs:
  /sys/kernel/tracing

tracer:
  function
```

## Runs

| Workload | Args | Run directory | Status |
| --- | --- | --- | --- |
| `futex` | `futex 5000 cross` | `build/qemu/slice0c-boot-smoke/20260627T054514Z` | Passed |
| `affinity` | `affinity 40` | `build/qemu/slice0c-boot-smoke/20260627T054559Z` | Passed |
| `pressure` | `pressure 8 500000` | `build/qemu/slice0c-boot-smoke/20260627T054618Z` | Passed |
| `all` | `all` | `build/qemu/slice0c-boot-smoke/20260627T054636Z` | Passed |

For each run:

```text
CONFIG_CAPSCHED=y
CONFIG_FUNCTION_TRACER=y
TRACEFS /sys/kernel/tracing
TRACER function
WORKLOAD_RET 0
CAPSCHED_QEMU_END workload_ret=0
qemu_status=0
```

## Counts

| Target | futex cross | affinity | pressure | all |
| --- | ---: | ---: | ---: | ---: |
| `try_to_wake_up` | 8765 | 253 | 12 | 8761 |
| `ttwu_runnable` | 0 | 0 | 0 | 0 |
| `ttwu_do_activate` | 17526 | 258 | 14 | 17386 |
| `sched_ttwu_pending` | 17522 | 18 | 6 | 17256 |
| `__ttwu_queue_wakelist` | 0 | 0 | 0 | 0 |
| `ttwu_queue` | 0 | 0 | 0 | 0 |
| `wake_up_new_task` | 0 | 4 | 18 | 18 |
| `move_queued_task` | 0 | 78 | 0 | 38 |
| `enqueue_task` | 8763 | 211 | 16 | 8743 |
| `__pick_next_task` | 0 | 0 | 0 | 0 |
| `pick_next_task` | 0 | 0 | 0 | 0 |
| `__schedule` | 0 | 0 | 0 | 0 |
| `sched_waking` | 8762 | 130 | 7 | 8694 |
| `sched_wakeup` | 8763 | 132 | 16 | 8704 |
| `sched_wakeup_new` | 0 | 2 | 9 | 9 |
| `sched_switch` | 17523 | 261 | 266 | 17634 |
| `sched_migrate_task` | 0 | 85 | 4 | 41 |
| `sched_process_fork` | 0 | 2 | 9 | 9 |
| `sched_process_exec` | 0 | 1 | 1 | 0 |
| `sched_process_exit` | 3 | 2 | 9 | 12 |

## Coverage Improvements

The broader QEMU runs improved coverage in these areas:

```text
futex cross:
  high-volume cross-CPU wake/switch pressure

affinity:
  queued migration and sched_migrate_task coverage

pressure:
  scheduler pressure without large fork/exec counts

all:
  combined wake, switch, migration, and process lifecycle coverage
```

## Persistent Gaps

These targets remained unavailable or unobserved across all runs:

```text
ttwu_runnable
__ttwu_queue_wakelist
ttwu_queue
__pick_next_task
pick_next_task
__schedule
```

Because the runner reported these as `FUNCTION_MISSING`, this is no longer just
a workload gap. It is likely a symbol/ftrace availability gap caused by
compiler shape, inlining, static visibility, notrace annotation, or ftrace
eligibility.

These semantic categories remain unresolved:

```text
already-runnable wake path
remote wakelist enqueue path
delayed fair requeue distinction
pick fast path versus class iteration
core scheduling cached/force-idle branches
final __schedule function-entry correlation
enqueue flag and argument-level classification
```

## Decision

The QEMU observation harness is now useful and repeatable enough to keep.

Do not proceed to RunCap enforcement from this evidence.

Next gate should be one of:

```text
symbol/ftrace eligibility analysis against the QEMU vmlinux
guest-side kprobe event experiment for missing functions and arguments
minimal CONFIG_CAPSCHED internal observation patch if no-code tracing cannot
  resolve critical branch/argument coverage
```

The recommended next step is symbol/ftrace eligibility analysis first. It is
lower risk than adding a Linux patch and may explain which gaps can be solved
with kprobes versus which require internal observation.

