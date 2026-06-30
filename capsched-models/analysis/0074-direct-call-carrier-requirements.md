# Analysis 0074: Direct-Call Carrier Requirements Gate

Status: Draft implementation-facing carrier requirements with model gate

Date: 2026-06-30

Related artifacts:

```text
analysis/0069-local-monitor-admission-abi-semantics.md
analysis/0071-direct-call-reference-abi-sketch.md
analysis/0073-combined-admission-carriers-plan.md
analysis/direct-call-carrier-requirements-v1.json
formal/0051-direct-call-carrier-requirements-model/
validation/0073-direct-call-carrier-requirements-tlc.md
```

## Purpose

N-101 defines implementation-facing requirements for the first concrete local
monitor admission carrier.

The recommended first carrier is:

```text
direct-call reference carrier
```

This is still not a binary ABI layout, C struct packing, syscall/VM-call/SMC/HVC
number, register convention, Linux stub, monitor implementation, or production
protection claim.

The goal is to define the constraints that a later binary/direct-call ABI must
satisfy before any code is written.

## Carrier Selection Rule

The first implementation-facing carrier should be direct-call reference first:

```text
why direct-call first:
  smallest authority state machine
  easiest request copy/freeze boundary
  simplest replay and ledger ordering
  simplest revoke slow path
  best reference for later ring refinement
```

This does not reject the ring. The ring remains the throughput direction for
data-center admission bursts. But ring work must refine the direct-call
requirements and the combined-carrier plan.

Carrier preference is performance policy, not authority.

```text
direct-call:
  reference/control carrier
  low-volume query/revoke/ring-health operations
  implementation bring-up carrier

monitor-owned ring:
  later high-throughput carrier
  admission bursts
  batchable derived receipt minting
```

Forbidden:

```text
direct-call emergency path bypasses replay or budget checks
ring future compatibility weakens direct-call requirements
carrier_kind appears in authority replay namespace
carrier selection result treated as monitor approval
```

## Request Envelope Requirements

A future direct-call request envelope must carry enough typed information for
the monitor to build a canonical request image.

Required semantic groups:

```text
version group:
  abi_version
  request_class
  request_flags
  declared_semantic_length
  field_presence_or_typed_null_map

freshness group:
  request_id
  request_nonce
  replay_window_id
  expected_monitor_epoch

cluster/local authority group:
  monitor_id
  cluster_lease_id
  cluster_epoch
  root_management_epoch
  node_id
  local_lease_id
  local_lease_epoch

caller/service/target group:
  caller_domain_id
  caller_domain_epoch
  service_domain_id
  service_domain_epoch
  target_domain_id
  target_domain_epoch

device/resource group:
  device_root_id
  device_root_epoch
  requested_receipt_classes
  requested_revoke_scope
  budget_charge_class

canonicalization group:
  request_digest_or_monitor_computed_digest
  payload_schema_id
  payload_semantic_generation
```

The exact encoding is not selected here.

Required envelope properties:

```text
bounded monitor copy
no unbounded Linux pointer chasing
no semantic dependence on C padding
no implicit ambient defaults
typed nulls for irrelevant fields
unknown request classes fail closed
unknown mandatory fields fail closed
unsupported optional fields ignored only if explicitly marked optional
```

## Copy and Freeze Requirements

The monitor validates only monitor-owned request images.

Direct-call order:

```text
1. Linux places request in Linux-visible carrier memory
2. monitor entry begins
3. monitor bounds-checks declared length against maximum class length
4. monitor copies request bytes into monitor-owned image
5. monitor canonicalizes typed fields from the copied image
6. monitor computes or verifies request digest over canonical semantics
7. monitor validates fields, epochs, policy, and replay
8. Linux post-copy mutation cannot affect the decision
```

Rejected:

```text
validate directly from Linux mutable memory
validate before bounded copy
copy length chosen by untrusted nested pointer
parse request using mutable Linux-side side tables
accept request with uninitialized padding as semantic input
```

Variable-size payloads are allowed only if the class-specific maximum is known
before the monitor copy and all nested lengths are validated from the copied
image.

## Replay Key Requirements

Replay is monitor-owned and carrier-neutral.

Minimum replay key:

```text
monitor_id
monitor_epoch
replay_window_id
request_nonce
request_class
canonical_request_digest
local_lease_id
local_lease_epoch
service_domain_id
service_domain_epoch
target_domain_id
target_domain_epoch
device_root_id
device_root_epoch
```

Policy may choose whether `canonical_request_digest` is part of the replay key
or a mismatch check attached to the key. The security requirement is:

```text
same nonce and same authority scope cannot produce two success receipts
same nonce and different canonical digest fails terminally or as replay mismatch
```

Carrier-local sequence numbers, Linux buffer addresses, direct-call entry
numbers, and later ring slot generations are audit metadata only.

## Ledger Row Requirements

Every monitor response that can affect Linux-visible state must reference
monitor-owned ledger state.

Ledger row semantic fields:

```text
ledger_row_id
ledger_row_epoch
attempt_id
attempt_epoch
request_class
canonical_request_digest
replay_key_or_replay_result
response_class
terminal_failure_reason
receipt_id_set
receipt_epoch_set
shadow_generation
revoke_epoch
carrier_kind_for_audit
budget_charge_result
monitor_epoch
```

Success requires a success ledger row. Failure, stale, replay-rejected,
malformed, budget-denied, unsupported, cancel, and supersede outcomes are
terminal for their monitor-created attempt and should be ledger-visible or
queryable as monitor state.

Rejected:

```text
response without ledger row
receipt id returned without ledger row
failure that can later become success for same attempt
Linux-written ledger row
carrier-local ledger row as endpoint authority
```

## Response Handle Requirements

A direct-call response handle is a reference to monitor-owned state, not
authority by itself.

Required response handle semantics:

```text
monitor-sealed or monitor-queryable reference
ledger_row_id
ledger_row_epoch
attempt_id
attempt_epoch
response_class
replay_result
receipt class summary
shadow_generation
monitor_epoch
revoke_epoch where relevant
carrier_kind_for_audit only
```

The response handle may be copied to Linux, but Linux cannot mint or modify a
valid handle.

Response classes that are not receipts:

```text
accepted-for-processing
carrier-busy
carrier-unavailable
timeout-observed-by-Linux
Linux-local drop
```

`timeout-observed-by-Linux` is not a monitor response. It is an observation that
must be resolved by monitor query, cancel, or supersede semantics.

## Error Class Requirements

The direct-call carrier must distinguish terminal monitor failures from
transport observations.

Terminal monitor outcomes:

```text
malformed_request
unsupported_abi_version
unknown_request_class
field_presence_or_type_mismatch
stale_monitor_epoch
stale_cluster_or_root_epoch
stale_service_domain_epoch
stale_target_domain_epoch
stale_device_root_epoch
stale_local_lease_epoch
replay_rejected
same_nonce_digest_mismatch
policy_denied
budget_denied
revoke_in_progress
cancelled_by_monitor
superseded_by_monitor
```

Transport observations:

```text
linux_timeout
linux_buffer_fault_before_monitor_copy
carrier_unavailable_before_monitor_entry
local_retry_before_monitor_attempt
```

Transport observations cannot mint receipts, refresh shadows, consume replay,
or complete revoke.

## Shadow Generation Requirements

Linux-visible shadow refresh is permitted only after monitor-owned state exists.

Allowed sources:

```text
response handle backed by monitor ledger row
monitor receipt query
monitor shadow_generation
monitor revoke query
```

Forbidden:

```text
request buffer
direct-call return code without ledger reference
Linux timeout
carrier-local sequence
future ring slot generation
```

Shadow generation is shared with the future ring carrier. It is not a
direct-call-only generation.

## Revoke and Control Lane Requirements

Direct-call first should also be the initial control carrier.

Control operations:

```text
query receipt
query shadow generation
start revoke
cancel/supersede possible in-flight attempt
query carrier health
query ring state once ring exists
```

Control priority may be higher than ordinary admission priority, but it cannot
bypass authority checks.

Revoke requires:

```text
monitor-created revoke attempt
bounded copied revoke request image
shared replay consume for the revoke attempt
old-epoch direct admission stop
old-epoch ring admission stop once ring exists
new receipt embargo
direct in-flight drain/reject/prove-newer
ring pending drain/invalidate once ring exists
derived receipt revoke
shared shadow invalidation
revoke-complete ledger row
```

## Forward-Compatible Ring Constraints

Even though the first carrier is direct-call, the requirements must leave a
place for the future ring.

Forward-compatible constraints:

```text
carrier_kind is audit metadata only
attempt ids are monitor-owned and carrier-neutral
replay namespace is carrier-neutral
ledger row shape is carrier-neutral
shadow_generation is carrier-neutral
error classes distinguish monitor terminality from transport observations
timeout remains unknown until monitor state resolves it
ring claim will be equivalent to direct monitor entry for attempt creation
ring frozen slot image will be equivalent to direct monitor copied image
```

The direct-call implementation must not define an ABI surface that makes the
ring a separate authority path later.

## Combined Invariants

```text
No validation from Linux mutable memory.
No monitor decision before bounded copy/freeze.
No request success from carrier selection alone.
No success without canonical monitor attempt.
No success without shared replay consume.
No same-nonce different-digest success.
No response handle without monitor ledger state.
No shadow refresh without monitor ledger/query and shared shadow generation.
No Linux timeout as terminal monitor failure.
No transport observation as receipt authority.
No control/revoke priority bypass of replay, budget, or epoch checks.
No carrier-local sequence number as replay authority.
No future ring incompatibility from direct-call-only replay, ledger, or shadow namespaces.
```

## Non-Goals

This note does not select:

```text
binary field packing
endianness
alignment
C struct definitions
syscall number
VMX/EL2/SMC/HVC mechanism
register convention
shared page layout
cryptographic handle format
Linux source file placement
monitor source tree
performance budget
production protection claim
```

## Consequence

The next step may define a binary ABI candidate or a no-code Linux stub
readiness map only if it preserves these requirements. A direct-call prototype
may be the first implementation carrier, but it must remain the reference
semantics for later monitor-owned ring refinement rather than becoming a
direct-only authority island.
