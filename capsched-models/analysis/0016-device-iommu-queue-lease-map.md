# Analysis 0016: Device IOMMU and Queue Lease Map

Status: Draft

Date: 2026-06-26

Linux base:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
commit: 0b685979f27b3d42ee620ced5f707ee391a2a27f
```

## Purpose

This note maps Linux VFIO, iommufd, IOMMU ownership, and representative device
queue structures onto the CapSched production goal:

```text
driver/service Domain owns device control plane
Domain receives only typed queue leases for data plane
HyperTag Monitor owns the non-forgeable roots:
  IOMMU mappings
  queue ownership
  interrupt delivery ownership
  queue epochs
  rate/budget ceilings
```

This is not a Linux patch plan. It is a boundary map for future L4 work and for
the next formal model after the cluster lease result is known.

## Security Pressure

The data-center target needs stronger I/O semantics than ordinary VFIO device
assignment:

```text
No QueueLease, no device queue doorbell or queue ownership transfer.
No monitor-owned IOMMU mapping, no DMA into a Domain MemoryView.
Interrupt delivery must be owned by the same Domain or service endpoint as the
leased queue.
Linux shadow objects are policy cache, not authority root.
```

If arbitrary Linux code execution inside one Domain can program DMA, ring a
foreign queue doorbell, or receive another Domain's completion interrupt, the
hypervisor-replacement claim fails.

## Existing Linux Strengths

### iommufd object graph

`struct iommufd_ctx` already gives Linux an explicit object namespace:

```text
drivers/iommu/iommufd/iommufd_private.h:43-59
```

It carries an object xarray, group xarray, destruction wait queue, IOAS creation
lock, mmap metadata, software MSI state, accounting mode, no-IOMMU
compatibility, and VFIO compatibility IOAS.

`struct iommufd_object` gives each exported object a userspace ID, type, users
refcount, and wait count:

```text
include/linux/iommufd.h:28-59
drivers/iommu/iommufd/iommufd_private.h:169-251
```

This is useful vocabulary for CapSched compatibility because Linux already has:

```text
object ids
explicit object types
refcounted lifecycle
tombstone/remove semantics
destroy wait semantics
```

However, these objects are Linux-owned mutable state. Under the final hostile
kernel-context threat model they cannot be the root of device ownership.

### IOAS and HWPT split

`struct io_pagetable` is an IOVA-to-PFN map that can copy PFNs into multiple
IOMMU domains:

```text
drivers/iommu/iommufd/iommufd_private.h:73-97
```

The code explicitly supports IOAS 1:1 with a domain or IOAS 1:N with multiple
generic domains. It also tracks allowed IOVA ranges and reserved IOVA ranges.
IOAS allocation and map/unmap paths are in:

```text
drivers/iommu/iommufd/ioas.c:13-36
drivers/iommu/iommufd/ioas.c:66-184
drivers/iommu/iommufd/ioas.c:186-280
```

HW page table allocation links an IOMMU domain to an IOAS and populates the
domain:

```text
drivers/iommu/iommufd/hw_pagetable.c:88-204
```

CapSched reading:

```text
IOAS resembles a software MemoryView/IOVA policy object.
HWPT resembles a concrete hardware mapping instance.
```

Future CapSched should use this split as compatibility vocabulary, but the
monitor must own the final IOMMU mapping root for production isolation.

### Device bind and DMA ownership

`iommufd_device_bind()` already speaks in ownership terms:

```text
drivers/iommu/iommufd/device.c:202-217
```

Important properties:

```text
successful bind establishes ownership
driver must set driver_managed_dma
driver must not touch the device until bind succeeds
PCI bind places the entire RID under iommufd control
```

The function requires IOMMU cache coherency support and claims DMA ownership:

```text
drivers/iommu/iommufd/device.c:225-230
drivers/iommu/iommufd/device.c:256-257
```

The IOMMU core enforces a single owner value for a group, or the same owner for
multiple devices in a group:

```text
drivers/iommu/iommu.c:3414-3480
```

It releases ownership by restoring the default domain:

```text
drivers/iommu/iommu.c:3482-3525
```

CapSched reading:

```text
Linux already has an exclusive DMA-owner concept.
The missing piece is that the owner value is a Linux pointer, not a
monitor-sealed QueueLease or DomainToken.
```

### Interrupt isolation is already a first-class warning

iommufd refuses insecure interrupt configurations unless a module parameter is
set:

```text
drivers/iommu/iommufd/device.c:14-19
drivers/iommu/iommufd/device.c:236-253
```

The IOMMU core checks isolated MSI across all devices in a group:

```text
drivers/iommu/iommu.c:2022-2043
```

This is directly relevant to CapSched. A queue lease without interrupt delivery
ownership is incomplete. DMA isolation and interrupt isolation must be treated
as one lease boundary, not as independent conveniences.

### VFIO compatibility path

VFIO already binds physical devices through iommufd:

```text
drivers/vfio/iommufd.c:117-149
```

It attaches, replaces, and detaches IOAS/HWPT for physical devices and PASIDs:

```text
drivers/vfio/iommufd.c:151-225
```

It also has an emulated access path that pins pages and calls device-specific
DMA callbacks:

```text
drivers/vfio/iommufd.c:227-303
```

CapSched reading:

```text
VFIO/iommufd is a strong compatibility substrate for device assignment.
It is not yet a Domain queue lease system.
```

### iommufd HW queue support

Current iommufd has `IOMMUFD_OBJ_HW_QUEUE`:

```text
include/linux/iommufd.h:28-45
include/linux/iommufd.h:129-141
include/uapi/linux/iommufd.h:1298-1353
```

The current UAPI documents a vIOMMU-specific hardware-accelerated queue. The
only visible UAPI type in this tree is Tegra241 SMMUv3 VCMDQ:

```text
include/uapi/linux/iommufd.h:1298-1319
```

The allocator pins physically contiguous queue memory so hardware cannot keep
accessing queue memory after IOAS unmap:

```text
drivers/iommu/iommufd/viommu.c:281-354
drivers/iommu/iommufd/viommu.c:356-430
```

This is an important precedent, but it is not the same as CapSched data-plane
queue leasing for NIC, NVMe, or GPU queues. It is primarily vIOMMU queue support
inside the IOMMU subsystem.

### Real device queues are typed and driver-local

Linux networking exposes NAPI and netdev TX queue state:

```text
include/linux/netdevice.h:381-419
include/linux/netdevice.h:650-729
```

NVMe PCI queues carry SQ/CQ memory, DMA addresses, a doorbell pointer, qid,
phase, queue flags, and shadow doorbell buffers:

```text
drivers/nvme/host/pci.c:361-394
drivers/nvme/host/pci.c:718-733
drivers/nvme/host/pci.c:1436-1480
drivers/nvme/host/pci.c:1538-1627
```

mlx5 Ethernet queues and channels carry TX/RX/XDP queue state, completion
queues, UAR doorbell mapping, memory keys, NAPI, and per-queue control state:

```text
drivers/net/ethernet/mellanox/mlx5/core/en.h:420-470
drivers/net/ethernet/mellanox/mlx5/core/en.h:488-567
drivers/net/ethernet/mellanox/mlx5/core/en.h:671-790
drivers/net/ethernet/mellanox/mlx5/core/en_tx.c:371-421
drivers/net/ethernet/mellanox/mlx5/core/en_tx.c:590-610
```

CapSched reading:

```text
There is no generic Linux "device queue" authority point.
Queue meaning is typed by driver and subsystem.
```

This supports the typed endpoint direction. A single generic `QueueCap` should
not hide device-specific semantics. The shared layer should define common
invariants; each endpoint defines its own valid operations and consumption
rules.

## Boundary Mismatches

### Linux ownership is not monitor ownership

iommufd, VFIO, and the IOMMU core can enforce strong ownership while Linux is
trusted. They cannot by themselves survive arbitrary Linux kernel-context code
execution inside one Domain because their authority state is mutable Linux
memory.

Production CapSched needs:

```text
Linux shadow:
  object ids, policy cache, file descriptors, compatibility ioctls

Monitor root:
  Domain id
  epoch
  MemoryView id
  IOMMU mapping id
  QueueTag
  IRQ/event route
  rate/budget ceiling
```

### Device assignment is too broad

`iommufd_device_bind()` places an entire PCI RID under iommufd control. That is
appropriate for VFIO-style assignment, but CapSched's performance path is
direct queue leasing:

```text
ordinary VM path:
  pass through device or emulate virtio

CapSched path:
  service/driver Domain owns device control plane
  target Domain receives one or more typed data queues
```

The lease unit should be queue, completion route, DMA view, and rate limit, not
necessarily an entire physical device.

### Queue doorbells are not centralized

NVMe rings a queue doorbell by writing to `nvmeq->q_db`; mlx5 notifies hardware
through driver-specific UAR mappings. Network stack TX queues track stop/freeze
state but do not own the hardware doorbell.

Therefore a future CapSched QueueLease cannot be a single scheduler hook. It
needs typed integration at driver/service endpoints and a monitor-owned mapping
or doorbell gate for production.

### Interrupts and completions are part of authority

The iommufd MSI checks are a warning sign for our design: a queue lease is not
safe if DMA is isolated but interrupts or completion events can be delivered
outside the owning Domain or service endpoint.

NAPI, IRQ affinity, threaded NAPI, poll queues, eventfds, MSI-X tables, and
device-specific completion queues all become part of the lease boundary.

### Broad ioctls remain too much authority

VFIO and driver ioctls are designed for trusted-kernel device management and
userspace drivers. For CapSched, raw device ioctl authority is too broad for a
Domain that should only own a typed data path.

The driver/service Domain should keep:

```text
reset
firmware operations
queue creation/destruction
MSI-X table programming
IOMMU domain construction
device health recovery
```

The tenant/process/container Domain should receive only:

```text
queue submit/consume operation authority
DMA buffers in its MemoryView
completion/interrupt route
rate/budget allocation
revocation epoch
```

## CapSched QueueLease Model Sketch

A future semantic model should treat a queue lease as a typed resource lease:

```c
struct capsched_queue_lease {
        u64 queue_tag;
        u64 device_id;
        u64 queue_id;
        u64 owner_domain;
        u64 service_domain;
        u64 epoch;

        u64 memory_view_id;
        u64 iommu_map_id;
        u64 irq_route_id;

        u64 rate_budget;
        u64 burst_budget;
        unsigned long operations;
        unsigned long flags;
};
```

This is conceptual only. Do not add this to Linux yet.

The minimal state machine should include:

```text
AcquireQueueLease:
  service Domain requests queue lease
  policy front-end approves
  monitor creates QueueTag, IOMMU map, IRQ route, and epoch
  Linux receives only a shadow handle

UseQueueLease:
  Domain submits to queue endpoint
  endpoint checks typed operation and frozen endpoint/queue use
  monitor or monitor-derived gate checks QueueTag, MemoryView, IOMMU map, epoch,
  and rate/budget

CompleteQueueWork:
  completion is delivered to owner Domain or service endpoint only
  service work requires caller BudgetTicket if it executes on behalf of caller

RevokeQueueLease:
  monitor bumps queue epoch
  doorbell path is disabled
  IOMMU mapping is removed
  IRQ/event route is removed
  Linux shadow object is tombstoned or made stale
```

## Required Invariants for a QueueLease Model

```text
DEVICE-001:
  No QueueLease, no device queue doorbell or queue ownership transfer.

DEVICE-002:
  No monitor-owned IOMMU mapping, no DMA into a Domain MemoryView.

DEVICE-003:
  Interrupt delivery must be owned by the same Domain/service endpoint as the
  leased queue.

DEVICE-004:
  Linux shadow queue state must not create authority without a live monitor
  QueueTag and epoch.

DEVICE-005:
  Revocation invalidates queue submit, queue completion, IOMMU map, and IRQ
  delivery together.

DEVICE-006:
  Queue rate/budget exhaustion prevents further submit even if Linux queue state
  says the queue is available.
```

## Existing Object Mapping

| Existing object | CapSched reading | Hazard | Future target |
| --- | --- | --- | --- |
| `iommufd_ctx` | Linux object namespace for I/O authority shadows | mutable Linux root | policy/cache namespace below monitor-issued leases |
| `iommufd_object` | typed handle lifecycle | refcount is not security under kernel compromise | shadow handle with monitor epoch |
| `IOAS` / `io_pagetable` | IOVA policy and MemoryView-like map | Linux-owned IOVA-to-PFN state | monitor-backed MemoryView/IOMMU map with Linux compatibility shadow |
| `HWPT` | concrete IOMMU domain instance | Linux can allocate/replace if compromised | monitor-owned IOMMU map id, with Linux using approved handle |
| `iommufd_device` | device/RID ownership | device-granularity is broad | service Domain control-plane ownership |
| `iommu_group` owner | existing exclusive DMA owner | owner is a pointer value in Linux memory | monitor-sealed DMA owner and queue tag |
| isolated MSI check | interrupt isolation precondition | module override allows insecure path | production hard fail for unsafe interrupts |
| `IOMMUFD_OBJ_HW_QUEUE` | precedent for queue object and pinned queue memory | vIOMMU queue, not generic data-plane queue | typed queue lease family |
| `netdev_queue` / NAPI | network TX and RX scheduling state | no monitor authority, driver semantics vary | NetQueueLease endpoint |
| `nvme_queue` | SQ/CQ, DMA memory, doorbells, qid | doorbell is driver-local MMIO path | NvmeQueueLease endpoint |
| `mlx5e_txqsq` / `mlx5e_rq` / `mlx5e_xdpsq` | high-performance NIC queue state | UAR/doorbell and memory key authority are driver-specific | Mlx5QueueLease endpoint or service-domain mediated lease |
| VFIO emulated access | pinned access path for emulated devices | too broad for tenant queue lease | service endpoint or compatibility-only path |

## Linux Patch Implications

Slice 0B must not touch VFIO, iommufd, IOMMU, or drivers. Those areas are L4
and require a QueueLease model first.

For future L4:

```text
Use iommufd vocabulary where it preserves Linux compatibility.
Do not make iommufd Linux objects the production security root.
Keep driver/service Domain control-plane authority separate from tenant data
queue authority.
Treat queue lease, DMA mapping, and IRQ route as one revocation unit.
Avoid generic raw ioctl authority as a Domain data-plane interface.
```

The likely integration shape is:

```text
Linux:
  iommufd/VFIO/service-driver object graph
  typed endpoint operations
  audit and policy front-end

HyperTag Monitor:
  QueueTag
  MemoryView/IOMMU map
  IRQ route
  queue epoch
  rate/budget ceiling
```

## Next Formal Candidate

After the ClusterLease full TLC run completes, the next useful model candidate
is:

```text
QueueLease:
  Domain
  ServiceDomain
  Queue
  QueueTag
  MemoryView
  IOMMUMap
  InterruptRoute
  Epoch
  RateBudget
  LinuxShadow
```

The adversary should be allowed to:

```text
forge Linux shadow queue state
try to ring a queue without QueueTag
try to DMA outside MemoryView
try to keep completion/IRQ route after revocation
try to use stale epoch
try to spend queue budget twice
```

The model should prove the invariants in this note before any device/IOMMU
Linux patch is considered.
