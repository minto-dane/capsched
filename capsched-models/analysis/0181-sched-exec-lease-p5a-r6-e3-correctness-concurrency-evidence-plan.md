# Analysis 0181: SchedExecLease P5A-R6 E3 Correctness and Concurrency Evidence Plan

Date: 2026-07-26

Status: source-free pre-source plan. Passing this plan may authorize one exact
disposable, default-off, same-translation-unit R6-E3 KUnit source draft. It
does not accept source, connect Linux scheduler or cgroup seams, or establish
runtime behavior.

## Decision Boundary

Validation/0278 closed the exact R6-E2 layout on fresh arm64 and x86_64
baselines and through an independent read-only closure. E3 is therefore
allowed to plan synthetic correctness evidence, but not to assume that layout
success proves selector, fairness, hierarchy, migration, current-stop,
hotplug, or lifetime correctness.

The three transitions remain separate:

```text
source-free plan pass
  -> exact disposable E3 draft may be created

exact source/build gate pass
  -> four diagnostic boots may start

complete diagnostic evidence plus independent closure
  -> a separate source-free E4 timing plan may be considered
```

No transition promotes the disposable E2/E3 branch to primary Linux or the
patch queue.

## Frozen Evidence and Future Source

The plan binds:

```text
primary Linux:
  5e1ca3037e34823d1ba0cdd1dc04161fac170280
  tree 54f685aad94f28f0027cbba18cf5e29aadce234a

R6-E2 parent:
  66e2fd20fc85012d7dc03649fcf4c7af583cbb94
  tree 603762b7a36d7b57e2456b90538c3ba77a1aba16
  diff 1ae8a83fd083c9c96412da2db98298cc708b743fc8b6266a49e16e29c16058ed

R6-E2 source gate:
  18c329d9f10a34559056f8ef00007f9d6644b82b5d4be5f8227a4d7f8f9d452f

R6-E2 dual architecture:
  6164a7a9913e9cf6da96a7f09944c3a18225ddddb8d1ccc690350d339b2890a4

R6-E2 independent closure:
  e937c252819d0e79b8815b540641002f9f9bb22b6f432f3ab1e18992d6b0c7b8
```

The future draft is a signed-off direct child of the R6-E2 commit on
`codex/p5a-r6-e3-correctness-prototype`. It changes exactly `init/Kconfig` and
`kernel/sched/exec_lease.c`.

The 49 R6 layout values, the 51 existing expanded values, the E2 private type
block, and all public/scheduler headers remain exact. Ordinary
`sched_entity`, `cfs_rq`, `rq`, and `task_struct` growth remains zero.

## Configuration and Isolation

The only new option is:

```text
CONFIG_SCHED_EXEC_LEASE_R6_KUNIT_TEST
  bool
  default n
  depends on SCHED_EXEC_LEASE_R6_LAYOUT_PROBE && KUNIT=y
```

It is not selected by the lease option, either probe, or `KUNIT_ALL_TESTS`.
The exact suite is `sched_exec_lease_r6_correctness`. Test helpers, fixtures,
fault knobs, receipts, and suite registration stay within the E2 translation
unit and option.

Disabled and release modes contain no E3 symbol, relocation, string, initcall,
allocation, or test surface. E3 adds no export, static key, tracepoint,
debugfs/proc/sysfs/securityfs entry, device, netlink family, or ABI.

The suite may instantiate the exact E2-private slot, top-node, control, and rq
types around a synthetic rq shell using real raw spinlocks, refs, cpumasks,
and RCU. It may not attach anything to a live `rq`, `cfs_rq`, `sched_entity`,
`task_struct`, `task_group`, or cgroup; call a production scheduling/hotplug
seam; call `resched_curr()` on a live rq; or make a monitor, policy, budget,
authority, admission, or denial decision.

## Independent 64-Leaf Oracle

The oracle is a plain array of exactly 64 immutable leaf records. It may not
call or share the implementation's tree traversal, mutation, reconciliation,
task-binding, or migration helpers. For each forced transition, the harness
snapshots implementation state under documented locks and separately derives:

```text
allowed and runnable aggregate
left-biased signed EEVDF division result
eligible set and earliest deadline
stable slot-id tie break
expected pick or explicit no-pick
aggregate, candidate, and total visit counts
leaf and ancestor versions
changed-mask bit count and reconciliation ledger
task/domain/root/slot/generation acceptance
source, neutral, and destination contributions
current stop request and later observation sequences
accepting, visibility, readers, refs, grace, and free state
fairness service and denied-service ledgers
```

Empty, singleton, alternating, all-64, current-only, and revoked-current masks
are mandatory. The oracle explicitly enumerates all 64 leaves even when the
implementation skips a disjoint or fully covered subtree.

Each case emits a machine-readable receipt containing input leaves, mask,
forced schedule, fault point, implementation snapshot, independent expected
result, visit ledger, contribution equation, reference equation, and cleanup
state. Failure does not skip final cleanup or leak checks.

## Structural Bounds

The prototype must enforce and measure:

```text
slots                                      64
unique complete-tree nodes                127
levels                                      6
aggregate phase visits                 <= 127
candidate phase visits                 <= 127
complete query visits                  <= 254
changed leaf ancestor updates           <=   6
descriptor reconcile slot visits        <=  64
authorization task-tree scan                  0
```

Changed-mask cases are exactly 0, 1, 63, and 64 bits. Leaf-update cases include
both valid boundary indices 0 and 63; active-slot cardinality covers 0, 1, 63,
and 64 without accepting a 65th slot. Leaf and summary versions must agree
after each mutation. These are structural work limits, not latency or
performance claims; arbitrary-mask selection is not claimed logarithmic.

## Fairness Oracles

The top level uses fixed `NICE_0_LOAD` weight and is tested separately from
ordinary fairness inside the selected domain.

For a canonical 4,096-round experiment with all 64 domains continuously
runnable, equal slices, and a stable all-allowed mask:

- service difference between any two domains is at most one top slice;
- every domain's pick gap is at most 64 selections;
- a denied domain gains exactly zero service;
- a reallowed domain starts with zero negative lag;
- its first service is at most one top slice;
- unauthorized time creates exactly zero catch-up credit; and
- positive debt is not erased by revoke/reallow.

The reference ledger and expected sequence are computed independently.
Passing does not claim flat-CFS equivalence, variable domain weights, PELT,
bandwidth, uclamp, load balance, EAS, core scheduling, sched_ext, RT/DL,
deadline server, proxy execution, or CPU-capacity integration.

## Hierarchy, Task, and Migration

Valid composition remains one sealed domain per dedicated root-child fair
subtree with same-domain descendant cgroups. Cgroup identity and shares are
mechanism, never authority.

The suite must reject mixed-domain subtrees, one domain mapped to multiple
roots, leased fair-root tasks, autogroup, unsealed/stale/digest-mismatched
descriptors, and final task generation/domain/slot mismatch.

Fork inherits a frozen binding. Exec advances its generation before runnable
commitment. Enqueue rechecks the sealed descriptor, slot, root, CPU mask,
online state, and accepting state before exactly one contribution.

Cgroup move settles under a synthetic `task_rq_lock()` equivalent and accepts
only the same slot or an already frozen replacement binding. CPU migration is
remove-neutral-add. Destination rejection for mask, root, capacity, online,
or accepting state leaves a single explicit `BlockedNeutral` state; it never
restores an unverified source contribution or falls back to the ordinary root.

## Current, Hotplug, RCU, and Faults

A revoked current domain is distinct from next-pick filtering. The synthetic
rq-locked transition records a stop request; only a later distinct scheduler
observation may record changed or revalidated current. The request is not a
monitor interrupt or completion receipt.

Online ordering is:

```text
allocate -> initialize -> publish -> accept
```

Offline ordering is:

```text
stop accepting -> remove visibility -> drain contributions/readers/refs
-> unpublish -> RCU grace -> free
```

Sleepable drain, cancellation, allocation, free, and grace waiting are outside
all scheduler locks. Free requires zero queued/current contribution, readers,
refs, and transitions. Generation and slot-identity saturation block until
quiescent replacement and never wrap into trust.

Fault injection covers sealed descriptor, per-CPU private rq state, and task
binding allocation. All occur before runnable contribution, never under
task/rq locks. Every failure leaves no contribution or reference and permits a
clean retry after fault removal. Slot 65 blocks without alias, eviction,
merge, or fallback.

## Mandatory Cases and Race Control

The JSON contract names 55 non-reducible case families spanning masks,
traversal, tree mutation, reconciliation, signed arithmetic, fairness,
descriptor faults, hierarchy, task lifecycle, cgroup move, migration, current,
hotplug, RCU, saturation, allocation, capacity, references, and cleanup.

Race sides use completions, atomic checkpoints, or explicit barriers.
Timing-only sleeps are not proof. Each case has a 15-second hard timeout. Each
diagnostic profile repeats its stress families at least 4,096 times using a
recorded deterministic seed set. No required case may be skipped,
expected-fail, or removed after a failure.

## Build and Diagnostic Matrix

Each architecture uses fresh outputs for:

```text
exact E2 parent with layout on
E3 candidate with layout on and E3 test off
E3 candidate with layout on and E3 test on
E3 candidate normal/release with probes and test off
```

Arm64 and x86_64 preserve the existing 51 values and E2's 49 values where
enabled, exclude E3 artifacts when disabled, keep zero ordinary structure
growth, and pass strict checkpatch 0/0/0.

Four fresh diagnostic boots are mandatory:

```text
arm64   standard debug + lockdep + RCU + hotplug + allocation faults
x86_64  standard debug + lockdep + RCU + hotplug + allocation faults
arm64   generic KASAN + lockdep + exact suite
x86_64  KCSAN + lockdep + exact suite
```

Every profile runs the exact suite and every required case/receipt with zero
failure, skip, timeout, or warning. KASAN, KCSAN, lockdep, refcount, workqueue,
irq-work, RCU, kmemleak, WARNING, BUG, Oops, panic, stall, hung-task, lockup,
or CPUHP diagnostics reject the source. Missing/reduced/corrupt evidence is a
harness failure, never a pass.

## Authorization and Claim Boundary

Passing this source-free plan authorizes only the exact disposable E3 draft
and a later source gate. E3 source and correctness remain blocked until the
exact source/build matrix, all four complete boots, and an independent
evidence closure pass.

E4 planning/source, primary Linux or patch-queue promotion, live scheduler
behavior, runtime admission or denial, monitor delivery/enforcement, N-136
charging, flat-CFS equivalence, cross-class coverage, bare-metal validity,
performance, cost, production protection, deployment, multi-node,
multi-cluster, and datacenter readiness remain false.
