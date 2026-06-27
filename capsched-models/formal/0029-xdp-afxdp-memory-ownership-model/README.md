# XDP and AF_XDP Memory Ownership Model

Status: Checked for tiny finite TLC configurations

Date: 2026-06-27

Related artifacts:

```text
capsched/capsched-models/analysis/0052-ice-modern-nic-queuelease-source-map.md
capsched/capsched-models/formal/0028-modern-nic-queuelease-model/README.md
capsched/capsched-models/validation/0047-ice-modern-nic-readiness-result.md
```

## Purpose

This model refines the modern NIC QueueLease class split for XDP_TX page-pool
reuse and AF_XDP zero-copy memory ownership.

The modeled design rule is:

```text
DMA-capable packet memory is not authorized by queue reachability alone.
```

XDP_TX page-pool reuse needs page-pool ownership and a live MemoryView/IOMMU
mapping. AF_XDP zero-copy needs XSK/UMEM ownership, a frozen descriptor, and a
live MemoryView/IOMMU mapping. Neither path can borrow SKB authority or generic
XDP authority.

## Modeled Hazards

```text
XDP_TX submit without page-pool ownership
AF_XDP submit without XSK/UMEM ownership
DMA submit without live MemoryView/IOMMU
ambient AF_XDP descriptor use without freeze
cross-Domain DMA
completion without typed ledger
double return of packet memory
return after revoke
submit without budget
```

## Checked Invariants

```text
NoXDPTxWithoutPagePoolOwnership
NoAFXDPWithoutXSKOwnership
NoDmaWithoutMemoryViewAndIommu
NoSubmitWithoutBudget
NoCompletionWithoutLedgerAndServiceBudget
NoReturnWithoutCompletion
NoDoubleReturn
NoSubmitClassMix
NoOutstandingAfterRevoke
```

## Scope Limit

This is not a full XDP or AF_XDP model. It does not model BPF program safety,
real UMEM chunk layout, multi-buffer packets, hardware descriptor wraparound,
page-pool recycling algorithms, or actual IOMMU invalidation latency.

It is a design filter for the CapSched rule:

```text
XDP_TX and AF_XDP submit paths require explicit memory ownership authority.
```
