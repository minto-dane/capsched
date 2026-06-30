# Validation 0079: Direct-Call Overlay Drift Checker Result

Status: Executed; source-only drift check emitted

Date: 2026-06-30

Checker:

```text
capsched/capsched-models/traceability/check-direct-call-overlay-drift.sh
```

Input seed:

```text
/media/nia/scsiusb/dev/linux-cap/build/direct-call-inventory/20260630T230536Z/overlay-seed.json
```

Run directory:

```text
/media/nia/scsiusb/dev/linux-cap/build/traceability-drift/20260630T230822Z
```

Output files:

```text
drift-ledger.tsv
drift-ledger.json
stale-or-gap.tsv
summary.txt
metadata.txt
```

## Result Summary

```text
seed_rows=41
anchor_rows=41
ok_rows=34
gap_rows=7
path_changed_rows=0
pattern_missing_rows=0
semantic_recheck_required_rows=0
safety_flag_violations=0
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

The checker confirms that the 34 source-observed N-106 direct-call anchors still
exist with matching path, pattern, and recorded blob state in the current Linux
tree.

The 7 non-ok rows are expected gaps:

```text
6 future direct-call implementation gaps
1 trace catalog plan row
```

No path changes, missing patterns, or source-blob semantic recheck rows were
found for the currently observed anchors.

## Non-Claims

This run does not support:

```text
direct-call admission exists
monitor verification occurred
tracefs runtime coverage occurred
dynamic probes were attached
source anchors provide authority
missing anchors remove semantic obligations
Linux timeout has monitor meaning
public tracepoint ABI is approved
production protection exists
```

## Design Consequence

N-107 is satisfied as a first source-only drift checker for the N-106
direct-call overlay seed.

The next safe step is to generalize this into a project-level traceability
ledger/checker that can ingest older source-map families, not only the
direct-call inventory seed. That generalization must preserve the same safety
defaults and must mark source changes as semantic recheck requirements rather
than silently updating security assumptions.
