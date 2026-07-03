# Analysis 0136: SchedExecLease P5A-R Picker Ineligibility Gate

Date: 2026-07-03

Status: design/formal gate. No Linux behavior patch is approved.

## Purpose

This gate refines analysis/0135 into the minimum safe shape for a future
P5A-R behavior patch:

```text
deny one CFS task and pick the next CFS task
```

It is intentionally not an implementation approval. Its job is to prevent the
next patch from using a late run-edge check, `sched_delayed`, `RETRY_TASK`, idle
fallback, class-settled state, core cached picks, DL server state, proxy
executor state, sched_ext dispatch, or Linux-local trace/test/BPF state as
SchedExecLease authority.

## Source Basis

```text
linux_branch=capsched-linux-l0
linux_commit=d812f83c033a9f9b3d533e667e7106a5734eb30b
upstream_ref=upstream/master
upstream_commit=87320be9f0d24fce67631b7eef919f0b79c3e45c
source_map=analysis/0135-sched-exec-lease-p5a-r-cfs-picker-eligibility-source-map.md
```

## Design Decision

The only acceptable P5A-R design family remains:

```text
1. CFS selects a candidate before class state settlement.
2. SchedExecLease validates that candidate against a fresh run tuple.
3. If ALLOW:
     commit the candidate normally.
4. If DENY:
     record an attempt-local denied-candidate receipt.
     make the denied candidate picker-visible ineligible for this attempt.
     retry CFS selection with a finite bound.
5. If no allowed CFS candidate exists:
     fail closed or enter an explicitly modeled quarantine path.
```

This gate does not choose the final Linux data structure. It rejects unsafe
families and records the constraints that later code must satisfy.

## Required Invariants

Denied candidate visibility:

```text
denialRecorded(candidate) => candidate in attempt.ineligible
retry => denied candidate cannot be picked again in the same attempt
```

Pre-settlement:

```text
denial must happen before put_prev_set_next_task()
denial must happen before set_next_task_fair()/set_next_entity() settlement
denial must happen before rq->curr publication
```

Bounded progress and cost:

```text
retryCount <= retryBudget
retry must either pick a different eligible task or fail closed explicitly
linear rb-tree, hierarchy, domain, or denied-list scans are rejected
unbounded retry is rejected
```

Hot-path layout discipline:

```text
no persistent task_struct denial bit
no persistent sched_entity denial bit
no persistent cfs_rq/rq denial field in the first candidate design
no persistent per-cgroup denied map
```

The reason is datacenter cost: task, entity, cfs_rq, and rq layouts are hot,
massively replicated, and upstream-sensitive. A future behavior patch must
prove layout and disabled-path overhead separately before adding persistent
state.

Wakeup isolation:

```text
pick_next_entity()/pick_eevdf() are not schedule-only concepts
denial must be gated to an active schedule-pick attempt
wakeup-preempt paths must not inherit denial cost or semantics
```

Identity and freshness:

```text
attempt-local carrier must be keyed by rq/cpu/attempt epoch
task identity must include task_generation and exec_generation
domain/grant epochs must match
stale denial across migration, exec, exit, cgroup move, enqueue, or dequeue is rejected
```

Hierarchy:

```text
leaf denial must not permanently deny the parent group
if another allowed task exists in the same child cfs_rq, retry may stay there
if no allowed task exists in the child cfs_rq, parent-level skip must be modeled
hierarchical h_nr_queued/h_nr_runnable accounting must not be faked
cgroup mutation without settlement invalidates the attempt-local carrier
```

EEVDF return coverage:

```text
the ineligibility predicate or funnel must dominate every pick_eevdf return:
  single queued entity
  next buddy
  protected current
  leftmost eligible
  heap search result
  final current override
```

A post-leaf check alone is not enough.

Cross-path settlement:

```text
core scheduling:
  core_pick cache, core-cookie search, forced idle, sequence mismatch,
  hotplug/offline, and cookie steal must be settled or explicitly excluded.

DL server:
  fair-server picks must not convert lease denial into wrong server stop,
  RETRY_TASK leakage, uncleared rq->dl_server state, or borrowed-budget
  authority.

proxy execution:
  the authority subject must be explicitly donor, executor, or both, and skip
  lifetime must survive proxy idle/deactivate/migration semantics.

sched_ext:
  SCX switched-all and local DSQ dispatch are out of CFS-only scope unless a
  separate SCX gate is passed.
```

Accounting and lifetime separation:

```text
lease denial is not sleep
lease denial is not CFS bandwidth throttle
lease denial is not delayed dequeue
lease denial is not yield
lease denial is not EEVDF negative lag
denial state must not reference task/entity pointers across delayed dequeue
denial state must not reuse throttled limbo lists or DEQUEUE_THROTTLE
```

Authority separation:

```text
Linux-local sched_exec_task is not positive run authority
a denied receipt is not positive run authority
trace/test state is not positive run authority
BPF state is not positive run authority
CFS picker state is not positive run authority
```

## Accepted First Candidate Shape

For the first future behavior patch, the least-risk shape to model remains:

```text
attempt-local denied-candidate carrier
  lifetime:
    one pick attempt
  protection:
    rq lock
  contents:
    denied leaf task identity and generation
    exec generation
    domain/grant epochs
    denied entity path or parent cfs_rq path evidence
    retry budget
    denial reason/status
  persistence:
    no persistent task_struct bit
    no persistent sched_entity bit
    no public ABI
    no trace ABI
```

The first behavior candidate should be ordinary CFS only, off by default,
test-only, and non-core/non-proxy/non-SCX/non-DL-server unless those paths have
separate settlement models.

## Rejected Design Families

```text
late hook denial:
  rejected because P4 validate_run_edge runs after pick_next_task() and after
  class state settlement.

sched_delayed reuse:
  rejected because delayed dequeue has sleep/fairness accounting semantics and
  pointer lifetime hazards.

RETRY_TASK-only denial:
  rejected because it can spin on the same candidate without picker-visible
  ineligibility, and DL-server propagation is unsafe.

idle fallback authority:
  rejected because idle is not proof that no allowed CFS task exists.

linear candidate search:
  rejected because it destroys CFS picker complexity and datacenter scalability.

persistent hot layout state:
  rejected until separate layout and disabled-overhead proof exists.

core cached pick authority:
  rejected because core_pick can replay an older selection.

DL server authority:
  rejected because server pick/stop/borrow semantics are not RunLease
  authority.

proxy executor authority:
  rejected until donor/executor subject is explicitly modeled.

SCX dispatch authority:
  rejected for CFS-only P5A-R claims.

Linux-local authority forgery:
  rejected for sched_exec_task, denied receipts, trace/test state, BPF state,
  and CFS picker state.
```

## Formal Model

The corresponding TLA+ gate is:

```text
formal/0104-p5a-r-picker-ineligibility-gate-model/P5ARPickerIneligibilityGate.tla
```

It models the safe path:

```text
Start
  -> PickedDenied(A)
  -> Denied(A in attempt.ineligible)
  -> PickedAllowed(B)
  -> Running(B)
```

and rejects unsafe paths where:

```text
the denied candidate runs
retry happens without ineligibility
retry budget is ignored
the denied candidate is committed
denial happens after rq->curr publication
sched_delayed is used as denial
RETRY_TASK is treated as authority
class state is treated as authority
idle fallback is treated as authority
core cached pick is treated as authority
DL server state is treated as authority
proxy executor state is treated as authority
SCX dispatch is treated as authority
cross paths are not settled or excluded
accounting is collapsed
linear search or unbounded retry is used
hot replicated scheduler/task layouts carry persistent denial state
wakeup preemption inherits denial semantics
newidle rq unlock leaks denial carrier state
stale task/exec/domain/grant generation is used
cgroup hierarchy mutation is unsettled
any EEVDF return path bypasses ineligibility
DL-server RETRY_TASK/rq->dl_server state leaks
delayed dequeue or throttled limbo lifetime is aliased
core sequence mismatch or hotplug/offline leaks denial state
Linux-local state is used as positive authority
unsupported core/proxy/SCX/DL-server config is claimed
behavior/protection/cost/datacenter claims are made
```

## Non-Claims

This gate does not approve:

```text
Linux code changes
runtime denial
CFS deny-and-repick implementation
broad move denial
runtime coverage
budget enforcement
public ABI or trace ABI
monitor calls or monitor verification
production protection
hypervisor-grade isolation
cost-efficiency
deployment readiness
datacenter readiness
```

## Next

The next work remains model/design:

```text
P5A-R group hierarchy settlement model
P5A-R source-shape checker for EEVDF return dominance
P5A-R core/DL/proxy/SCX path classification update
P5A-R future Linux patch plan with exact touched files and drift gate
```
