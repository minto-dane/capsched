# Analysis 0018: Protection Claim Evidence Map

Status: Draft

Date: 2026-06-26

Linux base:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
commit: 0b685979f27b3d42ee620ced5f707ee391a2a27f
```

## Purpose

This note maps the project's top-level security and datacenter goals to the
evidence already produced and to the evidence still missing.

The immediate problem is not lack of ideas. The risk is that the project
collects good local models without a clear assurance chain from those models to
the final claim:

```text
A process-scale or container-scale Domain compromise should require something
comparable to a hypervisor escape before it can cross into another Domain.
```

## Top-Level Claim

The production CapSched-H claim should eventually be:

```text
If an attacker controls all userspace in a Domain and gains arbitrary Linux
kernel-context execution scoped to that Domain, crossing into another Domain's
memory, execution authority, device queue, DMA memory, or control authority
requires breaking the HyperTag Monitor or an explicitly exposed typed service
endpoint.
```

This claim is not true for Linux-only L0. It is not true merely because a task
has a Domain pointer. It requires non-forgeable roots below Linux and a much
smaller mutable sharing story.

## Evidence Map

| Claim | Current evidence | Strength | Missing evidence |
| --- | --- | --- | --- |
| No RunCap, no enqueue/execution | `RunnableLease` model and validation 0001 | Tiny finite model | Linux behavior patch, scheduler class coverage, wakeup variants |
| No async work without caller provenance | `EndpointAsync` model, analysis 0015 | Tiny finite model plus Linux attachment map | workqueue/task_work/io_uring implementation and tests |
| No broker work without caller ticket | `BrokerBudget` model and validation 0006 | Tiny finite model | service-domain Linux prototype and accounting policy |
| Linux shadow DomainTag is not authority | `DomainMonitor` model and validation 0007 | Tiny finite model with hostile shadow state | actual monitor prototype, arch-specific activation |
| Cluster lease compiles local before execution | decomposed Cluster authority models and validation 0009 | Decomposed proof root | broader integration remains stress-only, no cluster control plane |
| Linux page/slab/page-cache metadata is not memory authority | analysis 0017, `MemoryOwnership` decomposed models | Decomposed proof root | real PageOwner/MemoryView monitor implementation |
| No stale direct-map/TLB translation crosses Domains | `DirectMapTLB` model and validation 0011 | Counterexample-driven finite model | arch TLB, ASID/PCID/VMID/EPT/stage-2 implementation |
| Mutable page-cache state is per-Domain or service-mediated | `PageCacheOverlay` model and validation 0012 | Counterexample-driven finite model | filesystem-specific semantics and Linux page-cache design |
| Queue submit/DMA/IRQ/budget are one lease boundary | `QueueLease` model and validation 0013 | Two finite TLC runs | device-specific endpoints and real IOMMU/IRQ invalidation |
| Linux-only patches do not claim security | Slice 0A Kconfig/help text and build validation 0004 | Build evidence | every future patch needs claim-boundary review |

## What Is Still Unproven

The following are not proven by the current work:

```text
arbitrary Domain-local Linux kernel code cannot write other Domain kernel state
real stage-2/EPT MemoryView enforcement
real direct-map split or removal
real TLB shootdown and invalidation ordering
IOMMU TLB invalidation ordering
interrupt remapping correctness
device-specific queue semantics
filesystem consistency under overlays
service Domain TCB size and attack surface
side-channel containment
performance and cost-efficiency against KVM/Firecracker
```

These are not small gaps. They are the difference between a strong Linux
prototype and a hypervisor-replacement claim.

## Current Strategic Gap

The project now has good semantic atoms:

```text
Run lease
Endpoint frozen use
Broker ticket
Monitor activation
Cluster-local authority compilation
Memory ownership
Direct-map/TLB revoke
Page-cache overlay conflict
QueueLease/IOMMU/IRQ boundary
```

The next missing layer is an explicit assurance structure that says:

```text
which top-level claim each atom supports
which implementation gate will exercise that claim
which validation evidence is sufficient for that gate
which claims remain forbidden for Linux-only L0
```

Without that structure, the project can accidentally make progress on many
interesting pieces while failing to converge on the actual goal.

## Recommended Direction

The next work should split into two synchronized tracks.

### Track A: Minimal Linux Integration

Return to Linux with a deliberately inert Slice 0B:

```text
opaque authority type names
comments that deny security claims
no hot struct fields
no behavior
no user ABI
only include/linux/capsched.h and kernel/sched/capsched.c
```

Reason:

The current models are enough to justify vocabulary, not behavior. Adding the
vocabulary gives future patches stable names and prevents ad hoc type collapse.

### Track B: Assurance Case

Create and maintain a living assurance case:

```text
top-level claim
subclaims
model evidence
Linux evidence
monitor evidence
negative evidence and counterexamples
forbidden claims
open gaps
```

Reason:

The goal is not to pass TLC. The goal is to make the final security and
efficiency claim true. The assurance case keeps every model and patch tied to
that final claim.

## Next Gate Recommendation

Do not start behavior-changing scheduler hooks yet.

The best next gate is:

```text
1. Add an assurance-case plan.
2. Update Slice 0B readiness using the new memory and QueueLease evidence.
3. Apply only type-only Slice 0B in Linux.
4. Re-run CONFIG_CAPSCHED=n/y build validation.
```

After that, the first behavior-adjacent slice should probably be trace-only
instrumentation, not enforcement:

```text
Domain shadow identity creation
Domain switch tracepoint or debug counter
no scheduler decision changes
no claim of enforcement
```

This creates observability before authority.

## Stop Conditions

Stop and re-model before implementation if a patch would:

```text
attach CapSched fields to task_struct
change enqueue/pick/tick behavior
touch workqueue, io_uring, socket, VFS, MM, IOMMU, or drivers
create any user ABI
create any helper named like an enforcement or activation hook
imply Linux-only monitor authority
merge RunCap, EndpointCap, BudgetTicket, MemoryView, and QueueLease into one type
```

Those moves require their own implementation plan and validation gate.
