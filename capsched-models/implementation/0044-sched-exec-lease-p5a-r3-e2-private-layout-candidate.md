# Implementation 0044: SchedExecLease P5A-R3 E2 Private Layout Candidate

Date: 2026-07-15

Status: exact disposable source candidate committed and dual-architecture E2
layout evidence closed. The candidate is accepted only as input to a separate
E3 plan; it remains build-only and is not accepted for runtime or production.

## Disposable Source Identity

```text
worktree: build/DomainLeaseLinux.volume/worktrees/p5a-r3-e2-layout
branch:   codex/p5a-r3-e2-layout
parent:   5e1ca3037e34823d1ba0cdd1dc04161fac170280
commit:   63313b329e1d44901acfce30698613c38615c8d5
tree:     8d51c596d3d73a6c6dc507b84fdcd4ac8aa7f8eb
diff sha: fe8b75cb31bb5612d2f32f95b9988c4e7796ae5b919ecd8f5dacc2e0c12ffe09
```

The direct child adds 209 lines in exactly two files:

```text
init/Kconfig
kernel/sched/exec_lease.c
```

Strict checkpatch reports zero errors, warnings, and checks. Primary Linux
remains at `5e1ca3037e348` and the patch queue remains at `0014`.

## Measured Candidate

`CONFIG_SCHED_EXEC_LEASE_BUCKET_LAYOUT_PROBE` is default off and is reachable
only through the existing explicit layout-probe/debug boundary with SMP and
fair-group scheduling. It has no constructor, callsite, runtime branch,
static key, export, tracepoint, ABI, or userspace interface.

The candidate measures the dominant Candidate C storage rather than a small
control surrogate:

```text
sched_exec_bucket_key             eight u64-equivalent words
sched_exec_bucket                 key, raw membership lock, ref/state,
                                  cpumask_var_t active-rq set, sparse xarray
sched_exec_bucket_rq_projection   embedded inner cfs_rq, outer sched_entity,
                                  work and generation/ref/count metadata
sched_exec_bucket_rq_state        embedded private outer cfs_rq and rq state
```

Forty-three new ELF symbol sizes encode private sizes, alignments, and offsets.

## Dual-Architecture Result

Run `20260715T-p5a-r3-e2-dual-arch` rebuilt fresh architecture-local primary,
private-off, private-on, and normal configurations for arm64 and x86_64. Its
result SHA-256 is
`48a4a0f358896f0e552173f5e308970ef14dc83a58beef62caaed03e360e7038`.

Both architectures preserved all 51 existing expanded-probe values, emitted
exactly 43 private symbols only in private-on mode, and emitted zero private
symbols, relocations, or strings in disabled modes. The ordinary structure
deltas are all zero:

```text
                 arm64  x86_64  delta
sched_entity        320     320      0
cfs_rq              384     384      0
rq                 3520    3392      0
task_struct        4160    3328      0
```

The private layout is 64-byte key, 128-byte bucket, 832-byte projection, and
448-byte rq state on both measured architectures. With `B_max=64`, measured
active private memory is `64 * 832 + 448 = 53,696` bytes per rq, below the
65,536-byte limit. Maximum measured private alignment is 64 bytes.

Independent closure run `20260715T-p5a-r3-e2-closure` re-extracted the ELF
tables and rechecked all four configs, 28 source blobs, direct-child/two-file
identity, patch-queue series identity, disabled absence, arithmetic, and result
hashes. Closure result SHA-256 is
`d9b63a3efd0fd6b60223190418b3baacc3c0ac2d275fd99aa594d1fe6c18efba`.

E2 is complete. A separate E3 evidence plan may now be drafted; E3 source may
not be created until that plan passes.

## Non-Claims

The source does not create a bucket or projection and does not integrate with
enqueue, dequeue, migration, picking, accounting, hotplug, publication, work,
or retirement. It does not establish scheduling correctness, denial
correctness, protection, latency, performance, deployment, or datacenter
readiness. A passing E2 can authorize only a separately specified E3 synthetic
same-translation-unit prototype.
