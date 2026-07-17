# Validation 0240: SchedExecLease P5A-R4 E2 Evidence Closure

Date: 2026-07-17

Status: passed for R4-E3 planning only. R4-E3 source remains unauthorized
until a separate pre-source evidence plan passes.

## Immutable Identity

```text
primary:        5e1ca3037e34823d1ba0cdd1dc04161fac170280
candidate:      a429fc30252ac6af94c51d96cd4ac24e72d9f83b
candidate tree: fffd419bbc05bab87ad304c1e4a3213439d62bab
candidate diff: 94dedc73b731c451d52b90885cd63a350a1cd562a3b1b40f856c5984b4f6cd15
patch queue:    16bb080da472ffabbbafd2698073eca633fb0602
series blob:    298567f8e0bd18168222da4e64da32750b9ea818
```

The candidate is a direct primary child and changes exactly `init/Kconfig`
and `kernel/sched/exec_lease.c`. Closure re-hashed all 34 build-relevant
primary/candidate files against their recorded and frozen commit blobs. The
closure runner resolves the candidate through retained ref
`codex/p5a-r4-e2-layout`, so the disposable checkout is not required.

## Monitored Build Result

Detached job `p5a-r4-e2-dual-arch-build` completed in 315 seconds with exit
code zero. It rebuilt architecture-local primary, R4-off, R4-on, and normal
configurations for arm64 and x86_64.

```text
existing expanded symbols/architecture   51
existing value changes                    0
R4-on private symbols                     58
baseline/R4-off/normal private symbols     0
R4-off/normal private relocations          0
R4-off/normal private strings              0
ordinary scheduler structure deltas        0/0/0/0
```

The ordinary architecture-local sizes remained arm64 `320/384/3520/4160`
and x86_64 `320/384/3392/3328` for
`sched_entity/cfs_rq/rq/task_struct`.

## Independent ELF Closure

Closure run `20260717T-p5a-r4-e2-closure-r1` did not trust the build result
booleans. It re-extracted the stored object symbol tables, relocations, and
strings; compared all existing and private tables; checked every object and
result hash; revalidated all eight configs; and recomputed key offsets,
dominant private offsets, and storage arithmetic.

Both architectures independently measured:

```text
key                                  64 bytes
bucket including notifier           200 bytes
projection including dirty node     768 bytes
rq state including irq/work owner   512 bytes
B_max                                64
worst active private bytes/rq      49664 bytes
planned maximum/rq                 62016 bytes
hard limit/rq                      65536 bytes
maximum alignment                     64 bytes
```

The notifier, projection dirty node, irq-work, recovery-work, and rq dirty
head offsets were `120/704/384/416/448` on both architectures.

## Authoritative Hashes

```text
dual-architecture result:
  6346c3570008942fae533395ff4eb1165c3d42c6572d134c945e20fb57cbad1e
arm64 result:
  6c2fe1c5b3ac50db4076661f62d571422b3409c661779bb0b7125f6a8cf211a9
x86_64 result:
  738a871991397f39c42cd31e705c1a99dd01431696e7d63d376f3a33e45ace46
independent closure result:
  fed621ee76effc554df806f40f6289d375dafe3f127427a9be73d6ff2ddcc048
post-retirement reproduction result:
  27f5a7acc52cc3852ca049a6abc07a72bce2c4e99e7a1a2e02167548a7b3d0f6
architecture summary:
  97c6b9e7f153e9ced3d16c46256ad1130a2a911de5f55731953f090a38c62697
source manifest:
  23798f462a289d8a53bac6f1d26de0c78fc05d59a5ee1b1f18518494aeb77fba
```

## Quality-Preserving Storage Reclaim

After closure, the clean 1.7 GiB disposable checkout was removed only after
its local branch, fork tracking branch, draft PR head, and exact commit were
verified. The 68 MiB canonical architecture objects and all result/table/hash
evidence remain. APFS verification passed before and after detaching and
compacting the sparsebundle; compaction reclaimed 1,803,584 KiB. The volume
was remounted, primary/candidate Git identities reverified, and the idle Apple
Container machine left stopped.

Closure was then rerun without recreating the checkout. Run
`20260717T-p5a-r4-e2-closure-post-retirement-r1` resolved the retained
candidate ref and revalidated the same Git objects and build evidence. After
removing only run/output-path fields, its result is byte-identical to the
original closure result.

## Authorization

N-132 and R4-E2 are complete. The exact candidate is accepted only as input
to an R4-E3 pre-source evidence plan. That plan must bind the irq-work to
ordinary-work bridge, one-projection recovery, notifier cursor/restart and
late admission, current-stop observation, migration, hotplug, lifetime,
allocation-fault, KUnit, KASAN, KCSAN, lockdep, IRQ-work, work-debug, and RCU
requirements already fixed by R4-E1.

R4-E3 implementation, runtime scheduling or denial, production layout,
primary Linux or patch-queue promotion, monitor protection, bounded latency,
performance/cost, deployment, and datacenter claims remain unapproved.
