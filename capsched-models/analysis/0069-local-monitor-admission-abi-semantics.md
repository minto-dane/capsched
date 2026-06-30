# Analysis 0069: Local Monitor Admission ABI Semantics Candidate

Status: Draft semantic ABI candidate with model gate

Date: 2026-06-30

Related artifacts:

```text
analysis/0067-local-monitor-admission-interface-boundary.md
analysis/0068-local-monitor-admission-carrier-storage.md
analysis/local-monitor-admission-abi-semantics-v0.json
formal/0046-local-monitor-admission-abi-model/
validation/0068-local-monitor-admission-abi-tlc.md
```

## Purpose

N-096 defines the first concrete semantic candidate for a local HyperTag Monitor
admission ABI.

This is still not a code layout. It does not choose syscall, VM-call, SMC/HVC,
ioctl, netlink, shared ring memory layout, cryptographic seal format, or Linux
stub placement.

It defines the semantics that any later carrier must preserve:

```text
request classes are typed
monitor responses are monitor-minted
receipt ledger state is monitor-owned
request replay windows are consumed once
Linux-visible shadows are non-authoritative and invalidated on revoke
failure paths are terminal for that attempt
revoke paths embargo new receipts before derived receipts are revoked
```

## ABI Candidate Name

```text
LocalMonitorAdmissionABI-v0
```

The `v0` suffix means "semantic candidate zero", not a stable binary ABI.

## Participants

```text
Root-management plane:
  issues cluster policy and ClusterLease intent

Linux service Domain:
  carries local requests, programs devices after receipts, and maintains
  non-authoritative shadows

Local HyperTag Monitor:
  owns request replay windows, response minting, receipt ledger writes, revoke
  state, and local hardware ownership roots

Target Domain:
  receives typed endpoints only after monitor-verified receipts
```

## Request Classes

Minimum request classes:

```text
HTAG_REQ_IMPORT_CLUSTER_LEASE:
  import root-management ClusterLease into the local monitor replay window

HTAG_REQ_BIND_DEVICE_ROOT:
  bind a local device identity, PCI RID/PASID/equivalent identity, and device
  root epoch to monitor-owned state

HTAG_REQ_ADMIT_SERVICE_DOMAIN:
  admit the Linux service Domain as request carrier and device programmer for
  an allowed service action set

HTAG_REQ_ADMIT_TARGET_DOMAIN:
  admit a target Domain epoch and root budget for local device lease use

HTAG_REQ_COMPILE_LOCAL_DEVICE_LEASE:
  compile cluster intent, service admission, target admission, device root,
  queue policy, DMA MemoryView policy, IRQ route policy, and root budget into a
  LocalDomainDeviceLease receipt

HTAG_REQ_MINT_DERIVED_RECEIPTS:
  mint DeviceRoot, VF/SF epoch, QueueLease, DMA MemoryView, IRQ route, ledger,
  and typed endpoint receipts from a live LocalDomainDeviceLease

HTAG_REQ_QUERY_RECEIPT:
  query monitor receipt validity and epochs for slow path or shadow refresh

HTAG_REQ_REVOKE_LOCAL_DEVICE_LEASE:
  begin revoke for a LocalDomainDeviceLease epoch and requested revoke scope
```

Unknown request classes must fail closed.

## Common Request Fields

Every request class carries:

```text
abi_version
request_class
request_id
request_nonce
replay_window_id
caller_domain_id
caller_domain_epoch
monitor_id
expected_monitor_epoch
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
requested_receipt_classes
requested_revoke_scope
```

Fields irrelevant to a request class must be explicitly absent or set to a
typed null value. They must not be interpreted as ambient defaults.

## Response Classes

Minimum response classes:

```text
HTAG_RESP_ACCEPTED:
  request accepted for monitor processing, not itself authority

HTAG_RESP_FAILURE:
  terminal failure for this request attempt, bound to failed phase and reason

HTAG_RESP_REPLAY_REJECTED:
  request nonce/replay window rejected and no receipt can be derived from this
  request

HTAG_RESP_STALE_EPOCH:
  monitor, cluster, service, target, device root, local lease, or revoke epoch
  mismatch

HTAG_RESP_RECEIPT_SET:
  monitor-minted receipt ids and epochs were written to the monitor ledger

HTAG_RESP_REVOKE_STARTED:
  local lease revoke began and new receipt minting for the old epoch is
  embargoed

HTAG_RESP_DERIVED_RECEIPTS_REVOKED:
  derived queue, DMA, IRQ, ledger, and endpoint receipts are invalid

HTAG_RESP_REVOKE_COMPLETE:
  local lease epoch is revoked and cannot authorize future derived receipts
```

## Receipt Ledger Semantics

The monitor receipt ledger is the only authority root for local admission
responses and receipts.

Required ledger properties:

```text
monitor-owned write path
receipt id and receipt epoch
local lease id and local lease epoch
monitor epoch
source request id and request nonce
response class
receipt class set
valid/revoked state
revoke epoch
shadow generation
append-only or equivalent tamper-evident mutation semantics
```

Linux may receive handles, copies, or indexes derived from this ledger. Linux
may not write authoritative receipt state.

## Replay Window Semantics

The monitor owns replay windows.

```text
fresh request:
  request nonce is unused in replay_window_id and expected epochs match

accepted request:
  consumes the nonce before success receipts are visible

replayed request:
  receives HTAG_RESP_REPLAY_REJECTED or HTAG_RESP_STALE_EPOCH
  cannot mint receipts
  cannot refresh Linux-visible shadows
```

Replay protection cannot be implemented by Linux-only ring slot generation.

## Linux-Visible Shadow Semantics

Linux-visible shadow state is allowed only as non-authoritative acceleration:

```text
shadow source:
  monitor receipt id, receipt epoch, shadow generation

shadow use:
  cache/index/trace/slow-path hint

shadow miss or corruption:
  slow path monitor query or fail closed

shadow invalidation:
  mandatory on revoke start or derived receipt revoke
```

A Linux-visible shadow must never authorize endpoint delivery by itself.

## Failure Semantics

Failure is terminal for the request attempt:

```text
HTAG_RESP_FAILURE
HTAG_RESP_REPLAY_REJECTED
HTAG_RESP_STALE_EPOCH
unknown request class
field presence/type mismatch
policy mismatch
service Domain mismatch
target Domain mismatch
device root mismatch
root budget mismatch
```

After a terminal failure, the same request attempt cannot later produce a
receipt. A new attempt requires a new request id and nonce.

## Revoke Semantics

Revoke ordering:

```text
1. HTAG_REQ_REVOKE_LOCAL_DEVICE_LEASE
2. HTAG_RESP_REVOKE_STARTED
3. new receipt embargo for the old local lease epoch
4. derived queue/DMA/IRQ/ledger/endpoint receipts revoked
5. Linux-visible shadows invalidated
6. HTAG_RESP_REVOKE_COMPLETE
```

Revoke complete before derived receipt revoke is rejected. New receipt minting
during revoke is rejected.

## Accepted Future Carrier Shapes

The same semantics may later be carried by:

```text
direct monitor call
monitor-owned shared ring
Linux service-domain request queue plus monitor copy/validate step
root-management feed plus local monitor import
```

The carrier is not the authority root. The monitor ledger is.

## Explicit Non-Goals

This candidate is not:

```text
a Linux patch
a monitor implementation
a binary ABI
a cryptographic sealing format
a memory layout
a syscall number allocation
a hardware-specific VMX/EL2/SMC/HVC decision
a protection claim
```

## Design Consequence

The next concrete step after this semantic candidate is to decide whether the
first implementation-facing ABI sketch should be:

```text
synchronous direct monitor call first
or
monitor-owned admission ring first
```

That choice must preserve this model. It cannot move response minting, receipt
ledger writes, replay-window ownership, shadow authority, or revoke completion
into Linux-owned state.
