# Analysis 0021: Slice 0C Observation Synthesis and Hook-Placement Constraints

Status: Draft synthesis, no implementation approved

Date: 2026-06-27

Linux source:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
commit: 7cf0b1e415bcead8a2079c8be94a9d41aad7d462
subject: sched/capsched: Add type-only authority scaffolding
```

## Purpose

This note synthesizes Slice 0C source reading, QEMU tracing, and guest-side
kprobe evidence into constraints for the first future CapSched scheduler hook.

It does not approve a Linux behavior patch.

It originally pointed toward the next modeling step:

```text
Linux-runnable hook-placement model
```

The purpose of that next model is to decide whether a future Linux patch can
start with a small observation/default-permissive runnable lease scaffold, or
whether more internal observation is required before touching scheduler control
flow.

After behavior-tagging review, do not jump directly from this synthesis to the
hook-placement model. First create schema v2 for behavior tags so mechanical
selection cannot confuse observation, Linux-only enforcement, monitor-backed
authority, performance benefit, or production security evidence.

## Inputs

Source and design:

```text
analysis/0019-wakeup-enqueue-runnable-coverage.md
analysis/0020-qemu-ftrace-symbol-eligibility.md
implementation/0006-slice0c-trace-observation-gate.md
```

Runtime evidence:

```text
validation/0021-slice0c-qemu-boot-smoke-result.md
validation/0022-slice0c-qemu-broader-workload-result.md
validation/0023-slice0c-qemu-kprobe-observation-result.md
```

Linux source anchors:

```text
kernel/sched/core.c
kernel/sched/sched.h
```

## Evidence Boundary

Validated so far:

```text
The CapSched worktree kernel boots under QEMU.
CONFIG_CAPSCHED=y coexists with scheduler tracing.
fork/exec, futex cross-CPU wake, affinity migration, pressure, and combined
  workloads complete with WORKLOAD_RET 0.
guest-side kprobe events can capture selected scheduler function arguments.
enqueue_task() flags are visible for wake, migration, initial, restore, and
  rq-selected enqueue categories.
one successful affinity serial log observed ENQUEUE_DELAYED | ENQUEUE_NOCLOCK.
move_queued_task(new_cpu) is observable under affinity migration.
```

Not validated:

```text
RunCap enforcement
FrozenRunUse creation
SchedContext budget enforcement
DomainTag activation
monitor-backed protection
cross-Domain isolation
hypervisor-grade claims
```

## Source Facts That Constrain Hook Placement

### `enqueue_task()` Is Central But Already Mutates State

`enqueue_task()` is the generic scheduler-class enqueue wrapper:

```text
kernel/sched/core.c:2172
```

It updates rq clock, uclamp, scheduler-class state, PSI, sched_info, and core
scheduling state. It returns `void`.

Implication:

```text
enqueue_task() is an excellent observation point and future nofail assertion
point.

It is a poor first fail-capable enforcement point unless the surrounding call
sites are also redesigned, because there is no return path and partial
accounting mutation would be dangerous.
```

### `activate_task()` Is Common But Not Complete

`activate_task()` calls `enqueue_task()` and then sets:

```text
p->on_rq = TASK_ON_RQ_QUEUED
```

Source:

```text
kernel/sched/core.c:2219
```

It covers common wake activation, new task activation, and queued migration
reactivation. It does not cover every execution-relevant transition.

### `ttwu_runnable()` Can Complete a Wake Without Normal Activation

`ttwu_runnable()` handles the already-on-runqueue case:

```text
kernel/sched/core.c:3865
```

If the task is already queued, it may only run wake/preempt logic and
`ttwu_do_wakeup()`. If fair delayed state is present, it can call:

```text
enqueue_task(rq, p, ENQUEUE_NOCLOCK | ENQUEUE_DELAYED)
```

Source:

```text
kernel/sched/core.c:3876
```

Implication:

```text
An activate_task-only hook misses a meaningful runnable path.
An enqueue_task observer can see delayed requeue, but not all already-runnable
wake completions.
```

### Current Self-Wake Is Not Enqueue Authority

`try_to_wake_up()` has a `p == current` path:

```text
kernel/sched/core.c:4251
```

That path clears blocked state and calls `ttwu_do_wakeup()` without normal
runqueue enqueue. The task is already the current execution context.

Implication:

```text
self-wake current is not "submit a task to the runqueue".
It should be modeled as continued current-execution authority, not as a new
RunCap enqueue operation.
```

### Remote Wake Has a Pending State

Remote wake may queue a task on the target CPU wake list:

```text
__ttwu_queue_wakelist(): kernel/sched/core.c:3950
sched_ttwu_pending():    kernel/sched/core.c:3891
ttwu_queue():            kernel/sched/core.c:4067
```

The target CPU later drains the pending list and calls `ttwu_do_activate()`.

Implication:

```text
future revocation and epoch changes must account for remote-pending wake state.
Checking only at final enqueue may be enough for execution admission, but it
does not by itself model pending work lifetime.
```

### New Task Wake Is Spawn Authority Plus Runnable Authority

`wake_up_new_task()` sets the new task running, selects a CPU, then calls:

```text
activate_task(rq, p, ENQUEUE_NOCLOCK | ENQUEUE_INITIAL)
```

Source:

```text
kernel/sched/core.c:4941
```

Implication:

```text
new task runnable admission cannot be treated as ordinary wake only.
It depends on SpawnCap, inherited/attenuated authority, task generation, and an
initial FrozenRunUse.
```

### Queued Migration Is Placement Refresh, Not New User Authority

`move_queued_task()` deactivates a queued task, updates CPU, locks destination
rq, and reactivates:

```text
kernel/sched/core.c:2546
```

The affinity kprobe run observed `move_queued_task(new_cpu)` under the
synthetic affinity workload.

Implication:

```text
queued migration should not mint new RunCap authority.
It must refresh or revalidate the CPU placement portion of an existing frozen
run use.
```

### Pick/Switch Is Final Execution Selection

`__pick_next_task()` has a fair fast path and class iteration:

```text
kernel/sched/core.c:6124
```

`pick_next_task()` has core-scheduling behavior when `CONFIG_SCHED_CORE=y`:

```text
kernel/sched/core.c:6216
```

In the current QEMU config, `CONFIG_SCHED_CORE=n`, so the simple wrapper is
optimized away. `__schedule()` is:

```text
static void __sched notrace __schedule(int sched_mode)
```

Source:

```text
kernel/sched/core.c:7061
```

It picks `next`, assigns `rq->curr`, traces the switch, and calls
`context_switch()`.

Implication:

```text
pick/switch is the last chance to validate that the chosen task still carries
live execution authority.

It is also the natural Linux-side place to request monitor DomainTag activation
when prev and next differ in a monitor-backed design.

It cannot be the only RunCap hook, because it would not prove "No FrozenRunUse,
no runqueue entry".
```

## Runtime Evidence From Slice 0C

Broader QEMU workloads showed:

```text
futex cross:
  high-volume try_to_wake_up, ttwu_do_activate, sched_ttwu_pending,
  enqueue_task, sched_wakeup, and sched_switch counts.

affinity:
  move_queued_task, sched_migrate_task, wake_up_new_task, enqueue_task,
  and kprobe move_queued_task(new_cpu) evidence.

pressure:
  scheduler pressure and lifecycle events.

all:
  combined wake, switch, migration, and lifecycle coverage.
```

Guest-side kprobe showed:

```text
enqueue_task flags can distinguish multiple enqueue categories.
try_to_wake_up entry wake_flags are visible.
ttwu_do_activate downstream wake_flags are visible.
move_queued_task new_cpu is visible.
```

Unresolved due to symbol/ftrace shape:

```text
ttwu_runnable
__ttwu_queue_wakelist
ttwu_queue
__pick_next_task
pick_next_task
__schedule function entry
CONFIG_SCHED_CORE branches
```

## Synthesis: A Single Hook Is Not Enough

The future design should not ask "where is the one scheduler hook?"

The correct question is:

```text
Which transitions create, preserve, refresh, select, and activate execution
authority?
```

That yields at least four roles:

| Role | Meaning | Candidate Linux region | Enforcement shape |
| --- | --- | --- | --- |
| Admission/freeze | Create or refresh a FrozenRunUse before a task becomes queued. | Callers before `enqueue_task()` mutation, including wake/new-task/migration paths. | Eventually fail-capable, but only after return/error semantics are modeled. |
| Enqueue assertion | Assert that a queued entry has a frozen authority record matching flags and CPU. | `enqueue_task()` or immediately adjacent wrappers. | Nofail assertion/trace first; no return-value enforcement initially. |
| Pick validation | Check the chosen task still has live epoch, generation, CPU, and budget authority. | `pick_next_task()` / `__schedule()` vicinity. | Cheap no-sleep validation; failure semantics must be separately modeled. |
| Switch activation | Activate DomainTag/MemoryView when crossing Domains. | After final `next` selection, before execution resumes. | Trace-only in L0; monitor call in CapSched-H. |

This is the central Slice 0C conclusion:

```text
enqueue admission and final execution selection are different security events.
```

Conflating them would either miss runqueue authority or force a dangerous
late-scheduling rejection path.

## Candidate Future Hook Model

This is not approved implementation. It is the next model target.

The model should include these abstract events:

```text
FreezeWakeRunUse(task, cpu, flags, cause)
FreezeNewTaskRunUse(task, cpu, spawn_generation)
RefreshMigrationRunUse(task, old_cpu, new_cpu)
AssertEnqueueHasFrozenUse(task, cpu, flags)
ValidatePick(task, cpu)
SwitchDomain(prev, next)
ChargeRunningBudget(task, delta)
RevokeDomain(domain, epoch)
```

Where `cause` is at least:

```text
normal_wake
remote_pending_wake
already_runnable_delayed_requeue
new_task
queued_migration
class_restore
```

The model should explicitly treat these as non-equivalent:

```text
self_current_wake
already_runnable_wake_without_enqueue
queued_migration
new_task_initial_enqueue
normal blocked-to-runnable wake
pick/switch execution
```

## Modeling Requirements Before Enforcement

The next formal model or executable semantic model must prove at least:

```text
NoQueuedWithoutFrozenUse:
  Every queued task requiring CapSched authority has a live FrozenRunUse.

NoPickWithoutLiveFrozenUse:
  A picked non-idle task requiring CapSched authority has a live FrozenRunUse
  matching task generation, process generation, domain epoch, CPU, and budget.

MigrationDoesNotMintAuthority:
  Queued migration refreshes placement but does not create broader authority.

SelfWakeDoesNotMintRunCap:
  Current self-wake does not create a new RunCap or bypass current execution
  authority.

RevocationInvalidatesPendingAndQueued:
  Domain/run-cap epoch revoke invalidates pending remote wake, queued frozen
  uses, and future picks.

SwitchRequiresActivation:
  Cross-Domain switch requires active DomainTag/MemoryView activation in the
  monitor-backed model.
```

The model must also contain explicit failure semantics. It is not enough to say
"reject enqueue" because Linux wakeup code often has already changed task state
or is holding scheduler locks.

## Compatibility Constraints

Any future Linux patch must respect:

```text
no allocation under rq locks or p->pi_lock
no sleeping under scheduler locks
no slow capability-table lookup in hot wakeup or pick paths
no public ABI in observation slices
CONFIG_CAPSCHED=n behavior unchanged
CONFIG_CAPSCHED=y initial behavior default-permissive until explicitly gated
no scheduler class callback contract changes without a separate gate
no raw RunCap handle stored as runqueue authority
```

The likely implementation pattern, if later approved, is:

```text
slow path:
  resolve and freeze authority before or at admission boundaries

hot path:
  compare already-frozen generation, epoch, CPU, and budget fields

switch path:
  activate only when DomainTag changes
```

## What The Current Evidence Allows

Allowed conclusion:

```text
Slice 0C has enough evidence to build a Linux-runnable hook-placement model.
```

Not allowed:

```text
Slice 0C proves the final hook placement.
Slice 0C proves RunCap enforcement.
Slice 0C proves protection.
Slice 0C proves all CONFIG_SCHED_CORE co-tenancy behavior.
```

More generic workload pressure is unlikely to solve the remaining named-symbol
gaps. The unresolved categories require either:

```text
source-local internal observation
different debug/config build shape
or conservative modeling that treats the path as possible even if not observed
```

For security, conservative modeling is preferable to pretending an unobserved
optimized-away helper does not exist.

## Decision

Do not add RunCap enforcement yet.

Do not add a behavior-changing Linux scheduler patch yet.

Next artifact should be schema v2, then a model:

```text
analysis/behavior-tags/schema-v2-requirements.json
```

After that, the model target remains:

```text
formal/0012-linux-runnable-hook-placement-model/
```

That model should refine the earlier `RunnableLease` model with Linux path
classes from this note. It should decide whether the first implementation slice
can be:

```text
CONFIG_CAPSCHED=y default-permissive FrozenRunUse scaffolding plus observation
```

or whether one more internal observation-only Linux patch is required first for:

```text
ttwu_runnable
remote wakelist enqueue
pick fast path / class iteration
CONFIG_SCHED_CORE cached and force-idle branches
```

## Current Recommendation

Proceed to schema v2 and then the hook-placement model before writing Linux
scheduler behavior code.

If a Linux patch is needed before that model passes, it must be observation-only
and must be justified by a specific unobservable path in this synthesis.
