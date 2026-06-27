# Assurance Case Index

Updated: 2026-06-26

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
| `claims.json` | Machine-readable claim, evidence, counterexample, and gate register for AI/state recovery. |

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
- service-domain TCB reduction
- exploit-containment and cost-efficiency evaluation
