# Implementation 0008: Direct-Call Attachment Readiness Gate

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
analysis/0076-direct-call-attachment-readiness.md
analysis/direct-call-attachment-readiness-v1.json
formal/0053-direct-call-attachment-readiness-model/
validation/0075-direct-call-attachment-readiness-tlc.md
```

## Purpose

This gate prepares a future direct-call local monitor carrier without approving
one.

Allowed meaning:

```text
The required Linux/monitor attachment rows are named, and every row remains
observation-only or inert until a separate monitor-backed implementation is
approved.
```

Forbidden meaning:

```text
The direct-call carrier exists, authorizes anything, or is monitor-verified.
```

## Current Linux State

The current Linux branch has only:

```text
include/linux/capsched.h:
  opaque type names and comments

kernel/sched/capsched.c:
  inert translation unit

kernel/sched/Makefile:
  CONFIG_CAPSCHED-gated capsched.o build hook
```

No behavior-changing direct-call, monitor, scheduler, endpoint, device, or user
ABI is approved.

## Allowed Next Linux Work

Only with a separate review, future work may propose:

```text
1. no-code trace runner using existing tracing
2. source-anchor inventory for candidate attachment points
3. machine-readable readiness ledger
4. inert type-only declarations
5. compile-only internal helper shapes returning not-implemented without
   changing caller behavior
6. test-only failure-injection plan with no production behavior effect
```

## Forbidden Patch Effects

No N-103-derived patch may:

```text
change scheduler behavior
change device, DMA, IRQ, endpoint, cgroup, namespace, or LSM decisions
create user ABI
create public tracepoint ABI without a separate gate
embed authority fields in hot objects
validate requests from Linux mutable memory
mint response handles in Linux
write monitor ledger state in Linux
refresh shadow state from timeout or return code
claim monitor verification
claim production protection
expose raw monitor, PF/VF, IOMMU, MSI, devlink, task, fd, or scheduler handles
```

## Required Row Contract

Every readiness row must contain:

```text
row_id
row_class
linux_anchor
monitor_responsibility
observation_surface
stub_shape
failure_injection_surface
schema_reference
ledger_reference
shadow_reference
ring_compatibility_requirement
observation_only
authority_claim
monitor_verified
behavior_change
user_abi
public_tracepoint_abi
protection_claim
forbidden_shortcut
validation_hook
```

Required values:

```text
observation_only=true
authority_claim=false
monitor_verified=false
behavior_change=false
user_abi=false
public_tracepoint_abi=false
protection_claim=false
```

Rows missing these fields or values cannot justify a Linux patch.

## Exit Meaning

Passing this gate means:

```text
It is reasonable to design a no-code trace runner, source-anchor inventory, or
inert compile-only stub proposal for direct-call carrier readiness.
```

Passing this gate does not mean:

```text
Direct-call admission exists.
Linux can mint receipts.
A HyperTag Monitor verifies anything.
CapSched-H provides production protection.
```
