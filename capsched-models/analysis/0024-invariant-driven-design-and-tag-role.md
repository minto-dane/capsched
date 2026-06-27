# Analysis 0024: Invariant-Driven Design and the Role of Tags

Status: Accepted analysis direction

Date: 2026-06-27

## Purpose

This note records the design-method correction after reviewing whether
behavior tags should decide CapSched scheduler design.

Conclusion:

```text
Tags must not decide design.
Invariants and semantic state machines decide what must be true.
Tags index evidence, constraints, proof obligations, measurements, and gaps.
```

This supersedes any interpretation of behavior tagging as an autonomous
mechanical design-selection engine.

## Why This Matters

CapSched-Linux is not only a scheduler instrumentation project. The intended
production architecture is a monitor-backed Linux-derived datacenter OS substrate
where a process-scale, service-scale, container-scale, tenant-scale, or
cluster-cell-scale Domain can be isolated with VM-like strength.

That goal has a hostile threat model:

```text
an attacker may control Domain userspace
an attacker may exploit reachable Linux kernel bugs inside that Domain context
Linux-visible Domain shadow state may be forged
Linux-only checks are not a production trust root
```

Therefore a tag ledger cannot be the security root. A tag score cannot prove
noninterference, revocation, memory isolation, CPU-budget enforcement, async
provenance, or distributed authority safety.

## Rejected Model

The rejected model is:

```text
Linux behavior paths
  -> tags
  -> numeric score
  -> optimizer picks hook
  -> design accepted
```

This is unsafe because:

```text
classification mistakes become design mistakes
unknown paths can be hidden by scores
observation can be confused with enforcement
Linux-only evidence can be promoted into production claims
performance benefit can mask security failure
ontology lock-in can hide important failure modes
```

Examples of immediate hard failures:

```text
revocation race exists
Linux mutable shadow state is treated as authority
enqueue after mutation is made fail-capable without rollback
remote cluster consensus is placed in wake/pick/switch hot paths
unknown failure action is scored instead of rejected
```

These are not low scores. They are invalid designs.

## Accepted Model

The accepted model is:

```text
threat model
  -> non-negotiable invariants
  -> semantic state machines
  -> Linux source behavior map
  -> tags as evidence and constraint indexes
  -> candidate hook sets
  -> hard reject unsafe candidates
  -> formal validation and runtime measurement
  -> implementation decision
```

Tags are useful because Linux scheduler behavior is too large to safely hold in
human memory:

```text
current self-wake
already-runnable wake
remote pending wake
normal wake activation
new task wake
queued migration
delayed fair requeue
pick fast path
scheduler class pick path
proxy execution
core scheduling
sched_ext
RT and deadline classes
tick and budget charge
fork, exec, exit
workqueue and io_uring workers
softirq, timer, RCU, kthread, stop task
hotplug and cpuset changes
```

The tag system should help answer:

```text
which invariant does this path affect?
which authority event happens here?
which Linux mutation already happened?
what lock, IRQ, and memory-ordering context applies?
can failure be handled before mutation?
what trust root is used?
what revocation scope is covered?
what evidence exists?
what remains unknown?
```

## Non-Negotiable Invariant Set

The current scheduler-facing invariant root is:

```text
NoRunWithoutAuthority
NoQueuedWithoutFrozenUse
NoPickWithoutLiveFrozenUse
NoSwitchWithoutDomainActivation
NoBudgetNoExecution
NoRunAfterRelevantEpochMismatch
NoMigrationMintAuthority
NoSelfWakeMintRunCap
NoRemotePendingEscape
NoLinuxMutableStateAsProductionRoot
NoAsyncAuthorityConfusion
NoRemoteAuthorityInSchedulerHotPath
```

These names are design obligations, not implementation details. Later models and
patches may refine them, but they must not weaken them silently.

## Required Artifact Relationship

Use this relationship:

```text
Invariant
  -> semantic transition
  -> Linux source path
  -> candidate hook role
  -> tag record
  -> proof obligation
  -> evidence record
  -> assurance claim
```

Do not use this relationship:

```text
tag record
  -> design truth
```

## Solver Boundary

Allowed solver uses:

```text
reject candidates with missing hard fields
find uncovered invariants
find Linux paths with no corresponding authority transition
find claim/evidence mismatches
find config and scheduler-class gaps
produce Pareto frontiers among surviving candidates
generate proof-obligation and validation backlogs
```

Forbidden solver uses:

```text
declare a security claim
average safety into a score
promote observation into enforcement
promote L0 evidence into CapSched-H evidence
treat unknown safety as neutral
choose a hook that has unmodeled failure semantics
choose a hook that performs distributed authority acquisition in hot paths
```

## Consequence for Schema v2

Schema v2 must be derived after a scheduler authority state machine exists.

Schema v2 must encode:

```text
claim_scope
enforcement_strength
trust_root
attacker_mutability
authority_event
authority_lifetime
failure_action
failability_after_mutation
revocation_scope
revocation_stop_point
ordering_context
lock_context
class_semantics
config_scope
evidence and confidence
performance cost and benefit vectors
cluster authority locality
assurance claim linkage
```

The schema may support design exploration, but it must remain subordinate to
invariants and state-machine semantics.

## Next Step

Create a Linux scheduler authority state machine that maps upstream scheduler
behavior to CapSched authority events.

Only after that should we produce the first solver-eligible schema v2 ledger.
