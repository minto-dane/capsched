# Formal 0009: Direct Map and TLB Revocation Model

Status: Checked with TLC after counterexample-driven fix

Date: 2026-06-26

Linux base:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
commit: 0b685979f27b3d42ee620ced5f707ee391a2a27f
```

## Purpose

This model pressures the next memory risk after the initial MemoryOwnership
model: a correct PageOwner is not enough if stale direct-map or TLB translations
can still reach a page.

Production CapSched-H must ensure:

```text
No foreign direct-map entry.
No completed page revoke while stale TLB entries remain.
No stale TLB access after a page has left the active Domain's authority.
```

## Threat Assumption

Linux-visible direct-map claims may be forged. The model represents them as a
shadow set. Actual direct-map entries are monitor-owned state.

An attacker may run in a Domain kernel context and try to access pages through:

```text
Domain MemoryView
Domain direct-map subset
stale CPU TLB entry
forged Linux shadow direct-map claim
```

Only the first three can be real hardware paths. The last one must never create
authority.

## Files

```text
DirectMapTLB.tla
DirectMapTLB.cfg
notes.md
```

## Encoded Safety Properties

```text
NoMemoryViewForeignPage
NoDirectMapForeignPage
NoAccessWithoutCurrentAuthority
NoFreePageMappedOrCached
NoFinishedRevokeWithStaleTlb
NoLinuxShadowDirectMapAuthority
NoTlbForeignActiveDomain
```

## TLC Result

The first TLC run found a real stale-translation bug: a CPU could switch from
one Domain to another while carrying an old TLB entry. The model was fixed by
making Domain activation clear that CPU's TLB. A production design may use
tagged translations instead of a full flush, but it must preserve the same
semantic invariant.

After the fix, TLC completed the finite state graph with no invariant errors:

```text
8224001 states generated
386784 distinct states found
0 states left on queue
depth: 21
```
