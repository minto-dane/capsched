# Validation 0222: SchedExecLease P5A-R3 E2 Dual-Architecture Layout

Date: 2026-07-15

Status: monitored build prepared; result pending.

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

The build is independently monitored as `p5a-r3-e2-dual-arch-build`; its
authoritative result will be written under
`build/source-check/sched-exec-lease-p5a-r3-e2-dual-arch-layout/`.
