# Analysis 0153: SchedExecLease P5A-R2 Layout Probe Patch Plan

Date: 2026-07-05

Status: patch-plan gate. No Linux patch is created or approved.

## Purpose

Validation/0195 closed the evidence-plan gate for P5A-R2 hot layout and
overhead. The next step is to define the only acceptable shape for a future
no-behavior layout probe patch before any P5A-R2 selector behavior patch.

This plan reserves the next reviewable Linux patch slot for a probe-only
candidate:

```text
0013 = no-behavior layout probe infrastructure only
```

It does not create `0013` and does not approve behavior.

## Why an Internal Probe Is Needed

The existing task layout probe can be an external build-only module because it
only needs `include/linux/sched.h` and `struct task_struct`.

P5A-R2 also needs exact layout evidence for:

```text
struct sched_entity
struct cfs_rq
struct rq
```

`struct sched_entity` is visible from `include/linux/sched.h`, but `struct
cfs_rq` and `struct rq` are scheduler-internal definitions in
`kernel/sched/sched.h`. A production-quality layout probe therefore should not
pretend that a public external module can measure all required fields. It
should be a scheduler-internal build-only object or an equivalent in-tree build
probe.

## Required Patch Shape

A future `0013` candidate may be drafted only if it remains no-behavior:

```text
allowed Linux files:
  init/Kconfig
  kernel/sched/Makefile
  kernel/sched/exec_lease_layout_probe.c

normal CONFIG_SCHED_EXEC_LEASE=n:
  probe object absent
  no new runtime fields
  no new scheduler branches

normal CONFIG_SCHED_EXEC_LEASE=y:
  probe object absent unless explicit probe config is enabled
  no new runtime fields
  no new scheduler branches

probe build:
  internal probe object may compile and emit measurement symbols
  object is used only for build evidence
```

The main `CONFIG_SCHED_EXEC_LEASE` option must not select or imply the probe.
The probe config must default to `n`.

## Probe Measurements

The future probe must expose stable, non-exported object symbols sufficient to
derive:

```text
sizeof(struct sched_entity)
offset/size sched_entity.run_node
offset/size sched_entity.min_vruntime
offset/size sched_entity.vruntime
sizeof(struct cfs_rq)
offset/size cfs_rq.tasks_timeline
offset/size cfs_rq.curr
offset/size cfs_rq.next
sizeof(struct rq)
offset/size rq.nr_running
offset/size rq.curr or rq.donor/curr union
offset/size rq.cfs
sizeof(struct task_struct)
offset/size task_struct.sched_exec when CONFIG_SCHED_EXEC_LEASE=y
```

The symbols must not be exported and must not define a userspace ABI, trace ABI,
sysfs/proc/debugfs ABI, or monitor ABI.

## Required Validation After Patch

The future `0013` patch cannot be accepted until validation records:

```text
patch queue replay to exact Linux tree
CONFIG=n normal build with probe object absent
CONFIG=y normal build with probe object absent
probe-on build with probe object present
symbol table extracted from probe object
object/function absence checks for normal builds
source-shape check proving no runtime callsite change
strict checkpatch or explicit style exception
security review
upstream replay/freshness check
```

## Explicit Rejections

The future patch must be rejected if it:

```text
adds runtime call sites
adds picker branches
adds monitor calls
does policy lookup
exports symbols
adds public ABI or trace ABI
selects the probe from CONFIG_SCHED_EXEC_LEASE
builds the probe object in normal CONFIG=y builds
accepts 0009-0012 production behavior
claims runtime denial correctness
claims production protection
claims cost efficiency without benchmarks
claims datacenter readiness
```

## Non-Claims

This plan does not approve:

```text
Linux code changes
new hot scheduler fields
future min-pickable summary fields
runtime denial correctness
complete CFS deny-and-repick correctness
runtime coverage
monitor enforcement
production protection
cost efficiency
deployment readiness
datacenter readiness
```

## Next

If this gate validates, the next reviewable work is a concrete `0013`
no-behavior layout probe patch draft. Long build validation should run under
systemd and be recorded separately.
