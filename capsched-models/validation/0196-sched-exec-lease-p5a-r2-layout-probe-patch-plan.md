# Validation 0196: SchedExecLease P5A-R2 Layout Probe Patch Plan

Date: 2026-07-05

Status: passed. No Linux patch is created or approved.

## Scope

This validates the patch-plan gate for a future P5A-R2 no-behavior layout
probe patch. It does not create `0013`.

Validated artifacts:

```text
analysis/0153-sched-exec-lease-p5a-r2-layout-probe-patch-plan.md
analysis/sched-exec-lease-p5a-r2-layout-probe-patch-plan-v1.json
formal/0120-p5a-r2-layout-probe-patch-plan-model/
validation/run-sched-exec-lease-p5a-r2-layout-probe-patch-plan.sh
```

Run:

```text
RUN_ID=20260705T-p5a-r2-layout-probe-patch-plan
```

Result:

```text
linux_commit: bd71af5daeae808ac948cbd12af2663151936f22
linux_tree: 25dbe4e04baa112ab9a872a897f67bec094df209
source_anchor_count: 32
line_drift_count: 0
missing_anchor_count: 0
absence_failure_count: 0
patch_slot_free: true
kconfig_boundary_observed: true
internal_probe_need_observed: true
hot_layout_basis_observed: true
task_probe_basis_observed: true
safe TLC: 6 generated states, 5 distinct states, depth 5
unsafe counterexamples: 31 expected
```

## Interpretation

The future `0013` patch slot is reviewable only as a no-behavior layout probe
candidate.

The source check confirms:

```text
0013 does not exist yet
no SCHED_EXEC_LEASE_LAYOUT_PROBE config exists yet
no exec_lease_layout_probe object exists yet
no P5A-R2 min-pickable summary fields exist yet
```

The plan also records that `struct cfs_rq` and `struct rq` require a
scheduler-internal build-only probe or equivalent in-tree build mechanism,
rather than pretending the existing external task-layout probe can measure all
hot scheduler internals.

## Allowed Next Patch Scope

The next Linux patch may be drafted only within this scope:

```text
0013:
  no-behavior build-only layout probe infrastructure
  default-off probe config
  no normal CONFIG off/on probe object
  no runtime call sites
  no public ABI
  no exported symbols
```

## Non-Claims

This validation does not approve:

```text
runtime behavior changes
new hot scheduler fields
future min-pickable summary fields
accepting 0009-0012
runtime denial correctness
complete CFS deny-and-repick correctness
runtime coverage
monitor enforcement
production protection
cost efficiency
deployment readiness
datacenter readiness
```

## Next

Draft `0013` as a no-behavior layout probe patch, then run patch queue replay,
CONFIG off/on normal build absence checks, probe-on build, symbol extraction,
source-shape checks, security review, and upstream replay.
