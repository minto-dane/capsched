# SchedExecLease P5A-R5 Generation-Sealed Immutable Projection

Date: 2026-07-24

## Decision

The source-free R5 architecture gate passes. R5 selects generation-sealed
immutable projection views built outside rq-lock install phases, with an exact
receipt and constant-work RCU pointer install. Only an R5-E1
source/locking/lifetime evidence plan may now be drafted.

No R5 layout, configuration, Linux source, primary-Linux or patch-queue
change, runtime behavior, or broader claim is authorized.

## Exact R4 Trigger

The gate revalidates complete R4 arm64 result SHA-256
`edb07251794914381433d4ff221753c4b038afe6b02e969f2ad93d67860a0951`
and both independent closures normalized to
`8ebacd3c03dee0519a978cd21a7537b729fb61267d2491b70f76f54219fa84b5`.
It independently reproduces the 682 cells, 6,820,000 pairs, 362 rejected
cells, 692 breaches, family row/rejection counts, and exact reason counts.

The successor decision is not based only on rare TCG maxima. Recovery has
97 p99 and 96 p99.9 failures, notifier has 48 of each, offline has 15 of each,
and IRQ dispatch has four p99 failures. R5 therefore removes mutable
projection repair and notifier-driven repair from rq-lock quanta. Fixed R4
thresholds are not relaxed or reinterpreted.

## Contract

The gate requires:

- one frozen, release-published descriptor with non-reused generation,
  eligibility, selector key, authority digest, and membership sequence;
- one preallocated coalescing compile owner per demanded rq/bucket, with the
  newest desired generation winning;
- immutable view construction outside the rq lock and no assumed-safe lockless
  traversal of mutable scheduler trees;
- matching build-start/build-end descriptor and membership observations;
- a sealed seven-field receipt before installation;
- one-rq-lock constant-work install that performs final exact checks and swaps
  one RCU pointer without scanning, allocation, variable hashing, compilation,
  queueing, waiting, flushing, or cancellation;
- picker checks for sealed state, exact generation/membership/selector/digest,
  entity membership proof, and a final task-local check;
- fail-closed Blocked state on mismatch, race, allocation, or build failure;
- a current-stop distributor separate from projection compilation/install;
- explicit enqueue, migration, offline, reference, RCU, and retirement
  obligations; and
- stable-window liveness assumptions without a global settlement or
  wall-clock claim.

An old view, work pending bit, RCU pointer alone, or incomplete receipt is not
authority.

## Linux Mechanism Boundary

The gate binds primary Linux commit
`5e1ca3037e34823d1ba0cdd1dc04161fac170280`, tree
`54f685aad94f28f0027cbba18cf5e29aadce234a`.
All 11 current mechanism anchors pass for RCU pointer replacement/publication,
`call_rcu()`, saturating refcounts, seqcount observation, rq-locked
`resched_curr()`, and workqueue coalescing. All six future R5 source patterns
remain absent.

These anchors show available mechanisms only. They do not establish a
consistent scheduler-membership snapshot or approve an implementation.

## Formal and Focused Validation

Canonical run
`20260724T-p5a-r5-generation-sealed-immutable-projection-r1` produces result
SHA-256
`ceb595322a92886c2296cbcafd3c2fd08b220753a250ac2c4a7222a54a64bf9b`.

The safe model passes with:

```text
states generated:   16
distinct states:    16
search depth:       16
liveness branches:  2
```

The two temporal properties cover stable eligible demand installation and
stable revoked demand blocking. All 49 unsafe faults produce expected
counterexamples, including missing trigger/closure, relaxed thresholds,
publisher fanout, mutable or mismatched trust, unsealed install, rq-lock build
or scan, old-view fallback, duplicate owners, lost newest generation, missing
RCU/ref lifetime, projection-repair notifier restoration, current-stop
conflation, absent stable-window assumptions, migration/offline defects,
premature x86/R5 source, and overclaims.

Focused contract tests accept the exact JSON and reject six mutations:
rq-lock repair restoration, unsealed install, install-time membership scan,
old-view fallback, current-stop repair authority, and premature R5 source
approval. VM ShellCheck passes for both runner and test.

## Next Gate

R5-E1 must remain source-free and resolve the exact membership-sequence owner,
bounded view representation, EEVDF-compatible membership/selection proof,
compile inputs and locking, allocation failure, install seam, current
contributor index, enqueue/migration/offline handshakes, and full
reference/RCU/hotplug teardown. It must define deterministic unsafe cases and
later measurement rejection gates before any layout draft.

## Claim Boundary

No R5 source, real scheduler attachment, runtime denial, monitor delivery,
N-136 runtime charge, bare-metal latency, performance, cost, production
protection, deployment, multi-node, multi-cluster, or datacenter readiness is
accepted.
