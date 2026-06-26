# Notes: Cluster Lease Compilation Model

Date: 2026-06-26

## Claim Being Modeled

This model captures the DragonFlyBSD-like ambition in a CapSched-safe way:

```text
one capability/resource lease namespace across nodes
not one shared mutable distributed Linux kernel
```

The core safety claim is:

```text
No ClusterLease compilation, no node-local execution or endpoint use.
```

## Why Compilation Matters

A cluster control plane can issue a broad resource lease. That lease should not
be directly executable by a node. It must first be compiled into node-local
objects:

```text
ClusterLease
  -> LocalContext
  -> local SchedContext-like budget
  -> local EndpointCap subset
  -> local monitor-enforced DomainTag/MemoryView/QueueTag in later models
```

This prevents the project from drifting into a fake global scheduler. The
cluster may distribute authority, but actual enforcement remains local and
monitor-backed.

## Modeled Objects

```text
ClusterLease:
  Domain, epoch, allowed node set, endpoint set, total budget, remaining
  uncompiled budget, and multi-node flag.

LocalContext:
  Node-local authority reserved from one ClusterLease. It carries an attenuated
  endpoint set and a local budget.

localShadow:
  Mutable node-local claim state. The model lets a node forge this freely.

activeLease:
  Node-local execution state. It requires LocalContext.

endpointUse:
  Node-local endpoint operation state. It requires LocalContext and activeLease.
```

## Budget Semantics

Budget is reserved at local compilation:

```text
CompileLocal:
  leaseRemaining -= amount
  localCtx.budget += amount
```

Runtime consumes local budget:

```text
TickNode:
  localCtx.budget -= 1
  spent += 1
```

Revocation forfeits remaining authority:

```text
RevokeLease / RevokeDomain:
  forfeited += leaseRemaining + sum(localCtx.budget)
  clear local contexts and active use
```

The model checks:

```text
leaseRemaining + localBudget + spent + forfeited = leaseTotal
```

## Endpoint Semantics

Endpoint authority is attenuated during compilation:

```text
localCtx.endpoints <= leaseEndpoints
```

Endpoint use then requires:

```text
activeLease
AND live LocalContext
AND endpoint in localCtx.endpoints
AND endpoint in original lease endpoint scope
```

This mirrors the broader CapSched rule that remote endpoints should be typed
capabilities, not raw cross-node kernel references.

## Migration and Multi-Node Semantics

The model does not implement migration as cross-machine Linux task migration.
Instead, movement is represented as:

```text
release or revoke local context on one node
compile local context on another node
activate there
```

If a lease is not marked `multiNode`, at most one node can be active for that
lease at a time. A `multiNode` lease may be active on multiple nodes, but only
within the total compiled budget.

## Linux Implications

This suggests:

1. CapSched cluster support should be a lease compiler into node-local
   `SchedContext`, `EndpointCap`, and later monitor objects.
2. Linux cpuset, affinity, root-domain, housekeeping, and topology constraints
   remain local compatibility constraints.
3. Cluster lease state should never become a raw pointer path across nodes.
4. Node-local cached claims are not authority unless validated and compiled.
5. Budget conservation must span cluster remaining budget and node-local
   reserved budget.

## What This Does Not Prove

This model does not prove:

- cryptographic signature correctness,
- distributed consensus,
- lease renewal protocol safety,
- network partition handling,
- clock synchronization,
- real task migration,
- monitor MemoryView or IOMMU enforcement,
- Linux locking or cpuset hotplug correctness.

It only checks the small safety story for cluster lease compilation into local
execution and endpoint authority.
