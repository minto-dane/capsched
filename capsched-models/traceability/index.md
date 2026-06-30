# Traceability Index

Updated: 2026-06-30

## Purpose

This directory records the cross-reference layer between chronological work,
semantic models, Linux source anchors, validation evidence, implementation
slices, and assurance claims.

It does not replace:

- `capsched-ai/state/state.json`
- `capsched-ai/state/events.jsonl`
- artifact-specific indexes under `analysis/`, `formal/`, `validation/`,
  `implementation/`, or `assurance/`

Instead, it explains how to read them together.

## Current Files

| File | Role |
| --- | --- |
| `0001-n-series-overlay-policy.md` | Human-readable policy for N-series overlay traceability and Linux drift handling. |
| `overlay-row-schema-v1.json` | Machine-readable row schema for future N/artifact/Linux/claim crosswalk ledgers. |

## Existing Indexes

Existing indexes already cover artifact lists and some source-anchor inventories:

| Existing file | What it covers | What it does not cover |
| --- | --- | --- |
| `capsched-ai/state/state.json` | Current project state, Linux base/work commit, current N list. | It is not a complete N-to-artifact-to-claim crosswalk. |
| `capsched-ai/state/events.jsonl` | Append-only chronological event evidence. | It is too verbose to be the only recovery index. |
| `capsched-models/analysis/index.md` | Analysis artifact titles and machine-readable source-map artifacts. | It is not a Linux drift ledger. |
| `capsched-models/formal/index.md` | Formal model artifacts. | It does not classify all claim support. |
| `capsched-models/validation/index.md` | Validation artifacts and runner results. | It does not by itself define production protection evidence. |
| `capsched-models/assurance/claims.json` | Machine-readable assurance claims and evidence records. | It does not enumerate every Linux anchor drift state. |

## Current Gap

The project already has many Linux source maps, especially for scheduler,
workqueue, io_uring, modern NIC, IOMMU, VFIO, and direct-call readiness work.
What is missing is a central machine-readable overlay ledger that can answer:

```text
N item
  -> artifacts
  -> semantic ids
  -> Linux source anchors and commits
  -> validation evidence class
  -> supported and explicitly unsupported claims
  -> upstream drift status
```

That central ledger should be built incrementally. It must not rewrite the
historical N records.

## Fixed Reading Rule

For every N item, past or future:

```text
N-*:
  chronological work event

overlay rows:
  interpretation layer

CLAIM-*:
  assurance statement, never implied directly by N completion
```

For every Linux source anchor:

```text
source observed:
  useful evidence

source observed:
  not authority

source missing:
  gap, not obligation removal
```

For every upstream update:

```text
compile still works:
  necessary but insufficient

anchor still exists:
  necessary but insufficient

meaning still matches:
  semantic recheck required when source changed
```

## Long-Horizon Rule

ADR-0008 fixes the implementation posture:

```text
small slice:
  acceptable

short-horizon security model:
  rejected

thin Linux hook:
  maintainability tactic

thin Linux hook as authority substitute:
  rejected
```

Future overlay rows for implementation-facing work should say which L5/L4/L3
invariant shape they preserve and which future HyperTag Monitor authority is
still external.
