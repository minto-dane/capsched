# Analysis 0088: Linux Source-Map Refresh Target Selection

Status: target selected for source-only refresh

Date: 2026-07-01

Related artifacts:

```text
analysis/0087-linux-source-drift-automation-and-model-freshness.md
analysis/linux-source-drift-model-freshness-gate-v1.json
validation/run-linux-source-drift-gate.sh
validation/0103-linux-source-drift-freshness-gate.md
analysis/linux-source-map-refresh-target-selection-v1.json
formal/0066-linux-source-map-refresh-target-model/
validation/0104-linux-source-map-refresh-target-selection.md
```

## Purpose

N-132 made upstream drift observable and model freshness explicit. This note
applies that gate to choose the next concrete source-map refresh target.

The selected target is:

```text
scheduler_authority_core
```

This is a source-map refresh target, not a Linux patch target.

## Gate Input

The current source-drift gate run observed:

```text
run_id=20260701T193000Z
base=4edcdefd4083ae04b1a5656f4be6cd83ae919ef4
upstream=665159e246749578d4e4bfe106ee3b74edcdab18
work=7cf0b1e415bcead8a2079c8be94a9d41aad7d462
base_to_upstream_commit_count=340
watched_changed_count=1
model_refresh_required_count=0
merge_tree_clean=true
model_freshness=fresh
linux_patch_approved=false
```

The only changed watch group was:

```text
scheduler_nearby_non_intersecting:
  kernel/sched/cpufreq_schedutil.c
```

That drift should remain recorded, but it is not by itself the highest-value
source-map refresh target.

## Candidate Comparison

| Candidate | Freshness | Centrality | Immediate value | Decision |
| --- | --- | ---: | --- | --- |
| `scheduler_authority_core` | fresh | high | root of RunCap/SchedContext/FrozenRunUse hook semantics | selected |
| `task_lifecycle_identity` | fresh | high | spawn/exec/exit propagation, but depends on scheduler authority vocabulary | later |
| `async_workqueue` | fresh | high | heavily modeled in N-127/N-129; implementation remains blocked | later |
| `async_io_uring` | fresh | high | heavily modeled in N-128/N-129; implementation remains blocked | later |
| `scheduler_nearby_non_intersecting` | changed but non-stale | low for authority | record drift, do not chase as main model target | not selected |
| `l0_footprint` | fresh | medium | no drift, no patch movement | not selected |
| `policy_frontend_security` | fresh | medium | important for issuance, but not the execution root | later |
| `memory_and_mm_state` | fresh | high | production isolation root, but belongs to later split-state/monitor layer | later |
| `device_queue_iommu` | fresh | high | production I/O isolation root, but later L4/L5 | later |

## Why Scheduler Authority Core

The scheduler authority core is the narrowest source-map target that advances
the central CapSched model:

```text
RunCap admission
FrozenRunUse custody
SchedContext budget and placement
SelectedUse validation
DomainTag switch activation
budget tick/charge
class-specific selection
sched_ext and fallback implications
```

It is also where a future Linux patch would be most tempting. That makes it the
right target for a source-only refresh before any implementation movement.

## Current Upstream Anchors

Current upstream anchors at `665159e246749578d4e4bfe106ee3b74edcdab18` include:

```text
kernel/sched/core.c:2172 enqueue_task()
kernel/sched/core.c:2219 activate_task()
kernel/sched/core.c:3805 ttwu_do_activate()
kernel/sched/core.c:3865 ttwu_runnable()
kernel/sched/core.c:4067 ttwu_queue()
kernel/sched/core.c:4251 try_to_wake_up()
kernel/sched/core.c:5674 task_sched_runtime()
kernel/sched/core.c:5762 sched_tick()
kernel/sched/core.c:6124 __pick_next_task()
kernel/sched/core.c:7061 __schedule()
kernel/sched/core.c:7316 schedule()
kernel/sched/fair.c:1985 update_curr()
kernel/sched/fair.c:14851 task_tick_fair()
kernel/sched/rt.c:974 update_curr_rt()
kernel/sched/rt.c:2540 task_tick_rt()
kernel/sched/deadline.c:2128 update_curr_dl()
kernel/sched/deadline.c:2876 task_tick_dl()
kernel/sched/ext/ext.c:1321 update_curr_scx()
kernel/sched/ext/ext.c:3480 scx_tick()
kernel/sched/ext/ext.c:3505 task_tick_scx()
```

Important refreshed observations:

```text
enqueue_task() is void and mutates uclamp, class enqueue, psi, sched_info, and
sched_core state.

activate_task() calls enqueue_task() before writing p->on_rq =
TASK_ON_RQ_QUEUED.

ttwu_runnable() can re-enqueue delayed fair state with ENQUEUE_DELAYED and does
not create new CapSched authority.

try_to_wake_up() has a current-task special case that clears blocked state and
calls ttwu_do_wakeup() without normal enqueue custody.

try_to_wake_up() writes TASK_WAKING before remote/local enqueue paths, making
failure placement delicate.

sched_tick() charges/accounting work to rq->donor, not blindly to rq->curr.

__pick_next_task() has fair fast path, class iteration, RETRY_TASK handling, and
sched_ext restart implications.

__schedule() commits through rq locking, state reads, block/dequeue paths, pick,
and context-switch machinery; fail-closed DomainTag activation must be modeled
before behavior patches.
```

## Refresh Scope

The next source-only refresh should update:

```text
analysis/0025-linux-scheduler-authority-state-machine.md
analysis/0026-scheduler-hook-proof-obligation-matrix.md
analysis/0028-tick-runtime-budget-source-map.md
formal/0012-linux-scheduler-authority-model/
```

The refresh must preserve:

```text
No Linux patch
No direct-call stub
No async-carrier Linux name
No tracepoint ABI
No ABI
No runtime coverage claim
No monitor verification claim
No production protection claim
```

## Not Selected Now

### Workqueue and io_uring

They remain important, but recent work has already split them into dedicated
adapter models. Their next movement is not source-map selection; it is still
blocked on concrete storage, lifetime, locking, settlement, and tests.

### cpufreq_schedutil drift

The only observed upstream drift is scheduler-nearby but non-stale for current
authority models. Chasing it as the main refresh target would optimize for the
latest changed file rather than the highest security leverage.

### Memory and Device Roots

MemoryView, IOMMU, QueueLease, and HyperTag Monitor work remains central to the
hypervisor-grade goal, but the next Linux scheduler capability step still needs
a refreshed execution-authority root.

## Decision

Proceed with a source-only scheduler authority core refresh next.

Do not approve Linux code.

## Non-Claims

This target selection does not approve Linux implementation, runtime coverage,
ABI, public tracepoints, workqueue integration, io_uring integration, monitor
verification, behavior change, or production protection.
