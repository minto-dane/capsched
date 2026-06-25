# ADR-0001: Project State Foundation and Directory Layout

Status: Superseded by ADR-0002

Date: 2026-06-25

## Context

The project will span upstream Linux investigation, scheduler design, capability
semantics, formal modeling, validation, prototyping, and security evaluation.
AI context limits make explicit state management necessary.

The Linux source has not been fetched yet. Implementation decisions must wait
until real upstream code has been read.

## Decision

Create `capsched-state/` as the explicit project memory directory, separate from
the future Linux source checkout.

Use:

- `state.json` as canonical compact machine-readable current state
- `events.jsonl` as append-only chronological log
- `context/` for human-readable compact and extended project memory
- `decisions/` for ADR-style decisions
- `investigations/` for code and prior-art reading notes
- `models/` for formal and semi-formal semantic models
- `validation/` for validation plans and evidence
- `implementation/` for patch maps and prototype plans
- `templates/` for repeatable records

## Rationale

This split keeps Linux source code, implementation artifacts, and research state
separate. It also gives future AI sessions a short recovery path:

```text
state.json -> context/compact.md -> decisions/index.md
```

Machine-readable state should stay terse and current. Longer reasoning belongs
in contextual notes or ADRs.

## Consequences

All major changes to direction, chosen Linux base, validation approach, or
implementation plan should update `state.json` and add an event.

Accepted decisions should not be silently rewritten when their meaning changes.
Instead, create a superseding ADR.
