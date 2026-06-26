# Formal 0007: Cluster Authority Decomposition Model

Status: Draft

Date: 2026-06-26

Linux base:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
commit: 0b685979f27b3d42ee620ced5f707ee391a2a27f
```

## Purpose

This model set replaces the unfinished full `ClusterLease.tla` TLC run as the
primary validation shape for cluster lease semantics.

The project goal is not to finish large TLC runs. The goal is a secure and
efficient datacenter OS substrate. TLC is useful only when it gives pressure and
evidence for specific semantic claims. The full integration model remains a
valuable stress test, but it is too large to be the proof root.

## Decomposition Rule

Do not weaken CapSched security claims to make TLC pass. Instead, split claims
by authority boundary:

```text
cluster lease issue/revoke
  -> local compilation
  -> local activation
  -> endpoint use
  -> budget accounting
  -> forged mutable claims
```

Each smaller model must preserve the hostile assumption relevant to that
boundary. For example, forged local shadow state remains arbitrary in the shadow
model; epoch revocation remains asynchronous and invalidates cached authority in
the epoch model.

## Files

```text
ClusterShadowForgery.tla
ClusterShadowForgery.cfg
ClusterEpochRevoke.tla
ClusterEpochRevoke.cfg
notes.md
```

## Models

### ClusterShadowForgery

Checks that arbitrary node-local mutable shadow claims do not create execution
or endpoint authority. The only path to active execution or endpoint use is a
compiled local context derived from a live cluster lease.

The shadow value is abstracted to a boolean "forged claim exists" marker. This
is intentional: no authority transition reads the shadow value, so enumerating
every fake lease/domain/endpoint tuple only creates irrelevant state-space
product.

Primary claim:

```text
No compiled LocalContext, no active execution or endpoint use,
even if local shadow state is forged.
```

### ClusterEpochRevoke

Checks that domain/lease revocation and epoch changes invalidate local
activation authority. It keeps mutable node-local claims explicit but outside
the authority path.

Primary claim:

```text
No live lease epoch, no active local execution.
```

## Role of Full Integration

The earlier full integration model remains useful as a broad regression stress
test, but it is no longer the gate for progress. It explored a very large state
space without finding an invariant violation before being stopped:

```text
17,127,406,139 states generated
550,525,279 distinct states found
512,945,750 states left on queue
depth: 7
```

That is not a pass. It is evidence that a monolithic BFS over every
interleaving is the wrong validation shape for this phase.

## Design Consequence

Cluster support should compile broad cluster leases into node-local authority
objects. It should not become one distributed Linux kernel and should not pass
raw kernel object references across nodes.
