# Validation 0220: SchedExecLease P5A-R3 E1 Source, Locking, and Lifetime Evidence Plan

Date: 2026-07-15

Status: passed for creating only the exact disposable R3-E2 two-file layout
draft. No behavior or primary source is approved.

## Scope

Validate:

```text
analysis/0167-sched-exec-lease-p5a-r3-e1-source-locking-lifetime-evidence-plan.md
analysis/sched-exec-lease-p5a-r3-e1-source-locking-lifetime-evidence-plan-v1.json
formal/0132-p5a-r3-e1-source-locking-lifetime-evidence-plan-model/
validation/run-sched-exec-lease-p5a-r3-e1-source-locking-lifetime-evidence-plan.sh
```

The runner rechecks the exact primary Linux and patch-queue identities, hashes
the accepted R3 architecture result, validates all machine constraints, checks
38 current source anchors and 8 future absences, then runs the safe model and
all 36 fault configurations.

## Fixed Boundaries

```text
B_max per rq:                       64
outer feature layers:               1
maximum outer rb height:            12
private active memory budget/rq:    64 KiB
ordinary hot-structure growth:      0 bytes
E2 files:                           init/Kconfig, kernel/sched/exec_lease.c
```

Work is unbound and owns one coalesced reference per projection. Hotplug uses
the fair rq-online/offline callbacks under the existing rq lock. Retirement
stops queueing before `cancel_work_sync()`, drains all work/ref state, and waits
for RCU before free.

## Result

Canonical run:

```text
RUN_ID=20260715T-p5a-r3-e1-plan-r2
status=passed_r3_e1_plan_only
Linux commit/tree=5e1ca3037e348/54f685aad94f
patch queue=2a022dce5467
R3 predecessor result SHA-256=250f35d8756378d7cf17a032a2a6734818e6291f317f335b4af01b15d1dc55ba
source anchors=38, failures=0
future absences=8, failures=0
safe TLC=12 generated, 11 distinct, depth 11
unsafe expected counterexamples=36/36
result SHA-256=bc6f5bca4fb3c6d94bc8cdf129d399dfebf9b723bc18d8bd4f9727bd44d6b692
```

Output:

```text
build/source-check/sched-exec-lease-p5a-r3-e1-source-locking-lifetime-evidence-plan/
  20260715T-p5a-r3-e1-plan-r2/result.json
```

Re-executing the runner with the same RUN_ID produced the same result SHA-256.

## Authorization

The pass authorizes a disposable direct child of the primary commit changing
exactly:

```text
init/Kconfig
kernel/sched/exec_lease.c
```

It may contain only default-off private layout/probe definitions. It must keep
all four ordinary scheduler structure deltas at zero and preserve all 51
existing expanded-probe values independently on arm64 and x86_64.

## Claim Boundary

Even after a pass, R3-E3/R3-E4 source, scheduler behavior, primary Linux or
patch-queue changes, runtime denial, monitor enforcement, protection,
performance/cost, deployment, and datacenter claims remain unapproved.
