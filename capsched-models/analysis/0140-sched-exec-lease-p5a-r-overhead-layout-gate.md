# Analysis 0140: SchedExecLease P5A-R Overhead and Layout Gate

Date: 2026-07-03

Status: design/formal/source-shape gate. No Linux behavior patch is approved.

## Purpose

P5A-R is a future behavior slice for:

```text
deny one ordinary CFS task and pick the next ordinary CFS task
```

The design is only acceptable if it does not buy safety by destroying scheduler
cost structure. The first behavior candidate must not add unbounded scans,
unbounded retry, persistent hot denial fields, or disabled-configuration
overhead without separate generated-object and layout evidence.

This gate converts that into a pre-code rule:

```text
security semantics must be explicit
cost semantics must be explicit
disabled overhead must be evidenced
hot layout changes must be separately justified
```

## Source Basis

```text
linux_branch=capsched-linux-l0
linux_commit=d812f83c033a9f9b3d533e667e7106a5734eb30b
upstream_ref=upstream/master
upstream_commit=87320be9f0d24fce67631b7eef919f0b79c3e45c
prior_gate=analysis/0139-sched-exec-lease-p5a-r-cross-path-exclusion-settlement.md
layout_evidence=validation/0158-sched-exec-lease-p5a0-p1-object-layout.md
```

## Current Baseline

Current Linux has a config-gated task identity shadow:

```text
CONFIG_SCHED_EXEC_LEASE=y:
  task_struct.sched_exec exists

CONFIG_SCHED_EXEC_LEASE=n:
  sched_exec field is absent from task_struct
```

That field is existing P2/P5A0 baseline evidence, not P5A-R denial state.

Current P4 helpers are inline allow-only:

```text
sched_exec_lease_validate_run_edge()         -> ALLOW
sched_exec_lease_validate_move_edge()        -> ALLOW
sched_exec_lease_validate_move_edge_locked() -> ALLOW
```

Current P5A0.P1 object/layout evidence records:

```text
CONFIG_SCHED_EXEC_LEASE=off:
  exec_lease.o absent
  sched_exec field absent

CONFIG_SCHED_EXEC_LEASE=on:
  exec_lease.o present
  task_struct.sched_exec is the existing P2 layout
  P5A0.P1 adds no new task/rq/sched_entity/cfs_rq layout change
```

P5A-R must preserve this discipline unless a later patch carries a separate
layout and generated-object proof.

## Hot Structures

The following structures are hot, replicated, upstream-sensitive, or all three:

```text
task_struct
sched_entity
cfs_rq
rq
per-cgroup scheduler state
CFS rb-tree / EEVDF timeline state
```

The first P5A-R behavior candidate must not add persistent denial state to them.

## Required Shape

The first acceptable P5A-R denial design must use:

```text
attempt-local carrier
rq lock protection
constant retry budget
constant denied-candidate receipt capacity
pre-frozen authority tuple
candidate identity comparison only
no allocation in the picker
no sleep in the picker
no monitor call in the picker
no policy lookup in the picker
```

The future code can ask:

```text
is this selected candidate the denied candidate for this attempt?
```

It must not ask by scanning:

```text
walk the rb-tree until an allowed task appears
walk every descendant cfs_rq
walk every task in a cgroup
walk a Domain table from the picker
walk a denied list/map of unbounded size
```

## Required Invariants

```text
retry_count <= fixed_retry_budget
denied_receipt_count <= fixed_constant
retry never performs an unbounded candidate search
picker does not allocate, sleep, call policy, or enter monitor
candidate validation uses pre-frozen authority
P5A-R denial state is attempt-local, not persistent hot layout
disabled CONFIG_SCHED_EXEC_LEASE has no new runtime object or branch cost
enabled hot layout is unchanged unless a separate layout gate approves it
hot scheduler function growth requires object/function-size evidence
cost/datacenter claims require benchmark evidence, not model evidence
```

## Rejected Design Families

```text
linear rb-tree scan:
  rejected because it changes picker complexity.

full hierarchy scan:
  rejected because cgroup depth/fanout becomes denial-path cost.

domain-table lookup in picker:
  rejected because authority must be pre-frozen before the picker.

unbounded retry:
  rejected because denial can become scheduler livelock.

persistent task_struct denial bit:
  rejected because task_struct is hot and massively replicated.

persistent sched_entity denial bit:
  rejected because EEVDF entity layout is hot picker state.

persistent rq/cfs_rq denial field:
  rejected for the first candidate because it changes hot scheduler layout.

per-cgroup denied map:
  rejected because it turns a task denial into scalable mutable cgroup state.

allocation/sleep/monitor/policy lookup in picker:
  rejected because the picker is rq-locked scheduler hot path.

disabled branch or object growth without generated-object evidence:
  rejected because compatibility is not just source-level.
```

## Non-Claims

This gate does not approve:

```text
Linux code changes
runtime denial
CFS deny-and-repick implementation
hot-layout changes
disabled-overhead changes
runtime coverage
benchmark evidence
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
negative validation plan
implementation patch plan
```
