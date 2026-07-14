# Validation 0215: SchedExecLease P5A-R2 E4 Lock-Hold Source Gate

Date: 2026-07-14

Status: passed for launching the exact arm64 disposable measurement only.
E4 measurement, cross-architecture acceptance, full locked rebuild, latency,
performance, production, and protection claims remain unaccepted.

## Scope

Validate the committed E4 descendant against the passed E4 plan and E3
correctness evidence before any long measurement build is launched. The gate
requires exact source identity, a direct E3 parent, exactly two changed files,
frozen E2/E3/primary/patch-queue boundaries, default-off KUnit isolation, the
fixed matrix and thresholds, O(1) timed callback, exact IRQ/clock/rq-lock
ordering, no forbidden operation in the interval, strict patch style, and an
E4-enabled arm64 object build with bounded stack frames.

## Runner

```text
capsched-models/validation/
  run-sched-exec-lease-p5a-r2-e4-lock-hold-source-gate.sh
```

## Result

Run `20260714T-p5a-r2-e4-source-gate` passed:

```text
parent:                 d1d5e78da8484c91eae70f22399c6901da680ea0
source:                 dc3618e2bc56d3ede9b8d1378099c7b9ad15e08f
tree:                   b8a7023993560bcc40077a5db25288c3fdf4765a
diff SHA-256:            9d33d848b13f01e15d6ff6369c465964ca0682829eafbaa3906bbf17e3b18709
delta:                  356 additions, 0 deletions, exactly two files
strict checkpatch:       0 errors, 0 warnings, 0 checks
arm64 targeted compile: passed, 0 compiler warnings
timed helper stack:      96 bytes
cell driver stack:       384 bytes
matrix:                  35 cells, 256 warmups, 10,000 pairs/cell
```

Result:
`build/source-check/sched-exec-lease-p5a-r2-e4-lock-hold-source-gate/20260714T-p5a-r2-e4-source-gate/result.json`.

Result SHA-256:
`e0895e883f50151b4d239165ad690e3a3a6587a591a0ee81665d33777d6d2b92`.

The enabled `fair.o` SHA-256 is
`0d776e3f4c8936090d8d6972bccac6b4c295b3ee54225acd6ecfe1252b954460`;
the exact `.config` SHA-256 is
`57cf7063c1404b31aff0c3617ffbdc7f58ef7e279757872d222a377b6c162c22`.

## Authorization Boundary

Only the exact source commit above may launch the arm64 Apple Container/QEMU
measurement. The runner must preserve all 35 cells and 10,000 measured pairs,
classify a threshold breach as valid `rejected_full_locked_rebuild` evidence,
and classify missing/malformed rows, build/boot/KUnit failure, or unavailable
warning evidence as `harness_failed`.

This pass does not authorize x86_64 until the arm64 result is recorded, accept
E4, approve the full locked rebuild, modify primary Linux or patch queue 0014,
or claim production layout, live behavior, bounded latency, performance, cost,
protection, deployment, or datacenter readiness.
