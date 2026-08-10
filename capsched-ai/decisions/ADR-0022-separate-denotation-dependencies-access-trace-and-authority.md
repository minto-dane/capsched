# ADR-0022: Separate Denotation, Dependencies, Access Trace, and Authority

Status: Accepted; refines ADR-0021

Date: 2026-08-10

## Context

F0 v5 originally defined `Eval` and a dynamic `Reads` set. That set omitted
PARAM and EVENT, sometimes erased PRE versus POST, and selected branches and
dynamic keys only after evaluation. It was therefore useful as a state-support
projection but unsafe to interpret as a complete dependency set or as prior
authorization. The prose stability theorem also permitted selector equality as
an external premise, which could conceal a missing selector dependency.

The finite evaluator has a different problem. It needs deterministic access
order, resource accounting, finite carrier enumeration, and explicit
inconclusive outcomes. None of those operational concerns may narrow the
set-theoretic meaning of an infinite interpretation.

## Decision

### Value and selected-path dependencies are simultaneous

The denotational judgment is `ObsD=(value,DynDeps)`. `Eval` is its value
projection. `DynDeps` contains typed PARAM, PRE, POST, and EVENT dependencies.
PRE and POST locations remain distinct. Let and match binders carry the origin
dependencies of their bound value; quantifier binders are internally generated
and carry none.

`StateReads`, with `Reads` retained as an exact compatibility alias, is only the
phase-preserving PRE/POST projection of `DynDeps`. It is not complete provenance
and is never a capability grant.

### Structural bounds and actual traces are separate

`MayDeps` is an input-independent structural upper bound. It includes every
branch and the complete key carrier for every syntactic state-product read.
It may be infinite.

`EvalF` over a validated finite interpretation emits an ordered `AccessTrace`
in addition to value and dependencies. Strict operators and quantifiers do not
short circuit; only conditionals and exhaustive matches select one branch. The
set projection of a complete root trace must equal `DynDeps`.

Dynamic dependencies cannot be used after the fact as authorization. A
concrete refinement must either preauthorize the conservative `MayDeps` bound
or mediate every primitive access before it occurs. This obligation belongs to
the platform/refinement layer, not to hidden F0 evaluator policy.

### Mathematical and finite evaluation remain different interfaces

`ObsD` is total for every well-typed term in every admissible interpretation,
including infinite carriers and mathematical total functions. `EvalF` accepts
only a validated finite profile and returns one of:

```text
Success(value, DynDeps, StateReads, AccessTrace, usage)
Reject(input defect)
Inconclusive(resource or supported-domain exhaustion)
InternalFailure(checker defect; never evidence)
```

Quantity Overflow and Underflow variants are ordinary successful values.
Resource exhaustion is not semantic rejection and cannot be promoted to a
positive result.

### Stability is one-sided and selector-complete

If a second well-formed context agrees with a first context on the first
evaluation's `DynDeps`, it must produce the same value and exact same
`DynDeps`. Selector equality follows from the dependency agreement; it is not
an extra premise. The theorem does not claim every accessed input is
semantically influential.

### Branch witness and dispatch are different

The denotational `BranchStep(a,b,...)` checks the named branch. A finite
dispatcher that discovers `b` evaluates every guard in canonical order and
has a separate, larger trace. Concrete implementations must refine the access
behavior they actually use.

## Consequences

- PARAM and EVENT influence can no longer disappear inside an empty state-read
  set.
- PRE and POST cannot alias after phase erasure.
- Dynamic-key evaluation cannot justify an access that already happened.
- Selected-path dependency precision is preserved without weakening the
  conservative preauthorization option.
- Finite traces and resource limits remain evidence machinery rather than the
  denotation of the language.
- The machine package now needs exact rule tables for all 42 constructors,
  carrier/equality/enumeration, finite profile decoding, result taxonomy, and
  trace projection, followed by hostile parity tests and proof statements.
- F0 acceptance, F1/F2/F3, K0/G0, candidate IR, TLA+, Linux behavior, and every
  protection claim remain unauthorized.
