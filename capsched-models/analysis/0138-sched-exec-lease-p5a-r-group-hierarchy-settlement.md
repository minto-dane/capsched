# Analysis 0138: SchedExecLease P5A-R Group Hierarchy Settlement

Date: 2026-07-03

Status: design/formal/source-shape gate. No Linux behavior patch is approved.

## Purpose

P5A-R cannot safely implement:

```text
deny one CFS task and pick the next CFS task
```

until leaf-task denial is separated from parent group/cgroup denial.

Current Linux CFS selection is hierarchical. `pick_task_fair()` starts at the
root `cfs_rq`, repeatedly picks a `sched_entity`, descends through
`group_cfs_rq(se)`, and only materializes the final task with `task_of(se)` once
the selected entity is a leaf task.

Therefore:

```text
denying leaf task A
  !=
skipping the parent group entity containing A
```

Skipping the parent group is legal only after an explicit child-exhaustion
proof for the current attempt. Otherwise one denied leaf can hide allowed
siblings and turn P5A-R into cgroup-level denial.

## Source Basis

```text
linux_branch=capsched-linux-l0
linux_commit=d812f83c033a9f9b3d533e667e7106a5734eb30b
upstream_ref=upstream/master
upstream_commit=87320be9f0d24fce67631b7eef919f0b79c3e45c
prior_gate=analysis/0137-sched-exec-lease-p5a-r-eevdf-return-dominance.md
```

## Current Linux Shape

Source facts:

```text
entity_is_task(se):
  a sched_entity is a task iff it does not own a child runqueue.

task_of(se):
  warns if se is not a task entity.

group_cfs_rq(se):
  returns the child cfs_rq owned by a group entity.

pick_task_fair():
  starts from rq->cfs
  calls pick_next_entity()
  if no entity, retries only for delayed dequeue/new selection semantics
  descends by cfs_rq = group_cfs_rq(se)
  repeats until cfs_rq is NULL
  then calls task_of(se)
```

Settlement occurs after selection:

```text
__pick_next_task():
  p = pick_task_fair(...)
  put_prev_set_next_task(...)

set_next_task_fair():
  walks sched_entity ancestors for the selected task
  set_next_entity(...)

set_next_entity():
  writes cfs_rq->curr = se
```

Thus post-`task_of(se)` denial is too late to prove hierarchy correctness
unless rollback is separately proven. This gate does not approve rollback.

## Required State Distinctions

The next implementation design must distinguish:

```text
LeafDenied:
  a concrete leaf task identity/generation is denied for this attempt.

PathDenied:
  an entity path carries denial evidence; this is not cgroup authority by
  itself.

ChildCfsRqExhausted:
  within a child cfs_rq, no supported allowed descendant remains for this
  attempt.

ParentSkipJustified:
  the parent group entity may be skipped only because ChildCfsRqExhausted is
  proven for that child.

ParentOverDenied:
  unsafe state: a parent group is skipped while an allowed sibling descendant
  remains.
```

## Required Invariants

```text
parent skip => child cfs_rq exhaustion proof
leaf denial does not imply parent skip
path denial does not mint cgroup authority
allowed sibling descendant must remain pickable
same denied leaf must not be repicked in the same attempt
child exhaustion is not nr_queued == 0
child exhaustion is not sleep/throttle/delayed dequeue/yield/EEVDF lag
task_of(se) is only used after the entity is a leaf task
group hierarchy settlement remains ordinary-CFS-only
core/DL/proxy/SCX remain excluded or unsettled by this artifact
```

## Rejected Design Families

```text
post-task_of-only denial:
  rejected because parent entity choices have already been made.

leaf-denial-implies-parent-skip:
  rejected because it can hide allowed sibling descendants.

parent skip without child exhaustion:
  rejected because it changes task-level denial into cgroup-level denial.

child exhaustion by accounting alias:
  rejected for nr_queued, sleep, throttle, delayed dequeue, yield, or EEVDF lag.

task_of on group entity:
  rejected because group entities are not tasks.

path evidence as authority:
  rejected because path evidence is a carrier, not positive authority.
```

## Non-Claims

This gate does not approve:

```text
Linux code changes
runtime denial
CFS deny-and-repick implementation
group hierarchy implementation
core/DL/proxy/SCX settlement
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

After this gate, P5A-R still needs:

```text
core/DL/proxy/SCX exclusion-or-settlement gate
no-O(n)/no-hot-layout/disabled-overhead gate
negative validation plan
implementation patch plan
```
