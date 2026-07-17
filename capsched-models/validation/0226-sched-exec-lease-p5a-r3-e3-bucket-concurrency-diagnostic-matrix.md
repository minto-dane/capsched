# Validation 0226: SchedExecLease P5A-R3 E3 Diagnostic Matrix

Date: 2026-07-16

Status: passed for the corrected disposable synthetic protocol only. Attempt 1
failed and remains immutable negative evidence in validation/0227. Corrected
run `20260716T-p5a-r3-e3-diagnostic-matrix-r2`, exposed as long-job
`p5a-r3-e3-diagnostic-matrix-r2`, passed the complete four-boot matrix.

The runner consumes the exact source-gate result from validation/0225 and
creates four independent full-kernel outputs:

```text
arm64   KUnit + PROVE_LOCKING + DEBUG_OBJECTS_WORK + PROVE_RCU
x86_64  KUnit + PROVE_LOCKING + DEBUG_OBJECTS_WORK + PROVE_RCU
arm64   the same diagnostic base plus generic KASAN
x86_64  the same diagnostic base plus KCSAN
```

Each image boots with two virtual CPUs, no network, an exact
`sched_exec_lease_bucket` filter, and KUnit poweroff. Acceptance requires all
20 cases to pass with zero failure, skip, timeout, KASAN/KCSAN report, lockdep
cycle, refcount underflow, work-object warning, RCU stall, WARNING, BUG, or
lockup. The runner records compiler and QEMU versions, configs, build logs,
object/image hashes, QEMU commands, complete consoles, normalized KTAP, and a
machine-readable aggregate result.

A pass is evidence only for the synthetic same-TU protocol under this matrix.
It does not attach buckets to the real scheduler or authorize primary Linux,
the patch queue, production behavior, deployment, latency, or performance
claims.

## Result

The authoritative result is:

```text
build/source-check/
  sched-exec-lease-p5a-r3-e3-bucket-concurrency-diagnostic-matrix/
    20260716T-p5a-r3-e3-diagnostic-matrix-r2/result.json
```

Its SHA-256 is
`3ec1cd9b54b326d889c5ef3d6398e70530f3f50e5fd7cd89e3f3aa0c2f45c756`.
It binds candidate commit
`be9339363a99fb31a5b7d03f3d70430d64a45593`, tree
`a92d096ef4779f20c5e652de3c21b8f85b2476c7`, parent
`63313b329e1d44901acfce30698613c38615c8d5`, and source-gate result
SHA-256 `a78e1672afc904ee40a7ec019ed94f8bea16713ab101d2518f595c9bbbe3be53`.

All four independent boots passed exactly 20/20 required cases:

```text
arm64 standard debug:   20 pass, 0 fail, 0 skip, 0 timeout
x86_64 standard debug:  20 pass, 0 fail, 0 skip, 0 timeout
arm64 generic KASAN:    20 pass, 0 fail, 0 skip, 0 timeout
x86_64 KCSAN:           20 pass, 0 fail, 0 skip, 0 timeout
aggregate diagnostics:  0 warning reports
```

Fresh build outputs were used for every boot, and compiler, config, object,
image, QEMU command, complete console, and normalized KTAP evidence were
recorded. The result sets
`synthetic_protocol_diagnostic_matrix_passed=true`, while preserving
`real_scheduler_attachment=false` and `production_ready=false`.

## Authorization Boundary

This pass closes R3-E3 synthetic concurrency evidence and permits drafting a
separate R3-E4 measurement plan only. It does not authorize E4 source before
that plan passes, real scheduler attachment, a behavior candidate, primary or
patch-queue changes, runtime denial, monitor enforcement, cross-class
coverage, protection, bounded latency, performance, cost, deployment, or
datacenter readiness.
