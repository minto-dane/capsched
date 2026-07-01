# Analysis 0096: F1 Admission-Freeze Refresh

Status: Draft model gate with TLC-backed design filter; no implementation
approved

Date: 2026-07-01

## Purpose

This note refreshes `analysis/0031` against the current upstream scheduler
source and turns the F1 wakeup boundary into a stronger implementation-facing
design filter.

The rule is:

```text
Fail-capable runnable authority resolution must finish before Linux publishes
an irreversible wakeup/enqueue state.
```

After that publication, CapSched may perform only bounded, nofail, cheap
freshness validation of already-frozen authority. It must not discover new
authority, allocate the frozen-use object, call the monitor to mint authority,
walk policy, or return an ordinary late denial that breaks Linux wakeup
semantics.

## Source Basis

Current Linux source:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
work commit: 7cf0b1e415bcead8a2079c8be94a9d41aad7d462
upstream ref: 665159e246749578d4e4bfe106ee3b74edcdab18
upstream freshness: `git fetch upstream master` on 2026-07-01 observed 0 commits after this ref
```

Key source anchors:

| Surface | Current upstream anchor | CapSched meaning |
| --- | --- | --- |
| `try_to_wake_up()` contract | `kernel/sched/core.c:4215` through `:4250` | wakeup is state change plus optional enqueue |
| `p->pi_lock` stabilized fields | `kernel/sched/core.c:4231` through `:4237` | F1 can rely on local scheduler fields, not arbitrary policy walks |
| current/self wake path | `kernel/sched/core.c:4258` through `:4283` | continuation path, not a new RunCap mint |
| F1 state match | `kernel/sched/core.c:4292` through `:4298` | fail-capable check window exists before publication |
| already-runnable path | `kernel/sched/core.c:4322` through `:4324` | runnable continuation path may complete without enqueue |
| `TASK_WAKING` publication | `kernel/sched/core.c:4351` through `:4357` | primary irreversible wake publication boundary |
| remote wake-list publication | `kernel/sched/core.c:4378` through `:4380` | after `TASK_WAKING`, remote activation can be delegated |
| post-publication CPU selection | `kernel/sched/core.c:4393` | placement must refine frozen envelope, not mint authority |
| post-publication CPU write | `kernel/sched/core.c:4400` through `:4402` | migration is state mutation after wake publication |
| post-publication queue | `kernel/sched/core.c:4415` | enqueue path must consume pre-frozen authority |
| `select_task_rq()` lock contract | `kernel/sched/core.c:3610` through `:3636` | placement is constrained by stable `p->cpus_ptr` and fallback |
| activation path | `kernel/sched/core.c:3805` through `:3827` | `activate_task()` precedes final `TASK_RUNNING` wake completion |
| `ttwu_runnable()` delayed enqueue | `kernel/sched/core.c:3865` through `:3888` | already queued/delayed state cannot become authority mint |
| pending remote wake activation | `kernel/sched/core.c:3891` through `:3912` | remote wakelist consumer does activation later |
| wakelist publish helper | `kernel/sched/core.c:3950` through `:3960` | wake entry is a Linux carrier, not authority |
| queued wake condition | `kernel/sched/core.c:4005` through `:4027` | CPU allowance check narrows placement only |
| `ttwu_queue()` activation | `kernel/sched/core.c:4067` through `:4078` | local queue path is post-publication activation |
| `wake_up_new_task()` | `kernel/sched/core.c:4935` through `:4964` | initial runnable publication must be SpawnCap/admission frozen before enqueue |
| wake queue readiness note | `include/linux/sched/wake_q.h:31` through `:33` | task must be ready at `wake_q_add()` time |
| `wake_q_add()` contract | `kernel/sched/core.c:1116` through `:1125` | wake queue is used as if `wake_up_process()` |
| `wake_up_q()` execution | `kernel/sched/core.c:1156` through `:1173` | later wake call cannot be first authority discovery |

## Refreshed Boundary

The F1 boundary remains the interval inside `try_to_wake_up()` where
`p->pi_lock` is held, state matching has succeeded, and `TASK_WAKING` has not
yet been written:

```text
p->pi_lock held
  -> ttwu_state_match() success
  -> already-runnable shortcut considered
  -> smp_acquire__after_ctrl_dep()
  -> before WRITE_ONCE(p->__state, TASK_WAKING)
```

The important refinement is that F1 is not the only publication surface. A
future CapSched hook must also classify:

```text
TASK_WAKING:
  primary irreversible wake publication for sleeping tasks

remote wake_list:
  delegated activation after TASK_WAKING

enqueue-visible runqueue state:
  activation through ttwu_do_activate(), activate_task(), enqueue_task()

wake_q:
  earlier logical readiness requirement before wake_up_q()

wake_up_new_task():
  initial runnable publication without TASK_WAKING

already-runnable/current continuation:
  no new authority mint; relies on existing running or queued authority
```

## Required Frozen Tuple

Before any wake/enqueue publication that can make a task executable, CapSched
must have a frozen tuple containing at least:

```text
TaskGeneration
ProcessGeneration, where process-level authority is relevant
DomainId or Domain pointer shadow
DomainEpoch
RunCap-derived authority id and epoch
SchedContext id and epoch
PlacementSnapshot
MonitorRootBudget or root-budget ticket reference
FrozenRunUse storage identity
Evidence class / mode bits that prevent L0 protection overclaim
```

The frozen tuple must not contain a raw mutable capability-table handle whose
meaning can be reinterpreted after publication.

## Hard Rule

```text
Authority discovery before publication.
Cheap freshness validation after publication.
```

Allowed before publication:

```text
bounded local reads of task-local or pre-pinned fields
epoch/generation comparisons
checking an already-available SchedContext pointer/id
checking an already-available placement envelope
checking an already-available root-budget ticket reference
writing an embedded or preallocated FrozenRunUse
rejecting without publishing TASK_WAKING or enqueue-visible state
```

Rejected before publication:

```text
allocation under p->pi_lock
sleeping
LSM/namespace/cgroup/BPF policy walks for authority issuance
remote cluster lease acquisition
monitor calls to mint fresh authority
slow refs that can depend on reclaim
new global mutable capability-table lookup
```

Rejected after publication:

```text
raw cap lookup
raw cap handle interpretation
monitor call to mint RunToken
ordinary -EPERM/-EAGAIN denial that loses the wakeup
placement/cpuset/hotplug result treated as authority
worker/current identity treated as authority
fork/clone initial runnable state treated as ambient authority
trace/TLC evidence treated as protection
```

## Path Classification

| Path | Linux behavior | CapSched requirement |
| --- | --- | --- |
| sleeping task wake | writes `TASK_WAKING`, selects CPU, queues task | freeze before `TASK_WAKING`; later path uses cheap validation |
| remote wakelist | stores task wake entry after `TASK_WAKING` | no raw cap in `wake_entry`; frozen tuple must already exist |
| local `ttwu_queue()` | activates under rq lock | no fail-capable authority discovery at activation |
| `wake_q_add()`/`wake_up_q()` | wake may logically happen at add time | authority readiness must exist at `wake_q_add()`; `wake_up_q()` is not discovery |
| `wake_up_new_task()` | sets `TASK_RUNNING`, selects CPU, enqueues | SpawnCap/admission freeze must precede initial runnable publication |
| `p == current` wake | clears blocked state and sets running | continuation of current authority, not new RunCap mint |
| `ttwu_runnable()` | already queued task made running, maybe delayed reenqueue | existing queued/running authority or pre-frozen continuation only |
| placement fallback/hotplug | chooses valid Linux CPU | placement constrains execution; it cannot mint authority |

## Lost-Wakeup Constraint

After `TASK_WAKING` has been written, Linux has committed to completing the
wake path through local or remote activation. A late CapSched failure must not
drop the task on the floor or silently consume a wakeup.

This means the model admits only two broad shapes:

```text
fail before publication:
  no TASK_WAKING, no wake_list, no enqueue-visible state

stale after publication:
  no new authority is minted; execution is stopped by cheap freshness
  validation, throttling, or monitor fail-closed activation without losing the
  Linux wakeup bookkeeping
```

The second shape is not an approval to enqueue without authority. It is a
requirement to preserve Linux's wakeup accounting while refusing execution
until a valid frozen use exists again.

## Interaction With Earlier Gates

This refresh composes with:

```text
analysis/0089:
  TASK_WAKING requires pre-frozen authority

analysis/0090:
  runtime charge subject must be explicit

analysis/0091 and analysis/0094:
  server-borrow tickets require fresh server epoch

analysis/0093:
  monitor root budget/timer is the production CPU root

analysis/0095:
  deadline CBS/GRUB state is compatibility policy, not authority
```

## Model

New model:

```text
formal/0074-f1-admission-freeze-refresh-model/
```

Checked invariants:

```text
NoTaskWakingWithoutFrozenUse
NoWakeListWithoutFrozenUse
NoEnqueueWithoutFrozenUse
NoRunWithIncompleteFrozenUse
NoRunWithoutCheapValidation
NoRawCapHandleAfterPublication
NoHeavyLookupAfterPublication
NoLateDenyLostWake
NoPlacementAsAuthority
NoCurrentContinuationMint
NoForkAmbientAuthority
NoProtectionClaim
```

## Hard Rejections

Reject:

```text
TASK_WAKING before FrozenRunUse
wake_list publication before FrozenRunUse
enqueue-visible activation before FrozenRunUse
running with missing generation, Domain epoch, SchedContext, placement, or root
  budget ticket
raw mutable cap handle carried past wake publication
slow authority lookup after TASK_WAKING, wake_list, or enqueue-visible state
late denial that loses the Linux wakeup
placement/cpuset/hotplug result treated as RunCap authority
current/self-wake continuation treated as new authority mint
fork/clone initial runnable state treated as ambient authority
protection claim without implementation and monitor evidence
```

## Non-Claims

This note does not approve a Linux hook, task field, scheduler behavior change,
public ABI, monitor call ABI, tracepoint ABI, runtime coverage result, monitor
verification, or production protection.
