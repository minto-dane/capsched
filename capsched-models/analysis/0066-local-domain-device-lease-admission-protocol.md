# Analysis 0066: Local Domain Device Lease Admission Protocol

Status: Draft protocol map with model gate

Date: 2026-06-30

Related artifacts:

```text
analysis/0065-local-domain-device-lease-observation-contract.md
analysis/local-domain-device-lease-observation-contract-v1.json
analysis/local-domain-device-lease-admission-protocol-v1.json
formal/0043-local-domain-device-lease-admission-model/
validation/0065-local-domain-device-lease-admission-tlc.md
```

## Purpose

N-093 maps a root-management/local monitor admission protocol onto the
`LocalDomainDeviceLease` observation contract.

The protocol is still pre-implementation. It does not define a monitor ABI,
wire format, cryptographic suite, kernel API, or driver patch. It defines the
semantic sequence that a future design must preserve.

The core rule is:

```text
LocalDomainDeviceLease exists only after root-management intent, local monitor
checks, service admission, device-root binding, target Domain epoch/budget, and
local monitor compile all agree.
```

## Actors

```text
RootManagement:
  issues ClusterLease and admits the service/driver Domain

Local HyperTag Monitor:
  validates cluster lease signature/epoch/revocation, owns device roots,
  checks target Domain epoch/budget, compiles LocalDomainDeviceLease, mints
  receipts, and completes revoke

Linux service/driver Domain:
  requests device receipts and programs Linux-visible hardware state only after
  monitor receipts

Target Domain:
  receives typed endpoints only after local lease compile and receipt minting
```

## Happy Path

```text
IssueClusterLease
ReceiveClusterLeaseOnNode
MonitorCheckClusterLease
RootManagementAdmitServiceDomain
MonitorBindDeviceRoot
MonitorCheckTargetEpochBudget
MonitorCompileLocalDomainDeviceLease
ServiceDomainRequestDeviceReceipts
TargetDomainReceiveTypedEndpoints
MonitorRequestRevoke
MonitorEmbargoNewReceipts
MonitorRevokeDerivedReceipts
MonitorCompleteRevoke
```

## Failure Paths

Each failure is terminal for that admission attempt:

```text
bad cluster signature:
  no local lease, no receipt, no endpoint

stale cluster epoch:
  no local lease, no receipt, no endpoint

cluster lease already revoked:
  no local lease, no receipt, no endpoint

service Domain mismatch:
  no local lease, no receipt, no endpoint

device root missing or not monitor-bound:
  no local lease, no receipt, no endpoint

target Domain mismatch:
  no local lease, no receipt, no endpoint

target epoch stale or root budget unavailable:
  no local lease, no receipt, no endpoint
```

Failure rows are not soft warnings. They are stop points.

## Revoke Ordering

Revoke has its own ordering:

```text
revoke request
  -> embargo new receipts and endpoint deliveries
  -> revoke queue/DMA/IRQ/ledger/endpoint derived receipts
  -> complete local lease revoke
```

Forbidden:

```text
new receipt after revoke request
typed endpoint delivery after revoke request
local lease reuse before revoke completes
audit-only revoke completion
```

## Non-Authority Inputs

These may be inputs, but never local authority roots:

```text
ClusterLease text
scheduler placement
service Domain admission
Linux PCI probe
Linux devlink registration
Linux IOMMU attach trace
Linux cgroup/root budget shadow
receipt request log
typed endpoint delivery log
audit-only monitor log
```

## Protocol Invariants

```text
No local lease after rejection
No local lease without checked cluster lease
No local lease without matching service Domain
No local lease without monitor-owned device root
No local lease without matching target Domain
No local lease without target epoch and root budget
No receipt before local lease
No endpoint before local lease
No new receipt during revoke
No local lease reuse before revoke completion
No audit-only admission or revoke
```

## Design Consequence

The next implementation-facing work must choose a concrete place to represent
this protocol:

```text
root-management control-plane record
local monitor admission API
service Domain request/receipt path
typed endpoint delivery ledger
revoke receipt ledger
```

Until that exists, the project may keep producing observation and model
evidence, but must not claim monitor-backed protection.
