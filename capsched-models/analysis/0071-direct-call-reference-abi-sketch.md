# Analysis 0071: Direct-Call Reference ABI Sketch

Status: Draft reference ABI sketch with model gate

Date: 2026-06-30

Related artifacts:

```text
analysis/0069-local-monitor-admission-abi-semantics.md
analysis/0070-local-monitor-admission-carrier-sketch-comparison.md
analysis/direct-call-reference-abi-sketch-v1.json
formal/0048-direct-call-reference-abi-model/
validation/0070-direct-call-reference-abi-tlc.md
```

## Purpose

N-098 defines the direct-call reference ABI sketch for
`LocalMonitorAdmissionABI-v0`.

This is still not a binary ABI, syscall/VM-call number, VMX/EL2/SMC/HVC
mechanism, Linux stub, monitor implementation, or memory layout.

It is the small reference semantics that monitor-owned shared rings must later
refine.

## Direct-Call Shape

Reference call flow:

```text
Linux service Domain builds request in Linux-visible memory
  -> local monitor entry
  -> monitor copies request into monitor-owned request image
  -> monitor validates ABI version, request class, field presence, and epochs
  -> monitor consumes replay nonce/window for the attempt
  -> monitor writes success/failure/revoke facts to monitor-owned ledger
  -> monitor returns sealed response handle
  -> Linux refreshes non-authoritative shadow from response handle/query
```

The Linux-visible request buffer is a carrier only. The monitor-owned request
image is the validation subject.

## Request Copy and Freeze

The monitor must not validate directly from Linux mutable request memory.

Required order:

```text
1. monitor entry begins
2. monitor copies bounded request payload
3. monitor records request image id/generation
4. monitor validates only the copied request image
5. Linux post-copy mutation cannot alter the monitor decision
```

This is the direct-call equivalent of the later ring slot claim. It prevents
Linux service-domain compromise from racing field changes after validation.

## Validation Phases

The monitor validates:

```text
ABI version
request class
required field presence
typed nulls for irrelevant fields
monitor id and expected monitor epoch
cluster lease id and epoch
root-management epoch
node id
service Domain id and epoch
target Domain id and epoch
device root id and epoch
local lease id and epoch
requested receipt classes
requested revoke scope
root budget binding where relevant
```

Unknown request classes, malformed fields, stale epochs, service/target/device
mismatch, and unsupported receipt/revoke scopes fail closed.

## Replay Handling

For any monitor-processed attempt:

```text
fresh nonce:
  monitor consumes the replay-window entry before any success ledger write

replayed/stale nonce:
  monitor returns replay/stale failure
  no success receipt can be derived

terminal failure:
  monitor records terminal response for request id/nonce
  same attempt cannot later produce a receipt
```

The exact replay-table storage is not selected here. It is monitor-owned.

## Ledger Write and Response Handle

Success path:

```text
validate copied request image
consume replay window
write monitor-owned receipt ledger row
mint sealed response handle
return response handle to Linux
```

The response handle is not the ledger. It is a proof-carrying or queryable
reference to monitor-owned ledger state. Linux cannot mint it.

Failure path:

```text
validate enough copied request image to identify attempt
record terminal failure or replay/stale rejection
return failure response handle
do not write success receipt
do not refresh authoritative shadow
```

## Linux Shadow Refresh

Linux-visible shadow refresh is allowed only from:

```text
monitor response handle
monitor receipt query
monitor shadow generation
```

Shadow state remains:

```text
cache
index
trace
slow-path hint
```

It is never endpoint authority.

## Revoke Slow Path

Direct-call revoke path:

```text
Linux carries revoke request
  -> monitor entry
  -> monitor copies revoke request image
  -> monitor validates local lease id/epoch and revoke scope
  -> monitor consumes revoke replay nonce
  -> monitor marks revoke started
  -> monitor embargoes new receipts for old local lease epoch
  -> monitor drains or rejects in-flight direct calls for that lease epoch
  -> monitor revokes derived queue/DMA/IRQ/ledger/endpoint receipts
  -> monitor invalidates Linux-visible shadow generation
  -> monitor writes revoke-complete ledger row
  -> monitor returns revoke-complete response handle
```

Direct calls are synchronous per caller, but multiple CPUs can enter the monitor
concurrently. Therefore revoke complete must wait until relevant in-flight
direct calls are drained, rejected, or proven to belong to a newer epoch.

## Direct-Call Reference Invariants

```text
No validation from Linux mutable request memory.
No success response without monitor entry.
No success ledger write without copied request validation.
No success ledger write before replay-window consume.
No Linux-owned ledger write.
No response handle without monitor ledger state.
No Linux shadow refresh from mutable request or failure-only state.
No Linux shadow as endpoint authority.
No receipt after terminal failure for same attempt.
No revoke complete before new receipt embargo.
No revoke complete before relevant in-flight direct calls drain or reject.
No revoke complete before derived receipt revoke and shadow invalidation.
```

## Why This Is Reference Semantics

Direct-call-first is not the final performance target. It is the simplest
correct semantic reference:

```text
small request state
explicit monitor entry
explicit monitor copy/freeze
single replay-window transition
single ledger write point
obvious failure terminality
obvious revoke slow path
```

The future monitor-owned ring must preserve these semantics while amortizing
transitions and batching requests.

## Non-Goals

This sketch does not decide:

```text
binary structure packing
syscall/VM-call/SMC/HVC mechanism
register convention
shared memory layout
cryptographic sealing format
Linux stub file locations
monitor implementation
performance budget
production protection claim
```

## Consequence

The next implementation-facing refinement can sketch a binary direct-call ABI
or a monitor-owned ring refinement. Either must preserve this direct-call
reference model and cite the validation record.
