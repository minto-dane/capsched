# Implementation 0006: Slice 0C Trace-Only Observation Gate

Status: Proposed gate, no Linux patch approved yet

Date: 2026-06-26

Linux source:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
current commit: 7cf0b1e415bcead8a2079c8be94a9d41aad7d462
subject: sched/capsched: Add type-only authority scaffolding
```

## Purpose

Slice 0C should observe Linux runnable-state behavior before any scheduler
authority enforcement.

Linked assurance claims:

```text
EXEC-001:
  No CPU execution without runnable authority.

COMPAT-001:
  Linux compatibility is preserved.
```

Linked assurance gate:

```text
G2:
  Trace-only Linux observation.
```

Source input:

```text
capsched-models/analysis/0019-wakeup-enqueue-runnable-coverage.md
```

## Claim Boundary

Slice 0C may support only this claim:

```text
We can observe selected Linux runnable-state paths without changing scheduler
behavior.
```

Slice 0C must not claim:

```text
No RunCap, no run.
No FrozenRunUse, no runqueue entry.
DomainTag activation.
monitor-backed authority.
hypervisor-grade isolation.
```

## Preferred First Step: No-Code Observation

Before patching Linux again, prefer a no-code observation pass using existing
Linux tracing where available:

```text
existing scheduler tracepoints:
  sched_waking
  sched_wakeup
  sched_wakeup_new
  sched_switch

dynamic ftrace function targets:
  try_to_wake_up
  ttwu_runnable
  ttwu_do_activate
  sched_ttwu_pending
  wake_up_new_task
  move_queued_task
  enqueue_task
  __pick_next_task
  pick_next_task
  __schedule
```

This avoids adding new ABI, new tracepoints, or new hot-path calls before the
coverage question is better understood.

## If a Linux Patch Becomes Necessary

A Slice 0C patch may be considered only if existing trace facilities cannot
answer the coverage question.

Allowed patch shape:

```text
CONFIG_CAPSCHED-gated internal observation only
no user ABI
no new public tracepoint ABI unless explicitly re-gated
no task_struct authority fields
no RunCap, SchedContext, or FrozenRunUse layout fields
no wakeup, enqueue, pick, or switch rejection
no scheduler class callback contract changes
no allocation or blocking lookup under scheduler locks
```

Candidate internal observation categories:

```text
wake_current_self
wake_already_runnable
wake_delayed_requeue
wake_local_activate
wake_remote_wakelist
wake_remote_pending_activate
wake_new_task
wake_queued_migration
pick_fair_fast
pick_class_iteration
pick_core_cached
pick_core_force_idle
switch_prev_next
```

The observation vocabulary is deliberately about Linux path shape, not security
authority. It should not use names like `check`, `enforce`, `grant`, or
`activate_domain`.

## Candidate Observation Points

| Category | Source point | Reason |
| --- | --- | --- |
| `wake_current_self` | `try_to_wake_up()` current path around `kernel/sched/core.c:4258` | Wake without enqueue or rq lock. |
| `wake_already_runnable` | `ttwu_runnable()` around `kernel/sched/core.c:3865` | Wake may complete while task is already queued. |
| `wake_delayed_requeue` | `enqueue_task(... ENQUEUE_DELAYED)` at `kernel/sched/core.c:3876` | Fair delayed entity requeue bypasses normal activation. |
| `wake_local_activate` | `ttwu_do_activate()` around `kernel/sched/core.c:3804` | Common local wake activation. |
| `wake_remote_wakelist` | `__ttwu_queue_wakelist()` around `kernel/sched/core.c:3950` | Activation deferred to target CPU. |
| `wake_remote_pending_activate` | `sched_ttwu_pending()` around `kernel/sched/core.c:3891` | Target CPU drains pending remote wakes. |
| `wake_new_task` | `wake_up_new_task()` around `kernel/sched/core.c:4941` | New forked task first becomes runnable. |
| `wake_queued_migration` | `move_queued_task()` around `kernel/sched/core.c:2546` | Queued task moves without new user wake. |
| `pick_fair_fast` | `__pick_next_task()` fast fair path around `kernel/sched/core.c:6132` | Common pick path bypasses class iteration. |
| `pick_class_iteration` | `__pick_next_task()` class loop around `kernel/sched/core.c:6159` | Higher-priority class coverage. |
| `pick_core_cached` | `pick_next_task()` `rq->core_pick` reuse around `kernel/sched/core.c:6254` | Core scheduling can reuse cached picks. |
| `pick_core_force_idle` | `pick_next_task()` force-idle branch around `kernel/sched/core.c:6372` | Runnable tasks can be skipped for co-tenancy. |
| `switch_prev_next` | `__schedule()` around `kernel/sched/core.c:7149` and `7234` | Final CPU-local transition observation. |

## Explicitly Forbidden in Slice 0C

Do not add:

```text
task_struct Domain, RunCap, SchedContext, or FrozenRunUse fields
runqueue rejection
wakeup rejection
pick rejection
budget charging
monitor activation
new syscall, prctl, ioctl, procfs, sysfs, or debugfs ABI
new public tracepoint ABI
BPF or sched_ext security root
LSM policy issuer
workqueue, io_uring, socket, VFS, MM, IOMMU, or driver changes
```

Do not rename observation helpers as enforcement helpers. Forbidden name
fragments include:

```text
capsched_check
capsched_enforce
capsched_authorize
capsched_activate
capsched_grant
capsched_token_validate
```

## Validation Requirements

For no-code observation:

```text
record exact trace commands
record kernel commit and config
record workload
record which paths were observed and which were not observed
record limitations of trace coverage
```

For any future Slice 0C Linux patch:

```text
git diff --check
changed file allowlist review
CONFIG_CAPSCHED=n vmlinux build
CONFIG_CAPSCHED=y vmlinux build
disabled-config no capsched observation object or calls, unless explicitly
  justified by Kconfig shape
forbidden-name grep
no new user ABI review
runtime smoke only if build passes
```

## Exit Criteria

Slice 0C exits successfully only when it produces a coverage record answering:

```text
Which wake/enqueue/pick/switch categories were observed?
Which categories remained unobserved under the workload?
Which categories need synthetic tests?
Which categories would be unsafe for future enforcement?
Where would a future last-chance pick/switch validation need to sit?
```

This exit does not approve enforcement. It only supports the next gate:

```text
Runnable-state model refinement
or
Slice 0D minimal debug-only Domain shadow identity observation
or
return to source analysis if trace coverage is insufficient
```

## Current Recommendation

Do not patch Linux yet.

First, prepare a no-code trace run plan using existing scheduler tracepoints and
dynamic ftrace. If that cannot observe enough of the categories above, then
draft a minimal CONFIG_CAPSCHED-gated Linux observation patch under a new gate.
