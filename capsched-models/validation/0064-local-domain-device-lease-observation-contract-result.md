# Validation 0064: Local Domain Device Lease Observation Contract Result

Status: Executed; observation contract validated

Date: 2026-06-30

Runner:

```text
capsched/capsched-models/validation/run-local-domain-device-lease-observation-contract.sh
```

Related artifacts:

```text
analysis/0065-local-domain-device-lease-observation-contract.md
analysis/local-domain-device-lease-observation-contract-v1.json
analysis/0064-local-domain-device-lease-compilation.md
validation/0063-local-domain-device-lease-tlc.md
```

Run directory:

```text
/media/nia/scsiusb/dev/linux-cap/build/local-domain-device-lease-observation-contract/20260630T051105Z
```

Output files:

```text
contract-rows.tsv
semantic-gaps.tsv
summary.txt
```

## Result Summary

```text
row_count=10
dependency_rule_count=7
dependency_errors=0
safety_flag_violations=0
forbidden_authority_collapse_count=9
observation_only=true
authority_claim=false
monitor_verified=false
behavior_change=false
protection_claim=false
```

The contract rows are:

```text
LDDL-010-ISSUE-CLUSTER-LEASE
LDDL-020-RECEIVE-ON-NODE
LDDL-030-CHECK-CLUSTER-LEASE
LDDL-040-ADMIT-SERVICE-DOMAIN
LDDL-050-BIND-DEVICE-ROOT
LDDL-060-CHECK-TARGET-EPOCH-BUDGET
LDDL-070-COMPILE-LOCAL-LEASE
LDDL-080-SERVICE-REQUEST-RECEIPTS
LDDL-090-TARGET-RECEIVE-ENDPOINTS
LDDL-100-REVOKE-LOCAL-LEASE
```

## Validated Local Claim

This run supports only this claim:

```text
The LocalDomainDeviceLease observation contract is internally well-formed for
pre-monitor planning: every row preserves the observation-only safety flags,
required fields are present, dependency rules resolve, and receipt/endpoint rows
depend on the local lease compile row.
```

It does not support:

```text
root-management exists
HyperTag Monitor exists
LocalDomainDeviceLease has been minted
DeviceRootReceipt has been minted
QueueLeaseReceipt has been minted
DmaMemoryViewReceipt has been minted
IrqRouteReceipt has been minted
typed endpoint authority exists
revocation has completed
protection exists
```

## Forbidden Collapses Preserved

The runner emitted semantic gap rows for:

```text
ClusterLease text is not LocalDomainDeviceLease
Node receipt is not LocalDomainDeviceLease
Cluster signature or epoch check is not local queue authority
ServiceAdmission cannot mint LocalDomainDeviceLease
Linux PCI/devlink/IOMMU registration is not DeviceRootBinding authority
Scheduler placement or Linux cgroup state is not target budget authority
Audit-only monitor log is not compile authority
Receipt request is not receipt minting
Typed endpoint delivery log is not monitor verification
Revocation request is not completed revoke of all derived receipts
```

## Design Consequence

N-092 is satisfied as a non-behavior-changing observation contract. The next
safe step can map a future root-management/local monitor admission protocol to
this contract, or use it as the required external row shape before any inert
Linux probe/stub proposal.

No behavior-changing Linux, driver, scheduler, queue, IOMMU, IRQ, or monitor
work is approved by this validation.
