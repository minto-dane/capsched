# Validation 0051: ice Revoke Readiness Result

Status: Executed observation-only static readiness check

Date: 2026-06-29

Runner:

```text
capsched/capsched-models/validation/run-ice-revoke-readiness.sh
```

Related artifacts:

```text
capsched/capsched-models/analysis/0053-ice-modern-nic-revoke-source-map.md
capsched/capsched-models/analysis/ice-modern-nic-revoke-source-map-v1.json
capsched/capsched-models/formal/0031-modern-nic-queue-revoke-model/ModernNicQueueRevoke.tla
capsched/capsched-models/validation/0050-modern-nic-queue-revoke-tlc.md
```

## Purpose

This validation checks whether the `ice` revoke source map can be converted
into an observation-only readiness ledger for the `formal/0031` revoke,
drain, quarantine, IRQ, IOMMU, control, representor, service, and reassignment
obligations.

It is not an enforcement test and not a protection proof.

## Executed Result

Final run:

```text
run directory:
  /media/nia/scsiusb/dev/linux-cap/build/ice-revoke-readiness/20260630T002344Z

tracepoints:
  /media/nia/scsiusb/dev/linux-cap/build/ice-revoke-readiness/20260630T002344Z/tracepoint-inventory.tsv

source anchors:
  /media/nia/scsiusb/dev/linux-cap/build/ice-revoke-readiness/20260630T002344Z/source-anchors.tsv

readiness:
  /media/nia/scsiusb/dev/linux-cap/build/ice-revoke-readiness/20260630T002344Z/obligation-readiness.tsv

gaps:
  /media/nia/scsiusb/dev/linux-cap/build/ice-revoke-readiness/20260630T002344Z/semantic-gaps.tsv
```

Outcome:

```text
status: observation_only_ice_revoke_readiness
tracepoint_rows: 8
tracepoint_missing_rows: 0
source_anchor_rows: 31
source_anchor_missing_rows: 0
obligation_readiness_rows: 10
gap_rows: 8
```

Every readiness row carries:

```text
observation_only=true
authority_claim=false
monitor_verified=false
```

## Tracepoint Coverage

Existing generic tracepoints cover useful outer events:

```text
net_dev_xmit_timeout
napi_poll
irq_handler_entry
irq_handler_exit
iommu unmap
dma_unmap_sg
workqueue_queue_work
workqueue_execute_start
```

These tracepoints are useful for observation and regression studies, but they
do not provide:

```text
QueueTag
queue epoch
typed SubmitLedger or DescriptorLedger id
completion-settlement id
monitor-owned IOMMU or IRQ ownership
service/caller authority intersection
old/new queue epoch handoff
```

## Source Anchor Coverage

The checker found all 31 source anchors with zero missing rows.

Key anchors include:

```text
netif_tx_disable
netif_tx_stop_queue
ice_vsi_dis_irq
QINT_RQCTL_CAUSE_ENA clear
GLINT_DYN_CTL clear
synchronize_irq q_vector
ICE_VSI_VF synchronize_irq exception
ice_vsi_stop_lan_tx_rings
ice_vsi_stop_xdp_tx_rings
ice_vsi_stop_all_rx_rings
ice_clean_tx_ring
ice_clean_rx_ring
ice_qp_clean_rings
xsk_pool_dma_unmap
ice_unmap_and_free_tx_buf
napi_disable
ice_xsk_clean_rx_ring
ice_xsk_clean_xdp_ring
xsk_tx_completed
ice_reset_subtask
ice_prepare_for_reset
ice_devlink_reinit_down
ice_eswitch_port_start_xmit
ice_eswitch_stop_all_tx_queues
ice_repr_stop_tx_queues
ice_service_task_schedule
ice_service_task_stop
ice_service_task
ice_qp_ena
ice_rebuild
ice_devlink_reinit_up
```

## Obligation Readiness

```text
REV-ICE-001 NoSubmitAfterRevoke:
  partial_gap_recorded

REV-ICE-002 NoOldControlAuthorityAfterRevoke:
  not_ready_future_capsched

REV-ICE-003 NoReassignWithoutIommuAndIrqInvalidation:
  partial_gap_recorded

REV-ICE-004 NoLedgerClearBeforeDrain:
  partial_gap_recorded

REV-ICE-005 NoReassignWithoutIommuAndIrqInvalidation:
  partial_gap_recorded

REV-ICE-006 NoDeliveryAfterRevoke:
  partial_gap_recorded

REV-ICE-007 NoControlAfterRevoke:
  source_only_gap_recorded

REV-ICE-008 NoRepresentorForwardAfterRevoke:
  partial_gap_recorded

REV-ICE-009 NoServiceWorkAfterRevoke:
  source_only_gap_recorded

REV-ICE-010 NoReassignBeforeDrainOrQuarantine:
  partial_gap_recorded
```

## High-Severity Gaps

All recorded gaps are high severity:

```text
queue-epoch:
  no QueueTag or queue epoch source anchor

typed-ledger:
  ring stop and clean anchors exist but no SubmitLedger/DescriptorLedger id

iommu-root:
  DMA unmap anchors are Linux-owned

vf-irq-sync:
  ice_vsi_dis_irq skips synchronize_irq for ICE_VSI_VF from host

xsk-quarantine:
  xsk_tx_completed can occur during cleanup

representor-lower-lease:
  representor stop is not lower QueueLease revoke

service-carrier:
  ICE_SERVICE_SCHED and queue_work coalesce service work

epoch-handoff:
  ice_qp_ena/rebuild reload without CapSched old/new epoch handoff
```

## Validated Non-Claims

This validation confirms only observation readiness. It does not prove:

```text
QueueLease enforcement
monitor QueueTag or queue epoch existence
monitor-owned IOMMU or IRQ invalidation
stale completion quarantine correctness
RepresentorForward invalidation through lower QueueLease revoke
service/caller authority intersection
old/new queue epoch reassignment safety
```

## Design Consequence

The `ice` driver has useful shutdown, cleanup, reset, representor, service, and
rebuild machinery for future observation. CapSched must still provide the
authority root and typed state:

```text
QueueTag + queue epoch
SubmitLedger / DescriptorLedger / CompletionSettlement
MemoryView / IOMMU root
IRQ ownership root
XSK/page-pool quarantine semantics
RepresentorForward lower QueueLease derivation
ServiceWork carrier or audited service-only class
old/new epoch handoff protocol
```

Therefore the next focused risk is the VF IRQ ownership exception: the source
anchor exists, but the host VF path explicitly skips `synchronize_irq()`, so a
monitor-backed QueueLease revoke model must separate host-owned, VF-owned, and
monitor-owned interrupt completion authority before any driver behavior change.
