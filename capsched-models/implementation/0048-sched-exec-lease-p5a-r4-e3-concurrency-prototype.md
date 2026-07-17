# Implementation 0048: SchedExecLease P5A-R4 E3 Concurrency Prototype

Date: 2026-07-17

Status: exact disposable source candidate committed and N-134 source gate
closed. Attempt 1 remains invalid; corrected W=1 r2 plus two independent
closure runs authorize only the fixed six-boot diagnostic matrix. No R4-E3
source/correctness or runtime claim is accepted yet.

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

## Closed Source Gate

Source-gate attempt 1 `20260717T-p5a-r4-e3-source-gate-r1` completed all eight
fresh objects and emitted result SHA-256
`fb2bc59d01cda4110a2022fc5e810d0b0b445bfb80498f25558476e74667369a`.
Independent closure then found 2.1--2.8ms future mtimes and GNU make `Clock
skew detected. Your build may be incomplete.` warnings in the x86_64 layout-
off and test-on logs. Because the old runner did not scan build warnings, its
result is invalid evidence even though the object, table, and disabled-artifact
checks passed.

Corrected run `20260717T-p5a-r4-e3-source-gate-r2` adds W=1 compiler-diagnostic
rejection. A clock-skewed initial output triggers an immediate same-target
verification build; the verification must contain zero compiler diagnostics,
future-mtime notices, or clock-skew warnings. Corrected-runner preflight
`20260717T-p5a-r4-e3-source-preflight-r7` passed the full non-build boundary
and intentionally created no source-gate result. Canonical r2 passed with zero
diagnostics/retries/skew at result SHA-256
`7c24c35506345550353a3c9f9b4d986fbccdccfbdbb884a4497df6c89e55cf27`.

Validation/0246 copied and independently audited all 105 artifacts twice.
Closure r1/r2 result SHA-256 values are
`4daf672d70cdead4bdd7d00f40381d99b4b6f1e9807fced16f9d68ee9578df91`
and `4d2dae97f059ab73ad233e4232ce26fc27e5667cf99de5540719d62965c4af10`;
their normalized SHA-256 is
`4471b71c85762ce75b609f84649335f300029b223524795bab7f86bb4f51fd8d`.
N-134 is complete and only the exact six-boot matrix is authorized.

## Non-Claims

The committed source and preflight do not accept R4-E3 source correctness,
concurrency correctness, runtime behavior, denial correctness, the six-boot
diagnostic matrix, primary/patch promotion, bounded latency, performance,
monitor enforcement, production protection, deployment, multi-node,
multi-cluster, or datacenter readiness.
