# Validation 0090: Direct-Call Receipt Consumer Placement Gate Result

Status: executed, source-only gate validation

Date: 2026-06-30

## Inputs

```text
implementation/0010-direct-call-receipt-consumer-placement-gate.md
implementation/direct-call-receipt-consumer-placement-gate-v1.json
formal/0057-direct-call-receipt-consumer-placement-model/
validation/0089-direct-call-receipt-consumer-placement-tlc.md
analysis/direct-call-receipt-consumer-source-map-v1.json
```

## Commands

```sh
jq empty \
  capsched/capsched-models/implementation/direct-call-receipt-consumer-placement-gate-v1.json

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
   $flags.behavior_change,
   $flags.public_tracepoint_abi,
   $flags.protection_claim] | @tsv' \
  capsched/capsched-models/implementation/direct-call-receipt-consumer-placement-gate-v1.json
```

## Result

```text
gate_rows=7
gate_rows_with_required_preconditions_forbidden_fallbacks_and_patch_precondition=7
implementation_approval=false
authority_claim=false
monitor_verified=false
behavior_change=false
public_tracepoint_abi=false
protection_claim=false
```

## Gate Meaning

The gate translates formal/0057 into implementation-facing blockers:

```text
DCPGATE-001 receipt provenance root
DCPGATE-002 hot-path bounded consumption
DCPGATE-003 policy and lifecycle separation
DCPGATE-004 generic async exclusion
DCPGATE-005 future gap preservation
DCPGATE-006 revoke and shadow invalidation
DCPGATE-007 evidence class split
```

## Non-Claims

This validation does not approve Linux code, direct-call ABI, tracepoints,
runtime coverage, monitor verification, behavior change, or production
protection.

