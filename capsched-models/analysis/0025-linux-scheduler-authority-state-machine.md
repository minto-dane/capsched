# Analysis 0025: Linux Scheduler Authority State Machine

Status: Draft state machine, source-only refresh applied, no implementation approved

Date: 2026-06-27

Updated: 2026-07-01

Linux source:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
commit: 7cf0b1e415bcead8a2079c8be94a9d41aad7d462
source refresh ref: upstream/master 665159e246749578d4e4bfe106ee3b74edcdab18
refresh gate: validation/0103, validation/0104
```

## Source-Only Refresh 2026-07-01

This refresh updates the scheduler authority map against current
`upstream/master` without changing Linux code.

Current upstream anchors:

| Authority transition | Current upstream anchor |
| --- | --- |
| Generic enqueue custody | `kernel/sched/core.c:2172 enqueue_task()` |
| Activate task into runqueue custody | `kernel/sched/core.c:2219 activate_task()` |
| Delayed queued wake | `kernel/sched/core.c:3865 ttwu_runnable()` |
| Wake activation | `kernel/sched/core.c:3805 ttwu_do_activate()` |
| Wake queue dispatch | `kernel/sched/core.c:4067 ttwu_queue()` |
| Normal wake admission | `kernel/sched/core.c:4251 try_to_wake_up()` |
| New task initial wake | `kernel/sched/core.c:4941 wake_up_new_task()` |
| CPU placement selection | `kernel/sched/core.c:3614 select_task_rq()` |
| CPU placement compatibility | `kernel/sched/core.c:2501 is_cpu_allowed()` |
| Queued migration | `kernel/sched/core.c:2546 move_queued_task()` |
| Migration stopper | `kernel/sched/core.c:2611 migration_cpu_stop()` |
| Runtime read freshness | `kernel/sched/core.c:5674 task_sched_runtime()` |
| Tick/runtime pressure | `kernel/sched/core.c:5762 sched_tick()` |
| Selected use | `kernel/sched/core.c:6124 __pick_next_task()` |
| Switch activation boundary | `kernel/sched/core.c:7061 __schedule()` |
| Public schedule entry | `kernel/sched/core.c:7316 schedule()` |

Refreshed source observations:

```text
enqueue_task() remains void and mutates uclamp, class enqueue, PSI,
sched_info, and sched_core state. It is still an assertion/refinement point,
not a safe fail-capable hook without rollback modeling.

activate_task() calls enqueue_task() before writing p->on_rq =
TASK_ON_RQ_QUEUED. A future CapSched hook must not treat on_rq alone as proof
that authority was frozen.

try_to_wake_up() still has a current-task special case that avoids normal
enqueue custody and must remain CurrentContinuation, not new RunCap admission.

try_to_wake_up() still writes TASK_WAKING before the queue/activation path.
Any fail-capable admission after that point requires a lost-wakeup and rollback
model.

ttwu_runnable() still handles already-queued tasks and can re-enqueue delayed
state with ENQUEUE_DELAYED. This is not authority minting.

sched_tick() accounts through rq->donor. Any budget model that charges only
rq->curr is stale.

__pick_next_task() still has fair fast path, RETRY_TASK restart, active class
iteration, sched_ext interaction, and put_prev_set_next_task() before return.

__schedule() remains the switch-commit region where fail-closed DomainTag and
MemoryView activation must be modeled before behavior-changing patches.
```

This refresh does not approve a Linux patch. It only updates the source-map
contract for the next scheduler authority modeling step.

## Purpose

This note maps Linux scheduler behavior into a CapSched authority state machine.

It exists before schema v2 and before any behavior-changing Linux patch because
tags must be derived from authority semantics, not from convenient hook
locations.

This note is not an implementation approval.

## Authority Objects

The scheduler-facing objects are:

```text
TaskIdentity:
  task pointer, task generation, process generation

Domain:
  domain id, domain epoch, authority root, MemoryView root

RunCap:
  authority to submit a specific task/thread for runnable execution

SchedContext:
  CPU-time and placement resource object

FrozenRunUse:
  enqueue/admission-time frozen execution use

RunQueueCustody:
  Linux scheduler custody of a runnable or pending task

SelectedUse:
  task chosen by scheduler class logic but not yet switched to

ActiveExecution:
  CPU running a task under an active DomainTag/MemoryView context

BudgetLedger:
  remaining SchedContext/root budget and charging state
```

## Abstract States

Use these CapSched abstract states for local scheduler execution:

```text
Blocked:
  not runnable, no runqueue custody

CurrentContinuation:
  current task remains the running context and may clear blocked state

RemotePendingWake:
  wake request is queued on a target CPU wake list, not yet activated

FrozenRunnable:
  authority has been frozen for runnable custody

Queued:
  task is on a Linux runqueue under a FrozenRunUse

DelayedQueued:
  task remains queued or delayed in class-specific state

MigratingQueued:
  task is being moved between runqueues under existing authority

Selected:
  task has been chosen for execution but context switch is not committed

Running:
  task executes on a CPU under active DomainTag and budget authority

Quarantined:
  future enforcement state for failed validation before execution

Dead:
  task is exiting or gone; frozen uses must be invalidated
```

Linux does not currently implement these CapSched states. They are the semantic
states future patches and models must refine.

## State Transition Map

### Current Self-Wake

Linux path:

```text
try_to_wake_up(): kernel/sched/core.c:4251
p == current path: kernel/sched/core.c:4258
ttwu_do_wakeup(): kernel/sched/core.c:4282
```

CapSched transition:

```text
Running or CurrentContinuation
  -> CurrentContinuation
```

Authority meaning:

```text
does not mint RunCap
does not create new runqueue custody
does not create a new FrozenRunUse
may preserve already-active execution authority
```

Hard rule:

```text
NoSelfWakeMintRunCap
```

Why:

The Linux path intentionally avoids the normal runqueue enqueue path because
`p == current` already runs on the current CPU. Treating this as a fresh
RunCap submission would confuse continued execution with admission.

### Already-Runnable Wake

Linux path:

```text
ttwu_runnable(): kernel/sched/core.c:3865
task_on_rq_queued() test: kernel/sched/core.c:3870
delayed fair requeue: kernel/sched/core.c:3875
ttwu_do_wakeup(): kernel/sched/core.c:3887
```

CapSched transition:

```text
Queued or DelayedQueued
  -> Queued or DelayedQueued
```

Authority meaning:

```text
does not create a new RunCap
must not extend authority lifetime
may require revalidation if delayed class state is re-enqueued
may trigger preemption decisions
```

Hard rules:

```text
NoAlreadyQueuedWakeMintRunCap
NoDelayedQueuedUseWithoutLiveFrozenUse
```

Open modeling point:

Delayed requeue must say whether it requires a fresh placement/budget check, or
whether the original FrozenRunUse remains live and sufficient.

### Normal Wake Admission

Linux path:

```text
try_to_wake_up(): kernel/sched/core.c:4251
TASK_WAKING write: kernel/sched/core.c:4357
select_task_rq(): kernel/sched/core.c:4393
ttwu_queue(): kernel/sched/core.c:4067
ttwu_do_activate(): reached through ttwu_queue()
activate_task(): kernel/sched/core.c:2219
enqueue_task(): kernel/sched/core.c:2172
```

CapSched transition:

```text
Blocked
  -> FrozenRunnable
  -> Queued
```

Authority meaning:

```text
RunCap and SchedContext must be resolved before executable runqueue custody
FrozenRunUse binds task generation, process generation, domain epoch,
  SchedContext epoch, CPU placement, and budget authority
Linux TASK_WAKING is not authority by itself
```

Hard rules:

```text
NoRunCapNoFrozenRunnable
NoSchedContextNoFrozenRunnable
NoQueuedWithoutFrozenUse
NoLinuxMutableStateAsProductionRoot
```

Failability warning:

Once Linux writes `TASK_WAKING`, a future fail-capable CapSched rejection must
prove it can avoid lost wakeups, stuck tasks, and broken ordering. The safer
first model is to freeze authority before entering non-rollback Linux wake
mutation or to use nofail assertions after mutation.

### Remote Pending Wake

Linux path:

```text
ttwu_queue_wakelist(): kernel/sched/core.c:4056
__ttwu_queue_wakelist(): kernel/sched/core.c:3950
sched_ttwu_pending(): kernel/sched/core.c:3891
ttwu_do_activate(): kernel/sched/core.c:3911
```

CapSched transition:

```text
Blocked
  -> RemotePendingWake
  -> FrozenRunnable
  -> Queued
```

Authority meaning:

```text
pending wake is not execution authority
pending wake carries revocation exposure
final activation must check or consume a live frozen authority
domain or task epoch revoke must stop stale pending wake before execution
```

Hard rules:

```text
NoRemotePendingEscape
RevocationInvalidatesRemotePendingBeforeActivation
NoRemoteAuthorityInSchedulerHotPath
```

Cluster rule:

Remote CPU wake within a node is not the same as cluster-remote authority. A
multi-cluster lease must already be compiled into local sealed authority before
Linux scheduler hot paths see it.

### New Task Wake

Linux path:

```text
wake_up_new_task(): kernel/sched/core.c:4941
state set TASK_RUNNING: kernel/sched/core.c:4948
CPU selection: kernel/sched/core.c:4958
activate_task(... ENQUEUE_INITIAL): kernel/sched/core.c:4963
```

CapSched transition:

```text
Spawned
  -> FrozenRunnable
  -> Queued
```

Authority meaning:

```text
SpawnCap and inherited/attenuated authority are involved
new task generation must be issued
initial FrozenRunUse must bind the child identity
ordinary wake RunCap is not sufficient by itself
```

Hard rules:

```text
NoSpawnWithoutSpawnCap
NoInheritedAmbientRunAuthority
NoInitialQueueWithoutChildFrozenUse
```

### Queued Migration

Linux path:

```text
move_queued_task(): kernel/sched/core.c:2546
deactivate_task(): kernel/sched/core.c:2552
set_task_cpu(): kernel/sched/core.c:2553
activate_task(): kernel/sched/core.c:2560
```

CapSched transition:

```text
Queued
  -> MigratingQueued
  -> Queued
```

Authority meaning:

```text
migration refreshes placement authority
migration must not mint broader RunCap authority
CPU mask and allowed placement must be revalidated or remain proven valid
```

Hard rules:

```text
NoMigrationMintAuthority
NoCPUOutsideFrozenPlacement
NoMigrationAcrossRevokedDomain
```

Linux compatibility note:

`is_cpu_allowed()` includes hotplug, migrate-disabled, kthread, and per-CPU
kthread exceptions around `kernel/sched/core.c:2501`. CapSched CPU authority
must refine these rules rather than replace them with a simpler cpumask.

### Generic Enqueue Custody

Linux path:

```text
enqueue_task(): kernel/sched/core.c:2172
uclamp_rq_inc(): kernel/sched/core.c:2182
sched_class->enqueue_task(): kernel/sched/core.c:2184
psi_enqueue(): kernel/sched/core.c:2186
sched_info_enqueue(): kernel/sched/core.c:2189
sched_core_enqueue(): kernel/sched/core.c:2192
activate_task sets on_rq: kernel/sched/core.c:2226
```

CapSched transition:

```text
FrozenRunnable
  -> Queued
```

Authority meaning:

```text
excellent observation point
excellent future nofail assertion point
poor first fail-capable rejection point
```

Hard rules:

```text
NoEnqueueWithoutFrozenUse
NoFailAfterIrreversibleAccountingWithoutRollbackModel
```

Why fail-capable enforcement is risky:

`enqueue_task()` returns `void` and already mutates uclamp, scheduler class,
PSI, sched_info, and core scheduling state before the task is considered fully
queued by `activate_task()`. A rejection here needs a precise rollback model for
every scheduler class and accounting path, or it must be nofail.

### Pick

Linux path:

```text
__pick_next_task(): kernel/sched/core.c:6124
fair fast path: kernel/sched/core.c:6141
pick_task_fair(): kernel/sched/core.c:6144
put_prev_set_next_task(): kernel/sched/core.c:6152
scheduler class loop: kernel/sched/core.c:6156
```

CapSched transition:

```text
Queued
  -> Selected
```

Authority meaning:

```text
must validate live FrozenRunUse before execution
must validate task/process generation and domain epoch
must validate CPU placement and budget availability
must not mutate class state in a way that cannot be retried safely
```

Hard rules:

```text
NoPickWithoutLiveFrozenUse
NoPickAfterEpochMismatch
NoPickWithoutBudget
NoPickRetryAfterClassMutationWithoutModel
```

Failure-action warning:

Pick-time failure cannot be hand-waved as "choose another task" unless the
model proves scheduler class accounting, `put_prev_set_next_task()`, core
scheduling cached pick state, sched_ext state, and proxy execution state remain
consistent.

### Switch Activation

Linux path:

```text
__schedule(): kernel/sched/core.c:7061
pick_next_task(): kernel/sched/core.c:7149
rq->curr publish: kernel/sched/core.c:7201
trace_sched_switch(): kernel/sched/core.c:7231
context_switch(): kernel/sched/core.c:7234
```

CapSched transition:

```text
Selected
  -> Running
```

Authority meaning:

```text
cross-Domain switch requires DomainTag/MemoryView activation
monitor-backed production must fail closed if activation cannot be proven
same-Domain switch should avoid monitor transition when still valid
```

Hard rules:

```text
NoSwitchWithoutDomainActivation
NoLinuxShadowDomainTagAsAuthority
NoSwitchActivationFailureWithoutFailClosedModel
```

Ordering warning:

`rq->curr` publication and membarrier constraints around
`kernel/sched/core.c:7201` make late failure particularly dangerous. A
monitor-backed activation failure after Linux commits to `next` needs a
specific fail-closed action such as refusing the CPU transition, selecting idle
before commit, or isolating the CPU. It cannot be an ordinary error return.

### Budget Charge

Linux path:

```text
tick and scheduler accounting paths, not yet mapped in Slice 0C
```

CapSched transition:

```text
Running
  -> Running with budget charged
  -> Quarantined or preempted when budget exhausted
```

Authority meaning:

```text
Linux L0 may account and preempt for prototype semantics
CapSched-H requires monitor/root budget so Linux compromise cannot exceed cap
```

Hard rules:

```text
NoBudgetNoExecution
NoLinuxOnlyBudgetAsProductionRoot
```

Open analysis:

The tick/budget charge path remains a separate required source map before
budget enforcement.

### Exit

Linux path:

```text
kernel/exit.c and scheduler dead task paths, not fully remapped here
```

CapSched transition:

```text
Running or Queued
  -> Dead
```

Authority meaning:

```text
self-exit is not RunCap use
external terminate requires ThreadControlCap, not RunCap
all FrozenRunUse and SelectedUse state must be invalidated
budget reservation policy must be explicit
```

## Minimal Transition Table

| Linux behavior | CapSched transition | Creates authority | Preserves authority | Must validate before run |
| --- | --- | --- | --- | --- |
| current self-wake | Running -> CurrentContinuation | no | yes | active context |
| already-runnable wake | Queued -> Queued | no | yes | live queued grant |
| normal wake | Blocked -> FrozenRunnable -> Queued | yes, by freezing existing RunCap | no | RunCap, SchedContext, epoch, CPU |
| remote pending wake | Blocked -> RemotePendingWake -> Queued | pending is no | maybe | pending epoch before activation |
| new task wake | Spawned -> FrozenRunnable -> Queued | yes, via SpawnCap plus initial run use | no | child generation, attenuated authority |
| queued migration | Queued -> MigratingQueued -> Queued | no | yes | CPU placement, epoch |
| enqueue_task | FrozenRunnable -> Queued | no | yes | nofail assertion or prechecked use |
| pick | Queued -> Selected | no | yes | live grant, budget, CPU |
| switch | Selected -> Running | no | yes | DomainTag/MemoryView activation |
| tick/budget | Running -> Running/preempt | no | consumes | remaining budget |
| exit | any live state -> Dead | no | invalidates | cleanup policy |

## Derived Hook Roles

The state machine preserves the four-role synthesis from analysis/0021, but
grounds it in authority transitions:

```text
admission/freeze:
  creates FrozenRunUse before executable custody

enqueue assertion:
  confirms existing FrozenRunUse at nofail enqueue points

pick validation:
  validates live grant before selected execution

switch activation:
  activates DomainTag/MemoryView or fails closed before running
```

Additional roles are required:

```text
placement refresh:
  queued migration and affinity/hotplug paths

budget charge:
  tick/runtime enforcement paths

revoke propagation:
  queued, selected, remote-pending, async, and active execution states

spawn initialization:
  wake_up_new_task and fork/clone identity generation
```

## Next Modeling Obligations

Before implementation:

```text
1. Build a scheduler hook candidate obligation matrix from this state machine.
2. Extend the existing RunnableLease model or add a LinuxSchedulerAuthority
   model with RemotePendingWake, SelectedUse, migration, and failure actions.
3. Derive schema v2 tag fields from the state machine transitions.
4. Retag Slice 0C behavior paths under schema v2.
5. Only then decide whether a trace-only or default-permissive Linux hook slice
   is justified.
```

## Open Risks

Open areas that must not be hidden by tags:

```text
tick and runtime charging path not mapped here
RT and deadline class-specific pick/enqueue state not fully mapped here
sched_ext custody and fallback not fully modeled here
core scheduling forced-idle and cached pick state not fully modeled here
proxy execution state not fully modeled here
async execution paths still require separate provenance state machines
monitor activation failure semantics remain unimplemented
```
