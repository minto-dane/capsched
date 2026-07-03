# Validation 0162: SchedExecLease P5A-R CFS Picker Source Map

Date: 2026-07-03

Status: passed for source-map consistency. No Linux behavior change is
approved.

## Scope

This validation checks the P5A-R CFS picker source map:

```text
analysis/0135-sched-exec-lease-p5a-r-cfs-picker-eligibility-source-map.md
analysis/sched-exec-lease-p5a-r-cfs-picker-eligibility-source-map-v1.json
```

It validates that the artifact records P5A-R as blocked, with no Linux patch,
runtime denial, CFS deny-and-repick, runtime coverage, monitor, production, or
datacenter claim.

## Checks

Machine-readable checks:

```text
jq empty analysis/sched-exec-lease-p5a-r-cfs-picker-eligibility-source-map-v1.json
```

Claim checks:

```text
linux_patch_approved=false
behavior_change_approved=false
deny_one_cfs_pick_next_approved=false
non_claims.runtime_denial=false
non_claims.cfs_deny_and_repick=false
non_claims.broad_move_denial=false
non_claims.runtime_coverage=false
non_claims.monitor_verified=false
non_claims.production_protection=false
non_claims.hypervisor_grade_isolation=false
non_claims.cost_efficiency=false
non_claims.datacenter_ready=false
```

Required blocker checks:

```text
fair-picker-visible denied-candidate ineligibility
bounded retry or fail-closed/quarantine rule
group hierarchy rollback or aggregate denial semantics
core-scheduling core_pick cache and core-cookie search settlement or exclusion
DL-server nested fair-pick settlement or exclusion
proxy donor/executor authority subject rule
sched_ext exclusion or separate settlement gate
denial accounting separation from sleep, throttle, delayed dequeue, yield, and
  EEVDF lag
```

## Result

The source map is accepted as a design/input artifact for the next P5A-R gate.
It does not approve a behavior patch.

Recorded source-map counts:

```text
anchor_count=12
blocker_count=9
allowed_next_count=5
non_claim_true_count=0
```

## Next

The next P5A-R gate should model:

```text
attempt-local denied-candidate carrier
bounded retry
group hierarchy settlement
core scheduling settlement or explicit exclusion
DL-server settlement or explicit exclusion
proxy donor/executor authority subject
sched_ext exclusion or separate model
```
