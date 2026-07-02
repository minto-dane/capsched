# DomainLease-Linux Workspace

This directory is the DomainLease-Linux project-control repository. It was
called CapSched-Linux during the private modeling phase; N-156 freezes the
public vocabulary before publication.

## Layout

`capsched-ai/`
: AI-facing project memory and state management. Contains handoff, operating
  protocol, machine-readable state, event log, design context, decisions, and
  templates.

`capsched-models/`
: Modeling and engineering work area. Contains formal models, upstream code
  analysis, validation plans/results, roadmaps, and implementation planning.

`linux/`
: Future upstream Linux checkout at `../linux/`. This should be a separate Git
  repository. It is not ignored here; Linux patches are managed by the Linux
  repository itself.

## Recovery Path

Read in this order:

1. `capsched/capsched-ai/state/state.json`
2. `capsched/capsched-ai/handoff.md`
3. `capsched/capsched-ai/design/compact.md`
4. `capsched/capsched-ai/decisions/index.md`

## Git Plan

Use this `capsched/` directory as the project-control Git repository. The
upstream Linux tree should live in sibling directory `../linux/` with its own
Git history and DomainLease implementation branches.

Current project-control state is expected to be committed before fetching
upstream Linux.
