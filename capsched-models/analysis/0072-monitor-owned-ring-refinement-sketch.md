# Analysis 0072: Monitor-Owned Ring Refinement Sketch

Status: Draft throughput refinement sketch with model gate

Date: 2026-06-30

Related artifacts:

```text
analysis/0071-direct-call-reference-abi-sketch.md
analysis/monitor-owned-ring-refinement-sketch-v1.json
formal/0049-monitor-owned-ring-refinement-model/
validation/0071-monitor-owned-ring-refinement-tlc.md
```

## Purpose

N-099 defines the monitor-owned ring refinement sketch for
`LocalMonitorAdmissionABI-v0`.

This is not a binary ring layout, shared-memory format, doorbell mechanism,
Linux stub, monitor implementation, or performance benchmark.

It is the throughput refinement that must preserve the direct-call reference
ABI semantics while allowing batching and lower transition amortization.

## Core Rule

```text
Linux may write request payloads into a carrier ring.
Only the monitor may claim a slot as an admission attempt.
Only the monitor-owned claimed slot image may be validated.
Only the monitor may publish success/failure responses.
Only the monitor ledger is receipt authority.
```

Ring state is a carrier. It is not authority.

## Ring Ownership Split

```text
Linux-writable:
  request payload area
  producer hint
  doorbell hint

Monitor-owned:
  slot claim bit/epoch
  slot generation
  batch epoch
  replay-window state
  response epoch
  response publication state
  receipt ledger
  revoke/drain state
```

Linux-owned head/tail/generation is not sufficient for replay protection.

## Request Path

Reference ring path:

```text
Linux writes bounded request payload into free slot
  -> Linux rings doorbell or otherwise signals monitor
  -> monitor claims slot with monitor-owned slot epoch/generation
  -> monitor freezes slot payload into monitor-owned request image
  -> monitor validates copied/frozen request image
  -> monitor checks batch epoch and local lease epoch
  -> monitor consumes replay window
  -> monitor writes receipt ledger row
  -> monitor publishes response with monitor-owned response epoch
  -> Linux consumes response handle
  -> Linux refreshes non-authoritative shadow from monitor ledger/handle
```

Linux post-submit mutation is ignored after monitor claim. A new request
requires a new slot generation or a fresh monitor claim under a fresh epoch.

## Batch Boundary

Batching is allowed only within stable authority epochs:

```text
monitor epoch
local lease epoch
service Domain epoch
target Domain epoch
device root epoch
slot epoch
batch epoch
revoke epoch
```

The monitor must not let one batch straddle a revoke or epoch transition as if
all entries had the same authority.

## Response Publication

Response publication requires:

```text
monitor slot claim
frozen request image
request validation outcome
replay-window consume or terminal replay/stale rejection
ledger write for success or terminal failure fact
monitor-owned response epoch
```

Linux may observe or consume the response. Linux may not publish it.

## Shadow Refresh

Linux-visible shadow refresh is allowed only from:

```text
monitor response handle
monitor receipt query
monitor shadow generation
```

It is rejected from:

```text
ring slot payload
Linux producer state
doorbell state
Linux-visible response cache without monitor epoch
```

## Revoke and Drain

Revoke ordering for the ring refinement:

```text
1. monitor marks revoke started
2. monitor stops accepting old-epoch slots
3. monitor embargoes new receipts for old local lease epoch
4. monitor drains or invalidates pending claimed slots
5. monitor drains or invalidates pending responses
6. monitor revokes derived queue/DMA/IRQ/ledger/endpoint receipts
7. monitor invalidates Linux shadow generation
8. monitor writes revoke-complete ledger row
```

Revoke complete before pending slot/response drain is rejected.

## Ring Full and DoS Accounting

Ring full, dropped request, or throttled request is availability/accounting
state, not admission authority.

Required rule:

```text
ring-full or drop accounting may produce a terminal failure/accounting event
but cannot mint a success receipt, refresh a shadow, or bypass replay checks.
```

This matters because a compromised Linux service Domain can cause backpressure
or drops. That must be DoS, not authority confusion.

## Refinement Relation to Direct Call

For every successful ring admission there must be an equivalent direct-call
semantic trace:

```text
monitor entry/claim
monitor-owned request image
validation
replay consume
ledger write
response handle
non-authoritative shadow refresh
```

The ring adds batching and slot state, but must not remove or weaken any
direct-call safety property.

## Ring-Specific Invariants

```text
No Linux ring slot as authority.
No monitor response before monitor slot claim.
No validation from mutable Linux slot payload after claim.
No slot reuse without monitor-owned generation advance.
No batch crosses epoch/revoke boundary.
No ledger write before replay consume.
No Linux-published success response.
No shadow refresh from ring payload or producer state.
No revoke complete before pending claimed slots are drained or invalidated.
No revoke complete before pending responses are drained or invalidated.
No ring-full/drop/DoS accounting as success authority.
```

## Non-Goals

This sketch does not decide:

```text
ring memory layout
slot size
head/tail representation
doorbell mechanism
interrupt mechanism
cache/TLB strategy
NUMA placement
binary ABI
Linux stub files
monitor implementation
performance budget
production protection claim
```

## Consequence

The next step can compare binary layout sketches or define a combined direct
call plus ring ABI plan. Any such plan must keep this ring refinement relation
to the direct-call reference ABI.
