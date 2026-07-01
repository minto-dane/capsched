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
/media/nia/scsiusb/dev/linux-cap/build/traceability-overlay/20260630T235558Z/project-overlay-ledger.json
```

Run directory:

```text
/media/nia/scsiusb/dev/linux-cap/build/semantic-recheck/20260630T235623Z
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
semantic_recheck_items=0
gap_items=14
line_only_anchor_items=0
symbol_missing_items=0
pattern_missing_items=0
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
0 semantic recheck items:
  no active line-only, missing-symbol, or missing-pattern rows

14 gap preservation items:
  future direct-call gaps
  trace-plan rows
```

This makes the next review step explicit: the semantic recheck queue is empty,
and only preserved gap/plan rows remain. Those gaps are still obligations or
future anchors, not implementation evidence.

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

N-110 is satisfied as a queue/workflow preparation step. N-111 removed the two
high-priority missing-symbol/pattern items, and N-112 removed the remaining
line-only anchor recheck items. The remaining queue is gap preservation only.
