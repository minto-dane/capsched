# Validation 0048: XDP and AF_XDP Memory Ownership TLC

Status: Safe model passed; unsafe models produced expected counterexamples

Date: 2026-06-27

Model:

```text
capsched/capsched-models/formal/0029-xdp-afxdp-memory-ownership-model/XdpAfxdpMemoryOwnership.tla
```

Related artifacts:

```text
capsched/capsched-models/analysis/0052-ice-modern-nic-queuelease-source-map.md
capsched/capsched-models/validation/0047-ice-modern-nic-readiness-result.md
capsched/capsched-models/formal/0028-modern-nic-queuelease-model/README.md
```

TLC logs:

```text
/media/nia/scsiusb/dev/linux-cap/build/tlc/xdp-afxdp-memory-ownership-20260627T114322Z/XdpAfxdpMemoryOwnershipSafe.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/xdp-afxdp-memory-ownership-20260627T114322Z/XdpAfxdpMemoryOwnershipUnsafeAFXDPNoXSK.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/xdp-afxdp-memory-ownership-20260627T114322Z/XdpAfxdpMemoryOwnershipUnsafeAmbientXSKDesc.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/xdp-afxdp-memory-ownership-20260627T114322Z/XdpAfxdpMemoryOwnershipUnsafeCompletionNoLedger.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/xdp-afxdp-memory-ownership-20260627T114322Z/XdpAfxdpMemoryOwnershipUnsafeCrossDomainDma.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/xdp-afxdp-memory-ownership-20260627T114322Z/XdpAfxdpMemoryOwnershipUnsafeDmaNoMemoryView.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/xdp-afxdp-memory-ownership-20260627T114322Z/XdpAfxdpMemoryOwnershipUnsafeDoubleReturn.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/xdp-afxdp-memory-ownership-20260627T114322Z/XdpAfxdpMemoryOwnershipUnsafeReturnAfterRevoke.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/xdp-afxdp-memory-ownership-20260627T114322Z/XdpAfxdpMemoryOwnershipUnsafeSubmitNoBudget.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/xdp-afxdp-memory-ownership-20260627T114322Z/XdpAfxdpMemoryOwnershipUnsafeXDPTxNoPagePool.log
```

## Result Summary

Safe configuration:

```text
config: XdpAfxdpMemoryOwnershipSafe.cfg
result: PASS
generated states: 19
distinct states: 13
search depth: 6
```

Unsafe configurations produced expected counterexamples:

```text
config: XdpAfxdpMemoryOwnershipUnsafeXDPTxNoPagePool.cfg
target invariant: NoXDPTxWithoutPagePoolOwnership
result: expected FAIL
generated states before violation: 6
distinct states before violation: 6

config: XdpAfxdpMemoryOwnershipUnsafeAFXDPNoXSK.cfg
target invariant: NoAFXDPWithoutXSKOwnership
result: expected FAIL
generated states before violation: 8
distinct states before violation: 8

config: XdpAfxdpMemoryOwnershipUnsafeDmaNoMemoryView.cfg
target invariant: NoDmaWithoutMemoryViewAndIommu
result: expected FAIL
generated states before violation: 6
distinct states before violation: 6

config: XdpAfxdpMemoryOwnershipUnsafeAmbientXSKDesc.cfg
target invariant: NoAFXDPWithoutXSKOwnership
result: expected FAIL
generated states before violation: 8
distinct states before violation: 8

config: XdpAfxdpMemoryOwnershipUnsafeCrossDomainDma.cfg
target invariant: NoDmaWithoutMemoryViewAndIommu
result: expected FAIL
generated states before violation: 6
distinct states before violation: 6

config: XdpAfxdpMemoryOwnershipUnsafeCompletionNoLedger.cfg
target invariant: NoCompletionWithoutLedgerAndServiceBudget
result: expected FAIL
generated states before violation: 14
distinct states before violation: 11

config: XdpAfxdpMemoryOwnershipUnsafeDoubleReturn.cfg
target invariant: NoDoubleReturn
result: expected FAIL
generated states before violation: 20
distinct states before violation: 14

config: XdpAfxdpMemoryOwnershipUnsafeReturnAfterRevoke.cfg
target invariant: NoReturnWithoutCompletion
result: expected FAIL
generated states before violation: 10
distinct states before violation: 9

config: XdpAfxdpMemoryOwnershipUnsafeSubmitNoBudget.cfg
target invariant: NoSubmitWithoutBudget
result: expected FAIL
generated states before violation: 6
distinct states before violation: 6
```

## Validated Claims

This validation supports these local constraints:

```text
1. XDP_TX page-pool reuse requires page-pool ownership, page-pool submit
   authority, and a live DMA mapping.

2. AF_XDP zero-copy submit requires XSK pool binding, UMEM ownership, a frozen
   descriptor, AF_XDP submit authority, and a live DMA mapping.

3. Queue reachability alone does not authorize DMA-capable packet memory.

4. DMA submit requires live MemoryView and IOMMU state.

5. Cross-Domain DMA is forbidden even if Linux queue or pool state exists.

6. Completion and memory return require a typed ledger and service budget.

7. Packet memory must not be returned twice.

8. Packet memory must not be returned after revoke as if it completed normally.

9. XDP_TX and AF_XDP submit require queue budget.
```

## Unsafe Counterexample Meaning

`XdpAfxdpMemoryOwnershipUnsafeXDPTxNoPagePool.cfg` demonstrates XDP_TX submit
without page-pool ownership.

`XdpAfxdpMemoryOwnershipUnsafeAFXDPNoXSK.cfg` demonstrates AF_XDP submit without
XSK/UMEM ownership.

`XdpAfxdpMemoryOwnershipUnsafeDmaNoMemoryView.cfg` demonstrates DMA submit
without live MemoryView.

`XdpAfxdpMemoryOwnershipUnsafeAmbientXSKDesc.cfg` demonstrates ambient AF_XDP
descriptor use without a frozen descriptor.

`XdpAfxdpMemoryOwnershipUnsafeCrossDomainDma.cfg` demonstrates cross-Domain DMA
despite the queue path being reachable.

`XdpAfxdpMemoryOwnershipUnsafeCompletionNoLedger.cfg` demonstrates completion
and memory return without a typed ledger.

`XdpAfxdpMemoryOwnershipUnsafeDoubleReturn.cfg` demonstrates double return of
packet memory.

`XdpAfxdpMemoryOwnershipUnsafeReturnAfterRevoke.cfg` demonstrates stale memory
return after revoke.

`XdpAfxdpMemoryOwnershipUnsafeSubmitNoBudget.cfg` demonstrates submit without
queue budget.

## Evidence Limits

This validation does not prove:

```text
real page-pool recycling implementation correctness
real XSK/UMEM chunk accounting
multi-buffer XDP behavior
BPF/XDP program safety
hardware IOMMU invalidation latency
actual monitor-backed MemoryView enforcement
```

Those remain future proof obligations.

## Design Consequence

The modern NIC class model must be refined as:

```text
SubmitLedgerXDPFrame:
  ordinary XDP frame DMA

SubmitLedgerXDPTxPagePool:
  page-pool-owned DMA memory reuse

SubmitLedgerAFXDP:
  XSK/UMEM-owned zero-copy descriptor submit
```

These are related but not interchangeable. Any future Linux prototype must not
authorize XDP_TX or AF_XDP zero-copy by SKB reachability, generic netdev
authority, or ambient driver worker state.
