# ADR-0006: Use Invariant-Driven Design with Tag-Indexed Evidence

Status: Accepted

Date: 2026-06-27

## Context

The project considered using behavior tags and a machine-readable schema to
guide CapSched scheduler capability design and hook placement.

Critical review across security/formal methods, Linux scheduler implementation,
research methodology, and multi-cluster datacenter OS perspectives reached the
same conclusion:

```text
tag-driven design selection is unsafe
tag-indexed evidence and constraint tracking is useful
```

CapSched-H ultimately targets hostile Domain-local kernel-context compromise.
That means no tag score, trace observation, or Linux-local prototype result can
declare a production security claim by itself.

## Decision

CapSched design is invariant-driven.

Tags are not the source of truth. Tags are indexes into:

```text
threat-model assumptions
security and compatibility invariants
semantic state machines
Linux source evidence
runtime observation evidence
proof obligations
performance and scalability measurements
assurance-case claims
unknowns and gaps
```

The accepted design flow is:

```text
threat model
  -> non-negotiable invariants
  -> semantic state machines
  -> Linux behavior map
  -> tag-indexed evidence and constraints
  -> candidate hook sets
  -> hard rejection of unsafe candidates
  -> formal validation and runtime measurement
  -> implementation decision
```

The rejected design flow is:

```text
tag ledger
  -> scoring
  -> optimizer chooses hook
  -> implementation
```

## Rules

The solver may reject candidates.

The solver may rank candidates that survived all hard constraints.

The solver may not declare security.

Security claims require:

```text
explicit invariant
semantic model or equivalent argument
non-forgeable enforcement root
Linux source mapping
negative/adversarial validation
assurance-case linkage
```

Observation evidence never satisfies enforcement obligations.

Linux-only L0 evidence never satisfies monitor-backed CapSched-H production
claims.

Unknown safety, trust-root, failure-action, or revocation semantics make an
enforcement candidate ineligible.

## Consequences

The behavior tag schema v2 must be derived from invariants and semantic state
machines, not the other way around.

The next analysis step is not direct hook optimization. The next analysis step
is a Linux scheduler authority state machine that maps wake, enqueue, migration,
pick, switch, tick, and revocation behavior to CapSched authority events.

The current v1 tag ledger remains exploratory only.

Future hook-placement work must say which invariant, proof obligation, source
path, runtime evidence, performance dimension, and assurance claim it touches.
