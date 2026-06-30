# Implementation 0007: Modern NIC HyperTag Readiness Gate

Status: Proposed gate, no Linux patch approved yet

Date: 2026-06-30

Linux source:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
current commit: 7cf0b1e415bcead8a2079c8be94a9d41aad7d462
subject: sched/capsched: Add type-only authority scaffolding
```

Related artifacts:

```text
analysis/0061-modern-nic-hypertag-interface-map.md
analysis/0062-modern-nic-hypertag-readiness-probe-map.md
analysis/modern-nic-hypertag-readiness-probe-map-v1.json
formal/0041-modern-nic-readiness-gate-model/
validation/0061-modern-nic-readiness-gate-tlc.md
```

## Purpose

This gate prepares a future monitor-backed modern NIC implementation without
approving one.

The immediate temptation is to add convenient Linux-side checks into the `ice`
driver or generic networking paths and call those checks "QueueLease",
"MemoryView", "IRQ route", or "Domain" enforcement. That would be structurally
wrong. Until a HyperTag Monitor or equivalent non-forgeable root exists, Linux
can only provide observation, scaffolding, and compatibility pressure.

The accepted N-089 claim is therefore:

```text
We know which receipt/carrier rows a future implementation must cover, and we
can map them to observation-only probes or inert stubs without changing Linux
behavior.
```

The forbidden N-089 claim is:

```text
The system now provides monitor-backed device isolation.
```

## Gate Scope

This gate covers the modern NIC path:

```text
LocalDomainDeviceLease
DeviceRootReceipt
VfEpochReceipt
QueueLeaseReceipt
DmaMemoryViewReceipt
IrqRouteReceipt
LedgerRootReceipt
typed endpoint carriers
revoke and handoff receipts
```

It does not cover:

```text
real HyperTag Monitor code
real stage-2/EPT or IOMMU authority implementation
real IRQ remapping authority implementation
real device driver service Domain isolation
real packet throughput evaluation
real exploit-containment validation
```

## Allowed Next Linux Work

A future Linux patch may be proposed only as one of these:

```text
1. no-code trace runner using existing ftrace/kprobe/tracepoints
2. CONFIG_CAPSCHED-gated observation counters with no behavior effect
3. inert type-only scaffolding with no hot-path attachment
4. compile-only stub call shapes returning "not implemented" or equivalent
   without changing the caller's behavior
```

Even those are not approved by this document alone. They must name the exact
receipt/carrier row they observe and pass this gate's checks.

## Forbidden Patch Effects

No future N-089-derived patch may:

```text
change scheduler behavior
change netdev queue selection
reject or accept a packet differently
change queue enable/disable ordering
change DMA map/unmap behavior
change IOMMU attach/detach behavior
change IRQ allocation/free/delivery behavior
change VF mailbox return codes
change devlink, switchdev, representor, VFIO, or iommufd semantics
create user ABI
create a new public tracepoint ABI without a separate gate
claim monitor-backed security
```

## Required Machine-Readable Row Fields

Any future readiness ledger must use rows shaped like:

```text
receipt_or_carrier:
linux_source_anchor:
observation_surface:
stub_shape:
observation_only: true
authority_claim: false
monitor_verified: false
behavior_change: false
protection_claim: false
forbidden_shortcut:
validation_command:
```

Rows missing these fields cannot be used to justify a Linux patch.

## Stub Design Rules

Allowed stubs:

```text
opaque ids
enums for typed operation classes
struct declarations without hot object embedding
disabled-by-default counters
static inline helpers that preserve existing behavior
documentation comments that say the type is not authority
```

Forbidden stubs:

```text
helpers named authorize/enforce/grant/mint/activate
helpers that return success/failure into existing driver decisions
fields added to hot structs as if authority already exists
receipt structs whose values are derived from Linux mutable state
stubs that expose raw PF/VF/IOMMU/MSI/devlink/lower_dev handles to Domains
```

## Acceptance Checks

Before any behavior-changing implementation plan can be discussed, this gate
must have:

```text
analysis map:
  every receipt/carrier row exists
  every row has observation surface and forbidden shortcut

machine-readable map:
  every row has observation_only=true
  every row has authority_claim=false
  every row has monitor_verified=false
  every row has behavior_change=false
  every row has protection_claim=false

formal model:
  safe configuration passes
  unsafe behavior-before-gate fails
  unsafe probe-as-authority fails
  unsafe stub-enforces fails
  unsafe missing-coverage fails
  unsafe raw-endpoint stub fails
  unsafe protection-claim fails

assurance case:
  records the gate as readiness evidence only
  preserves all protection gaps
```

## Exit Meaning

Passing this gate means:

```text
It is now reasonable to design an observation-only Linux probe/stub patch or a
no-code trace runner for the modern NIC HyperTag path.
```

Passing this gate does not mean:

```text
It is safe to enforce QueueLease in Linux.
It is safe to expose target Domains to queues.
It is safe to claim hypervisor-level isolation.
```

The next approved action after this gate should still be observation or inert
scaffolding, not enforcement.
