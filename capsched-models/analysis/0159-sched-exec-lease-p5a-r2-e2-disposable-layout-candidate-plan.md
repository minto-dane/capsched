# Analysis 0159: SchedExecLease P5A-R2 E2 Disposable Layout Candidate Plan

Date: 2026-07-13

Status: pre-implementation gate for arm64 E2 layout evidence only. No primary
Linux branch, patch-queue, behavior, ABI, or production field is approved.

## Decision

Validation/0206 completes E1 at Linux commit
`5e1ca3037e34823d1ba0cdd1dc04161fac170280`. E2 may now create one
disposable Git worktree from that exact commit and measure a CONFIG-gated
layout candidate. The primary `capsched-linux-l0` branch and patch queue must
remain at 0014.

Allowed candidate paths are exactly:

```text
init/Kconfig
include/linux/sched.h
kernel/sched/sched.h
kernel/sched/exec_lease_layout_probe.c
```

`kernel/sched/Makefile`, runtime translation units, scheduler functions, and
callsites are frozen.

## Candidate Configuration

Add `CONFIG_SCHED_EXEC_LEASE_LAYOUT_CANDIDATE` as a default-off, test-only
option depending on `SCHED_EXEC_LEASE_LAYOUT_PROBE`. Ordinary
`CONFIG_SCHED_EXEC_LEASE=y` must not select it. Candidate fields therefore do
not exist in normal off/on builds and cannot be compiled without the explicit
build-only probe configuration.

## Provisional Fields

The disposable candidate contains exactly four fields:

```text
struct sched_entity:
  unsigned char sched_exec_summary_valid
    consumes one byte of the existing explicit flag-area hole
  u64 sched_exec_min_fresh_vruntime
    placed in the existing alignment gap immediately before sched_avg

struct rq, at the structure tail after nr_iowait:
  unsigned char sched_exec_summary_state
  u64 sched_exec_built_generation
    state-first ordering consumes the existing tail alignment gap
```

No existing field offset is changed. No field is added to `cfs_rq` or
`task_struct`. The conservative global fanout does not need a per-rq
callback/list carrier, so E2 must not add one.

These names and placements are measurement material, not an accepted Linux
interface or implementation design.

## Conditional Probe Contract

Under `CONFIG_SCHED_EXEC_LEASE_LAYOUT_CANDIDATE`, the existing build-only probe
adds offset and size symbols for the four fields:

```text
sched_exec_lp_sched_entity_summary_valid
sched_exec_lp_sched_entity_summary_min
sched_exec_lp_rq_built_generation
sched_exec_lp_rq_summary_state
```

This adds eight object-local symbols to the E1 total of 51, for exactly 59.
The cacheline table grows from 23 to 27 fields. No symbol is exported and no
runtime reporting path is added.

## Arm64 Layout Gate

Compare only against validation/0206's arm64 E1 baseline:

```text
sched_entity: 320 bytes
cfs_rq:        384 bytes
rq:           3520 bytes
task_struct:   4160 bytes
```

The candidate passes arm64 E2 layout evidence only if:

```text
sched_entity delta: 0..8 bytes
cfs_rq delta:       exactly 0
rq delta:           0..32 bytes
task_struct delta:  exactly 0

unchanged offsets:
  sched_entity.run_node
  sched_entity.min_vruntime
  rq.nr_running
  rq.curr
  rq.cfs
  rq.clock_task
  task_struct.sched_exec
```

The candidate fields must fit their containing structures. Their cacheline
locations are recorded, not justified after the fact. x86_64 requires its own
later E2 build and is not inferred from arm64.

## Build Matrix

The disposable source must pass fresh arm64 targeted builds for:

```text
CONFIG_SCHED_EXEC_LEASE=n
CONFIG_SCHED_EXEC_LEASE=y, layout candidate disabled
CONFIG_SCHED_EXEC_LEASE=y, layout probe and candidate enabled
```

Normal builds must omit the probe object and all candidate symbols. The
explicit candidate probe must preserve all 51 E1 symbols, add exactly eight,
and emit the 27-field comparison table.

## Rejection and Claim Boundary

Reject E2 if it touches the primary branch or patch queue, escapes the four
paths, modifies the Makefile, enables the candidate normally, adds callback,
`cfs_rq`, or `task_struct` fields, changes runtime code, exports an ABI, misses
an E1 symbol, exceeds any size envelope, shifts a protected offset, or claims
cross-architecture identity, behavior, denial correctness, protection,
performance, cost, deployment, or datacenter readiness.

Passing arm64 E2 permits only an architecture-local layout result. E3 rebuild
work remains separately gated.

## Next

Run validation/0207. If it passes, create the disposable worktree, apply the
four-field candidate and conditional probes, then launch validation/0208 with
the generic 30-second monitor.
