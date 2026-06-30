# Analysis 0068: Local Monitor Admission Carrier and Receipt Storage

Status: Draft choice gate with model

Date: 2026-06-30

Related artifacts:

```text
analysis/0067-local-monitor-admission-interface-boundary.md
analysis/local-monitor-admission-carrier-storage-v1.json
formal/0045-monitor-admission-carrier-storage-model/
validation/0067-monitor-admission-carrier-storage-tlc.md
```

## Purpose

N-095 compares carrier and receipt-storage choices for local monitor admission
before selecting a concrete monitor ABI, Linux service-domain stub, shared ring,
or receipt cache.

The core rule is:

```text
carrier transports a request
receipt proves monitor admission
Linux-visible state may cache or route
Linux-visible state must not become the authority root
```

This distinction is mandatory for the HyperTag design. A Linux service Domain
may be compromised. Therefore any design where Linux service-domain state can
mint, replay, or substitute a monitor response is rejected.

## Terms

```text
request carrier:
  A synchronous call, ring slot, service queue item, or feed item that asks the
  local monitor to admit or revoke something.

monitor response:
  A monitor-minted success or failure response bound to monitor epoch, request
  nonce, target Domain epoch, service Domain epoch, device root epoch, and local
  lease epoch.

monitor receipt:
  A durable or queryable monitor-owned fact that a local lease, device root,
  queue, DMA MemoryView, IRQ route, ledger root, endpoint, or revoke state is
  valid for an epoch.

Linux shadow:
  A Linux-visible copy, index, cache, trace row, or acceleration hint derived
  from monitor receipts.

authority root:
  The state that decides whether endpoint delivery, hardware programming, or
  lease reuse is allowed.
```

Only the monitor live state and monitor-owned receipt ledger may be the
authority root.

## Candidate Choices

| Choice | Accepted role | Rejected role | Notes |
| --- | --- | --- | --- |
| Direct monitor call | Baseline synchronous request/response carrier | Linux-owned response authority | Smallest correctness baseline; poor batching, good for first monitor ABI model. |
| Monitor-owned shared ring | High-throughput request/response carrier with monitor-owned slot epochs | Ring slot as replayable receipt | Requires monitor-owned head/tail or sealed slot generation, request nonce, and response epoch. |
| Linux service-domain queue | Request buffering and ordering hint only | Admission source of truth | Compromised service Domain may drop/reorder/DoS, but must not authorize. |
| Root-management feed | Cluster policy input to local monitor | Local lease by itself | Remote ClusterLease must compile into a local monitor receipt before use. |
| Monitor receipt ledger | Recommended authority store | Mutable Linux log | Must be monitor-owned, epoch-indexed, revoke-aware, and queryable or sealed. |
| Linux-visible shadow state | Cache, index, trace, fast-path hint | Authority root | Corruption or loss must cause slow path or fail-closed, not endpoint grant. |
| Audit-only log | Evidence for debugging and assurance | Runtime authority | Audit rows can explain decisions but cannot authorize future actions. |
| Raw driver handles | Internal service-domain implementation detail | Target Domain endpoint | PF/VF/IOMMU/MSI/devlink handles cannot escape as Domain endpoint authority. |

## Recommended Shape

The current preferred semantic shape is:

```text
correctness baseline:
  direct monitor call

throughput extension:
  monitor-owned shared admission ring

authority storage:
  monitor live state + monitor-owned append-only receipt ledger

Linux service-domain queue:
  request carrier only

Linux-visible shadow:
  non-authoritative cache/index/trace derived from receipts

target endpoint:
  materialized only from monitor-verified receipts
```

This is not yet a selected ABI. It is a filter for future ABI choices.

## Security Invariants

```text
No Linux-owned response store as authority.
No service-domain queue item as authority.
No Linux shadow state as authority.
No replayed ring slot accepted as a fresh response.
No tampered receipt ledger accepted.
No request carrier treated as a receipt.
No audit-only log treated as authority.
No raw service-domain device handle delivered as target endpoint.
No endpoint delivery without monitor-minted and monitor-verified receipt state.
```

## Performance and Scalability Dimensions

The carrier choice affects cost but must not weaken authority:

```text
direct monitor call:
  low design ambiguity, higher per-admission transition cost

monitor-owned shared ring:
  better batching and multi-queue scaling, stronger replay and slot-ownership
  requirements

service-domain queue:
  good integration with Linux driver/service scheduling, but authority collapse
  risk is high unless it remains request-only

monitor receipt ledger:
  supports revoke, audit root, replay detection, and multi-cluster handoff, but
  requires careful lookup and cache invalidation design

Linux shadow:
  useful for fast lookup and tracing, but must be treated as a hint
```

For a data-center OS, the likely scalable path is direct calls for the first
correct monitor ABI plus a monitor-owned shared ring and receipt ledger for
high-throughput cluster nodes.

## Multi-Cluster Implication

Cluster-level authority should enter the node as policy input, not as a local
lease:

```text
root-management ClusterLease
  -> local monitor import and epoch check
  -> LocalDomainDeviceLease receipt
  -> Queue/DMA/IRQ/endpoint receipts
```

This keeps the "single OS across clusters" goal compatible with local hardware
ownership. A remote or cluster policy plane may authorize intent, but only the
local monitor can bind that intent to local CPU, memory, IOMMU, queue, and IRQ
facts.

## Rejected Collapses

The following are explicitly rejected:

```text
Linux queue item == successful monitor response
Linux shadow state == receipt ledger
trace/audit row == authority
ring slot generation controlled only by Linux == replay protection
service Domain PF/VF handle == target endpoint
root-management feed == local device lease without local monitor compilation
```

## Consequence for Future Implementation

The next implementation-facing design can choose an ABI only if it preserves
these properties:

```text
monitor controls response minting
monitor controls receipt storage or sealing
monitor can reject stale/replayed carrier entries
Linux service queues are request-only
Linux shadows are non-authoritative
endpoint delivery has a monitor receipt verification step
revoke invalidates both monitor receipts and Linux shadows
```

Until those properties are represented in code and validation, this remains
semantic evidence only. It is not a monitor ABI, Linux patch plan, or production
protection claim.
