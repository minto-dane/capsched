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

Forbidden:
  Do not treat netdev/ring/q_vector/devlink/workqueue state as production
  authority. Do not treat netdev down/reset, ring cleanup, NAPI disable,
  Linux-owned DMA unmap, representor stop, or devlink reload as QueueLease
  revoke authority. Do not implement behavior-changing QueueLease enforcement
  from this evidence alone.
```
