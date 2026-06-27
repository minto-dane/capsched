# Validation 0036: Wider Endpoint Capability TLC

Status: Completed bounded model check

Date: 2026-06-27

Model:

```text
capsched/capsched-models/formal/0024-wider-endpoint-capability-model/EndpointAuthority.tla
```

Related analysis:

```text
capsched/capsched-models/analysis/0041-wider-endpoint-capability-semantics.md
```

TLC logs:

```text
/media/nia/scsiusb/dev/linux-cap/build/tlc/endpoint-authority-20260627T091658Z/EndpointAuthoritySafe.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/endpoint-authority-20260627T091658Z/EndpointAuthorityUnsafeFdLookup.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/endpoint-authority-20260627T091658Z/EndpointAuthorityUnsafeOpenBasis.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/endpoint-authority-20260627T091658Z/EndpointAuthorityUnsafeNoSec.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/endpoint-authority-20260627T091658Z/EndpointAuthorityUnsafeTransfer.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/endpoint-authority-20260627T091658Z/EndpointAuthorityUnsafeAsyncAmbient.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/endpoint-authority-20260627T091658Z/EndpointAuthorityUnsafeRevokedUse.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/endpoint-authority-20260627T091658Z/EndpointAuthorityUnsafeMmap.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/endpoint-authority-20260627T091658Z/EndpointAuthorityUnsafeIoctl.log
```

## Result Summary

Safe configuration:

```text
config: EndpointAuthoritySafe.cfg
result: PASS
generated states: 57
distinct states: 43
search depth: 7
```

Unsafe configurations produced expected counterexamples:

```text
config: EndpointAuthorityUnsafeFdLookup.cfg
target invariant: NoFdLookupAsAuthority
result: expected FAIL
generated states before violation: 58
distinct states before violation: 44
depth: 7

config: EndpointAuthorityUnsafeOpenBasis.cfg
target invariant: NoOpenBasisAsOperationAuthority
result: expected FAIL
generated states before violation: 58
distinct states before violation: 44
depth: 7

config: EndpointAuthorityUnsafeNoSec.cfg
target invariant: NoNoSecBypass
result: expected FAIL
generated states before violation: 58
distinct states before violation: 44
depth: 7

config: EndpointAuthorityUnsafeTransfer.cfg
target invariant: NoTransferWithoutDerivation
result: expected FAIL
generated states before violation: 58
distinct states before violation: 44
depth: 7

config: EndpointAuthorityUnsafeAsyncAmbient.cfg
target invariant: NoWorkerAmbientEndpointExec
result: expected FAIL
generated states before violation: 31
distinct states before violation: 30
depth: 6

config: EndpointAuthorityUnsafeRevokedUse.cfg
target invariant: NoRunWithStaleEndpointEpoch
result: expected FAIL
generated states before violation: 31
distinct states before violation: 31
depth: 6

config: EndpointAuthorityUnsafeMmap.cfg
target invariant: NoMmapWithoutMmapCap
result: expected FAIL
generated states before violation: 58
distinct states before violation: 44
depth: 7

config: EndpointAuthorityUnsafeIoctl.cfg
target invariant: NoIoctlWithoutTypedCommandCap
result: expected FAIL
generated states before violation: 58
distinct states before violation: 44
depth: 7
```

## Validated Claims

This validation supports the following local design constraints:

```text
1. Linux fd lookup, struct file refs, socket refs, and fixed-file reachability
   are not endpoint authority.

2. EndpointBasis from open/create/accept/receive/register is not all future
   operation authority.

3. CapSched endpoint checks cannot depend only on LSM hooks because Linux has
   valid nosec fast paths such as socket send/recv reuse paths.

4. dup, SCM_RIGHTS receive, accept, registration, epoll-style observation, and
   broker/service return must derive or attenuate receiver authority.

5. Worker, rescuer, kthread, SQPOLL, or io-wq context cannot perform
   caller-attributed endpoint effects by ambient worker authority.

6. Endpoint/domain/object revoke must invalidate queued, registered, mapped, or
   pending uses before they can produce new endpoint effects.

7. mmap requires distinct authority from read/write because it creates a
   continuing memory mapping and future page-fault/memory-view consequences.

8. ioctl and uring command paths require typed command authority, not generic
   fd authority.
```

## Unsafe Counterexample Meaning

`EndpointAuthorityUnsafeFdLookup.cfg` demonstrates running an operation because
an fd lookup returned a reachable object.

`EndpointAuthorityUnsafeOpenBasis.cfg` demonstrates treating open/create basis
as authority for all later operations.

`EndpointAuthorityUnsafeNoSec.cfg` demonstrates a socket nosec fast path
performing an endpoint effect without a fresh CapSched frozen use.

`EndpointAuthorityUnsafeTransfer.cfg` demonstrates receiver-side use after a
transfer-like event without a derived receiver authority.

`EndpointAuthorityUnsafeAsyncAmbient.cfg` demonstrates a worker executing a
caller-attributed endpoint effect by ambient worker authority and without a live
BudgetTicket.

`EndpointAuthorityUnsafeRevokedUse.cfg` demonstrates a queued or registered
endpoint use running after endpoint epoch revocation.

`EndpointAuthorityUnsafeMmap.cfg` demonstrates mmap authorized by ordinary
operation authority without an explicit MmapCap.

`EndpointAuthorityUnsafeIoctl.cfg` demonstrates ioctl authorized by generic fd
authority rather than typed command authority.

## Evidence Limits

This validation does not prove:

```text
complete VFS permission semantics
complete socket protocol behavior
all ioctl command taxonomies
all io_uring opcodes and worker paths
all anonymous fd object classes
full mmap/page-fault/writeback revocation behavior
performance cost of endpoint freezing
monitor-backed MemoryView enforcement
```

Those remain separate proof obligations.

## Design Consequence

The future endpoint implementation should be staged as:

```text
E0:
  inert type names for EndpointBasis, FrozenEndpointUse, DerivedEndpointCap

E1:
  trace-only basis attachment and freeze/consume observation for major file,
  socket, mmap, ioctl, anon-fd, and io_uring paths

E2:
  derivation models for dup, SCM_RIGHTS, accept, epoll add, io_uring
  registration, and service endpoint return

E3:
  fail-closed enforcement for a narrow operation class only after coverage and
  compatibility evidence exist
```

The immediate Linux code should not yet enforce endpoint permissions. It should
first prove that the selected attachment points can observe and represent the
required authority transitions without changing Linux behavior.
