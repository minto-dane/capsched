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
| `check-direct-call-overlay-drift.sh` | Source-only drift checker for N-106 direct-call overlay seed rows. |
| `check-project-source-map-drift.sh` | Source-only project-level drift checker for legacy source-map families and direct-call overlay seeds. |

## Latest Direct-Call Drift Check

Validation/0079 executed the direct-call overlay drift checker against the N-106
seed:

```text
run: build/traceability-drift/20260630T230822Z
seed_rows=41
anchor_rows=41
ok_rows=34
gap_rows=7
path_changed_rows=0
pattern_missing_rows=0
semantic_recheck_required_rows=0
safety_flag_violations=0
```

This is source-only drift evidence, not authority, monitor verification, or
protection evidence.

## Latest Project Source-Map Drift Check

Validation/0080 executed the project-level source-map drift checker against
legacy machine-readable source maps and the latest direct-call overlay seed:

```text
run: build/traceability-project-drift/20260630T232802Z
json_artifacts_scanned=15
anchor_rows=515
ok_rows=481
gap_rows=13
path_changed_rows=0
symbol_missing_rows=1
pattern_missing_rows=1
semantic_recheck_required_rows=19
unsupported_extraction_rows=3
safety_flag_violations=0
safety_scan_scope=recursive_boolean_safety_fields_in_scanned_json
content_source=git_HEAD_objects
source_path_pattern_only=true
semantic_validation=false
```

The one missing symbol is `ice_alloc_vfs` in
`drivers/net/ethernet/intel/ice/ice_sriov.c`; current source shows the relevant
VF allocation region under `ice_create_vf_entries()`, so that legacy anchor
requires semantic recheck. The 19 semantic-recheck rows are line-only anchors
that are no longer treated as evidence merely because the file exists. Gap rows
and unsupported rows are preserved, not converted into authority or removed
obligations.

The `ok_rows` count is path/pattern drift evidence only; it is not semantic
validation of those source regions.

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
The N-106 direct-call inventory expansion emits `overlay-seed.json` as a local
source-only seed. What is still missing is a central machine-readable overlay
ledger that can answer across the whole project:

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
