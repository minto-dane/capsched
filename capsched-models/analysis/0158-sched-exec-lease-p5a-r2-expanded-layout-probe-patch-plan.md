# Analysis 0158: SchedExecLease P5A-R2 Expanded Layout Probe Patch Plan

Date: 2026-07-13

Status: patch-plan gate. Patch 0014 may be drafted only as a no-behavior
extension of the existing default-off build-only probe.

## Decision

Validation/0203 requires an expanded E1 probe before disposable layout fields
or rebuild code. Validation/0204 closes the arm64 baseline. Reserve:

```text
0014 = expand build-only layout evidence only
```

The only allowed Linux file is:

```text
kernel/sched/exec_lease_layout_probe.c
```

The existing Kconfig and Makefile boundary is frozen. The patch must not add
or change scheduler structures, fields, functions, call sites, configuration
semantics, or runtime objects.

## Measurements Added by 0014

The existing 24 symbols remain unchanged. Object-local symbols are added for:

```text
SMP_CACHE_BYTES

sched_entity.group_node offset/size
sched_entity.on_rq offset/size
sched_entity.sched_delayed offset/size
sched_entity.rel_deadline offset/size
sched_entity.custom_slice offset/size
sched_entity.exec_start offset/size
sched_entity.avg offset/size

rq.ttwu_pending offset/size
rq.cpu_capacity offset/size
rq.nr_switches offset/size
rq.__lock offset/size
rq.clock_task offset/size
rq.balance_callback offset/size
```

This adds 25 symbols for an expected total of 49. Validation derives start and
end cacheline indices from offsets, field sizes, and `SMP_CACHE_BYTES`; the
kernel source does not gain a cacheline-reporting runtime path.

## Candidate-Field Boundary

Candidate fields do not exist yet. Patch 0014 must not fabricate them, add
placeholder fields, or claim their layout. A later disposable E2 patch must
add both provisional CONFIG-gated fields and matching conditional probe
symbols in the same disposable delta. Absence is recorded as absence.

The reserved future symbol families are:

```text
sched_exec_lp_sched_entity_summary_min
sched_exec_lp_sched_entity_summary_valid
sched_exec_lp_rq_built_generation
sched_exec_lp_rq_summary_state
sched_exec_lp_rq_rebuild_callback
```

Their presence in 0014 rejects the patch.

## Acceptance Gate

The concrete patch is reviewable only after:

```text
exact one-file delta and no runtime functions/calls
existing Kconfig remains default n and unselected by SCHED_EXEC_LEASE
normal CONFIG off/on probe-object absence
explicit probe-on targeted build
exact 49-symbol extraction
structured field/cacheline table
architecture-local comparison against validation/0198 and validation/0204
checkpatch with only a recorded metadata exception, if any
patch queue replay to exact tree
source security and non-claim review
```

No cross-architecture byte identity is expected. Each architecture is compared
with its own baseline.

## Rejection Rules

Reject 0014 if it modifies Kconfig, Makefile, a structure definition, a runtime
translation unit, or exports a symbol; builds in a normal configuration; adds
a candidate field; changes any existing probe symbol; creates ABI; or claims
hot-field approval, behavior, runtime denial, protection, performance, cost,
deployment, or datacenter readiness.

## Next

Run the source/formal patch-plan gate. If it passes, draft 0014, replay it, and
run the targeted three-mode build and layout extraction. No behavior patch is
authorized by this plan.
