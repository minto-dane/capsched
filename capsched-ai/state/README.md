# CapSched AI State Ledger

This directory is the minimal machine-readable state ledger for CapSched-Linux.
It lives under `capsched-ai/` because it exists primarily to support reliable AI
handoff and state recovery.

The goal is to make the current project state machine-readable and cheap to
recover. A future AI or human should start with:

1. `state.json`
2. `../handoff.md`
3. `../design/compact.md`
4. `../decisions/index.md`

## Local Files

`state.json`
: Canonical compact machine-readable state. Keep it short and current.

`events.jsonl`
: Append-only chronological event log. One JSON object per line.

`schemas/`
: JSON schemas for state files.

Modeling, code analysis, validation, and implementation planning live under
`../../capsched-models/`. See `../../README.md`.

## Operating Protocol

Before major work:

1. Read `state.json`.
2. Read `../handoff.md`.
3. Read `../design/compact.md`.
4. Check `../decisions/index.md`.
5. Add an event to `events.jsonl` when the project state changes.

When a decision is made:

1. Create or update an ADR in `../decisions/`.
2. Update `../decisions/index.md`.
3. Update `state.json` if it affects current direction, constraints, or next
   actions.

When upstream Linux is pulled:

1. Record the exact remote, branch, commit, and date in `state.json`.
2. Create an investigation note before choosing patch points.
3. Do not commit to implementation structure until the relevant upstream code is
   read.
