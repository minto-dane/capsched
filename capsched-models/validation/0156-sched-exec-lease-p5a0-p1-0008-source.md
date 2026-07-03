# Validation 0156: SchedExecLease P5A0.P1 0008 Source Gate

Date: 2026-07-02

Status: source checker passed; patch queue replay matched exact Linux HEAD and
tree; safe TLC passed; 11 unsafe configs produced expected counterexamples.
Full build, QEMU, object/layout, and final overclaim acceptance remain pending.

## Scope

This validates the concrete P5A0.P1 `0008` patch as a no-behavior
source-contract delta.

It does not validate behavior-changing denial, runtime coverage, monitor
verification, production protection, cost-efficiency, deployment readiness, or
datacenter readiness.

## Source Gate

Command:

```sh
DOMAINLEASE_RUN_ID=20260702T-p5a0-p1-0008-source \
  capsched/capsched-models/validation/run-sched-exec-lease-p5a0-p1-0008-source-check.sh
```

Result:

```text
run_dir=build/source-check/sched-exec-lease-p5a0-p1-0008-source-check/20260702T-p5a0-p1-0008-source
parent_commit=a937c67f51d1b82297c4f8b7c471f63e8f1a4fe8
future_commit=d812f83c033a9f9b3d533e667e7106a5734eb30b
patch_name=0008-sched-exec_lease-Document-P5A0.P1-no-behavior-bounda.patch
patch_sha256=f3622196210b7953ce34f145cecec8fb23f95cfffc4852c87e3dedbb12a4ea48
series_sha256=6ad90da9bf1f96eabe7a84c333ec15e46810a015ccb7b539f8e941e82dfaa9ac
```

Key checked facts:

```text
checkpatch_clean=true
delta_files_exact_allowlist=true
delta_comment_only=true
hot_helper_bodies_unchanged=true
lifecycle_helper_bodies_unchanged=true
sched_exec_task_layout_changed=false
helper_return_set_allow_only=true
scheduler_branch_on_validation_result=false
scheduler_validation_callsite_count=3
fair_picker_ineligibility=false
public_abi_or_monitor=false
runtime_denial=false
runtime_coverage_claim=false
production_or_cost_claim=false
```

## Patch Queue Replay

Command:

```sh
REPLAY=build/replay/p5a0-p1-0008-verify
DOMAINLEASE_LINUX_REFERENCE="$PWD/linux" \
DOMAINLEASE_RECREATE_FETCH=0 \
  linux-patches/scripts/recreate-capsched-linux-l0.sh "$REPLAY"
```

Result:

```text
linux_head=d812f83c033a9f9b3d533e667e7106a5734eb30b
replay_head=d812f83c033a9f9b3d533e667e7106a5734eb30b
linux_tree=23802bfd565a1a3f2c8ece2b3702d0eaea6d3ff8
replay_tree=23802bfd565a1a3f2c8ece2b3702d0eaea6d3ff8
log=build/replay/p5a0-p1-0008-verify.log
```

## Formal Gate

Model:

```text
formal/0103-p5a0-p1-0008-source-gate-model/
```

TLC output:

```text
build/tlc/p5a0-p1-0008-source-gate/20260702T-p5a0-p1-0008-source
```

Safe config passed. The 11 unsafe configs produced expected counterexamples
for missing `0008`, out-of-allowlist delta, non-comment code, checkpatch/replay
failure, hot-helper change, lifecycle-helper change, layout change, non-ALLOW
or scheduler branch, ABI/monitor surface, runtime/protection claims, and full
acceptance overclaim.

## Verdict

P5A0.P1 `0008` is accepted as a source-contract/no-behavior delta only.

It remains deliberately insufficient for P5A-R or P5A-M. Denying one CFS task
still requires fair-picker eligibility integration, and broad common move
denial still requires status settlement across migration, affinity, swap, push,
and core-cookie-steal paths.
