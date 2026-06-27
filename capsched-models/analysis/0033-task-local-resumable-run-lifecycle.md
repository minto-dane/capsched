# Analysis 0033: Task-Local Resumable-Run Lifecycle

Status: Draft source map and design constraints, no implementation approved

Date: 2026-06-27

Linux source:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
commit: 7cf0b1e415bcead8a2079c8be94a9d41aad7d462
```

## Purpose

`analysis/0031` established that F1 is a validation/freeze boundary, not a
capability discovery boundary. `analysis/0032` established that generic wake
paths and `wake_q` do not carry typed authority.

This note narrows the ordinary-task case:

```text
Where can a task-local resumable-run authority live, and how must it survive
fork, block, wake, pick, switch, revoke, exec, exit, and final free without
becoming ambient authority?
```

This is not an approval to patch `task_struct` yet.

## Core Finding

A task-local resumable-run object is plausible for ordinary Linux sleep and
wake, but only if its lifecycle is stricter than normal task state.

The required shape is:

```text
fork raw-copy hazard:
  child must not inherit parent frozen/selected/running authority

new task:
  child must have SpawnCap-derived initial resumable-run state before
  wake_up_new_task() makes it TASK_RUNNING and activates it

ordinary block:
  runnable/frozen/selected/running use must be cleared, while a task-local
  continuation can remain prepared if the domain, generation, epoch,
  placement envelope, and SchedContext are still valid

ordinary wake:
  try_to_wake_up() may validate and freeze from task-local prepared data, but
  must not allocate, sleep, call the monitor, or perform slow discovery

pick/switch:
  selected and running state are derived from a frozen use, not from a raw cap

revoke:
  epoch or generation change makes blocked, queued, selected, and running
  state fail closed at the earliest valid boundary

exit/free:
  no CapSched authority or reference may survive TASK_DEAD or final task free
```

The first implementation slice should therefore treat task-local state as a
small lifecycle object with explicit phases, not as a loose set of pointers.

## Source Anchors

Task storage:

```text
include/linux/sched.h:826 task_struct begins
include/linux/sched.h:843 randomized_struct_fields_start
include/linux/sched.h:855-860 on_cpu, on_rq, is_blocked, wake_entry
include/linux/sched.h:1241 embedded wake_q node
include/linux/sched.h:1669 randomized_struct_fields_end
```

If CapSched stores task-local fields in `task_struct`, normal fields belong in
the randomized region unless they are truly scheduler-critical.

Fork copy hazard:

```text
kernel/fork.c:899 arch_dup_task_struct()
kernel/fork.c:914 dup_task_struct()
kernel/fork.c:2110 copy_process() calls dup_task_struct()
kernel/fork.c:2258 copy_process() calls sched_fork()
```

The weak generic `arch_dup_task_struct()` copies the whole task:

```text
*dst = *src
```

Several architectures may override the helper, but the semantic lesson is the
same: a newly allocated child begins life as a copy of the parent task before
many per-task fields are reset. Any CapSched pointer, frozen use, run token,
selected-state marker, or reference-counted authority stored directly in
`task_struct` can be duplicated unless it is explicitly reset.

New-task scheduler window:

```text
kernel/sched/core.c:4563 __sched_fork()
kernel/sched/core.c:4803 sched_fork()
kernel/sched/core.c:4807-4811 sched_fork() sets TASK_NEW
kernel/sched/core.c:4814-4816 child priority is reset to current normal_prio
kernel/sched/core.c:4941 wake_up_new_task()
```

`sched_fork()` gives CapSched a useful non-runnable window: `TASK_NEW` prevents
external events from waking the child before the fork path reaches the initial
wake. But `wake_up_new_task()` is a void activation path that writes
`TASK_RUNNING`, selects a CPU, and calls `activate_task()`. Therefore a child
cannot discover or allocate its initial authority inside normal activation.
Initial task-local run state must be prepared before `wake_up_new_task()`.

Wake path:

```text
kernel/sched/core.c:4215 try_to_wake_up() comment
kernel/sched/core.c:4251 try_to_wake_up()
kernel/sched/core.c:4258-4284 current self-wake path
kernel/sched/core.c:4292 p->pi_lock
kernel/sched/core.c:4295 ttwu_state_match()
kernel/sched/core.c:4323 already-runnable ttwu_runnable()
kernel/sched/core.c:4355-4357 TASK_WAKING transition
kernel/sched/core.c:4393 select_task_rq()
kernel/sched/core.c:4415 ttwu_queue()
kernel/sched/core.c:4067 ttwu_queue()
kernel/sched/core.c:4082 ttwu_state_match()
```

`try_to_wake_up()` is performance-sensitive and heavily synchronized around
`p->pi_lock`, task state, `p->on_rq`, and CPU selection. The current self-wake
path has a special fast path before taking `p->pi_lock`. The already-runnable
path can complete without ordinary admission failure. CapSched must therefore
treat these as distinct cases:

```text
blocked ordinary task:
  validate prepared task-local continuation and freeze before TASK_WAKING

self wake/current continuation:
  no slow failure path; state must already be current-owned and valid

already runnable:
  no new capability discovery; selected/switch checks may still fail closed
```

Block and schedule path:

```text
kernel/sched/core.c:6698 try_to_block_task()
kernel/sched/core.c:7061 __schedule()
kernel/sched/core.c:7135-7143 schedule path may block prev
kernel/sched/core.c:7149 pick_next_task()
kernel/sched/core.c:7201 rq->curr = next
kernel/sched/core.c:7231 trace_sched_switch()
kernel/sched/core.c:7234 context_switch()
kernel/sched/sched.h:3032-3072 __block_task()
```

`__block_task()` stores `p->on_rq = 0` and its comment says the caller must not
reference `p` after losing ownership. A task-local continuation must therefore
be lifetime-pinned by `task_struct` ownership or an explicit reference, not by
runqueue ownership. It must not rely on a runqueue entry surviving block.

Switch path:

```text
kernel/sched/core.c:5273 prepare_task_switch()
kernel/sched/core.c:5318 finish_task_switch()
kernel/sched/core.c:5448 context_switch()
```

Selected and running CapSched state must align with the existing two-sided
switch protocol. The conceptual transitions are:

```text
pick:
  frozen use becomes selected use

context_switch/monitor activation:
  selected use becomes running use if DomainTag/MemoryView activation succeeds

finish_task_switch:
  previous running use is charged, stopped, or cleared
```

L0 may not yet have a monitor, but the state machine should be shaped so that
DomainTag activation can be inserted later without changing the meaning of
earlier grants.

Exit and free:

```text
kernel/exit.c:924 do_exit()
kernel/exit.c:946 exit_signals() sets PF_EXITING
kernel/exit.c:1004 exit_task_work()
kernel/exit.c:1047 do_task_dead()
kernel/sched/core.c:7244 do_task_dead()
kernel/fork.c:533 free_task()
kernel/fork.c:781 __put_task_struct()
kernel/fork.c:2603-2622 fork failure cleanup reaches delayed_free_task()
```

Exit is not a normal wake failure. It is self-disposal of the current task.
CapSched must invalidate running/selected/frozen uses before the task becomes
dead and release references on both normal final put and fork failure cleanup.

Exec:

```text
fs/exec.c:1110 begin_new_exec()
fs/exec.c:1754 bprm_execve()
fs/exec.c:1768 current->in_execve = 1
fs/exec.c:1771 sched_exec()
fs/exec.c:1778 exec_binprm()
```

The current architectural rule remains:

```text
exec changes program image and credentials within policy
exec does not automatically change DomainTag, SchedContext, or monitor identity
```

If `process_generation` changes across exec, task-local resumable-run state
must be refreshed or revalidated as part of exec semantics. That remains an
open modeling item, not a reason to let exec mint new run authority.

## Conceptual State Slots

A minimal task-local object needs these logical slots, even if the eventual
implementation stores them differently:

```text
identity:
  domain
  task_generation
  process_generation
  domain_epoch_seen

resource:
  sched_ctx
  sched_ctx_epoch_seen
  placement_envelope
  budget_snapshot_or_ticket

prepared continuation:
  resumable_prepared
  blocked_prepared
  wake_prepared

derived uses:
  frozen_valid
  selected_valid
  running_valid

lifetime:
  initialized
  fork_child_reset_done
  spawn_prepared
  exiting
  dead
```

Important separation:

```text
resumable_prepared:
  a local continuation seed bound to task/domain/generation/SchedContext

frozen_valid:
  a one-wake or one-enqueue use created after validation

selected_valid:
  scheduler-local chosen use after pick

running_valid:
  CPU-local active use after switch/activation
```

Only the first is a persistent task-local continuation. The others are derived
uses and must be cleared on block, revoke, exit, or failed activation.

## Lifecycle

### 1. Duplication

Raw child task memory may contain parent CapSched values immediately after task
duplication.

Required rule:

```text
capsched_task_reset_after_dup(child)
  clears frozen/selected/running uses
  clears raw parent pointers that require ref ownership
  marks child uninitialized or reset
  prevents cleanup from double-putting parent-owned references
```

No child may reach `sched_fork()`, error cleanup with CapSched refs, or any
trace/exposure path while still carrying parent frozen authority.

### 2. Spawn Preparation

Before `wake_up_new_task()`:

```text
SpawnCap policy chooses whether child creation is permitted
child receives a fresh task_generation
child receives explicit Domain/SchedContext inheritance or new assignment
child receives a prepared initial resumable-run state
child has preallocated or embedded storage sufficient for F1 freeze
```

If this fails, fork must fail before the child becomes runnable. Failure cleanup
must release only references owned by the child.

### 3. Initial Wake

`wake_up_new_task()` should be treated as nofail from CapSched's perspective.
It may assert or validate that initial state exists, but it should not perform
slow policy discovery.

Two safe designs remain candidates:

```text
pre-frozen initial use:
  fork path prepares a FrozenRunUse before wake_up_new_task()

prevalidated task-local continuation:
  wake_up_new_task() freezes from already-local, preallocated, nofail data
```

The model rejects:

```text
wake_up_new_task() before initialization
child running with copied parent frozen use
child running without SpawnCap-derived prepared state
```

### 4. Running to Blocked

When a task blocks:

```text
running_valid is stopped or charged
selected_valid is cleared
frozen_valid is cleared or consumed
resumable_prepared may remain if still current
```

The continuation is not a right to run forever. It is only a local seed that F1
can turn into a frozen use if epochs, generations, placement, and budget remain
valid.

### 5. Blocked to Waking

For ordinary wait/wake:

```text
validate task_generation
validate process_generation if relevant
validate domain_epoch
validate sched_ctx epoch
validate placement envelope
validate budget nonzero
freeze into preallocated/embedded FrozenRunUse storage
only then allow TASK_WAKING / enqueue
```

No sleep, allocation, global cap-table walk, LSM policy walk, monitor call, or
remote lease discovery is allowed in this hot boundary.

### 6. Queued to Selected

Pick must not trust that a queued frozen use is still fresh. It must recheck:

```text
frozen_valid
generation match
epoch match
CPU allowed by placement envelope
remaining budget
task still live
```

If a queued task became stale through revoke, pick should skip/dequeue/fail
closed according to the class-specific rule later modeled for CFS/RT/DL/SCX.

### 7. Selected to Running

Context switch is the future DomainTag activation boundary.

L0:

```text
selected_valid becomes running_valid
chargeable execution begins
```

Monitor-backed CapSched-H:

```text
selected_valid becomes running_valid only after sealed RunToken,
DomainTag, epoch, MemoryView, co-tenancy, and root budget checks pass
```

Same-domain switch may use a fast path, but the fast path still requires epoch
freshness and budget freshness. It is not an ambient bypass.

### 8. Revoke

Revocation can hit while blocked, queued, selected, or running.

Required behavior:

```text
blocked:
  next wake rejects before TASK_WAKING

queued:
  pick or dequeue path fails closed before execution

selected:
  switch/activation rejects before running

running:
  tick, forced reschedule, monitor timer, or immediate IPI path stops execution
```

L0 can model only Linux-side checks, but the state names must not prevent a
later monitor root budget and epoch stop.

### 9. Exec

Default rule:

```text
Domain/SchedContext stay unchanged across exec.
```

Possible future rule:

```text
process_generation changes across successful exec, invalidating endpoint
object uses that were bound to the old image while preserving domain-local
run continuation if policy permits.
```

This must be split explicitly. Exec must not be a hidden Domain transition.

### 10. Exit and Final Free

On exit:

```text
mark exiting
clear running/selected/frozen uses
stop budget charging
invalidate task-local continuation
release CapSched references
```

On final free:

```text
assert no CapSched authority remains
assert no child-cleanup path will double-put parent-owned refs
```

Fork failure cleanup must follow the same owned-reference rule.

## Storage Options

### Embedded task state

```text
struct task_struct {
        ...
#ifdef CONFIG_CAPSCHED
        struct capsched_task_state capsched;
#endif
};
```

Advantages:

```text
no allocation in F1
easy lifetime with task_struct
easy nofail initial wake and ordinary wake
```

Costs:

```text
increases task_struct size
must carefully reset after dup_task_struct()
must avoid putting rarely-used endpoint state inside every task
```

### Pointer to preallocated object

```text
struct task_struct {
        ...
#ifdef CONFIG_CAPSCHED
        struct capsched_task_state *capsched;
#endif
};
```

Advantages:

```text
smaller task_struct
can vary object size by configuration or domain type
```

Costs:

```text
requires allocation in fork path before any wake
copy hazard still exists for the pointer
failure cleanup must be exact
F1 must never allocate the object lazily
```

No choice is approved yet. The current evidence favors either a very small
embedded hot state plus pointers to colder objects, or a pointer allocated and
reset immediately after task duplication.

## Hard Rejects

These design shapes are rejected:

```text
raw copied parent FrozenRunUse survives into child
wake_up_new_task() discovers authority after setting TASK_RUNNING
F1 allocates or sleeps to build task-local state
runqueue entry stores raw RunCap handles
blocked task owns continuation only through a runqueue entry
exec changes DomainTag implicitly
exit leaves frozen/selected/running authority reachable
cleanup double-puts parent-owned authority copied into child
same-Domain switch bypasses epoch or budget freshness
```

## Compatibility Notes

The task-local continuation model is compatible with Linux semantics only if:

```text
normal wake success/failure return conventions remain intact
fork failures happen before child publication/runnability
existing cgroup, rlimit, cpuset, and scheduler class decisions are inputs, not
  silently bypassed authorities
sched_ext fallback cannot erase the native CapSched check
TASK_NEW, TASK_WAKING, on_rq, and on_cpu synchronization remain owned by the
  scheduler
```

The model must preserve existing Linux behavior when `CONFIG_CAPSCHED=n`.

## Implications for the First Behavior-Changing Slice

Before patching behavior, the first L0 enforcement slice should prove these
local invariants:

```text
NoForkGrantInheritance:
  a child never runs with parent frozen/selected/running authority

NoInitialRunWithoutPreparedState:
  wake_up_new_task() cannot activate an unprepared child

NoTaskWakingWithoutFrozenUse:
  ordinary blocked wake cannot reach TASK_WAKING without a frozen use

NoFrozenUseAfterRevoke:
  stale epoch/generation invalidates frozen/selected/running uses

NoDeadTaskAuthority:
  dead or freed task has no authority-bearing CapSched refs
```

The next formal model should remain deliberately small and focus on the raw
copy/reset/prep/wake/block/revoke/exit lifecycle, not full scheduler policy.

## Open Follow-Ups

```text
Q-021:
  Should the first implementation use a tiny embedded capsched_task_state, a
  pointer allocated in fork, or a hybrid hot/cold split?

Q-022:
  Should successful exec bump process_generation for run authority, endpoint
  authority only, or both?

Q-023:
  What is the class-specific stale-queued-task behavior for CFS, RT, DL, and
  sched_ext?

Q-024:
  How does current self-wake prove it is using current-owned continuation
  rather than a normal fail-capable wake path?
```
