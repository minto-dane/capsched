# Validation 0228: SchedExecLease P5A-R3 E4 Bucket Measurement Plan

Date: 2026-07-16

Status: passed for creating the exact disposable E4 two-file measurement
source draft only. E4 measurement, E5, and every runtime, production, latency,
or performance claim remain unaccepted.

## Scope

Validation binds analysis/0169 and formal/0134 to the authoritative corrected
E3 four-boot result, exact primary/E2/E3/patch-queue identities, current Linux
rq-lock/clock/hotplug/E3 source anchors, immutable 32-cell one-projection,
5-cell hotplug, and 5-cell fanout matrices, fixed rejection limits, negative
evidence classification, architecture split, and explicit non-claims.

## Runner

```text
capsched-models/validation/
  run-sched-exec-lease-p5a-r3-e4-bucket-measurement-plan.sh
```

## Result

Run `20260716T-p5a-r3-e4-bucket-measurement-plan` passed:

```text
E3 diagnostic result SHA-256:    3ec1cd9b54b326d889c5ef3d6398e70530f3f50e5fd7cd89e3f3aa0c2f45c756
source anchors:                  30, failures 0
future/source absence checks:    6, failures 0
frozen E3 case count:            20
safe TLC:                        8 generated, 7 distinct, depth 7
unsafe expected counterexamples: 40/40
one-projection matrix:           32 cells
hotplug matrix:                   5 cells
fanout matrix:                    5 cells
measured pairs per cell:         10,000
```

Result:
`build/source-check/sched-exec-lease-p5a-r3-e4-bucket-measurement-plan/20260716T-p5a-r3-e4-bucket-measurement-plan/result.json`.

Result SHA-256:
`107cf025ccb3030cafe6a142a994fdf5d5e7a6d4cf8b8fc07f5b49bb8e878cab`.

The fixed gates are:

```text
one projection: p99 5,000; p99.9 25,000; max 50,000 ns
hotplug drain:  p99 25,000; max 50,000 ns
targeted fanout: p99 10,000,000; max 100,000,000 ns
normalized base slice: 700,000 ns
```

The runner executed in the Apple Container machine because the host has no
Java runtime. OpenJDK checked the safe model and all forty generated unsafe
configurations. This changes no source or evidence contract.

## Authorization Boundary

The exact branch `codex/p5a-r3-e4-bucket-measurement` may now be created as a
direct child of E3 commit `be9339363a99fb31a5b7d03f3d70430d64a45593`,
changing only `init/Kconfig` and `kernel/sched/exec_lease.c` under default-off
`CONFIG_SCHED_EXEC_LEASE_BUCKET_MEASURE_KUNIT_TEST`.

This pass does not authorize launching measurement before a separate source
gate, accepting E4, starting E5 planning/source, attaching to a live scheduler,
changing primary Linux or patch queue, or claiming runtime denial, monitor or
cross-path coverage, production protection, bare-metal bounded latency,
performance, cost, deployment, or datacenter readiness.
