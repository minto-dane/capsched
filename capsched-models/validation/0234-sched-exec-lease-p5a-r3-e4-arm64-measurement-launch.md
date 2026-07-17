# Validation 0234: SchedExecLease P5A-R3 E4 Arm64 Measurement Launch

Date: 2026-07-16

Status: historical launch contract, now completed. Validation/0235 records the
terminal arm64 rejection; this record remains the immutable launch boundary.

## Runner

```text
capsched-models/validation/
  run-sched-exec-lease-p5a-r3-e4-arm64-bucket-measurement.sh
```

The runner refuses any source, tree, parent, source-gate, regression-result,
matrix, sample-count, threshold, or claim-boundary drift. It builds a fresh
arm64 Image on the Apple Container machine's internal ext4-compatible storage,
with E3 and E4 KUnit enabled, exact suite filter
`sched_exec_lease_bucket_measure`, lockdep, `DEBUG_OBJECTS_WORK`, `PROVE_RCU`,
and IRQ-off tracing.

The guest has 64 virtual CPUs because the fixed targeted-fanout matrix reaches
64 active-rq projections. QEMU uses the arm64 virt machine, cortex-a57 TCG,
4GiB memory, no network, KUnit poweroff, and a 7,200-second outer timeout.
The environment record includes the outer host, Apple Container machine,
compiler, QEMU, configuration, clocksource, frequency/governor availability,
mitigations, full console, normalized KTAP, and all measurement rows.

## Evidence classification

The runner requires all 42 unique cells, 10,000 samples per cell, monotonic
statistics, three zero-harness-error summaries, three passing KUnit cases, and
a source-independent recomputation of every `gate=pass|reject` field.

```text
passed_r3_e4_architecture_measurement
rejected_r3_bucket_measurement
harness failure: no valid result JSON
```

A fixed-threshold breach or a complete gated diagnostic report is valid arm64
rejection evidence. Missing rows, duplicated cells, malformed statistics,
source-reported gate disagreement, incomplete warning evidence, build/boot/
KUnit failure, or identity drift is a harness failure and cannot be credited as
an E4 result.

Before QEMU, the exact Image and `exec_lease.o` are compressed with zstd level
9, archive-tested, and restored-hash verified. The internal build tree is
pruned after QEMU whether the boot succeeds or fails, preventing another large
scratch accumulation while retaining the exact binaries.

## Preflight

Config-smoke run
`20260716T-p5a-r3-e4-arm64-measurement-config-smoke` passed with
`CONFIG_NR_CPUS=64`, the exact E4 filter and option, KUnit timeout 7,200,
lockdep, work-object diagnostics, PROVE_RCU, and IRQ-off tracing. It launched no
kernel build and removed its internal scratch tree.

## Monitoring

Detached job name: `p5a-r3-e4-arm64-measurement-r1`.

```text
./tools/long-job.sh watch p5a-r3-e4-arm64-measurement-r1 30
```

Ctrl-C stops only the display. A passing arm64 architecture may authorize an
exact-source x86_64 measurement. A valid arm64 rejection stops E5 and does not
need an x86_64 latency claim.

## Outcome

The arm64 run completed build and QEMU, then exposed a host parser defect after
all raw evidence was durable. The runner now uses explicit numeric coercion,
preserves the first parser error, and supports fully verified postprocess-only
recovery. Validation/0235 records deterministic result SHA-256
`edba124b804beeaa7a2d723027fa3a6345f2d546fb0ab861428c6a4727b5cb7b`,
19 rejected cells, and 26 fixed-gate breaches. x86_64 and E5 are stopped.

## Non-claims

Launch does not accept E4 or E5, attach the source to the live scheduler,
change primary Linux or the patch queue, or establish runtime denial,
monitor/cross-path coverage, production protection, bare-metal latency,
performance, cost, deployment, or datacenter readiness.
