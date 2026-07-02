# Analysis 0132: SchedExecLease P5A0.E Prepatch Evidence

Date: 2026-07-02

Status: prepatch evidence package; no Linux patch approved.

## Purpose

P5A0 recorded the only safe next direction:

```text
no-behavior infrastructure before any CFS denial or broad move denial
```

P5A0.E is not that infrastructure patch. It is the evidence package required
before such a patch can be written or reviewed.

The goal is to prevent the project from drifting into behavior enforcement by
accident. P5A0.E fixes the review contract for:

- fresh source drift;
- patch queue plan;
- source checker plan;
- build and QEMU denial-disabled plan;
- object and symbol review plan;
- negative harness plan;
- claim ledger row;
- explicit non-claims.

## Source Basis

Linux work tree:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
commit: a937c67f51d1b82297c4f8b7c471f63e8f1a4fe8
subject: sched/exec_lease: Add allow-only validation skeleton
```

Fresh drift run:

```text
run_dir: build/source-drift/linux-source-drift-gate/20260702T-p5a0-1-drift
base_commit: 4edcdefd4083ae04b1a5656f4be6cd83ae919ef4
upstream_commit: 87320be9f0d24fce67631b7eef919f0b79c3e45c
work_commit: a937c67f51d1b82297c4f8b7c471f63e8f1a4fe8
merge_tree_clean: true
patch_footprint_config_matches_actual: true
```

The global model freshness result is intentionally not fresh:

```text
model_freshness: stale
semantic_drift_requires_refresh: true
stale group: device_queue_iommu
changed_count: 61
```

This stale result remains real for device, QueueLease, IOMMU, network,
datacenter, protection, and cost-efficiency claims.

## Candidate Scope

P5A0.E candidate identity:

```text
candidate_id: P5A0EPrepatchEvidence
mode: evidence_only_no_linux_patch
```

Touched or claimed groups for this evidence package:

```text
l0_footprint:
  fresh, changed_count=0

scheduler_authority_core:
  fresh, changed_count=0
```

The task lifecycle identity group is not claimed by P5A0.E. A later patch that
touches fork, exec, exit, or task layout must refresh and claim it separately.

Non-candidate stale group:

```text
device_queue_iommu:
  D4_semantic_drift
  stale for queuelease_patch, iommu_mapping_claim, device_queue_lease_claim,
  datacenter_device_claim, global_all_angles_freshness
```

P5A0.E must not convert candidate-scoped freshness into global freshness.

## Source Observations

Current P4 allow-only helpers are static inline and return only ALLOW:

```text
include/linux/sched_exec_lease.h:
  sched_exec_lease_validate_run_edge()
  sched_exec_lease_validate_move_edge()
  sched_exec_lease_validate_move_edge_locked()
```

Current callsites:

```text
kernel/sched/core.c:
  move_queued_task()
  __schedule()

kernel/sched/sched.h:
  move_queued_task_locked()
```

Current facts that keep P5 behavior blocked:

```text
run:
  final-run validation is before rq->curr and context_switch
  final-run validation is after pick_next_task and known class settlement
  therefore it is not a denial hook

move:
  common and locked move validation are before local detach and set_task_cpu
  callers still assume success
  move helpers do not return denial status to callers
  therefore broad move denial is not settled
```

## P5A0.E Required Plans

Patch queue plan:

```text
next patch queue slot: future 0008, not created by P5A0.E
patch class: no-behavior infrastructure only
required before acceptance: replay to exact Linux HEAD and clean checkpatch
```

Source checker plan:

```text
check current Linux HEAD matches the P5A0.E contract
check candidate groups are fresh or explicitly scoped
check non-candidate stale groups are recorded and barred from broad claims
check helper return set is ALLOW only
check scheduler does not branch on validation result
check callsite count and names remain expected
check move helpers still have no reachable non-ALLOW behavior
check run helper is not used as a denial hook
check no syscall/ioctl/sysfs/procfs/debugfs/tracepoint/monitor ABI appears
check no allocation, sleep, lock, refcount, exported symbol, or monitor call is
  introduced by a future P5A0 patch
check no task_struct, rq, sched_entity, cfs_rq, or scheduler-class layout change
  is introduced by a future P5A0 patch unless a separate layout gate approves it
```

Build and QEMU plan:

```text
CONFIG_SCHED_EXEC_LEASE=n full vmlinux build
CONFIG_SCHED_EXEC_LEASE=y full vmlinux build
QEMU boot/workload smoke with denial disabled
no runtime coverage claim from this smoke
```

Object and symbol plan:

```text
CONFIG=n:
  no sched_exec_lease object code in scheduler hot path

CONFIG=y:
  helper symbols not emitted unless explicitly justified
  no exported symbols
  no public ABI symbols
  object-size and disassembly review for hot-path codegen
  no task_struct, rq, sched_entity, or cfs_rq layout change unless separately
  approved
```

Negative harness plan:

```text
internal-only observables may be planned
no public tracepoint ABI
no syscall/ioctl/sysfs/procfs/debugfs ABI
no monitor ABI
no live denial injection until P5A-R/P5A-M validates source placement and
status settlement
```

Claim ledger row:

```text
allowed claim:
  P5A0.E prepatch evidence package recorded and validated

candidate-scoped claim:
  l0_footprint and scheduler_authority_core were fresh for this evidence
  package at the recorded drift run

forbidden claims:
  Linux patch approved
  behavior change approved
  runtime denial
  runtime coverage
  monitor verification
  production protection
  hypervisor-grade isolation
  cost efficiency
  deployment readiness
  datacenter readiness
  global all-angles freshness
```

## Security Review Points

The main security risk in P5A0.E is not a direct vulnerability. It is authority
collapse in the design process:

- treating ALLOW-only helper return vocabulary as enforcement;
- treating the final-run observation point as denial-safe;
- treating local pre-move validation as caller-visible denial settlement;
- treating candidate-scoped drift freshness as global freshness;
- treating QEMU smoke as runtime coverage;
- treating Linux-only scaffolding as monitor-backed protection.

P5A0.E rejects all of these.

## Performance and Scalability Review Points

The future no-behavior infrastructure patch must preserve hot-path discipline:

- no new task or rq cacheline fields;
- no new scheduler branch on validation result;
- no allocation, sleeping, refcount transfer, or monitor transition;
- no public tracepoint emitted from hot paths;
- no retry loop or fair-picker repick loop;
- no cross-CPU status propagation on the ALLOW path;
- object/disassembly review before accepting even ALLOW-only plumbing.

Any status carrier that changes code generation or branch structure must be
measured and reviewed before acceptance.

## Upstream-Tracking Review Points

P5A0.E is safe only while the candidate scope remains small. A future patch
that touches or claims any of the following must reopen scope:

```text
task_lifecycle_identity
async_workqueue
async_io_uring
policy_frontend_security
memory_and_mm_state
device_queue_iommu
```

The stale `device_queue_iommu` result must remain visible in state and cannot
be hidden by scheduler-only progress.

## Future Patch Identity

To avoid ambiguity, the canonical names are:

```text
P5A0.E:
  this prepatch evidence package; no Linux patch.

P5A0.P1:
  future first no-behavior Linux patch proposal, limited to source-only
  contract/internal type shapes.

P5A0.P2:
  future move status carrier plumbing, still ALLOW-only, only after P5A0.P1
  and a renewed source/object review.
```

The recommended P5A0.P1 Linux file allowlist is:

```text
include/linux/sched_exec_lease.h
kernel/sched/exec_lease.c
```

Touching `kernel/sched/core.c`, `kernel/sched/sched.h`, `kernel/sched/fair.c`,
`kernel/sched/rt.c`, `kernel/sched/deadline.c`, or `kernel/sched/ext/ext.c`
expands scope and requires a new scheduler-settlement gate before review.

## Decision

P5A0.E may close only the prepatch evidence requirement.

It does not approve Linux code. It does not approve P5A0.P1 or P5A0.P2. It
makes a future P5A0.P1 proposal reviewable only if that proposal remains
no-behavior, stays within the file allowlist or reopens scope, and passes the
source checker, formal gate, build/QEMU plan, object/symbol review, and
overclaim review defined here.

## Non-Claims

This note does not approve Linux code, behavior changes, runtime denial,
retry, fail-closed behavior, quarantine, public ABI, tracepoint ABI, monitor
calls, monitor verification, runtime coverage, production protection,
hypervisor-grade isolation, cost-efficiency, deployment readiness, datacenter
readiness, or global all-angles freshness.
