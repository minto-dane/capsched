# ADR-0018: Split Foundation, Candidate, Freeze, and Proof Gates

Status: Accepted; refines ADR-0017

Date: 2026-08-10

## Context

ADR-0017 correctly rejected R11 G0 v1 and required executable external
semantics. The first epoch-2 semantic-kernel contract still mixed four stages:
defining a language and policy, authorizing candidate construction, reviewing
an exact candidate, and accepting proof evidence.

That creates a cycle. Candidate bindings and writer/action completeness cannot
be prerequisites for a gate that must pass before the candidate may be built.
The initial kernel contract also listed operators without defining a carrier,
state, action, event, trace, stuttering, enabledness, or satisfaction relation.
A reference interpreter and conformance corpus can test an implementation of
semantics, but cannot serve as the definition of those semantics.

## Decision

Replace the single overloaded R11 gate with four acyclic gates:

```text
K0 / G0  Foundation adoption
  language denotation, type/phase system, external policy templates,
  mandatory threat/action basis, scenario-generator rules, mutation catalog,
  assurance root and tool policy
  -> authorizes candidate construction only

K1 / G1  Candidate construction readiness
  exact state/action/event IR, total role bindings, generated frames,
  reachable cases, cuts, mutations, and local mechanical closure
  -> authorizes exact semantic review only

K2 / G2  Exact semantic review and architecture freeze
  externally authenticated reviews of final candidate bytes and generated
  semantics, with deterministic derived acceptance
  -> authorizes backend translation and proof attempts only

K3 / G3  Proof and evidence decision
  translation-validation evidence, safety/liveness/noninterference results,
  hostile mutants, exact claim-specific capsule and decision
  -> may support only the exact model claims named by that decision
```

Every gate consumes only immutable predecessor bytes and external inputs that
were fixed before the artifact under review. A later gate cannot retroactively
select an earlier trust root, policy, checker, roster, or checkpoint.

The semantic foundation has a mathematical denotation independent of any
interpreter or backend. It defines sort carriers, units, total state maps,
events, action relations over pre/post states, explicit stutter, finite and
infinite traces, enabledness, and satisfaction. Syntax is phase typed:

```text
StaticTerm<T>
PreTerm<T>
PostTerm<T>
StatePred
ActionRel(pre, params, post, event)
```

Temporal progress, timed/provider behavior, distributed crash/durability, and
two-trace noninterference are separate conservative extensions. There is no
temporal-next expression in the base term language.

All operations are total. State products are total maps. Absence is an
`Option`; sums and options use exhaustive matching; checked quantity arithmetic
returns an explicit success/overflow/underflow result. The kernel has no raw
semantic string, unbounded host integer, partial lookup, arbitrary choice,
embedded backend source, or digest operator.

Architecture carriers are parametric. A finite executable profile supplies a
finite carrier valuation and numeric limits. Counterexample-free bounded runs
support only bounded claims unless a separate induction, refinement, or
proof-producing argument establishes a broader theorem.

The external threat policy owns mandatory environment and adversary action
families. Candidate omission cannot remove hostile Linux writes, mint/replay,
scheduler suppression, service/management compromise, message loss/duplicate/
reorder, stale references, crash, restart, or clock uncertainty when they are
in scope.

Protocol v3 from Analysis 0201 is the assurance baseline, not a parallel
protocol. Epoch 2 refines it with a pre-candidate out-of-band `TrustRoot`,
`GatePolicy`, checker pins, persistent high-water state, exact
`(review-role, check-id)` assignments, and a verifier-derived decision. The
gate never selects the registry that authenticates that same gate.

## Consequences

- The first semantic-kernel v2 contract is retained as a rejected requirements
  inventory and is not implemented.
- A revised v3 kernel must define denotation before syntax implementation or
  conformance fixtures.
- G0 now means K0 foundation adoption only. It no longer requires or contains
  candidate IR.
- Formal 0150 belongs to K1 and remains forbidden until K0 is externally
  accepted.
- W0-W12 remain coverage views, not single scenarios. Typed generators expand
  them into digest-fixed reachable traces and hostile schedules.
- TLA+, SMT, Alloy, interpreters, scenario compilers, and solvers are untrusted
  producers unless a narrower decision explicitly places a checker in the TCB.
- Backend test agreement is regression evidence, not translation equivalence.
  Proof-producing translation validation or compositional preservation evidence
  is required for the corresponding claim.
- No Linux behavior change or Monitor implementation is authorized.

## Non-Claims

This decision does not complete K0, supply an external root, define all policy
templates, construct candidate IR, freeze architecture, prove a property, or
support protection, performance, cost, cluster, or deployment claims.
