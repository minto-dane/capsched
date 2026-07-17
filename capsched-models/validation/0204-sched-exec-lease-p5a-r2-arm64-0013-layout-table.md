# Validation 0204: SchedExecLease P5A-R2 arm64 0013 Layout Table

Date: 2026-07-13

Status: passed for arm64 layout-baseline evidence only. No Linux patch, hot
field, runtime behavior, protection, performance, or cost claim is approved.

## Scope

Mechanically convert the 24 symbols from the already completed arm64 0013
probe object into a structured layout table, verify the exact Linux commit and
tree, and prove that every measured field lies within its containing
structure.

The source build is:

```text
build/DomainLeaseLinux.volume/builds/arm64-current/20260713T140445Z/result.json
```

The extraction runner is:

```text
validation/run-sched-exec-lease-p5a-r2-arm64-0013-layout-table.sh
```

## Run

```text
RUN_ID=20260713T-p5a-r2-arm64-0013-layout-table \
  validation/run-sched-exec-lease-p5a-r2-arm64-0013-layout-table.sh
```

Result:

```text
status: passed
architecture: arm64
compiler: gcc (Ubuntu 13.3.0-6ubuntu2~24.04.1) 13.3.0
kernel_release: 7.1.0-14076-g077c948be394
linux_commit: 077c948be39432971e7273b16b728172251129aa
linux_tree: 7ef04bf73d26b2813b10016b7eb342a618a66570
probe symbols: 24
layout entries: 14
struct entries: 4
field entries: 10
fields within containing structures: true
```

Output:

```text
build/source-check/sched-exec-lease-p5a-r2-arm64-0013-layout-table/
  20260713T-p5a-r2-arm64-0013-layout-table/result.json
```

Integrity:

```text
probe object sha256:
  b55ff779a6e2ac14ac6c7711678c05dc6321f6eae532cd2f70eaafe07068a4b3
layout TSV sha256:
  c40d7f04b3de8e80108a763cb726c33448fece904aecd06a792244fb9b8a4173
layout JSON sha256:
  e75126b7ad874591a8a36cf597e94e61cc886e0335f372f850cb4cf4acef878e
```

## arm64 Baseline

Offsets and sizes are decimal bytes. A structure row contains only its size.

| Item | Offset | Size |
| --- | ---: | ---: |
| `sched_entity` | - | 320 |
| `sched_entity.run_node` | 16 | 24 |
| `sched_entity.min_vruntime` | 48 | 8 |
| `sched_entity.vruntime` | 120 | 8 |
| `cfs_rq` | - | 384 |
| `cfs_rq.tasks_timeline` | 64 | 16 |
| `cfs_rq.curr` | 80 | 8 |
| `cfs_rq.next` | 88 | 8 |
| `rq` | - | 3520 |
| `rq.nr_running` | 0 | 4 |
| `rq.curr` | 24 | 8 |
| `rq.cfs` | 128 | 384 |
| `task_struct` | - | 4160 |
| `task_struct.sched_exec` | 1232 | 40 |

## Architecture Boundary

This arm64 table and validation/0198's x86_64 table are architecture-local
baselines. Their whole-structure sizes and some offsets differ; therefore no
cross-architecture byte-identity claim is made. A future candidate must be
compared with its own architecture's baseline under the envelopes fixed by
analysis/0157 and validation/0203.

## Non-Claims

This validation does not approve:

```text
Linux code changes
new scheduler hot fields
an expanded probe patch
the global-fence rebuild prototype
runtime denial correctness or coverage
monitor delivery or enforcement
production protection
latency, performance, energy, or cost efficiency
deployment or datacenter readiness
```

## Next

Define the expanded build-only probe patch plan needed to measure every future
global-fence candidate field and every protected hot offset, while preserving
the default-off, no-runtime-callsite, no-ABI boundary of 0013.
