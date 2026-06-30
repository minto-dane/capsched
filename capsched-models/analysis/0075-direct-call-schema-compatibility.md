# Analysis 0075: Direct-Call Semantic Schema and Compatibility

Status: Draft semantic schema candidate with model gate

Date: 2026-06-30

Related artifacts:

```text
analysis/0074-direct-call-carrier-requirements.md
analysis/direct-call-schema-compatibility-v1.json
formal/0052-direct-call-schema-compatibility-model/
validation/0074-direct-call-schema-compatibility-tlc.md
```

## Purpose

N-102 defines the first direct-call semantic schema compatibility candidate for
`LocalMonitorAdmissionABI-v0`.

This is not binary packing, C struct layout, endianness, register convention,
syscall/VM-call/SMC/HVC selection, Linux stub code, monitor code, ring layout,
or a production protection claim.

It defines how a future direct-call carrier can negotiate semantic schemas and
fail closed when a request, response, ledger row, error namespace, or feature
set is not understood.

## Candidate Name

```text
DirectCallSemanticSchema-v0
```

`v0` is a semantic schema candidate, not a stable binary ABI.

## Schema Objects

The monitor owns schema acceptance.

Schema objects:

```text
abi_family:
  LocalMonitorAdmissionABI

semantic_schema_id:
  DirectCallSemanticSchema-v0 or later semantic schema id

request_class_schema_id:
  schema for a specific request class

response_schema_id:
  schema for response handle semantics

ledger_schema_id:
  schema for monitor ledger row semantics

error_namespace_id:
  schema for stable terminal/transport outcome classes

feature_set_id:
  named set of semantic features and required behavior
```

Linux may propose a schema id and feature set. The monitor decides whether the
proposal is acceptable.

## Negotiation Rules

A direct-call request is eligible for monitor processing only if:

```text
abi_family matches LocalMonitorAdmissionABI
semantic_schema_id is supported by the monitor
request_class_schema_id is supported for the request class
response_schema_id is supported or safely translatable
ledger_schema_id is supported by the monitor
error_namespace_id is supported or safely translatable
all mandatory fields are known and valid
all required features are supported
monitor policy minimum schema is satisfied
caller-declared minimum schema is satisfied
no forbidden field is present
no critical unknown field is present
```

If any required part is missing or unsupported, the monitor returns a terminal
schema failure or rejects before creating a success-capable attempt. Such a
failure cannot mint receipts or refresh shadows.

## Mandatory, Optional, and Forbidden Fields

Every field in a request-class schema has:

```text
field_id
field_type
presence:
  mandatory | optional | forbidden
criticality:
  critical | noncritical
nullability:
  typed_null_allowed | typed_null_forbidden
maximum_semantic_length
digest_participation
replay_key_participation
authority_effect
```

Rules:

```text
missing mandatory field:
  fail closed

unknown mandatory field:
  fail closed

unknown critical optional field:
  fail closed

unknown noncritical optional field:
  may be ignored only if the response records it was ignored

forbidden field present:
  fail closed

typed null where forbidden:
  fail closed

implicit default for absent field:
  forbidden
```

An ignored optional field must not affect authority. The response must expose
the accepted feature set or ignored optional set so Linux cannot believe the
monitor enforced a feature it ignored.

## Canonical Digest and Replay

The canonical request digest is over semantic content, not binary padding.

Digest input includes:

```text
abi_family
semantic_schema_id
request_class_schema_id
request_class
known mandatory fields
known accepted optional fields
typed-null declarations
accepted feature set
authority-relevant epochs and ids
```

Digest input excludes:

```text
binary padding
Linux buffer address
carrier sequence number
ignored noncritical optional field payload
future ring slot generation
```

Replay protection uses the shared replay namespace from N-100/N-101. The
schema id and accepted feature set must be bound into either the replay key or
the canonical digest.

Security rule:

```text
same nonce + same authority scope + incompatible schema/digest mismatch
  cannot become success via retry, fallback, or schema downgrade
```

## Downgrade Rejection

Downgrade is forbidden when it would remove a required safety property.

The monitor tracks:

```text
monitor_min_schema
monitor_supported_schema_set
monitor_required_feature_set
caller_min_schema
request_declared_schema
request_required_feature_set
```

Accept only if:

```text
request_declared_schema >= monitor_min_schema
request_declared_schema >= caller_min_schema
request_required_feature_set subset monitor_supported_feature_set
monitor_required_feature_set subset request_effective_feature_set
```

An attacker must not be able to strip fields or lower schema ids to remove:

```text
bounded copy/freeze
canonical digest
shared replay
ledger-backed response
shared shadow generation
timeout-as-unknown
carrier-neutral namespace
budget/epoch checks
```

## Response Schema Requirements

Response handles must name their semantic schema.

Required response semantic fields:

```text
response_schema_id
ledger_schema_id
error_namespace_id
accepted_schema_id
accepted_feature_set
ignored_optional_field_set
ledger_row_id
ledger_row_epoch
attempt_id
attempt_epoch
response_class
terminal_or_transport_outcome
receipt_summary
shadow_generation
monitor_epoch
revoke_epoch
```

If the response schema is unsupported by Linux, Linux may query the monitor or
fail closed. Unsupported response interpretation must not create authority.

## Ledger Schema Requirements

The ledger schema is monitor-owned and carrier-neutral.

Ledger row schema must include:

```text
ledger_schema_id
semantic_schema_id
request_class_schema_id
response_schema_id
error_namespace_id
accepted_feature_set
canonical_request_digest
replay_result
terminal_or_success_outcome
receipt ids and epochs
shadow_generation
revoke_epoch
carrier_kind_for_audit
```

The future ring carrier must write rows of the same semantic ledger shape.

## Error Namespace Requirements

The error namespace must be stable enough for fail-closed interpretation.

Rules:

```text
unknown success code:
  fail closed

unknown terminal failure code:
  treat as terminal non-success

unknown transport observation code:
  treat as non-authoritative unknown and query/fail closed

transport observation:
  cannot consume replay, mint receipt, or refresh shadow

terminal monitor failure:
  may be ledger-visible but cannot become later success for the same attempt
```

The stable categories are:

```text
success
terminal_monitor_failure
replay_or_stale_rejection
schema_or_field_rejection
policy_or_budget_rejection
revoke_or_cancel_terminal
transport_observation
unknown_non_authority
```

## Forward Compatibility With Ring

The schema must not make direct-call an authority island.

Forward-compatible rules:

```text
schema ids are carrier-neutral
request_class_schema_id is shared by direct and ring
response_schema_id is shared by direct and ring or explicitly translatable
ledger_schema_id is shared by direct and ring
error_namespace_id is shared by direct and ring
accepted_feature_set is carrier-neutral
carrier_kind is audit metadata only
ring claim freezes the same semantic schema as direct monitor copy
ring response references the same ledger schema
```

## Combined Invariants

```text
No accept on unsupported semantic schema.
No accept when monitor minimum schema is not satisfied.
No accept when caller minimum schema is not satisfied.
No accept with missing or unknown mandatory fields.
No accept with unknown critical optional fields.
No authority from ignored noncritical optional fields.
No success unless accepted feature set covers monitor-required features.
No downgrade that removes bounded copy, digest, replay, ledger, shadow, timeout, carrier-neutral namespace, budget, or epoch checks.
No success response without compatible response and ledger schema.
No shadow refresh from unsupported response interpretation.
No unknown success code.
No transport observation as receipt authority.
No direct-only schema namespace that prevents ring refinement.
```

## Non-Goals

This note does not select:

```text
numeric schema ids
binary field encodings
endianness
alignment
C struct layout
TLV versus fixed header
syscall or monitor-call mechanism
cryptographic handle format
Linux source file placement
monitor source tree
performance budget
production protection claim
```

## Consequence

The next binary or no-code ABI readiness work must preserve this schema
compatibility gate. Any prototype that accepts unknown mandatory fields,
downgrades away required features, treats unknown success as success, or
creates direct-only schema namespaces is rejected before implementation.
