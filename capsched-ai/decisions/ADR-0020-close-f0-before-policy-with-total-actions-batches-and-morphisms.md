# ADR-0020: Close F0 Before Policy with Total Actions, Batches, and Morphisms

Status: Accepted; refines ADR-0019

Date: 2026-08-10

## Context

The exact first F0 v4 draft made useful progress: dependent locations and
labels were explicit, state updates generated their own frame, safety ranged
over assumption-free executions, and finite/general claims were separated.
Four exact-hash local hostile reviews still rejected it.

The draft's event terms were not constructible, state invariants could read an
unbound action parameter, declared actions could be omitted from the step
relation, read instrumentation was undefined for infinite quantification,
outer-cell maps could hide coarse authority writes, quantified model classes
could be empty, and extension/refinement interfaces had no morphism laws. It
also deferred the machine grammar and proof objects to F3, allowing an external
policy selected later to redefine what counted as an F0 proof.

## Decision

The v4 bytes are retained unchanged and rejected. F0 v5 follows these rules.

### One closed core package

F0 fixes, before F3:

```text
normative mathematical denotation
fully expanded machine grammar
syntax-directed typing and provenance rules
well-formedness predicates
claim/scope/nonvacuity judgments
metatheory theorem statements
proof-object or certificate format
small checker interface and soundness statement
```

F3 may authenticate, assign reviewers to, and decide adoption of those exact
bytes. It cannot select a successor grammar, theorem, proof calculus, or checker
retroactively.

### Three well-formedness levels

```text
CoreSyntaxWF(M)
  finite expanded declarations and bodies, namespace/import closure, typing

InstanceWF(M,I)
  valid inhabited interpretation, semantic branch disjointness, premises

ClaimPackageWF(M,I_or_scope,C,P)
  claim-specific nonvacuity, assumption feasibility, mutants, scope binding
```

`Admissible(M)` contains only interpretations satisfying `InstanceWF` and the
explicit typed model-class premises. Every quantified claim requires a witness
that its interpretation class is nonempty; finite-class claims require an
admitted finite witness.

### Exact action closure

Every declared action has exactly one body and every action is in the base step
relation:

```text
dom(ActionBodies) = ActionName
```

There is no candidate-owned `RequiredActionSet`. F3 ensures the complete
mandatory action basis is declared. Invocation predicates and branch guards
must satisfy policy-required totality; compromise interfaces require
candidate-non-narrowable input-enabledness/inclusion at F2/F3.

### State predicates and action-scoped terms

Closed `StatePred` may depend only on `PRE`. Action bodies bind an explicit
typed `p:Pa`; no unindexed `current_parameter` primitive exists. Event
construction and exhaustive event matching have explicit AST, typing,
provenance, and evaluation rules. Only transition labels invert to exact action,
branch, and parameter. Events need only satisfy channel/tag/payload typing.

### Security-visible state normal form and finite batch updates

Authority-relevant mutable maps cannot be hidden as one outer cell. F0 defines
a security state-normal-form obligation: state-product keys expose the
granularity at which ownership, conflict, framing, and compromise are claimed.

Point writes remain available. Dynamic atomic updates use a finite batch:

```text
Patch(q, D, values)
  D : FinSet(Kq)
  values : TotalMap(Kq,Vq)
```

Its simultaneous write set is exactly `{(q,k) | k in D}`. Batch/list ordering,
same-location conflict, read footprint, and frame semantics are explicit.
Infinite or unbounded atomic havoc is not smuggled through a whole-map value;
F2 compromise is represented by input-enabled finite adversary steps and their
closure, or by a separately justified physical refinement.

### Event channels

A step emits a finite typed event bundle keyed by fresh event-channel names.
Stutter emits the empty bundle. Module composition combines disjoint channels;
erasure removes module-owned channels. Full labels are semantic occurrence
witnesses and are not automatically public observations.

### Denotational footprints

The common calculus uses set-valued read/write footprints with recursive rules
and a footprint-stability theorem. Ordered operational traces exist only in a
finite executable fragment with an explicit canonical order and are not part of
the parametric denotation.

### Separate morphisms

F0 defines two interfaces:

```text
PureExtension
  injective/fresh signature import, interpretation restriction, state/label/
  event projection, init preservation, finite-path step projection, identity,
  composition, and optional backward lifting for true conservativity

PlatformRefinement
  abstract/concrete state and observation relations, init simulation,
  finite-path step simulation, whole-execution projection, and footprint
  preservation
```

One-way projection is sound refinement, not conservativity. Trace-restricting
assumptions are named assumption-qualified refinements.

### Claim-bound nonvacuity

Nonvacuity is bound to the exact `(claim, scope, interpretation/profile)`.
Branch reachability in some unrelated profile is no substitute. Every
assumption-filtered claim proves an admitted trace exists. Mutations are
digest-bound semantic operators that preserve the claim and premises, alter a
designated site, remain in scope, and produce a replayable reachable
counterexample.

Finite search bounds are evidence metadata, never part of `I_F`. A replayed
counterexample refutes every scope containing its valid instance; a positive
exhaustive result supports only the exact instance unless a checked widening
proof applies.

## Consequences

- F0 v4 is immutable rejected evidence and cannot be repaired in place.
- F0 v5 must close the machine grammar and proof boundary before it can be
  locally accepted.
- F1 work remains blocked until an exact F0 interface survives hostile review.
- F2 and F3 remain distinct; F3 cannot lend semantic meaning to an incomplete
  F0/F1/F2 document.
- No K1 candidate IR, TLA+, Linux behavior, or Monitor implementation is
  authorized.

## Non-Claims

This decision does not complete F0, prove its metatheory, supply F1/F2/F3,
constitute external K0 authority, or support model, protection, performance,
cost, scale, cluster, or deployment claims.
