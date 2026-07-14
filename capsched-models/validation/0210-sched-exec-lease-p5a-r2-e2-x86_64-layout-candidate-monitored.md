# Validation 0210: SchedExecLease P5A-R2 E2 x86_64 Layout Candidate

Date: 2026-07-14

Status: detached cross-build prepared; no x86_64 result is claimed until the
generated result reports `status: passed`.

## Contract

Validation/0209 passed the build-launch plan. This validation installs only
the x86_64 GNU cross compiler in the existing Apple Container Linux machine,
then performs fresh same-toolchain builds of:

```text
primary E1 expanded probe
candidate normal CONFIG off scheduler objects
candidate normal CONFIG on, layout candidate disabled scheduler objects
candidate explicit layout-probe plus candidate object
```

The result must reproduce the x86_64 320/384/3392/3328 E1 size baseline,
preserve all 51 E1 symbol values, add exactly eight symbols for 59 total, emit
27 table fields, satisfy the architecture-local growth envelope, and keep all
candidate fields within their structures.

## Monitored Job

```text
name: p5a-r2-e2-x86_64-build
refresh interval: 30 seconds
result: build/source-check/sched-exec-lease-p5a-r2-e2-x86_64-layout-candidate/
        20260714T-p5a-r2-e2-x86_64-layout/result.json
```

Monitor from the project root:

```text
./tools/long-job.sh watch p5a-r2-e2-x86_64-build 30
```

## Claim Boundary

A pass is compiler/object layout evidence only. Cross-compilation is not
x86_64 boot, runtime, bare-metal, latency, protection, performance, or cost
evidence. The layout remains disposable and unaccepted; E3 remains blocked
until this result passes and a separate acceptance gate is completed.

## Attempt History

The first attempt installed the cross compiler successfully and stopped at
12%, before compiling any target object. x86_64 `defconfig` leaves `EXPERT`
disabled; because `SCHED_EXEC_LEASE` depends on `EXPERT`, `olddefconfig`
correctly removed the requested E1 probe. The common configuration procedure
now enables `EXPERT` before applying each mode. This is a harness prerequisite
correction, not a Linux or candidate source change.
