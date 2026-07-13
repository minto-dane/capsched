# Analysis 0155: SchedExecLease P5A-R2 Summary Update-Closure Map

Date: 2026-07-13

Status: source/locking/update-closure gate. No Linux patch or hot field is
approved.

## Purpose

Analysis/0154 corrected the future Fresh-summary representation to an explicit
validity tag plus a wrap-aware vruntime minimum. That representation is sound
only while every event that can change the represented witness also refreshes
or conservatively invalidates the summary.

This note maps that update closure to the recreated Linux tree at commit
`077c948be39432971e7273b16b728172251129aa`. It does not add a hook. It
identifies the exact scheduler ownership and the remaining architecture gaps
that must be closed before a behavior patch can be drafted.

## Summary Layers

Three values must remain distinct:

```text
node aggregate:
  Fresh/pickable witnesses in one rb-tree node and its descendants

cfs_rq combined witness:
  root node aggregate OR separately checked cfs_rq->curr

group projection:
  whether a parent group sched_entity can lead to a Fresh/pickable witness in
  its child cfs_rq
```

The existing `min_vruntime_cb` maintains only ordinary EEVDF vruntime and slice
augmentation. The existing `propagate_entity_cfs_rq()` maintains PELT state.
Neither function currently maintains SchedExecLease freshness. Similar names
must not be treated as proof that the new closure already exists.

## Locking Contract

Every mutation of a summary that contributes to an on-rq entity must occur
while the owning `rq->lock` is held. A refresh starts at the changed leaf or
child `cfs_rq`, recomputes the local node/current witness, projects the result
through the parent group entity, and continues to the root runqueue before the
lock is released.

All CFS group entities for one CPU share that CPU's runqueue lock. Therefore a
single locked upward walk is the natural ownership boundary. An unchanged
combined witness may permit an early stop, but only after comparing both the
validity tag and wrap-aware numeric minimum.

Cross-rq movement is a two-boundary transaction:

```text
old rq locked:
  remove or invalidate the old contribution before old-rq unlock

TASK_ON_RQ_MIGRATING / off-rq interval:
  the task contributes to neither runqueue

destination rq locked:
  publish a Fresh contribution only after CPU, cfs_rq, identity, placement,
  and queue membership are settled
```

No transient state may advertise the task as Fresh on both runqueues.

## Source Update Map

| Family | Current source boundary | Required P5A-R2 obligation |
|---|---|---|
| rb insert/erase | `__enqueue_entity()` / `__dequeue_entity()` use augmented rb callbacks | Initialize/recompute the node's local Fresh witness on insert and remove it on erase; propagate validity plus wrap-aware minimum. |
| in-tree value change | `reweight_entity()` and `requeue_delayed_entity()` dequeue/reinsert around vruntime changes; hierarchy loops call `min_vruntime_cb_propagate()` for current augmentation | Preserve the same remove/change/reinsert discipline. Any future in-place Fresh-state mutation needs an explicit new augmentation propagation call. |
| enter current | `set_next_entity()` erases the entity from `tasks_timeline` and then assigns `cfs_rq->curr` | Recompute the combined tree-or-current witness and propagate the child result before leaving the locked transition. |
| current execution | `update_curr()` changes `curr->vruntime` and charges CFS runtime | If current remains Fresh, update its wrap-aware value; if lease budget or identity crosses a Fresh boundary, invalidate it. Propagate any combined-witness change before return. |
| leave current | `put_prev_entity()` reinserts an on-rq current entity and clears `cfs_rq->curr` | Insert only the freshly revalidated local witness, recompute the combined witness, and propagate before unlock. |
| hierarchy selection | `__pick_task_fair()` descends with `group_cfs_rq(se)` under `rq->lock` | Parent group validity must mean the selected child has a tree-or-current Fresh witness. The reached task still receives a final task-local Fresh check. |
| hierarchy enqueue/dequeue | `enqueue_task_fair()` and `dequeue_entities()` walk `for_each_sched_entity()` and explicitly propagate ordinary augmentation | Extend a single upward refresh path to the Fresh summary. Enqueue/dequeue-only coverage is insufficient. |
| PELT attach/detach | `attach_entity_cfs_rq()`, `detach_entity_cfs_rq()`, and `propagate_entity_cfs_rq()` update load averages | Do not reuse PELT propagation as Fresh proof. Cgroup moves require a separate old-parent invalidation and new-parent publication under `task_rq_lock()`. |
| task birth/wake | reset and fork identity happen before first enqueue; `wake_up_new_task()` takes `p->pi_lock` and the destination rq lock before `activate_task()` | Off-rq initialization needs no tree propagation. First publication must validate the completed identity/placement under the destination rq lock. |
| exec/exit generation | `sched_exec_task_commit_exec()` and `sched_exec_task_exit()` mutate the task shadow outside a demonstrated rq-lock boundary | A future implementation must split identity mutation from a scheduler-owned locked notification, or acquire `task_rq_lock()` safely. Runnable/current contribution invalidation must finish before execution may use the new generation/exit state. |
| affinity/cpuset | `__set_cpus_allowed_ptr()` enters through `task_rq_lock()`; `do_set_cpus_allowed()` may change placement before deferred migration | If the old CPU becomes invalid, invalidate its current/tree contribution before releasing the old rq lock. Cpuset inherits this obligation. |
| queued migration | `move_queued_task()` deactivates under the old rq lock, changes CPU off-rq, then activates under the destination rq lock | Old contribution must be absent before old unlock; destination contribution must not appear before locked activation and final Fresh validation. |
| cgroup movement | `sched_move_task()` holds `task_rq_lock()` and changes the task group through scheduler dequeue/change/enqueue guards | Invalidate the old child-to-parent chain before detach and publish the new chain only after the new `cfs_rq`/parent linkage is settled. |
| budget charge | `update_curr()` calls `account_cfs_rq_runtime()`; CFS bandwidth decrements `runtime_remaining` | Execution-lease budget is a separate future object, but the analogous transition belongs in the locked current-accounting path. Crossing positive to exhausted invalidates before another pick trusts the summary. |
| throttle | `throttle_cfs_rq()` publishes `cfs_rq->throttled = 1` while scheduler state is rq-lock owned | Invalidate the child combined witness and every parent projection no later than throttle publication and before rq unlock. |
| refill/unthrottle | runtime distribution takes the target rq lock; `unthrottle_cfs_rq()` updates current state and re-enqueues limbo tasks | Revalidation is allowed only after runtime and queue state are settled under the rq lock. Refill must not silently flip invalid to valid outside the upward refresh. |
| domain/grant epoch | current task shadow has domain and generation values, but no runtime domain/grant publication or runnable membership index exists | A shared epoch change needs a versioned per-rq receipt or an indexed fanout that conservatively invalidates every affected contribution. The mechanism is unresolved. |
| future monitor revoke | the current scaffold intentionally has no monitor endpoint or picker call | Consume receipts outside the picker, then process affected runqueues under their locks. A single unindexed global flip cannot keep per-node summaries coherent. |
| mode/selector generation | a summary can only prove the predicate and selector generation for which it was computed | A future outer Domain/SchedContext selector must key or generation-stamp the summary. An unkeyed summary cannot be reused across different selector contexts. |

## Generic Refresh Shape

The source map supports one conceptual helper, not yet approved as Linux code:

```text
refresh changed task/current/node under rq lock
repeat for child cfs_rq -> parent group sched_entity:
  recompute child combined = tree aggregate OR separate curr witness
  recompute group local witness from child combined
  if group entity is in the parent rb-tree:
    propagate validity plus wrap-aware minimum through that tree
  otherwise group entity is parent curr:
    recompute the parent's separate-current witness
  continue to the next parent
```

The helper must be safe when the changed entity is off-rq, delayed, current,
in-tree, a group entity, throttled, or moving. The picker must not call this
helper to repair stale policy state. Picker-visible state must already be
coherent or conservatively invalid, and the reached entity must still be
revalidated.

## Shared-State Gap

Task-local enqueue/dequeue/current events can be closed with the existing
runqueue hierarchy. Shared execution-lease events cannot yet be closed:

```text
domain epoch or grant generation revoke
shared budget exhaustion/refill
future monitor receipt
outer selector generation change
```

The current tree has no runtime authority publication, no domain-to-runnable
membership index, no per-rq receipt generation, and no fanout protocol. A
behavior patch that adds only rb fields and picker checks would therefore
create stale false-positive summaries after shared invalidation. Final entity
revalidation is mandatory defense-in-depth, but it does not replace coherent
pruning state or guarantee bounded progress after repeated stale hits.

This is the concrete implementation blocker discovered by the closure map.
The next design gate must choose and model a versioned invalidation mechanism
before any hot-field or selector patch is reviewable.

## Rejected Shortcuts

```text
enqueue/dequeue-only refresh
using existing PELT propagation as Fresh propagation
folding curr into the rb-tree aggregate
changing a runnable task generation without rq-locked invalidation
publishing destination validity before activation
leaving the old rq valid until migration completes
unindexed shared epoch/budget/revoke flips
repairing stale summaries by scanning in pick_eevdf()
monitor or policy calls from the picker
trusting a summary without final entity revalidation
unkeyed reuse across outer selector generations
```

## Non-Claims

This source map does not approve:

```text
Linux code changes
new hot scheduler fields
accepting experimental patches 0009-0012 as production design
runtime denial correctness
complete CFS deny-and-repick correctness
runtime coverage
monitor enforcement
production protection
performance or cost efficiency
deployment readiness
datacenter readiness
```

## Next

Define the P5A-R2 versioned invalidation and shared-state fanout contract. It
must choose how domain/grant epochs, shared budget transitions, monitor
receipts, and outer selector generations make every affected rq summary
conservatively invalid before it can be trusted again.
