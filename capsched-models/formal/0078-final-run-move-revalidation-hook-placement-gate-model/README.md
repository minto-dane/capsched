# Final Run/Move Revalidation Hook Placement Gate Model

Status: Checked with safe pass and expected unsafe counterexamples

Date: 2026-07-01

## Purpose

This model checks that ordinary Domain execution and queued-task movement
consume a fresh validation tuple at the final commitment edge.

It models:

```text
Domain/SchedContext/RunCap grant provenance
task generation
Domain epoch
SchedContext epoch
RunCap epoch
move sequence
core scheduling cached-pick sequence
sched_ext DSQ/custody sequence
fresh allowed CPU set
run versus move tuple kind
edge kind
pending migration
Linux selected/move machinery as non-authority
```

## Safe Path

The safe path reaches both a move and a run:

```text
IssueAuthority
  -> PrepareMoveTuple
  -> CommitMove
  -> PrepareRunTuple
  -> CommitRun
```

The model also allows tuple invalidation between validation and commit. After
invalidation, the task either revalidates from actual authority or fails closed
when no fresh CPU intersection remains.

## Key Rule

```text
CommitRun consumes a Run tuple.
CommitMove consumes a Move tuple.
The consumed tuple must exactly match current generation, epochs, move/core/scx
sequences, edge kind, CPU, fresh allowed set, and no-pending-migration state.
```

A move tuple cannot run a task. A run tuple cannot authorize a queued move.

## Rejected Substitutions

Unsafe configs reject:

```text
run or move without tuple consumption
stale task generation
stale Domain epoch
stale SchedContext epoch
stale RunCap epoch
stale move sequence
stale core scheduling sequence
stale sched_ext sequence
run/move outside the fresh CPU set
run/move while migration is pending
run with an empty actual CPU intersection
run tuple used for move
move tuple used for run
edge mismatch
hook after rq->curr commit
Linux pick/move/balance/dispatch/hotplug/migration machinery as authority
Linux exception authority for ordinary Domain tasks
Linux hook approval, behavior change, monitor verification, or protection
overclaims
```

## Run

```sh
java -cp /home/nia/tools/tla/tla2tools.jar \
  tlc2.TLC \
  -config FinalRunMoveRevalidationHookPlacementGateSafe.cfg \
  FinalRunMoveRevalidationHookPlacementGate.tla
```

Use a distinct `-metadir` for bulk unsafe runs to avoid TLC state-directory
collisions.

## Non-Claims

This model does not approve Linux hooks, task fields, a public ABI, a monitor
ABI, runtime coverage, behavior change, monitor implementation, monitor
verification, or production protection.
