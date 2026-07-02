# Implementation 0016: SchedExecLease L0 Implementation Readiness Gate

Status: Ready for implementation design and no-behavior preparation patches;
behavior-changing enforcement patch still requires the vertical-slice design
gate below

Date: 2026-07-02

## Purpose

This gate decides whether the project is ready to move from model-only work
toward Linux implementation work.

It is deliberately stricter than "the code builds." A SchedExecLease patch is
implementation-ready only when it preserves Linux compatibility and does not
smuggle protection claims into a Linux-only prototype.

## Current Verdict

```text
Patch queue replay:                 ready
Source-drift freshness:             ready
Naming and no-ABI surface:          ready
No-behavior scaffold build:         ready
Behavior-changing enforcement:      not approved yet
First implementation design gate:   required and drafted in 0017
```

The next allowed work is design-complete preparation for the first vertical
slice. It is not yet permission to add runtime denial, user ABI, public
tracepoints, monitor ABI, or production protection claims.

## Passed Preconditions

| Gate | Evidence | Result |
| --- | --- | --- |
| Public naming freeze | `analysis/0110`, `traceability/0002` | Passed |
| Linux scaffold rename | Linux commit `3bb2a5821ffdcc0fa6d451cbf259ef82a9ea9a9c` | Passed |
| Targeted build on current tree | `validation/0128` | Passed |
| Patch queue replay | `validation/0129` | Passed |
| Source-drift freshness after rename | `validation/0129` | Passed |
| Overclaim guard | `analysis/0109`, `assurance/claims.json` | Still active |

## Hard Requirements Before Runtime Enforcement

Runtime enforcement may not be implemented until each requirement below has an
implementation placement and validation plan:

| ID | Requirement | Reason |
| --- | --- | --- |
| L0-RDY-001 | `CONFIG_SCHED_EXEC_LEASE=n` remains behavior-compatible | Required for Linux compatibility |
| L0-RDY-002 | `CONFIG_SCHED_EXEC_LEASE=y` starts with default allow-all/root-domain semantics | Avoid accidental denial or ABI dependence |
| L0-RDY-003 | No user ABI, public tracepoint ABI, monitor ABI, syscall, procfs, sysfs, debugfs, or exported symbol | Avoid premature ABI |
| L0-RDY-004 | Fallible admission must occur before `TASK_WAKING` publication or be modeled as nofail/quarantine | `try_to_wake_up()` publishes `TASK_WAKING` before enqueue |
| L0-RDY-005 | `enqueue_task()` is not the first fallible authority hook | It is void and mutates uclamp/class/psi/core state |
| L0-RDY-006 | Final run validation occurs before `rq->curr` publication | Denial after publication breaks scheduler semantics |
| L0-RDY-007 | Denied candidates use bounded retry and ineligibility state | Avoid infinite retry, silent drop, or class-state corruption |
| L0-RDY-008 | Runtime budget subject is donor-aware | `sched_tick()` charges `rq->donor`; proxy execution can split donor and current |
| L0-RDY-009 | Core scheduling cached picks are revalidated | `rq->core_pick` can bypass ordinary fresh selection |
| L0-RDY-010 | sched_ext and proxy execution are explicitly supported, disabled, or fail-closed | They can move or select tasks outside the simple path |
| L0-RDY-011 | Task lifetime and generation storage are fixed before task fields are used | `dup_task_struct()` copies task state and RCU visibility is not authority |
| L0-RDY-012 | fork/clone, exec, and exit identity propagation are connected before runtime authority is consumed | No ambient lease inheritance |
| L0-RDY-013 | cleanup, trace, RCU, cancel, or io_uring/workqueue completion are not revoke receipts | Avoid false revocation evidence |
| L0-RDY-014 | Full `vmlinux` build and QEMU smoke are required before any behavior-changing patch is accepted | Targeted build is not enough for runtime behavior |

## Source Anchors

Key Linux anchors inspected for this gate:

```text
kernel/sched/core.c:2172   enqueue_task()
kernel/sched/core.c:3950   remote wake list publication
kernel/sched/core.c:4251   try_to_wake_up()
kernel/sched/core.c:4357   TASK_WAKING publication
kernel/sched/core.c:4941   wake_up_new_task()
kernel/sched/core.c:5623   sched_exec() placement only
kernel/sched/core.c:5762   sched_tick()
kernel/sched/core.c:6254   core scheduling cached pick
kernel/sched/core.c:7149   pick_next_task()
kernel/sched/core.c:7201   rq->curr publication
kernel/sched/fair.c:1355   fair runtime accounting
kernel/sched/sched.h:1135  rq donor/current state
kernel/fork.c:914          dup_task_struct()
kernel/fork.c:2778         child wake
fs/exec.c:1006             exec pid transfer
fs/exec.c:1131             exec point of no return
kernel/exit.c:924          do_exit()
```

## Implementation Readiness State

The project is now ready to design the first SchedExecLease L0 vertical slice
against current Linux source. It is not yet ready to merge a behavior-changing
enforcement patch.

The next artifact is:

```text
implementation/0017-sched-exec-lease-l0-vertical-slice-design.md
```

## Non-Claims

This gate is not Linux implementation, runtime coverage, monitor verification,
production protection, or cost-efficiency evidence.
