# Validation 0231: SchedExecLease P5A-R3 E4 Source Gate and E3 Regression Launch

Date: 2026-07-16

Status: corrected static/build source gate passed. Exact-E4-source E3 four-boot
regression diagnostic is launch-ready. E4 measurement remains blocked until
that diagnostic passes.

## Passed Source Gate

Corrected run `20260716T-p5a-r3-e4-source-gate-r2` passed with result:

```text
build/source-check/
  sched-exec-lease-p5a-r3-e4-bucket-measurement-source-gate/
    20260716T-p5a-r3-e4-source-gate-r2/result.json
```

Result SHA-256:
`8529ceac4f5018be0878507e6fce7c7d8a9dda1f9f586e551f09c64bd14b2e7c`.

The independently audited result binds candidate
`f20c62a2ad5aec4347dc7c8c4d81e3f7fa1f3da1`, tree
`61541cb0c8aedef941e534c73effdea1f6b3d938`, and direct E3 parent
`be9339363a99fb31a5b7d03f3d70430d64a45593`. It reports:

```text
architectures:                         arm64, x86_64
fresh modes per architecture:          E3 parent, E4 disabled, E4 enabled
strict checkpatch:                     0 errors / 0 warnings / 0 checks
W=1 compiler warnings:                 0
final clock-skew warnings:             0
shared-filesystem skew verifications:  3
E2 private probes:                     43, zero changed
disabled E4 symbols/relocations/text:  0
```

## Required Regression Diagnostic

The E4 source extracted the one-projection and settle transitions into shared
helpers used by the unchanged E3 suite. Therefore the predecessor's four-boot
result cannot alone approve the exact E4 source. The new runner is:

```text
capsched-models/validation/
  run-sched-exec-lease-p5a-r3-e4-e3-regression-diagnostic.sh
```

It builds four fresh images from the exact E4 commit while explicitly disabling
`CONFIG_SCHED_EXEC_LEASE_BUCKET_MEASURE_KUNIT_TEST` and filtering only suite
`sched_exec_lease_bucket`:

```text
arm64   standard debug + lockdep + DEBUG_OBJECTS_WORK + PROVE_RCU
x86_64  standard debug + lockdep + DEBUG_OBJECTS_WORK + PROVE_RCU
arm64   the same diagnostic base plus generic KASAN
x86_64  the same diagnostic base plus KCSAN strict
```

Every boot must pass the same 20 named E3 cases with no failure, skip, timeout,
KASAN/KCSAN, lockdep, workqueue, RCU, warning, bug, or lockup report. Config,
compiler, image, object, QEMU command/version, complete serial, normalized KTAP,
and SHA-256 manifests are retained per boot. Shared-filesystem clock skew uses
the strict corrected verification rule from validation/0230.

Only the complete four-boot result may set `e4_measurement_may_start` true. It
does not accept E4, E5, live scheduler behavior, latency, performance,
protection, deployment, or datacenter claims.

## Monitoring

The detached job is `p5a-r3-e4-e3-regression`. Monitor it every 30 seconds:

```text
./tools/long-job.sh watch p5a-r3-e4-e3-regression 30
```

Ctrl-C stops only the display.
