# Validation 0206: SchedExecLease P5A-R2 0014 Expanded Layout Probe

Date: 2026-07-13

Status: monitored arm64 build launched; no passed-build claim is recorded until
the generated result reports `status: passed`.

## Completed Before Launch

```text
one-file Linux delta: passed
git diff --check: passed
strict checkpatch: 0 errors, 0 warnings
patch queue 0001..0014 replay: passed
local/replay tree equality: true
patch-plan validation/0205: passed
```

## Monitored Job

```text
name: p5a-r2-0014-build
refresh interval: 30 seconds
```

The job runs fresh arm64 targeted builds for normal CONFIG off, normal CONFIG
on, and explicit layout-probe on. It then requires exactly 49 probe symbols and
produces a 23-field offset/size/cacheline table.

Expected output:

```text
build/source-check/sched-exec-lease-p5a-r2-0014-expanded-layout-probe/
  20260713T-p5a-r2-0014-expanded-probe/result.json
```

Monitor from the project root:

```text
./tools/long-job.sh watch p5a-r2-0014-build 30
```

One-shot status:

```text
./tools/long-job.sh status p5a-r2-0014-build
```

## Claim Boundary

Until the result is passed, build compatibility and the 49-symbol table remain
pending. Regardless of result, 0014 makes no behavior, runtime denial,
protection, performance, cost, deployment, or datacenter claim.
