# Modern NIC HyperTag Split Model

Status: Draft, intended for tiny finite TLC checking

Date: 2026-06-30

Related artifacts:

```text
analysis/0061-modern-nic-hypertag-interface-map.md
analysis/modern-nic-hypertag-interface-map-v1.json
assurance/0002-modern-nic-queuelease-assurance-map.md
```

## Purpose

This model checks the N-088 boundary between:

```text
HyperTag Monitor roots and receipts
Linux service/driver Domain policy and hardware programming substrate
typed endpoints exposed to target Domains
```

The safe design is not "put the whole NIC driver in the monitor". It is:

```text
monitor owns non-forgeable roots and receipts
service Domain parses policy and programs hardware only after receipts
target Domains receive typed endpoints and direct data-plane queues
ordinary packet submission does not trap to the monitor
```

## Checked Invariants

```text
NoEffectWithoutMonitorRoots
NoServiceMintedMonitorRoot
NoLinuxDmaAsReceipt
NoLinuxIrqAsReceipt
NoRawEndpointToTarget
NoQueueActivationWithoutDmaIrq
NoServiceReplayOldEpoch
NoRemoteLeaseDirectUse
NoAuditOnlyMonitor
NoPerPacketMonitorTrap
NoBadServiceMint
NoBadLinuxDma
NoBadLinuxIrq
NoBadRawEndpoint
NoBadActivateNoDmaIrq
NoBadServiceReplay
NoBadRemoteLeaseDirect
NoBadAuditOnly
NoBadPacketTrap
```

## Modeled Hazards

```text
service Domain mints QueueLease-like authority
Linux DMA map/unmap is treated as a monitor DMA receipt
Linux IRQ teardown or vector mapping is treated as a monitor IRQ receipt
target Domain receives raw PF/VF/IOMMU/MSI/devlink authority
queue is activated without matching DMA and IRQ receipts
reset/rebuild service replay uses old epoch state
signed cluster lease is used directly without local monitor compilation
monitor calls are audit-only after Linux has already performed the side effect
ordinary packet submission requires per-packet monitor traps
```

## Scope Limit

This is not a NIC driver, virtchnl, IOMMU, MSI-X, or service Domain
implementation. It is a design filter for the CapSched-H split. The model
intentionally keeps the data plane abstract so that monitor entry remains on
bind/config/revoke/epoch transitions, not per descriptor.
