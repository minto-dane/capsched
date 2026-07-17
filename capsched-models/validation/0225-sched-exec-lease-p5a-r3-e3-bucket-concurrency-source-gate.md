# Validation 0225: SchedExecLease P5A-R3 E3 Bucket Concurrency Source Gate

Date: 2026-07-16

Status: passed. Authoritative result:

```text
build/source-check/sched-exec-lease-p5a-r3-e3-bucket-concurrency-source-gate/
  20260716T-p5a-r3-e3-source-gate-r2/result.json
sha256: a78e1672afc904ee40a7ec019ed94f8bea16713ab101d2518f595c9bbbe3be53
```

The gate freezes the exact E2 parent, E3 direct-child commit/tree/diff, primary
Linux, and patch-queue series. It rejects any source outside the two allowed
files, any deletion, any E2 private layout/probe drift, an implicit KUnit
enable path, a changed 20-case or six-fault set, oracle representation sharing,
blocking work/allocation/XArray mutation under a test lock, or retirement
ordering drift.

It then performs fresh architecture-local builds for arm64 and x86_64 in four
modes: exact E2 baseline, E3 all-off, E3 layout-on/test-off, and E3 test-on.
Disabled objects must contain zero E3 symbols, relocations, and identifying
strings; test-on objects must contain the exact suite. The gate records configs,
logs, object hashes, strict checkpatch output, and a machine-readable result.

Both architecture-local four-mode builds passed. The exact E2 43-value table
was preserved, all-off omitted the translation unit, layout-on/test-off had
zero E3 symbols, relocations, and strings, and test-on contained the exact
suite. Strict checkpatch was 0/0/0 and every static source/ordering gate passed.

This corrected run supersedes the pre-runtime source-gate result for commit
`60e148fa0476c742b13a743345d1383db04fc843`. That earlier result remains
preserved, but diagnostic attempt 1 invalidated the candidate and required the
correction recorded in validation/0227. The corrected direct-E2-child identity
is `be9339363a99fb31a5b7d03f3d70430d64a45593`.

This pass authorizes only the four-boot diagnostic matrix. Runtime correctness
and production readiness remain false until separately evidenced and reviewed.
