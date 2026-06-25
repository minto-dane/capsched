# CapSched-Linux Workspace

This workspace separates project control artifacts from the future upstream
Linux source checkout.

## Layout

`capsched-ai/`
: AI-facing project memory and state management. Contains handoff, operating
  protocol, machine-readable state, event log, design context, decisions, and
  templates.

`capsched-models/`
: Modeling and engineering work area. Contains formal models, upstream code
  analysis, validation plans/results, roadmaps, and implementation planning.

`linux/`
: Future upstream Linux checkout. This should be a separate Git repository and
  should not be committed into the workspace project-control repository.

## Recovery Path

Read in this order:

1. `capsched-ai/state/state.json`
2. `capsched-ai/handoff.md`
3. `capsched-ai/design/compact.md`
4. `capsched-ai/decisions/index.md`

## Git Plan

Use the workspace root as the project-control Git repository. Exclude `linux/`
so the upstream Linux tree can keep its own Git history and branches.

Current project-control state is expected to be committed before fetching
upstream Linux.
