# Analysis 0107: Side-Channel and Co-Tenancy Policy Gate

Status: Draft model gate with TLC-backed design filter; no mitigation
implementation or performance evidence approved

Date: 2026-07-01

## Purpose

N-153 closes the model-only blocker for `SIDE-001`.

The model does not require all co-tenancy to be disabled. Datacenter efficiency
requires controlled sharing. The invariant is stricter and more useful:

```text
no co-tenancy decision is implicit, unknown, performance-only, or able to
weaken hard Monitor-backed isolation.
```

## Required Policy Boundary

The following dimensions require explicit policy tags and leakage
classification before sharing:

```text
SMT sibling sharing
core sharing
cache sharing
NUMA locality/sharing
device queue sharing
cluster placement
```

Hard boundaries remain separate:

```text
RunCap / SchedContext / root budget
MemoryView / page ownership
IOMMU / QueueLease ownership
typed endpoint authority
monitor activation binding
```

Side-channel policy is not an authority root. It constrains placement and
co-tenancy; it does not mint execution, memory, endpoint, queue, or budget
authority.

## Model

New model:

```text
formal/0085-side-channel-cotenancy-policy-gate-model/
```

Checked invariant group:

```text
Safety
```

with component obligations:

```text
NoModelSupportWithoutKnownPolicy
NoModelSupportWithoutLeakageClassification
NoImplicitSharing
NoPerformanceOverride
NoSidePolicyWeakensHardBoundary
NoSchedulerBypass
NoSidePolicyAsAuthorityRoot
NoProductionProtectionClaim
NoCostEfficiencyClaim
```

## Rejected Designs

The model rejects:

```text
unknown policy defaulting to allow
SMT sharing without explicit policy
core sharing without explicit policy
cache sharing without explicit policy
NUMA sharing without explicit policy
device queue sharing without explicit policy
cluster placement without explicit policy
performance optimizer overriding isolation
side policy weakening hard Monitor-backed boundary
scheduler ignoring side policy
missing monitor binding
missing leakage classification
side policy treated as authority root
production-protection overclaim
cost-efficiency overclaim
```

## Assurance Effect

This gate moves `SIDE-001` from open to model-supported. It does not claim that
side-channel mitigations are implemented, sufficient, measured, or production
safe.

## Non-Claims

This gate does not provide scheduler hooks, core-scheduling integration,
cache/NUMA isolation implementation, device queue isolation implementation,
runtime side-channel tests, performance evidence, monitor verification,
production protection, or cost-efficiency evidence.
