# Validation 0195: SchedExecLease P5A-R2 Layout and Overhead Evidence Plan

Date: 2026-07-04

Status: passed. No Linux behavior patch is approved.

## Scope

This validates the P5A-R2 evidence plan before any future patch adds
picker-visible Fresh summary fields or changes hot CFS/EEVDF selection logic.

Validated artifacts:

```text
analysis/0152-sched-exec-lease-p5a-r2-layout-overhead-evidence-plan.md
analysis/sched-exec-lease-p5a-r2-layout-overhead-evidence-plan-v1.json
formal/0119-p5a-r2-layout-overhead-evidence-plan-model/
validation/run-sched-exec-lease-p5a-r2-layout-overhead-evidence-plan.sh
```

Run:

```text
RUN_ID=20260704T-p5a-r2-layout-overhead-evidence-plan
```

Result:

```text
linux_commit: bd71af5daeae808ac948cbd12af2663151936f22
linux_tree: 25dbe4e04baa112ab9a872a897f67bec094df209
source_anchor_count: 40
line_drift_count: 0
missing_anchor_count: 0
hot_structures_observed: true
eevdf_update_paths_observed: true
existing_probe_basis_observed: true
future_fields_absent: true
experimental_replacement_target_observed: true
safe TLC: 6 generated states, 5 distinct states, depth 5
unsafe counterexamples: 36 expected
```

## Interpretation

The validated contract requires future P5A-R2 candidate work to separate:

```text
CONFIG_SCHED_EXEC_LEASE=n object/layout evidence
CONFIG_SCHED_EXEC_LEASE=y selector-disabled overhead evidence
CONFIG_SCHED_EXEC_LEASE=y candidate-enabled hot-path evidence
runtime negative tests
benchmark/perf evidence for any cost claim
```

It also records that current Linux still has no future
`min_pickable_vruntime`-style P5A-R2 summary field, and that the existing
`0012` post-filter fallback is only a replacement target, not an accepted
production mechanism.

## Non-Claims

This validation does not approve:

```text
Linux code changes
new hot scheduler fields
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

The next reviewable work is either a concrete no-behavior layout probe patch or
a more detailed object/layout probe plan. A behavior patch should wait until
disabled-overhead evidence, layout probes, source-shape checks, negative stale
summary tests, QEMU/runtime coverage, security review, and upstream replay are
defined for the candidate.
