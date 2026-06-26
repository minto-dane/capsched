# Validation 0012: Page Cache Overlay Conflict TLC Check

Status: Passed after counterexample-driven fix

Date: 2026-06-26

## Purpose

Validate the remaining L2 page-cache safety obligation before any real
per-Domain page-cache overlay implementation work.

The production claim is:

```text
Mutable page-cache state is per-Domain overlay state or service-mediated commit
state, never shared ambient Linux authority.
```

## Model Directory

```text
capsched/capsched-models/formal/0010-page-cache-overlay-model/
```

## First Counterexample

The first TLC run found a real bug in the initial model:

```text
Two overlays are dirty against the same sealed base version.
Both enter committing.
One finishes and advances the sealed base version.
The other remains a stale committing overlay.
```

The violated invariant was:

```text
NoStaleOverlayCanCommit
```

This is a meaningful design finding: page-cache overlay commit/writeback cannot
be merely per-overlay. It needs base-level serialization or an equivalent
commit token.

## Fix

The model uses this rule:

```text
Only one overlay may be committing for a given sealed base.
```

Production mechanisms remain undecided. Candidates include:

```text
service-Domain merge lock
address_space/inode-level commit serialization
monitor-backed base commit token
```

The semantic requirement is the same for all of them: no stale mutable overlay
can commit after another overlay has advanced the sealed base.

## Command

```sh
java -XX:+UseParallelGC \
  -cp /home/nia/tools/tla/tla2tools.jar \
  tlc2.TLC \
  -workers 8 \
  -fp 0 \
  -metadir /media/nia/scsiusb/dev/linux-cap/build/tlc/page-cache-overlay-20260626T \
  PageCacheOverlay.tla
```

Working directory:

```text
capsched/capsched-models/formal/0010-page-cache-overlay-model/
```

## Result

```text
Model checking completed. No error has been found.
7370677 states generated
524808 distinct states found
0 states left on queue
depth: 26
fingerprint collision estimate:
  calculated optimistic: 1.9E-7
  actual fingerprints: 1.3E-8
```

Checked invariants:

```text
TypeOK
NoOverlayMappingWithoutLiveOwner
NoMutableOverlayMappedAcrossDomains
NoFreeOverlayMappedOrPending
NoWritebackWithoutProvenanceTicket
NoStaleOverlayCanCommit
NoLinuxShadowOwnerAuthority
NoBaseMissingForLiveOverlay
```

## Security Interpretation

The checked model supports these rules:

```text
1. Sealed base content may be shared, but mutable overlay state is Domain-owned.
2. A mutable overlay maps only into its owner Domain.
3. Dirty/queued/committing overlay work requires live owner epoch and ticket.
4. A stale overlay cannot enter or remain in committing state.
5. Base-level commit serialization is required for overlay writeback.
6. Linux-visible shadow ownership does not map or commit an overlay.
7. Domain revoke removes owned overlays and pending overlay work.
```

## Non-Claims

This validation does not prove:

- POSIX filesystem semantics,
- mmap coherence,
- direct I/O invalidation,
- truncate, hole-punch, rename, or reflink behavior,
- XArray locking correctness,
- writeback error propagation,
- real filesystem parser isolation,
- DMA/IOMMU isolation.

Those remain separate gates.
