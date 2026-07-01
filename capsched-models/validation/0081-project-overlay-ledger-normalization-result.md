# Validation 0081: Project Overlay Ledger Normalization Result

Status: Executed; source-only project overlay ledger emitted

Date: 2026-06-30

Builder:

```text
capsched/capsched-models/traceability/build-project-overlay-ledger.sh
```

Input:

```text
/media/nia/scsiusb/dev/linux-cap/build/traceability-project-drift/20260630T235533Z/project-anchor-ledger.json
```

Run directory:

```text
/media/nia/scsiusb/dev/linux-cap/build/traceability-overlay/20260630T235558Z
```

Output files:

```text
project-overlay-ledger.json
project-overlay-ledger.tsv
semantic-recheck.tsv
gaps.tsv
summary.txt
metadata.txt
```

## Result Summary

```text
input_rows=515
overlay_rows=515
ok_rows=501
gap_rows=14
path_changed_rows=0
symbol_missing_rows=0
pattern_missing_rows=0
semantic_recheck_required_rows=0
needs_semantic_recheck_rows=0
path_only_rows=67
line_only_rows=0
symbol_rows=397
pattern_rows=37
gap_match_rows=14
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
semantic_validation=false
n_series_rewrite=false
```

## Meaning

The builder normalized the N-108 project drift rows into central overlay rows
with explicit:

```text
source artifact
source context
Linux anchor id
source path
symbol or pattern
line or range
match kind
drift status
evidence class
unsupported claims
next action
```

The generated overlay ledger is intentionally build output rather than a large
checked-in generated table. The script and schema are tracked, so the ledger can
be regenerated after upstream Linux updates.

## Non-Claims

This run does not support:

```text
source anchors provide authority
ok rows provide semantic validation
line-only anchors are semantically current
gap rows remove obligations
runtime coverage occurred
monitor verification occurred
public tracepoint ABI is approved
production protection exists
```

## Design Consequence

N-109 is satisfied as the first central overlay-ledger normalizer. The N-112
rerun shows the active overlay has no line-only or missing-symbol/pattern
semantic recheck rows. The remaining safe step is preserving and classifying the
14 gap rows before they can influence implementation decisions.
