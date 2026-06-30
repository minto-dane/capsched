# Validation 0082: Semantic Recheck Queue Result

Status: Executed; source-only semantic recheck queue emitted

Date: 2026-06-30

Builder:

```text
capsched/capsched-models/traceability/build-semantic-recheck-queue.sh
```

Workflow:

```text
capsched/capsched-models/traceability/semantic-recheck-workflow-v1.md
```

Input:

```text
/media/nia/scsiusb/dev/linux-cap/build/traceability-overlay/20260630T233634Z/project-overlay-ledger.json
```

Run directory:

```text
/media/nia/scsiusb/dev/linux-cap/build/semantic-recheck/20260630T234227Z
```

Output files:

```text
recheck-queue.json
recheck-queue.tsv
gap-preservation.tsv
summary.txt
metadata.txt
```

## Result Summary

```text
overlay_rows=515
semantic_recheck_items=21
gap_items=14
line_only_anchor_items=19
symbol_missing_items=1
pattern_missing_items=1
gap_or_plan_items=14
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
```

## Meaning

The queue separates:

```text
21 semantic recheck items:
  19 line-only anchors
  1 missing symbol
  1 missing descriptive pattern

14 gap preservation items:
  future direct-call gaps
  trace-plan rows
```

This makes the next review step explicit and prevents weak anchors from being
silently counted as implementation evidence.

## Non-Claims

This run does not support:

```text
semantic recheck has been performed
source anchors provide authority
runtime coverage occurred
monitor verification occurred
public tracepoint ABI is approved
production protection exists
```

## Design Consequence

N-110 is satisfied as a queue/workflow preparation step. The next safe step is
to perform the first semantic recheck batch and update or preserve the affected
source-map anchors without changing Linux behavior.
