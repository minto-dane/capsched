# Formal 0011: Queue Lease and IOMMU Boundary Model

Status: Checked with two TLC runs

Date: 2026-06-26

Linux base:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
commit: 0b685979f27b3d42ee620ced5f707ee391a2a27f
```

## Purpose

This model pressures the L4 device/I/O security boundary before any VFIO,
iommufd, IOMMU, or driver work.

The model treats a QueueLease as one indivisible authority boundary:

```text
QueueTag
owner Domain epoch
IOMMU DMA buffer map
interrupt route
submit budget
```

If any piece is stale or missing, the queue must not submit, DMA, or deliver a
completion interrupt as that Domain.

## Threat Assumption

Linux-visible queue ownership and IOMMU claims may be forged. The model
represents them with shadow queue owner and shadow IOMMU map state. Shadow
claims must never create real doorbell, DMA, or IRQ authority.

## Files

```text
QueueLease.tla
QueueLease.cfg
notes.md
```

## Encoded Safety Properties

```text
NoDoorbellWithoutLiveQueueLease
NoIommuMapWithoutQueueAndBufferAuthority
NoDmaWithoutIommuMap
NoIrqRouteForeign
NoIrqDeliveryForeign
NoIrqAliasedAcrossQueues
NoRevokedQueueHasAuthority
NoFreeOrRevokingBufferMappedOrDma
NoLinuxShadowQueueAuthority
NoLinuxShadowIommuAuthority
NoStaleQueueEpoch
```

## TLC Result

TLC completed the finite state graph twice with different fingerprint indexes
and no invariant errors:

```text
primary run:
  97882849 states generated
  6465312 distinct states found
  0 states left on queue
  depth: 23

second run:
  97882849 states generated
  6465312 distinct states found
  0 states left on queue
  depth: 24
```
