# Validation 0219: SchedExecLease P5A-R3 Bucket-Local Targeted Projection

Date: 2026-07-15

Status: passed as a successor architecture gate only. R3-E1 evidence-plan
drafting is allowed; disposable Linux source and behavior remain unapproved.

## Scope

Validate that P5A-R3 reacts to the exact E4 rejection without reviving an
all-leaf locked rebuild, and that the selected bucket-local design records the
authority-equivalence key, active-rq membership index, publication/insertion
handshake, lock ordering, one-bucket work bound, migration settlement, picker
fence, lifetime, source boundary, and non-claims.

## Runner

```text
capsched-models/validation/
  run-sched-exec-lease-p5a-r3-bucket-local-targeted-projection.sh
```

## Result

Run `20260715T-p5a-r3-bucket-local-plan-r2` passed:

```text
primary Linux commit:       5e1ca3037e34823d1ba0cdd1dc04161fac170280
primary Linux tree:         54f685aad94f28f0027cbba18cf5e29aadce234a
canonical E4 result SHA:    21cad0c9d6923e3e6a42749c315aca150126424ca14dd717c868e80eeba9bccc
source anchors:             20/20
future implementation absent: 6/6
safe TLC states:            16 generated, 14 distinct, depth 10
unsafe expected results:    34/34 counterexamples
selected successor:         bucket_local_targeted_projection
```

Result:
`build/source-check/sched-exec-lease-p5a-r3-bucket-local-targeted-projection/20260715T-p5a-r3-bucket-local-plan-r2/result.json`.

Result SHA-256:
`250f35d8756378d7cf17a032a2a6734818e6291f317f335b4af01b15d1dc55ba`.

The gate mechanically rechecked that the canonical E4 result is a complete
arm64 `rejected_full_locked_rebuild` measurement with 35 rows, 10,000 pairs
per cell, 36 threshold breaches, QEMU exit zero, KUnit pass, warning count
zero, valid negative-evidence classification, and x86_64 launch false.

## Counterexample-Driven Correction

The first safe-model authoring run found a real protocol omission: a shared
republish racing an in-flight worker reused the earlier active-rq snapshot, so
an rq that joined after that snapshot was not covered by the newer generation.

The accepted model and analysis now require every generation publication to
take a fresh active-rq snapshot under the membership lock and acquire work
references for that snapshot before unlock. The safe graph then passed, and
the 34 fault configurations all produced the expected `Safety` violation. No
failed-run rows or states are merged into the accepted result.

## Accepted Architecture Boundary

The accepted direction is:

```text
one authority-equivalent execution bucket
one non-wrapping generation/state per bucket
preallocated per-CPU projections
per-rq runnable/current contribution refcounts
target only active rqs
enqueue before snapshot is selected
enqueue after snapshot observes the new generation
one bucket projection update per rq-lock acquisition
no leaf scan, hierarchy rebuild, all-bucket loop, allocation, sleep,
monitor call, or policy call in the update interval
```

Publisher lock order is bucket-membership-only during publication/snapshot;
it releases that lock before queueing work and never acquires an rq lock while
holding it. Mutation order is rq lock followed by at most one bucket lock.
Migration removes the old contribution, crosses a neutral interval, and only
then publishes the destination contribution using the latest generation.

## Implementation Decision

Validation permits only the R3-E1 exact source/locking/lifetime/finite-`B_max`
evidence plan. That next plan must narrow file scope and prove CPU-hotplug,
callback drain, layout, configuration-off absence, one outer layer, finite
bucket admission, cross-path exclusions, and future measurement rejection
limits before any disposable source exists.

The gate does not approve a Linux change, the rejected E2/E3/E4 fields,
chunked full rebuild, targeted task-list walk, production cgroup binding,
runtime denial, monitor delivery/enforcement, cross-class coverage, bounded
latency, performance, cost, protection, deployment, or datacenter readiness.
