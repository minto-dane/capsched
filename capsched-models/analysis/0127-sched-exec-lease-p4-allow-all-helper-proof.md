# SchedExecLease P4 Allow-All Helper Proof

Date: 2026-07-02

Status: allow-all/no-denial helper proof contract complete; P4 implementation
still not applied.

## Purpose

N-170 closed static final-run observability. This note closes the remaining
pre-P4 design blocker:

```text
allow-all helper proof
no reachable denial path proof
```

This proof is deliberately split into two layers:

```text
current-tree source check:
  the current P3 tree contains no P4 validation call sites and the only private
  validation helper returns ALLOW.

future-P4 contract:
  any P4 production helper must return only ALLOW and must not make non-allow
  enum values reachable from scheduler control flow.
```

This is not a P4 implementation and does not approve Linux behavior changes.

## Current Source Basis

```text
linux_branch: capsched-linux-l0
linux_commit: d5f77adb5a64f3b2545db6ab1dcdc4aa4442bab3
upstream_commit: 87320be9f0d24fce67631b7eef919f0b79c3e45c
```

Current private validation vocabulary:

```c
enum sched_exec_validation_result {
        SCHED_EXEC_VALIDATION_ALLOW,
        SCHED_EXEC_VALIDATION_RETRY,
        SCHED_EXEC_VALIDATION_INELIGIBLE,
        SCHED_EXEC_VALIDATION_QUARANTINE,
};

static inline enum sched_exec_validation_result
sched_exec_allow_all_validation(void)
{
        return SCHED_EXEC_VALIDATION_ALLOW;
}
```

The non-allow enum values are shape only. They are not reachable P4 behavior.

## P4 Helper Contract

P4 may add production helper names such as:

```text
sched_exec_lease_validate_run_edge(...)
sched_exec_lease_validate_move_edge(...)
sched_exec_lease_validate_move_edge_locked(...)
```

But in P4, every production helper must satisfy:

```text
return set == { SCHED_EXEC_VALIDATION_ALLOW }
```

Forbidden in P4:

- returning `RETRY`;
- returning `INELIGIBLE`;
- returning `QUARANTINE`;
- branching scheduler control flow on non-allow results;
- marking tasks ineligible;
- queuing quarantine;
- retrying `pick_again`;
- idling or fail-closing the CPU;
- changing `rq->curr` commitment behavior;
- changing scheduler-class state;
- allocating;
- sleeping;
- taking new locks;
- charging budget;
- calling policy front ends;
- calling the monitor;
- adding ABI, tracepoint ABI, debugfs, procfs, sysfs, syscall, or ioctl
  surface.

Non-allow enum values may exist only as:

```text
type vocabulary
comments
model text
future P5 test-only code after separate approval
```

## Current-Tree Source Check

Machine-readable contract:

```text
analysis/sched-exec-lease-p4-allow-all-helper-proof-v1.json
```

Runner:

```text
validation/run-sched-exec-lease-p4-allow-all-helper-proof.sh
```

The runner checks:

- Linux work commit matches the contract;
- `sched_exec_allow_all_validation()` exists;
- its return statement is exactly `SCHED_EXEC_VALIDATION_ALLOW`;
- no current return statement returns `RETRY`, `INELIGIBLE`, or `QUARANTINE`;
- no P4 validate-run/move helper exists yet;
- no scheduler call site branches on a SchedExecLease validation result;
- no Linux patch, runtime denial, runtime coverage, monitor verification, or
  protection claim is made.

## Formal Gate

Formal model:

```text
formal/0096-p4-allow-all-helper-gate-model/
```

The model rejects:

- closing the proof without source check;
- production helper returning non-allow;
- non-allow result reachable from scheduler control flow;
- scheduler branching on validation result;
- retry/fail-closed/quarantine/ineligible behavior in P4;
- monitor call, budget charge, or ABI from P4 helper;
- implementation approval from helper proof alone;
- runtime coverage, protection, hypervisor-grade, cost, or deployment claims.

## Decision

The P4 allow-all/no-denial helper proof blocker is closed.

Remaining before applying a P4 patch:

1. write the actual P4 patch;
2. run generated-code/object review on the patch;
3. run off/on build validation;
4. run QEMU compatibility validation;
5. rerun overclaim/security-diff review for the actual patch.

P5 remains blocked by denial source shape, liveness/progress properties,
negative denial tests, path-classification enforcement, async exclusions, and
monitor non-forgeability.

## Non-Claims

This note does not approve Linux code, P4 implementation, runtime denial,
runtime coverage, ABI, monitor calls, monitor verification, production
protection, hypervisor-grade isolation, cost-efficiency, or deployment
readiness.
