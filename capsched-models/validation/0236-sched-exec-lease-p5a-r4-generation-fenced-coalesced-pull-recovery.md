# Validation 0236: SchedExecLease P5A-R4 Generation-Fenced Coalesced Pull Recovery

Date: 2026-07-16

Status: passed architecture/formal gate. An R4-E1 evidence plan may be drafted.
Linux source, runtime behavior, and all production claims remain unapproved.

## Run

```text
RUN_ID=20260716T-p5a-r4-generation-fenced-coalesced-pull-recovery-r1
./capsched/capsched-models/validation/
  run-sched-exec-lease-p5a-r4-generation-fenced-coalesced-pull-recovery.sh
```

Canonical result:

```text
build/source-check/
  sched-exec-lease-p5a-r4-generation-fenced-coalesced-pull-recovery/
  20260716T-p5a-r4-generation-fenced-coalesced-pull-recovery-r1/result.json
SHA-256: 388e4f41651cf42518aa273e32721aa62ca91d3dd286e88d2060b8dd7fc699b4
status: passed_generation_fenced_coalesced_pull_recovery_architecture_only
```

## Exact predecessor gate

The runner rehashed the complete R3 arm64 result to
`edba124b804beeaa7a2d723027fa3a6345f2d546fb0ab861428c6a4727b5cb7b`
and rechecked its exact candidate/tree, 42 rows, 10,000 measured pairs per
cell, 19 rejected cells, 26 threshold breaches, zero warnings, clean QEMU exit,
passing KUnit, valid negative-evidence classification, and x86_64/E5 stop.

The R4 input contract explicitly records that R3 generation mismatch already
prevented picker trust and its fanout experiment was availability-only. This
corrects the earlier shorthand that called settlement a publication-authority
condition; no R3 evidence or threshold was changed.

## Source boundary

Primary Linux remained exact at commit
`5e1ca3037e34823d1ba0cdd1dc04161fac170280`, tree
`54f685aad94f28f0027cbba18cf5e29aadce234a`, with a clean tracked working
tree. All 16 source anchors passed and all six future R4 names were absent.

The anchors cover rq-locked `resched_curr()` and remote reschedule delivery,
workqueue pending-bit coalescing and return semantics, irq-work single-pending
and offline-flush constraints, and fair rq online/offline callbacks. They prove
that current Linux has candidate mechanisms only; no R4 storage, dispatch,
coalescing, lifetime, or behavior exists.

## Formal result

The safe TLC configuration checked `TypeOK`, `Safety`,
`EligibleStableRecovery`, and `RevokedStableRecovery`:

```text
states generated: 16
distinct states:  15
depth:            15
liveness branches checked: 2
errors:           0
```

The trace covers an eligible generation mismatch, a partial old-generation
notifier pass, a repeated publication that coalesces to the newest generation,
completion and restart of the notifier cursor, one notifier and one owner per
rq, bounded one-projection repair, an ineligible publication, separate current
stop-request delivery, and final Blocked settlement. The stable trace takes
three notifier quanta for two active rqs and therefore exercises the `2*A`
restart bound. Both temporal properties rely on the model's explicit
stable-window and weak-fairness assumptions.

All 47 unsafe fault configurations produced the expected invariant
counterexample. They include:

- missing or reinterpreted R3 rejection evidence;
- O(n), rq-locking, or waiting work in the authority publication section;
- generation reuse, duplicate notifier/owner/kick, or lost newest generation;
- picker trust of mismatch, picker repair, or an unmapped locked dispatch;
- publication-count queue growth, multi-projection rq-lock work, or Fresh
  publication without a final generation check;
- restoration of synchronous/global last-settlement acceptance;
- missing stable-window/fairness/finite bounds or wall-clock/unconditional
  liveness overclaims;
- conflation of picker trust with current execution, unlocked reschedule, or
  Linux reschedule mislabeled as a monitor receipt;
- enqueue, migration, hotplug, lifetime, and RCU omissions; and
- Linux-source, behavior, protection, performance, and cost overclaims.

## Accepted decision

The gate selects R4 Generation-Fenced Coalesced Pull Recovery:

- an O(1) authority-publication critical section release-publishes state and
  generation and queues at most one notifier;
- an O(1) picker mismatch fails closed and records an idempotent pull kick;
- repeated publications update the newest desired generation without growing
  notifier, rq-owner, or projection-node depth;
- notifier work visits the stable active/current set in at most `2*A` logical
  quanta after the final publication;
- each rq settles its stable dirty set in at most `B_max` one-projection
  recovery quanta; and
- current stop-request delivery is separate from projection recovery and does
  not claim instantaneous or monitor-backed revoke completion.

The bounds are deterministic logical work bounds, not latency measurements.
Under infinite publication, safety and bounded queue depth remain required but
availability may remain fail-closed.

## Next and non-claims

Only an R4-E1 no-source evidence plan is now allowed. It must fix storage and
admission bounds, an exact post-rq-lock dispatch seam, notifier cursor/restart,
one-owner coalescing, hotplug/lifetime drain, current stop-request observation,
and safe/unsafe diagnostic requirements before any disposable source draft.

Primary Linux, patch queue, R3 promotion, R4 source, live behavior, runtime
denial, cross-path coverage, monitor enforcement, protection, wall-clock
latency, performance, cost, deployment, and datacenter readiness remain false.
