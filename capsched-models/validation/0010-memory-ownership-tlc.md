# Validation 0010: Memory Ownership TLC Check

Status: Passed for decomposed finite models

Date: 2026-06-26

## Purpose

Validate the first memory ownership semantics before any L2 MM, slab,
page-cache, or reclaim implementation work.

This validation supports the CapSched-H memory claim:

```text
No monitor PageOwner and MemoryView mapping, no Domain memory access.
```

It also validates that Linux-visible shadow metadata is not authority.

## Model Directory

```text
capsched/capsched-models/formal/0008-memory-ownership-model/
```

## Broad Integration Attempt

The broad `MemoryOwnership.tla` model combines:

```text
PageOwner
MemoryView mapping
sealed pages
mutable page-cache overlays
Linux shadow page claims
slab object generation
memory work provenance and tickets
Domain epoch revoke
```

It was stopped after state growth without invariant errors observed before
interruption:

```text
117095466 states generated
17752582 distinct states found
11234928 states left on queue
depth: 12
```

This is not a pass. It remains broad stress coverage.

## Decomposed Proof Root

### PageOwnerMemoryView

Command:

```sh
java -XX:+UseParallelGC \
  -cp /home/nia/tools/tla/tla2tools.jar \
  tlc2.TLC \
  -workers 8 \
  -fp 0 \
  -metadir /media/nia/scsiusb/dev/linux-cap/build/tlc/page-owner-memory-view-20260626T \
  PageOwnerMemoryView.tla
```

Result:

```text
Model checking completed. No error has been found.
22257 states generated
2704 distinct states found
0 states left on queue
depth: 11
fingerprint collision estimate:
  calculated optimistic: 2.9E-12
```

Checked invariants:

```text
TypeOK
NoMappingWithoutMonitorAuthority
NoMutablePageMappedAcrossDomains
NoFreePageMapped
NoStaleEpochMapping
NoLinuxShadowConfersMappingAuthority
NoMutablePageCacheSharing
NoSealedPageHasMutableOwner
```

### SlabObjGen

Command:

```sh
java -XX:+UseParallelGC \
  -cp /home/nia/tools/tla/tla2tools.jar \
  tlc2.TLC \
  -workers 8 \
  -fp 1 \
  -metadir /media/nia/scsiusb/dev/linux-cap/build/tlc/slab-obj-gen-20260626T \
  SlabObjGen.tla
```

Result:

```text
Model checking completed. No error has been found.
140977 states generated
19728 distinct states found
0 states left on queue
depth: 17
fingerprint collision estimate:
  calculated optimistic: 1.3E-10
  actual fingerprints: 4.8E-12
```

Checked invariants:

```text
TypeOK
NoObjectUseWithoutLiveGeneration
NoObjectUseAcrossPageOwner
NoFreePageHasLiveObject
NoLinuxObjectShadowConfersAuthority
```

### MemoryWorkProvenance

Command:

```sh
java -XX:+UseParallelGC \
  -cp /home/nia/tools/tla/tla2tools.jar \
  tlc2.TLC \
  -workers 8 \
  -fp 2 \
  -metadir /media/nia/scsiusb/dev/linux-cap/build/tlc/memory-work-provenance-20260626T \
  MemoryWorkProvenance.tla
```

Result:

```text
Model checking completed. No error has been found.
39217 states generated
4880 distinct states found
0 states left on queue
depth: 13
fingerprint collision estimate:
  calculated optimistic: 9.1E-12
```

Checked invariants:

```text
TypeOK
NoWorkExecutionWithoutProvenanceTicket
NoQueuedWorkWithoutLivePage
NoFreePageHasPendingWork
NoLinuxWorkShadowConfersExecution
```

## Security Interpretation

The checked models support these rules:

```text
1. Mutable pages require monitor-owned PageOwner and live Domain epoch.
2. MemoryView mappings cannot be created from Linux shadow page metadata.
3. Mutable private/cache pages cannot be mapped across Domains.
4. Sealed shared pages have no mutable owner.
5. Slab object use requires live object generation and backing page ownership.
6. Reclaim/writeback/service memory work requires caller provenance and ticket.
7. Domain revoke clears or invalidates owned pages, object use, and memory work.
```

## Non-Claims

This validation does not prove:

- real stage-2/EPT programming,
- TLB shootdown ordering,
- direct-map visibility constraints,
- DMA/IOMMU isolation,
- Linux SLUB implementation correctness,
- filesystem consistency,
- page-cache overlay conflict resolution.

Those remain separate gates.
