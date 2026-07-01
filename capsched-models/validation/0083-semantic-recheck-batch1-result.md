# Validation 0083: Semantic Recheck Batch 1 Result

Status: Executed; high-priority source-anchor recheck completed

Date: 2026-06-30

Inputs:

```text
build/semantic-recheck/20260630T234227Z/recheck-queue.tsv
```

Rechecked rows:

```text
RECHECK-0017:
  artifact: capsched-models/analysis/ice-vf-epoch-handoff-source-map-v1.json
  old: ice_alloc_vfs
  new: ice_create_vf_entries
  source: drivers/net/ethernet/intel/ice/ice_sriov.c

RECHECK-0021:
  artifact: capsched-models/analysis/direct-call-trace-source-inventory-contract-v1.json
  old: inert translation unit
  new: This translation unit is intentionally inert
  source: kernel/sched/capsched.c
```

Follow-up runs:

```text
project drift:
  build/traceability-project-drift/20260630T234623Z

project overlay:
  build/traceability-overlay/20260630T234640Z

semantic recheck queue:
  build/semantic-recheck/20260630T234640Z
```

## Result Summary

After recheck:

```text
symbol_missing_rows=0
pattern_missing_rows=0
semantic_recheck_items=19
gap_items=14
line_only_anchor_items=19
symbol_missing_items=0
pattern_missing_items=0
source_only=true
semantic_validation=false
authority_claim=false
monitor_verified=false
protection_claim=false
```

## Meaning

The first high-priority recheck batch removed the only missing symbol and the
only missing descriptive pattern from the source-only drift ledger.

The remaining semantic recheck queue consists of line-only anchors. Those still
need replacement with symbol/pattern anchors or explicit path-only downgrades.

N-112 completed that line-only follow-up; see validation/0084 for the current
post-recheck queue state.

## Non-Claims

This run does not support:

```text
all semantic rechecks are complete
line-only anchors are acceptable evidence
runtime coverage occurred
monitor verification occurred
production protection exists
```
