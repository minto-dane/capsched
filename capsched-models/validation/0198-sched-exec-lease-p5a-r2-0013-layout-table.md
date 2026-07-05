# Validation 0198: SchedExecLease P5A-R2 0013 Layout Table

Date: 2026-07-05

Status: passed. No runtime behavior or protection claim is approved.

## Scope

This validation converts the build-only 0013 probe symbols into a structured
layout table.

Source validation:

```text
validation/0197-sched-exec-lease-p5a-r2-0013-layout-probe.md
```

Run:

```text
RUN_ID=20260705T-p5a-r2-0013-layout-table
```

Result:

```text
linux_commit: 0b79e307dc9536d38557141cfd650f2be9a2af57
linux_tree: 7ef04bf73d26b2813b10016b7eb342a618a66570
patch_sha256: cc1fe1754e64bfaa23e8214445b748d0287e7961500d0aa2a7d6f995a295fb38
series_sha256: 8f7c96605f816f9ec34015d7c6d8d1e1dbbe2936e60b86f8bc70dc4e1727270e
probe_object_sha256: d688b67c55e9cfb0fdd8d5c0e6978be548d69edaa7d7b6c738baba8c6ae6d4cc
layout_entry_count: 14
layout_struct_count: 4
layout_field_count: 10
fields_within_containing_structures: true
layout_tsv_sha256: 466349c5b78cf23d7cc996649372fa003fa82fbeaf89b7fd222ef244a9ae5523
layout_json_sha256: 06bf37fdb4a1ef823f21887f1b61b1df14749dfcf1c7b63a11f52fc2994b97e7
```

## Layout Snapshot

```text
sched_entity size: 320
sched_entity.run_node offset/size: 16 / 24
sched_entity.min_vruntime offset/size: 48 / 8
sched_entity.vruntime offset/size: 120 / 8

cfs_rq size: 384
cfs_rq.tasks_timeline offset/size: 64 / 16
cfs_rq.curr offset/size: 80 / 8
cfs_rq.next offset/size: 88 / 8

rq size: 3392
rq.nr_running offset/size: 0 / 4
rq.curr offset/size: 16 / 8
rq.cfs offset/size: 128 / 384

task_struct size: 3328
task_struct.sched_exec offset/size: 1424 / 40
```

## Interpretation

The 0013 probe can mechanically measure scheduler-internal structures that an
external module cannot reliably inspect, especially `struct cfs_rq` and
`struct rq`.

The table is only a baseline for future object/layout comparison. It does not
justify adding hot-path fields or changing CFS behavior by itself.

## Non-Claims

This validation does not approve:

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

## Next

The next evidence step is disabled-overhead comparison for normal CONFIG off
and CONFIG on builds, separate from the explicit probe build.
