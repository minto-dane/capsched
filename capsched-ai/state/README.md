# DomainLease-Linux AI State Ledger

This directory is the minimal machine-readable current-state ledger for
DomainLease-Linux.
It lives under `capsched-ai/` because it exists primarily to support reliable AI
handoff and state recovery.

The goal is to make the current project state machine-readable and cheap to
recover. A future AI or human should start with:

1. `state.json`
2. `../handoff.md`
3. `../../capsched-models/analysis/0185-final-goal-conformance-and-compositional-model-reopen.md`
4. `../../capsched-models/plans/0006-final-compositional-model-completion-plan.md`

Do not load `../design/compact.md` by default. It is retained as detailed
historical chronology.

## Local Files

`state.json`
: Canonical compact machine-readable current state, schema v2. Keep it short,
  current, and free of chronological result dumps.

`events.jsonl`
: Append-only chronological event log. One JSON object per line.

`check-current-state.sh`
: Checks the compact state, assurance reopen, canonical file set, branch and
  commit ancestry, strict same-commit freshness of state/handoff/events, and
  invokes the semantic cross-artifact consistency layer.

`check-state-consistency.py`
: Derives claim, gate, install, G6/G7, exact-input, durable-attempt, and handoff
  relationships. It also runs hostile drift mutations. Invoke it through
  `check-current-state.sh`; it is not a competing checkpoint command.

`schemas/`
: JSON schemas for state files.

Modeling, code analysis, validation, and implementation planning live under
`../../capsched-models/`. See `../../README.md`.

## Operating Protocol

Before major work:

1. Read `state.json`.
2. Read `../handoff.md`.
3. Read Analysis 0185 and active Plan 0006.
4. Read focused artifacts only for the next requirement.
5. Add an event to `events.jsonl` when the project state changes.
6. Run `./capsched-ai/state/check-current-state.sh` after committing.

Volatile campaign facts belong only in `state.json` and the mechanically
checked projection in `../handoff.md`. README, index, plan, analysis, and
validation files may describe durable or historical facts but must not act as
parallel live-status ledgers.

When a decision is made:

1. Create or update an ADR in `../decisions/`.
2. Update `../decisions/index.md`.
3. Update `state.json` and `../handoff.md` in the same commit if it affects
   current direction, constraints, completion status, or next actions.

When upstream Linux is pulled:

1. Record the exact remote, branch, commit, and date in `state.json`.
2. Create an investigation note before choosing patch points.
3. Do not commit to implementation structure until the relevant upstream code is
   read.

## Freshness Rule

Any commit that changes semantic state under decisions, plans, analysis,
formal, validation, implementation, assurance, or traceability must update:

```text
state.json
../handoff.md
events.jsonl
```

in that commit. The strict checker rejects a stale state commit. During editing,
`check-current-state.sh --allow-draft` performs structural checks without the
same-commit requirement.

The same checker also rejects semantic agreement-by-staleness: gate partitions
are derived from the contract, claim statuses from the assurance register,
current inputs and G6 observations are digest-bound, and the handoff projection
must equal the state-derived projection exactly.
