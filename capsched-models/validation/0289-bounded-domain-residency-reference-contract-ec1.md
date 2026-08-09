# Validation 0289: Bounded Domain Residency Reference Contract EC1

Status: Passed; `RESIDENCY-001` may move from Open to Model-supported only

Date: 2026-08-09

Work record: N-176

## Scope

This validation checks the bounded Domain-residency reference contract in
Analysis 0188 and Formal 0148. It is the second claim-specific consumer of
Evidence Capsule v1.

The accepted claim is narrow:

```text
Under the modeled finite one-shot protocols and explicit Monitor/hardware
fairness assumptions, a fixed Monitor-pre-admitted Domain population larger
than the replaceable per-CPU slot set can be projected and served without
making residency execution authority, aliasing identity or slot generations,
evicting trusted references, duplicating exclusive authority, or letting
adversarial Linux starve a modeled guaranteed residency request.
```

It does not select a production directory, cache, replacement, or rekey
algorithm. It does not accept Monitor or Linux implementation, physical shadow
backing, MemoryView/TLB composition, root-budget conservation, wall-clock
bounds, protection, performance, cost, cluster, or datacenter claims.

## Exact Model Identity

```text
model commit: 9f1eaae410fd4878d7e0e04bf757377434980b86
model tree:   736a9484b931b79d6374c468831b6c0d78353fe2
model SHA-256:
  1efd0719569d31657c0b7aaf50e103f5fdcdc94dfce7499fc0f149780982a431

pipeline commit:
  3d1c335e44ae576bb98e98b8e87fdd6001902f52
deterministic hardening commit:
  85724b74659886241474bab8172a19908e6012cc
TLC jar SHA-256:
  936a262061c914694dfd669a543be24573c45d5aa0ff20a8b96b23d01e050e88
contract SHA-256:
  f0047ad634feea5746d2a7fea7c3dd603894bf1f8dd6dfd988f08478fba0ccfe
```

The contract independently fixes all 27 static-input hashes, all 26 command
lines, four safe state-space results, 22 expected negative classifications,
tool identity, deterministic TLC parameters, resource limits, claim boundary,
and 85 producer-declared objects.

## Fail-Closed Diagnostic Run

The first captured run was intentionally not promoted:

```text
run id:
  20260809T054235Z-residency-ec1
capsule id:
  9b7bfd68b91caac3018bf3248af6649504fe7dd81cd83a56b9c3934624afd24c
validator status:
  Invalid
failure:
  SafeAdmission expected depth 23 but observed depth 22
```

The generated and distinct state counts matched. The varying breadth-first
search depth came from parallel TLC exploration rather than a semantic state
space change. Because depth was part of the frozen oracle, the Validator
failed closed and skipped re-execution. The rejected capsule is retained as a
diagnostic witness; it has no promotion credit.

The hardening revision fixes one TLC worker, fingerprint index 0, and seed
20260809014235. Canonical depths were then frozen from a clean deterministic
run before the accepted capsule was produced.

## Evidence Capsule

Canonical run:

```text
run id:
  20260809T060117Z-residency-ec1-deterministic
capsule id:
  efecb20ac9132caf6e20e6a8faac47704fad6429a48416910be62615163e5314
core-manifest SHA-256:
  dbd52e48963b5eb175419502cfc259eba30b618c6d7b0ead694fdbc38dcf5d9a
capture-request SHA-256:
  ba6fcb93d754ccdbc290608b22e9b476fc050eabf0a2e5349c91477099e78f1c
collector SHA-256:
  73835e1b3a80f4116e08b36047ca129072eaebc9dd8d32ae624c3610657e9665
captured claim-validator SHA-256:
  2f97d8792acaa1a4450eb3a525126d16808bd945e2eb42194b63aecc3a30da9e
```

The producer package is a clean initial Git commit:

```text
commit: 16e9e893d62c0d28115a9db2f00939fb9d18a4bc
tree:   dde91af8bc900ae6e16a9daeac4cccf1d8595095
parents: []
dirty: false
```

The Collector captured 87 objects: 85 declared objects plus the exact request
and Collector implementation. The manifest covers 88 files including the
manifest itself. No optional object is missing.

Validator-owned limits sealed into the capsule are:

```text
request:      1 MiB
objects:      96
per object:   8 MiB
total bytes: 64 MiB
per TLC run: 120 seconds
TLC workers: 1
TLC fp index: 0
TLC seed:    20260809014235
```

## Safe Results

Producer execution and Validator re-execution from captured bytes reproduced:

| Configuration | Exit | Generated | Distinct | Depth | Result |
| --- | ---: | ---: | ---: | ---: | --- |
| `SafeAdmission` | 0 | 190271 | 2660 | 21 | safety and guaranteed one-shot admission pass |
| `SafeMigration` | 0 | 39761 | 560 | 8 | source-drain-first exclusive migration passes |
| `SafeHotplug` | 0 | 34791 | 490 | 7 | drain, offline, fresh CPU incarnation passes |
| `SafeRevoke` | 0 | 70071 | 980 | 8 | replica drain before epoch commit passes |

No fairness is assigned to Linux. Weak fairness is limited to the modeled
Monitor protocol and trusted hardware reference-release actions.

## Negative Discrimination

The three temporal mutants exited 13 and the 19 safety or initial-boundary
mutants exited 12. Producer and Validator independently classified all 22:

| Configuration | Failure |
| --- | --- |
| `WaitForLinuxHint` | guaranteed admission waits on adversarial Linux |
| `SkipGuaranteed` | admitted guaranteed request is skipped |
| `NoHardwareQuiesce` | trusted reference never quiesces |
| `EvictPinned` | running or referenced binding is evicted |
| `ReuseGeneration` | slot generation is reused |
| `StaleEpochBinding` | stale Domain epoch is resident |
| `BestEffortOverwrite` | held guaranteed handoff is overwritten |
| `PublishBeforeSeal` | partially installed binding is published |
| `TrustStaleHandle` | stale local handle becomes active |
| `LinuxOwnsBinding` | Linux becomes resident-binding authority |
| `ResidentSlotIsAuthority` | residency itself becomes execution authority |
| `LinuxMintsActivation` | Linux mints activation authority |
| `ManagementBindingLost` | recovery depends on replaceable residency |
| `CopyBeforeSourceFence` | exclusive residency is duplicated |
| `DestinationBeforeSourceStop` | exclusive authority runs on two CPUs |
| `MigrationIdentityDrift` | migration changes global identity or authority |
| `OfflineBeforeDrain` | offline CPU retains authority |
| `LinuxMintsOnlineCPU` | Linux creates authoritative CPU state |
| `ReuseCpuIncarnation` | hotplug reuses a CPU incarnation |
| `EpochBeforeDrain` | revoke commits before trusted drain |
| `ActivateDuringRevoke` | new activation is issued during revoke |
| `LinuxWritesRegistry` | Linux writes the global Domain registry |

The five initial-state boundary cases are still meaningful negative tests:
they reject an invalid authority ownership boundary before a protocol
transition can hide it.

## Claim-Specific Validation

The Validator passed 16 checks:

```text
structural verification before validation
unique manifest object paths
hard-coded independent contract digest oracle
exact contract shape: 27 static inputs and 26 runs
exact RESIDENCY claim and contract scope
exact 85-object declaration with no producer summary
fresh single-commit producer and bounded capture
model/config/tool/validator/collector identity
exact command manifest
declared environment binding
raw log and status recomputation
four exact safe state spaces
22 negative discriminators
no producer-summary oracle
Validator replay of all 26 TLC runs
structural verification after validation
```

Result and decision:

```text
validator-result SHA-256:
  9f4156a60746587a5e6e30583be5fdeeae594655d5babc44f78bc1919dea4e93
decision SHA-256:
  534cf2c87219962a23ae3432b4bf0a22ce2429adda85984be333a7f7dfc224fb
decision id:
  RESIDENCY-001-EC1-decision-20260809T060117Z
allowed transition:
  RESIDENCY-001.open_to_model_supported
```

Both objects validate against the Evidence Capsule v1 Draft 2020-12 schemas.
The decision explicitly forbids implementation, production algorithm,
wall-clock, protection, performance/cost, multi-cluster/datacenter, and
`TOP-001` promotion claims.

## Mutation Validation

The focused regression script reproduced both expected boundaries:

```text
direct-mutation: rejected
resealed-semantic-mutation: rejected-without-reexecution
```

A raw-log mutation fails structural verification. A same-account attacker can
reseal structurally modified bytes at EC1, but the separate claim-specific
oracle rejects the semantic mismatch before executing captured code or tools.

## Evidence Level and Residual Trust

This is EC1, not EC2 or EC3. The workstation kernel, filesystem, Java and
Python runtimes, Git, SHA-256 implementation, Collector and Validator account,
TLC implementation, TLA semantics, and finite model abstraction remain in the
trusted evidence base. There is no independently implemented oracle or
independent-host reproduction.

The accepted and rejected capsules reside under:

```text
build/evidence-capsules/bounded-domain-residency/
```

The separate Validator result and approval decision reside under:

```text
build/evidence-producer/bounded-domain-residency/
  20260809T060117Z-residency-ec1-deterministic/
    validator-result.json
    decision.json
```

Their exact hashes support later copying or append-only publication. This
record is not a substitute for retaining both capsules and the separate
decision object.

## Decision

`RESIDENCY-001` is now Model-supported for the finite reference contract.
The new `RESIDENCY-DYN-001` requirement retains everything outside this
decision: dynamic feasibility admission/rejection and class changes, recurring
request identity/cancellation/coalescing, bounded churn and overflow work,
generation saturation/rekey, and production representation/replacement. It is
Open and is the next model. Physical-lifetime refinement, Monitor and
architecture implementation, `ENTRY-001 + CODE-001`, later
state/service/cluster composition, and final cross-component refinement also
remain open.
