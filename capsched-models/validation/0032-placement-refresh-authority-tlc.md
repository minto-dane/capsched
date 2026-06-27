# Validation 0032: Placement Refresh Authority TLC

Status: Completed bounded model check

Date: 2026-06-27

Model:

```text
capsched/capsched-models/formal/0020-placement-refresh-authority-model/PlacementRefreshAuthority.tla
```

Related analysis:

```text
capsched/capsched-models/analysis/0037-placement-refresh-affinity-hotplug-authority.md
```

TLC logs:

```text
/media/nia/scsiusb/dev/linux-cap/build/tlc/placement-refresh-authority-20260627T083526Z/PlacementRefreshAuthoritySafe.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/placement-refresh-authority-20260627T083526Z/PlacementRefreshAuthorityUnsafeRunStale.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/placement-refresh-authority-20260627T083526Z/PlacementRefreshAuthorityUnsafeSelected.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/placement-refresh-authority-20260627T083526Z/PlacementRefreshAuthorityUnsafeQueuedMove.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/placement-refresh-authority-20260627T083526Z/PlacementRefreshAuthorityUnsafeFallback.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/placement-refresh-authority-20260627T083526Z/PlacementRefreshAuthorityUnsafeInactive.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/placement-refresh-authority-20260627T083526Z/PlacementRefreshAuthorityUnsafeMigrationPending.log
```

## Result Summary

Safe configuration:

```text
config: PlacementRefreshAuthoritySafe.cfg
result: PASS
generated states: 13
distinct states: 10
search depth: 5
```

Unsafe configurations produced expected counterexamples:

```text
config: PlacementRefreshAuthorityUnsafeRunStale.cfg
target invariant: NoRunOutsideCurrentPlacement
result: expected FAIL
generated states before violation: 7
distinct states before violation: 7
depth: 4

config: PlacementRefreshAuthorityUnsafeSelected.cfg
target invariant: NoSelectedOutsideFrozenEnvelope
result: expected FAIL
generated states before violation: 4
distinct states before violation: 4
depth: 3

config: PlacementRefreshAuthorityUnsafeQueuedMove.cfg
target invariant: NoQueuedMoveOutsideFrozenEnvelope
result: expected FAIL
generated states before violation: 7
distinct states before violation: 7
depth: 4

config: PlacementRefreshAuthorityUnsafeFallback.cfg
target invariant: NoFallbackExpansionCreatesAuthority
result: expected FAIL
generated states before violation: 12
distinct states before violation: 10
depth: 5

config: PlacementRefreshAuthorityUnsafeInactive.cfg
target invariant: NoRunOnInactiveCpu
result: expected FAIL
generated states before violation: 10
distinct states before violation: 8
depth: 5

config: PlacementRefreshAuthorityUnsafeMigrationPending.cfg
target invariant: NoMigrationPendingRuns
result: expected FAIL
generated states before violation: 12
distinct states before violation: 10
depth: 5
```

## Validated Claims

This validation supports the following local design constraints:

```text
1. Running requires a live FrozenRunUse, fresh PlacementEpoch, CPU in the
   frozen envelope, CPU in current Linux effective placement, and live
   CapSched placement envelope.

2. A selected CPU is not authority. Selected state must remain inside the
   frozen envelope and current placement.

3. Queued migration and core-steal-like movement cannot carry an authority
   bearing task outside FrozenRunUse.allowed_cpus.

4. Linux cpuset/fallback/force-affinity repair cannot create CapSched
   execution authority.

5. Ordinary Domain execution cannot run on inactive CPUs.

6. A migration-pending or placement-invalid task must not continue as ordinary
   Domain execution until refreshed, migrated within envelope, or fail-closed.
```

## Unsafe Counterexample Meaning

`PlacementRefreshAuthorityUnsafeRunStale.cfg` demonstrates stale placement:

```text
Start -> Prepared -> FrozenQueued -> BadRunStalePlacement
```

The task runs after the current effective mask and placement epoch have become
stale.

`PlacementRefreshAuthorityUnsafeSelected.cfg` demonstrates treating a selected
CPU as authority without a frozen placement envelope:

```text
Start -> Prepared -> BadSelectedOutsideFrozen
```

`PlacementRefreshAuthorityUnsafeQueuedMove.cfg` demonstrates queued movement
outside the frozen envelope:

```text
Start -> Prepared -> FrozenQueued -> BadQueuedMoveOutsideFrozen
```

`PlacementRefreshAuthorityUnsafeFallback.cfg` demonstrates cpuset/fallback
expansion creating execution authority:

```text
Start -> Prepared -> FrozenQueued -> Invalidated -> BadFallbackExpansion
```

`PlacementRefreshAuthorityUnsafeInactive.cfg` demonstrates running on an
inactive CPU:

```text
Start -> Prepared -> FrozenQueued -> Selected -> BadRunInactiveCpu
```

`PlacementRefreshAuthorityUnsafeMigrationPending.cfg` demonstrates execution
while placement refresh/migration is pending:

```text
Start -> Prepared -> FrozenQueued -> Invalidated -> BadMigrationPendingRun
```

## Evidence Limits

This validation does not prove:

```text
all real cpumask combinations
exact cpuset hierarchy updates
all CPU hotplug ordering
all sched class select_task_rq() behavior
sched_ext BPF dispatch queue semantics
core scheduling cookie movement
migrate_disable continuation policy
monitor-backed CPU ownership
```

Those remain separate proof obligations.

## Design Consequence

Future CapSched placement logic must treat:

```text
selected CPU:
  hint

p->cpus_ptr:
  mutable Linux placement input

FrozenRunUse.allowed_cpus:
  frozen authority envelope

PlacementEpoch:
  freshness link between frozen authority, Linux effective placement, and
  CapSched policy
```

The safe implementation shape is to invalidate frozen placement on affinity,
cpuset, hotplug, SchedContext, or Domain placement changes and to revalidate
selected/queued/running candidates before execution.
