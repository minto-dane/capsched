# Analysis 0112: SchedExecLease P3/P4 Source-Verified Design Boundary

Status: Design-only source verification; no Linux implementation in current
scope

Date: 2026-07-02

## Purpose

Re-check the P3/P4 scheduler touch-point design against the current Linux
source after P2 validation, while keeping actual Linux implementation out of
scope.

Source basis:

```text
linux_branch=capsched-linux-l0
linux_commit=a0f2676adda634391983e74f29fcba577a9c919e
linux_subject=sched/exec_lease: Add task identity shadow
```

This note is a design artifact. It does not add Linux code, generate a patch,
or approve enforcement.

## Scope Boundary

Current phase:

```text
implementation-ready design
source-anchor verification
proof-obligation mapping
validation-plan design
claim hygiene
```

Out of scope:

```text
new Linux hooks
no-op helper implementation
runtime denial
budget charging
monitor calls
ABI
patch queue updates for P3/P4
```

## Source-Verified Anchors

### Wake Preparation

Current source:

```text
file: kernel/sched/core.c
function: try_to_wake_up()
anchor pattern: before WRITE_ONCE(p->__state, TASK_WAKING)
```

Design reading:

```text
TASK_WAKING is the first explicit wake publication in the non-runnable path.
Any future fallible admission must not discover denial only after this write.
P3, when implementation scope reopens, should only mark this edge. It must not
make try_to_wake_up() fail in the current design.
```

Rejected shortcut:

```text
enqueue_task() is too late for first wake authority because TASK_WAKING and
other wake-path state have already been mutated.
```

### New Task Publication

Current source:

```text
file: kernel/sched/core.c
function: wake_up_new_task()
anchor pattern: after raw_spin_lock_irqsave(&p->pi_lock, rf.flags)
                before WRITE_ONCE(p->__state, TASK_RUNNING)
```

Design reading:

```text
wake_up_new_task() returns void and directly publishes TASK_RUNNING after
taking p->pi_lock. Future P3 marker placement must be immediately before that
write if it is meant to name child runnable publication. Future denial cannot
be inserted here without a separate spawn/publication failure model because
the current Linux API has no failure channel at this point.
```

### Runtime Tick Observation

Current source:

```text
file: kernel/sched/core.c
function: sched_tick()
anchor pattern: after donor = rq->donor
                before psi_account_irqtime(rq, donor, NULL)
```

Design reading:

```text
The current tick path explicitly accounts to the donor task under proxy
execution. Runtime budget design must treat donor identity as the accounting
subject candidate, not blindly use rq->curr. P3 may only observe this source;
budget charging remains out of scope.
```

### Final Run Boundary

Current source:

```text
file: kernel/sched/core.c
function: __schedule()
anchor region: after pick_next_task() and proxy resolution
               at/near keep_resched
               before is_switch publication effects and before
               RCU_INIT_POINTER(rq->curr, next)
```

Design reading:

```text
Final run authority must be checked after Linux has selected the effective
next task, including proxy-exec replacement, but before rq->curr is published.
The call to context_switch() is too late for denial because rq->curr has
already been updated.
```

Open design obligation:

```text
The P4 allow-all skeleton must prove that every ordinary run edge reaches the
future validation point exactly once, including keep_resched, proxy idle,
SCX/class-selected paths, and no-switch cases that should not consume a run
tuple.
```

### Switch Boundary Observation

Current source:

```text
file: kernel/sched/core.c
function: __schedule()
anchor pattern: before context_switch(rq, prev, next, &rf)
```

Design reading:

```text
This is suitable for future Domain/monitor switch observation only, not for
final run denial. It happens after rq->curr publication. If used later, it must
not stand in for the final run validation edge.
```

### Queued Move Boundary

Current source:

```text
file: kernel/sched/core.c
function: move_queued_task()
anchor pattern: before deactivate_task(rq, p, DEQUEUE_NOCLOCK)

file: kernel/sched/sched.h
function: move_queued_task_locked()
anchor pattern: before deactivate_task(src_rq, task, 0)
```

Design reading:

```text
The move authority edge must be before detach and before set_task_cpu(). A
future denial/retry design must not leave a task half-moved or with mismatched
rq/CPU state. P4 may only add allow-all validation here after the run/move
tuple model is refreshed against the current source.
```

## Helper Naming Direction

When implementation scope reopens, P3 helper names should avoid implying
fallible validation. Prefer marker names:

```text
sched_exec_lease_prepare_wake()
sched_exec_lease_prepare_new_task()
sched_exec_lease_observe_tick()
sched_exec_lease_note_switch()
sched_exec_lease_note_queued_move()
```

Reserve `validate_*` names for P4 or later, where an explicit allow-all result
object exists and the validation contract has been reviewed.

## Required Before Any P3 Patch

```text
explicit user approval to reopen implementation scope
fresh source-drift check against upstream
P3 plan updated from design-only to implementation candidate
no behavior change proof for generated call sites
targeted build plan for off/on configurations
claim-ledger non-overclaim review
patch queue regeneration plan
```

## Required Before Any P4 Patch

```text
P3 implemented and validated, if P3 is still desired
refreshed final run/move edge model against current Linux
allow-all result type and no-denial proof
proxy/core/sched_ext path coverage review
move denial rollback remains out of scope
full vmlinux and QEMU smoke plan
```

## Non-Claims

This note is not P3 implementation, P4 implementation, scheduler hook
approval, runtime coverage, runtime denial, ABI approval, monitor
implementation, monitor verification, protection evidence, or cost-efficiency
evidence.
