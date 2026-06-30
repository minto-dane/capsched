# Analysis 0063: Modern NIC HyperTag Observation Ledger

Status: Draft observation-only ledger and no-code runner design

Date: 2026-06-30

Related artifacts:

```text
analysis/0062-modern-nic-hypertag-readiness-probe-map.md
analysis/modern-nic-hypertag-readiness-probe-map-v1.json
implementation/0007-modern-nic-hypertag-readiness-gate.md
validation/run-modern-nic-hypertag-observation-ledger.sh
validation/0062-modern-nic-hypertag-observation-ledger-result.md
```

## Purpose

N-090 turns the readiness gate into a concrete observation ledger and a no-code
runner. This still does not approve a Linux behavior-changing patch.

The runner answers only:

```text
Which source anchors and existing trace surfaces are visible for each required
receipt/carrier row?
```

It must not answer:

```text
Does authority exist?
Does the monitor exist?
Is device isolation enforced?
Can a target Domain safely own this queue?
```

## Ledger Rule

Every ledger row must carry these fields:

```text
receipt_or_carrier
row_kind
semantic_role
source_file
line
available
symbol_or_pattern
confidence
observation_surface
stub_shape
forbidden_shortcut
observation_only
authority_claim
monitor_verified
behavior_change
protection_claim
code
```

The safety flags are not optional:

```text
observation_only=true
authority_claim=false
monitor_verified=false
behavior_change=false
protection_claim=false
```

Any row that does not preserve these values is not a readiness row.

## No-Code Runner Shape

The runner:

```text
validation/run-modern-nic-hypertag-observation-ledger.sh
```

uses only:

```text
git grep against the local Linux tree
existing source files
existing tracepoint definitions
static text output
```

It does not:

```text
modify the Linux tree
load modules
write tracefs
require root
run QEMU
enable a tracepoint
attach BPF
change driver behavior
```

The output directory contains:

```text
observation-ledger.tsv:
  one row per required anchor or explicit gap

tracefs-plan.txt:
  optional tracefs event/kprobe suggestions for a later privileged run

semantic-gaps.tsv:
  high-level gaps that prevent authority or protection claims

summary.txt:
  row counts and hard safety flags
```

## Minimal Receipt/Carrier Coverage

The first runner intentionally uses a small, representative anchor set. It is
not an exhaustive driver analysis.

### LocalDomainDeviceLease

Expected result:

```text
not_in_linux
```

Reason:

```text
cluster/root-management admission and monitor lease compilation are not present
in upstream Linux. A Linux source anchor here would be suspicious unless it is
an explicitly inert CapSched scaffold in a later gate.
```

### DeviceRootReceipt

Representative anchors:

```text
ice PCI driver binding
ice pci_register_driver
ice devlink registration
IOMMU attach_device_to_domain tracepoint
```

Forbidden upgrade:

```text
PCI/device/devlink/IOMMU visibility is not DeviceRootReceipt.
```

### VfEpochReceipt

Representative anchors:

```text
ice_get_vf_by_id
ice_reset_vf
ICE_VF_STATE_ACTIVE / ICE_VF_STATE_DIS
```

Forbidden upgrade:

```text
visible vf_id, ice_vf pointer lifetime, state bits, or reset completion are not
fresh monitor epoch authority.
```

### QueueLeaseReceipt

Representative anchors:

```text
ice_vsi
ice_q_vector
netif_napi_add_config
ice_vc_cfg_qs_msg
ice_qp_dis
```

Forbidden upgrade:

```text
ring/q_vector/NAPI/VF queue config/queue disable visibility is not QueueLease.
```

### DmaMemoryViewReceipt

Representative anchors:

```text
VF-provided dma_ring_addr copy
ice Tx/Rx hardware context programming
DMA tracepoints
IOMMU map/unmap tracepoints
XSK/page-pool return paths
```

Forbidden upgrade:

```text
Linux DMA map/unmap, IOMMU unmap, XSK return, or page-pool recycle is not a
monitor DMA/MemoryView receipt.
```

### IrqRouteReceipt

Representative anchors:

```text
ice_vc_cfg_irq_map_msg
request_irq/free_irq trace surfaces
MSI/IOMMU route trace surfaces
IRTE/interrupt-remapping source anchors when visible
```

Forbidden upgrade:

```text
vector mapping, eventfd, free_irq, MSI-X teardown, or IRTE clear is not a route
receipt unless a future monitor explicitly mints one.
```

### LedgerRootReceipt

Representative anchors:

```text
next_to_watch publication
tail doorbell write
ice clean_tx/clean_rx tracepoint definitions
XSK completion and page-pool return paths
```

Forbidden upgrade:

```text
ring index, tracepoint visibility, NAPI context, or worker context is not a
typed submit/descriptor/completion ledger root.
```

### Typed Endpoint Carriers

Representative anchors:

```text
virtchnl message dispatch
VF queue config
VF queue IRQ map
VF queue budget/quanta
FDIR add/filter completion
representor xmit
TC flower offload
PTP/DPLL/service work
```

Forbidden upgrade:

```text
virtchnl validation, opcode allowlist, callback reachability, or service worker
identity is not endpoint authority.
```

### Revoke And Handoff Receipts

Representative anchors:

```text
ice_qp_dis
ice_reset_vf
queue disable/drain paths
FDIR context completion paths
XSK/page-pool settlement paths
mailbox reopen/dispatch paths
```

Forbidden upgrade:

```text
reset completion, service completion, ring cleanup, packet free, or mailbox
state is not revoke/handoff safety.
```

## Tracefs Plan

The runner emits a non-executed tracefs plan. It is intentionally a plan, not a
privileged run. Suggested events include:

```text
net:net_dev_start_xmit
net:net_dev_xmit
napi:napi_poll
irq:irq_handler_entry
irq:irq_handler_exit
iommu:map
iommu:unmap
dma:dma_map_sg
dma:dma_unmap_sg
workqueue:workqueue_queue_work
workqueue:workqueue_execute_start
```

Driver-specific dynamic probes may be added later only as observation probes.
They must preserve the same row flags and must not become enforcement hooks.

## Exit Meaning

If the runner passes, it means:

```text
the observation ledger was emitted
the ledger safety flags are intact
the source-anchor inventory can be reviewed
the next step may design an observation-only trace run or inert stub patch
```

It still does not mean:

```text
QueueLease exists
MemoryView exists
IRQ route receipt exists
HyperTag Monitor exists
protection exists
```
