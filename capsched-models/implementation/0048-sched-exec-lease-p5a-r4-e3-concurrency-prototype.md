# Implementation 0048: SchedExecLease P5A-R4 E3 Concurrency Prototype

Date: 2026-07-17

Status: exact disposable source candidate committed and preflight source checks
passed. The independent dual-architecture source gate is prepared but has not
yet produced a result. No R4-E3 correctness or runtime claim is accepted.

## Disposable Source Identity

```text
worktree: build/DomainLeaseLinux.volume/worktrees/p5a-r4-e3-concurrency-prototype
branch:   codex/p5a-r4-e3-concurrency-prototype
parent:   a429fc30252ac6af94c51d96cd4ac24e72d9f83b
commit:   f9c737c93ecff48c6f512048b05b1b49f4a54ca5
tree:     274f7b5d6969dc68e158819191fe598f9587e0ad
diff sha: c35299bead06a874a21f116b15f4aabfd27c9ca945e9541dfb6dc8c31fa5b781
```

After the clean candidate, local branch, fork branch, commit, tree, and diff
were independently fixed, the 1.7 GiB disposable checkout may be retired to
reclaim space. The canonical Git objects remain in the primary repository and
on the fork; the gate recreates isolated E2/E3 checkouts from those objects.

The candidate is one direct child of the closed R4-E2 layout commit. It adds
2,758 lines and deletes none in exactly:

```text
init/Kconfig
kernel/sched/exec_lease.c
```

Primary Linux remains `5e1ca3037e34823d1ba0cdd1dc04161fac170280`,
and the patch queue remains `16bb080da472ffabbbafd2698073eca633fb0602`.

## Synthetic Boundary

`CONFIG_SCHED_EXEC_LEASE_R4_KUNIT_TEST` defaults to off, depends on the R4
layout probe and built-in KUnit, and registers only suite
`sched_exec_lease_r4_concurrency` in the existing translation unit. The suite
instantiates the private E2 layouts using hard IRQ work, one unbound high-
priority reclaim-capable workqueue, raw locks, refcounts, XArray/cpumask state,
and RCU. All rq/current/contribution inputs are synthetic; there is no live
scheduler hook, exported ABI, CPUHP registration, userspace surface, or
production object creation.

The hard IRQ callback is dispatch-only and takes no rq or membership lock. A
plain-record oracle independent from the private layout checks the protocol,
and each case emits a machine-readable `R4_RECEIPT`.

## Fixed Diagnostic Contract

The source implements the exact plan order of 36 deterministic cases, all six
pre-runnable allocation fault sites with clean retry, a 15-second hard wait,
and 2,048 stress iterations. It includes notifier generation/membership
restart and late admission, one-projection recovery, queue false-return paths,
publication races, current observation, migration, hotplug drain, saturation,
and RCU retirement/reference cleanup.

Strict source and commit checkpatch both report `0 errors, 0 warnings, 0
checks`. Preflight run `20260717T-p5a-r4-e3-source-preflight-r6` independently
verified the N-133 r13/r14 seals, direct-child and exact two-file identity,
additive diff and byte-preserved E2 private block, exact cases/faults/config,
dispatch/publisher/offline protocol, forbidden-surface absence, and source
object identity. Inputs were verified read-only snapshots and the source came
from isolated Git-object E2/E3 worktrees. Preflight intentionally produced no
build result and removed its temporary worktrees and scratch.

## Pending Gate

Canonical source-gate run `20260717T-p5a-r4-e3-source-gate-r1` must freshly
build four modes on both arm64 and x86_64: exact E2 parent, all R4 options off,
R4 layout on with E3 off, and E3 on. It must preserve the 58 E2 private and 51
expanded values, prove zero disabled E3 symbols/relocations/strings/initcalls,
and verify all enabled suite/bridge objects before any diagnostic boot.

## Non-Claims

The committed source and preflight do not accept R4-E3 source correctness,
concurrency correctness, runtime behavior, denial correctness, the six-boot
diagnostic matrix, primary/patch promotion, bounded latency, performance,
monitor enforcement, production protection, deployment, multi-node,
multi-cluster, or datacenter readiness.
