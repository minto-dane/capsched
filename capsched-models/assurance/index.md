# Assurance Case Index

Updated: 2026-06-29

## Purpose

This directory tracks the assurance case for CapSched-Linux.

The assurance case is the bridge from local work products to the final
datacenter OS claim:

```text
Process-scale, service-scale, container-scale, tenant-scale, and cluster-cell
Domains should cross each other's hard boundary only by breaking the HyperTag
Monitor or an explicitly exposed typed service endpoint.
```

Linux-only L0 evidence is useful, but it is not production protection evidence.

## Files

| File | Role |
| --- | --- |
| `0001-hypervisor-grade-domain-separation-case.md` | Human-readable top-level claim tree, gaps, forbidden claims, and gate criteria. |
| `0002-modern-nic-queuelease-assurance-map.md` | Human-readable DEV-001 subclaim map for modern NIC QueueLease evidence, gaps, and forbidden claims. |
| `claims.json` | Machine-readable claim, evidence, counterexample, and gate register for AI/state recovery. |
| `modern-nic-queuelease-subclaims-v1.json` | Machine-readable DEV-001 modern NIC subclaim map and evidence classification. |

## Status Legend

```text
Open:
  Claim is required for the final goal but is not yet established.

Model-supported:
  A small or decomposed formal model supports part of the claim.

Prototype-evidenced:
  Linux-only code/build/trace evidence supports compatibility or integration,
  not production isolation.

Protection-evidenced:
  Monitor-backed or equivalent production evidence exists. No current claim has
  this status yet.

Forbidden-for-L0:
  Claim must not be made by Linux-only prototypes.
```

## Current Summary

The current project state has strong semantic atoms, but no production
protection claim yet.

Model-supported areas:

- runnable lease authority
- endpoint async provenance
- broker budget tickets
- monitor activation
- decomposed cluster authority
- memory ownership
- direct-map and TLB revocation pressure
- page-cache overlay conflict handling
- queue lease and IOMMU/IRQ boundary
- modern NIC QueueLease authority-class separation
- XDP and AF_XDP memory ownership
- QueueControl and RepresentorForward separation
- modern NIC queue revoke/drain/quarantine semantics
- VF IRQ revoke ownership and synchronization-exception semantics
- monitor IRQ route invalidation receipt semantics
- monitor DMA/IOMMU/MemoryView invalidation receipt semantics
- stale XSK/page-pool completion quarantine semantics
- representor-to-lower QueueLease derivation semantics

Prototype-evidenced areas:

- inert `CONFIG_CAPSCHED` build scaffolding
- type-only authority names in Linux
- build compatibility for `CONFIG_CAPSCHED=n` and `CONFIG_CAPSCHED=y`

Open production gaps:

- actual HyperTag Monitor
- real MemoryView/PageOwner enforcement
- per-Domain mutable kernel state
- real scheduler enforcement across all runnable paths
- async provenance implementation
- real IOMMU, IRQ, and queue revocation
- monitor-backed QueueTag, QueueControlCap, RepresentorForwardCap, and typed
  queue ledger roots
- service-domain TCB reduction
- exploit-containment and cost-efficiency evaluation

Current modern NIC QueueLease summary:

```text
Model-supported:
  SKB/XDP/AF_XDP/control/representor/service authority classes are separated.

Source-observed:
  Intel ice contains usable queue, descriptor, DMA, completion, devlink,
  representor, and service anchors.

Observation-only:
  ice readiness found 19 tracepoint rows, 40 source anchors, and 12
  high-severity gaps. Every row remains authority_claim=false and
  monitor_verified=false.
  ice revoke readiness found 8 tracepoint rows, 31 source anchors, 10
  obligation readiness rows, and 8 high-severity gaps. Every row remains
  observation_only=true, authority_claim=false, and monitor_verified=false.

VF IRQ revoke model:
  safe TLC passed with 25 generated states and 22 distinct states. Unsafe
  configs produced expected counterexamples for VF host-sync assumption, stale
  completion after revoke, reassignment without owner-specific IRQ quiescence,
  host-owned reassignment without synchronize_irq(), and monitor-owned
  reassignment without monitor invalidation.

Monitor IRQ route invalidation model:
  safe TLC passed with 14 generated states and 12 distinct states. Unsafe
  configs produced expected counterexamples for unsafe interrupt override,
  stale eventfd delivery, reassignment without receipt, receipt without IEC
  flush, receipt with posted state, and receipt with eventfd still live.

Monitor DMA/IOMMU invalidation model:
  safe TLC passed with 17 generated states and 17 distinct states. Unsafe
  configs produced expected counterexamples for IRQ-only reassignment,
  driver-unmap-only receipt, IOMMU unmap without IOTLB sync, queued-flush
  receipt, PageOwner transfer with DMA in flight, new MemoryView before old
  unmap, completion after revoke, and packet return before receipt. The
  receipt now also requires monitor-owned DMA root, new-work embargo,
  hardware queue quiescence, HW-owned descriptor drain, access-user release,
  and old device-domain/PASID fence.

XSK and page-pool quarantine model:
  safe TLC passed with 11 generated states and 11 distinct states. Unsafe
  configs produced expected counterexamples for XSK CQ submit after revoke,
  XSK free-list return after revoke, page-pool recycle after revoke, packet
  return before DMA receipt, PageOwner transfer before quarantine, packet
  return without generation reset, double return, and queue reassignment before
  settlement.

Representor lower QueueLease model:
  safe TLC passed with 14 generated states and 8 distinct states. Unsafe
  configs produced expected counterexamples for representor netdev-only lower
  forwarding, bridge FDB as lower lease, VLAN as lower lease, TC/offload rule
  install without control authority, TC/offload stale destination after LAG
  lower_dev change, forwarding with stale lower_dev, forwarding after revoke,
  and representor stop as lower QueueLease revoke.

Forbidden:
  Do not treat netdev/ring/q_vector/devlink/workqueue state as production
  authority. Do not treat netdev down/reset, ring cleanup, NAPI disable,
  Linux-owned DMA unmap, queued IOMMU flush, iommufd IOAS unmap, VFIO unmap
  callback, xsk_tx_completed(), xsk_buff_free(), page-pool recycle,
  representor stop, bridge FDB/VLAN success, TC redirect target, metadata_dst,
  or devlink reload as QueueLease authority or revoke authority. Do not
  implement behavior-changing QueueLease enforcement from this evidence alone.
```
