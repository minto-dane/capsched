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
3. `capsched/capsched-models/analysis/0226-dynamic-residency-f0-v5-supervisor-v3-candidate4-pre-full-local-closure.md`
4. `capsched/capsched-models/validation/0313-dynamic-residency-f0-v5-supervisor-v3-candidate4-pre-full-local-closure.md`
5. `capsched/capsched-models/plans/0006-final-compositional-model-completion-plan.md`

When already inside this repository, omit the leading `capsched/` component.
`capsched-ai/design/compact.md` is detailed historical chronology and is not in
the default AI recovery path.

Validate recovery state with:

```sh
./capsched-ai/state/check-current-state.sh
```

The current checkpoint is Candidate-4 pre-full: child 274, parent 715, and
runner 44 hostile regressions pass, as does the fast validator. The full
bounded reachability/commutation campaign has not run. F0, R11, K0/G0,
protection, cost, deployment, and final-model completion remain false.

For a clean public recovery including the patch queue:

```sh
git clone --recurse-submodules https://github.com/minto-dane/linux-cap.git
cd linux-cap/capsched
./capsched-ai/state/check-current-state.sh
python3 -I -S -B capsched-models/validation/validate-f0-supervisor-lts-v3.py
```

This requires Git, Bash, jq, awk, `sha256sum`, Python 3, and Python
`jsonschema` with Draft 2020-12 support. Do not launch the full runner until an
authority-disjoint capture service is approved.

## Git Plan

Use this `capsched/` directory as the project-control Git repository. The
upstream Linux tree should live in sibling directory `../linux/` with its own
Git history and DomainLease implementation branches.

ADR-0023 records that the GitHub superproject, project-control/model repository,
and patch queue are intentionally public. Never commit credentials, private
keys, tokens, or private operational data.
