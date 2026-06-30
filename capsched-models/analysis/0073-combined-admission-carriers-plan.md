# Analysis 0073: Combined Direct-Call and Ring Admission Carrier Plan

Status: Draft combined carrier plan with model gate

Date: 2026-06-30

Related artifacts:

```text
analysis/0069-local-monitor-admission-abi-semantics.md
analysis/0071-direct-call-reference-abi-sketch.md
analysis/0072-monitor-owned-ring-refinement-sketch.md
analysis/combined-admission-carriers-plan-v1.json
formal/0050-combined-admission-carriers-model/
validation/0072-combined-admission-carriers-tlc.md
```

## Purpose

N-100 combines the direct-call reference ABI and the monitor-owned ring
throughput refinement for `LocalMonitorAdmissionABI-v0`.

This is not a binary ABI, syscall, VM-call, SMC/HVC convention, shared-memory
layout, Linux stub, monitor implementation, or benchmark plan. It defines the
semantic join that later code must preserve.

The core objective is:

```text
direct call and monitor-owned ring are carriers of the same monitor admission
attempt semantics, not separate authority systems.
```

The ring may improve throughput. Direct calls may provide a simple reference
and fallback. Neither may mint a distinct authority path.

## Unified Admission Attempt

The monitor creates a canonical admission attempt only after one of:

```text
direct call:
  monitor entry and monitor-owned bounded request copy

ring:
  monitor slot claim and monitor-owned frozen slot image
```

Linux-visible carrier identifiers are not attempt identifiers. A direct call
sequence number, ring slot index, ring producer generation, or doorbell counter
may help find a carrier object, but it cannot authorize replay, response,
receipt, endpoint delivery, or shadow refresh.

Required canonical attempt fields:

```text
attempt_id
attempt_epoch
carrier_kind
carrier_observation_id
request_class
request_nonce
replay_window_id
monitor_id
monitor_epoch
cluster_lease_id
cluster_epoch
root_management_epoch
node_id
service_domain_id
service_domain_epoch
target_domain_id
target_domain_epoch
device_root_id
device_root_epoch
local_lease_id
local_lease_epoch
request_image_generation
receipt_ledger_row_id
response_epoch
shadow_generation
```

`carrier_observation_id` is audit metadata. `attempt_id` is monitor-owned.

## Shared Replay Namespace

Direct-call and ring attempts share the same monitor-owned replay namespace.

The replay key is at least:

```text
monitor_id
monitor_epoch
replay_window_id
request_nonce
request_class
local_lease_id
local_lease_epoch
service_domain_id
service_domain_epoch
target_domain_id
target_domain_epoch
device_root_id
device_root_epoch
```

The exact key encoding is not selected here. The semantic rule is that the
carrier is not part of the authority namespace.

Consequences:

```text
same nonce via ring then direct:
  at most one success receipt

same nonce via direct then ring:
  at most one success receipt

ring claim pending then direct fallback:
  monitor must serialize, reject, or query the shared replay state

ring full before monitor claim:
  not a monitor attempt and does not consume replay

ring full after monitor claim:
  is not "ring full"; it is a monitor-observed terminal attempt state
```

Carrier-local replay tables are forbidden. Linux-only ring generations are
performance metadata, not replay protection.

## Shared Receipt Ledger

There is one monitor-owned local receipt ledger for both carriers.

Every success response requires:

```text
canonical monitor attempt
monitor-owned frozen request image
shared replay consume
epoch validation
monitor-owned ledger row
monitor-owned response handle or published response
```

Direct-call responses and ring responses both reference the same ledger row
shape. Carrier-specific response buffers are delivery media only.

Forbidden:

```text
direct-call private success ledger
ring private success ledger
Linux service-domain success ledger
carrier-local response treated as receipt
two success rows for one replay key
```

Failure rows may also be recorded in the monitor ledger when the monitor has
created a canonical attempt. Carrier-local congestion, ring full, Linux drop,
or retry accounting without monitor claim/entry cannot become terminal monitor
authority.

## Shared Shadow Generation

Linux-visible shadow state is shared across both carriers.

Allowed shadow refresh sources:

```text
monitor response handle
monitor receipt query
monitor-owned shadow_generation
monitor-owned ledger row
```

Forbidden shadow refresh sources:

```text
direct-call request buffer
direct-call response buffer without ledger backing
ring slot payload
ring producer state
ring response cache without monitor response epoch
carrier-local generation counter
```

Shadow generation is a monitor-owned cache invalidation namespace. It is not a
per-carrier generation.

## Carrier Fallback Semantics

Fallback is allowed only as carrier substitution before authority is consumed.

Allowed examples:

```text
ring full before monitor slot claim:
  direct-call fallback may submit the same logical request
  replay has not been consumed by the ring carrier

ring unavailable by policy or feature flag:
  direct-call reference path may carry the request

direct-call congestion:
  ring path may carry later requests if monitor policy allows it
```

Constrained examples:

```text
ring slot claimed but response pending:
  direct-call fallback must not mint a second success
  direct path must query/serialize/reject against shared replay state

direct call in-flight:
  ring fallback must not mint a second success
  ring path must query/serialize/reject against shared replay state

terminal failure for same replay key:
  later fallback cannot turn the attempt into success
```

Timeout is not failure:

```text
missing ring response:
  unknown until monitor ledger/query says otherwise

claimed-or-possibly-claimed ring slot:
  direct fallback must be query, cancel, or supersede under monitor control
  not a fresh admission story

same nonce with different frozen payload digest:
  terminal mismatch or replay/stale rejection
  never "try the other carrier and accept"
```

Fallback is not a bypass lane. It is a transport retry before monitor authority
has been consumed, or a monitor-mediated query after it has.

## Shared Revoke Ordering

Revoke crosses both carriers.

Required ordering:

```text
1. monitor marks revoke started for local_lease_id/local_lease_epoch
2. monitor stops old-epoch admission on direct-call carrier
3. monitor stops old-epoch admission on ring carrier
4. monitor embargoes new receipts for the old local lease epoch
5. monitor drains, rejects, or proves-newer all relevant direct in-flight calls
6. monitor drains or invalidates all relevant ring claimed slots
7. monitor drains or invalidates all relevant ring pending responses
8. monitor revokes derived queue/DMA/IRQ/ledger/endpoint receipts
9. monitor invalidates the shared shadow_generation
10. monitor writes revoke-complete ledger row
```

Stopping only one carrier is invalid. A revoke-complete response while the
other carrier can still publish an old-epoch success is a protection failure,
not an availability detail.

## Multi-Cluster and Single-OS Implications

For a data-center single-OS substrate, local monitor admission must compose
with cluster authority without making a global lock the fast path.

The local replay and receipt keys therefore include:

```text
root_management_epoch
cluster_epoch
node_id
monitor_id
monitor_epoch
local_lease_id
local_lease_epoch
```

The root-management plane issues cluster intent. The local monitor compiles it
into local receipts. Direct-call and ring carriers exist inside a local monitor
authority boundary and must not reinterpret cluster intent independently.

This keeps the cluster-scale rule:

```text
global uniqueness is carried by cluster/root epochs and lease identity
local performance is handled by per-monitor replay windows and ledgers
```

## Performance and Liveness Notes

The ring exists for throughput:

```text
batching
lower transition amortization
per-node request queueing
admission burst smoothing
NUMA-friendly service Domain placement
```

Carrier selection guidance:

```text
direct-call:
  reference path
  low-volume query/control/revoke/ring-health operations
  emergency shadow refresh, still budgeted and monitor-validated

monitor-owned ring:
  high-churn QueueLease/DMA/IRQ/endpoint receipt minting
  batched local admission
  service-domain admission bursts
```

But performance metadata is never authority:

```text
queue depth
ring full count
drop count
batch size
transition cost
service latency
carrier preference
```

These may influence carrier selection and scheduling policy. They cannot
authorize responses, receipt creation, shadow refresh, replay acceptance, or
revoke completion.

The ring must not amplify revoke latency:

```text
bounded batch quanta
priority control/revoke lane or equivalent monitor preemption
monitor-invalidatable pending responses
no dependence on compromised Linux consuming responses
```

## Combined Invariants

```text
No carrier-local admission authority.
No carrier-local replay namespace.
No carrier-local success ledger.
No carrier-local shadow generation.
No response without shared monitor ledger state.
No success without canonical monitor attempt.
No success without shared replay consume.
No duplicate success across direct/ring fallback for one replay key.
No carrier fallback after claim/entry that bypasses shared replay state.
No ring-full/drop accounting as monitor terminal authority before claim.
No old-epoch admission on either carrier after revoke start.
No revoke complete before both carriers stop old-epoch admission.
No revoke complete before direct in-flight calls drain or reject.
No revoke complete before ring claimed slots and pending responses drain.
No revoke complete before derived receipts revoke and shadow invalidation.
No epoch split between carrier-visible request and monitor ledger row.
```

## Non-Goals

This note does not choose:

```text
binary ABI layout
direct-call trap mechanism
ring memory layout
doorbell or interrupt mechanism
monitor implementation language
Linux stub file locations
cryptographic seal format
performance budget
production protection claim
```

## Consequence

The next code-facing ABI work must cite this combined plan and state which
carrier semantics it implements first. Implementing only direct call is allowed
as a reference path. Implementing ring is allowed only if it refines the shared
attempt/replay/ledger/shadow/revoke model rather than creating carrier-local
authority.
