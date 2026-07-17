# Implementation 0047: SchedExecLease P5A-R4 E2 Private Layout Candidate

Date: 2026-07-17

Status: exact disposable source candidate committed and dual-architecture E2
layout evidence closed by validation/0240. This candidate is accepted only as
input to an R4-E3 pre-source plan; it is not accepted for runtime or production
use.

## Disposable Source Identity

```text
worktree: build/DomainLeaseLinux.volume/worktrees/p5a-r4-e2-layout
branch:   codex/p5a-r4-e2-layout
parent:   5e1ca3037e34823d1ba0cdd1dc04161fac170280
commit:   a429fc30252ac6af94c51d96cd4ac24e72d9f83b
tree:     fffd419bbc05bab87ad304c1e4a3213439d62bab
diff sha: 94dedc73b731c451d52b90885cd63a350a1cd562a3b1b40f856c5984b4f6cd15
```

After closure, the clean disposable checkout was retired to reclaim space.
The local/fork branch and commit remain intact and can recreate it with
`git -C linux worktree add ../build/DomainLeaseLinux.volume/worktrees/p5a-r4-e2-layout codex/p5a-r4-e2-layout`.

The direct child adds 254 lines in exactly:

```text
init/Kconfig
kernel/sched/exec_lease.c
```

The rejected R3 source is not its parent. Primary Linux remains at
`5e1ca3037e348`, and the patch queue remains at `0014`.

## Build-Only Layout

`CONFIG_SCHED_EXEC_LEASE_R4_LAYOUT_PROBE` defaults to off and depends on the
existing lease/layout debug boundary, SMP, fair-group scheduling, and IRQ work.
Nothing selects it normally. The private translation-unit-only candidate
contains:

```text
sched_exec_r4_bucket_key     frozen eight-word projection label
sched_exec_r4_bucket         membership/index state plus one notifier work
sched_exec_r4_projection     inner cfs_rq, outer sched_entity, one dirty node
sched_exec_r4_rq_state       outer cfs_rq, one irq_work, one recovery work,
                             and one bounded dirty-list head
```

The source has no constructor, function definition, callback, scheduler
callsite, queue operation, workqueue allocation, CPUHP registration, static
key, export, trace/file/userspace surface, public header change, or behavior.
Fifty-eight object-local ELF symbols encode all relevant sizes, alignments,
and offsets.

## Source Gate

Canonical run `20260717T-p5a-r4-e2-source-gate-r1` passed direct-parent and
two-file identity, forward and reverse patch replay, strict checkpatch
`0/0/0`, 22 source anchors, exact private owner/node counts, dense-CPU-storage
absence, runtime/surface/function absence, and a unique 58-symbol manifest.
Its result SHA-256 is
`9e79d3e58151960b397a715116eb545de4c1ecc1988e619b88139022f6395a82`.

The build gate independently preserved all 51 existing expanded-probe values
on arm64 and x86_64, emitted the 58 new symbols only when R4 was enabled, and
proved:

```text
key                              <=    64 bytes
bucket plus notifier             <=   384 bytes
projection plus dirty node       <=   960 bytes
rq state plus irq/work owner     <=   576 bytes
64 projections plus rq state     <= 62016 bytes/rq
hard private-rq limit            <= 65536 bytes/rq
ordinary scheduler-object growth ==     0 bytes
```

## Dual-Architecture Result

Run `20260717T-p5a-r4-e2-dual-arch-r1` passed all four modes on both
architectures in 315 seconds. Its result SHA-256 is
`6346c3570008942fae533395ff4eb1165c3d42c6572d134c945e20fb57cbad1e`.

Both architectures measured `64/200/768/512` bytes for the key, bucket plus
notifier, projection plus dirty node, and rq state plus bridge owner. With
`B_max=64`, active private storage is `49,664 bytes/rq`, below the planned
`62,016` and hard `65,536` limits. All ordinary scheduler-object deltas are
zero, and disabled symbols, relocations, and strings are absent.

Independent closure run `20260717T-p5a-r4-e2-closure-r1` re-extracted every
stored ELF table and rechecked identity, source/config hashes, object hashes,
private offsets, disabled absence, and arithmetic. Its result SHA-256 is
`fed621ee76effc554df806f40f6289d375dafe3f127427a9be73d6ff2ddcc048`.
After checkout retirement, run
`20260717T-p5a-r4-e2-closure-post-retirement-r1` passed from retained Git
objects alone; its stable fields are identical and its result SHA-256 is
`27f5a7acc52cc3852ca049a6abc07a72bce2c4e99e7a1a2e02167548a7b3d0f6`.

## Non-Claims

The source never creates or initializes an object. It establishes no
admission, scheduling, denial, repair, hotplug, lifetime, monitor, protection,
latency, performance, cost, deployment, or datacenter claim. R4-E3 plan
drafting may start, but R4-E3 source remains blocked until that separate plan
passes.
