# ADR-0011: Design-Ready Scope Before Next Linux Implementation

Status: Accepted

Date: 2026-07-02

## Context

After the SchedExecLease P2 task identity shadow was implemented and
validated, the next obvious step would be P3 scheduler touch points.

However, the current project objective has been narrowed:

```text
implementation-ready design only
actual implementation is out of scope for this phase
```

This matters because even no-op scheduler touch points are still Linux code
changes. They can create misleading momentum, stale anchors, or accidental
claims that the project has begun enforcement. The long-horizon security goal
remains strong, but this phase should not blur design readiness with Linux
implementation.

## Decision

Do not add new Linux implementation patches in the current scope.

The current scope is:

```text
source-verified design
threat/proof-obligation refinement
hook-placement review
validation plan design
upstream-drift and maintenance mapping
claim/non-claim hygiene
```

The current scope is not:

```text
new Linux scheduler hooks
new task_struct fields
new runtime state
new ABI
new monitor calls
new behavior-changing denial
new no-op implementation scaffolding
```

Existing committed P2 work remains recorded as historical project state. It is
not expanded in this phase.

## P3/P4 Rule

P3 and P4 may be made implementation-ready, but not implemented, until the user
explicitly reopens implementation scope.

Implementation-ready means:

```text
current-source anchors are verified
future helper names and signatures are proposed
forbidden fallbacks are recorded
required validation is specified
claim limits are explicit
upstream-drift refresh rules are defined
```

It does not mean:

```text
touching linux/kernel/sched/*
touching include/linux/sched_exec_lease.h
generating a new Linux patch
updating the Linux patch queue for P3/P4
claiming runtime coverage
```

## Rationale

This keeps the project aligned with the security objective rather than letting
convenient implementation steps define the design. Scheduler authority is a
security-critical boundary. Even a no-op hook name must be placed only after
the proof obligation, fallback behavior, and validation story are clear.

The project can still make progress by producing source-verified design notes
and validation gates that will make a later implementation smaller, safer, and
easier to review.

## Consequences

- Linux worktree should remain clean at the P2 commit unless implementation
  scope is explicitly reopened.
- P3/P4 documents may be updated as design artifacts.
- Patch queue remains at P2 for now.
- The next useful work is source-verified P3/P4 design, not code.
- Any future implementation turn must explicitly state which design gate it
  satisfies and which behavior claims remain forbidden.

## Non-Claims

This decision does not complete implementation readiness, approve P3/P4 code,
approve scheduler enforcement, approve runtime denial, approve ABI, verify the
monitor, prove protection, or prove cost efficiency.
