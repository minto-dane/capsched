# Analysis 0027: Schema v2 Derived from the Scheduler Authority Model

Status: Draft schema and v2 retagging complete for gap analysis

Date: 2026-06-27

## Purpose

This note records the first schema v2 derivation after ADR-0006, analysis/0025,
and analysis/0026.

The key correction is:

```text
schema v2 is not a design engine
schema v2 is an evidence, constraint, and proof-obligation index
```

The accompanying machine-readable artifacts are:

```text
analysis/behavior-tags/schema-v2.json
analysis/behavior-tags/slice0c-scheduler-behavior-tags-v2.json
```

## Inputs

The schema is derived from:

```text
ADR-0006:
  invariant-driven design, tag-indexed evidence

analysis/0024:
  tags index evidence and constraints, not design truth

analysis/0025:
  Linux scheduler authority state machine

analysis/0026:
  scheduler hook proof obligation matrix

analysis/behavior-tags/schema-v2-requirements.json:
  critical-review requirements
```

## What Changed from v1

The v1 ledger is exploratory only. It mixed:

```text
observation
authority semantics
security obligations
cost
benefit
implementation strategy
```

Schema v2 separates those concerns and requires each record to declare:

```text
claim boundary
authority transition
invariant references
trust and mutability
failure and revocation semantics
Linux scheduler context
evidence
performance/cost dimensions
cluster authority locality
proof obligations
solver use restrictions
```

## Solver Boundary

The current v2 artifacts allow:

```text
gap analysis
hard rejection
evidence indexing
proof-obligation generation
claim/evidence mismatch detection
```

They do not allow:

```text
security declaration
production claim satisfaction
automatic hook selection
weighted safety scoring
L0 observation promotion into CapSched-H proof
```

The Slice 0C v2 ledger is therefore marked:

```text
solver_use: gap_analysis_and_hard_reject_only
hook_selection_eligible: false
```

## Derived Record Kinds

Schema v2 has four first-class record kinds:

```text
invariant
behavior_path
hook_role
proof_obligation
```

Future records may add:

```text
hook_candidate
candidate_set
validation_result
performance_measurement
assurance_link
```

But hook candidates should not be selected until behavior paths and hook roles
are retagged under v2.

## Immediate Retagging Result

The Slice 0C v2 ledger now covers:

```text
current self-wake
already-runnable wake
normal wake admission
remote pending wake
new task wake
queued migration
generic enqueue custody
pick
switch activation
budget charge placeholder
exit placeholder
```

The retagging intentionally keeps several records ineligible for enforcement
selection because required proof obligations remain open.

Important open gaps:

```text
tick/runtime budget charge source map
RT and deadline scheduler class state
sched_ext custody/fallback state
core scheduling cached pick and forced-idle state
proxy execution state
fork/clone/exec/exit identity propagation
remote-pending revoke model
selected/running revoke model
monitor activation failure action
same-Domain fast path freshness
```

## Immediate Consequence

The next formal step is no longer "pick a hook".

The next formal step is:

```text
LinuxSchedulerAuthority model
```

Minimum model extensions over existing RunnableLease:

```text
RemotePendingWake
SelectedUse
CurrentContinuation
QueuedMigration
SpawnedInitialUse
failure before TASK_WAKING
failure after TASK_WAKING forbidden without rollback
switch activation fail-closed action
revocation over queued, selected, running, and remote-pending states
```

The next source-analysis step is:

```text
tick/runtime budget source map
fork/clone/exec/exit identity propagation map
```

Those are prerequisites before any behavior-changing runnable authority patch.
