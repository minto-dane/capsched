# Validation 0222: SchedExecLease P5A-R3 E2 Dual-Architecture Layout

Date: 2026-07-15

Status: monitored arm64/x86_64 build passed. Closure and authorization are
recorded separately in validation/0223.

## Matrix

The runner builds four fresh configurations for each of arm64 and x86_64:

```text
primary baseline       existing 51-symbol layout probe
candidate private-off  existing probe on, new private probe off
candidate private-on   existing probe and new private probe on
candidate normal       existing and new layout probes off
```

Each architecture is compared only with its own fresh baseline. Acceptance
requires all 51 existing values to remain byte-for-byte equal within the
architecture, exactly 43 new private values in the enabled `exec_lease.o`, no
new symbol or relocation in either disabled mode, zero ordinary
`sched_entity`/`cfs_rq`/`rq`/`task_struct` delta, and every E1 private-memory
limit to pass.

## Result

The independently monitored job `p5a-r3-e2-dual-arch-build` completed with
exit code zero. Authoritative result:

```text
build/source-check/sched-exec-lease-p5a-r3-e2-dual-arch-layout/
  20260715T-p5a-r3-e2-dual-arch/result.json
sha256: 48a4a0f358896f0e552173f5e308970ef14dc83a58beef62caaed03e360e7038
```

Per-architecture result hashes are:

```text
arm64:  61d689f23321af2542ce2a960e4de01e826129df4c4e7416a608bbaeb67aff84
x86_64: cb6e2ce1411e58be450909d2dfd6733b04765c275eebde6d278f2505bbe3087e
```

Both architectures preserved 51/51 existing values, added exactly 43 private
symbols in private-on only, and produced zero disabled private symbols and
relocations. All ordinary structure deltas are zero. Both measured the private
layout as key/bucket/projection/rq-state `64/128/832/448` bytes and the bounded
per-rq total as 53,696 bytes. Cross-architecture byte identity was not assumed;
each architecture was compared with its own fresh primary baseline.
