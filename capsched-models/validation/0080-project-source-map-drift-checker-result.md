# Validation 0080: Project Source-Map Drift Checker Result

Status: Executed; source-only project drift check emitted

Date: 2026-06-30

Checker:

```text
capsched/capsched-models/traceability/check-project-source-map-drift.sh
```

Run directory:

```text
/media/nia/scsiusb/dev/linux-cap/build/traceability-project-drift/20260630T235533Z
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
ok_rows=501
gap_rows=14
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

The 501 ok rows mean the mechanically extracted source paths and, where
precise enough, symbols or patterns still match the current Linux tree.
They do not mean the source semantics were validated.

The 14 gap rows are preserved gaps or trace-plan rows. They are not removed
obligations.

N-112 resolved the previous 19 line-only semantic-recheck rows by replacing
them with symbol-bearing source anchors or corrected symbol-bearing line
anchors. The checker still refuses to turn a bare historical line number into
semantic evidence.

The previous high-priority missing symbol and descriptive-pattern rows were
rechecked in N-111 and now match current source:

```text
ice_alloc_vfs -> ice_create_vf_entries
inert translation unit -> This translation unit is intentionally inert
```

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

The latest rerun after N-112 confirms that current source-map rows no longer
contain line-only semantic recheck items. The remaining safe step is to classify
the preserved gap rows without treating them as removed obligations:

```text
future Linux anchor gap
future monitor/root-management external anchor
trace-plan row
obsolete or intentionally unsupported extraction
```

ADR-0007 still applies: N-series history remains chronological, and
interpretation lives in overlay rows rather than by rewriting old N records.
