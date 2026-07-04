# P5A-R2 Invalidation Source Map Model

This model checks that the P5A-R2 invalidation source map covers the event
families that can make a future picker-visible lease summary stale.

It is not a Linux behavior proof and does not approve a patch. It only allows
the map to become `MapReady` when lifecycle, placement, migration, cgroup,
cpuset, budget, current-entity, group-summary, future monitor receipt, and
locking boundaries are all recorded while all runtime/protection/cost claims
remain false.
