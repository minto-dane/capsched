# Analysis 0017: MM Allocator and Page Cache Domain State Map

Status: Draft

Date: 2026-06-26

Linux base:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
commit: 0b685979f27b3d42ee620ced5f707ee391a2a27f
```

## Purpose

This note refines the mutable kernel state boundary map for MM, allocator,
memcg, slab, and page cache state.

The security goal is not merely to tag Linux pages. The production goal is that
a compromised Domain-local Linux kernel context cannot read or corrupt another
Domain's memory or mutable kernel state. That requires monitor-owned page
ownership and MemoryViews below Linux.

## Core Finding

Existing Linux MM has excellent lifetime, accounting, reclaim, and sharing
machinery. It does not provide non-forgeable Domain memory authority.

```text
Linux MM metadata:
  useful shadow/accounting/performance substrate

HyperTag Monitor:
  required owner of physical page ownership and MemoryView mappings
```

This means CapSched must not treat `struct page`, folio memcg data, slab cache
membership, page-cache mapping, or cgroup membership as the root of Domain
memory authority.

## Existing Linux Strengths

### struct page and folio

Evidence:

- `include/linux/mm_types.h` lines 43-48 explicitly says every physical page
  has a `struct page`, but there is no direct way to track which tasks use a
  page.
- `struct page` lines 80-170 contains flags, LRU/free/pcp list variants,
  mapping pointer, index/share, private data, page pool data, device page data,
  and typed page fields.
- `struct folio` lines 359-455 represents a physically and logically contiguous
  set of bytes and carries mapping, index, refcount, mapcount, memcg data, and
  kernel virtual address state.

CapSched interpretation:

`struct page` and folio are strong lifetime and accounting anchors. They are
not a security ownership root. The comment that Linux has no direct task-use
tracking is the key warning: page metadata is about current use and references,
not non-forgeable Domain authority.

### mm_struct and VMA state

Evidence:

- `include/linux/mm_types.h` lines 1160-1390 define `struct mm_struct`.
- It includes VMA maple tree state, page tables, locks, RSS counters, owner,
  executable file, MMU notifiers, NUMA state, async put work, and optional
  `iommu_mm`.

CapSched interpretation:

`mm_struct` is already the ordinary user address-space boundary. It should be
reused in L0/L1. It is not enough for a hypervisor-replacement claim because
its metadata and page table management remain mutable Linux kernel state.

### memcg and objcg

Evidence:

- `include/linux/memcontrol.h` lines 196-324 says the memory controller
  controls page cache and RSS per cgroup and contains page counters, events,
  cgroup writeback, socket pressure, kmem IDs, and per-node state.
- Lines 399-425 describe folio-to-memcg binding stability requirements.
- Lines 460-466 use `READ_ONCE()` because slab-related `memcg_data` may change
  asynchronously.
- `mm/memcontrol.c` lines 1130-1194 obtains memcg from `mm->owner`, current, or
  a folio using RCU and css references.
- `mm/memcontrol.c` lines 3010-3029 uses current or `set_active_memcg()` scope
  for object charging.
- `mm/memcontrol.c` lines 3485-3521 describes object charging and notes shared
  accounting bottlenecks.

CapSched interpretation:

memcg is extremely useful for accounting, pressure, reclaim, and compatibility.
It is not a protection root. It depends on Linux-owned task/mm/cgroup state and
scoped current-context rules. CapSched can align Domain budgets with memcg, but
must not define Domain memory ownership as memcg membership.

### SLUB and slab caches

Evidence:

- `include/linux/slab.h` lines 103-164 explains that
  `SLAB_TYPESAFE_BY_RCU` delays slab page freeing, not object freeing. The same
  memory location can be reused in the same RCU grace period; independent
  object validation after reference acquisition is required.
- Lines 178-188 define `SLAB_NO_MERGE`, but warn it should be used cautiously.
- Lines 196-205 define `SLAB_ACCOUNT` as memcg accounting.
- `mm/slab_common.c` lines 152-230 finds mergeable slab caches.
- `mm/slab_common.c` lines 232-380 creates caches, aliases mergeable caches,
  and protects creation under `slab_mutex`.

CapSched interpretation:

Pointer lifetime is not object authority. CapSched object capabilities need
generation/epoch validation. For CapSched's own security-critical caches, later
slices may need unmerged caches and Domain-local allocation policy. But broad
SLUB changes are L2 work, not Slice 0B.

### Page allocator fast paths

Evidence:

- `mm/page_alloc.c` lines 2651-2750 drains per-CPU pages, with an optimized
  racy check unless forced.
- Lines 3210-3425 allocate through per-CPU page lists first and fall back to
  buddy allocator state.
- Lines 5075-5235 implement bulk allocation and explicitly state that the bulk
  allocator does not support memcg accounting when `__GFP_ACCOUNT` is needed.
- Lines 5268-5343 apply scoped GFP context, cpuset/nodemask constraints, fast
  and slow paths, and optional memcg kmem page charging.

CapSched interpretation:

The allocator is optimized around locality and throughput. Per-CPU lists, bulk
allocation, GFP scopes, cpusets, and memcg charging are all useful, but none is
a stable Domain ownership mechanism. Page reuse across Domains must be mediated
by monitor-owned page ownership and MemoryView invalidation, not inferred from
allocator queues.

### address_space and page cache

Evidence:

- `include/linux/fs.h` lines 401-442 defines address-space operations such as
  read, writeback, dirtying, readahead, invalidate, migrate, direct I/O, and
  swap operations.
- Lines 453-486 define `struct address_space`, whose `i_pages` XArray stores
  cached pages with invalidation, mapping, writeback, error, and private state.
- Lines 493-496 define page-cache dirty/writeback tags.
- Lines 762-870 define `struct inode`, including ownership, operations,
  superblock, mapping, security pointer, writeback/cgroup state, LRU/list state,
  embedded `i_data`, and filesystem/device private state.
- `mm/filemap.c` lines 870-990 adds folios to a mapping, charges memcg, and
  updates LRU/page-cache state.
- `mm/filemap.c` lines 1924-2055 looks up or creates page-cache folios.
- `mm/filemap.c` lines 2765-2985 implements page-cache reads, writeback wait,
  invalidation around direct I/O, and generic file reads.

CapSched interpretation:

The page cache is a major efficiency asset and a major isolation challenge.
Production CapSched cannot expose one shared mutable page-cache authority to all
Domains and still claim hypervisor-grade separation.

## Boundary Mismatches

### Page metadata is not Domain ownership

`struct page` and folio metadata record current kernel use, mapping, refcount,
mapcount, memcg data, and cache state. They do not state:

```text
this physical page may be mapped into Domain D's MemoryView
and no other Domain may map it unless a typed share exists
```

That property belongs below Linux.

### memcg is not a security boundary

memcg controls accounting, pressure, reclaim, and writeback integration. It is
not non-forgeable under arbitrary Domain-local Linux kernel execution.

CapSched should use memcg as:

```text
accounting substrate
pressure signal
compatibility bridge
possible budget mirror
```

not as:

```text
MemoryView root
page ownership root
Domain isolation proof
```

### Slab object lifetime is not capability authority

`SLAB_TYPESAFE_BY_RCU` is direct evidence that safe pointer lookup still needs
independent object identity validation. CapSched capability-bearing objects need
at least:

```text
object generation
Domain epoch
authority type
owner Domain
revocation state
```

### Per-CPU allocator queues mix performance and ownership

PCP lists and bulk allocation are designed to reduce contention and improve
throughput. They are not a security structure. A page moving through allocator
state must not become accessible to a new Domain until monitor ownership and
MemoryView mappings have been updated.

### Page cache is shared mutable state

`address_space->i_pages` is one of Linux's performance wins. It is also one of
the hardest parts of making process-scale domains hypervisor-grade.

Candidate future shape:

```text
sealed shared base:
  immutable verified file pages and kernel text

per-Domain overlay:
  mutable page-cache contents, dirty state, and writeback metadata

service Domain:
  filesystem parsing and storage control plane

monitor root:
  physical page ownership and MemoryView mapping
```

## CapSched Memory Layering

```text
HyperTag Monitor:
  PageOwner
  MemoryView
  revoke-before-reuse
  shared-page seal
  stage-2/EPT mapping

Linux CapSched core:
  shadow page metadata
  Domain-local object metadata
  generation/epoch checks
  typed MemoryCap/EndpointCap placeholders

Linux MM/memcg:
  accounting
  reclaim
  NUMA placement
  cgroup compatibility
  pressure and writeback signals

Service Domains:
  filesystem parser
  page-cache control plane
  storage device control plane
```

## Required Invariants

```text
MEM-001:
  No monitor PageOwner, no Domain MemoryView mapping.

MEM-002:
  Linux page/memcg/slab metadata must not create cross-Domain memory authority.

MEM-003:
  Mutable page-cache data is not shared across Domains except through a typed
  service endpoint or sealed shared base.

MEM-004:
  Slab object lifetime or refcount validity is not capability authority without
  generation, epoch, and Domain checks.

MEM-005:
  Page revocation removes MemoryView mappings before the physical page is reused
  by another Domain.

MEM-006:
  Reclaim, writeback, and service memory work must carry caller provenance and
  a BudgetTicket when acting for a caller.

MEM-007:
  No Domain activation may carry untagged stale TLB translations into another
  Domain context.

MEM-008:
  No completed page revoke while MemoryView, direct-map, or TLB translations
  for that page remain.

MEM-009:
  Linux-visible direct-map shadow claims must not create hardware translation
  authority.

MEM-010:
  Mutable page-cache overlay state maps only into its owner Domain; sealed base
  content is the shareable form.

MEM-011:
  No stale overlay commit: page-cache overlay writeback requires provenance,
  ticket, current base version, and base-level serialization.
```

## Linux Patch Implications

For Slice 0B:

```text
Do not touch mm/, page allocator, memcg, page cache, slab, or VFS behavior.
Only opaque type names/comments are acceptable.
```

For later L2:

```text
CapSched-owned authority caches may need SLAB_NO_MERGE or Domain-local cache
policy, but only after a MemoryOwnership model exists.
```

For L3 production:

```text
Monitor-owned PageOwner and MemoryView are mandatory for hypervisor-grade
memory isolation.
```

## Initial Formal Model

The first `MemoryOwnership` model set now exists:

```text
capsched/capsched-models/formal/0008-memory-ownership-model/
```

It was checked through decomposed TLC models:

```text
PageOwnerMemoryView
SlabObjGen
MemoryWorkProvenance
```

Validation record:

```text
capsched/capsched-models/validation/0010-memory-ownership-tlc.md
```

The broad integrated model remains stress coverage and is not a pass.

## Remaining Formal Candidates

Follow-on models have now covered three of these risks:

```text
MemoryOwnership:
  PageOwner, MemoryView, slab generation, memory work provenance

DirectMapTLB:
  direct-map visibility and TLB revocation ordering

PageCacheOverlay:
  sealed base sharing, per-Domain mutable overlays, writeback conflicts
```

The remaining separate memory/device-adjacent candidate is IOMMU/DMA
MemoryView interaction, which belongs with QueueLease modeling before L4 device
work.

The initial model covered these minimum objects:


```text
Domain
DomainEpoch
Page
PageOwner
MemoryView
LinuxShadowPage
SlabObjGen
PageCacheEntry
ServiceEndpoint
ReclaimWork
```

And these minimum checks:

```text
No PageOwner, no MemoryView mapping.
No stale page epoch after revoke.
No Linux shadow page claim confers mapping authority.
No page-cache mutable sharing without sealed base or endpoint.
No slab object reuse without generation mismatch rejection.
No reclaim/writeback work without provenance.
```

## Conclusion

Linux MM gives CapSched powerful building blocks, but not the root of trust.
The efficient path is to reuse Linux MM for normal accounting and performance
while moving the actual memory ownership decision below Linux.

That is the difference between:

```text
strong container:
  Linux metadata and policy say this should be separated

monitor-backed CapSched:
  hardware-enforced MemoryView makes the separation physically true
```
