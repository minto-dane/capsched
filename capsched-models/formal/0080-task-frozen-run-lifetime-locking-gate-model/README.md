# Task FrozenRun Lifetime and Locking Gate Model

Status: Checked with safe pass and expected unsafe counterexamples

Date: 2026-07-01

## Purpose

This model fixes the minimum task-lifetime and scheduler-locking semantics
that a future `FrozenRunUse` or denied-candidate reference must satisfy.

The rule is:

```text
raw task pointer or RCU-only visibility is not runnable authority.
Frozen task identity can be consumed only while the task is still live,
generation-fresh, not migrating, not released, and stabilized by either a
task reference or the appropriate rq/pi locking context.
```

## Safe Paths

The safe model covers:

```text
acquire stable lifetime -> freeze candidate -> commit run -> release
acquire stable lifetime -> freeze candidate -> deny/retry-safe -> release
acquire stable lifetime -> freeze candidate -> task exit invalidates -> fail closed -> release
acquire stable lifetime -> freeze candidate -> move with rq lock -> release
```

## Rejected Behaviors

Unsafe configs reject:

```text
run after task free/exit invalidation
run without stable lifetime
RCU-only authority
raw pointer authority
run while TASK_ON_RQ_MIGRATING-equivalent state is active
stale generation run
use after release
release before denial/retry/fail-closed settlement
double release
terminal reference or lock leak
queued move without rq lock
retry without stable denied-candidate lifetime
ignored exit invalidation
behavior, monitor-verification, or protection overclaims
```

## Non-Claims

This model does not approve a Linux hook, task field, storage layout,
refcounting mechanism, locking protocol, scheduler behavior change, public ABI,
runtime coverage, monitor ABI, monitor verification, or production protection.

## TLC Result

Safe TLC passed with:

```text
20 generated states
12 distinct states
depth 6
```

Unsafe configs produced 16 expected invariant violations.
