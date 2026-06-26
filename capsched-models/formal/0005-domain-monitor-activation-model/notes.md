# Notes: Domain Monitor Activation Model

Date: 2026-06-26

## Claim Being Modeled

This model focuses on the activation root that separates a Linux-only prototype
from the eventual monitor-backed design:

```text
Linux may request or cache a DomainTag.
Only the monitor may make a DomainTag active for execution.
```

In a hypervisor-replacement threat model, this distinction is not cosmetic. If
Linux can directly write the state that hardware uses for Domain identity,
MemoryView, epoch, or root CPU budget, then a Domain-internal kernel compromise
can forge its way across the boundary.

## Modeled Boundary

The model deliberately splits CPU-local state into two groups:

```text
linuxTag:
  Mutable Linux shadow state. The model includes LinuxForgeTag, which can write
  arbitrary Domain, epoch, and MemoryView values here.

activeDomain / activeEpoch / activeMemView / runToken:
  Monitor-owned authority state. Execution uses this state, not linuxTag.
```

The safety properties do not require `linuxTag` to be honest. They require that
`linuxTag` alone cannot create an active task, active Domain, or active
MemoryView.

## Activation Rule

Monitor activation requires:

```text
selected Linux task
AND live grant for that task
AND grant epoch equals monitor epoch
AND grant MemoryView equals Domain MemoryView
AND selected CPU is in grant.allowedCpus
AND monitor root budget remains
AND co-tenancy policy allows this Domain on the CPU set
```

The model uses a deliberately strict co-tenancy rule:

```text
At most one non-empty Domain may be active across all CPUs.
```

That is stronger than a final datacenter system should require, but useful for
the first model because any cross-Domain co-run becomes an explicit future
weakening rather than an accidental default.

## Revocation Rule

Domain revocation increments the monitor epoch and clears:

```text
grants for that Domain
selected tasks for that Domain
active tasks for that Domain
active DomainTag / MemoryView state for that Domain
run tokens for that Domain
```

This is the monitor-side counterpart of the stricter revocation choice in the
Runnable Lease model. A future lazy revocation model may be possible, but it
must still preserve:

```text
No stale epoch may remain active for execution.
```

## Root Budget Rule

The model treats `rootBudget` as monitor-owned. `CpuTick` decrements it while a
task is active. If the decrement reaches zero, the monitor clears the active
token and moves the task to `throttled`.

This is not intended to mirror Linux CFS/RT/DL accounting. It represents the
lower absolute ceiling:

```text
Linux scheduler policy may decide fairness.
Monitor root budget decides the maximum Domain CPU authority.
```

## Linux Implications

The model suggests these implementation constraints without deciding patch
points yet:

1. Linux L0 may instrument Domain switches, but that instrumentation must be
   labeled as a shadow/request state, not a production security root.
2. Monitor-backed CapSched needs a sealed activation object analogous to
   `runToken`.
3. A cross-Domain context switch must fail closed if token validation fails.
4. Root budget exhaustion must be enforceable below Linux scheduler state.
5. Co-tenancy and core-scheduling policy should be part of the monitor
   activation check for production claims.

## What This Does Not Prove

This model does not prove:

- EPT or stage-2 page table correctness,
- TLB shootdown correctness,
- interrupt delivery or return-to-user sequencing,
- real KVM/pKVM/VMX/EL2 implementation safety,
- IOMMU or DMA isolation,
- Linux context switch locking correctness,
- side-channel resistance,
- liveness or fairness.

It only checks the modeled safety property that mutable Linux tag state is not
execution authority without monitor token activation.
