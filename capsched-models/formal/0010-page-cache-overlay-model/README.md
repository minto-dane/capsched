# Formal 0010: Page Cache Overlay Conflict Model

Status: Checked with TLC after counterexample-driven fix

Date: 2026-06-26

Linux base:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
commit: 0b685979f27b3d42ee620ced5f707ee391a2a27f
```

## Purpose

This model pressures the remaining L2 memory risk after the initial
MemoryOwnership and DirectMapTLB models: Linux page cache efficiency depends on
shared state, but hypervisor-grade Domain isolation cannot allow shared mutable
page-cache authority.

The intended production shape is:

```text
sealed shared base:
  immutable file/cache content visible to multiple Domains

per-Domain overlay:
  mutable dirty state owned by one Domain

service-mediated commit:
  writeback or merge requires provenance, ticket, service epoch, and current
  base version
```

## Threat Assumption

Linux-visible page-cache ownership claims may be forged. The model represents
that with `linuxShadowOwner`. Shadow claims must not map, write back, or commit
another Domain's overlay.

## Files

```text
PageCacheOverlay.tla
PageCacheOverlay.cfg
notes.md
```

## Encoded Safety Properties

```text
NoOverlayMappingWithoutLiveOwner
NoMutableOverlayMappedAcrossDomains
NoFreeOverlayMappedOrPending
NoWritebackWithoutProvenanceTicket
NoStaleOverlayCanCommit
NoLinuxShadowOwnerAuthority
NoBaseMissingForLiveOverlay
```

## TLC Result

The first TLC run found a real conflict bug: two overlays could enter
`committing` for the same sealed base version. After one finished and advanced
the base version, the other remained a stale committing overlay.

The model was fixed by requiring base-level commit serialization:

```text
Only one overlay may be committing for a given sealed base.
```

After the fix, TLC completed the finite state graph with no invariant errors:

```text
7370677 states generated
524808 distinct states found
0 states left on queue
depth: 26
```
