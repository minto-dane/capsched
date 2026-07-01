# Placement, Affinity, and Hotplug Integration Gate Model

Status: Checked with safe pass and expected unsafe counterexamples

Date: 2026-07-01

## Purpose

This model checks that ordinary Domain execution cannot treat Linux placement
machinery as capability authority.

It models:

```text
Domain/SchedContext/RunCap grant provenance
capability CPU envelope
current Linux effective CPU mask
active CPU mask
monitor CPU binding
MemoryView CPU binding
frozenAllowed set
selected CPU
run CPU
placement epoch
migration pending state
ordinary Domain task versus Linux exception concepts
```

## Safe Path

The safe path is:

```text
IssueRunAuthority
  -> FreezePlacementFromAuthority
  -> SelectByLinuxWithinFrozen
  -> RunSelected
```

It also allows affinity, cpuset, hotplug, monitor CPU binding, or MemoryView CPU
binding invalidation from `Frozen`, `Selected`, or `Running`. After
invalidation, the task either refreezes from actual authority and a non-empty
intersection, or fails closed when the intersection is empty.

## Key Rule

```text
frozenAllowed =
  capEnvelope ∩ linuxMask ∩ activeMask ∩ monitorCpuSet ∩ memoryViewCpuSet
```

`selectedCpu` is only a selected state. It is not authority.

## Rejected Substitutions

Unsafe configs reject:

```text
run without frozen placement
run with stale placement epoch
run outside current Linux mask
run on inactive CPU
run without monitor CPU binding
run without MemoryView CPU binding
run while migration is pending
selected CPU as authority
placement minting authority
fallback expansion as authority
force affinity as authority
cpuset fallback as authority
class selection as authority
sched_ext selection as authority
core scheduling pick/steal as authority
sched_exec placement as authority
migrate_disable as ordinary Domain authority
per-cpu kthread exception as ordinary Domain authority
run with empty actual intersection
protection overclaim
```

## Subagent Review

An earlier boolean version of this model was rejected before completion. It did
not adequately represent CPU-set intersections, authority provenance, running
state invalidation, or Linux exception task kinds. This checked model is the
strengthened replacement.

## Run

```sh
java -cp /home/nia/tools/tla/tla2tools.jar \
  tlc2.TLC \
  -config PlacementAffinityHotplugIntegrationGateSafe.cfg \
  PlacementAffinityHotplugIntegrationGate.tla
```

Use a distinct `-metadir` for bulk unsafe runs to avoid TLC state-directory
collisions.

## Non-Claims

This model does not approve Linux hooks, task fields, a public ABI, a monitor
ABI, runtime coverage, behavior change, monitor implementation, monitor
verification, or production protection.
