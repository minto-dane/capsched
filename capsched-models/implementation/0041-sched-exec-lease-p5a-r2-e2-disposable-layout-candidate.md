# Implementation 0041: SchedExecLease P5A-R2 E2 Disposable Layout Candidate

Date: 2026-07-13

Status: disposable source candidate committed; monitored arm64 comparison is
the remaining evidence. This is not a primary Linux or patch-queue change.

## Disposable Source Identity

```text
worktree: build/DomainLeaseLinux.volume/worktrees/p5a-r2-e2-layout
branch:   codex/p5a-r2-e2-layout
parent:   5e1ca3037e34823d1ba0cdd1dc04161fac170280
commit:   162d16640634637a6f7604b90bf2275bea47ec63
tree:     a435a65f1b1ae5e4c10d09e5753fc0871f1381d1
diff sha: 645ef21d82ff3abbe64177a624846e730c30400897cd011190e9abb579aa56ee
```

The candidate contains 42 additions in exactly four files:

```text
init/Kconfig
include/linux/sched.h
kernel/sched/sched.h
kernel/sched/exec_lease_layout_probe.c
```

Strict checkpatch on the source delta reports 0 errors and 0 warnings. The
primary `capsched-linux-l0` branch remains at E1 commit `5e1ca3037e348` and the
primary patch queue remains at 0014.

## Layout Candidate

`CONFIG_SCHED_EXEC_LEASE_LAYOUT_CANDIDATE` is default off and depends on the
explicit build-only probe. It is not selected by ordinary
`CONFIG_SCHED_EXEC_LEASE`.

The four provisional fields are:

```text
sched_entity.sched_exec_summary_valid       unsigned char
sched_entity.sched_exec_min_fresh_vruntime  u64
rq.sched_exec_summary_state                 unsigned char
rq.sched_exec_built_generation              u64
```

The validity byte consumes the existing flag-area hole. The minimum occupies
the existing alignment gap before `sched_avg`. The rq state and generation use
the tail alignment gap after `nr_iowait`, state first. No existing field is
reordered. No field is added to `cfs_rq` or `task_struct`, and no callback/list
carrier is added.

## Conditional Probe

The candidate adds offset/size probes for the four fields only while the
candidate config is enabled. The expected object-local symbol count is
`51 + 8 = 59`; the expected cacheline table has 27 fields.

## Monitored Validation

Validation/0208 performs fresh arm64 normal-off, normal-on, and explicit
candidate-probe targeted builds. It compares all E1 symbol names and values,
checks the exact eight-symbol addition, verifies the structure-growth and
protected-offset envelope, and records the 27-field table.

## Non-Claims

The disposable candidate contains no picker, update, publication, fanout,
rebuild, monitor, policy, or runtime callsite. It defines no ABI. It does not
approve a production hot field, E3 rebuild, scheduling behavior, denial
correctness, protection, performance, cost, deployment, or datacenter
readiness. x86_64 E2 evidence remains separate.
