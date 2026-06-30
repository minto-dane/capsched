# Validation 0080: Project Source-Map Drift Checker Result

Status: Executed; source-only project drift check emitted

Date: 2026-06-30

Checker:

```text
capsched/capsched-models/traceability/check-project-source-map-drift.sh
```

Run directory:

```text
/media/nia/scsiusb/dev/linux-cap/build/traceability-project-drift/20260630T232802Z
```

Output files:

```text
project-anchor-ledger.tsv
project-anchor-ledger.json
stale-or-gap.tsv
unsupported-extractions.tsv
summary.txt
metadata.txt
```

## Result Summary

```text
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
source_only=true
requires_privilege=false
writes_tracefs=false
attaches_probes=false
modifies_linux=false
public_tracepoint_abi=false
authority_claim=false
monitor_verified=false
protection_claim=false
```

Linux source:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
commit: 7cf0b1e415bcead8a2079c8be94a9d41aad7d462
```

## Meaning

The checker ingested existing machine-readable source-map and ledger artifacts,
plus the latest direct-call overlay seed, and produced a central source-anchor
drift ledger.

The 481 ok rows mean the mechanically extracted source paths and, where
precise enough, symbols or patterns still match the current Linux tree.
They do not mean the source semantics were validated.

The 13 gap rows are preserved gaps or trace-plan rows. They are not removed
obligations.

The 19 semantic-recheck rows are line-only anchors. The checker now refuses to
turn a historical line number into semantic evidence without a symbol or pattern.

The one symbol-missing row is useful drift evidence:

```text
capsched-models/analysis/ice-vf-epoch-handoff-source-map-v1.json
drivers/net/ethernet/intel/ice/ice_sriov.c
ice_alloc_vfs
```

In the current Linux tree, the relevant allocation region is represented by
`ice_create_vf_entries()`, so this source-map anchor needs semantic recheck
before it is used as evidence.

The one pattern-missing row is:

```text
capsched-models/analysis/direct-call-trace-source-inventory-contract-v1.json
kernel/sched/capsched.c
inert translation unit
```

That row used a descriptive phrase, not a literal source pattern, so the next
normalization step should encode it as path-only or replace it with a literal
predicate.

The 3 unsupported extraction rows are also deliberate:

```text
1 symbol not found in a multi-file candidate set
2 external monitor/root-management anchors with no Linux path
```

They are not silently converted into authority, proof, or removed obligations.

## Non-Claims

This run does not support:

```text
Linux source anchors provide authority
source-map completion implies security coverage
missing source anchors remove semantic obligations
runtime coverage occurred
tracefs probes were attached
monitor verification occurred
public tracepoint ABI is approved
production protection exists
```

## Design Consequence

N-108 is satisfied as a first project-level, source-only drift checker.

The next safe step is to normalize legacy source-map families into a central
overlay ledger that records:

```text
artifact id
semantic id
Linux anchor id
recorded commit/blob where available
current drift status
match predicate type
evidence class
explicit unsupported claims
required semantic recheck
```

That normalization should preserve ADR-0007: N-series history remains
chronological, and interpretation lives in overlay rows rather than by rewriting
old N records.
