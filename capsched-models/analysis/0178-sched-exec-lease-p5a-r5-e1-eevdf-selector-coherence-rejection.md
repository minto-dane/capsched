# Analysis 0178: SchedExecLease P5A-R5 E1 EEVDF Selector-Coherence Rejection

Date: 2026-07-24

Status: source-free feasibility rejection. This record rejects R5 before layout
or source. It may authorize only a new successor analysis; it does not
authorize an R5 repair, R6 source, runtime behavior, or any broader claim.

## Decision

R5 Generation-Sealed Immutable Projection cannot satisfy its own E1 selector
obligation for current Linux EEVDF.

The immutable authority receipt remains a useful design ingredient, but an
immutable installed selector view cannot remain coherent with EEVDF's dynamic
runqueue state. One RCU pointer swap cannot update the weighted virtual-time
state and every affected subtree augmentation. Trusting the stale selector
summary violates selection soundness; refusing it is fail-closed but can block
an allowed runnable entity after ordinary scheduler progress.

R5 is rejected without a Linux patch.

## Exact Prerequisite

Validation/0273 selected R5 source-free only. Canonical architecture result
`20260724T-p5a-r5-generation-sealed-immutable-projection-r1` has SHA-256
`ceb595322a92886c2296cbcafd3c2fd08b220753a250ac2c4a7222a54a64bf9b`.
It explicitly deferred EEVDF-compatible membership and selection proof to E1
and kept layout/source false.

This analysis does not reopen R4. R4 remains rejected by complete arm64 result
`edb07251794914381433d4ff221753c4b038afe6b02e969f2ad93d67860a0951`
and normalized timing closure
`8ebacd3c03dee0519a978cd21a7537b729fb61267d2491b70f76f54219fa84b5`.

## Current EEVDF State Is Dynamic

At primary Linux commit
`5e1ca3037e34823d1ba0cdd1dc04161fac170280`, tree
`54f685aad94f28f0027cbba18cf5e29aadce234a`, a `cfs_rq` owns:

```text
sum_w_vruntime
sum_weight
zero_vruntime
tasks_timeline (augmented cached RB tree)
curr
next
```

Every `sched_entity` supplies the one live `run_node`, `deadline`,
`min_vruntime`, `vruntime`, slice fields, and on-rq/current state.
`min_vruntime_cb` maintains subtree augmentation during RB insert/erase.
`avg_vruntime()` includes both the queued weighted sums and current. EEVDF
eligibility compares a candidate against those current aggregate values.

`pick_eevdf()` obtains O(log n) behavior because the live tree is ordered by
deadline and each subtree carries the current minimum vruntime. It may descend
left only when that live augmentation proves an eligible entity exists.

Ordinary scheduling changes this state:

- `update_curr()` changes current service and vruntime;
- enqueue updates load, placement, weighted sums, and inserts the entity;
- dequeue updates lag/load, erases the entity, and changes weighted sums;
- `set_next_entity()` removes current from the tree; and
- `put_prev_entity()` updates current and inserts it again.

An authority generation and membership sequence can remain stable while these
events continue. R5's stable-window assumptions therefore do not make the
selector state immutable.

## Existing Experimental Negative Evidence

The local experimental P5A-R path demonstrates the missing augmentation.
`sched_exec_cfs_entity_pickable()` is a final node predicate, but it is not part
of `min_vruntime_cb`. A subtree may appear eligible while every entity in it is
denied. The fallback
`sched_exec_cfs_pickable_scan()` walks the complete `tasks_timeline` with
`rb_next()`.

That scan is historical, default-off experimental source and is already
unaccepted. It cannot be used to make R5 feasible because R5 forbids a
variable tree scan in the picker.

## Why the Immutable View Fails

An off-rq-lock builder could copy authority membership into immutable storage,
but a correct EEVDF selector also needs a coherent snapshot of:

```text
tree membership and topology
deadline ordering
subtree minimum vruntime
allowed-only weighted sum and weight
current entity and current vruntime
enqueue/dequeue/delayed/current transitions
```

The current RB tree cannot be traversed safely without the rq lock. Copying it
under the rq lock is variable O(n) work and violates R5. A separate RCU
registry plus a sequence counter could permit an optimistic off-lock copy, but
ordinary current updates invalidate the sequence; after install, the first
normal scheduler mutation makes the immutable summary stale again.

A mutable overlay updated on every scheduler mutation could remain coherent,
but it is no longer the immutable generation-sealed selector R5 selected. A
separate tree per generation requires moving existing runnable entities into
the new tree or maintaining multiple live nodes; either operation creates a
new dynamic materialization protocol that R5 did not model or measure.

The exact contradiction is:

```text
immutable selector view
+ ordinary EEVDF state mutation
+ no variable picker scan
+ no mutable post-install selector maintenance
= either stale trust or allowed-task unavailability
```

Fail-closed safety chooses unavailability. Since EEVDF state changes while the
authority descriptor is stable, R5's stated stable-window liveness does not
repair the contradiction.

## Formal Boundary

The bounded E1 model installs a generation-matched view, performs an ordinary
dynamic scheduler-state mutation without changing authority generation, and
then attempts to pick.

- the safe configuration refuses the stale view and preserves safety;
- a stale-trusting configuration violates the safety invariant; and
- the safe configuration violates eventual allowed selection after the
  mutation.

This is not a proof that every conceivable scheduler architecture is
impossible. It proves that the R5 combination selected in validation/0273 is
incomplete: immutable selector view, O(1) install, no dynamic maintenance, and
stable-authority liveness cannot all hold for current EEVDF.

## Rejected Repairs

- Reintroducing R4-style mutable repair under another name is rejected.
- Using the existing O(n) experimental fallback scan is rejected.
- Treating a seqcount retry as safe lockless RB-tree traversal is rejected.
- Assuming authority stability implies vruntime/tree stability is rejected.
- Updating an immutable view after install is a contract change, not a fix.
- Adding a second live RB node/tree without a new layout, lifecycle, fairness,
  memory, and timing architecture is rejected.
- Aligning DomainLease authority with `task_group` merely to obtain separate
  `cfs_rq` objects is rejected unless authority and cgroup-policy semantics are
  independently proven equivalent; they are not assumed equivalent.

## Successor Requirement

A successor must make authorization a native input to the dynamic EEVDF
augmentation, or introduce an authority-aligned scheduling hierarchy whose
dynamic selector state is maintained under existing rq-lock mutation points.
It must keep immutable generation receipts as the trust fence while treating
the scheduler index as explicitly mutable, non-authoritative, and
fail-closed-checked.

The next source-free analysis must compare at least:

1. augmenting the existing EEVDF tree with generation-aware allowed-subtree
   summaries;
2. authority-aligned per-rq scheduling queues with explicit fairness
   composition; and
3. a monitor-compiled hierarchy mapped to Linux scheduling groups without
   equating mutable cgroup policy with authority.

No successor is selected by this rejection.

## Claim Boundary

No R5/R6 source, real scheduler attachment, runtime denial, monitor delivery,
N-136 runtime charge, bare-metal latency, performance, cost, production
protection, deployment, multi-node, multi-cluster, or datacenter readiness is
accepted.
