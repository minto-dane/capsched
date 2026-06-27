# Validation 0017: Slice 0C Trace Analysis and Workload Plan

Status: Planned, not executed

Date: 2026-06-26

## Purpose

Define how Slice 0C no-code trace output should be interpreted after
`run-slice0c-no-code-trace.sh` executes.

This plan exists because trace evidence can be misleading. Seeing a function
entry is not the same as seeing the exact scheduler branch we care about, and
seeing a path under a small workload is not a security proof.

## Analyzer

Analyzer:

```text
capsched-models/validation/analyze-slice0c-trace.sh
```

Usage:

```sh
/media/nia/scsiusb/dev/linux-cap/capsched/capsched-models/validation/analyze-slice0c-trace.sh \
  /media/nia/scsiusb/dev/linux-cap/build/traces/slice0c-no-code-<timestamp>
```

Default output:

```text
coverage-summary.md
```

The analyzer classifies observations as:

```text
observed:
  The target function or event appeared in the trace.

not_observed:
  The target did not appear in this trace.

ambiguous:
  A related target appeared, but simple no-code tracing cannot prove the exact
  branch or flag.

not_inferable:
  The current trace method cannot decide this category without argument
  capture, a dynamic kprobe event, or a later explicit trace patch.
```

## No-Code Trace Limits

The first no-code runner uses scheduler tracepoints and ftrace function
entries. This is useful, but it has strict limits:

```text
try_to_wake_up observed
  does not prove p == current or p != current branch

enqueue_task observed
  does not expose ENQUEUE_DELAYED, ENQUEUE_INITIAL, ENQUEUE_MIGRATED, or
  ENQUEUE_RESTORE flags

__pick_next_task observed
  does not prove fair fast path versus class iteration

pick_next_task observed
  does not prove core cached pick or force-idle branch

sched_switch observed
  does not prove Domain transition or authority validation
```

These limits are good to expose early. They tell us whether no-code tracing is
enough or whether a later CONFIG_CAPSCHED internal observation patch is
justified.

## Workload Set

The first run may use the default fork/exec workload, but it should not be the
only workload.

### W0: Default Fork/Exec Smoke

Purpose:

```text
wake_up_new_task
sched_wakeup_new
sched_process_fork
sched_process_exec
sched_process_exit
sched_switch
```

Command:

```sh
sudo ./capsched/capsched-models/validation/run-slice0c-no-code-trace.sh
```

Expected:

```text
wake_new_task should be observed
switch_prev_next should be observed
many other categories may remain unobserved
```

### W1: Pipe or Futex Ping-Pong

Purpose:

```text
try_to_wake_up
ttwu_do_activate
ttwu_runnable, if the timing hits already-runnable wake
sched_switch
```

Candidate command:

```sh
sudo ./capsched/capsched-models/validation/run-slice0c-no-code-trace.sh \
  bash -lc 'for i in $(seq 1 200); do sleep 0.001 & wait $!; done'
```

This is weak. A small userspace C futex ping-pong workload may be needed later.

### W2: Cross-CPU Wake

Purpose:

```text
remote wakelist
sched_ttwu_pending
sched_migrate_task, depending on placement
```

Candidate command:

```sh
sudo ./capsched/capsched-models/validation/run-slice0c-no-code-trace.sh \
  bash -lc 'taskset -c 0 sh -c "for i in $(seq 1 200); do sleep 0.001 & wait $!; done"'
```

Limit:

```text
This may not force remote wakelist. It is only a first attempt.
```

### W3: Affinity Change and Migration

Purpose:

```text
move_queued_task
sched_migrate_task
affinity-induced placement changes
```

Candidate command:

```sh
sudo ./capsched/capsched-models/validation/run-slice0c-no-code-trace.sh \
  bash -lc 'sh -c "while :; do :; done" & p=$!; sleep 0.1; taskset -pc 0 $p >/dev/null; sleep 0.1; taskset -pc 1 $p >/dev/null; sleep 0.1; kill $p; wait $p 2>/dev/null || true'
```

Limit:

```text
Requires at least two CPUs and taskset.
```

### W4: Scheduler Pressure

Purpose:

```text
pick path pressure
fair fast path
class iteration, if RT/DL tasks are available
switch density
```

Candidate command:

```sh
sudo ./capsched/capsched-models/validation/run-slice0c-no-code-trace.sh \
  bash -lc 'for j in $(seq 1 8); do sh -c "for i in $(seq 1 200000); do :; done" & done; wait'
```

Limit:

```text
Simple function tracing cannot prove fair-fast versus class-loop branch.
```

### W5: Core Scheduling and sched_ext Probe

Purpose:

```text
determine whether core scheduling or sched_ext is enabled and visible
```

This is mostly metadata. Do not enable sched_ext or change core-scheduling
state just to satisfy this validation. Record whether it is present.

## Post-Run Result Template

After a run, create a new validation result record with:

```text
Status:
  Passed for observation
  or Incomplete
  or Blocked

Kernel:
  uname
  config source
  whether it matches the CapSched worktree

Trace:
  output directory
  runner command
  workload command
  analyzer command

Observed categories:
  table copied or summarized from coverage-summary.md

Ambiguous categories:
  branch/flag questions not answered by no-code tracing

Unobserved categories:
  workload gaps

Decision:
  no-code tracing sufficient for now
  or more synthetic workloads needed
  or dynamic kprobes needed
  or minimal CONFIG_CAPSCHED internal observation patch justified
```

## Acceptance Boundary

Even a successful trace run supports only:

```text
we observed selected Linux runnable-state paths without patching Linux
```

It does not support:

```text
No RunCap, no run
No FrozenRunUse, no runqueue entry
DomainTag activation
monitor-backed protection
hypervisor-grade isolation
```

## Next Decision After Analysis

If many categories are `ambiguous` rather than `observed`, prefer one of:

```text
dynamic kprobe events that capture arguments and branch-specific state
small userspace synthetic workload suite
minimal CONFIG_CAPSCHED internal observation patch
source-only refinement before any patch
```

The default should remain no Linux patch unless the observation gap directly
blocks the next assurance gate.
