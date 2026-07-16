# Implementation 0045: SchedExecLease P5A-R3 E3 Bucket Concurrency Prototype

Date: 2026-07-16

Status: exact disposable source candidate committed. Source-gate and diagnostic
matrix results are recorded separately; this record makes no runtime or
production claim.

## Disposable identity

```text
worktree: build/DomainLeaseLinux.volume/worktrees/p5a-r3-e3-bucket-concurrency-prototype
branch:   codex/p5a-r3-e3-bucket-concurrency-prototype
parent:   63313b329e1d44901acfce30698613c38615c8d5
commit:   60e148fa0476c742b13a743345d1383db04fc843
tree:     326da04e5b11e8036a4074b1d363410b21033ef8
diff sha: 1f591cfd4d6c05e6eb42f2f14120f23d6645c0e0b6cb6b0615f069f10a93d0d7
```

The commit is the direct child of the frozen E2 candidate. It adds 1,999 lines
and deletes none in exactly `init/Kconfig` and
`kernel/sched/exec_lease.c`. The E2 private layout and all 43 E2 probe values
are byte-identical to the parent. Strict checkpatch is 0/0/0.

## Prototype boundary

`CONFIG_SCHED_EXEC_LEASE_BUCKET_KUNIT_TEST` is default off, depends on the E2
layout boundary and built-in KUnit, and is not selected by `KUNIT_ALL_TESTS`.
The suite remains in `exec_lease.c`, so no private type or helper is exported.
No runqueue, task, cgroup, picker, hotplug callback, monitor, ABI, tracepoint, or
ordinary scheduler path reaches it.

The synthetic protocol uses the actual E2 private bucket, projection, rq-state,
raw lock, refcount, cpumask, XArray, work item, and RCU fields. It includes the
fixed `B_max=64` rejection boundary; all six pre-runnable allocation faults;
queued/delayed/current accounting; coalesced generation publication; a single
work owner; remove-neutral-add migration; offline settlement; RCU unpublish;
pending/running/requeued cancellation; and retirement drain.

The same-TU suite is named `sched_exec_lease_bucket` and registers exactly the
20 deterministic case families frozen by analysis/0168. Completion waits have
a five-second bound, and the coalescing, migration, hotplug, and retirement
stress paths repeat 1,024 times. Expected state is held in a plain oracle record
which contains no E2 private type and calls no prototype transition helper.

## Non-claims

This source is a disposable diagnostic candidate, not a scheduler feature. A
source-gate pass permits only the specified build/QEMU diagnostic matrix. It
does not prove runtime correctness, authorize primary Linux or patch-queue
changes, or establish protection, latency, performance, deployment, or
production readiness.
