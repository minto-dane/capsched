# Implementation 0044: SchedExecLease P5A-R3 E2 Private Layout Candidate

Date: 2026-07-15

Status: exact disposable source candidate committed; dual-architecture E2
layout evidence is pending. This candidate is build-only and is not accepted
for runtime or production use.

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
The dual-architecture gate must rebuild and preserve all 51 existing expanded
probe values, prove that all new symbols and relocations disappear while the
new option is disabled, and enforce the E1 private-memory envelope.

## Non-Claims

The source does not create a bucket or projection and does not integrate with
enqueue, dequeue, migration, picking, accounting, hotplug, publication, work,
or retirement. It does not establish scheduling correctness, denial
correctness, protection, latency, performance, deployment, or datacenter
readiness. A passing E2 can authorize only a separately specified E3 synthetic
same-translation-unit prototype.
