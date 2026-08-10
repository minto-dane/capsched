# ADR-0021: Separate Typed Core Denotation and Finite Evidence Wire

Status: Accepted; refines ADR-0020

Date: 2026-08-10

## Context

The first F0 v5 machine-grammar draft closed useful structural boundaries. A
strict raw-byte parser, pinned meta-schema, relational symbol checks, and 38
hostile mutations all passed. Independent parity review still found direct
prose/AST contradictions: actions had no parameter binder, polymorphic terms
had no common result-sort annotation, quantity arithmetic had no nominal result
binding, exact scope was accidentally limited to a finite profile, and the
runtime objects needed for source counterexample replay were absent.

The same review also found a category error. Infinite interpretations, total
function spaces, executions, and semantic relations have denotational meaning,
but they cannot in general be enumerated as JSON. Finite profiles and finite
runs are evidence objects. Treating the latter as the only semantic objects
would silently weaken the calculus to bounded model checking.

## Decision

### Typed terms are checked wrappers

The machine language represents a term as:

```text
Term = TYPED_TERM(result_sort, node: TermNode)
```

`TermNode` is the closed constructor union. Every recursive term position uses
`Term`, never a raw `TermNode`. The result annotation is not trusted metadata:
the syntax-directed checker derives the unique sort of `node` and requires
exact equality with `result_sort`.

Actions carry an explicit `parameter_variable` and `parameter_sort`. Their
bodies are checked under exactly that one PARAM binding. Quantity addition and
subtraction resolve through a checked declaration that binds each used Qty sort
to one nominal result Variant with the required Ok/Overflow/Underflow shape.

### Interpretation scope is not finite-profile scope

`SCOPE_EXACT` names an interpretation identity. A finite profile is one
machine-replayable realization of an exact interpretation, not the definition
of all exact interpretations. General and infinite interpretations remain
mathematical objects represented inside checked theorem/proof systems. A claim
package must resolve every named exact interpretation through its proof or
finite-evidence registry; an unresolved reference rejects.

Atom declarations explicitly choose `FINITE` or `UNRESTRICTED` carrier class.
Cardinality premises remain typed constraints. Absence of a finite profile
never proves an unrestricted carrier finite.

### Wire objects do not redefine denotation

The machine grammar fixes primitive JSON representations, root entry points,
and one policy for every collection-valued field. Collection policy distinguishes
ordered sequences from duplicate-free canonical sets and canonical maps. A
single exact canonical JSON rule supplies stable identities; unknown fields,
duplicate keys, null, floats, negative integers, non-ASCII values, and
noncanonical collections reject.

Finite replay adds typed wire objects for locations, cells, finite states,
event bundles, labels, transitions, and finite runs. These objects are complete
only under a named finite interpretation. Infinite executions, arbitrary total
maps, PureExtension functions, and PlatformRefinement relations are not
silently serialized as finite arrays; they are quantified denotational objects
or proof terms.

### Construction revisions remain distinguishable

The first v5 grammar bytes are retained by digest and locally rejected for
semantic parity. The successor receives a distinct construction identity. A
language-surface digest covers primitive wire rules, collection policies, kind
partitions, roots, and exact ordered node signatures. The final hostile-review
manifest will additionally pin all normative documents, grammar/schema/rule
artifacts, checker, and mutation corpus.

## Consequences

- A raw constructor cannot evade or forge the unique result-sort check.
- Action parameter identity is explicit and capture checks have a concrete
  binder to validate.
- Finite replay remains executable without turning bounded evidence into the
  meaning of Exact, FiniteClass, or Admissible claims.
- Canonicalization and collection identity become language rules rather than
  mutable prose hints.
- Strict model/profile schema generation remains blocked until this successor
  surface and its collection policies close.
- F0 acceptance, F1/F2/F3, K0/G0, candidate IR, TLA+, Linux behavior, and all
  protection or performance claims remain unauthorized.
