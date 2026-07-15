# Formal 0133: P5A-R3 E3 Bucket Concurrency Evidence Plan

Date: 2026-07-15

Status: pre-source plan model. A safe pass plus every expected unsafe
counterexample authorizes only creation of the exact disposable two-file E3
draft.

The state machine follows allocation, rq online, boundary admission,
publication, running-worker republish, settlement, remove-neutral-add
destination rejection, detach, offline, retirement, work drain, RCU-reader
drain, and free. `StateSafety` requires capacity and allocation before a
contribution, exact active membership, live work ownership while pending or
running or behind desired generation, neutral migration, offline admission
closure, retirement unpublication, complete reference/work drain, and RCU
quiescence before free.

`PlanContract` fixes the exact E2 closure and direct-child/two-file future
boundary; preservation of all layout probes; default-off same-TU KUnit
isolation; finite B_max and complete allocation rollback; rq-to-one-membership
locking; publisher/worker ownership and coalescing; migration, hotplug,
retirement, cancel, and RCU ordering; independent oracle; deterministic cases;
the full arm64/x86_64 KUnit/KASAN/KCSAN/lockdep/work-debug/RCU matrix; and all
runtime, E4, cross-path, and production non-claims.

Fifty-one unsafe fault values each remove one indispensable condition and must
produce an expected `Safety` counterexample.
