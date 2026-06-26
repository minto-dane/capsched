# Notes: Direct Map and TLB Revocation

Date: 2026-06-26

## Why This Exists

The MemoryOwnership model says PageOwner and MemoryView are authority. But a
real kernel has additional translation paths:

```text
kernel direct map
per-CPU TLB state
speculative/stale translations
```

If Domain-private pages remain visible through a shared direct map, a
Domain-local kernel exploit can bypass the PageOwner story. If a page is reused
before stale TLB entries are gone, a previous Domain can retain access to a
new Domain's page.

## Modeled Revoke Sequence

```text
StartPageRevoke:
  remove MemoryView mapping
  remove direct-map entry
  mark page revoking

FlushTlb:
  remove stale CPU TLB entries for that page

FinishPageRevoke:
  allowed only after no MemoryView, direct-map, or TLB entry remains
```

The model permits TLB entries to exist during the revoking phase, but they do
not confer access. This reflects a conservative production rule: a page can be
in revoke transition, but it must not be reused for another Domain until flush
completion.

## First Counterexample

The first TLC run found a real ordering bug in the model:

```text
CPU c1 runs Domain d1
c1 loads a TLB entry for d1-owned page p1
c1 switches to Domain d2 without flushing or retagging TLB
the stale p1 TLB entry is now present in a d2 CPU context
```

The model fix is conservative:

```text
ActivateCpu clears that CPU's TLB.
```

Production implementations may use tagged translations instead of a full flush,
but the invariant is the same: stale translations from one Domain must not be
usable after activation of another Domain.

The Linux shadow direct-map invariant was then strengthened. A forged Linux
shadow direct-map claim must not correspond to any real direct-map authority
unless the page is live for that same Domain.

## Final TLC Result

After the activation fix, TLC completed the finite model:

```text
Model checking completed. No error has been found.
8224001 states generated
386784 distinct states found
0 states left on queue
depth: 21
fingerprint collision estimate:
  calculated optimistic: 1.6E-7
  actual fingerprints: 2.8E-9
```

The checked result supports these semantic requirements:

```text
Domain activation flushes or retags stale translations.
Page revoke cannot finish while MemoryView, direct-map, or TLB translations remain.
Linux-visible shadow direct-map claims do not create hardware translation authority.
Actual direct-map entries refine PageOwner and live Domain epoch.
```

## What This Does Not Prove

This model does not prove actual architecture-specific shootdown mechanics,
IPI ordering, PCID/ASID invalidation, speculative side-channel safety, or EPT
programming. It only fixes the semantic order required before those mechanisms
are implemented.
