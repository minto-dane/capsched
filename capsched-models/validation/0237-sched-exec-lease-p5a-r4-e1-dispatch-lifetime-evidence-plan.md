# Validation 0237: SchedExecLease P5A-R4 E1 Dispatch and Lifetime Evidence Plan

Date: 2026-07-16

Status: passed plan-only gate. An exact disposable, default-off R4-E2 two-file
layout candidate may be drafted. No R4 behavior source is approved.

## Canonical Run

```bash
RUN_ID=20260716T-p5a-r4-e1-dispatch-lifetime-plan-r1
PROGRESS_FILE=build/long-jobs/p5a-r4-e1-plan/progress
container machine run -n domainlease-dev \
  --workdir /Users/niania/Documents/linux-cap \
  env RUN_ID="$RUN_ID" PROGRESS_FILE="$PWD/$PROGRESS_FILE" \
  ./capsched/capsched-models/validation/\
run-sched-exec-lease-p5a-r4-e1-dispatch-lifetime-evidence-plan.sh
```

Canonical result:

```text
build/source-check/
  sched-exec-lease-p5a-r4-e1-dispatch-lifetime-evidence-plan/
  20260716T-p5a-r4-e1-dispatch-lifetime-plan-r1/result.json
SHA-256 2710cea3ed5a8b2838b80b734a94878ed978c40e3e20daa0529ad359c6aa7bca
```

The macOS host has no Java runtime, so the finite TLC run executed in the
existing Apple Container Linux machine. The runner, inputs, mounted workspace,
run ID, and result path were unchanged.

## Input and Source Closure

The gate revalidated:

```text
R4 architecture result SHA-256:
  388e4f41651cf42518aa273e32721aa62ca91d3dd286e88d2060b8dd7fc699b4
primary Linux commit:
  5e1ca3037e34823d1ba0cdd1dc04161fac170280
primary Linux tree:
  54f685aad94f28f0027cbba18cf5e29aadce234a
patch queue commit:
  16bb080da472ffabbbafd2698073eca633fb0602
```

All 42 Linux anchors passed and all eight future R4 layout/runtime names were
absent. The anchors establish that balance callbacks execute with the rq lock,
`irq_work` coalesces one pending item and can bridge to ordinary work, MM CID
uses exactly that bridge to avoid wakeup nesting under rq lock, unbound work
survives target-CPU death, cancel/sync require racing enqueues to stop, CPUHP
ONLINE callbacks are sleepable, fair online/offline seams are rq-locked, and
current rescheduling requires the rq lock.

The runner also compared the CPUHP enum line order and proved
`WORKQUEUE_ONLINE < ONLINE_DYN < AP_ACTIVE`. Because teardown is reverse order,
fair disarm occurs before the R4 dynamic drain, and workqueue offlining occurs
after the drain.

## Fixed Engineering Boundary

The result freezes:

```text
B_max                                      64 projections/rq
one rq recovery owner                      exact
one rq irq-work bridge                     exact
one notifier owner/active bucket           exact
private active storage                     62016 bytes/rq
hard private storage limit                 65536 bytes/rq
ordinary sched_entity/cfs_rq/rq/task delta 0 bytes
R4-E2 file scope                           init/Kconfig
                                             kernel/sched/exec_lease.c
```

`queue_balance_callback()` is explicitly rejected as a post-lock seam.
The selected path records durable dirty/latest-generation state under rq lock
with IRQs disabled, queues one hard irq-work item, unconditionally queues one
unbound recovery work item from the dispatch-only irq callback, and repairs
one projection per later rq-lock quantum.

The notifier visits one projection per invocation using a CPU cursor. A final
generation or membership-sequence change restarts the pass through a
publisher/clear handshake; late admission self-handshakes and kicks. Under the
stable-window assumptions the visit bound is at most `2*A`, and remains a
logical count rather than a wall-clock statement.

Hotplug is fixed as rq-locked accepting/disarm first, followed by sleepable
`irq_work_sync()`, `cancel_work_sync()`, reference settlement, and RCU drain.
Current stop request plus later scheduler observation remains separate from
picker trust and from monitor receipt.

## Formal Result

Safe TLC completed with:

```text
21 states generated
20 distinct states
depth 20
0 states left on queue
3 temporal properties checked
```

The trace covered duplicate rq-locked kicks, publication while irq-work was
pending, post-lock irq-to-work dispatch, newest-generation recovery, a partial
old notifier pass followed by a final-generation restart, stop requests on
both current rqs, and ordered offline drain.

All 60 unsafe fault configurations produced their expected invariant
counterexamples. These include unbounded admission/storage, ordinary hot
growth, balance-callback misuse, missing irq bridge/coalescing, queue-owner
loss, multi-projection recovery, cursor/restart and admission handshake gaps,
resched-as-receipt overclaim, migration double contribution, sleepable drain
under rq lock, cancel with racing enqueue, lost residual refs, missing RCU,
restored global settlement, and every behavior/protection/performance claim.

## Decision

```text
R4-E2 disposable worktree: allowed
R4-E2 exact default-off two-file layout draft: allowed
R4-E3 source: blocked on dual-architecture E2 closure and a new plan
R4-E4 source: blocked on E3 correctness and a new plan
R4 behavior source: blocked
primary Linux or patch queue change: blocked
```

This validation does not establish runtime behavior, task admission, denial
correctness, current-stop latency, monitor enforcement, production protection,
performance, cost, deployment, or datacenter readiness.
