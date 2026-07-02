# Validation 0155: SchedExecLease P5A0.P1 Patch Plan Gate

Date: 2026-07-02

Status: source/JSON gate passed; safe TLC passed; 20 unsafe configs produced
expected counterexamples; no Linux patch approved.

## Scope

This validates the P5A0.P1 plan contract only. It does not create or approve
`linux-patches` entry `0008` and does not modify Linux.

P5A0.P1 remains:

```text
source-only contract/internal-shape planning
no behavior
no denial
no Linux patch approval
```

## Source Gate

Command:

```sh
DOMAINLEASE_RUN_ID=20260702T-p5a0-p1-plan \
  capsched/capsched-models/validation/run-sched-exec-lease-p5a0-p1-patch-plan-gate.sh
```

Result:

```text
run_dir=build/source-check/sched-exec-lease-p5a0-p1-patch-plan-gate/20260702T-p5a0-p1-plan
```

Key checked facts:

```text
work_commit_matches=true
linux_tree_clean=true
linux_patch_created=false
linux_patch_approved=false
future_0008_patch_exists=false
per_0008_delta_required=true
whole_queue_footprint_not_sufficient=true
file_allowlist_exact=true
hot_path_helper_count=8
validation_helper_count=3
helper_return_set_allow_only=true
scheduler_validation_callsite_count=3
scheduler_branch_on_validation_result=false
fair_picker_ineligibility=false
lifecycle_helper_count=4
lifecycle_callsite_baseline_present=true
lifecycle_helper_body_change_allowed=false
object_and_hot_function_growth_review_required=true
layout_review_required=true
runtime_denial_approved=false
public_abi_or_monitor=false
production_or_cost_claim=false
global_all_angles_freshness=false
```

## Formal Gate

Model:

```text
formal/0102-p5a0-p1-patch-plan-gate-model/
```

TLC output:

```text
build/tlc/p5a0-p1-patch-plan-gate/20260702T-p5a0-p1-plan/summary.tsv
```

Safe config passed and requires `PlanRecordedEventually`, so the model cannot
pass by staying in `Start`. The 20 unsafe configs produced expected
counterexamples for missing evidence, missing plan record, patch approval,
missing patch identity, missing allowlist, out-of-allowlist delta, scheduler
touch without reopen, unclaimed drift-group touch, external layout/runtime
state, lifecycle helper changes, non-static/exported symbols, behavior or
non-ALLOW reachability, scheduler branches, runtime-denial family, public
ABI/trace/monitor surface, layout/hot-path impact, allocation/sleep/lock/ref,
QEMU-smoke-as-coverage, scoped-freshness-as-global, and
protection/cost/datacenter overclaims.

## Review Inputs Integrated

Subagent review integration:

- Security review: allowlist is insufficient by itself because `exec_lease.c`
  lifecycle helpers are called from fork, exec, and exit; P5A0.P1 freezes their
  behavior.
- Maintainability review: future acceptance must inspect the `0008` delta,
  not the full existing queue footprint.
- Performance review: future acceptance must include object/section-size,
  hot scheduler function growth, and layout evidence.
- Formal review: P5A0.P1 is a plan/reviewability gate, not patch approval; the
  safe model includes an eventual plan-recorded property.

## Verdict

P5A0.P1 patch-plan gate is recorded and validated. A future `0008` Linux patch
may be drafted only under this contract, but it is not approved here.

P5A-R CFS denial remains blocked by fair-picker eligibility integration.
P5A-M broad move denial remains blocked by migration, affinity, swap, push, and
core-cookie-steal status settlement.
