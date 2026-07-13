# Validation 0206: SchedExecLease P5A-R2 0014 Expanded Layout Probe

Date: 2026-07-13

Status: passed. The corrected arm64 validation result reports `status: passed`.

## Completed Before Launch

```text
one-file Linux delta: passed
git diff --check: passed
strict checkpatch: 0 errors, 0 warnings
patch queue 0001..0014 replay: passed
local/replay tree equality: true
patch-plan validation/0205: passed
```

## Monitored Job Result

```text
name: p5a-r2-0014-build
refresh interval: 30 seconds
```

The job ran fresh arm64 targeted builds for normal CONFIG off, normal CONFIG
on, and explicit layout-probe on. It required exactly 51 probe symbols and
produced a 23-field offset/size/cacheline table.

Result:

```text
build/source-check/sched-exec-lease-p5a-r2-0014-expanded-layout-probe/
  20260713T-p5a-r2-0014-expanded-probe/result.json
```

```text
status: passed
architecture: arm64
normal CONFIG off build: passed; probe object absent
normal CONFIG on build: passed; probe object absent
explicit probe build: passed
existing probe symbols: 24
added probe symbols: 27
missing existing probe symbols: 0
total probe symbols: 51
cacheline table fields: 23
strict checkpatch: 0 errors, 0 warnings
```

The first execution completed the builds and extracted the correct 51 symbols,
but then failed an erroneous `24 + 25 = 49` ledger gate. The actual extension
contains one cache-width symbol plus 13 field offset/size pairs, so it adds 27
symbols. Validation/0205 and this runner were corrected to require
`24 + 27 = 51`; the corrected run passed without changing the Linux tree.

Monitor from the project root:

```text
./tools/long-job.sh watch p5a-r2-0014-build 30
```

One-shot status:

```text
./tools/long-job.sh status p5a-r2-0014-build
```

## Claim Boundary

This passes the arm64 targeted build and expanded E1 layout-evidence gate for
0014. It does not approve an E2 candidate layout. Patch 0014 makes no behavior,
runtime denial, protection, performance, cost, deployment, or datacenter
claim.
