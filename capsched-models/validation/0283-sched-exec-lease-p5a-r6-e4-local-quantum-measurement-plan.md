# P5A-R6-E4 local-quantum measurement-plan validation

Status: passed twice; exact disposable source draft authorized

Date: 2026-07-27

## Outcome

The source-free R6-E4 gate passed twice against immutable prerequisite,
threat-model, source, formal-model, and upstream identities. The two results
differ only in `run_id`; their normalized SHA-256 is:

```text
4490f9cc3898bb1a662c537cd99706675cbcb07b2fc2a52cb95898cdc0784f3d
```

This accepts the exact 855-cell local-quantum measurement plan and authorizes
only an exact disposable default-off R6-E4 source draft after a separate source
gate. It does not accept any R6-E4 source or measurement result.

## Canonical runs

| Run | Result SHA-256 |
| --- | --- |
| `20260727T-p5a-r6-e4-measurement-plan-r2` | `b2a689abc6e936b06c65958c775e7d1b3bcfee8fb0768d7d5b03abcb6de0d1e6` |
| `20260727T-p5a-r6-e4-measurement-plan-r3` | `58984d7f4c9c58ee6dbde90abdd5c4de35b4422f0f36c9fafe7c7677646e092a` |

Runner SHA-256:

```text
f2d59ee2d59182b96a401ea2c49b157cdfc40f401e7165202175e75a5f179820
```

Plan SHA-256:

```text
e4c10f61e97a98ca76567ba0df23ca3542462187070384d8ce27cd578e3be2f7
```

Contract SHA-256:

```text
8c3838e38568c780fb1e02c6ffc839de66b121af564bea47d45c289858667dc3
```

Threat-model SHA-256:

```text
262f609a04b1da7b87562b48e42e9674e91151ed8ccdaaef3bc88596795e997d
```

Formal source manifest SHA-256:

```text
f9e65914e00df5886fed41f70b058cc475588564482fdb22b361cdb158c01e0d
```

## Exact measurement boundary

Each run independently verified nine measurement families totaling 855 cells
and 8,550,000 paired observations:

| Family | Cells |
| --- | ---: |
| descriptor publication | 135 |
| leaf plus six ancestors | 80 |
| aggregate | 45 |
| candidate | 180 |
| complete selection | 45 |
| reconciliation | 120 |
| selected-slot handoff and final task check | 96 |
| current request and observation | 54 |
| offline | 100 |

Every cell has 256 warm-up pairs and 10,000 recorded treatment/control pairs.
Raw treatment, control, and additional-time rows are retained exactly and may
be losslessly compressed only after hashing and closure. Row discard,
rounding, aggregation in place of raw evidence, and reuse after rejection are
forbidden.

The ordinary additional-time gates are p99 <= 5 us, p999 <= 25 us, max <= 50
us, and every pair < 700 us. Offline locked-path gates are p99 <= 25 us, p999
<= 40 us, max <= 50 us, and every pair < 700 us. Current observation and drain
calibrations use separate p99 <= 10 ms and max <= 100 ms diagnostic bounds and
are not runtime SLOs.

Ordinary Linux `pick_eevdf()` remains an unchanged baseline outside the R6
additional interval. Only the selected-slot handoff and final authorization
check are included. The plan therefore makes no `pick_eevdf()` latency or
improvement claim.

Arm64 must run first. Any rejection stops R6 and prevents x86_64 execution; a
passed arm64 closure permits only a same-source x86_64 run. Two independent
complete evidence closures remain mandatory.

## Formal and negative validation

The safe finite-trace TLA+ model generated 14 states, found 14 distinct states
at depth 14, and satisfied both temporal properties. All 82 unsafe safety
configurations and both unsafe liveness configurations produced the expected
counterexamples.

The regression harness accepted the exact contract and rejected:

1. post-E3 authorization hash tampering;
2. threat-model hash tampering;
3. broadened source scope;
4. a reduced matrix;
5. a reduced pair count;
6. a relaxed threshold;
7. an EEVDF improvement overclaim;
8. reversed architecture ordering;
9. raw-evidence discard;
10. a monitor-verification overclaim; and
11. a symlinked contract.

The first canonical attempt also exposed a runner-only TLC policy mismatch:
the intentional terminal `Authorized` state was checked as a deadlock. The
runner now invokes the safe finite-trace check with deadlock checking disabled,
matching the already validated model semantics. Shell syntax, ShellCheck, all
negative fixtures, and both fresh canonical runs passed after that correction.

## Upstream drift

Both online runs independently observed Torvalds upstream
`f5098b6bae761e346ebcd9da7f95622c04733cff`, 108 commits after the post-E3
observation. No candidate path changed in those 108 commits.

Relative to the candidate merge base, only `init/Kconfig` changed within the
candidate path set. The candidate and clean-merge private `SCHED_EXEC_LEASE`
Kconfig blocks remain byte-identical, and private
`kernel/sched/exec_lease.c` remains absent upstream. This is exact scoped drift
classification, not a global upstream-freshness claim.

## Remaining false claims

Both canonical results keep false every R6 behavior-source, measurement,
runtime scheduler, runtime denial, runtime coverage, runtime budget,
async/service, MemoryView/TLB, device/DMA/IOMMU, monitor, cluster, bare-metal,
latency, performance, cost, production, deployment, multi-node,
multi-cluster, and datacenter claim. Primary Linux and the patch queue remain
immutable.

The next permitted activity is the exact disposable default-off R6-E4 source
draft followed by its separate source gate. Measurement may not begin before
that gate passes.
