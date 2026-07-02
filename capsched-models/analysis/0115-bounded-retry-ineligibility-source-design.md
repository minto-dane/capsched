# Analysis 0115: Bounded Retry and Ineligibility Source Design

Status: Source-verified B2 design constraint; no implementation approved

Date: 2026-07-02

## Purpose

Close the source-shape part of blocker B2 from analysis/0113:

```text
denied candidate ineligibility
retry epoch
retry budget
class-state neutralization
balance-callback cleanup
fail-closed condition
```

This note refines analysis/0101 against the current SchedExecLease P2 Linux
tree. The central finding is that a final denial cannot simply be added to the
existing P4 allow-all hook position and then `goto pick_again`.

## Source Basis

```text
linux_branch=capsched-linux-l0
linux_commit=a0f2676adda634391983e74f29fcba577a9c919e
linux_subject=sched/exec_lease: Add task identity shadow
```

Important current-source anchors:

```text
kernel/sched/core.c:6144 pick_task_fair()
kernel/sched/core.c:6152 put_prev_set_next_task() before return
kernel/sched/core.c:6160 class->pick_task()
kernel/sched/core.c:6164 put_prev_set_next_task() before return
kernel/sched/core.c:6254 core cached-pick fast path
kernel/sched/core.c:6305 restart_single
kernel/sched/core.c:6327 restart_multi
kernel/sched/core.c:6388 core_pick_seq publication
kernel/sched/core.c:6448 put_prev_set_next_task() before core return
kernel/sched/core.c:7147 __schedule() pick_again
kernel/sched/core.c:7149 pick_next_task()
kernel/sched/core.c:7157 find_proxy_task()
kernel/sched/core.c:7188 picked
kernel/sched/core.c:7201 RCU_INIT_POINTER(rq->curr, next)
kernel/sched/sched.h:2758 put_prev_set_next_task()
kernel/sched/sched.h:2769 prev->sched_class->put_prev_task()
kernel/sched/sched.h:2770 next->sched_class->set_next_task()
kernel/sched/sched.h:4120 move_queued_task_locked()
kernel/sched/ext/ext.c:2495 consume_dispatch_q()
kernel/sched/ext/ext.c:2766 scx_dispatch_sched()
kernel/sched/ext/ext.c:3148 do_pick_task_scx()
```

## Core Finding

Current Linux combines candidate selection and scheduler-class settlement:

```text
pick candidate
  -> put_prev_set_next_task(prev, candidate)
  -> return candidate to __schedule()
```

`put_prev_set_next_task()` clears deadline-server state, calls
`put_prev_task()` on the old donor, and calls `set_next_task()` on the selected
candidate. Therefore, a SchedExecLease denial placed only at the P4 conceptual
final point in `__schedule()` would often be post-settlement even though it is
pre-`rq->curr`.

That position is acceptable for allow-all shape checking. It is not sufficient
for a behavior-changing denial unless a separate class-state unwind proof
exists.

Subagent source review confirmed the sharper rule:

```text
pre-rq->curr is not automatically pre-commit.
```

By the time `pick_next_task()` returns to `__schedule()`, Linux may already have
mutated scheduler-class state enough that denial is no longer a local boolean
decision.

Examples of already-mutated state include:

```text
CFS:
  cfs_rq->curr, rb-tree / delayed dequeue state, runtime update, MRU and hrtick
  effects.

RT:
  pushable-list membership, runtime/load state, and push callbacks.

Deadline:
  dl_rq->curr, server lending state, runtime/deadline state, and push/pull
  callbacks.

sched_ext:
  DSQ custody, BPF dispatch effects, kick-sync counters, local/global/bypass
  DSQ movement, and deferred callbacks.

Core scheduling:
  sibling core_pick state, core_sched_seq/core_pick_seq, force-idle accounting,
  core_occupation, resched IPIs, and core balance callbacks.

Proxy execution:
  rq->donor, rq->next_class, blocked_donor handoff, donor-idle transitions,
  proxy migration/deactivation, and owner/current separation.
```

Therefore "deny after final candidate selected" is safe only if the selected
state is still pre-settlement, or if the design has a per-path rollback proof.

## Design Decision

The first safe bounded retry design must use one of two shapes:

```text
Shape A: pre-settle candidate validation
  Validate the candidate before put_prev_set_next_task() or equivalent class
  settlement. Denied candidates become ineligible inside the current retry
  epoch, and class pick must not return them again.

Shape B: explicit post-settle rollback
  Validate after settlement only if every touched scheduler class and proxy/core
  path has a source-proved rollback operation that restores donor, next,
  dl_server, class current pointers, balance callbacks, and sibling/core state.
```

Default implementation-ready direction:

```text
Shape A is the default.
Shape B is rejected for P5 until class-specific rollback is modeled and tested.
```

This changes the reading of P4/P5:

```text
P4 allow-all final revalidation:
  useful as no-denial source skeleton and tuple-observation pressure.

P5 denial:
  must not be created by merely turning the P4 allow-all final hook into a
  denying hook.
```

## Retry Epoch

A retry epoch is a scheduler-local attempt to select a runnable ordinary Domain
task for one run edge.

Required fields:

```text
rq identity
cpu
epoch sequence
retry count
retry budget
edge kind: run or move
denied candidate set
current core sequence snapshot
current sched_ext custody snapshot if sched_ext is in scope
current proxy donor/executor relation if proxy is in scope
claim scope: supported, disabled, or excluded class/path set
```

Denied candidate keys must include:

```text
task pointer
task generation
process generation if available
Domain epoch
RunCap or future run-grant epoch
SchedContext epoch
run CPU or move destination CPU
edge kind
```

The denied set is not authority. It is only a negative filter for the current
retry epoch. It must not be user ABI, tracepoint ABI, persistent policy,
monitor receipt, or proof of revocation.

## Ineligibility Visibility

Marking a task as denied in the common scheduler loop is insufficient if the
same class picker can return the same task again.

Therefore the ineligibility predicate must be visible at the candidate
selection point:

```text
CFS candidate pick
RT candidate pick
deadline candidate pick
sched_ext local DSQ pick and DSQ consume if sched_ext is supported
core cached-pick consumption if core scheduling is supported
proxy donor/executor resolution if proxy execution is supported
```

If a class or path cannot consult the retry epoch, that class or path must be
disabled or excluded from runtime coverage claims for the test-only denial
mode.

## Class-State Neutralization

For Shape A:

```text
candidate denied before put_prev_set_next_task()
  -> no class settlement for denied candidate
  -> clear or prove empty ordinary balance callbacks before retry
  -> preserve balance_push_callback semantics
  -> retry with updated ineligibility set
```

For Shape B:

```text
candidate denied after put_prev_set_next_task()
  -> restore dl_server ownership
  -> undo prev put / next set effects
  -> restore donor/current relation
  -> clear or replay balance callbacks in a proved-safe order
  -> invalidate core and proxy selected state
```

Shape B is not implementation-ready because Linux does not expose a generic
class rollback API.

Shape B must also prove that retry re-enters the scheduler with coherent:

```text
rq->curr
rq->donor
rq->next_class
cfs_rq/dl_rq class current fields
dl_server ownership
SCX local/global/bypass DSQ state
core_pick/core_dl_server sibling state
balance callbacks
reschedule state and switch accounting
```

Without that proof, post-settle denial is forbidden even if it still occurs
before `RCU_INIT_POINTER(rq->curr, next)`.

## Balance Callback Rule

`__schedule()` asserts that ordinary balance callbacks are empty at
`pick_again`. Proxy execution already uses `zap_balance_callbacks()` before
some retry or lock-release paths.

SchedExecLease retry must obey:

```text
ordinary callback queued by candidate selection cannot survive into retry
balance_push_callback is a special Linux hotplug mechanism, not authority
zapping a callback is cleanup, not proof that the denied candidate was safe
callback cleanup must happen before rq lock release or retry
```

## Retry Budget

The retry budget is a livelock guard, not authority to run idle or to drop a
candidate.

Implementation-ready requirements:

```text
retry_count increments on every denial
same denied candidate cannot be returned again in the same epoch
retry must make progress by shrinking the eligible candidate set or refreshing
  the epoch after a real state change
budget exhaustion cannot justify running a denied candidate
budget exhaustion cannot justify claiming "no eligible task" unless the
  supported class/path set was actually exhausted
```

For a future test-only P5, if the supported class/path set cannot prove
exhaustion, budget exhaustion must be treated as a test-mode violation and not
as production-ready fail-closed evidence.

The retry path also must not reinterpret a previous task that Linux has already
blocked or dequeued. After `try_to_block_task()` / `block_task()` succeeds,
ordinary wakeup and migration rules own that task; SchedExecLease retry cannot
use the old `prev` pointer as a rollback handle.

## Fail-Closed Rule

Fail-closed means:

```text
No supported ordinary Domain candidate remains eligible for this retry epoch.
The CPU may choose an internal idle/exception path instead of running a denied
ordinary Domain task.
```

Fail-closed does not mean:

```text
idle fallback is authority
sched_ext fallback is authority
RETRY_TASK is authority
budget exhaustion is authority
unsupported class state can be ignored
```

If the scheduler enters an idle/exception path because all supported ordinary
Domain candidates are denied, the design must avoid clearing reschedule state
as if an ordinary authorized task had been selected, or must explicitly
re-establish a reschedule trigger. Existing proxy paths show that Linux already
distinguishes some idle retry paths from normal `picked` clearing, but that is
not SchedExecLease authority.

## sched_ext Consequence

sched_ext has independent DSQ custody and dispatch loops. `consume_dispatch_q()`
can retry, migrate remote tasks, and consume bypass/global/local DSQs.
`scx_dispatch_sched()` can loop around BPF `ops.dispatch()` and has a watchdog
for repeated ineligible dispatches.

For SchedExecLease denial:

```text
sched_ext ineligibility must be visible to DSQ consume and local pick
BPF dispatch cannot keep reintroducing the same denied candidate in the same
  retry epoch
SCX_DSP_MAX_LOOPS is not a SchedExecLease retry budget
bypass DSQs and server pick cannot be fallback authority
task_can_run_on_remote_rq() cannot be extended into final authority because it
  misses local DSQ picks, same-rq moves, keep-prev, bypass, global consumption,
  core scheduling, and proxy execution
first_local_task() has no skip loop, so a denied task left at the local DSQ head
  can be selected forever
global DSQ fallback means "try elsewhere", not "not executable"; a denied task
  sent global can be consumed before BPF policy sees it again
direct dispatch denial after ddsp state or finish_dispatch() needs explicit
  cleanup of direct-dispatch state, custody state, and ops_state transitions
ext_server_pick_task() must never return RETRY_TASK because force-SCX paths do
  not use RETRY_TASK as an ordinary denial sentinel
bypass mode recovery must not silently erase SchedExecLease denial semantics
```

Until this is designed and tested, the safest P5 stance is:

```text
disable or exclude sched_ext while test denial is enabled
```

If sched_ext is later supported, denial outcomes must be typed:

```text
ALLOW
RETRY
INELIGIBLE
QUARANTINE
```

They must not collapse into `RETRY_TASK`, global fallback, bypass fallback, or
plain `NULL` unless the denied task has first been removed from executable
custody or made non-selectable for the retry epoch.

## Core Scheduling Consequence

Core scheduling can reuse cached sibling picks and can set `core_pick_seq`
before the current CPU consumes `next`.

For SchedExecLease denial:

```text
denying one sibling pick invalidates the sibling core_pick tuple set
core_pick_seq/core_task_seq/core_sched_seq must be part of retry freshness
cached core picks cannot bypass the ineligibility set
sched_core_find() walks the core tree by cookie and can bypass class-local
  picker filters, so core ineligibility cannot live only in per-class pick code
local-only denial is unsafe after a core-wide pick because sibling core_pick
  state may already be published for later fast-path consumption
try_steal_cookie() move edges need separate move denial handling
```

Until this is modeled and tested, the safest P5 stance is:

```text
disable or exclude core scheduling while test denial is enabled
```

## Proxy Execution Consequence

Proxy execution already has source-level cleanup patterns:

```text
proxy_resched_idle()
proxy_deactivate()
proxy_migrate_task()
zap_balance_callbacks()
find_proxy_task() returning NULL to pick_again
```

Those patterns prove that Linux needs explicit cleanup before retry. They do
not prove SchedExecLease denial safety.

For SchedExecLease denial:

```text
denied subject must say whether donor, executor/current, or both are denied
budget subject remains donor-aware
proxy migration invalidates the retry epoch
idle proxy fallback is not authority
proxy_deactivate() and proxy_migrate_task() are reference-fragile and must not
  retain donor/owner conclusions across dequeue, attach, or rq-lock drop
blocked_donor handoff is part of mutex progress and must not be silently
  cleared by denial cleanup
tick/runtime budget semantics must explicitly name donor, executor, or both
```

Until this is modeled and tested, the safest P5 stance is:

```text
disable or exclude proxy execution while test denial is enabled
```

## Queued Move Denial

Queued movement has a cleaner source shape than final run denial because
common helpers mutate state after a visible move edge:

```text
move_queued_task_locked()
  -> deactivate_task()
  -> set_task_cpu()
  -> activate_task()
```

A move denial must occur before detach or CPU mutation. A denied move tuple
does not authorize a run, and a denied run tuple does not authorize a move.

Move retry epoch fields must include:

```text
source rq
destination rq
destination CPU
task generation
Domain epoch
move sequence
class migration path
hotplug or affinity state
```

If a balancing path cannot choose an alternate move candidate after denial, it
must leave the task in place or fail the test path. It must not silently move
the denied task.

## Required Future Model Refresh

formal/0079 already checks the abstract denial rule:

```text
deny -> ineligible -> neutralize -> bounded retry or fail closed
```

Before implementation scope reopens, the model must be refreshed or extended
with the source-specific split:

```text
pre_settle_validation
post_settle_validation_requires_rollback
class_picker_observes_ineligibility
same_class_same_candidate_repick
balance_callback_cleanup
core_cached_pick_invalidation
sched_ext_reintroduce_denied_candidate
proxy_donor_executor_denial_subject
```

## Implementation-Ready Consequence

P5 is not implementation-ready until a future artifact chooses and validates:

```text
supported scheduler classes and excluded classes
pre-settle validation insertion shape
class picker ineligibility visibility
retry epoch storage shape
retry budget and exhaustion semantics
fail-closed path that does not overclaim idle fallback
negative tests for same-candidate repick and post-settle denial
```

## Non-Claims

This note does not approve Linux code, scheduler hooks, task fields, rq fields,
class picker changes, rollback APIs, runtime denial, runtime coverage, public
ABI, monitor ABI, monitor verification, production protection, or
cost-efficiency claims.
