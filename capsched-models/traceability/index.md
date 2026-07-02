# Traceability Index

Updated: 2026-07-02

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
| `0002-terminology-alias-appendix.md` | Human-readable legacy-to-public vocabulary alias map for N-156 and later work. |
| `overlay-row-schema-v1.json` | Machine-readable row schema for future N/artifact/Linux/claim crosswalk ledgers. |
| `project-overlay-ledger-row-schema-v1.json` | Machine-readable row schema for generated project-level overlay ledger rows. |
| `project-gap-classification-schema-v1.json` | Machine-readable schema for classifying preserved project gaps into semantic groups. |
| `check-direct-call-overlay-drift.sh` | Source-only drift checker for N-106 direct-call overlay seed rows. |
| `check-project-source-map-drift.sh` | Source-only project-level drift checker for legacy source-map families and direct-call overlay seeds. |
| `build-project-overlay-ledger.sh` | Source-only normalizer from project drift rows to central overlay ledger rows. |
| `semantic-recheck-workflow-v1.md` | Source-only workflow for reviewing weak source anchors. |
| `build-semantic-recheck-queue.sh` | Source-only queue builder for semantic recheck and gap-preservation items. |
| `gap-classification-workflow-v1.md` | Source-only workflow for classifying preserved gap rows without resolving them. |
| `classify-project-gaps.sh` | Source-only classifier that groups preserved project gaps by semantic gap id. |

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

Validation/0088 refreshed the project-level source-map drift checker after
adding the N-117 direct-call receipt-consumer source map:

```text
run: build/traceability-project-drift/20260701T020900Z
json_artifacts_scanned=16
anchor_rows=542
ok_rows=521
gap_rows=21
path_changed_rows=0
symbol_missing_rows=0
pattern_missing_rows=0
semantic_recheck_required_rows=0
unsupported_extraction_rows=3
safety_flag_violations=0
safety_scan_scope=recursive_boolean_safety_fields_in_scanned_json
content_source=git_HEAD_objects
source_path_pattern_only=true
semantic_validation=false
```

N-111 rechecked the previous missing symbol and descriptive pattern rows. N-112
then replaced the remaining line-only anchors with symbol-bearing anchors.
N-117 added 20 current source anchors and 7 preserved future gap/plan rows for
the receipt-consumer lens. Gap rows and unsupported rows are preserved, not
converted into authority or removed obligations.

The `ok_rows` count is path/pattern drift evidence only; it is not semantic
validation of those source regions.

## Latest Project Overlay Ledger

Validation/0088 refreshed the project overlay ledger normalizer against the
latest project source-map drift output:

```text
run: build/traceability-overlay/20260701T020930Z
input_rows=542
overlay_rows=542
ok_rows=521
gap_rows=21
path_changed_rows=0
symbol_missing_rows=0
pattern_missing_rows=0
semantic_recheck_required_rows=0
needs_semantic_recheck_rows=0
path_only_rows=67
line_only_rows=0
symbol_rows=397
pattern_rows=57
gap_match_rows=21
safety_flag_violations=0
semantic_validation=false
n_series_rewrite=false
```

This generated ledger is the central overlay view for current source-map drift
state. It is still source-only: it does not support monitor verification,
runtime coverage, authority, ABI approval, or production protection.

## Latest Semantic Recheck Queue

Validation/0088 refreshed the semantic recheck queue builder against the latest
project overlay ledger:

```text
run: build/semantic-recheck/20260701T020945Z
overlay_rows=542
semantic_recheck_items=0
gap_items=21
line_only_anchor_items=0
symbol_missing_items=0
pattern_missing_items=0
gap_or_plan_items=21
safety_flag_violations=0
semantic_validation=false
```

This queue is empty for active semantic recheck items. The 21 preserved
gap/plan rows remain tracked separately so that missing future anchors are not
mistaken for implementation evidence or silently dropped.

## Latest Semantic Recheck Batch

Validation/0083 performed the first high-priority source-anchor recheck:

```text
ice_alloc_vfs -> ice_create_vf_entries
inert translation unit -> This translation unit is intentionally inert
```

This removed the missing-symbol and missing-pattern rows from the active queue.
It did not validate runtime behavior, monitor authority, or production
protection.

Validation/0084 then performed the line-only anchor recheck:

```text
e1000e source-map line-only anchors -> symbol-bearing anchors
ice source-map line-only anchors -> symbol-bearing anchors
usbnet source-map line-only anchors -> symbol-bearing anchors
```

This removed the remaining active semantic recheck rows. It did not validate
runtime behavior, monitor authority, ABI approval, behavior-changing Linux
patches, or production protection.

## Latest Project Gap Classification

Validation/0088 refreshed the preserved gap/plan classification after N-117:

```text
run: build/traceability-gap-classification/20260701T020955Z
gap_rows=21
semantic_gap_groups=7
duplicate_groups=7
future_linux_anchor_rows=15
future_linux_anchor_groups=5
future_test_anchor_rows=3
future_test_anchor_groups=1
trace_plan_rows=3
trace_plan_groups=1
unknown_gap_rows=0
safety_flag_violations=0
semantic_validation=false
implementation_approval=false
```

The 21 rows collapse into the same 7 direct-call semantic gap groups. Five are
high-severity future Linux/internal anchors that still depend on monitor-owned
direct-call semantics; one is a test-only failure-injection surface; one is a
trace-only observation plan. N-117 adds a third source-map view of each group,
not implementation approval.

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

The project now has a generated central project overlay ledger for currently
machine-readable source-map families. What is still missing is a durable,
checked-in or reproducibly regenerated N-to-artifact-to-claim crosswalk that can
answer across the whole project:

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
