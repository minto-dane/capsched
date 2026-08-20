# Dynamic Residency F0 v4 Hostile Rejection and v5 Closure

## Status

The exact first `DL-F0-Core-4` draft is locally rejected. Its exact identity
checker and 21 structural mutations pass, but four independent read-only local
reviews found semantic counterexamples. This is negative design evidence, not
external K0 authority. All promotion states remain false.

The machine-readable disposition is
`dynamic-residency-f0-v4-hostile-rejection-v5-closure-v1.json`.

## Exact Target and Mechanical Result

```text
f0-core-calculus-v4.md
  177ae3e0a860b808fd49a5bd93d03adc74d5b56f9950d1d257fa63e8fb6c7d9c
  24915 bytes

f0-review-target-v4.json
  a2b56d0a2d1f80ac1d45ad4e6612d6005bf7191781d3a7cb5dbf084e6daaef12

identity/shape checker
  06f3871b9f4744f5d811700e5d13060f5e1e1063f2ab168b93144ac36a43aa6c
  output 058c0612362f9e20a789bf25b4b8e0f802e208b9a8504b0b5650c36c26559199

mutation runner
  723ac1af83a7db89cc346d532837e8029d772982f228cca23a0e66fd029fd67d
  21/21 expected structural/authority rejections
  output eff57e1bd77d3e2d9bd5aba670ca48ab1d07da2d8b9ed9ab05bf31356c56d09c
```

Both outputs reproduced twice. They establish byte identity, predecessor
retention, closed heading identity, and false promotion fields. They do not
establish semantics or metatheory.

## Review Provenance

| Axis | Session | Verdict |
| --- | --- | --- |
| type theory and metatheory | `019fe9ef-b8e2-72e0-a807-923b3e9ecdf1` | `LOCAL_ADVISORY_REJECT` |
| action, frame, and security | `019fe9ef-d8d8-7990-bd03-ecc2b1aed28b` | `LOCAL_ADVISORY_REJECT` |
| safety, nonvacuity, scope, backend | `019fe9f0-041f-7141-b872-e518f5f5e576` | `LOCAL_ADVISORY_REJECT` |
| extension interface and expressiveness | `019fe9f0-244b-7a82-83c2-e59032f5cda0` | `LOCAL_ADVISORY_REJECT` |

All sessions confirmed the exact source hash. None is an F3 external review.

## Retained Results

The dependent `Location`, `Cell`, and `Label` carriers are the correct remedy
for heterogeneous state/action types. A finite ordered fold of point writes
does establish `Diff(s,s') subseteq WriteSet` at its declared cell granularity,
including aliasing, repeated writes, and same-value writes. Assumption-free
`Exec`, explicit stutter, finite/general scope separation, and treating backend
agreement as non-proof also remain valid directions.

## Normalized Blockers

### F0V4-B01: Event bodies cannot be constructed

`EventSigma` is not a data sort, but the closed grammar has neither an event
constructor nor exhaustive event matching. Generic Variant construction cannot
produce an `EventTerm`, so every branch's required `Emit` is undefined.

v5 adds channel-indexed event construction and exhaustive channel/tag matching
with recursive typing, provenance, and denotation.

### F0V4-B02: Action parameter and state predicate scopes are inconsistent

The unindexed current parameter has action-dependent type `Pa`. `PreTerm`
admits PARAM, yet `BaseAlways`, `InitSafe`, and reachability evaluate without a
parameter. A Boolean current parameter can therefore type as an invariant with
no denotation.

v5 binds `p:Pa` explicitly in an action-scoped context and defines closed
`StatePred` with provenance restricted to PRE only.

### F0V4-B03: Evaluation and macro closure are incomplete

Normative clauses use incompatible evaluator arities and undefined `rho[p]`.
Bodies are not explicitly closed, macro definitions have no call/dependency
grammar, polymorphic constructors lack sort annotations, and anonymous
`ArithResult` is outside the named grammar.

v5 uses fully expanded core terms, one recursive evaluator signature, qualified
constructors, and explicit result sorts. Surface macros are separately expanded
and checked before core typing.

### F0V4-B04: Events do not invert to occurrences

Two actions or parameters may emit the same event. Only the full semantic label
contains `(a,b,p)`. v5 replaces event inversion with `LabelInversion` and
`EventBundleWellTyped`. Request correlation is an F1 protocol obligation.

### F0V4-B05: Read instrumentation is underdefined

Value erasure permits an instrumenter that returns no reads. An ordered trace
has no denotation for quantification over an infinite unordered carrier.

v5 defines recursive set-valued denotational footprints and footprint
stability. Ordered traces are limited to a separately defined finite executable
fragment with canonical order.

### F0V4-B06: Declared actions can disappear

Candidate-owned `RequiredActionSet` can omit `Compromise`, or include it with an
always-false guard. v5 requires `dom(ActionBodies)=ActionName`; Step ranges over
all declared actions. F3 owns declaration-basis completeness. Invocation
totality and compromised-step input-enabledness are claim/platform obligations.

### F0V4-B07: Nested maps hide authority granularity

A product keyed by One whose value is an entire authority map turns a global
rewrite into one coarse location. v5 defines security state normal form and
forbids hiding authority-relevant mutable maps beneath an untracked cell unless
recursive leaf locations and whole-value write expansion are proved.

### F0V4-B08: Dynamic finite atomic updates are missing

Fixed point-write lists cannot model an atomic crash cut or teardown over a
runtime finite set without collapsing state granularity. v5 adds typed finite
`Patch(q,D,values)` with simultaneous exact write set, explicit composition with
point writes, and frame/read rules.

### F0V4-B09: Model and claim classes can be empty

Inconsistent constant constraints can make `Admissible(M)` empty, so universal
claims are vacuous. Model-class premises are referenced but absent. v5 separates
`CoreSyntaxWF`, `InstanceWF`, and `ClaimPackageWF`, makes typed premises explicit,
and requires witnesses for admissible and finite quantified classes.

### F0V4-B10: Nonvacuity is not bound to the claim instance

A dangerous branch reachable in one profile can be absent from the exact
profile receiving a positive claim. `Exec_A` can be empty. Mutation entries can
be unrelated or alter the claim itself.

v5 binds reachability, assumption feasibility, and discriminating mutation to
the exact claim, scope, and interpretation/profile. A mutant preserves claim and
premises, changes a designated semantic site, remains admitted, and yields a
source-replayable reachable counterexample.

### F0V4-B11: Finite runs and evidence bounds are confused

A finite prefix is defined through an already infinite execution, making the
extension theorem circular. Executable-fragment bounds can underapproximate an
exact instance. v5 defines finite runs directly, proves stutter extension, and
keeps search bounds only in evidence metadata.

### F0V4-B12: Extension and platform maps are not morphisms

One-way projection can suppress every base action and cannot represent one
extended step refining a finite base path or a relational concrete state map.
Modules cannot contribute a full signature, initialization, or disjoint event
instrumentation.

v5 defines separate `PureExtension` and `PlatformRefinement` interfaces with
signature import, initialization, finite-path simulation, state/label/event or
observation relations, execution projection, footprint preservation, identity,
and composition. Backward lifting is additionally required before claiming true
conservativity.

### F0V4-B13: One event cannot compose independent modules

Timing, durability, receipt, and lane modules need disjoint observations on one
transition. v5 emits a finite typed event bundle keyed by fresh channel names;
stutter is empty and module erasure projects away owned channels.

### F0V4-B14: Proof identity is deferred too late

F0 lists theorem names while F3 is allowed to choose future grammar, proof
objects, and TCB. That lets later policy redefine what was proved. ADR-0020
requires F0 to fix the grammar, inference rules, theorem statements,
certificate format, checker interface, and soundness boundary. F3 can
authenticate/adopt those exact bytes only.

## v5 Work Order

```text
1. fully expanded core grammar and qualified declarations
2. recursive typing, provenance, event and footprint semantics
3. total action closure, point/Patch updates, security state normal form
4. CoreSyntaxWF, InstanceWF, ClaimPackageWF and inhabited scope judgments
5. FiniteRun, Exec, base safety and claim-bound nonvacuity
6. PureExtension and PlatformRefinement morphisms
7. exact metatheory statements, proof objects, and small checker boundary
8. exact identity target, structural mutants, then fresh hostile review
```

F1 remains blocked until that exact F0 package survives review. No result here
authorizes K0, candidate IR, TLA+, Linux/Monitor implementation, or any model or
production claim.
