# Validation 0093: Direct-Call Async Source Map Result

Status: executed; source-only workqueue/io_uring maps checked

Date: 2026-06-30

## Inputs

```text
analysis/0081-direct-call-async-workqueue-io-uring-source-map.md
analysis/direct-call-async-workqueue-source-map-v1.json
analysis/direct-call-async-io-uring-source-map-v1.json
implementation/0011-direct-call-async-carrier-gate.md
formal/0058-direct-call-async-carrier-model/
validation/0091-direct-call-async-carrier-tlc.md
```

## Local JSON Safety Check

Command shape:

```sh
jq empty \
  capsched/capsched-models/analysis/direct-call-async-workqueue-source-map-v1.json \
  capsched/capsched-models/analysis/direct-call-async-io-uring-source-map-v1.json

jq -r '(.source_rows | length) as $total |
  (.source_rows |
   map(select(.source_only==true and
              .observation_only==true and
              .authority_claim==false and
              .monitor_verified==false and
              .runtime_coverage==false and
              .behavior_change==false and
              .user_abi==false and
              .public_tracepoint_abi==false and
              .protection_claim==false)) | length) as $safe |
  [$total,$safe] | @tsv' ...
```

Result:

```text
workqueue_rows=19
workqueue_rows_with_required_safety_flags=19
io_uring_rows=18
io_uring_rows_with_required_safety_flags=18
```

## Project Drift

Run:

```text
/media/nia/scsiusb/dev/linux-cap/build/traceability-project-drift/20260701T025605Z
```

Result:

```text
json_artifacts_scanned=18
anchor_rows=579
ok_rows=558
gap_rows=21
path_changed_rows=0
symbol_missing_rows=0
pattern_missing_rows=0
semantic_recheck_required_rows=0
unsupported_extraction_rows=3
safety_flag_violations=0
source_only=true
semantic_validation=false
```

The new N-122 maps contributed 37 current Linux anchors:

```text
DCAWQ rows=19
DCAIO rows=18
new_rows_with_non_ok_drift=0
```

## Overlay and Recheck

Overlay run:

```text
/media/nia/scsiusb/dev/linux-cap/build/traceability-overlay/20260701T025713Z
```

Result:

```text
overlay_rows=579
ok_rows=558
gap_rows=21
needs_semantic_recheck_rows=0
line_only_rows=0
symbol_rows=397
pattern_rows=94
gap_match_rows=21
safety_flag_violations=0
n_series_rewrite=false
```

Semantic recheck run:

```text
/media/nia/scsiusb/dev/linux-cap/build/semantic-recheck/20260701T025731Z
```

Result:

```text
semantic_recheck_items=0
gap_items=21
safety_flag_violations=0
semantic_validation=false
```

Gap classification run:

```text
/media/nia/scsiusb/dev/linux-cap/build/traceability-gap-classification/20260701T025747Z
```

Result:

```text
gap_rows=21
semantic_gap_groups=7
future_linux_anchor_rows=15
future_linux_anchor_groups=5
future_test_anchor_rows=3
future_test_anchor_groups=1
trace_plan_rows=3
trace_plan_groups=1
unknown_gap_rows=0
safety_flag_violations=0
implementation_approval=false
```

## Meaning

The maps establish source-only traceability for DCASYNC-007 and DCASYNC-008:

```text
workqueue:
  generic work_struct, pending bits, worker/current_func identity, and
  flush/cancel state are not CapSched authority. Domain-originated work needs a
  typed wrapper/carrier.

io_uring:
  io_kiocb and io_rsrc_node are plausible future storage anchors, but current
  request, cred, tctx, registered-resource, cancel, completion, and retry state
  are not monitor receipt authority.
```

## Non-Claims

This validation does not approve Linux code, workqueue integration, io_uring
integration, direct-call ABI, tracepoints, runtime coverage, monitor
verification, behavior change, or production protection.
