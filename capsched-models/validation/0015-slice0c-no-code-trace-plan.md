# Validation 0015: Slice 0C No-Code Trace Plan

Status: Planned, not executed

Date: 2026-06-26

## Purpose

Prepare a no-code observation run for Slice 0C.

This validation is tied to:

```text
assurance claims:
  EXEC-001
  COMPAT-001

assurance gate:
  G2 trace-only observation

implementation gate:
  implementation/0006-slice0c-trace-observation-gate.md

source map:
  analysis/0019-wakeup-enqueue-runnable-coverage.md
```

It does not validate RunCap enforcement, FrozenRunUse enforcement, DomainTag
activation, monitor-backed authority, or hypervisor-grade isolation.

## Strategy

Use existing Linux tracing before patching Linux again.

The first run should try to observe:

```text
sched_waking
sched_wakeup
sched_wakeup_new
sched_switch
sched_migrate_task
sched_process_fork
sched_process_exec
sched_process_exit
```

and dynamic ftrace function entries for:

```text
try_to_wake_up
ttwu_runnable
ttwu_do_activate
sched_ttwu_pending
__ttwu_queue_wakelist
ttwu_queue
wake_up_new_task
move_queued_task
enqueue_task
__pick_next_task
pick_next_task
__schedule
```

These are observation targets only. They are not accepted hook points.

## Runner

Runner:

```text
capsched-models/validation/run-slice0c-no-code-trace.sh
```

Default output:

```text
/media/nia/scsiusb/dev/linux-cap/build/traces/slice0c-no-code-<timestamp>/
```

The runner:

```text
requires root or tracefs write access
uses /sys/kernel/tracing or /sys/kernel/debug/tracing
saves trace settings before modification
restores trace settings on exit
records available and missing ftrace function targets
records enabled/missing scheduler events
captures the trace buffer
does not modify the Linux source tree
```

## Example Commands

Default workload:

```sh
sudo /media/nia/scsiusb/dev/linux-cap/capsched/capsched-models/validation/run-slice0c-no-code-trace.sh
```

Custom workload:

```sh
sudo /media/nia/scsiusb/dev/linux-cap/capsched/capsched-models/validation/run-slice0c-no-code-trace.sh \
  bash -lc 'for i in $(seq 1 500); do /bin/true >/dev/null 2>&1; done'
```

Pinned workload, if `taskset` is available:

```sh
sudo /media/nia/scsiusb/dev/linux-cap/capsched/capsched-models/validation/run-slice0c-no-code-trace.sh \
  bash -lc 'taskset -c 0 sh -c "for i in $(seq 1 500); do /bin/true; done"'
```

## Expected Artifacts

The output directory should contain:

```text
metadata.txt
trace.txt
enabled-events.txt
missing-events.txt
enabled-functions.txt
missing-functions.txt
workload.txt
```

The validation record after execution should summarize:

```text
kernel version and config source
workload command
trace duration
which scheduler events were available
which ftrace functions were available
which categories from analysis/0019 were observed
which categories were not observed
whether synthetic tests are needed
```

## Coverage Questions

The post-run analysis must answer:

```text
Was a self-current try_to_wake_up path observed?
Was ttwu_runnable observed?
Was ENQUEUE_DELAYED observable or absent under this workload?
Were remote wakelist and sched_ttwu_pending observed?
Was wake_up_new_task observed?
Was move_queued_task or sched_migrate_task observed?
Was the fair fast pick path observed?
Was core scheduling visible or disabled?
Was sched_ext enabled, disabled, or unavailable?
Was __schedule/sched_switch correlation usable?
```

## Acceptance Criteria

This planned validation passes only as an observation run if:

```text
the runner completes and restores trace settings
trace output and metadata are saved
the result record states that no security property was validated
the result record maps observations back to analysis/0019 categories
```

It is acceptable for many categories to be unobserved under a small workload.
Unobserved categories should become synthetic workload requirements, not
implicit proof that the paths are irrelevant.

## Stop Conditions

Stop and do not treat the run as valid if:

```text
trace settings cannot be restored
tracefs is unavailable
the runner needs a Linux source patch
the workload requires disabling kernel safety features
results are summarized as enforcement evidence
```

## Next After Execution

After a successful trace run, create a new validation result record rather than
editing this plan in place. The result should decide one of:

```text
no-code tracing is sufficient for Slice 0C coverage
synthetic workloads are required before a patch
a minimal CONFIG_CAPSCHED internal observation patch is justified
return to source analysis before any patch
```
