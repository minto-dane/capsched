# ADR-0008: Implement From the Long-Horizon Target Backward

Status: Accepted

Date: 2026-06-30

## Context

CapSched-Linux is not only a Linux scheduler experiment. The long-horizon target
is a monitor-backed datacenter OS substrate where process-, service-,
container-, tenant-, and cluster-cell-scale Domains can receive isolation
strength comparable to VM boundaries, with better cost efficiency and finer
authority structure.

The project still needs small, reviewable Linux changes. Upstream Linux churn
also requires a thin patch surface and drift-aware source anchors. However,
"small initial patch" must not become "small security model".

The danger is implementing a Linux-only prototype that later cannot grow into:

```text
single-image, multi-context, monitor-backed Linux
```

If L0 is designed only as a local scheduler experiment, it may bake in wrong
authority roots, ambient Linux trust, untracked async authority, or hook choices
that block HyperTag Monitor integration.

## Decision

Implement from the long-horizon target backward.

Every implementation slice, including L0, must be designed as a constrained
projection of the final CapSched-H architecture:

```text
L5 target:
  hypervisor-replacement evaluation
  monitor-backed memory, CPU, IOMMU, queue, and Domain authority

L4:
  IOMMU and queue leases

L3:
  HyperTag Monitor, sealed tokens, epochs, MemoryViews, root budgets

L2:
  per-Domain mutable kernel state and service Domains

L1:
  identity and async provenance

L0:
  Linux-only scheduler capability substrate
```

The implementation order can still be incremental. The design direction cannot
be short-horizon.

## Rules

L0 must not claim L5 protection.

L0 must still preserve L5 semantics where possible:

- use explicit capability vocabulary instead of ambient Linux authority
- keep RunCap, SchedContext, grant/frozen-use, control caps, and endpoint caps
  separable
- record where a Linux-only check is a future monitor receipt, not authority
- design hooks so they can become monitor-call boundaries or receipt carriers
- preserve Domain epoch, generation, and freshness concepts even when inert
- keep async provenance and service-domain obligations visible as gaps
- avoid public user ABI or public tracepoint ABI before the monitor-backed
  semantics are stable
- keep Linux patch surface thin without weakening the target threat model

Patch-surface minimization is a maintainability tactic, not a security
reduction. If a small hook cannot preserve the final invariant shape, the hook
is wrong or the slice is premature.

## Thin Waist Rule

The project should aim for a thin waist:

```text
Linux core:
  small, explicit, no-op-capable hooks and typed carriers

CapSched authority layer:
  capability validation, freezing, budgets, epochs, provenance, and endpoints

HyperTag Monitor:
  non-forgeable DomainTag, MemoryView, root budget, IOMMU, queue, and receipt
  authority
```

The thin waist exists to keep upstream tracking possible. It must not hide
authority in Linux-global mutable state or treat Linux source observations as
security roots.

## Consequences

Future implementation plans must state:

```text
long-horizon invariant preserved
future monitor responsibility
Linux-only placeholder status
forbidden protection claim
upstream drift exposure
```

Before behavior-changing Linux patches are accepted, the plan must explain how
the patch remains compatible with:

- HyperTag Monitor receipts
- Domain epochs and revocation
- async provenance
- per-Domain mutable state pressure
- IOMMU/queue leases when relevant
- cluster-cell and multi-cluster single-OS operation when relevant

This ADR does not approve any behavior-changing Linux patch. It fixes the
implementation posture: build in small slices, but aim at the full target from
the first slice.
