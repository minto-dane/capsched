# ADR-0015: Architecture Before Executable Specification

Status: Accepted as the model-completion work order

Date: 2026-08-09

## Context

TLA+ is valuable for making transition systems executable, finding
counterexamples, and checking finite refinements. It is not an architecture
generator and cannot repair an omitted authority owner, hidden trusted
component, impossible availability promise, or unmodeled cost attack.

Starting from convenient TLA variables risks selecting a small state space
rather than the system required by the hostile-kernel, process-through-
container, datacenter threat model.

## Decision

For every remaining Plan 0006 component, use this order:

```text
1. restate the exact claim and non-claims
2. read current implementation and architecture constraints
3. separate identities, authority, policy, work, and observations
4. enumerate threats, failure modes, and impossibility boundaries
5. compare alternatives and reject unsafe or unscalable shapes
6. define admission, lifecycle, cancellation, recovery, and cost semantics
7. define scale, hierarchy, and rely/guarantee composition
8. perform independent hostile contradiction and minimality reviews
9. freeze the human and machine-readable semantic contract
10. write decomposed TLA+/other executable specifications and mutants
11. validate frozen inputs through claim-specific evidence and a decision
```

TLA+ is therefore the final executable expression of a reviewed semantic
contract, not the first design sketch. A formal counterexample may reopen the
architecture; the model is never forced to pass by weakening the claim or
adding fairness to an adversarial component.

Long-running TLC, symbolic, build, QEMU, or matrix jobs still follow Plan
0006's detached-job rule. Launch plus immutable input capture ends the
interactive task; result acceptance is a separate review.

## Required Architecture Gate

Before executable specification, the component record must explicitly cover:

```text
claim scope and threat subject
object and version algebra
authority owner versus untrusted shadow
linearization and settlement points
resource and control-work conservation
overflow, saturation, restart, and fail-stop behavior
safety versus liveness assumptions and bound units
impossibility/non-claim boundaries
datacenter scale and process-through-container granularity
upstream Linux or architecture refinement surfaces
cross-component rely/guarantee edges
independent contradiction/minimality findings and their disposition
```

"Perfect" is not recorded as a status. The strongest honest state is that all
requirements in the frozen review gate are covered, known contradictions are
closed, deferred assumptions are named, and executable/mutation validation has
not found a counterexample within its exact scope.

## Consequences

- `RESIDENCY-DYN-001` receives an architecture contract and hostile review
  before any new TLA+ module.
- `ENTRY-001 + CODE-001`, `STATE-001 + SVC-001 + MGMT-001`,
  `CLUSTER-PART-001`, and `COMPOSE-001` use the same order.
- Existing accepted models remain valid within their frozen scopes.
- Model-checking convenience cannot silently narrow the project goal.
- Validators and provers remain instruments for the security objective, not
  project goals by themselves.

## Non-Claims

This process decision does not complete any architecture, prove a model,
approve implementation, or guarantee that review has found every defect. It
defines how completeness is pursued and how overclaim is prevented.
