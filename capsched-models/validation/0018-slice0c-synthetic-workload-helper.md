# Validation 0018: Slice 0C Synthetic Workload Helper

Status: Added, build-tested, and smoke-tested

Date: 2026-06-26

## Purpose

Add a userspace-only workload helper for future Slice 0C no-code trace runs.

This does not modify Linux. It does not add a kernel ABI. It does not provide
security evidence by itself.

The helper exists to make trace workloads more deliberate than shell loops.

## Files

```text
capsched-models/validation/workloads/slice0c_sched_workload.c
capsched-models/validation/build-slice0c-workload.sh
```

Default build output:

```text
/media/nia/scsiusb/dev/linux-cap/build/workloads/slice0c_sched_workload
```

## Build

```sh
/media/nia/scsiusb/dev/linux-cap/capsched/capsched-models/validation/build-slice0c-workload.sh
```

Build result:

```text
/media/nia/scsiusb/dev/linux-cap/build/workloads/slice0c_sched_workload
```

Smoke tests executed without trace:

```sh
./build/workloads/slice0c_sched_workload forkexec 3
./build/workloads/slice0c_sched_workload futex 100 same
./build/workloads/slice0c_sched_workload pressure 2 10000
./build/workloads/slice0c_sched_workload affinity 2
```

## Modes

```text
forkexec [iters]:
  fork and exec /bin/true repeatedly.

futex [iters] [same|cross]:
  two pthreads ping-pong on a futex. cross pins them to CPU 0 and 1 when
  at least two CPUs are online.

affinity [iters]:
  fork a busy child and alternate its CPU affinity between CPU 0 and 1.

pressure [threads] [iters]:
  run CPU-pressure worker threads with periodic sched_yield().

all:
  run forkexec, futex cross, affinity, and pressure with moderate defaults.
```

## Example Trace Commands

Build:

```sh
./capsched/capsched-models/validation/build-slice0c-workload.sh
```

Run all modes under the no-code trace runner:

```sh
sudo ./capsched/capsched-models/validation/run-slice0c-no-code-trace.sh \
  ./build/workloads/slice0c_sched_workload all
```

Run only futex cross-CPU wake pressure:

```sh
sudo ./capsched/capsched-models/validation/run-slice0c-no-code-trace.sh \
  ./build/workloads/slice0c_sched_workload futex 50000 cross
```

Run only affinity migration pressure:

```sh
sudo ./capsched/capsched-models/validation/run-slice0c-no-code-trace.sh \
  ./build/workloads/slice0c_sched_workload affinity 40
```

Analyze output:

```sh
./capsched/capsched-models/validation/analyze-slice0c-trace.sh \
  ./build/traces/slice0c-no-code-<timestamp>
```

## Expected Coverage Pressure

| Mode | Intended pressure |
| --- | --- |
| `forkexec` | `wake_up_new_task`, `sched_wakeup_new`, fork/exec/exit tracepoints |
| `futex cross` | `try_to_wake_up`, `ttwu_do_activate`, possible remote wakelist |
| `affinity` | `sched_migrate_task`, possible `move_queued_task` |
| `pressure` | scheduler switch density and pick-path visibility |

## Limitations

This helper still cannot prove branch-specific scheduler semantics by itself.

Examples:

```text
futex mode can exercise try_to_wake_up but cannot prove p == current branch.
function tracing can observe enqueue_task but not its enqueue flags.
function tracing can observe __pick_next_task but not fair-fast branch choice.
affinity mode may not always hit move_queued_task under a given kernel/workload.
```

Unobserved categories remain workload or trace-method gaps. They are not proof
that the path does not matter.
