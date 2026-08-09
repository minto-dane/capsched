# Plan 0006: Final Compositional Model Completion

Status: Active; supersedes model-complete scheduling optimization as the
critical path

Date: 2026-08-08

## Objective

Complete a compositional semantic model of the hostile-kernel,
process-through-container, monitor-backed, multi-cluster DomainLease-Linux
architecture before promoting another Linux scheduling mechanism.

This plan implements ADR-0012 and Analysis 0185. It does not discard existing
models. It supplies the missing system contracts between them.

## Exit Condition

The plan is complete only when all of the following are true:

```text
ROOTSCHED-001 closed
RESIDENCY-001 closed
ENTRY-001 closed
CODE-001 closed
STATE-001 closed
SVC-001 closed
MGMT-001 explicitly modeled or bounded by an accepted threat assumption
CLUSTER-PART-001 closed
COMPOSE-001 closed
GRANULARITY-001 has a complete-path evaluation contract
EVIDENCE-001 closes positive-evidence provenance
```

Closure means more than a checklist boolean. Each requirement needs a human
contract, machine-readable record, formal or otherwise executable semantics,
negative cases, and an assurance mapping.

## Phase A: Evidence and State Trust

Purpose:

```text
make future positive decisions depend on captured evidence rather than on the
producer's mutable workspace or summary
```

Deliverables:

1. Evidence Capsule v1 contract.
2. Producer/validator role separation.
3. Validator-owned capture-before-read rule.
4. Transitive manifest for source, config, tool, command, image, raw output,
   and derived result.
5. Revalidation classification for existing positive gates.
6. Compact HEAD-fresh AI state with a machine check.

Gate:

```text
no new positive promotion gate may consume uncaptured producer summaries
negative evidence and counterexamples remain usable with explicit provenance
```

Current status: the compact state check and minimal Evidence Capsule v1
Collector/structural Verifier are complete. EVIDENCE-001 remains open because
claim-specific Validators, approval binding, historical migration, and EC2/EC3
evidence do not yet exist.

## Phase B: Root Execution and Scale

### B1: Adversarial Root Scheduler

Model the Linux scheduler state as attacker-controlled after Domain compromise.
The Monitor must independently enforce:

```text
root lease admission
root budget/deadline expiry
bounded overrun
handoff away from an expired or revoked Domain
eventual service for another eligible guaranteed Domain
reserved management/recovery service
```

The model must distinguish safety from availability:

```text
safety:
  an unauthorized Domain does not run

liveness:
  an admitted guaranteed Domain is not permanently suppressed by Linux
```

Expected tool: TLA+ with explicit weak/strong fairness assumptions limited to
Monitor and hardware actions. Do not assume fairness from adversarial Linux.

### B2: Bounded Residency

Model more global Domains than per-CPU slots. Include:

```text
stable DomainID and epoch
slot generation
admit, reject, evict, and reuse
running and referenced-slot quiescence
cross-CPU migration
CPU hotplug
guaranteed versus best-effort classes
churn and overflow
```

R6 is accepted only as a local refinement candidate if its slot and selector
actions refine this model.

Expected tool: TLA+ for temporal behavior; Alloy may be used as a bounded
structural cross-check for identity/slot aliasing, but is not required.

## Phase C: Privileged Address-Space Integrity

### C1: Entry, MemoryView, and Translation

Compose activation with syscall, exception, IRQ, NMI-class entry, nested entry,
stacks, per-CPU state, TLB, and return. Model stale, reordered, duplicate, and
interrupted transitions.

Key properties:

```text
NoEntryWithWrongView
NoEntryStackCrossDomain
NoNestedEntryEpochConfusion
NoReturnToRevokedView
NoStaleTranslationAfterOwnershipTransfer
```

### C2: Executable Integrity

Model shared read-only executable pages, W^X, code epochs, and controlled
mutation for modules, livepatch, alternatives/static keys, tracing probes,
text pokes, and JIT pages.

Key properties:

```text
NoDomainWritableSharedExecutable
NoExecuteBeforeSeal
NoOldCodeEpochAfterCommit
NoLinuxMintedExecutableProvenance
```

Expected tools: TLA+ for transitions; later architecture-specific page-table
tests and LKMM litmus tests for publication/invalidation ordering.

## Phase D: State, Services, and Management

### D1: Exhaustive Mutable-State Ownership

Create an ownership algebra for privileged mutable pages and objects. Unknown
classification is an error, not shared Linux state.

The model must include allocator metadata, stacks, credentials, fd tables,
VFS/page-cache state, network state, async queues, and device metadata as
representative classes. It need not enumerate every Linux type in TLA+, but the
refinement ledger must map every implementation allocation family to an owner.

### D2: Compromised Service Domain

Assume arbitrary kernel-context execution inside one service Domain. Prove that
its effects remain limited to typed endpoint operations, explicitly shared
buffers, service-local objects, caller-frozen authority, and budgets.

### D3: Management and Recovery

Separate:

```text
offline signing root
online cluster control plane
node-local Monitor
management Domain
recovery/break-glass authority
```

Record which compromise cases are prevented, contained, recoverable, or out of
scope. Do not hide all of them behind one trusted-root sentence.

## Phase E: Multi-Cluster Failure Semantics

Model at least two clusters, multiple nodes, delayed/reordered/duplicated/lost
messages, a network partition, local monotonic clocks with declared drift
bounds, node restart, and migration.

Required decisions:

```text
lease signature and delegation chain shape
maximum offline lease duration
renewal and expiry rules
epoch/quorum recovery rule
fencing token and ownership transfer rule
global Domain/endpoint namespace uniqueness
source/destination migration non-duplication
partition behavior by workload class
```

Required non-claim:

```text
instantaneous global revocation and unrestricted partition availability are
not both promised
```

Expected tool: decomposed TLA+ models with symmetry and bounded topology. Use a
separate refinement model instead of retrying an unbounded monolith.

## Phase F: Composition and Refinement

Create a machine-readable component contract ledger. Each row records:

```text
component id
owned variables
read-only dependencies
trusted actions
adversarial actions
assumptions
guarantees
failure/recovery actions
refinement mapping
consumers
unresolved incompatibilities
```

Then build cross-component models for the six compositions listed in Analysis
0185. `COMPOSE-001` closes only when:

1. Every assumption is discharged by a named guarantee or accepted threat
   assumption.
2. No variable has conflicting owners.
3. No Linux-visible shadow is promoted to Monitor authority.
4. Revocation and failure actions compose without stale carrier escape.
5. Safety and required liveness properties survive adversarial Linux actions.
6. The architecture objects have refinement mappings to eventual Linux and
   Monitor implementation surfaces.

TLAPS may be introduced for stable inductive invariants. Apalache may provide a
symbolic cross-check. Neither is required merely for tool diversity.

## Phase G: Granularity and Cost Contract

Define experiments only after Phases B through F fix the complete transition
path. Required workload classes:

```text
same-Domain threads
process-per-Domain high-risk service
container/service Domain
tenant Domain with nested process Domains
cross-node service call
device-queue owner Domain
```

Required baselines:

```text
ordinary Linux process/container
KVM VM
microVM
DomainLease-Linux Linux-only prototype
Monitor-backed DomainLease-Linux
```

Measure throughput, p50/p95/p99/p999 latency, CPU overhead, memory density,
TLB behavior, service IPC, device path, recovery time, and operational cost.
Security envelopes must be matched before cost comparisons are accepted.

## Linux Work During This Plan

Allowed:

```text
read current upstream source
refresh source anchors and semantic drift maps
preserve existing patch queue and disposable prototypes
build no-behavior measurement or conformance helpers only when a model requires
them and a separate gate approves them
```

Paused:

```text
new behavior-changing scheduler enforcement
promotion of R6 as the node-wide architecture
R6 E4 as an assurance or cost promotion gate
new public ABI
claims of final model completion
```

## Long-Running Validation Rule

TLC, symbolic checking, full kernel builds, QEMU matrices, sanitizer matrices,
and performance runs that are expected to outlive an interactive session must
be launched through the existing detached job mechanism. Launch and immutable
input capture complete the interactive task; result acceptance is a later,
independent task. An interactive agent must not spend context repeatedly
polling a healthy long-running job.

## Immediate Next Artifact

The next semantic model is the adversarial Monitor root scheduler. Its
claim-specific Validator is the first consumer of Evidence Capsule v1. The
bootstrap container is ready; a positive root-scheduler result still requires
captured raw model/tool output and a capsule-bound decision.

## Non-Claims

This plan is not a proof, implementation approval, Monitor implementation,
Linux hook selection, protection result, scalability result, cost result, or
deployment approval.
