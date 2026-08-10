# ADR-0017: Reject R11 G0 v1 and Require Executable External Semantics

Status: Accepted

Date: 2026-08-09

## Context

R11 G0 v1 separated a candidate bundle, three review roles, a gate decision,
and an evidence capsule. It also moved policy, profile, rule, and mutation names
outside the future machine IR. The exact 17-artifact candidate is reproducible,
and its 12 declared structural mutations reject at fixed locations.

That separation is necessary but not sufficient. Three fresh hostile reviews
and two executable negative tests show that the policy still expresses most
meaning as unconstrained identifiers or prose. The checker accepts all 12
tested semantic weakenings. The review and gate schemas also accept five
forged-positive documents, including failed checks, duplicate roles, one
principal occupying all roles, and an open blocking finding paired with an
`accept` verdict.

A schema can validate document shape. It cannot establish formula meaning,
cross-field truth, principal independence, or signed authority merely because
the document contains booleans asserting those properties.

## Decision

Reject the exact R11 G0 v1 candidate before external review. Preserve its 17
captured artifacts and manifest digest unchanged as negative evidence. Do not
repair those captured files in place and do not reuse v1 acceptance language
for a different trust model.

Continue within R11 as G0 epoch 2. This is not R12 because no R11 machine IR,
semantic freeze, or accepted G0 boundary exists yet.

Epoch 2 must use an external, backend-neutral, executable semantic kernel:

```text
external semantic signature
  finite sorts, products, identities, units, state products, owners, writers

external formula/template library
  typed formulas for every SEM rule, invariant, progress and provider contract

candidate architecture IR
  concrete state and action relations plus total typed bindings to templates

independent materializer and proof backends
  instantiate obligations; never infer missing meaning from names or prose

external scenario semantics
  typed actions, relations, outcomes, cuts and mandatory interaction products

independent promotion boundary
  authority registry, exact review set, signed receipts and executable gate
```

No normative formula may be supplied as a free-form string, an unconstrained
name, or backend source. Candidate bindings may select declared symbols of the
required type and context, but may not redefine the external template being
bound. Every mutable state product has an exact owner, consistency-domain key,
initial origin, writer action set, linearization point, and failure successor.

Progress obligations must identify a typed trigger, success predicate,
well-founded rank or explicit finite bound, fairness only for named trusted
actions, and an exact unit. Policy withdrawal is a distinct terminal outcome;
it cannot satisfy a promised service-success property.

Scenario profiles must be generated from typed action semantics and a mandatory
interaction matrix. Witness labels are not evidence. Each required obligation
needs a reachable antecedent, an executable trace or cut family, and a semantic
mutation that would falsify it.

Review receipts and gate decisions require executable cross-document checks.
An `accept` decision is valid only when exact required check and review-role
sets are unique and complete, every disposition passes, blocker counts are
recomputed, principals and authorities satisfy an externally rooted
disjointness policy, predecessor digests are current, and the canonical signed
payload verifies. Self-asserted independence fields carry no authority.

## Consequences

- The v1 local integrity and 12 structural mutation results remain useful.
- The v1 policy/profile/review/gate semantics cannot authorize external review,
  machine-IR construction, semantic freeze, TLA+, or model support.
- Formal 0150 is not constructed until an epoch-2 G0 decision passes through
  an authority outside the candidate change authority.
- The epoch-2 design must close each recorded semantic and promotion
  counterexample, not merely rename fields or add required prose.
- Local AI or subagent reviews remain advisory even when role-separated. They
  cannot attest organizational or cryptographic externality.
- No Linux behavior patch or Domain Monitor implementation is authorized.

## Non-Claims

This decision does not complete epoch 2, establish an external authority,
prove any invariant, validate liveness, authorize TLA+, or support protection,
compatibility, performance, cost, cluster, or deployment claims.
