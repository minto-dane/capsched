# Validation 0217: SchedExecLease P5A-R2 E4 Corrected Source Gate

Date: 2026-07-14

Status: passed for corrected arm64 measurement relaunch only. No architecture
measurement, full rebuild, latency, performance, or production claim exists.

## Result

Run `20260714T-p5a-r2-e4-source-gate-r2` passed the exact corrected identity
and direct-E3-parent gates:

```text
parent:           d1d5e78da8484c91eae70f22399c6901da680ea0
source commit:    f6ad4e454778c52bcdaaecf684c148a3a8dae857
source tree:      265e6357627490e51084979382ef34b2cfcc0cb8
full diff SHA:    3f52a2b2724bd795466ab1f344bf3d02fde7ee6a39bfde0945f7f8cf6ab8e3a3
full delta:       362 additions, 0 deletions, exactly two files
correction SHA:   22cb55c3a8a9841122820a467712c015ba761961676898160f941157fc3414ed
correction delta: 10 additions, 4 deletions, kernel/sched/fair.c only
```

The gate also verified the preserved attempt-1 `harness_failed` result hash,
fixed 700,000ns normalized threshold basis, separate runtime-scaled metadata,
unchanged real IRQ/clock/rq-lock interval, unchanged 35 cells, 256 warm-ups,
10,000 measured pairs, 25,000ns p99 and 50,000ns maximum limits, and absence
of forbidden operations in the measured interval.

Strict checkpatch reported zero errors, warnings, and checks. The gate rebuilt
E4-enabled arm64 `kernel/sched/fair.o` with zero compiler warnings and found
all measurement symbols. Stack frames are 96 bytes for the timed helper, 384
bytes for the cell driver, and 160 bytes for the matrix case.

```text
target object SHA-256: a2362391c0125c83c9d311ad9d2fa80838409647136ed00d3aea0c8104416e3a
target config SHA-256: 57cf7063c1404b31aff0c3617ffbdc7f58ef7e279757872d222a377b6c162c22
```

Result:
`build/source-check/sched-exec-lease-p5a-r2-e4-lock-hold-source-gate-r2/20260714T-p5a-r2-e4-source-gate-r2/result.json`.

Result SHA-256:
`956007be42687193c9d3eeb29e5e0be80dcaeba16d22436c71e06a017a870adc`.

## Authorization Boundary

Only the exact corrected arm64 measurement may relaunch. x86_64 remains
blocked until arm64 produces a valid passed or threshold-rejection result.
E4 acceptance, the full locked rebuild, production fields, primary Linux or
patch-queue changes, runtime behavior, protection, bare-metal latency,
performance, cost, deployment, and datacenter readiness remain false.
