# ADR-0004: Encapsulate Project-Control Repo under capsched and Do Not Ignore Linux

Status: Accepted

Date: 2026-06-25

## Context

The previous layout placed the project-control Git repository at the workspace
root and ignored `linux/`. That made the workspace root carry project-control
files directly and created ambiguity about how the future Linux repository would
coexist with project state.

Linux will be patched directly, so the Linux tree should not be hidden by the
project-control ignore rules.

## Decision

Move the project-control repository into `capsched/`:

```text
linux-cap/
  capsched/
    .git/
    README.md
    .gitignore
    capsched-ai/
    capsched-models/

  linux/
    .git/
    ...
```

Remove `/linux/` from the project-control `.gitignore`.

The future Linux checkout will be a sibling repository at `linux/`, not a child
ignored by the project-control repository.

## Rationale

This gives the workspace two clear Git repositories:

- `capsched/`: AI state, decisions, design memory, models, validation, and plans
- `linux/`: upstream Linux source and CapSched implementation patches

It keeps the workspace root clean and avoids treating the Linux tree as an
ignored artifact.

## Consequences

The canonical recovery path is now from the workspace root:

```text
capsched/capsched-ai/state/state.json
-> capsched/capsched-ai/handoff.md
-> capsched/capsched-ai/design/compact.md
-> capsched/capsched-ai/decisions/index.md
```

Commands that operate on project-control history should run in `capsched/`.
Commands that operate on Linux implementation history should run in `linux/`
after the upstream checkout is created.

