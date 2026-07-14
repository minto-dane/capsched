# Implementation 0042: SchedExecLease P5A-R2 E3 Disposable Rebuild KUnit Prototype

Date: 2026-07-14

Status: disposable source draft complete and targeted arm64 compile passed.
The source and rebuild correctness remain unaccepted pending validation/0213.

## Source Identity

```text
worktree: build/DomainLeaseLinux.volume/worktrees/p5a-r2-e3-rebuild-prototype
branch:   codex/p5a-r2-e3-rebuild-prototype
parent:   162d16640634637a6f7604b90bf2275bea47ec63
commit:   d1d5e78da8484c91eae70f22399c6901da680ea0
tree:     aa6a5a3848415643f3b67434964b056e30421bb2
diff sha: a5351bbdd7a6617382bdea5ca9a7546e3defd97bd4a08c9c6ccf53390a88b4ed
delta:    947 additions, 0 deletions, exactly two files
```

The changed files are only `init/Kconfig` and `kernel/sched/fair.c`. The E2
field declarations, layout probe, scheduler Makefile, primary Linux commit,
and 0014 patch queue are unchanged.

## Isolation

`CONFIG_SCHED_EXEC_LEASE_REBUILD_KUNIT_TEST` is a default-off bool depending
on the disposable layout candidate and built-in KUnit. All C source, including
the KUnit include and suite registration, is under that boundary in `fair.c`.

There is no picker call, publisher, fanout, worker, incremental scheduler hook,
export, tracepoint, debugfs file, ABI, Makefile object, or primary patch.

## Rebuild Shape

The locked prototype:

1. asserts rq-lock ownership and acquire-loads the fixture generation;
2. rejects `U64_MAX` generation as Blocked;
3. marks the rq Refreshing;
4. clears old validity tags over every listed cfs_rq and the root;
5. rebuilds each rb-tree child-before-parent with the real postorder iterator;
6. processes the real cfs_rq list child-before-parent without recursion;
7. validates task leaves exactly once and projects completed child summaries;
8. combines current separately from the rb-tree;
9. acquire-loads generation again; and
10. publishes Fresh and built generation only when the complete pass is stable.

Only the four E2 candidate fields are written. Tree topology, queue state,
placement, throttling, and ordinary scheduler augmentation are not mutated.

## Independent Oracle and Cases

The oracle uses separate fixture arrays and a direct signed-delta cyclic
comparison. It does not call the prototype combine function,
`min_vruntime()`, or the postorder iterator. It independently checks every
flat rb node, root tree/current witnesses, validity/value pairs, generation,
rq state, and exact leaf visit counts.

The exhaustive case enumerates every freshness mask and insertion permutation
for one through six leaves at bases around zero, `S64_MAX`, and `U64_MAX`.
Eleven additional cases cover empty/singleton, tree/current combinations,
nested groups, invalid/throttle-like child state, enqueue/dequeue, current
transitions, cgroup-like movement, old/destination-rq migration, publication
before rebuild, publication races/rapid bumps, and saturation.

## Local Source Checks

Strict checkpatch passed with zero errors, warnings, and checks. An arm64
targeted build with lease, layout candidate, KUnit, and rebuild test enabled
compiled `kernel/sched/fair.o` successfully.

These are source and compile facts, not KUnit runtime evidence. The controlled
off/layout-on/test-on object matrix and QEMU KTAP remain validation/0213 work.

## Non-Claims

This draft does not accept E3 correctness, the E2 layout for production, a
real generation protocol, runtime denial, protection, lock-hold performance,
cost, deployment, or datacenter readiness. E4 remains unauthorized.
