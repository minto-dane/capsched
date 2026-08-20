# ADR-0019: Decompose Foundation Calculus, Claims, Platform, and Assurance

Status: Accepted; refines ADR-0018

Date: 2026-08-10

## Context

The exact `DL-SemFoundation-3` draft repaired several category errors from the
epoch-2 v2 kernel: it supplied set-theoretic carriers, total maps, explicit
stutter, checked arithmetic, phase-labelled terms, finite/general claim
separation, and a backend/TCB boundary. Four independent local advisory reviews
nevertheless rejected the exact v3 bytes.

The draft still combined four different jobs. Its base transition calculus was
not fully typed; progress, time, durability, distribution, composition, and
noninterference were requirement lists rather than denotations; the abstract
state could omit physical attack surfaces; and the external K0 source set and
trust policy did not yet exist. Treating all of that as one document made a
locally sound paragraph appear to lend authority to unrelated open semantics.

## Decision

Retain v3 unchanged as rejected evidence. Build its successor as four separately
versioned and digest-bound layers:

```text
F0  typed transition calculus and metatheory
F1  claim-specific semantic modules
F2  platform refinement and threat over-approximation
F3  externally owned K0 policy, coverage, mutation, and assurance package
```

### F0: Typed transition calculus

F0 owns only the common mathematical substrate:

```text
well-formed signature and model body
set-theoretic interpretation and finite executable profile
phase/provenance-indexed AST, typing, and denotation
dependent-sum Label and Location carriers
explicit action branches, parameters, events, frames, and closed relations
base executions, stutter, enabledness, reachability, and safety judgments
claim well-formedness and mandatory nonvacuity premises
```

An action relation must be generated from its exact body, branch identity,
event constraint, and independently derived frame. A post-state difference
cannot define its own permission to write. Variables retain `STATIC`, `PARAM`,
`PRE`, `POST`, or `EVENT` provenance, so a binding cannot launder a post/event
value into a state predicate.

### F1: Claim semantics

F1 contains separate, composable modules for:

```text
response, request correlation, fairness feasibility, and ranking
timed traces, clocks, uncertainty, provider service curves, and non-Zeno time
durable/volatile state, cut generation, crash, recovery, and re-crash
network and authority-transfer protocols, anti-replay, and refund limits
parallel-lane composition and rely/guarantee discharge
two-trace confidentiality and robust-integrity/endorsement
```

Each module defines syntax, state contribution, transition contribution,
satisfaction, nonvacuity, and composition. It also supplies an erasure map to
F0. A module may be called conservative only after stating and discharging the
appropriate syntactic conservativity and trace-projection obligations. A module
that restricts traces by assumptions is labelled an assumption-qualified
refinement, not an unconditional conservative extension.

Safety is evaluated over all base executions containing every mandatory hostile
and fault action. Fairness may restrict only an explicitly named progress claim
and must have a nonempty admitted trace set. It cannot remove a safety
counterexample or grant fairness to hostile Linux or an asynchronous network.

### F2: Platform refinement and threat closure

F2 connects abstract model state to machines that can be attacked. It owns:

```text
physical and architectural state/observation coverage ledger
abstraction and concretization relations
Monitor-enforced deny boundary
candidate-independent compromised-principal havoc relations
coalition compromise matrix and guarantee/nonclaim partition
process/thread/container/service/cluster-cell sharing and lifecycle graph
multicore, memory-model, IRQ/NMI, DMA/IOMMU, device, raw ABI, and crypto models
microarchitectural observation basis and explicit leakage budgets/nonclaims
```

Unknown reachable physical state is not silently abstracted away. For a claimed
boundary it either maps to an abstract state/action/observation, is physically
proved inaccessible by the Monitor/hardware contract, or makes the claim
incomplete. A candidate may refine but never narrow the K0-owned compromised
step relation.

### F3: External K0 package

F3 binds the complete pre-candidate source set:

```text
F0/F1/F2 exact manifests and metatheory evidence
role-typed policy templates and mandatory threat/action basis
claim and nonclaim catalog
scenario, cut, topology, interaction, and paired-trace generators
hostile mutation catalog and expected counterexamples
proof/checker policy and certificate formats
out-of-band trust root, gate policy, assignments, checkpoint, and high-water
```

The `FoundationSourceSet` is fixed before any K1 candidate or campaign capsule.
The K0 verifier derives one transition only:

```text
foundation_open -> candidate_construction_authorized
```

No candidate-selected registry, verdict field, evaluator, backend, or review
roster may authorize that transition.

## Required Review Order

```text
F0 closure and hostile review
  -> F1 modules and cross-module composition review
  -> F2 platform/refinement and threat-coverage review
  -> F3 source-set and assurance review
  -> external K0 decision
  -> and only then K1 candidate construction
```

Failure in a predecessor creates successor bytes and invalidates dependent
reviews. Rejected bytes remain immutable and addressable.

## Consequences

- `DL-SemFoundation-3` cannot authorize K0, candidate IR, TLA+, or a model
  claim.
- The v4 work starts with F0; it does not copy prose-only F1/F2 requirements
  into a machine inventory and call them semantics.
- `Formal/0150` and candidate-specific D0-D17/W0-W12 remain forbidden before a
  real external K0 transition.
- TLA+, SMT, Alloy, scenario generators, and reference evaluators remain
  untrusted producers unless a later narrow decision changes that boundary.
- Linux behavior and HyperTag Monitor implementation remain out of scope for
  this model-completion goal.

## Non-Claims

This decision does not complete any F-layer, establish metatheory, supply an
external trust root or review, authorize candidate construction, freeze an
architecture, prove isolation or progress, or support protection, performance,
cost, scalability, cluster, or deployment claims.
