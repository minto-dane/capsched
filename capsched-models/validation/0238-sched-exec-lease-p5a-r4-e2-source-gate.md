# Validation 0238: SchedExecLease P5A-R4 E2 Source Gate

Date: 2026-07-17

Status: passed for the exact dual-architecture build only. No R4 behavior or
E3 source is approved.

## Canonical Run

```bash
RUN_ID=20260717T-p5a-r4-e2-source-gate-r1 \
  ./capsched/capsched-models/validation/\
run-sched-exec-lease-p5a-r4-e2-source-gate.sh
```

Result:

```text
build/source-check/sched-exec-lease-p5a-r4-e2-source-gate/
  20260717T-p5a-r4-e2-source-gate-r1/result.json
SHA-256 9e79d3e58151960b397a715116eb545de4c1ecc1988e619b88139022f6395a82
```

The macOS host does not provide GNU `sha256sum`, so the unchanged runner and
workspace executed in the existing Apple Container Linux machine.

## Result

The gate bound the exact R4-E1 result SHA-256
`2710cea3ed5a8b2838b80b734a94878ed978c40e3e20daa0529ad359c6aa7bca`
and rechecked its 42 source anchors, eight absences, TLC 21/20/depth-20 safe
run, three liveness properties, and 60 expected fault counterexamples.

The candidate is direct child `a429fc30252a` of frozen primary
`5e1ca3037e348`; rejected R3 is not its parent. Its tree is
`fffd419bbc05`, and its 254-line diff SHA-256 is
`94dedc73b731c451d52b90885cd63a350a1cd562a3b1b40f856c5984b4f6cd15`.
Exactly `init/Kconfig` and `kernel/sched/exec_lease.c` changed. Forward apply
against primary and reverse apply against the candidate both passed. Strict
checkpatch reported zero errors, warnings, and checks.

All 22 layout anchors passed. Source cardinality checks found exactly one
bucket notifier work, one projection dirty node, one rq dirty head, one rq
irq-work bridge, and one rq recovery work. The source contains no dense CPU
array, runtime call, function definition, export, static key, tracepoint,
syscall, or file/userspace surface. The declared symbol set exactly matches the
58-entry unique manifest.

## Decision

Fresh arm64 and x86_64 architecture-local baseline/R4-off/R4-on/normal builds
may start. They must preserve 51 existing values, prove disabled symbol,
relocation, and string absence, keep all ordinary scheduler structure deltas
at zero, and pass the `64/384/960/576/62016/65536` private envelope.

R4-E3 source, primary Linux or patch-queue changes, runtime behavior,
protection, bounded latency, performance/cost, deployment, and datacenter
claims remain blocked.
