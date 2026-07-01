# Project Gap Classification Workflow v1

Status: source-only workflow

Purpose: classify preserved project overlay gaps after semantic recheck so that
they remain visible obligations instead of being mistaken for implementation
evidence.

## Inputs

```text
build/semantic-recheck/<run>/gap-preservation.tsv
build/traceability-overlay/<run>/project-overlay-ledger.json
```

## Output Classes

```text
future_linux_anchor:
  A Linux-side helper, wrapper, query, control, or internal path does not exist
  yet. This blocks implementation use until a design and source anchor exist.

future_test_anchor:
  A test-only or fault-injection surface does not exist yet. This cannot affect
  live monitor or Linux decisions.

trace_plan_row:
  A possible trace/source observation plan exists. This is not runtime coverage,
  tracefs execution, public tracepoint ABI, or authority.

external_monitor_anchor:
  The missing anchor belongs to a future HyperTag Monitor, root-management
  service, or external proof artifact rather than Linux source.

unsupported_extraction:
  The row could not be normalized mechanically and needs explicit source-map or
  extraction repair.
```

## Hard Rules

- Do not remove a gap merely because it is classified.
- Do not convert a gap into `ok`.
- Do not treat a future Linux helper as a monitor receipt or canonical authority
  image.
- Do not treat trace-plan rows as runtime observation.
- Do not use gap classification as behavior-changing Linux patch approval.

## Current Expected Shape

After N-112, the active project overlay should have:

```text
semantic_recheck_items=0
gap_items=14
```

Those 14 rows are expected to collapse into 7 semantic direct-call gap groups:

```text
request envelope builder
direct-call entry wrapper/backend
schema negotiation query
response-handle shadow refresh
control revoke lane
test-only failure-injection surface
trace-only observation surface
```

This workflow is source-only and does not claim monitor verification,
runtime coverage, authority, ABI approval, behavior change, or production
protection.
