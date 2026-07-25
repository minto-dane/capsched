# Implementation 0050: SchedExecLease P5A-R6 E2 Domain-Forest Layout Candidate

Date: 2026-07-25

Status: exact disposable source candidate passes the independent
dual-architecture layout gate and evidence closure. It is accepted only for
source-free R6-E3 planning. No runtime behavior is accepted.

## Disposable Source Identity

```text
worktree: build/DomainLeaseLinux.volume/worktrees/p5a-r6-e2-layout
branch:   codex/p5a-r6-e2-layout
parent:   5e1ca3037e34823d1ba0cdd1dc04161fac170280
commit:   66e2fd20fc85012d7dc03649fcf4c7af583cbb94
tree:     603762b7a36d7b57e2456b90538c3ba77a1aba16
diff sha: 1ae8a83fd083c9c96412da2db98298cc708b743fc8b6266a49e16e29c16058ed
```

The signed-off commit is a direct child of the clean primary and is pushed to
`fork/codex/p5a-r6-e2-layout`. It adds 208 lines in exactly `init/Kconfig` and
`kernel/sched/exec_lease.c`. Primary Linux and the patch queue are unchanged.

## Build-Only Boundary

`CONFIG_SCHED_EXEC_LEASE_R6_LAYOUT_PROBE` defaults to off and directly depends
on the existing lease and layout probe, debug kernel, SMP, cgroup scheduling,
fair-group scheduling, and disabled scheduler autogroup.

The private translation-unit-only types are:

```text
sched_exec_r6_slot_state   inner cfs_rq, top entity, explicit statistics,
                           sealed-domain bookkeeping
sched_exec_r6_top_node     exact 64-byte masked reduction node
sched_exec_r6_rq_control   observed non-authoritative receipt cache/control
sched_exec_r6_rq_state     fixed 64 slots, 127 nodes, and one control block
```

Forty-nine ELF array symbols encode sizes, alignments, offsets, exact counts,
the conservative 74,688-byte computation, and the 98,304-byte hard limit.
There is no function, constructor, callsite, callback, hook, allocation,
CPUHP registration, static key, export, tracepoint, file, ABI, or monitor or
policy call.

## Arm64 Preflight

A fresh arm64 object preflight resolved the exact config with
`SCHED_AUTOGROUP` disabled and compiled `exec_lease.o` plus the existing
expanded layout-probe object with six jobs:

```text
slot state                 768 bytes <= 1,024
top node                    64 bytes <=    64
rq control                  48 bytes <= 1,024
rq state                57,344 bytes <= 74,688
conservative formula    74,688 bytes <= 98,304
maximum alignment           64 bytes
```

This is preflight only. It does not replace the required fresh
primary/candidate off/on/normal arm64 and x86_64 matrix.

## Closed Layout Evidence

Validation/0278 records complete arm64 and x86_64 four-mode matrices at result
SHA-256
`6164a7a9913e9cf6da96a7f09944c3a18225ddddb8d1ccc690350d339b2890a4`
and an independent read-only closure at
`e937c252819d0e79b8815b540641002f9f9bb22b6f432f3ab1e18992d6b0c7b8`.

All 51 existing layout values are unchanged on each architecture. Exactly 49
private R6 symbols exist only when enabled; symbols, relocations, and strings
are absent when disabled. Ordinary scheduler object growth is zero.

```text
                         arm64    x86_64
slot state                  768      1,024
top node                     64         64
rq control                   48         48
concrete rq state        57,344     73,728
conservative total       74,688     74,688
hard limit               98,304     98,304
```

The x86_64 slot consumes the exact inclusive 1,024-byte ceiling and therefore
has no measured headroom. The immutable candidate JSON remains the frozen
pre-matrix input contract; its historical status field is not rewritten after
hash binding.

## Next Evidence

Only a separate source-free R6-E3 correctness and concurrency plan may start.
It must bind the exact E2 result and closure before defining selector,
reconcile, hierarchy, fairness, lifetime, fault, and architecture-profile
evidence. R6-E3 source remains forbidden until that plan passes.

No E3 source, real selector, scheduler/cgroup attachment, task binding,
runtime denial, monitor verification, protection, performance, cost,
deployment, or datacenter claim is accepted.
