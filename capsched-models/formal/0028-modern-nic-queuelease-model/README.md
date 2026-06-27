# Modern NIC QueueLease Model

Status: Checked for tiny finite TLC configurations

Date: 2026-06-27

Related analysis:

```text
capsched/capsched-models/analysis/0049-e1000e-queuelease-source-map.md
capsched/capsched-models/analysis/0050-aggregate-queuelease-settlement-semantics.md
capsched/capsched-models/analysis/0052-ice-modern-nic-queuelease-source-map.md
```

## Purpose

This model refines the generic QueueLease settlement model for modern
multi-queue NIC semantics exposed by Intel `ice`.

The modeled design rule is:

```text
one queue object is not one authority type.
```

SKB transmit, XDP frame transmit, XDP_TX page-pool reuse, AF_XDP zero-copy,
devlink queue control, representor forwarding, and service work need separate
authority classes even when they eventually touch the same driver queue, ring,
q_vector, NAPI, or workqueue substrate.

## Modeled Hazards

```text
submit without QueueBind
submit without budget
SKB submit without IOMMU proof
XDP frame submit using an SKB ledger/capability
AF_XDP zero-copy submit without XSK ownership
representor forwarding without derived lower queue authority
devlink queue-control through RunCap
service/reset/PTP/DPLL work charged to the last submitter
completion by ambient worker/service authority
delivery after revoke
```

## Checked Invariants

```text
NoSubmitWithoutQueueBind
NoSubmitWithoutBudget
NoDescriptorDoorbellWithoutTypedLedger
NoSubmitClassCollapse
NoCompletionWithoutTypedLedgerAndServiceBudget
NoRepresentorForwardWithoutDerivation
NoQueueControlWithoutQueueControlCap
NoServiceWorkAsCallerEffect
NoDeliveryAfterRevoke
NoOutstandingAfterRevoke
```

## Scope Limit

This model intentionally does not model real descriptor ring size, wraparound,
NAPI poll fairness, packet contents, eBPF/XDP program semantics, AF_XDP UMEM
layout, devlink implementation details, or hardware interrupt remapping.

It is a class-separation model. Its purpose is to prevent the first modern NIC
design from collapsing all queue-adjacent actions into one generic QueueLease or
one worker callback authority.
