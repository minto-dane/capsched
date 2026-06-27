# Wider Endpoint Capability Model

Status: Draft, checked with tiny finite TLC configurations

Date: 2026-06-27

Related analysis:

```text
capsched/capsched-models/analysis/0041-wider-endpoint-capability-semantics.md
```

## Purpose

This model captures the endpoint authority rule:

```text
Linux object reachability is not resource authority.
Endpoint effects require operation-specific FrozenEndpointUse.
```

## Modeled Hazards

```text
fd lookup or struct file reference treated as authority
open/create basis treated as authority for all future operations
socket nosec fast path bypassing CapSched frozen use
dup/SCM_RIGHTS/accept-style transfer without receiver derivation
async worker execution using ambient worker authority
queued or registered work running after endpoint/domain revoke
mmap authorized by ordinary read/write authority
ioctl authorized by generic fd authority
```

## Checked Invariants

```text
NoOperationWithoutFrozenEndpointUse
NoFdLookupAsAuthority
NoOpenBasisAsOperationAuthority
NoRunWithStaleEndpointEpoch
NoNoSecBypass
NoTransferWithoutDerivation
NoWorkerAmbientEndpointExec
NoMmapWithoutMmapCap
NoIoctlWithoutTypedCommandCap
```

## Scope Limit

This is not a full VFS, socket, epoll, io_uring, or driver model. It abstracts
Linux object reachability and operation dispatch into a design filter for
CapSched endpoint semantics.

The model intentionally does not decide the final C storage location for
endpoint metadata. It only establishes that storage and hooks must preserve the
distinction between:

```text
EndpointBasis
EndpointHandle
FrozenEndpointUse
DerivedEndpointCap
```
