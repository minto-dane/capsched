# SchedExecLease P4 Pre-Implementation Critical Audit Validation

Date: 2026-07-02

Status: executed; P4 remains paused.

This validation records the mechanical checks and read-only multi-axis review
that followed N-166. It does not apply P4 code.

## Commands

JSON syntax:

```sh
jq empty \
  capsched/capsched-models/analysis/linux-source-drift-model-freshness-gate-v1.json
```

Runner syntax:

```sh
bash -n capsched/capsched-models/validation/run-linux-source-drift-gate.sh
```

Remote observation before fetch:

```text
remote master:          87320be9f0d24fce67631b7eef919f0b79c3e45c
local upstream/master:  4a50a141f05a8d1737661b19ee22ff8455b94409
work branch:            d5f77adb5a64f3b2545db6ab1dcdc4aa4442bab3
```

Fresh drift run:

```sh
DOMAINLEASE_DRIFT_FETCH=1 \
DOMAINLEASE_CONCRETE_CONSUMER_NEED=1 \
DOMAINLEASE_RUN_ID=20260702T203130Z-n167-p4-pre-audit \
  capsched/capsched-models/validation/run-linux-source-drift-gate.sh
```

Formal liveness/progress probe:

```sh
grep -RIlE '\bPROPERTY\b|\bWF_|\bSF_' capsched/capsched-models/formal | wc -l
grep -RIl 'CHECK_DEADLOCK FALSE' capsched/capsched-models/formal | wc -l
```

## Results

Syntax:

```text
jq empty: pass
bash -n: pass
```

Fresh drift result:

```text
run_dir=/media/nia/scsiusb/dev/linux-cap/build/source-drift/linux-source-drift-gate/20260702T203130Z-n167-p4-pre-audit
base_commit=4edcdefd4083ae04b1a5656f4be6cd83ae919ef4
upstream_commit=87320be9f0d24fce67631b7eef919f0b79c3e45c
work_commit=d5f77adb5a64f3b2545db6ab1dcdc4aa4442bab3
base_to_upstream_commit_count=422
watched_changed_count=62
model_refresh_required_count=1
direct_footprint_drift=false
future_attachment_drift=false
semantic_drift_requires_refresh=true
merge_tree_exit=0
merge_tree_clean=true
missing_watched_path_count=0
patch_footprint_config_matches_actual=true
model_freshness=stale
candidate_no_behavior_patch_reviewable=false
linux_patch_approved=false
behavior_change=false
runtime_coverage=false
abi=false
public_tracepoint_abi=false
monitor_verified=false
production_protection=false
```

Changed groups:

```text
device_queue_iommu:
  changed_count=61
  stale_if_changed=true
  model_refresh_required=true
  drift_class=D4_semantic_drift

scheduler_nearby_non_intersecting:
  changed_count=1
  stale_if_changed=false
  model_refresh_required=false
  drift_class=D1_nearby_non_intersecting_drift
```

Fresh groups:

```text
l0_footprint
scheduler_authority_core
task_lifecycle_identity
async_workqueue
async_io_uring
policy_frontend_security
memory_and_mm_state
```

Actual Linux patch footprint recorded by the hardened runner:

```text
fs/exec.c
include/linux/sched.h
include/linux/sched_exec_lease.h
init/Kconfig
kernel/exit.c
kernel/fork.c
kernel/sched/Makefile
kernel/sched/core.c
kernel/sched/exec_lease.c
kernel/sched/sched.h
```

Formal liveness/progress probe:

```text
files containing PROPERTY, WF_, or SF_: 0
files containing CHECK_DEADLOCK FALSE: 255
```

## Multi-Axis Read-Only Review Summary

Six read-only reviews were integrated:

```text
security:
  no hypervisor-grade/security-boundary claim is defensible.

scheduler integration:
  P4 allow-all placement is plausible; P5 denial at the same point is unsafe
  without pre-settle insertion or rollback proof.

performance:
  P3 marker overhead is compatibility-only; P2 adds per-task footprint; P4 and
  monitor costs are unmeasured.

datacenter scalability:
  single mutable distributed Linux/global scheduler claim is blocked; local
  monitor roots plus lease-compiled authority is the supportable direction.

upstream maintenance:
  patch queue shape is good, but stale remote tracking, checkpatch/signoff
  issues, and hot-path anchors require tighter gates.

formal validation:
  current TLA evidence is safety/checklist evidence, not liveness/fairness or
  Linux enforcement refinement.
```

## Validation Verdict

P4 implementation is not approved by this validation.

P4 may be reconsidered only after:

```text
candidate-scope drift is closed, or D4 device_queue_iommu drift is refreshed;
P4 final-run and queued-move anchor manifest exists;
final-run anchor observability is available through runtime or static proof;
P4 remains allow-all only;
no denial path is reachable;
no ABI, monitor call, runtime coverage claim, or protection claim is made.
```

P5 remains blocked by separate denial-source, liveness, negative-test,
path-classification, async, and monitor non-forgeability requirements.
