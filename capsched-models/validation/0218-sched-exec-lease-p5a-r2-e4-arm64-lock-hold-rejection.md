# Validation 0218: SchedExecLease P5A-R2 E4 Arm64 Lock-Hold Rejection

Date: 2026-07-14

Status: complete valid negative evidence. The full locked rebuild is rejected;
x86_64 launch and all production or performance claims remain false.

## Result

Run `20260714T-p5a-r2-e4-arm64-r4` completed the exact corrected arm64
experiment and returned `rejected_full_locked_rebuild` with exit code zero.

```text
source commit:          f6ad4e454778c52bcdaaecf684c148a3a8dae857
source tree:            265e6357627490e51084979382ef34b2cfcc0cb8
source diff SHA-256:     3f52a2b2724bd795466ab1f344bf3d02fde7ee6a39bfde0945f7f8cf6ab8e3a3
source-gate SHA-256:     956007be42687193c9d3eeb29e5e0be80dcaeba16d22436c71e06a017a870adc
measurement rows:       35/35
warm-up pairs per cell: 256
measured pairs per cell:10,000
generation race ppm:    0
QEMU exit code:         0
KUnit required case:    passed
warning count:          0
```

Result:
`build/source-check/sched-exec-lease-p5a-r2-e4-arm64-lock-hold-measurement/20260714T-p5a-r2-e4-arm64-r4/result.json`.

Result SHA-256:
`21cad0c9d6923e3e6a42749c315aca150126424ca14dd717c868e80eeba9bccc`.

Important artifact hashes:

```text
Image:             a6bb581d86a36f870ac0d855f981cd1116b8907287f2767043eda12a25f8780c
fair.o:            b742e3dead46d3f25101bd12f51795b1ae7d6c41bcf7471d2eee9f5d7a576ee9
serial:            3dbd7b4fa6a46f9da653a87f58ce249b838bafce002d3ee8f60ddeb90830531e
normalized KTAP:   188e5987c2c8cb610ac1db742c55b69eb1bcfb742a950ee522042a2073ec38a3
measurement table: d01c902780b706defcdee443a0d7c649385b0259eb506f5470d94e4bd39d6a20
```

The run used Apple Container 1.1.0 and a named-volume Linux worker, then QEMU
8.2.2 TCG with two virtual cortex-a57 CPUs. It is virtualized architecture
evidence and makes no bare-metal claim. Reusing the exact Image after a
post-build host harness repair was allowed only after configuration, Image,
object, source, and source-gate identity checks; r4 ran a fresh QEMU guest.

## Gate Outcome

The fixed normalized basis was 700,000ns. The separately recorded two-CPU
runtime value was 1,400,000ns and did not change the limits.

```text
distinct cells with a breach: 20/35
total breaches:               36
additional p99 >25,000ns:     12
additional max >50,000ns:     20
sample >=700,000ns:            4
worst cell:                   q=4096, depth=64
worst additional p99:         520,992ns
worst additional maximum:     2,440,048ns
```

All rows, metadata, KTAP, warning evidence, and process status were complete.
Consequently these breaches are the planned terminal negative classification,
not a harness error.

## Attempt Separation

The r2 host comparison-fixture failure and r3 worker-lifetime interruption are
noncanonical and contribute no rows to this result. Validation does not merge
partial runs. r4 independently completed all 35 rows.

## Decision Boundary

Arm64 has already falsified the full O(n) rq-locked rebuild against fixed
architecture-independent gates, so x86_64 is not launched. The disposable
E2/E3/E4 line is not promoted. Any bounded-work successor requires a new plan
and source gate.

Production layout, hot fields, real publisher/fanout/picker integration,
primary Linux and patch-queue changes, runtime behavior or denial correctness,
protection, latency, performance, cost, deployment, and datacenter readiness
remain unapproved.
