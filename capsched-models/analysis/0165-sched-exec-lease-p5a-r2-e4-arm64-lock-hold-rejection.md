# Analysis 0165: SchedExecLease P5A-R2 E4 Arm64 Lock-Hold Rejection

Date: 2026-07-14

Status: complete negative evidence. The measured full O(n) rebuild under the
irq-disabled rq lock is rejected. x86_64 measurement is not authorized.

## Exact Evidence Boundary

The canonical arm64 result measures corrected direct-E3 child
`f6ad4e454778c52bcdaaecf684c148a3a8dae857`, tree
`265e6357627490e51084979382ef34b2cfcc0cb8`, with full diff SHA-256
`3f52a2b2724bd795466ab1f344bf3d02fde7ee6a39bfde0945f7f8cf6ab8e3a3`.
Validation/0217 had already passed the exact identity, unchanged interval and
matrix, strict style, and arm64 targeted-build gates. Its result SHA-256 is
`956007be42687193c9d3eeb29e5e0be80dcaeba16d22436c71e06a017a870adc`.

Canonical measurement:

```text
run:        20260714T-p5a-r2-e4-arm64-r4
result:     build/source-check/sched-exec-lease-p5a-r2-e4-arm64-lock-hold-measurement/20260714T-p5a-r2-e4-arm64-r4/result.json
result SHA: 21cad0c9d6923e3e6a42749c315aca150126424ca14dd717c868e80eeba9bccc
status:     rejected_full_locked_rebuild
```

The run emitted all 35 required rows over seven runnable counts and five
hierarchy depths, with 256 warm-up pairs and 10,000 measured control/rebuild
pairs per cell. Generation-race rate was zero. QEMU exited zero, the required
KUnit suite and case passed without a skip, all command-line parameters were
recognized, irqsoff evidence was active, and lockdep, irqsoff, RCU stall,
soft-lockup, and hard-lockup warning counts were all zero. This is therefore a
valid architecture measurement, not a build, boot, parser, or harness failure.

The Image was reused only after a host-side expected-cell fixture repair. The
source commit, configuration, Image, `fair.o`, and measurement implementation
were unchanged and hash-checked before a fresh QEMU execution. The result
records this as `same_source_image_reused_after_post_build_harness_fix`.

## Rejection Evidence

The fixed normalized base-slice basis remained 700,000ns. The two-vCPU guest
correctly reported the separately recorded runtime-scaled value as 1,400,000ns;
runtime scaling did not relax any gate.

Across 20 of 35 distinct cells, 36 rejection conditions fired:

| Condition | Breaches | Fixed limit |
| --- | ---: | ---: |
| additional p99 | 12 | 25,000ns |
| additional maximum | 20 | 50,000ns |
| additional sample reached normalized base slice | 4 | <700,000ns |

The worst cell, 4,096 runnable entities at depth 64, measured 520,992ns
additional p99 and 2,440,048ns additional maximum. The latter is 48.8 times
the maximum limit and 3.49 times the normalized base-slice basis. Four cells
reached or exceeded the base-slice rejection boundary; the worst other
examples include 4,096/depth 0 at 1,089,488ns and 256/depth 16 at 927,536ns.

## Noncanonical Attempts

Run r2 completed guest output but could not produce a result because the
host-side expected-cell generator wrote its loop output to stdout rather than
the comparison file. Run r3 reused the same exact Image but its Apple
Container worker lifetime expired after 12 of 35 rows while the Mac slept.
Neither partial attempt is combined with r4 or treated as performance
evidence. Run r4 started a fresh QEMU guest and independently completed every
cell.

## Decision

The E4 experiment has reached its planned terminal negative outcome:

- reject the full O(n) all-rq projection rebuild while holding each rq lock;
- do not spend another architecture build on x86_64, because arm64 already
  failed architecture-independent fixed rejection gates;
- do not promote the disposable E2 fields or E3/E4 source to primary Linux or
  the patch queue; and
- retain E3 only as synthetic-fixture correctness evidence, not as a viable
  production update strategy.

This rejects the full locked rebuild design, not the versioned invalidation
objective. Any successor must first provide a separately gated architecture
that bounds rq-lock work, for example through indexed targeted fanout,
incremental bounded repair, or publication/rebuild separation. No successor
source is authorized by this result.

Production layout, hot fields, live publisher/fanout/picker integration,
runtime denial, protection, bare-metal latency, performance, cost, deployment,
and datacenter claims remain false.
