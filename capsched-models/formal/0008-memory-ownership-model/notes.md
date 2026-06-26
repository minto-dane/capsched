# Notes: Memory Ownership Model

Date: 2026-06-26

## Claim Being Modeled

This model is the first explicit memory-boundary model for CapSched-H:

```text
Linux page metadata is not memory authority.
Monitor PageOwner and MemoryView are memory authority.
```

This is the line between a strong container and a hypervisor-grade Domain
boundary.

## Why This Must Come Before L2

L2 plans include per-Domain kernel state, page-cache overlays, Domain-local
slab policy, async queues, and reclaim/writeback provenance. Those features can
make the system safer only if page ownership and mapping authority are already
semantically separated from Linux-owned metadata.

Without that separation, a Domain-local kernel exploit could try to:

```text
forge struct page owner-like metadata
reuse a stale slab object address
map a freed physical page into a new Domain
read mutable shared page-cache data
enqueue reclaim/writeback work without caller provenance
claim memcg membership as authority
```

The model checks that none of those becomes authority.

## Abstractions

Linux shadow state is represented as booleans:

```text
linuxShadowPage[p]
linuxShadowObject[o]
linuxShadowWork[w]
```

This is intentional. The authority transitions do not inspect the shadow value.
Enumerating every fake tuple would only create irrelevant state-space product.
The hostile fact that Linux can hold forged mutable claims is preserved.

## Page Kinds

```text
free:
  no owner, no mapping, no live object, no pending work

private:
  monitor-owned mutable Domain page

cache:
  monitor-owned mutable page-cache overlay page

sealed:
  immutable shared base page, no mutable owner
```

Sealed pages can be mapped by multiple Domains. Mutable private/cache pages
cannot.

## Reuse Rule

Physical page reuse is safe only after all MemoryView mappings and dependent
objects/work have been cleared:

```text
free page => no mappings, no live slab object, no pending memory work
```

This models the production requirement:

```text
revoke MemoryView mapping before reuse by another Domain
```

## Slab Rule

Object lookup safety is not authority. A live object use must match:

```text
object live
object generation
object owner Domain
backing page owner Domain
backing page epoch
```

This mirrors the Linux `SLAB_TYPESAFE_BY_RCU` lesson: address stability does not
prove object identity or authority.

## Work Rule

Reclaim/writeback/service memory work must carry:

```text
caller Domain
caller epoch
target page
ticket
```

Service authority alone is not enough. This aligns with the BrokerBudget model:
work done for a caller must consume caller-derived bounded authority.

## What Comes Next

The broad integration model is intentionally retained as stress coverage, but
the checked proof root is decomposed:

```text
PageOwnerMemoryView
SlabObjGen
MemoryWorkProvenance
```

After these models, the next memory-related model should add one of:

```text
page-cache overlay conflicts
direct-map visibility
IOMMU/DMA MemoryView interaction
TLB shootdown ordering
```

Do not start L2 MM implementation before choosing which of these is the next
risk.
