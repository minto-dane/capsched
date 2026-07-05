# Implementation 0039: SchedExecLease P5A-R2 0013 Layout Probe

Date: 2026-07-05

Status: drafted. No runtime behavior or protection claim is approved.

## Linux Patch

Local Linux commit:

```text
0b79e307dc9536d38557141cfd650f2be9a2af57
sched/exec_lease: Add build-only layout probe
```

Patch queue replay commit:

```text
077c948be39432971e7273b16b728172251129aa
```

Both trees match:

```text
7ef04bf73d26b2813b10016b7eb342a618a66570
```

Patch queue file:

```text
linux-patches/patches/capsched-linux-l0/0013-sched-exec_lease-Add-build-only-layout-probe.patch
```

## Scope

The patch changes only:

```text
init/Kconfig
kernel/sched/Makefile
kernel/sched/exec_lease_layout_probe.c
```

It adds a default-off `CONFIG_SCHED_EXEC_LEASE_LAYOUT_PROBE` option and a
scheduler-internal build-only object. Normal CONFIG off/on builds do not build
`exec_lease_layout_probe.o`.

## Probe Symbols

The probe object emits object-local symbols for:

```text
struct sched_entity size
sched_entity.run_node offset/size
sched_entity.min_vruntime offset/size
sched_entity.vruntime offset/size
struct cfs_rq size
cfs_rq.tasks_timeline offset/size
cfs_rq.curr offset/size
cfs_rq.next offset/size
struct rq size
rq.nr_running offset/size
rq.curr offset/size
rq.cfs offset/size
struct task_struct size
task_struct.sched_exec offset/size
```

## Initial Build Evidence

Manual targeted checks before recording validation:

```text
normal CONFIG off: exec_lease_layout_probe.o absent
normal CONFIG on: exec_lease_layout_probe.o absent
probe CONFIG on: exec_lease_layout_probe.o present
probe object size: 2464
probe object sha256: d688b67c55e9cfb0fdd8d5c0e6978be548d69edaa7d7b6c738baba8c6ae6d4cc
probe symbols: 24
```

Patch queue replay passed after updating `linux-patches/upstream/base.txt`.

Checkpatch currently reports:

```text
0 errors
1 warning: new file, MAINTAINERS review
```

The warning is recorded as an explicit style/metadata exception for this
private patch queue. Before RFC or upstream-style publication, MAINTAINERS
ownership should be revisited.

## Non-Claims

This implementation does not approve:

```text
runtime behavior changes
new hot scheduler runtime fields
future min-pickable summary fields
accepting 0009-0012
runtime denial correctness
complete CFS deny-and-repick correctness
runtime coverage
monitor enforcement
production protection
cost efficiency
deployment readiness
datacenter readiness
```
