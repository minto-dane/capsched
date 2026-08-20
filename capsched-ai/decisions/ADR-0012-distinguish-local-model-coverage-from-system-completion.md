# ADR-0012: Distinguish Local Model Coverage from System Completion

Status: Accepted

Date: 2026-08-08

## Context

N-155 concluded that the model-only goal was complete after every claim in the
then-current claim inventory had either model support or an explicit evidence
classification. That result was useful: it prevented Linux compatibility,
TLC completion, and evaluation contracts from being promoted into production
protection claims.

The project goal is broader than that inventory. It requires a hostile
Domain-local Linux kernel context to remain unable to cross a Domain boundary,
at process through container granularity, while retaining a viable local
scheduler and a partition-aware multi-cluster control plane. Review of the
exact project lineage at `75e34749b94af52338085caced75c44c70f0a1b4` found
that several system-level obligations were not represented in N-155:

```text
monitor-owned root scheduling availability
bounded per-CPU Domain residency versus global Domain cardinality
syscall/exception/IRQ/NMI entry under MemoryViews
shared executable-code integrity and mutation
service/global mutable-state and management compromise boundaries
partition, clock, fencing, and migration semantics across clusters
explicit composition/refinement among component models
full-path cost envelopes for process-granular Domains
```

The N-155 TLA module is a completion ledger over declared booleans. It is not a
composition of the scheduler, monitor, memory, service, device, and cluster
transition systems.

## Decision

Keep N-155 and its evidence IDs immutable as historical records, but scope its
meaning to:

```text
v1 claim-inventory, local-contract, and overclaim-gate coverage complete
```

Do not use N-155 to state:

```text
the final system model is complete
the component models compose
the hostile-kernel goal is semantically closed
the process-scale or multi-cluster goal is semantically closed
```

The final compositional model goal is reopened. It closes only after the new
requirements in Analysis 0185 have semantic models and an explicit
assume/guarantee or refinement composition.

Use these completion levels in future records:

```text
Inventory complete:
  required claim families are enumerated and non-claims are recorded.

Local-contract complete:
  each component has a checked local safety/liveness contract.

Compositional-model complete:
  shared variables, assumptions, guarantees, and refinement mappings show
  that the hostile-kernel system goal follows from the component contracts.

Implementation complete:
  Linux, Monitor, service, memory, and device mechanisms exist and pass their
  implementation gates.

Protection-evidenced:
  adversarial and exploit evaluation supports the production claim.
```

N-155 reached the first level and substantial parts of the second. It did not
reach the third.

## R6 Disposition

Preserve R6 source, models, negative results, and measurements as research
history. Interpret its 64 slots only as a candidate bounded per-CPU resident
working set until a residency model establishes admission, eviction,
generation fencing, migration, churn, non-aliasing, and progress for more than
64 global Domains.

R6 E4 measurement may remain reproducible engineering work, but it cannot
advance architecture or assurance status before the root-scheduling,
residency, entry/code-integrity, distributed-failure, and composition gates are
closed. No current Linux commit is promoted or reverted by this decision.

## Rationale

Append-only scoping preserves research traceability and avoids pretending the
earlier vocabulary already contained obligations discovered later. Reopening
the larger goal is necessary because a set of individually safe components can
still fail when their assumptions disagree or when an attacker controls the
Linux state coordinating them.

This also keeps optimization subordinate to architecture. A fast local
selector is valuable only if it is a valid refinement of a scalable,
monitor-enforced Domain scheduler.

## Consequences

- `TOP-001` remains Open.
- The assurance tree gains explicit root-scheduler, residency, entry,
  executable-integrity, management, distributed-failure, composition, and
  granularity obligations.
- N-155 is not deleted, renumbered, or silently rewritten into a new proof.
- Additional local TLC runs do not by themselves restore final-model
  completeness.
- Linux behavior work is paused while the reopened architecture gates are
  resolved.
- A monolithic TLC state space is not mandatory. Explicit compositional
  contracts are mandatory.

## Non-Claims

This decision is not a Monitor design selection, Linux patch plan, liveness
proof, composition proof, scalability result, performance result, protection
result, or deployment approval.
