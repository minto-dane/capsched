# SchedExecLease P5A-R6 Sealed Masked Domain Forest

Date: 2026-07-24

## Decision

The source-free R6 architecture gate passes. R6 selects Sealed Masked Domain
Forest: an immutable generation-sealed authorization mask separated from
explicitly mutable, rq-lock-maintained domain and task scheduling state.

Only an R6-E1 source/locking/layout/fairness evidence plan may now be drafted.
No R6 layout, configuration, Linux source, primary-Linux or patch-queue
change, runtime behavior, or broader claim is authorized.

## Exact Trigger

The gate revalidates R5 E1 rejection result SHA-256
`6fee1f3f3d68cbc816321b2759de71b1a35e64f8d207425fcfe5d0d86b7fe0a5`.
That result proves the R5 combination fails before source: an immutable copied
selector view becomes stale under ordinary EEVDF mutation, stale trust loses
safety, and stale refusal loses allowed progress.

R6 retains the immutable receipt but does not retain the immutable selector
copy.

## Candidate Decision

Three candidates are compared:

- Flat generation-aware task-tree augmentation is rejected because exact
  arbitrary-mask eligibility needs per-slot minima, variable task search, or
  authority-update repair.
- Treating cgroup/task-group state as authority is rejected because Linux
  membership, shares, and topology are mutable policy rather than a monitor
  receipt.
- Sealed Masked Domain Forest is selected because authority publication
  changes only an immutable 64-bit allowed-slot mask while scheduler mutation
  changes separate live per-slot queues and top-selector summaries.

Exactly one candidate is selected.

## Selected Contract

R6 fixes `B_max = 64`. Each admitted task contributes to one authority slot
and rq. Each active slot owns a dynamically maintained EEVDF queue. The top
selector has 64 fixed leaves and six levels; a slot state change updates one
leaf and at most six ancestors under the rq lock.

Each top subtree has a static slot mask. A query skips subtrees disjoint from
the sealed allowed mask and evaluates current scheduling state for allowed
branches. A single minimum cannot summarize every arbitrary allowed subset,
so this validation makes no logarithmic picker claim. The exact structural
worst case is 64 leaves plus 63 internal nodes: 127 fixed nodes independent of
`nr_running`. That bound still requires later arm64-first timing rejection
gates.

The authority receipt uses a non-reused generation, frozen slot-map digest,
and exact 64-bit allowed mask. Publication is constant work and performs no rq,
task, or queue traversal; allocation; queueing; waiting; flush; cancellation;
or selector repair. Cgroup/task-group state, weights, vruntime, deadlines, and
topology are not authority.

Allocation completes before admission or the task is `Blocked`. Enqueue
revalidates generation, digest, and task slot. Migration is
remove-neutral-add. Slot reuse requires zero contributors and refs, retirement,
and RCU grace. Offline stops admission before visibility removal and completes
sleepable work/ref/RCU teardown. Current-task stop remains a separate
distributor.

## Fairness Boundary

R6 explicitly creates two-level domain-then-task fairness and does not claim
flat-CFS equivalence. Monitor-issued domain weights, lag/deadline composition,
sleeper placement, throttling, idle behavior, and CPU-capacity behavior remain
R6-E1 proof obligations. No performance claim is accepted.

## Linux Mechanism Boundary

The gate binds primary Linux commit
`5e1ca3037e34823d1ba0cdd1dc04161fac170280`, tree
`54f685aad94f28f0027cbba18cf5e29aadce234a`.

All 16 current mechanism anchors pass for `task_group`, per-CPU `cfs_rq`,
group allocation/initialization, `sched_entity` parent/owning/owned queues,
group descent, task-group assignment under scheduler locks, ancestor matching,
and the hierarchical `__pick_task_fair()` loop. All six future R6 source
patterns remain absent. The tracked Linux tree is clean.

These anchors establish mechanism availability only; task groups and cgroups
are not accepted as authority.

## Formal and Focused Validation

Canonical run `20260724T-p5a-r6-sealed-masked-domain-forest-r1` produces
result SHA-256
`82f9c5dd5f6793934e18ded895501a363527df144a3874a427437cef1ffe0bd6`.

The safe model passes:

```text
states generated:     5
distinct states:      5
search depth:         5
liveness properties:  2
```

The trace mutates live selector state, selects an allowed slot, publishes a
constant-work revocation, and separately observes current-task stop. All 13
unsafe safety faults produce expected counterexamples for receipt, generation,
slot map, publication work, top bound, cgroup authority, task binding,
allocation, flat fallback, stale summary, denied branch visibility, premature
source, and production overclaim. Two liveness faults produce expected
counterexamples for missing allowed selection and missing current stop.

Focused tests accept the exact contract and reject nine mutations, including
the logarithmic picker overclaim. Bash syntax checks and VM ShellCheck pass.
Canonical read-only evidence contains 95 files in 180 KiB.

## Next Gate

R6-E1 must remain source-free and define exact:

1. top-selector storage, live summary rules, and 127-node bound;
2. per-rq/per-slot memory and disabled-build zero-cost limits;
3. two-level EEVDF fairness and monitor-weight receipt semantics;
4. admission, fork/exec, enqueue, migration, current, and offline handshakes;
5. allocation, slot exhaustion, generation saturation, teardown, and failure;
6. deterministic unsafe cases; and
7. future layout, diagnostics, and arm64-first timing rejection gates.

## Claim Boundary

No R6 source, real scheduler attachment, runtime denial, monitor delivery,
N-136 runtime charge, flat-CFS fairness equivalence, bare-metal latency,
performance, cost, production protection, deployment, multi-node,
multi-cluster, or datacenter readiness is accepted.
