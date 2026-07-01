# Validation 0103: Linux Source-Drift Freshness Gate

Status: source-drift runner executed; safe model passed; unsafe models produced
expected counterexamples; JSON contracts checked

Date: 2026-07-01

## Inputs

```text
analysis/0087-linux-source-drift-automation-and-model-freshness.md
analysis/linux-source-drift-model-freshness-gate-v1.json
validation/run-linux-source-drift-gate.sh
formal/0065-linux-source-drift-freshness-gate-model/
analysis/0086-linux-upstream-drift-maintenance-review.md
validation/0102-linux-upstream-maintenance-gate-tlc.md
```

## Source-Drift Runner

Command:

```sh
CAPSCHED_RUN_ID=20260701T193000Z \
  capsched-models/validation/run-linux-source-drift-gate.sh
```

Run directory:

```text
/media/nia/scsiusb/dev/linux-cap/build/source-drift/linux-source-drift-gate/20260701T193000Z
```

Observed result:

```text
base_commit=4edcdefd4083ae04b1a5656f4be6cd83ae919ef4
upstream_commit=665159e246749578d4e4bfe106ee3b74edcdab18
work_commit=7cf0b1e415bcead8a2079c8be94a9d41aad7d462
base_to_upstream_commit_count=340
watched_changed_count=1
model_refresh_required_count=0
direct_footprint_drift=false
future_attachment_drift=false
semantic_drift_requires_refresh=false
merge_tree_exit=0
merge_tree_clean=true
model_freshness=fresh
concrete_consumer_need=0
candidate_no_behavior_patch_reviewable=false
linux_patch_approved=false
behavior_change=false
runtime_coverage=false
abi=false
public_tracepoint_abi=false
monitor_verified=false
production_protection=false
```

Changed watch group:

| Group | Count | Drift class | Model refresh required | Changed path |
| --- | ---: | --- | --- | --- |
| `scheduler_nearby_non_intersecting` | 1 | `D1_nearby_non_intersecting_drift` | false | `kernel/sched/cpufreq_schedutil.c` |

No watched group with `stale_if_changed=true` changed.

## TLC Run

Run directory:

```text
/media/nia/scsiusb/dev/linux-cap/build/tlc/linux-source-drift-freshness-gate-20260701T192135Z
```

Safe command shape:

```sh
java -cp /home/nia/tools/tla/tla2tools.jar \
  tlc2.TLC \
  -config LinuxSourceDriftFreshnessGateSafe.cfg \
  LinuxSourceDriftFreshnessGate.tla
```

Safe result:

```text
exit_code=0
states_generated=8
distinct_states=8
states_left_on_queue=0
search_depth=8
```

Safe path:

```text
watch map loaded -> source observed -> groups classified ->
merge-tree checked -> freshness computed -> patch deferred -> accepted
```

## Expected Unsafe Counterexamples

All unsafe configurations exited with code `12` and violated the intended
invariant:

| Config | Violated invariant |
| --- | --- |
| `LinuxSourceDriftFreshnessGateUnsafeAbi` | `NoAbi` |
| `LinuxSourceDriftFreshnessGateUnsafeBehaviorChange` | `NoBehaviorChange` |
| `LinuxSourceDriftFreshnessGateUnsafeCleanMergeAsFreshness` | `FreshnessRequiresGroupClassification` / `CleanMergeIsNotFreshnessProof` |
| `LinuxSourceDriftFreshnessGateUnsafeMissingNonClaims` | `FreshnessDecisionRequiresNonClaims` |
| `LinuxSourceDriftFreshnessGateUnsafeMissingWatchMap` | `GroupClassificationRequiresWatchMap` |
| `LinuxSourceDriftFreshnessGateUnsafeNewLinuxNames` | `NoNewLinuxNamesWithoutConsumer` |
| `LinuxSourceDriftFreshnessGateUnsafePatchWithStaleModel` | `NoPatchWithStaleModel` |
| `LinuxSourceDriftFreshnessGateUnsafePatchWithoutObservation` | `PatchRequiresObservation` |
| `LinuxSourceDriftFreshnessGateUnsafeProtectionClaim` | `NoProtectionClaim` |

The first run of this model exposed missing invariants: a bad path without a
watch map and a bad path without non-claims were not rejected. The model was
strengthened with:

```text
GroupClassificationRequiresWatchMap
FreshnessDecisionRequiresNonClaims
```

The final run rejects both.

## JSON Contract Checks

Checked:

```text
jq empty analysis/linux-source-drift-model-freshness-gate-v1.json
jq ... build/source-drift/linux-source-drift-gate/20260701T193000Z/result.json
```

Result:

```text
watch_groups=9
global_non_claim_false_flags=7
result_watched_changed_count=1
result_model_refresh_required_count=0
result_model_freshness=fresh
result_candidate_no_behavior_patch_reviewable=false
result_linux_patch_approved=false
result_safety_flags_false=6
```

## Meaning

N-132 adds the reusable gate needed before future upstream updates or patch
movement:

```text
fetch or use a recorded upstream ref
observe watched-path drift
classify changed groups
decide model freshness
run merge-tree
block patch movement if observation is missing, stale, or overclaimed
```

The current observation is fresh for the watched model groups, but it still does
not approve a Linux patch. In particular, it does not approve no-behavior async
carrier names because there is no concrete consumer need.

## Limits

This validation proves the runner contract and freshness-gate model for the
current observed refs. It is not Linux runtime evidence, implementation
approval, ABI approval, monitor verification, behavior change, or production
protection.

## Non-Claims

This validation does not approve Linux code, async carrier implementation,
workqueue integration, io_uring integration, direct-call ABI, public
tracepoints, runtime coverage, monitor verification, behavior change, or
production protection.
