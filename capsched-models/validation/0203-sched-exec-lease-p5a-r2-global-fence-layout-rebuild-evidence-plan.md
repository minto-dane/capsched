# Validation 0203: SchedExecLease P5A-R2 Global-Fence Layout/Rebuild Evidence Plan

Date: 2026-07-13

Status: passed for implementation-evidence planning only. No Linux patch, hot
field, rebuild prototype, runtime behavior, protection, or performance claim
is approved.

## Scope

Validate:

```text
analysis/0157-sched-exec-lease-p5a-r2-global-fence-layout-rebuild-evidence-plan.md
analysis/sched-exec-lease-p5a-r2-global-fence-layout-rebuild-evidence-plan-v1.json
formal/0124-p5a-r2-global-fence-layout-rebuild-evidence-plan-model/
validation/run-sched-exec-lease-p5a-r2-global-fence-layout-rebuild-evidence-plan.sh
```

## Run

```text
RUN_ID=20260713T-p5a-r2-global-fence-layout-rebuild-plan \
  validation/run-sched-exec-lease-p5a-r2-global-fence-layout-rebuild-evidence-plan.sh
```

Result:

```text
status: passed_evidence_plan_only
linux_commit: 077c948be39432971e7273b16b728172251129aa
linux_tree: 7ef04bf73d26b2813b10016b7eb342a618a66570
source anchors: 24
source anchor failures: 0
future absence checks: 6
future absence check failures: 0
safe TLC: 6 generated states, 5 distinct states, depth 5
unsafe expected counterexamples: 32
```

Output:

```text
build/source-check/sched-exec-lease-p5a-r2-global-fence-layout-rebuild-evidence-plan/
  20260713T-p5a-r2-global-fence-layout-rebuild-plan/result.json
```

## Layout Rejection Envelope

The future disposable candidate is bounded separately on x86_64 and arm64:

```text
sched_entity growth: at most 8 bytes
cfs_rq growth: exactly 0 bytes
rq growth: at most 32 bytes
task_struct growth: exactly 0 bytes
```

Existing offsets for `sched_entity.run_node`, `min_vruntime`, `rq.nr_running`,
`rq.curr`, `rq.cfs`, `rq.clock_task`, and `task_struct.sched_exec` must remain
unchanged. Candidate rq fields must not shift the dedicated first hot
cacheline or `rq.cfs`.

Exceeding an envelope rejects the candidate. It is not handled by explanatory
text after the fact.

## Rebuild Correctness Gate

A future default-off test-only rebuild must match a brute-force wrap-aware
oracle across tree/current/group and publication-race cases. It must source-
prove child-before-parent rb traversal and bottom-up cfs_rq traversal.

Unbounded recursive hierarchy traversal, allocation, sleep, monitor/policy
calls, tree mutation, and partial/raced Fresh publication are forbidden.

## Lock-Hold Rejection Gate

The measurement matrix covers runnable counts:

```text
0, 1, 8, 64, 256, 1024, 4096
```

and hierarchy depths:

```text
0, 1, 4, 16, 64
```

Against the current 700 microsecond base slice, full locked rebuild is
reviewable only when every required combination satisfies:

```text
p99 additional irq-disabled rq-lock hold <= 25 microseconds
raw maximum additional irq-disabled rq-lock hold <= 50 microseconds
no sample reaches one base slice
no lockdep, irqsoff, RCU-stall, soft-lockup, or hard-lockup warning
```

Failure rejects full O(n) rq-locked rebuild and requires a separately modeled
chunked, bucket-local, or targeted-index design. Passing is only a rejection
gate; it does not establish a performance or cost claim.

## Non-Claims

This validation does not approve:

```text
Linux code changes
new hot fields
layout-only candidate
rebuild prototype
full rebuild performance
runtime denial correctness or coverage
cross-path correctness
monitor delivery or enforcement
production protection
latency, performance, energy, or cost efficiency
deployment or datacenter readiness
```

## Next

Extract the structured arm64 0013 layout table from the completed
`20260713T140445Z` probe build, then define an expanded probe patch plan.
