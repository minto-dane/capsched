# Validation 0009: Cluster Authority Decomposition TLC Check

Status: Passed for decomposed finite models

Date: 2026-06-26

## Purpose

Validate the cluster lease authority decomposition after the full integration
`ClusterLease.tla` run proved too large to serve as the proof root.

This validation does not make TLC the project objective. It uses TLC as a
semantic pressure tool for the actual objective: secure and efficient
datacenter-grade CapSched Domain separation.

## Models

```text
capsched/capsched-models/formal/0007-cluster-authority-decomposition-model/
```

Files:

```text
ClusterShadowForgery.tla
ClusterShadowForgery.cfg
ClusterEpochRevoke.tla
ClusterEpochRevoke.cfg
```

## Shadow Forgery Model

Claim:

```text
No compiled LocalContext, no active execution or endpoint use,
even if node-local mutable shadow state is forged.
```

The first attempt modeled full forged shadow tuple contents and was stopped
after it grew without adding authority-relevant coverage:

```text
187624698 states generated
8679294 distinct states found
7497338 states left on queue
no invariant error observed before interruption
```

The checked model abstracts shadow contents to a boolean forged-claim marker.
This is a noninterference reduction: authority transitions never read the
shadow value, so enumerating fake tuple contents only creates irrelevant product
states.

Command:

```sh
java -XX:+UseParallelGC \
  -cp /home/nia/tools/tla/tla2tools.jar \
  tlc2.TLC \
  -workers 8 \
  -fp 0 \
  -metadir /media/nia/scsiusb/dev/linux-cap/build/tlc/cluster-shadow-forgery-20260626T \
  ClusterShadowForgery.tla
```

Result:

```text
Model checking completed. No error has been found.
20646297 states generated
1513736 distinct states found
0 states left on queue
depth: 17
fingerprint collision estimate:
  calculated optimistic: 1.6E-6
  actual fingerprints: 8.1E-8
```

Checked invariants:

```text
TypeOK
NoLocalContextWithoutValidLease
NoActiveWithoutCompiledContext
NoEndpointUseWithoutCompiledEndpointCap
NoShadowClaimConfersAuthority
NoShadowEndpointClaimConfersAuthority
```

## Epoch Revoke Model

Claim:

```text
No live lease epoch, no active node-local execution.
```

Command:

```sh
java -XX:+UseParallelGC \
  -cp /home/nia/tools/tla/tla2tools.jar \
  tlc2.TLC \
  -workers 8 \
  -fp 1 \
  -metadir /media/nia/scsiusb/dev/linux-cap/build/tlc/cluster-epoch-revoke-20260626T \
  ClusterEpochRevoke.tla
```

Result:

```text
Model checking completed. No error has been found.
231929 states generated
23688 distinct states found
0 states left on queue
depth: 14
fingerprint collision estimate:
  calculated optimistic: 2.7E-10
  actual fingerprints: 2.3E-11
```

Checked invariants:

```text
TypeOK
NoLocalContextWithoutLiveEpoch
NoActiveWithoutLiveEpoch
NoActiveAfterDomainRevoke
NoMutableClaimConfersExecution
```

## Security Interpretation

The decomposed models support these design rules:

```text
1. ClusterLease is not directly executable.
2. Node-local execution requires compiled LocalContext.
3. Endpoint use requires compiled endpoint authority.
4. Mutable local claims, caches, or shadows are not authority.
5. Lease/domain epoch revocation clears or invalidates active local execution.
```

This is stronger engineering evidence than waiting indefinitely on one broad
integration model. The full model remains useful as a stress/regression test,
but it is no longer a gate for progress.

## Non-Claims

This validation does not prove:

- distributed consensus,
- cryptographic lease signatures,
- network partition behavior,
- wall-clock lease expiry,
- Linux locking correctness,
- monitor MemoryView/IOMMU enforcement,
- budget conservation beyond the existing split budget model.

Those remain separate design and validation obligations.
