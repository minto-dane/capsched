# Formal 0006: Cluster Lease Compilation Model

Status: Full integration TLC run pending under systemd user service

Date: 2026-06-26

Linux base:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
commit: 0b685979f27b3d42ee620ced5f707ee391a2a27f
```

## Purpose

This model captures the datacenter and multi-cluster direction without turning
CapSched into a single global runqueue:

```text
ClusterLease -> node-local SchedContext and EndpointCap authority.
```

It checks that cluster-wide authority must be compiled into local capability
objects before a node can execute or use endpoints, and that local forged shadow
claims do not create authority.

## Files

```text
ClusterLease.tla
ClusterLease.cfg
ClusterBudget.tla
ClusterBudget.cfg
ClusterEndpoint.tla
ClusterEndpoint.cfg
notes.md
```

## Core Idea

The model separates:

```text
ClusterLease:
  Cluster-control-plane authority with Domain, epoch, allowed nodes, endpoint
  scope, and total budget.

LocalContext:
  Node-local compiled authority. It reserves budget from a ClusterLease and
  carries an attenuated endpoint set.

localShadow:
  Mutable node-local claim state. The model allows arbitrary forged claims here.

activeLease / endpointUse:
  Node-local execution and endpoint-use state. These require LocalContext, not
  localShadow.
```

The model is intentionally not a distributed Linux scheduler. It is a lease
compilation model:

```text
global policy is distributed
local enforcement remains node-local and monitor-backed
raw kernel pointers never cross nodes
```

## Encoded Safety Properties

```text
NoLocalContextWithoutValidLease
NoActiveWithoutCompiledContext
NoActiveWithStaleClusterEpoch
NoActiveOutsideLeaseNodeSet
NoActiveWithoutLocalBudget
NoEndpointUseWithoutCompiledEndpointCap
NoEndpointUseOutsideLease
NoShadowClaimConfersAuthority
NoSingleNodeLeaseActiveOnTwoNodes
NoLeaseBudgetOversubscription
NoBudgetUnderflow
```

## Expected Validation

Run the full integration model from this directory:

```text
java -cp /home/nia/tools/tla/tla2tools.jar tlc2.TLC ClusterLease.tla
```

For long runs, use:

```text
capsched/capsched-models/validation/run-cluster-lease-full-tlc.sh
```

Current systemd validation record:

```text
capsched/capsched-models/validation/0008-cluster-lease-full-systemd-tlc-run.md
```

The configuration intentionally uses a tiny finite model:

```text
2 Domains
2 Nodes
2 ClusterLeases
2 Endpoints
lease budget: 0..2
epochs: 0..1
```

## Design Questions This Model Pressures

1. A signed or root-issued ClusterLease should not be directly executable.
   It must compile into node-local authority.
2. Local nodes may cache or request claims, but those claims are not authority.
3. Endpoint authority is attenuated during local compilation.
4. Lease budget must be conserved across cluster remaining budget, local
   reserved budget, spent budget, and forfeited budget.
5. Migration and multi-node activity require explicit lease semantics. They are
   not ordinary cross-machine task migration.
