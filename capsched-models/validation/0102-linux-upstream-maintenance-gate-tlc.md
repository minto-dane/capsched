# Validation 0102: Linux Upstream Maintenance Gate TLC

Status: safe model passed; unsafe models produced expected counterexamples;
maintenance JSON checked

Date: 2026-07-01

## Inputs

```text
analysis/0086-linux-upstream-drift-maintenance-review.md
analysis/linux-upstream-drift-maintenance-review-v1.json
formal/0064-linux-upstream-maintenance-gate-model/
implementation/0014-linux-async-carrier-candidate-patch-plan.md
validation/0101-linux-async-carrier-patch-scope-tlc.md
```

## Source Observation Inputs

The review used these local commands as source evidence:

```text
git -C linux fetch upstream master
git -C linux rev-list --count 4edcdefd4083ae04b1a5656f4be6cd83ae919ef4..upstream/master
git -C linux diff --name-status 4edcdefd4083ae04b1a5656f4be6cd83ae919ef4..upstream/master -- <watched paths>
git -C linux merge-tree --write-tree upstream/master capsched-linux-l0
```

Observed result:

```text
fetched_upstream_master=665159e246749
base_to_upstream_commit_count=340
watched_path_drift=kernel/sched/cpufreq_schedutil.c
merge_tree_exit_code=0
merge_tree_result_tree=cda01cf9b8c171e29869170aa160ad0724cc9ad4
```

## Run Directory

```text
/media/nia/scsiusb/dev/linux-cap/build/tlc/linux-upstream-maintenance-gate-20260701T191114Z
```

## Safe Run

Command shape:

```sh
java -cp /home/nia/tools/tla/tla2tools.jar \
  tlc2.TLC \
  -config LinuxUpstreamMaintenanceGateSafe.cfg \
  LinuxUpstreamMaintenanceGate.tla
```

Result:

```text
exit_code=0
states_generated=8
distinct_states=8
states_left_on_queue=0
search_depth=8
```

The safe model covers:

```text
patch footprint read -> upstream fetched -> watched diff reviewed ->
merge-tree checked -> value assessed -> no-behavior async carrier patch
deferred -> accepted
```

## Expected Unsafe Counterexamples

All unsafe configurations exited with code `12` and violated the intended
invariant:

| Config | Violated invariant |
| --- | --- |
| `LinuxUpstreamMaintenanceGateUnsafeAbi` | `NoAbi` |
| `LinuxUpstreamMaintenanceGateUnsafeApproveWithoutFetch` | `NoApprovalWithoutFetch` |
| `LinuxUpstreamMaintenanceGateUnsafeApproveWithoutMergeTree` | `NoApprovalWithoutMergeTree` |
| `LinuxUpstreamMaintenanceGateUnsafeApproveWithoutNeed` | `NoApprovalWithoutNeed` / `NoCurrentPatchApproval` |
| `LinuxUpstreamMaintenanceGateUnsafeApproveWithoutWatchedDiff` | `NoApprovalWithoutWatchedDiff` |
| `LinuxUpstreamMaintenanceGateUnsafeBehaviorChange` | `NoBehaviorChange` |
| `LinuxUpstreamMaintenanceGateUnsafeHook` | `NoHook` |
| `LinuxUpstreamMaintenanceGateUnsafeObjectLayout` | `NoObjectLayout` |
| `LinuxUpstreamMaintenanceGateUnsafeProtectionClaim` | `NoProtectionClaim` |
| `LinuxUpstreamMaintenanceGateUnsafeRuntimeState` | `NoRuntimeState` |

## JSON Maintenance Gate Check

Command shape:

```sh
jq empty analysis/linux-upstream-drift-maintenance-review-v1.json

jq -r '...' analysis/linux-upstream-drift-maintenance-review-v1.json
```

Result:

```text
future_no_behavior_patch_gate=12
drift_classes=5
unsafe_patterns=11
safety_flags_false=12
safety_flags_total=12
add_no_behavior_async_carrier_patch_now=false
watched_path_drift_classification=D1_nearby_non_intersecting_drift
```

## Meaning

N-131 is a negative gate:

```text
No new Linux async-carrier patch is approved now.
Even no-behavior opaque async-carrier names are deferred.
The current low-drift L0 footprint is preserved.
```

The fetched upstream state currently shows low direct conflict risk for L0, but
that is not enough to justify new Linux names without a concrete consumer.

## Limits

This validation proves only the N-131 maintenance decision model and JSON gate.
It is not Linux runtime evidence, implementation approval, ABI approval,
monitor verification, behavior change, or production protection.

## Non-Claims

This validation does not approve Linux code, async carrier implementation,
workqueue integration, io_uring integration, direct-call ABI, public
tracepoints, runtime coverage, monitor verification, behavior change, or
production protection.
