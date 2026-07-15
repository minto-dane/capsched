# Validation 0224: SchedExecLease P5A-R3 E3 Bucket Concurrency Evidence Plan

Date: 2026-07-15

Status: passed for creating only the exact disposable R3-E3 two-file source
draft. E3 source and concurrency correctness remain unaccepted.

## Scope

The gate validates:

```text
analysis/0168-sched-exec-lease-p5a-r3-e3-bucket-concurrency-evidence-plan.md
analysis/sched-exec-lease-p5a-r3-e3-bucket-concurrency-evidence-plan-v1.json
formal/0133-p5a-r3-e3-bucket-concurrency-evidence-plan-model/
validation/run-sched-exec-lease-p5a-r3-e3-bucket-concurrency-evidence-plan.sh
```

It binds exact E2 closure and dual-architecture result hashes, the exact
primary/E2 candidate/parent/tree/diff identities, the patch-queue commit and
series blob, and 25 goal-relevant E2 working files re-hashed against HEAD.

## Fixed Future Boundary

```text
parent:    63313b329e1d44901acfce30698613c38615c8d5
worktree:  build/DomainLeaseLinux.volume/worktrees/
             p5a-r3-e3-bucket-concurrency-prototype
branch:    codex/p5a-r3-e3-bucket-concurrency-prototype
files:     init/Kconfig, kernel/sched/exec_lease.c
config:    CONFIG_SCHED_EXEC_LEASE_BUCKET_KUNIT_TEST, default n
suite:     sched_exec_lease_bucket
```

The test stays in `exec_lease.c`, uses the actual E2-private types, and may not
edit any header, Makefile, `sched.h`, `fair.c`, `core.c`, or existing layout
probe. All 51 ordinary and 43 private layout values must remain unchanged and
all four ordinary scheduler structure deltas must remain zero.

## Fixed Correctness Matrix

The contract requires:

```text
B_max cases:                       0, 1, 63, 64, rejected 65
pre-runnable allocation sites:     6
deterministic case families:      20
stress iterations/diagnostic:   1024
race timeout:                       5 seconds
architectures:                  arm64, x86_64
fresh build modes/architecture:    4
QEMU diagnostic boots:             4
```

The forced schedules cover publication before/after contribution, rapid
republish, worker-clear/republish, queue false while pending/running,
generation saturation, queued/delayed/current accounting, active-bit edges,
remove-neutral-add migration including destination failure, online/offline
races, retirement against publisher/worker/dequeue/RCU readers, all cancel
states, and every named allocation failure.

The future source matrix requires exact-suite KUnit on arm64 and x86_64,
arm64 generic KASAN, x86_64 KCSAN, lockdep, DEBUG_OBJECTS_WORK, and PROVE_RCU.
Any failed, skipped, or timed-out required case or any sanitizer, lock, refcount,
workqueue, RCU, warning, BUG, or lockup report rejects the draft.

## Canonical Result

Run `20260715T-p5a-r3-e3-plan` passed:

```text
E2 closure SHA-256:       d9b63a3efd0fd6b60223190418b3baacc3c0ac2d275fd99aa594d1fe6c18efba
E2 dual-arch SHA-256:     48a4a0f358896f0e552173f5e308970ef14dc83a58beef62caaed03e360e7038
source manifest:          25/25 HEAD blobs
source anchors:           58, failures 0
future absences:          10, failures 0
safe TLC:                 17 generated, 16 distinct, depth 16
unsafe counterexamples:   51/51
result SHA-256:           438496a960e566a3cfc2972c226072099b501de0b000378eef130aaca73aa24d
```

Output:

```text
build/source-check/sched-exec-lease-p5a-r3-e3-bucket-concurrency-evidence-plan/
  20260715T-p5a-r3-e3-plan/result.json
```

## Authorization

The pass authorizes creation of only the exact disposable direct-E2-child
worktree and two-file source draft. It does not accept source correctness or
authorize R3-E4 planning.

Primary Linux, patch queue, runtime scheduler hooks, picker/publisher/hotplug
integration, runtime behavior or denial, monitor delivery/enforcement,
cross-class coverage, bounded latency, performance, cost, production
protection, deployment, and datacenter readiness remain unapproved.
