# Notes: Cluster Authority Decomposition

Date: 2026-06-26

## Why This Exists

The full `ClusterLease.tla` model was intentionally ambitious. It combined:

```text
lease issue
local compilation
execution activation
endpoint use
budget conservation
lease revoke
domain epoch revoke
forged local shadows
multi-node activity
```

That is exactly the right conceptual integration story, but it is not the right
default model-checking shape. The full run reached hundreds of millions of
distinct states and the queue was still growing.

The security lesson is not to reduce the threat model. The lesson is to keep
the threat model and split proof obligations.

## Validation Philosophy

TLC is a tool for finding semantic mistakes. It is not the project objective.

The project objective remains:

```text
hypervisor-grade Domain separation
lower datacenter cost than per-Domain VMs
Linux ABI compatibility where possible
efficient local execution
explicit capability/resource authority
```

Validation must therefore answer questions like:

```text
Can forged mutable Linux state create authority?
Can stale epochs keep running?
Can endpoint use escape local compilation?
Can budget be overspent or confused-deputy donated?
Can cluster leases become raw cross-node kernel references?
```

It should not become a ritual of making one giant model finish.

## State-Space Reduction That Does Not Weaken the Claim

The first `ClusterShadowForgery` attempt let forged shadow claims carry
arbitrary lease/domain/epoch/endpoint tuples. That produced millions of
distinct states without changing the safety argument, because no activation or
endpoint transition reads those fields.

The reduced model keeps the hostile fact that forged mutable state exists, but
abstracts its contents:

```text
localShadow[n] = TRUE
```

This is not a weaker attacker. It is a noninterference abstraction: if authority
does not inspect a variable, enumerating its values is irrelevant to the
authority safety claim.

## Decomposition Map

```text
ClusterShadowForgery:
  mutable local claims are attacker-controlled and not authority;
  claim contents are abstracted because authority transitions never read them

ClusterEpochRevoke:
  lease/domain epoch changes invalidate local activation

ClusterBudget:
  budget conservation across remaining/local/spent/forfeited

ClusterEndpoint:
  endpoint attenuation and endpoint use require compiled authority

ClusterLease full:
  broad integration stress/regression only
```

## Implementation Pressure

This points to an implementation shape:

1. Cluster control plane issues broad, non-executable leases.
2. A local compiler turns those leases into node-local typed authority objects.
3. Scheduler and endpoints only consume local compiled objects.
4. Mutable caches, claims, or hints are never authority.
5. Monitor-backed production must seal the compiled root objects below Linux.
