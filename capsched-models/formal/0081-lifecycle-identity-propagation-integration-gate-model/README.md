# Lifecycle Identity Propagation Integration Gate Model

Status: Checked with safe pass and expected unsafe counterexamples

Date: 2026-07-01

## Purpose

This model integrates fork/clone, exec, and exit identity propagation with the
recent scheduler authority gates.

The rule is:

```text
fork/clone must create a SpawnCap-derived child identity before wake publication
exec must preserve ordinary Domain identity while requiring ExecContinuation
exit must invalidate task identity before any stale selected/queued use can run
```

Linux clone flags, PID/TGID reuse, raw task reuse, `sched_exec()` placement, and
task release state are not CapSched authority.

## Safe Paths

The safe model covers:

```text
same-Domain process spawn -> child first run
same-Domain thread clone -> child first run with shared process generation
new-Domain spawn with monitor token -> child first run
exec check-only path with no mutation
successful exec -> current task continues only via ExecContinuation
exit invalidation -> release settlement
```

## Rejected Behaviors

Unsafe configs reject:

```text
child run without SpawnCap
child run without fresh task generation
process clone without fresh process generation
ambient RunCap inheritance
FrozenRunUse inheritance
RunToken inheritance
unbound child SchedContext
wake before identity preparation
new Domain clone without monitor token
clone flags as Domain authority
exec Domain change without token
post-exec run without ExecContinuation
check-only exec mutating generation
old FrozenRunUse after exec
run after exit invalidation
PID/TGID reuse as task identity authority
release state as authority
behavior, monitor-verification, or protection overclaims
```

## Non-Claims

This model does not approve Linux fork, exec, exit, scheduler, task-field,
public ABI, monitor ABI, runtime coverage, behavior change, monitor
verification, or production protection changes.

## TLC Result

Safe TLC passed with:

```text
19 generated states
13 distinct states
depth 4
```

Unsafe configs produced 20 expected invariant violations.
