# Validation 0077: Direct-Call Inventory Runner Result

Status: Executed; source-only inventory emitted

Date: 2026-06-30

Runner:

```text
capsched/capsched-models/validation/run-direct-call-inventory.sh
```

Related artifacts:

```text
analysis/0077-direct-call-trace-source-inventory-contract.md
analysis/direct-call-trace-source-inventory-contract-v1.json
formal/0054-direct-call-inventory-contract-model/
validation/0076-direct-call-inventory-contract-tlc.md
```

Run directory:

```text
/media/nia/scsiusb/dev/linux-cap/build/direct-call-inventory/20260630T215918Z
```

Output files:

```text
inventory-ledger.tsv
inventory-ledger.json
tracefs-plan.txt
semantic-gaps.tsv
summary.txt
metadata.txt
```

## Result Summary

```text
ledger_rows=10
available_rows=3
future_gap_rows=6
trace_plan_rows=1
gap_rows=7
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

## Current Anchors Observed

The runner found the current inert CapSched anchors:

```text
include/linux/capsched.h:
  struct capsched_domain pattern found

kernel/sched/capsched.c:
  intentionally inert marker found

kernel/sched/Makefile:
  obj-$(CONFIG_CAPSCHED) += capsched.o pattern found
```

These are source observations only. They do not implement direct-call
admission, monitor verification, or protection.

## Gap Rows

The runner emitted expected future gaps for:

```text
request_envelope_builder
direct_call_entry_shape
schema_negotiation_probe
response_handle_shadow_refresh
control_revoke_lane
failure_injection_surface
```

It also emitted one trace-plan row:

```text
trace_only_observation_surface:
  existing tracefs-plan suggestions only
  no tracefs execution
  no runtime observation claim
```

## Validated Claim

This run supports only:

```text
The N-104 source-only direct-call inventory runner can emit the required ledger,
JSON, tracefs-plan, gap, summary, and metadata files from the current Linux
source tree without modifying Linux, requiring root, writing tracefs, attaching
probes, creating public tracepoint ABI, or producing authority/protection
claims.
```

It does not support:

```text
direct-call admission exists
monitor verification occurred
tracefs runtime coverage occurred
source anchors provide authority
missing anchors remove semantic obligations
Linux timeout has monitor meaning
public tracepoint ABI is approved
production protection exists
```

## Design Consequence

N-105 is satisfied as a source-only runner implementation and execution.

The next safe step is one of:

```text
1. broaden the source-only inventory to check more existing trace event source
   declarations and symbol candidates
2. add a separate privileged tracefs runbook/result for operator-approved
   runtime observation, still with observation_only=true
3. return to modeling direct-call request/response C layout constraints before
   any Linux stub
```

None of these may claim monitor-backed protection.
