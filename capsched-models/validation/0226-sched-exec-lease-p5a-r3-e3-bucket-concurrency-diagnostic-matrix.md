# Validation 0226: SchedExecLease P5A-R3 E3 Diagnostic Matrix

Date: 2026-07-16

Status: reproducible monitored runner prepared. The authoritative result is
generated under
`build/source-check/sched-exec-lease-p5a-r3-e3-bucket-concurrency-diagnostic-matrix/`.

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
