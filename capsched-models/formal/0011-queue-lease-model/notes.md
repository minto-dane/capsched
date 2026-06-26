# Notes: Queue Lease and IOMMU Boundary

Date: 2026-06-26

## Why This Exists

Hypervisor-grade Domain separation fails if a compromised Domain can program a
foreign device queue, DMA into another Domain, or receive another Domain's
completion interrupt.

Linux already has useful I/O vocabulary through VFIO, iommufd, IOMMU groups,
IOAS/HWPT, MSI isolation checks, and driver-local queue objects. But those are
Linux-owned mutable state. Production CapSched-H needs a monitor-owned root.

## QueueLease Semantic Unit

The model intentionally makes these inseparable:

```text
queue owner
queue epoch
IOMMU buffer map
IRQ route
submit budget
```

Revocation clears submit, DMA map, in-flight DMA, and IRQ route together.

## TLC Result

TLC completed the finite model twice with different fingerprint indexes:

```text
primary run:
  Model checking completed. No error has been found.
  97882849 states generated
  6465312 distinct states found
  0 states left on queue
  depth: 23

second run:
  Model checking completed. No error has been found.
  97882849 states generated
  6465312 distinct states found
  0 states left on queue
  depth: 24
```

The checked result supports these semantic requirements:

```text
No QueueLease, no doorbell.
No monitor IOMMU map, no DMA.
No queue-owned IRQ route, no completion delivery.
No IRQ route aliasing across non-free queues.
Queue revoke clears submit, DMA map, in-flight DMA, and IRQ route together.
Linux shadow queue/IOMMU state is not authority.
```

## Non-Goals

This model does not prove:

```text
real PCIe, ATS, PASID, PRI, or interrupt-remapping behavior
real VFIO/iommufd implementation correctness
driver-specific queue semantics
device firmware correctness
MSI-X table programming
NAPI or io_uring completion semantics
IOMMU TLB invalidation ordering
```

Those are future device-specific and architecture-specific gates.
