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
3. `capsched/capsched-models/analysis/0228-dynamic-residency-f0-v5-candidate4-g6-counterexample-repair.md`
4. `capsched/capsched-models/validation/0316-dynamic-residency-f0-c4-g6-incomplete-disposition.md`
5. `capsched/capsched-models/validation/0317-dynamic-residency-f0-c4-g6-counterexample-repair.md`
6. `capsched/capsched-models/plans/0006-final-compositional-model-completion-plan.md`

When already inside this repository, omit the leading `capsched/` component.
`capsched-ai/design/compact.md` is detailed historical chronology and is not in
the default AI recovery path.

Validate recovery state in Linux with procfs (the runner lifecycle regression
intentionally exercises Linux-only process semantics):

```sh
./capsched-ai/state/check-current-state.sh
```

The Apple Container machine uses `home-mount=none`. Never pass an SSD-resident
checkout through `--workdir`. Capture startup archives only the eight exact
tracked inputs from a clean commit into root-owned, read-only VM-native
staging; raw evidence stays in a separate VM-native root.

Volatile campaign status is intentionally not duplicated here. The structured
projection in `capsched-ai/handoff.md` is mechanically derived from
`capsched-ai/state/state.json`; the state checker rejects drift across the
claim register, gate contract, current exact inputs, and durable G6 result.

For a clean public recovery including the patch queue:

```sh
container machine run --root -n domainlease-dev --workdir / -- \
  git clone --recurse-submodules \
  --branch codex/reasoning-first-model-completion \
  https://github.com/minto-dane/linux-cap.git /opt/domainlease-recovery
container machine run --root -n domainlease-dev \
  --workdir /opt/domainlease-recovery/capsched -- \
  ./capsched-ai/state/check-current-state.sh
container machine run --root -n domainlease-dev \
  --workdir /opt/domainlease-recovery/capsched -- \
  python3 -I -S -B capsched-models/validation/validate-f0-supervisor-lts-v3.py
```

The Linux environment requires Git, Bash, jq, awk, `sha256sum`, Python 3, and
Python `jsonschema` with Draft 2020-12 support. Launch a full retry only when
the structured projection marks it eligible.

## Git Plan

Use this `capsched/` directory as the project-control Git repository. The
upstream Linux tree should live in sibling directory `../linux/` with its own
Git history and DomainLease implementation branches.

ADR-0023 records that the GitHub superproject, project-control/model repository,
and patch queue are intentionally public. Never commit credentials, private
keys, tokens, or private operational data.
