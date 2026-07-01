# Validation 0104: Linux Source-Map Refresh Target Selection

Status: safe model passed; unsafe models produced expected counterexamples;
target-selection JSON checked

Date: 2026-07-01

## Inputs

```text
analysis/0088-linux-source-map-refresh-target-selection.md
analysis/linux-source-map-refresh-target-selection-v1.json
formal/0066-linux-source-map-refresh-target-model/
validation/0103-linux-source-drift-freshness-gate.md
```

## Target Selection

Selected target:

```text
scheduler_authority_core
```

Selection type:

```text
source_map_refresh_target
```

Not selected:

```text
Linux patch target
runtime claim
protection claim
async carrier Linux name movement
```

## JSON Check

Command shape:

```sh
jq empty analysis/linux-source-map-refresh-target-selection-v1.json

jq -r '...' analysis/linux-source-map-refresh-target-selection-v1.json
```

Result:

```text
candidates=9
selected_candidates=1
selected_target=scheduler_authority_core
selected_target_linux_patch_target=false
current_upstream_anchors=20
safety_flags_false=9
safety_flags_total=9
gate_input_linux_patch_approved=false
gate_input_model_freshness=fresh
```

## TLC Run

Run directory:

```text
/media/nia/scsiusb/dev/linux-cap/build/tlc/linux-source-map-refresh-target-20260701T193010Z
```

Safe command shape:

```sh
java -cp /home/nia/tools/tla/tla2tools.jar \
  tlc2.TLC \
  -config LinuxSourceMapRefreshTargetSafe.cfg \
  LinuxSourceMapRefreshTarget.tla
```

Safe result:

```text
exit_code=0
states_generated=6
distinct_states=6
states_left_on_queue=0
search_depth=6
```

Safe path:

```text
gate read -> candidates compared -> scheduler authority selected ->
patch movement blocked -> accepted
```

## Expected Unsafe Counterexamples

All unsafe configurations exited with code `12` and violated the intended
invariant:

| Config | Violated invariant |
| --- | --- |
| `LinuxSourceMapRefreshTargetUnsafeAsyncNameMovement` | `NoAsyncNameMovement` |
| `LinuxSourceMapRefreshTargetUnsafeLinuxPatchApproval` | `NoLinuxPatchApproval` |
| `LinuxSourceMapRefreshTargetUnsafeProtectionClaim` | `NoProtectionClaim` |
| `LinuxSourceMapRefreshTargetUnsafeRuntimeClaim` | `NoRuntimeCoverageClaim` |
| `LinuxSourceMapRefreshTargetUnsafeSelectNearbyDriftOnly` | `NoNearbyDriftOnlyPrimaryTarget` |
| `LinuxSourceMapRefreshTargetUnsafeSelectStalePatchTarget` | `NoStalePatchTargetSelection` |
| `LinuxSourceMapRefreshTargetUnsafeSelectWithoutGate` | `SelectionRequiresGate` |

## Meaning

N-133 chooses the next concrete refresh target:

```text
refresh scheduler_authority_core source maps next
do it source-only
do not approve Linux code
do not chase the non-stale cpufreq_schedutil drift as the primary authority target
```

The next source-only refresh should update:

```text
analysis/0025-linux-scheduler-authority-state-machine.md
analysis/0026-scheduler-hook-proof-obligation-matrix.md
analysis/0028-tick-runtime-budget-source-map.md
formal/0012-linux-scheduler-authority-model/
```

## Limits

This validation selects a source-map refresh target. It does not perform the
full refresh and does not approve Linux implementation.

## Non-Claims

This validation does not approve Linux code, direct-call stubs, async carrier
Linux names, workqueue integration, io_uring integration, ABI, public
tracepoints, runtime coverage, monitor verification, behavior change, or
production protection.
