# Analysis 0162: SchedExecLease P5A-R2 E3 Rebuild Prototype Evidence Plan

Date: 2026-07-14

Status: pre-source gate for a disposable, default-off, test-only rebuild
prototype. No E3 source, production call site, Linux patch, runtime behavior,
or protection claim is approved by this document.

## Decision

Validation/0211 closed E2 with the same four provisional fields producing zero
structure growth on arm64 and x86_64. E3 may therefore test the correctness of
a full rebuild, but only on a new disposable descendant of the exact E2 commit.

The prototype will live in the same translation unit as CFS so KUnit can test
the actual static rb-tree, current-entity, and hierarchy traversal helpers. It
must not create a production object, exported helper, picker call site,
publisher, fanout worker, incremental update hook, tracepoint, debugfs file, or
userspace ABI.

## Exact Source Boundary

The E3 source draft, after this plan passes, must be created as:

```text
parent:    162d16640634637a6f7604b90bf2275bea47ec63
worktree:  build/DomainLeaseLinux.volume/worktrees/p5a-r2-e3-rebuild-prototype
branch:    codex/p5a-r2-e3-rebuild-prototype

allowed files:
  init/Kconfig
  kernel/sched/fair.c
```

The E2 fields and probe are frozen. E3 may not edit:

```text
include/linux/sched.h
kernel/sched/sched.h
kernel/sched/exec_lease_layout_probe.c
kernel/sched/Makefile
```

Primary Linux stays at `5e1ca3037e34823d1ba0cdd1dc04161fac170280` and
the primary patch queue stays at 0014. The E3 branch is measurement material,
not the future 0015 patch.

## Configuration Boundary

Add exactly one test configuration:

```text
CONFIG_SCHED_EXEC_LEASE_REBUILD_KUNIT_TEST
  bool
  default n
  depends on SCHED_EXEC_LEASE_LAYOUT_CANDIDATE && KUNIT=y
```

Ordinary `CONFIG_SCHED_EXEC_LEASE`, `KUNIT_ALL_TESTS`, and the existing denial
harness must not select it. All new source, including the KUnit include, test
fixture, rebuild helpers, semantic state constants, and suite registration,
must be inside this configuration boundary.

The suite name is fixed as `sched_exec_lease_rebuild`. It is registered from
`fair.c`, giving the tests direct access to the static CFS primitives without
adding a header declaration or Makefile object.

## Prototype Contract

The prototype owns no authority decision. A test-only leaf callback supplies a
valid/invalid leaf witness from frozen fixture data. It is an argument to the
prototype, not a stored scheduler callback, and cannot call policy or monitor
code. An independent test generation cell supplies deterministic release/
acquire publication and race injection; E3 does not add the real global
publisher or fanout.

The locked rebuild must:

```text
1. assert rq->lock ownership
2. acquire-read the target generation
3. set rq state to Refreshing before changing any aggregate
4. walk each cfs_rq in the existing leaf-before-parent list order
5. walk each tasks_timeline rb-tree child-before-parent using postorder
6. revalidate every task leaf exactly once for that cfs_rq
7. project an already rebuilt child cfs_rq through its parent group entity
8. combine validity and wrap-aware minimum without a numeric sentinel
9. combine cfs_rq->curr separately; never insert or pretend it is in the tree
10. acquire-read the generation again
11. publish built_generation and Fresh only if the generation is unchanged
    and the complete traversal succeeded
12. otherwise leave Stale or Blocked; generation saturation is Blocked
```

The root rb aggregate and separately validated root current entity remain the
O(1) root witnesses. No new `cfs_rq` or `rq` minimum field is authorized.

The same `sched_entity` fields can hold a rebuilt child projection before that
group entity is folded into its parent rb subtree. Child cfs_rqs must therefore
be completed before their parents. A task entity's local input is always
revalidated by the test callback; a previous aggregate value is never treated
as the next rebuild's local truth.

## Traversal Proof Obligations

The source already supplies:

```text
rbtree_postorder_for_each_entry_safe(): child before parent
for_each_leaf_cfs_rq_safe(): leaf cfs_rq list
list_add_leaf_cfs_rq(): explicit child-before-parent ordering invariant
vruntime_cmp()/min_vruntime(): signed-delta cyclic ordering
lockdep_assert_rq_held(): scheduler lock assertion
```

The rb postorder iterator permits changing fields in the current entity but
does not permit erase, insert, rotation, or any other tree reordering. The E3
prototype may only write the two candidate aggregate fields and the two rq
receipt fields. It may not change `run_node`, `tasks_timeline`, queue counts,
`curr`, group linkage, task placement, or throttling state.

There is no recursive group traversal. The hierarchy pass uses the existing
bottom-up list, and the rb pass uses parent-linked iterative postorder. No
kernel-stack depth claim is needed or made.

## Independent Oracle

The KUnit oracle must not call the production combine helper, production
postorder helper, `min_vruntime()`, or the hierarchy iterator under test. It
must enumerate fixture arrays in a separate representation and implement the
cyclic comparison directly as a signed 64-bit delta.

For every completed rebuild it compares:

```text
validity tag
minimum only when validity is true
per-node aggregate
child-to-parent group projection
root tree witness
separate root current witness
rq semantic state
built generation
leaf visit count (exactly once)
```

The exhaustive small-state core covers all freshness masks and insertion
orders for up to six leaves and vruntime bases around `0`, `S64_MAX`, and
`U64_MAX`. Larger deterministic cases check shape independence without
claiming exhaustive state-space coverage.

## Required KUnit Cases

The suite must include all of these families:

```text
empty and singleton trees
all-invalid, all-valid, and mixed-validity trees
cyclic vruntime values straddling zero and U64_MAX
tree-only, current-only, and tree-plus-current cfs_rq
balanced, left-heavy, and right-heavy rb shapes
one-level and nested group projections in bottom-up list order
throttled/invalid child exclusion and later revalidation
enqueue-like insertion and dequeue-like removal between full rebuilds
current enter, current advance, and current leave between rebuilds
cgroup-like parent change between rebuilds
affinity/migration-like old-rq removal and destination-rq addition
publication before simulated fanout/rebuild
publication during rebuild and rapid repeated generation changes
generation saturation
```

Event names above describe fixture mutations followed by a new complete
rebuild. E3 does not add or validate incremental scheduler hooks.

## Forbidden Locked Operations

The rebuild body and its callback path may not:

```text
allocate or free memory
sleep, wait, schedule, or yield
call monitor, security policy, userspace, or firmware code
take another task/rq lock or drop the owned rq lock
emit tracing or printk per entity
insert, erase, rotate, reorder, enqueue, dequeue, migrate, or throttle
publish Fresh before the final generation re-read
use recursion or an unbounded explicit stack
```

Fixtures may allocate before taking the synthetic rq lock. KUnit reporting
occurs after the locked helper returns.

## Build and Boot Matrix

The E3 validation must rebuild from fresh output directories:

```text
candidate parent, prototype absent
E3 source with CONFIG_SCHED_EXEC_LEASE=n
E3 source with lease/layout candidate on and rebuild KUnit off
E3 source with lease/layout candidate/KUnit/rebuild KUnit on
```

The first three modes must contain no rebuild suite or helper symbols. The
enabled mode must compile the suite and prototype. An arm64 QEMU boot must run
only the `sched_exec_lease_rebuild` suite and produce complete KTAP with zero
failed or skipped required cases. Build and boot evidence must record exact
commit, config, compiler, kernel image hash, fair.o hashes/symbols, KTAP, and
QEMU command.

Passing KUnit is rebuild-correctness evidence for synthetic fixture state. It
is not live scheduler integration, concurrent real-rq mutation, full runtime
coverage, or lock-hold performance evidence.

## Rejection Boundary

Reject E3 if its parent or frozen layout changes, a third file changes, the
config is selected normally, a helper survives with the config disabled, an
oracle shares the implementation being checked, a required case is missing,
a leaf is missed or visited twice, cyclic ordering differs, a group is
processed before its child, current is folded into the tree, a raced rebuild
becomes Fresh, saturation reuses a generation, the helper mutates topology,
or KUnit does not complete cleanly.

Any compile or boot failure is evidence against the draft. The gate is not
weakened to preserve the candidate.

## Claim Boundary

Even a passed E3 prototype does not approve:

```text
the four fields for production
primary Linux or patch queue changes
a real publisher, fanout, worker, or picker fence
incremental enqueue/dequeue/current/group update closure
runtime denial or execution correctness
production protection or monitor enforcement
bounded rq-lock hold, latency, throughput, energy, density, or cost
deployment or datacenter readiness
```

E4 remains the first stage allowed to measure the locked interval. A failed E4
rejects full O(n) rebuilding as a behavior candidate even if E3 is correct.

## Next

Run validation/0212. Only if the plan passes may the exact disposable E3
worktree and its two-file source draft be created.
