# AI Handoff

Updated: 2026-08-08

This file is current-state context only. Detailed chronology is in
`state/events.jsonl`, `design/compact.md`, focused model notes, and Git history.
Do not load the full chronology during routine recovery.

## Mission

DomainLease-Linux aims to provide process-through-container Domain boundaries
whose escape under arbitrary Domain-local Linux kernel-context compromise
requires breaking the Domain Monitor or an explicitly exposed typed service
endpoint, comparable to hypervisor escape.

It also targets one logical OS/authority namespace across nodes and clusters,
with node-local enforcement and higher cost efficiency than VM-based isolation
for selected datacenter workloads.

## Current Verdict

```text
v1 claim inventory/local-contract coverage:
  historically complete under N-155

final compositional model:
  reopened and incomplete

Linux implementation:
  historical scaffold and experimental prototypes only

Monitor implementation:
  absent

protection/cost/deployment claims:
  false
```

ADR-0012 and Analysis 0185 are authoritative. They preserve N-155 as a narrow
historical result and add the missing system requirements.

## Current Git State

Project-control work is isolated on:

```text
branch:
  codex/goal-conformance-and-assurance-repair

semantic baseline before this state repair:
  8fa312728240edaa256746a235e387c90ede7956

reviewed prior lineage:
  75e34749b94af52338085caced75c44c70f0a1b4

stable main:
  4aa3f5427e1d3649d4de1cadcbcb8f268fb932a9
```

Sibling Linux source:

```text
branch: capsched-linux-l0
HEAD:   74311ca1ac4937e0e62f1e0f6a3e5bfa4fc77d6f
tree:   54f685aad94f28f0027cbba18cf5e29aadce234a
base:   4edcdefd4083ae04b1a5656f4be6cd83ae919ef4
fetched upstream/master:
        a7c7074b58d28c4206d666a12aa2e33447b3c581
```

Sibling patch queue:

```text
branch: codex/replay-clone-portability
HEAD:   16bb080da472ffabbbafd2698073eca633fb0602
```

All three repositories were clean when this repair began. No Linux source or
patch-queue change is part of the current branch.

## Reopened Requirements

```text
ROOTSCHED-001
  Monitor-owned root handoff and guaranteed-Domain progress under hostile Linux

RESIDENCY-001
  global Domain identity with bounded per-CPU resident slots

ENTRY-001 / CODE-001
  privileged entry/return, MemoryView, stack, TLB, and shared executable integrity

STATE-001 / SVC-001 / MGMT-001
  exhaustive mutable-state ownership and bounded service/management compromise

CLUSTER-PART-001
  partitions, clocks, expiry, fencing, migration, and namespace recovery

COMPOSE-001
  explicit assume/guarantee and refinement composition

GRANULARITY-001
  complete-path security and cost envelope for process-through-container Domains

EVIDENCE-001
  validator-owned immutable evidence capsules
```

## R6 Status

R6 is retained as a bounded local selector research candidate. Its 64 slots are
not a node-wide Domain limit. The only admissible future interpretation before
`RESIDENCY-001` closes is a per-CPU resident working set with stable
DomainID/epoch and slot-generation fencing.

R6 E4 may be reproduced as an engineering experiment, but it is paused as an
architecture, assurance, performance, or cost promotion gate. Existing exact
Git objects remain useful. Positive promotion credit needs revalidation under
ADR-0013 if R6 remains architecturally relevant.

## Evidence Status

ADR-0013 and Analysis 0186 define Evidence Capsule v1:

```text
capture bytes first
seal an immutable manifest
validate only the captured bytes
recompute summaries from retained raw evidence
bind approval to the capsule id
```

The v1 schemas, capture-first Collector, structural Verifier, and bootstrap
mutation fixtures now exist under `validation/evidence-capsule-v1/`.
Validation 0287 passes six positive and 32 fail-closed cases. This is only the
minimal structural layer: no claim-specific Validator/Approver, historical
migration, EC2 independence, or EC3 reproduction is complete. Codex Security
plugin completion is not a project gate, and its non-sealed diagnostic run is
not assurance evidence.

## Next Order

1. Draft the adversarial Monitor root scheduler model and its claim-specific
   capsule Validator.
2. Draft the global Domain identity and bounded residency model.
3. Compose entry, MemoryView/TLB, stack, and code-integrity semantics.
4. Continue Plan 0006 through state/service/management, cluster partitions,
   composition, and the full cost contract.

## Do Not Do Yet

```text
do not add behavior-changing Linux scheduler enforcement
do not promote R6 as the node-wide architecture
do not treat Linux runqueue or selector state as root availability authority
do not claim final model completion
do not claim monitor-backed protection or cost efficiency
do not accept positive producer summaries without a captured validator capsule
```

## Long-Running Work

For TLC runs, symbolic checking, full kernel builds, QEMU/sanitizer matrices, or
measurements expected to outlive an interactive session:

1. Capture and seal exact inputs.
2. Launch through the detached job mechanism.
3. Record the launch identity and stop the interactive session.
4. Validate the completed result independently in a later session.

Do not poll a healthy long-running job merely to keep a chat session alive.

## Recovery Read Order

1. `state/state.json`
2. this file
3. `../capsched-models/analysis/0185-final-goal-conformance-and-compositional-model-reopen.md`
4. `../capsched-models/plans/0006-final-compositional-model-completion-plan.md`
5. focused artifacts for the next requirement only

Use `design/compact.md` only for historical detail.
