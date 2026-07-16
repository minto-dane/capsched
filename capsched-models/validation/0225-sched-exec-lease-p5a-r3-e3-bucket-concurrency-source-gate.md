# Validation 0225: SchedExecLease P5A-R3 E3 Bucket Concurrency Source Gate

Date: 2026-07-16

Status: passed. Authoritative result:

```text
build/source-check/sched-exec-lease-p5a-r3-e3-bucket-concurrency-source-gate/
  20260716T-p5a-r3-e3-source-gate/result.json
sha256: a1dc71e32dbacfad8479a167417c8a2e425b1b0ef169cc9f6cf05d95762272a1
```

The gate freezes the exact E2 parent, E3 direct-child commit/tree/diff, primary
Linux, and patch-queue series. It rejects any source outside the two allowed
files, any deletion, any E2 private layout/probe drift, an implicit KUnit
enable path, a changed 20-case or six-fault set, oracle representation sharing,
blocking work/allocation under a test lock, or retirement ordering drift.

It then performs fresh architecture-local builds for arm64 and x86_64 in four
modes: exact E2 baseline, E3 all-off, E3 layout-on/test-off, and E3 test-on.
Disabled objects must contain zero E3 symbols, relocations, and identifying
strings; test-on objects must contain the exact suite. The gate records configs,
logs, object hashes, strict checkpatch output, and a machine-readable result.

Both architecture-local four-mode builds passed. The exact E2 43-value table
was preserved, all-off omitted the translation unit, layout-on/test-off had
zero E3 symbols, relocations, and strings, and test-on contained the exact
suite. Strict checkpatch was 0/0/0 and every static source/ordering gate passed.

This pass authorizes only the four-boot diagnostic matrix. Runtime correctness
and production readiness remain false until separately evidenced and reviewed.
