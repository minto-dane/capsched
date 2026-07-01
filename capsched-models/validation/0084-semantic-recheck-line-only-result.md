# Validation 0084: Semantic Recheck Line-Only Result

Status: Executed; line-only source-anchor recheck completed

Date: 2026-06-30

Inputs:

```text
build/semantic-recheck/20260630T234640Z/recheck-queue.tsv
```

Updated source-map artifacts:

```text
capsched-models/analysis/e1000e-queuelease-source-map-v1.json
capsched-models/analysis/ice-modern-nic-queuelease-source-map-v1.json
capsched-models/analysis/usbnet-workqueue-source-map-v1.json
```

Synchronized human-readable notes:

```text
capsched-models/analysis/0049-e1000e-queuelease-source-map.md
capsched-models/analysis/0051-linux-queue-descriptor-ledger-observation-plan.md
capsched-models/analysis/0052-ice-modern-nic-queuelease-source-map.md
```

Follow-up runs:

```text
project drift:
  build/traceability-project-drift/20260630T235533Z

project overlay:
  build/traceability-overlay/20260630T235558Z

semantic recheck queue:
  build/semantic-recheck/20260630T235623Z
```

## Result Summary

```text
project_drift_ok_rows=501
project_drift_gap_rows=14
project_drift_semantic_recheck_required_rows=0
project_drift_symbol_missing_rows=0
project_drift_pattern_missing_rows=0
overlay_needs_semantic_recheck_rows=0
overlay_line_only_rows=0
semantic_recheck_items=0
gap_items=14
line_only_anchor_items=0
source_only=true
semantic_validation=false
authority_claim=false
monitor_verified=false
protection_claim=false
```

## Meaning

N-112 removed all active line-only anchors from the generated project overlay by
replacing them with symbol-bearing anchors and correcting obvious stale line
targets where the current Linux source made the intended object unambiguous.

The remaining 14 rows are preserved gaps or plan rows. They are not failures of
the line-only recheck, and they are not removed obligations.

## Non-Claims

This run does not support:

```text
all project semantics are validated
gap rows are safe to ignore
runtime coverage occurred
monitor verification occurred
public tracepoint ABI is approved
behavior-changing Linux patches are approved
production protection exists
```

## Design Consequence

The next safe traceability step is gap classification: each preserved gap should
be labeled as a future Linux anchor, external monitor/root-management anchor,
trace-plan row, or intentionally unsupported extraction before it can affect an
implementation gate.
