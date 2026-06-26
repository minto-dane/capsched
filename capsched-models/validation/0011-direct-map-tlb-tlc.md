# Validation 0011: Direct Map and TLB Revocation TLC Check

Status: Passed after counterexample-driven fix

Date: 2026-06-26

## Purpose

Validate the next memory safety obligation after `MemoryOwnership`: correct
PageOwner and MemoryView authority is insufficient if stale direct-map or CPU
TLB translations can still reach a page.

This validation supports the CapSched-H memory claim:

```text
No live Domain authority, no usable translation path.
```

## Model Directory

```text
capsched/capsched-models/formal/0009-direct-map-tlb-model/
```

## First Counterexample

The first TLC run found a real bug in the initial model:

```text
CPU c1 runs Domain d1.
c1 loads a TLB entry for d1-owned page p1.
c1 switches to Domain d2 without flushing or retagging TLB.
The stale p1 TLB entry remains present in a d2 CPU context.
```

The violated invariant was:

```text
NoTlbForeignActiveDomain
```

This is useful evidence, not a nuisance. It says Domain activation must include
translation invalidation or architectural translation tagging strong enough to
prevent old Domain translations from being usable in the new Domain context.

## Fix

The model uses the conservative semantic rule:

```text
ActivateCpu clears that CPU's TLB.
```

Production implementations may use ASID, PCID, VMID, EPTP, or stage-2 tagging
instead of a full flush, but the semantic obligation is identical: an untagged
stale translation from one Domain cannot survive activation of another Domain.

The Linux shadow direct-map invariant was also strengthened:

```text
Forged Linux shadow direct-map claims are not real direct-map authority unless
the page is live for that same Domain.
```

## Command

```sh
java -XX:+UseParallelGC \
  -cp /home/nia/tools/tla/tla2tools.jar \
  tlc2.TLC \
  -workers 8 \
  -fp 0 \
  -metadir /media/nia/scsiusb/dev/linux-cap/build/tlc/direct-map-tlb-20260626T \
  DirectMapTLB.tla
```

Working directory:

```text
capsched/capsched-models/formal/0009-direct-map-tlb-model/
```

## Result

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

Checked invariants:

```text
TypeOK
NoMemoryViewForeignPage
NoDirectMapForeignPage
NoAccessWithoutCurrentAuthority
NoFreePageMappedOrCached
NoFinishedRevokeWithStaleTlb
NoLinuxShadowDirectMapAuthority
NoTlbForeignActiveDomain
```

## Security Interpretation

The checked model supports these rules:

```text
1. Actual direct-map entries must refine monitor-owned PageOwner and live Domain epoch.
2. Domain activation must flush or retag stale translations.
3. Page revoke cannot finish while MemoryView, direct-map, or TLB entries remain.
4. A revoking page may have stale TLB entries only as non-authority transition state.
5. A free page has no MemoryView, direct-map, TLB, or active access state.
6. Linux-visible shadow direct-map claims are not authority.
```

## Non-Claims

This validation does not prove:

- architecture-specific TLB shootdown implementation,
- IPI completion ordering,
- PCID/ASID/VMID/EPTP correctness,
- speculative side-channel resistance,
- real stage-2/EPT programming,
- page-cache overlay conflict semantics,
- DMA/IOMMU isolation.

Those remain separate gates.
