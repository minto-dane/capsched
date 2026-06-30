# ADR-0007: Use Overlay Traceability for N-Series and Linux Anchors

Status: Accepted

Date: 2026-06-30

## Context

The project has reached N-105 with many analysis notes, formal models,
validation results, source maps, assurance records, and Linux source anchors.
The existing indexes are useful but mostly local:

- `state.json` and `events.jsonl` record project state and chronological work.
- `analysis/index.md`, `formal/index.md`, `validation/index.md`,
  `implementation/index.md`, and `assurance/index.md` list artifacts.
- several `*-source-map*.json` and readiness ledgers record Linux source
  anchors for individual topics.
- `assurance/claims.json` records machine-readable assurance claims.

There is not yet one central table that answers:

```text
Which N item produced which artifact?
Which semantic requirement, invariant, model, validation result, Linux source
anchor, and assurance claim does that artifact touch?
Which Linux commit was the anchor checked against?
Which claims are explicitly not supported by that evidence?
```

Adding new vocabulary at N-106 would be confusing if N-001 through N-105 looked
like a different system. Rewriting old N records would also be unsafe because it
would blur chronology and make later readers wonder whether history was edited.

## Decision

Use an overlay traceability model.

`N-*` remains an immutable chronological work ledger. An N item records what was
done, why it was done, dependencies, and completion status. It is not a
semantic requirement ID, guarantee ID, Linux source-anchor ID, or proof ID.

All semantic interpretation lives in separate overlay indexes:

```text
REQ-*:
  requirements

THR-*:
  threat-model assumptions and adversary powers

INV-*:
  invariants

DES-*:
  design decisions, ADRs, and implementation gates

MODEL-*:
  formal or semi-formal models

VAL-*:
  validation results, including counterexamples

LINUX-*:
  Linux source paths, symbols, tracepoints, patterns, commits, and drift state

PATCH-*:
  implementation slices and Linux changes

CLAIM-*:
  assurance claims and forbidden claims
```

The overlay applies to all N items, including N-001 through N-105 and every
future N item. Future N items do not get a different embedded schema. They get
rows in the same overlay tables, populated as the work is created or completed.
This keeps N-106 and later readable in exactly the same way as earlier work:

```text
N-series:
  chronological work history

overlay indexes:
  semantic interpretation and cross-reference layer
```

## Linux Anchor Rule

Linux source anchors are first-class traceability records, but they are never
authority by themselves.

Every nontrivial `LINUX-*` row must record:

```text
upstream base commit
work commit or checked commit
source path
symbol, tracepoint, or pattern
anchor class
drift status
evidence class
```

The default safety flags for Linux source anchors are:

```text
authority_claim=false
monitor_verified=false
protection_claim=false
```

An anchor disappearing is a gap, not proof that the corresponding obligation is
unnecessary. A source-only, observation-only, build-only, or model-checked row
must not be promoted into monitor-backed production protection evidence.

## Claim Rule

`N-*` must not directly support `CLAIM-*`.

Claims are supported only through typed evidence, usually:

```text
N -> artifact -> MODEL/VAL/LINUX/PATCH -> CLAIM
```

The evidence class controls what can be claimed. For example:

```text
source_only:
  can support source existence and gap tracking.

observation_only:
  can support visibility and hook placement analysis.

model_checked:
  can support bounded semantic consistency or counterexample discovery.

build_only:
  can support compile integration.

protection_evidenced:
  requires a non-forgeable enforcement root, threat-model linkage, invariant
  linkage, negative validation, and assurance-case approval.
```

## Consequences

Past N items are not rewritten into the new vocabulary. They are mapped by
overlay rows.

Future N items also remain ordinary chronological work items. The overlay rows
for future N items should be created as part of the work, but the N record
itself stays simple.

The `traceability/` directory is the home for crosswalk policy, schemas, and
eventually machine-readable N-to-artifact-to-Linux-to-claim ledgers.

Upstream Linux drift is now a design constraint. Rebase success is not enough.
When Linux source paths, symbols, call ordering, locking, runtime accounting, or
tracepoint meaning changes, affected overlay rows must be marked stale or
semantic-recheck-required.
