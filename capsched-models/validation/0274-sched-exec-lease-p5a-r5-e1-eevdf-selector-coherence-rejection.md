# SchedExecLease P5A-R5 E1 EEVDF Selector-Coherence Rejection

Date: 2026-07-24

## Decision

R5 Generation-Sealed Immutable Projection is rejected before layout or Linux
source. Its immutable authority receipt remains useful, but its immutable
selector view cannot satisfy both fail-closed safety and allowed-task progress
after ordinary current EEVDF mutations.

Only a new source-free successor analysis may start. R5 repair, R6 source,
primary-Linux or patch-queue changes, runtime behavior, and broader claims are
not authorized.

## Exact Prerequisite and Source Boundary

The gate revalidates R5 architecture result SHA-256
`ceb595322a92886c2296cbcafd3c2fd08b220753a250ac2c4a7222a54a64bf9b`.
That result authorized only E1 source-free investigation and explicitly
deferred EEVDF representation and selector proof.

The gate binds primary Linux commit
`5e1ca3037e34823d1ba0cdd1dc04161fac170280`, tree
`54f685aad94f28f0027cbba18cf5e29aadce234a`. All 18 source anchors pass for:

- `cfs_rq` weighted virtual-time state and the cached deadline tree;
- `sched_entity` live RB node and subtree minimum-vruntime augmentation;
- augmented RB insertion and erasure;
- `avg_vruntime()`, `update_curr()`, enqueue, dequeue, and `pick_eevdf()`;
- the live eligible-left-subtree descent; and
- the experimental full-tree pickable fallback scan.

The tracked primary Linux tree is clean. No Linux file is changed by this
gate.

## EEVDF Contradiction

Authority generation and membership can remain stable while normal scheduling
changes current vruntime, weighted sums, tree membership, deadline ordering,
and subtree minimum-vruntime augmentation. Consequently, the first such
mutation after R5 installs an immutable selector view makes that view stale.

The allowed options under the R5 contract are exhaustive:

1. Trust the stale view, which loses the exact current selector proof.
2. Reject the stale view, which is fail-closed but may leave an allowed
   runnable entity unavailable indefinitely.
3. Scan the live tree, which restores the rejected variable `O(n)` picker
   path.
4. Maintain the selector view at each mutation, which makes it mutable and is
   a different architecture.

An off-lock snapshot or sequence retry does not solve this: ordinary EEVDF
progress invalidates it again after installation. A second live scheduling
tree or authority-aligned hierarchy requires a new layout, lifecycle,
fairness, and measurement architecture and cannot be called an R5 repair.

## Formal and Focused Validation

Canonical run
`20260724T-p5a-r5-e1-eevdf-selector-coherence-rejection-r1` produces result
SHA-256
`6fee1f3f3d68cbc816321b2759de71b1a35e64f8d207425fcfe5d0d86b7fe0a5`.

The safe configuration refuses the stale view and passes:

```text
states generated:  3
distinct states:   3
search depth:      3
```

Trusting the stale view produces the expected `Safety` invariant violation.
Adding eventual allowed selection to the safe configuration produces the
expected temporal counterexample ending in a blocked stuttering state.

The focused contract test accepts the exact JSON and rejects eight mutations:
assuming authority stability makes the selector static, removing immutability,
trusting stale state, enabling a variable picker scan, marking R5 feasible,
authorizing an R5 repair, or prematurely authorizing R5 or R6 source. Bash
syntax checks and VM ShellCheck pass.

The canonical evidence is read-only, contains 12 files in 32 KiB, and records
zero source-anchor failures.

## Successor Requirement

A successor must preserve an immutable generation receipt as the trust fence
while making authorization an explicit input to dynamically maintained EEVDF
selector state. Source-free comparison must cover at least:

1. generation-aware allowed-subtree augmentation in the existing EEVDF tree;
2. authority-aligned per-rq scheduling queues with explicit fairness
   composition; and
3. monitor-compiled scheduling hierarchy mapping without treating mutable
   cgroup policy as authority.

No successor is selected by this validation.

## Claim Boundary

No R5/R6 source, real scheduler attachment, runtime denial, monitor delivery,
N-136 runtime charge, bare-metal latency, performance, cost, production
protection, deployment, multi-node, multi-cluster, or datacenter readiness is
accepted.
