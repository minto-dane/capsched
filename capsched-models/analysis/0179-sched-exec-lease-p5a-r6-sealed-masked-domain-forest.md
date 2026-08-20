# Analysis 0179: SchedExecLease P5A-R6 Sealed Masked Domain Forest

Date: 2026-07-24

Status: source-free successor architecture selection. This record may
authorize only an R6-E1 source/locking/layout/fairness evidence plan after
independent validation. It does not authorize layout, Linux source, runtime
behavior, or any broader claim.

## Trigger

Validation/0274 rejects R5 before layout/source. An immutable selector view
becomes stale because ordinary EEVDF operation mutates vruntime, weighted
aggregates, deadline-tree membership, current state, and subtree augmentation
while authority generation remains stable.

R6 therefore separates two kinds of state that R5 incorrectly joined:

- an immutable, generation-sealed authorization plane; and
- an explicitly mutable, rq-lock-maintained scheduling plane.

The selector may consume the authorization plane, but the authorization plane
does not copy, summarize, or claim ownership of mutable EEVDF state.

## Candidate Comparison

### A. Generation-aware augmentation of the flat task tree

Rejected as the main direction.

A subtree bitmask can prove that some authority slot is present, but existing
EEVDF eligibility also depends on minimum vruntime and weighted virtual-time
aggregates. Exact selection for an arbitrary allowed-slot mask requires
per-slot eligibility summaries, a variable search, or eager repair after an
authority update. Per-slot minima on every task-tree node scale with
`B_max * nr_running`; lazy generation repair recreates the R5 stale-summary
problem; eager repair recreates rejected R4 fanout/rebuild work.

### B. Cgroup/task-group state as authority

Rejected.

Linux fair group scheduling proves that hierarchical `cfs_rq` composition is
a real scheduler mechanism. It does not make cgroup membership, shares,
autogroup state, or `task_group` lifetime a monitor receipt. Those values are
mutable policy and administration state. Equating them with DomainLease
authority would violate the established rule that Linux policy is not
authority.

### C. Sealed Masked Domain Forest

Selected for source-free R6.

Each rq has at most `B_max = 64` preallocated authority slots. A task is
admitted into exactly one slot under a sealed descriptor and slot-map digest.
Each active slot owns its own dynamically maintained EEVDF queue. A fixed
six-level top selector contains one leaf per slot and mutable scheduling
summaries for those 64 slot entities.

Every top-selector subtree has a static slot mask determined solely by its
fixed leaf range. A masked query skips any subtree whose static mask does not
intersect the immutable 64-bit allowed-slot mask. A single scheduling minimum
cannot summarize an arbitrary allowed subset, so R6 does **not** claim that
every query visits only six nodes. The exact safe upper bound is all 64 leaves
and 63 internal nodes. This is fixed `O(B_max)` work independent of
`nr_running`, and it requires a later timing rejection gate.

Authority publication changes the receipt generation, digest, and allowed
mask in constant work; it does not rewrite task nodes, domain queues, or top
selector summaries.

The scheduling plane remains mutable:

- task enqueue/dequeue/current updates modify only the task's slot queue;
- a changed slot head/eligibility summary updates one leaf and at most six
  fixed ancestors under the owning rq lock;
- selection visits only subtrees whose static slot mask intersects the
  current allowed mask, computes the best eligible allowed leaf from current
  live scheduling state, and visits no more than 127 fixed nodes; and
- after selecting a leaf, the normal slot-local EEVDF queue selects a task,
  followed by an exact task-local authority check.

The authorization plane remains immutable:

- generation is non-reused and saturation blocks;
- slot-map digest is frozen for the receipt lifetime;
- the allowed-slot mask is exactly 64 bits;
- publication performs no rq/task traversal, allocation, queueing, waiting,
  cancellation, or mutable selector repair;
- selector use requires sealed state and exact generation/digest; and
- cgroup, task-group, weight, vruntime, deadline, and topology state are never
  authority.

## Why R6 Avoids the R5 Contradiction

Ordinary EEVDF mutation changes a slot queue and the fixed top scheduling
summary, both under the rq lock. It does not change the slot identity or the
receipt's allowed mask. Authority publication changes only which fixed slot
branches may be traversed. It does not assert that queue summaries are
immutable.

Thus:

```text
immutable sealed authority mask
+ explicitly mutable per-slot EEVDF queues
+ explicitly mutable fixed-size masked top scheduling query
+ static subtree slot masks
= no stale copied selector view
```

This is a new hierarchy, not an R5 repair.

## Fairness Boundary

R6 changes flat CFS competition into explicit two-level scheduling:
domain-slot fairness followed by task fairness within a slot. It must not
claim equivalence to flat CFS.

Monitor-issued domain weights and their receipt binding require a separate
proof. The first R6 plan must define lag/deadline composition, sleeper
placement, weight changes, bandwidth/throttling interaction, idle groups,
fork/exec inheritance, migration, and CPU capacity behavior. Until that proof
and measurement pass, R6 is only a safety-oriented architecture direction.

## Admission and Lifetime Boundary

- Slot storage and queue state are allocated before admission; failure is
  `Blocked`.
- A task contributes to exactly one `(slot, rq)` at a time.
- Enqueue validates current descriptor generation, slot-map digest, and task
  slot binding before contribution.
- Migration is remove, neutral, then add; simultaneous source/destination
  contribution is forbidden.
- Slot reuse requires zero queued/current contributors, zero refs, retirement,
  and an RCU grace period; generation and digest are not reused.
- CPU offline stops admission under rq lock, removes top-selector visibility,
  then drains work/refs/RCU in sleepable teardown.
- Revocation prevents a revoked slot from the next pick immediately after the
  new sealed receipt is observed. A separately modeled current-stop
  distributor remains necessary for a task already running.

## Linux Mechanism Boundary

Current Linux already supplies hierarchical scheduling mechanisms:

- `sched_entity` has `parent`, owning `cfs_rq`, and owned `my_q`;
- a `task_group` owns per-CPU `cfs_rq` state;
- `group_cfs_rq()` descends a selected group entity;
- `find_matching_se()` walks ancestors to compare sibling entities;
- task-group assignment is copied under task and rq locking because raw
  cgroup/autogroup values can change before scheduler attach; and
- `__pick_task_fair()` updates and descends successive `cfs_rq` levels.

These are mechanism anchors only. R6 must not reuse `task_group` as authority
without an independent internal ownership and lifecycle design.

## Next Gate

R6-E1 must remain source-free and resolve:

1. exact fixed top-selector data, update rules, and the 127-node worst-case
   masked-query proof without a logarithmic overclaim;
2. per-rq and per-slot storage below a fixed budget;
3. two-level EEVDF fairness and weight semantics;
4. task admission, fork/exec, migration, current, and hotplug handshakes;
5. receipt publication/acquire and task-local revalidation;
6. allocation, slot exhaustion, generation saturation, and teardown failures;
7. disabled-build zero-cost and ordinary scheduler-object growth;
8. deterministic unsafe cases; and
9. later arm64-first layout, diagnostic, and timing rejection gates.

No R6 layout or source may be drafted until that plan independently passes.

## Claim Boundary

No R6 source, real scheduler attachment, runtime denial, monitor delivery,
N-136 runtime charge, flat-CFS fairness equivalence, bare-metal latency,
performance, cost, production protection, deployment, multi-node,
multi-cluster, or datacenter readiness is accepted.
