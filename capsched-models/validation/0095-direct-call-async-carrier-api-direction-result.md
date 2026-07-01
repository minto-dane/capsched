# Validation 0095: Direct-Call Async Carrier API Direction Result

Status: executed; no-behavior API direction checked

Date: 2026-07-01

## Inputs

```text
capsched-ai/decisions/ADR-0009-async-carrier-api-direction.md
analysis/0083-direct-call-async-carrier-api-direction.md
analysis/direct-call-async-carrier-api-direction-v1.json
analysis/0082-direct-call-async-carrier-lifetime-table.md
implementation/0011-direct-call-async-carrier-gate.md
```

## Commands

```sh
jq empty \
  capsched/capsched-models/analysis/direct-call-async-carrier-api-direction-v1.json

jq -r '
  [
    (.options | length),
    (.options | map(select(.decision == "selected")) | length),
    (.adapter_contracts | length),
    (.adapter_contracts | map(.required_hazards | length) | add),
    (.forbidden_authority_sources | length),
    (.core_contract.operations | length),
    (.core_contract.must_not_include_subsystem_verbs | length),
    ([.safety_flags[]] | map(select(. == false)) | length),
    (.safety_flags | length)
  ] | @tsv' \
  capsched/capsched-models/analysis/direct-call-async-carrier-api-direction-v1.json

jq -e '
  .selected_direction == "shared_internal_capsched_async_carrier_with_per_subsystem_adapters" and
  (.options | map(select(.decision == "selected")) | length) == 1 and
  (.adapter_contracts | map(.adapter) | sort) == ["io_uring", "workqueue"] and
  (.safety_flags | to_entries | all(.value == false))
' \
  capsched/capsched-models/analysis/direct-call-async-carrier-api-direction-v1.json
```

## Result

```text
options=3
selected_options=1
adapter_contracts=2
adapter_hazards=18
forbidden_authority_sources=18
core_operations=6
subsystem_verbs_forbidden_in_core=6
safety_flags_false=11
safety_flags_total=11
selected_direction=shared_internal_capsched_async_carrier_with_per_subsystem_adapters
adapter_set=io_uring,workqueue
all_safety_flags_false=true
```

## Meaning

N-124 chooses the next no-behavior API sketch direction:

```text
shared internal capsched_async_carrier semantic core
+
per-subsystem workqueue and io_uring adapters
```

The choice is narrow:

```text
shared:
  frozen caller authority, caller BudgetTicket, monitor receipt reference,
  generation/epoch/revoke state, service/resource binding, settlement state

separate:
  workqueue pending/coalescing/delayed-work/callback/free mechanics
  io_uring SQE/request/resource/io-wq/reissue/CQE/refcount mechanics
```

## Non-Claims

This validation does not approve Linux code, workqueue integration, io_uring
integration, direct-call ABI, public tracepoints, runtime coverage, monitor
verification, behavior change, or production protection.

