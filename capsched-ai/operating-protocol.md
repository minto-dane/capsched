# AI Operating Protocol

Updated: 2026-08-08

This file defines how AI sessions should maintain project continuity.

## State Discipline

For any nontrivial change:

1. Update `state.json` if current phase, source commit, accepted invariants,
   open questions, or next actions changed.
2. Append one JSON object to `events.jsonl`.
3. Add or update an ADR when a durable decision is made.
4. Put code reading notes in `capsched/capsched-models/analysis/`.
5. Put formal semantics in `capsched/capsched-models/formal/`.
6. Put validation plans/results in `capsched/capsched-models/validation/`.
7. Put roadmaps and task breakdowns in `capsched/capsched-models/plans/`.
8. Put implementation-specific patch maps in `capsched/capsched-models/implementation/`.
9. Put cross-work traceability, Linux anchor drift rules, and N-to-artifact
   mapping policy in `capsched/capsched-models/traceability/`.

## Context Budget Discipline

Prefer short recovery files:

- `state.json` for machine state
- `capsched/capsched-ai/handoff.md` for AI resume context
- `capsched/capsched-ai/design/compact.md` for human-readable compact context

`design/compact.md` is now retained as historical detailed chronology and is
not part of default recovery. Do not append new result narratives there.

Do not overload current recovery files with long reasoning or chronological
result dumps. Put deep reasoning into focused notes under
`capsched/capsched-ai/design/` or the relevant `capsched/capsched-models/`
subdirectory, and put chronology in `events.jsonl`.

After a semantic state change, update `state.json`, `handoff.md`, and
`events.jsonl` in the same commit and run:

```sh
./capsched-ai/state/check-current-state.sh
```

Use `--allow-draft` only before the state commit exists.

Do not copy volatile campaign status into README, model indexes, or plans.
Record durable attempts as typed outcomes in `state.json`; retain historical
results in numbered analysis/validation records. The structured projection in
`handoff.md` is the only duplicated current view, and
`check-current-state.sh` compares it exactly while deriving gate, claim,
install, G6/G7, and digest relationships through the integrated semantic
consistency checker.

## Decision Discipline

Use ADRs for durable choices, especially:

- Linux base version/commit
- branch structure
- first L0 slice
- formal model choice
- validation claim boundaries
- implementation architecture
- monitor-backed security claims

Accepted ADRs should not be silently rewritten when meaning changes. Create a
new superseding ADR instead.

## Investigation Discipline

Before implementation, read upstream code and write focused investigation notes.
Tie findings to file paths, function names, and CapSched invariants.

Do not use speculative patch maps as accepted implementation plans.

## Long-Horizon Implementation Discipline

All implementation work is designed from the monitor-backed datacenter OS target
backward. A small Linux slice is acceptable only when it preserves the shape of
the long-horizon invariants.

For any behavior-changing Linux patch proposal, record:

- which L5/L4/L3 invariant it preserves
- which future HyperTag Monitor responsibility remains external
- which Linux-only placeholder must not be treated as authority
- which async, memory, IOMMU, queue, or cluster obligation remains open
- which protection claims are explicitly forbidden

Patch-surface minimization is a maintainability tactic. It is not permission to
weaken the threat model or collapse monitor-backed authority into Linux-global
mutable state.

## Traceability Discipline

`N-*` items are chronological work records only. Do not turn them into
requirements, invariants, Linux source anchors, validation ids, patch ids, or
assurance claims.

Use overlay traceability rows for semantic interpretation:

```text
N -> artifact -> REQ/THR/INV/DES/MODEL/VAL/LINUX/PATCH/CLAIM
```

For future N items, keep the N record format simple and add or refresh overlay
rows separately. This keeps N-106 and later readable the same way as N-001
through N-105.

Linux source anchors must record a checked commit. Source anchors are useful
evidence, but they default to:

```text
authority_claim=false
monitor_verified=false
protection_claim=false
```

After upstream Linux updates, compile success is not enough. Any affected Linux
anchor row must be checked for path, symbol/pattern, and semantic drift.

## Validation Discipline

Validation must support semantic claims. It is not just for making tests pass.

Separate:

- Linux-only prototype behavior
- monitor-backed protection claims
- performance evidence
- formal safety/liveness properties
- negative tests and counterexamples

Positive promotion evidence must follow ADR-0013: the validator captures and
seals exact inputs before reading them, validates only captured bytes,
recomputes summaries from retained raw evidence, and binds the decision to the
capsule id. Producer self-checks are diagnostic, not promotion authority.

## Git Discipline

Keep project state and Linux source separate:

```text
capsched/        project-control repository
linux/           upstream Linux repository and CapSched branches
```

Use Git commits in each repository to preserve history, while
`capsched/capsched-ai/state/state.json` preserves current project state.
