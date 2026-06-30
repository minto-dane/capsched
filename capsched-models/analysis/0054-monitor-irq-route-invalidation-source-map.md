# Analysis 0054: Monitor IRQ Route Invalidation Source Map

Status: Draft source map with model gate

Date: 2026-06-29

Related artifacts:

```text
analysis/0053-ice-modern-nic-revoke-source-map.md
validation/0051-ice-revoke-readiness-result.md
formal/0032-vf-irq-revoke-ownership-model/
validation/0052-vf-irq-revoke-ownership-tlc.md
```

## Purpose

N-080 established that the `ICE_VSI_VF` path must not borrow host
`synchronize_irq()` as a QueueLease revoke proof. N-081 maps the next layer:
what a monitor-backed IRQ route invalidation protocol must require from Linux
`ice`, VFIO, iommufd, MSI/MSI-X allocation, and interrupt-remapping substrate.

This is not an implementation plan and not protection evidence.

## Core Rule

For CapSched-H:

```text
IRQ route reachability is a monitor-owned QueueLease sub-authority.
```

Linux IRQ objects, VFIO eventfds, MSI-X vectors, iommufd isolated-MSI checks,
and interrupt-remapping table entries are substrate and observation points.
They are not the production authority root.

The minimal monitor-backed revoke ordering is:

```text
1. Begin queue epoch revoke.
2. Block new submit and new doorbell effects for the old QueueTag.
3. Mask or disable the device-visible interrupt source where Linux can do so.
4. Detach or quarantine user-visible delivery endpoints such as VFIO eventfd.
5. Invalidate the platform route below Linux:
     IRTE clear or equivalent route removal
     interrupt-entry-cache flush or equivalent
     posted-interrupt descriptor removal if present
6. Quiesce owner-specific in-flight IRQ/completion execution.
7. Drain or quarantine outstanding completion state.
8. Only then reassign the queue/IRQ route under a new queue epoch.
```

## Source Anchors

### Intel ice

Useful anchors:

```text
drivers/net/ethernet/intel/ice/ice_main.c:
  ice_vsi_req_irq_msix()
  devm_request_irq(..., vsi->irq_handler, ...)
  ice_vsi_dis_irq()
  QINT_RQCTL_CAUSE_ENA_M clear
  GLINT_DYN_CTL clear
  synchronize_irq(q_vector->irq.virq)
  ICE_VSI_VF synchronize_irq exception

drivers/net/ethernet/intel/ice/ice_lib.c:
  ice_vsi_free_irq()
  ice_vsi_release_msix()
  synchronize_irq(irq_num)
  devm_free_irq(...)
  ICE_VSI_VF early return

drivers/net/ethernet/intel/ice/ice_irq.c:
  ice_virt_get_irqs()
  ice_virt_free_irqs()
  pci_msix_free_irq()

drivers/net/ethernet/intel/ice/ice_sriov.c:
  VF first_vector_idx / num_msix allocation and free paths
```

Interpretation:

```text
ice can mask device queue causes and release Linux-visible IRQ resources.
ice also tracks VF virtual IRQ vector ranges.
This is useful substrate for observation and driver cooperation.
It does not prove monitor route invalidation, stale IRTE removal, eventfd
delivery quiescence, or posted-interrupt teardown.
```

The explicit hazard remains:

```text
ice_vsi_dis_irq() and ice_vsi_free_irq() return early for ICE_VSI_VF.
```

That may be correct for Linux's current host/VF ownership model, but CapSched-H
must not interpret it as proof that old VF interrupt delivery authority is
gone.

### VFIO PCI

Useful anchors:

```text
drivers/vfio/pci/vfio_pci_intrs.c:
  vfio_msihandler()
  eventfd_signal(trigger)
  vfio_msi_enable()
  pci_alloc_irq_vectors()
  vfio_msi_alloc_irq()
  pci_msix_alloc_irq_at()
  vfio_msi_set_vector_signal()
  free_irq(irq, ctx->trigger)
  request_irq(irq, vfio_msihandler, ...)
  irq_bypass_register_producer()
  vfio_msi_disable()
  vfio_virqfd_disable()
  vfio_msi_set_vector_signal(..., -1, ...)
  pci_free_irq_vectors()
```

Interpretation:

```text
VFIO maps device MSI/MSI-X delivery to eventfd and optional irq-bypass.
This is the user-visible delivery substrate.
It is not the physical interrupt route authority root.
```

CapSched must separate:

```text
eventfd endpoint delivery:
  user-visible notification path

Linux IRQ handler:
  host substrate for delivery and masking

platform interrupt route:
  monitor-owned route authority, usually represented by interrupt remapping
  or an equivalent lower-layer route table
```

Forbidden shortcut:

```text
Do not treat VFIO eventfd detach or free_irq() alone as monitor-grade route
invalidation.
```

### iommufd

Useful anchors:

```text
drivers/iommu/iommufd/device.c:
  allow_unsafe_interrupts
  iommu_group_has_isolated_msi()
  MSI interrupts are not secure warning
  iommu_device_claim_dma_owner()
  iommufd_group_setup_msi()

drivers/iommu/iommufd/driver.c:
  iommufd_sw_msi_get_map()
  iommufd_sw_msi_install()
  iommufd_sw_msi()
```

Important source comment:

```text
Secure/Isolated means that a MemWr operation from the device cannot trigger
an interrupt outside this iommufd context.
```

Interpretation:

```text
iommufd already exposes a crucial security predicate: isolated MSI.
It also has a historical override, allow_unsafe_interrupts, which is explicitly
a security weakness.
```

CapSched-H must treat:

```text
iommu_group_has_isolated_msi() == useful compatibility predicate
allow_unsafe_interrupts == hard reject for production protection claim
iommufd_sw_msi mappings == substrate for MSI doorbell translation, not route
authority by themselves
```

### PCI MSI/MSI-X and generic MSI domain

Useful anchors:

```text
drivers/pci/msi/api.c:
  pci_msix_alloc_irq_at()
  pci_msix_free_irq()
  pci_alloc_irq_vectors()
  pci_free_irq_vectors()

kernel/irq/msi.c:
  msi_domain_free_irqs_range_locked()
  __msi_domain_free_irqs()
  irq_domain_deactivate_irq()
  irq_domain_free_irqs()
```

Interpretation:

```text
MSI/MSI-X allocation creates Linux-visible interrupt vectors and descriptors.
Free/deactivate paths are useful teardown substrate.
They are not sufficient unless the lower interrupt-remapping route is also
invalidated and flushed.
```

### x86 interrupt remapping

Useful anchors:

```text
drivers/iommu/irq_remapping.c:
  irq_remapping_enabled
  irq_remapping_cap()

drivers/iommu/intel/irq_remapping.c:
  alloc_irte()
  set_msi_sid()
  prepare_irte()
  prepare_irte_posted()
  modify_irte()
  qi_flush_iec()
  clear_entries()
  intel_irq_remapping_prepare_irte()
  intel_irq_remapping_free()
  intel_irq_remapping_deactivate()
```

Interpretation:

```text
IRTE allocation and source-id verification are close to the hardware route
identity CapSched needs.
modify_irte() and clear_entries() followed by qi_flush_iec() are close to the
route invalidation and stale-entry flush CapSched needs.
Posted MSI adds another state that must be invalidated or forced back to host
before reassignment.
```

Forbidden shortcut:

```text
Do not treat irq_remapping_enabled alone as QueueLease route authority.
The monitor must own or verify the specific route tag, IRTE identity, source id,
epoch, and invalidation/flush completion.
```

## CapSched Protocol Objects

The source map suggests these typed objects:

```text
IrqRouteTag:
  monitor-owned identity for a device interrupt route.

IrqRouteEpoch:
  generation of the route; old MSI messages, eventfds, IRTEs, and completion
  paths must not cross it.

IrqDeliveryEndpoint:
  VFIO eventfd, KVM irqfd, host handler, or service-domain delivery target.

IrqRemapEntry:
  substrate-specific route entry such as Intel IRTE or AMD equivalent.

IrqInvalidationReceipt:
  proof that route removal and stale interrupt-entry-cache flush completed.

PostedInterruptState:
  optional posted interrupt target and descriptor state.
```

## Required Invariants

```text
No isolated MSI, no production QueueLease route.
No IrqRouteTag, no queue delivery.
No fresh IrqRouteEpoch, no eventfd or host delivery.
No route invalidation receipt, no queue reassignment.
No IRTE clear without interrupt-entry-cache flush.
No VFIO eventfd delivery after route revoke unless explicitly quarantined.
No posted interrupt descriptor survives old queue epoch.
No allow_unsafe_interrupts in production protection claim.
```

## Design Consequence

N-081 confirms the next model boundary:

```text
VFIO eventfd detach
+ Linux free_irq()
+ MSI/MSI-X vector free
+ iommufd isolated-MSI predicate
+ IRTE clear and IEC flush
```

must be treated as separate events. A production CapSched-H route revoke can
use all of them, but none is individually sufficient.

The first safe model should reject:

```text
unsafe interrupts override
delivery through stale eventfd
reassignment after IRQ masking but before route invalidation
IRTE clear without IEC flush
posted-interrupt state surviving revoke
```
