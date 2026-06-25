# ADR-0002: Split State Ledger from AI, Design, Model, and Analysis Artifacts

Status: Superseded by ADR-0003

Date: 2026-06-25

## Context

The first project-memory layout placed AI handoff, design context, decisions,
investigations, models, validation, plans, implementation notes, and templates
under `capsched-state/`.

That made early bootstrapping simple, but it blurred two different roles:

- compact current-state ledger
- growing research and engineering artifacts

For a long-running kernel research project, the latter will expand
substantially and should not make current-state recovery expensive.

## Decision

Keep `capsched-state/` as a minimal state ledger containing only:

- `state.json`
- `events.jsonl`
- schemas
- local README

Move major artifact categories into sibling top-level directories:

- `capsched-ai/`
- `capsched-design/`
- `capsched-decisions/`
- `capsched-analysis/`
- `capsched-models/`
- `capsched-validation/`
- `capsched-plans/`
- `capsched-implementation/`
- `capsched-templates/`

Use the workspace root as the project-control Git repository. The future
`linux/` checkout remains a separate Git repository and is ignored by the
project-control repo.

## Rationale

This keeps recovery cheap:

```text
capsched-state/state.json
-> capsched-ai/handoff.md
-> capsched-design/compact.md
-> capsched-decisions/index.md
```

It also prevents formal models, code investigations, validation results, and
implementation plans from turning the state directory into an unfocused archive.

## Consequences

References in `state.json`, AI handoff, and operating protocol must use the new
top-level paths.

Future artifact categories should be added as sibling project-control
directories unless they are truly part of the minimal state ledger.
