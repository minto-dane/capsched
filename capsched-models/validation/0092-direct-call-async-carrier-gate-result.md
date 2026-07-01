# Validation 0092: Direct-Call Async Carrier Gate Result

Status: executed, source-only gate validation

Date: 2026-06-30

## Inputs

```text
implementation/0011-direct-call-async-carrier-gate.md
implementation/direct-call-async-carrier-gate-v1.json
formal/0058-direct-call-async-carrier-model/
validation/0091-direct-call-async-carrier-tlc.md
```

## Commands

```sh
jq empty \
  capsched/capsched-models/implementation/direct-call-async-carrier-gate-v1.json

jq -r '.gate_rows as $rows | .safety_flags as $flags |
  [($rows|length),
   ($rows |
    map(select(.gate_id and
               (.required_preconditions|length > 0) and
               (.forbidden_fallbacks|length > 0) and
               .patch_precondition)) | length),
   $flags.implementation_approval,
   $flags.authority_claim,
   $flags.monitor_verified,
   $flags.runtime_coverage,
   $flags.behavior_change,
   $flags.public_tracepoint_abi,
   $flags.protection_claim] | @tsv' \
  capsched/capsched-models/implementation/direct-call-async-carrier-gate-v1.json
```

## Result

```text
gate_rows=9
gate_rows_with_required_preconditions_forbidden_fallbacks_and_patch_precondition=9
implementation_approval=false
authority_claim=false
monitor_verified=false
runtime_coverage=false
behavior_change=false
public_tracepoint_abi=false
protection_claim=false
```

## Gate Meaning

The gate translates formal/0058 into implementation-facing blockers:

```text
DCASYNC-001 typed carrier identity
DCASYNC-002 pending coalescing preservation
DCASYNC-003 caller BudgetTicket ownership
DCASYNC-004 service and caller intersection
DCASYNC-005 monitor receipt provenance
DCASYNC-006 revoke and stale carrier rejection
DCASYNC-007 workqueue patch boundary
DCASYNC-008 io_uring patch boundary
DCASYNC-009 evidence class split
```

## Non-Claims

This validation does not approve Linux code, workqueue integration, io_uring
integration, direct-call ABI, tracepoints, runtime coverage, monitor
verification, behavior change, or production protection.
