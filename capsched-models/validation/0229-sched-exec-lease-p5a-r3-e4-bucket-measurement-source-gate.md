# Validation 0229: SchedExecLease P5A-R3 E4 Bucket Measurement Source Gate

Date: 2026-07-16

Status: corrected run r2 passed. Attempt 1 remains the invalid harness result
recorded in validation/0230. The exact-E4-source E3 regression diagnostic in
validation/0231 is now required. E4 measurement remains blocked.

## Candidate and Prerequisites

```text
E3 parent:      be9339363a99fb31a5b7d03f3d70430d64a45593
E4 candidate:   f20c62a2ad5aec4347dc7c8c4d81e3f7fa1f3da1
E4 tree:        61541cb0c8aedef941e534c73effdea1f6b3d938
E4 diff SHA-256: ec369f6b40b427f1297b9ef5061d91bebb2e26c25d9f145a54b995b4b4a73205
plan result:    107cf025ccb3030cafe6a142a994fdf5d5e7a6d4cf8b8fc07f5b49bb8e878cab
E3 diagnostic:  3ec1cd9b54b326d889c5ef3d6398e70530f3f50e5fd7cd89e3f3aa0c2f45c756
```

The source-only smoke locks all identities, the exact direct-child two-file
boundary, 1006/10 line totals, strict checkpatch 0/0/0, Kconfig, frozen E3
20-case manifest, three E4 cases, all 42 matrix cells, fixed sample counts,
shared helpers, timed-function exclusions, and synthetic non-attachment.

## Independent Runner

```text
capsched-models/validation/
  run-sched-exec-lease-p5a-r3-e4-bucket-measurement-source-gate.sh
```

For arm64 and x86_64, the runner deletes its dedicated output and builds three
fresh `W=1` objects:

```text
exact E3 parent with E3 enabled
exact E4 candidate with E4 disabled
exact E4 candidate with E4 enabled
```

It compares all 43 private E2 layout values across the three modes, rejects
any compiler warning, proves E4 symbol/relocation/string absence while
disabled, and proves the E4 suite while enabled. Configs and objects receive
SHA-256 manifests.

Run `20260716T-p5a-r3-e4-source-gate-r2` produced status
`passed_static_source_gate_awaiting_e3_regression_diagnostic`. That result may
launch only an exact-source E3 regression diagnostic. It deliberately keeps
`e4_measurement_may_start`, E4 acceptance, and E5 authorization false.

Result SHA-256:
`8529ceac4f5018be0878507e6fce7c7d8a9dda1f9f586e551f09c64bd14b2e7c`.

## Monitoring

The completed external Apple Container job is `p5a-r3-e4-source-gate-r2`:

```text
./tools/long-job.sh watch p5a-r3-e4-source-gate-r2 30
```

Stopping the display with Ctrl-C does not stop the build.

## Non-Claims

Until both this build gate and a subsequent exact-source E3 regression
diagnostic pass, there is no accepted E4 measurement evidence. This gate makes
no live-scheduler, latency, bare-metal, performance, cost, protection,
deployment, or datacenter claim.
