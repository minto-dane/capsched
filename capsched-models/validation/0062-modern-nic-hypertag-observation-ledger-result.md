# Validation 0062: Modern NIC HyperTag Observation Ledger Result

Status: Executed; observation-only ledger emitted

Date: 2026-06-30

Runner:

```text
capsched/capsched-models/validation/run-modern-nic-hypertag-observation-ledger.sh
```

Related artifacts:

```text
capsched/capsched-models/analysis/0063-modern-nic-hypertag-observation-ledger.md
capsched/capsched-models/analysis/modern-nic-hypertag-observation-ledger-v1.json
capsched/capsched-models/analysis/0062-modern-nic-hypertag-readiness-probe-map.md
capsched/capsched-models/implementation/0007-modern-nic-hypertag-readiness-gate.md
```

Run directory:

```text
/media/nia/scsiusb/dev/linux-cap/build/modern-nic-hypertag-observation-ledger/20260630T044602Z
```

Output files:

```text
observation-ledger.tsv
tracefs-plan.txt
semantic-gaps.tsv
summary.txt
```

## Result Summary

```text
ledger_rows=37
available_rows=36
missing_rows=1
gap_rows=1
safety_flag_violations=0
observation_only=true
authority_claim=false
monitor_verified=false
behavior_change=false
protection_claim=false
```

Row distribution:

```text
DeviceRootReceipt: 4
DmaMemoryViewReceipt: 6
IrqRouteReceipt: 3
LedgerRootReceipt: 4
LocalDomainDeviceLease: 1
QueueLeaseReceipt: 5
RevokeAndHandoffReceipts: 4
TypedEndpointCarriers: 6
VfEpochReceipt: 4
```

The only missing row is intentional:

```text
gap_id: HTOBS-GAP-001
receipt_or_carrier: LocalDomainDeviceLease
severity: high
evidence: required root is outside upstream Linux source
required_next_step:
  define external root-management and local monitor compilation observation
  before any distributed lease claim
```

## What Was Observed

The runner found current upstream source anchors for:

```text
ice PCI driver and devlink registration
IOMMU attach/map/unmap trace surfaces
VF lookup and reset
VF state bits
VSI, q_vector, and NAPI binding
VF queue config and queue pair disable
VF-provided DMA ring addresses
Tx/Rx hardware context setup
VF IRQ map
IRQ handler trace surfaces
next_to_watch publication and tail doorbell write
ice TX/RX completion trace definitions
virtchnl dispatch
VF queue budget handler
VF FDIR offload handler
representor xmit
TC flower offload
ice service task
FDIR ctx_done
XSK free path
```

The generated `tracefs-plan.txt` lists existing trace events and candidate
dynamic probes for a later privileged observation run. It was not executed by
this validation.

## Validated Local Claim

This run supports only this claim:

```text
The modern NIC HyperTag receipt/carrier observation ledger can be emitted from
the current Linux source tree without changing Linux behavior, and every ledger
row preserves the required readiness safety flags.
```

It does not support:

```text
QueueLease authority exists
DeviceRootReceipt exists
VfEpochReceipt exists
DmaMemoryViewReceipt exists
IrqRouteReceipt exists
LedgerRootReceipt exists
typed endpoint carriers are implemented
HyperTag Monitor exists
Linux service/driver Domain isolation exists
protection exists
```

## Evidence Limits

The runner is static and source-observation only.

It does not:

```text
execute tracefs
exercise real hardware
run QEMU
prove runtime path coverage
measure performance
test hostile kernel compromise
verify IOMMU or IRQ hardware state
validate monitor receipts
```

## Design Consequence

N-090 is satisfied as an observation-ledger design and static runner. The next
safe step is a choice between:

```text
1. a privileged no-code tracefs run using tracefs-plan.txt
2. an inert Linux patch proposal that adds no behavior change and emits the same
   readiness flags
3. a deeper model/source map for the external LocalDomainDeviceLease gap
```

None of those may claim production protection.
