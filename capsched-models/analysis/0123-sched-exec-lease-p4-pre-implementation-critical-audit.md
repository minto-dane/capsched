# SchedExecLease P4 Pre-Implementation Critical Audit

Date: 2026-07-02

Status: P4 implementation is paused pending scoped drift closure and anchor
evidence hardening.

This note supersedes the operational readiness conclusion of N-166 for any
future P4 implementation decision. N-166 remains valid historical evidence for
the then-fetched local upstream ref. This audit re-ran the drift gate against
the current remote upstream and incorporated independent read-only reviews from
security, scheduler integration, performance, datacenter scalability, upstream
maintenance, and formal-validation perspectives.

## Scope

This is not a Linux behavior patch. It does not approve runtime denial,
monitor calls, ABI, budget charging, policy issuance, runtime coverage,
production protection, hypervisor-grade isolation, cost-efficiency, or
deployment readiness.

The audited question is narrower:

```text
Can we safely move from P3 placement-only no-op scheduler touchpoints
to P4 allow-all final-run/move validation skeleton?
```

The answer is:

```text
Not yet as a fully closed pre-P4 gate.
```

P4 remains architecturally plausible if it stays allow-all/no-denial/no-ABI/no
monitor. However, the validation base must be hardened first, because the
previous pre-entry gate had two weaknesses:

1. the drift watch map missed `kernel/sched/ext/ext.c` by watching the
   nonexistent `kernel/sched/ext.c`;
2. the direct patch footprint listed only the old four scaffold files while
   the current P3 Linux delta touches ten files.

Both are validation infrastructure issues. They do not show a runtime bug in
P3, but they are serious enough that P4 must not proceed on the old evidence.

## Current Fresh Remote Result

The drift gate was hardened and re-executed with fetch enabled.

Run directory:

```text
build/source-drift/linux-source-drift-gate/20260702T203130Z-n167-p4-pre-audit
```

Observed refs:

```text
base_commit:     4edcdefd4083ae04b1a5656f4be6cd83ae919ef4
upstream_commit: 87320be9f0d24fce67631b7eef919f0b79c3e45c
work_commit:     d5f77adb5a64f3b2545db6ab1dcdc4aa4442bab3
base..upstream:  422 commits
merge-tree:      clean
```

Hardened gate result:

```text
watched_changed_count:                62
model_refresh_required_count:         1
missing_watched_path_count:           0
patch_footprint_config_matches_actual:true
model_freshness:                      stale
candidate_no_behavior_patch_reviewable:false
```

Group result:

```text
l0_footprint:                  fresh
scheduler_authority_core:      fresh
task_lifecycle_identity:       fresh
async_workqueue:               fresh
async_io_uring:                fresh
policy_frontend_security:      fresh
memory_and_mm_state:           fresh
device_queue_iommu:            stale, D4 semantic drift
scheduler_nearby_non_intersecting: D1 cpufreq_schedutil.c drift
```

The D4 stale group is caused by a net merge after the previous local fetch,
including netfilter, TCP, bridge, DSA, SCTP, TIPC, batman-adv, and net/sched
fixes. Scheduler P4 does not directly touch those paths, but the project-level
drift gate is intentionally global and currently has no candidate-scope
selector. Therefore a global all-angles P4 preflight is not closed.

## Security Review

Security verdict:

```text
No hypervisor-grade or security-boundary claim is defensible.
```

Reasons:

- There is no non-forgeable monitor root. Linux-local task shadows remain
  forgeable under hostile Domain kernel-context compromise.
- P3 helpers are static inline no-ops and cannot deny, retry, charge budget, or
  call a monitor.
- P4 allow-all has zero protection value. It is safe only because it does not
  protect anything.
- P5 denial is source-unsafe unless redesigned around pre-settle insertion or
  a real rollback proof.
- Scheduler path coverage remains intentionally narrow: ordinary CFS only for
  first P5 consideration, with sched_ext/core/proxy/RT/DL/async paths disabled
  or excluded.
- Async provenance remains a confused-deputy blocker. Generic workqueue and
  io_uring state do not naturally carry caller authority.

P4 can only be an observation/source-shape step. The first reachable non-allow
branch turns the work into P5 and must go through P5 gates.

Codex Security plugin note: a broad vulnerability scan is not a substitute for
the missing monitor root, path coverage, or denial proof. The next useful
plugin-backed scan is a security diff scan after a concrete P4 patch is staged.

## Scheduler Integration Review

P4 placement is defensible only for allow-all validation:

- A hook near the final returned task is observation-compatible.
- A denial at that point is not automatically safe because Linux may already
  have settled scheduler-class state through `put_prev_set_next_task()`.
- Shared queued-move helpers are valid observation points for their users, but
  they do not cover fair direct load-balance detach, sched_ext DSQ migration,
  proxy execution migration, or all class-specific paths.
- The current P3 switch marker occurs after `rq->curr` publication and must
  stay observation-only.

P5 becomes unsound if it simply turns P4 allow-all into denial, uses unbounded
`pick_again` retries, fails to make denied candidates invisible to the picker,
or leaves sched_ext/core/proxy enabled while claiming coverage.

## Formal and Validation Review

The formal suite is valuable but currently weighted toward safety/checklist
properties:

```text
PROPERTY/WF_/SF_ usage in formal tree: 0 files
CHECK_DEADLOCK FALSE configs:          255 files
```

This does not invalidate the safety results. It means they must not be read as
progress, fairness, bounded drain, or bounded retry evidence.

Before P5, add temporal properties or explicit stuck/quarantine states for:

- bounded retry progress;
- no starvation after denial;
- eventual revoke drain;
- bounded running-after-revoke latency;
- bounded root-token latency after epoch revoke.

Before accepting P4 as final-run-anchor evidence, either runtime observability
for `pick_next_task()`/`__schedule` must work, or an equivalent static
instrumentation proof must show the exact call sites.

## Performance Review

Current performance facts are limited:

- P3 marker helpers compile away in the observed build; this is compatibility
  evidence, not a performance result.
- P2 already adds real task footprint: the task shadow grows `task_struct` from
  about `0xcc0` to `0xd00`, roughly 64 bytes per task after layout/alignment.
- P4 is not applied. Once helpers stop compiling away, expected costs include
  branch predictor pressure, I-cache growth in `__schedule`, register pressure,
  rq-lock/IRQ-off residency, and helper-call cost.
- QEMU boot/workload evidence is compatibility-only and cannot support
  cost-efficiency.
- Monitor transition, MemoryView switch, IOTLB invalidation, queue revoke, and
  DMA drain costs remain the real datacenter tail-latency risks.

No cost-efficiency claim is permitted before KVM, Firecracker, container/Linux,
and native Linux baselines exist with throughput, p99/p999 latency, density,
and operational-cost criteria.

## Datacenter and Multi-Cluster Review

The strong claim is not a single distributed mutable Linux kernel or one global
runqueue across clusters.

The supportable direction is:

```text
single Linux-compatible ABI/control-plane style
+ local monitor roots
+ cluster leases compiled into node-local authority
+ typed cross-node service endpoints
+ no global scheduler authority
```

Required future artifacts:

- ClusterControlPlaneAuthority;
- FailureDomainPartition;
- ClockEpochLease;
- CrossNodePlacementServiceDomain;
- DatacenterIOLocality;
- GlobalRevokeDrain;
- OperationalIsolation evidence contract.

Until those exist, cluster/single-OS language must be scoped to lease
translation and service-domain RPC, not scheduler continuity across nodes.

## Upstream Maintenance Review

The patch queue approach is still correct, but upstream readiness is not
achieved:

- checkpatch/signoff/description problems remain in the historical queue;
- P4/P5 anchors are in high-churn hot paths;
- P5 artifacts must be refreshed after P4 because some still cite older P2
  source basis;
- a clean public/RFC queue should eventually remove private add-then-rename
  history and carry real patch descriptions and signoffs.

The drift runner now fails closed for nonexistent watch paths and requires the
configured direct footprint to match the actual `base..work` Linux diff.

## Decision

P4 implementation is not approved by this audit yet.

Allowed next actions:

1. keep Linux code unchanged;
2. retain P3 as no-denial/no-ABI/no-monitor compatibility only;
3. harden validation and traceability;
4. create a candidate-scoped drift gate for scheduler-only P4, or refresh the
   stale D4 device/QueueLease source maps against upstream
   `87320be9f0d24fce67631b7eef919f0b79c3e45c`;
5. create an anchor manifest for P4 final-run and queued-move sites;
6. improve runtime/static observability for final-run anchors;
7. keep P5 blocked until source-specific CFS pre-settle denial and liveness
   properties exist.

Forbidden next actions:

1. applying P4 as anything other than allow-all;
2. treating P4 as protection evidence;
3. treating TLA safety checks as Linux enforcement evidence;
4. claiming hypervisor-grade isolation, datacenter cost efficiency, or
   production readiness;
5. moving to P5 by changing P4 return values;
6. relying on Linux-local task shadow fields as monitor-backed authority.

## P4 Reopen Criteria

P4 may be reconsidered only when all of the following are true:

```text
fresh_remote_drift_checked=true
watch_path_existence_checked=true
patch_footprint_matches_actual=true
candidate_scope_drift_closed=true
final_run_anchor_manifest_present=true
queued_move_anchor_manifest_present=true
runtime_or_static_anchor_observability_present=true
p4_helpers_allow_all_only=true
no_denial_path_reachable=true
no_abi=true
no_monitor_call=true
no_runtime_coverage_claim=true
no_protection_claim=true
```

P5 remains blocked after P4 until denial-source shape, liveness/progress,
negative tests, path-classification enforcement, async exclusions, and monitor
receipt non-forgeability are modeled and validated.
