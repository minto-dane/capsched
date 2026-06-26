# Validation 0013: Queue Lease and IOMMU Boundary TLC Check

Status: Passed with two finite TLC runs

Date: 2026-06-26

## Purpose

Validate the L4 device/I/O semantic boundary before any VFIO, iommufd, IOMMU,
or driver patch work.

The production claim is:

```text
Queue submit, DMA mapping, interrupt delivery, epoch, and rate budget are one
lease boundary.
```

## Model Directory

```text
capsched/capsched-models/formal/0011-queue-lease-model/
```

## Commands

Primary run:

```sh
java -XX:+UseParallelGC \
  -cp /home/nia/tools/tla/tla2tools.jar \
  tlc2.TLC \
  -workers 8 \
  -fp 0 \
  -metadir /media/nia/scsiusb/dev/linux-cap/build/tlc/queue-lease-20260626T \
  QueueLease.tla
```

Second run:

```sh
java -XX:+UseParallelGC \
  -cp /home/nia/tools/tla/tla2tools.jar \
  tlc2.TLC \
  -workers 8 \
  -fp 1 \
  -metadir /media/nia/scsiusb/dev/linux-cap/build/tlc/queue-lease-20260626T-fp1 \
  QueueLease.tla
```

Working directory:

```text
capsched/capsched-models/formal/0011-queue-lease-model/
```

## Results

Primary run:

```text
Model checking completed. No error has been found.
97882849 states generated
6465312 distinct states found
0 states left on queue
depth: 23
fingerprint collision estimate:
  calculated optimistic: 3.2E-5
  actual fingerprints: 2.4E-6
```

Second run:

```text
Model checking completed. No error has been found.
97882849 states generated
6465312 distinct states found
0 states left on queue
depth: 24
fingerprint collision estimate:
  calculated optimistic: 3.2E-5
  actual fingerprints: 2.8E-6
```

Checked invariants:

```text
TypeOK
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

## Security Interpretation

The checked model supports these rules:

```text
1. A queue cannot submit without a live QueueLease and owner Domain epoch.
2. DMA cannot occur without a live monitor IOMMU map to an owner buffer.
3. IOMMU mappings cannot point at another Domain's buffer.
4. Interrupt delivery must target the same live owner as the queue.
5. IRQ routes cannot be aliased across non-free queues.
6. Queue revoke removes submit, DMA map, in-flight DMA, and IRQ route together.
7. Domain revoke removes owned queues and buffers from active authority.
8. Linux-visible shadow queue and IOMMU claims do not create authority.
9. Queue budget exhaustion prevents further doorbells.
```

## Non-Claims

This validation does not prove:

- real PCIe, ATS, PASID, PRI, or interrupt remapping behavior,
- real VFIO or iommufd implementation correctness,
- driver-specific queue semantics,
- device firmware correctness,
- MSI-X table programming,
- IOMMU TLB invalidation ordering,
- NAPI, io_uring, or eventfd completion integration,
- side-channel isolation.

Those remain separate gates.
