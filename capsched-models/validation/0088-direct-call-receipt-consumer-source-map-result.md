# Validation 0088: Direct-Call Receipt Consumer Source Map Result

Status: executed, source-only

Date: 2026-06-30

## Inputs

```text
analysis/0080-direct-call-receipt-consumer-source-map.md
analysis/direct-call-receipt-consumer-source-map-v1.json
analysis/0079-direct-call-monitor-receipt-schema.md
implementation/0009-direct-call-gap-closure-gate.md
traceability/check-project-source-map-drift.sh
traceability/build-project-overlay-ledger.sh
traceability/build-semantic-recheck-queue.sh
traceability/classify-project-gaps.sh
```

## Commands

```sh
jq empty capsched/capsched-models/analysis/direct-call-receipt-consumer-source-map-v1.json

jq -r '.receipt_consumer_rows as $rows |
  [$rows|length,
   ($rows |
    map(select(.authority_claim==false and
               .monitor_verified==false and
               .behavior_change==false and
               .user_abi==false and
               .public_tracepoint_abi==false and
               .protection_claim==false)) | length)] | @tsv' \
  capsched/capsched-models/analysis/direct-call-receipt-consumer-source-map-v1.json

CAPSCHED_RUN_ID=20260701T020900Z \
  bash capsched/capsched-models/traceability/check-project-source-map-drift.sh

CAPSCHED_RUN_ID=20260701T020930Z \
CAPSCHED_PROJECT_DRIFT_DIR=/media/nia/scsiusb/dev/linux-cap/build/traceability-project-drift/20260701T020900Z \
  bash capsched/capsched-models/traceability/build-project-overlay-ledger.sh

CAPSCHED_RUN_ID=20260701T020945Z \
CAPSCHED_PROJECT_OVERLAY_JSON=/media/nia/scsiusb/dev/linux-cap/build/traceability-overlay/20260701T020930Z/project-overlay-ledger.json \
  bash capsched/capsched-models/traceability/build-semantic-recheck-queue.sh

CAPSCHED_RUN_ID=20260701T020955Z \
CAPSCHED_PROJECT_OVERLAY_JSON=/media/nia/scsiusb/dev/linux-cap/build/traceability-overlay/20260701T020930Z/project-overlay-ledger.json \
CAPSCHED_GAP_PRESERVATION_TSV=/media/nia/scsiusb/dev/linux-cap/build/semantic-recheck/20260701T020945Z/gap-preservation.tsv \
  bash capsched/capsched-models/traceability/classify-project-gaps.sh
```

## Result

`direct-call-receipt-consumer-source-map-v1.json` is valid JSON.

Receipt-consumer row safety flags:

```text
rows=27
rows_with_required_false_safety_flags=27
```

Project source-map drift:

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
source_only=true
semantic_validation=false
authority_claim=false
monitor_verified=false
protection_claim=false
```

Project overlay:

```text
run: build/traceability-overlay/20260701T020930Z
overlay_rows=542
ok_rows=521
gap_rows=21
needs_semantic_recheck_rows=0
line_only_rows=0
symbol_rows=397
pattern_rows=57
gap_match_rows=21
safety_flag_violations=0
semantic_validation=false
n_series_rewrite=false
```

Semantic recheck queue:

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

Gap classification:

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

The 21 preserved gap rows collapse into the same 7 semantic direct-call gap
groups as before. N-117 adds a third source-map view of those gaps through the
receipt-consumer lens; it does not resolve them.

## Non-Claims

This validation does not prove:

```text
Linux direct-call stubs exist
direct-call ABI is approved
monitor behavior is verified
runtime trace coverage occurred
scheduler behavior changed
production protection exists
```

The source-map rows are drift-tracking evidence only. The `ok_rows` count means
path/pattern anchors still exist in the checked Linux tree, not that the source
regions semantically implement CapSched.

