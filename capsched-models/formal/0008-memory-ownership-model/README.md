# Formal 0008: Memory Ownership Model

Status: Draft

Date: 2026-06-26

Linux base:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
commit: 0b685979f27b3d42ee620ced5f707ee391a2a27f
```

## Purpose

This model captures the memory boundary that CapSched needs before any L2
per-Domain MM, slab, page-cache, or reclaim work.

The goal is not to prove Linux MM correct. The goal is to pressure the security
claim:

```text
No monitor-owned PageOwner and MemoryView mapping, no Domain memory access.
```

Linux-visible page metadata, memcg state, page-cache state, slab lifetime, and
mutable shadow claims are treated as substrate or attacker-controlled hints, not
as authority roots.

## Threat Assumption

The model assumes Linux-visible mutable memory metadata may be forged or stale.
That includes:

```text
struct page-like owner hints
folio/memcg-like accounting claims
page-cache mapping claims
slab object lookup hints
reclaim/writeback work hints
```

The model therefore gives authority only to monitor-owned variables:

```text
pageOwner
pageEpoch
pageKind
mapped MemoryView sets
object generation
work tickets
```

## Files

```text
MemoryOwnership.tla
MemoryOwnership.cfg
PageOwnerMemoryView.tla
PageOwnerMemoryView.cfg
SlabObjGen.tla
SlabObjGen.cfg
MemoryWorkProvenance.tla
MemoryWorkProvenance.cfg
notes.md
```

`MemoryOwnership.tla` is the broad integration stress model. The current proof
root is the decomposed set:

```text
PageOwnerMemoryView:
  PageOwner, MemoryView mapping, sealed pages, mutable page-cache overlays.

SlabObjGen:
  slab object generation and page-owner validation.

MemoryWorkProvenance:
  reclaim/writeback/service memory work provenance and tickets.
```

## Modeled Objects

```text
Domain:
  protection and ownership context.

Page:
  physical page abstraction.

MemoryView:
  modeled as per-Domain mapped page sets.

PageOwner:
  monitor-owned owner of a mutable private/cache page.

Sealed page:
  immutable shared base page that may be mapped by multiple Domains.

Slab object:
  object allocated on an owned page with generation validation.

Memory work:
  reclaim/writeback/service work that requires caller provenance and a ticket.

Linux shadow:
  forged mutable Linux claim. It is intentionally abstracted because authority
  transitions do not read it.
```

## Encoded Safety Properties

```text
NoMappingWithoutMonitorAuthority
NoMutablePageMappedAcrossDomains
NoFreePageMappedOrReferenced
NoStaleEpochMapping
NoLinuxShadowConfersMappingAuthority
NoMutablePageCacheSharing
NoObjectUseWithoutLiveGeneration
NoObjectUseAcrossPageOwner
NoWorkExecutionWithoutProvenanceTicket
NoSealedPageHasMutableOwner
```

## Validation

Current validation record:

```text
capsched/capsched-models/validation/0010-memory-ownership-tlc.md
```

The broad integration model was stopped after state growth without invariant
errors observed before interruption. The decomposed models completed with no
invariant errors.

## Non-Claims

This model does not prove:

- real page-table or EPT programming,
- TLB shootdown correctness,
- cache side-channel isolation,
- DMA/IOMMU isolation,
- Linux direct-map surgery,
- actual SLUB implementation correctness,
- filesystem consistency,
- distributed storage semantics.

Those need separate models and implementation validation.

## Design Consequence

Linux MM should be reused for performance and compatibility, but production
CapSched memory authority must be below Linux:

```text
Linux:
  allocation, accounting, reclaim, cache policy

Monitor:
  PageOwner, MemoryView, revoke-before-reuse
```
