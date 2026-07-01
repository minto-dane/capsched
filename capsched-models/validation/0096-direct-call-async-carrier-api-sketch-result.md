# Validation 0096: Direct-Call Async Carrier API Sketch Result

Status: executed; no-behavior API sketch checked

Date: 2026-07-01

## Inputs

```text
implementation/0012-direct-call-async-carrier-api-sketch.md
implementation/direct-call-async-carrier-api-sketch-v1.json
capsched-ai/decisions/ADR-0009-async-carrier-api-direction.md
analysis/0083-direct-call-async-carrier-api-direction.md
implementation/0011-direct-call-async-carrier-gate.md
analysis/0082-direct-call-async-carrier-lifetime-table.md
formal/0058-direct-call-async-carrier-model/
```

## Commands

```sh
jq empty \
  capsched/capsched-models/implementation/direct-call-async-carrier-api-sketch-v1.json

jq -r '
  [
    (.core.authority_fields | length),
    (.core.authority_fields | map(select(.linux_minted_authority == false)) | length),
    (.core.lifetime_helpers | length),
    (.core.lifetime_helpers | map(select(.authority_granting == false)) | length),
    (.core.operations | length),
    (.core.operations | map(select(.subsystem_specific == false)) | length),
    (.adapter_contracts | length),
    (.adapter_contracts | map(.adapter_steps | length) | add),
    (.invariants | length),
    (.forbidden_authority_sources | length),
    (.patch_preconditions | length),
    (.postponed | length),
    (.required_future_models | length),
    (.red_flags | length),
    ([.safety_flags[]] | map(select(. == false)) | length),
    (.safety_flags | length)
  ] | @tsv' \
  capsched/capsched-models/implementation/direct-call-async-carrier-api-sketch-v1.json

jq -e '
  (.core.operations | map(.name) | sort) ==
    ["bind","freeze","release","revoke_check","settle","validate"] and
  (.adapter_contracts | map(.adapter) | sort) == ["io_uring","workqueue"] and
  (.safety_flags | to_entries | all(.value == false)) and
  (.core.ownership_boundary.release_must_not | length) >= 7 and
  (.core.single_assignment.forbidden_overwriters | length) >= 10
' \
  capsched/capsched-models/implementation/direct-call-async-carrier-api-sketch-v1.json
```

## Result

```text
authority_fields=8
authority_fields_with_linux_minted_authority_false=8
lifetime_helpers=4
lifetime_helpers_with_authority_granting_false=4
core_operations=6
core_operations_subsystem_specific_false=6
adapter_contracts=2
adapter_steps=18
invariants=15
forbidden_authority_sources=18
patch_preconditions=14
postponed_items=15
required_future_models=5
red_flags=9
safety_flags_false=12
safety_flags_total=12
core_operations=bind,freeze,release,revoke_check,settle,validate
adapter_set=io_uring,workqueue
all_safety_flags_false=true
release_must_not_couple_to_linux_cleanup=true
single_assignment_forbidden_overwriters_present=true
```

## Meaning

N-125 defines a no-behavior API sketch:

```text
shared internal capsched_async_carrier core:
  freeze, bind, validate, revoke_check, settle, release

workqueue adapter:
  wrapper/container for Domain-originated work only

io_uring adapter:
  explicit request/resource carrier only
```

The sketch preserves the N-124 rule that the core is shared authority state,
not shared Linux async execution.

## Non-Claims

This validation does not approve Linux code, workqueue integration, io_uring
integration, direct-call ABI, public tracepoints, runtime coverage, monitor
verification, behavior change, or production protection.
