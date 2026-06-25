# ADR-0003: Use Two Top-Level Directories for AI State and Modeling Work

Status: Superseded by ADR-0004

Date: 2026-06-25

## Context

ADR-0002 split project artifacts into many top-level directories. That separated
concerns clearly, but made the workspace noisier than necessary.

The desired structure is simpler: one directory for AI/state/decision continuity,
and one directory for modeling, code analysis, validation, plans, and
implementation reasoning.

## Decision

Use two top-level project-control directories:

```text
capsched-ai/
  handoff.md
  operating-protocol.md
  state/
  design/
  decisions/
  templates/

capsched-models/
  index.md
  formal/
  analysis/
  validation/
  plans/
  implementation/
```

The future upstream Linux tree remains a separate `linux/` Git repository.

## Rationale

This gives the workspace two clear mental buckets:

- `capsched-ai/`: state continuity, AI recovery, durable decisions, compact
  architecture memory
- `capsched-models/`: semantic models, code investigations, validation,
  sequencing, and implementation planning

It avoids both extremes: one overloaded state directory and too many top-level
artifact directories.

## Consequences

The canonical recovery path is:

```text
capsched-ai/state/state.json
-> capsched-ai/handoff.md
-> capsched-ai/design/compact.md
-> capsched-ai/decisions/index.md
```

All model, analysis, validation, plan, and implementation artifacts should be
placed under `capsched-models/`.
