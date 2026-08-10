# DL-F0-5 Part 00: Core Language and Denotation

Status: local normative design draft; package incomplete

Date: 2026-08-10

## F05-00-001: Qualified Finite Declarations

Every module has one `ModuleName`. Every non-module declaration identifier is
the pair `(module_name, local_name)`, where the first component resolves to one
declared module. The declaration namespaces are:

```text
Module, Atom, Enum, Unit, Limit, Record, Variant, Constant,
StateProduct, EventChannel, Action, Branch, Premise, Claim
```

Namespaces are pairwise disjoint. Branch names are scoped by Action; record
fields by Record; enum tags by Enum; variant tags by Variant. Constructor use is
fully qualified. Declaration sets, field/tag/branch lists, and imports are
finite. Imports are explicit and acyclic. Every reference resolves exactly
once. Duplicate, shadowed, ambiguous, unresolved, cyclic, or unknown names
reject.

The machine `Model` embeds a canonical map of modules and names exactly one
root. The import graph is a finite DAG, every imported target is embedded, and
the reflexive transitive reachability closure of the root is exactly the
embedded module set. An unreachable embedded module rejects. Imports do not
implicitly re-export names:

```text
DirectImports(m) = the module names listed by m
Visible(m)       = {m} union DirectImports(m)
```

A qualified reference `[owner,local]` in module `m` resolves only when `owner`
is in `Visible(m)`. Transitive imports contribute to link closure and identity,
not ambient name visibility. A future re-export feature requires a new explicit
core node; there is no wildcard, alias, unqualified lookup, or implicit export
in DL-F0-5.

Import is a name-resolution and dependency-identity relation only. It is not a
RunCap, read grant, write grant, emit grant, trust endorsement, or runtime
authority. Core syntax describes a mathematical transition even when it names
an imported state product; operational permission and security authority must
be represented by ordinary model state/predicates and discharged by F1/F2/F3
claims. No protection claim may infer permission from `Visible`.

Each import stores the lower-case digest:

```text
SHA256(ASCII("DL-F0-5|MODULE|DL-F0-CJSON-1|") ||
       DL-F0-CJSON-1(target Module node))
```

This is a domain-separated content digest, not by itself a semantic-package or
checker identity. An authoritative evidence package separately binds the
language, normative parts, rule tables, checker protocol, and checker artifact.
The same immutable canonical model bytes feed wire, link, and semantic checks;
re-reading a mutable path between stages is forbidden. The production boundary
is a `WireValidatedModelSnapshot` containing those bytes, their length and
SHA-256, the exact Model root kind, and the wire schema/surface identities. It
does not contain a mutable decoded object. Static checking, link construction,
and any cross-implementation reconstruction each parse the snapshot bytes
again under their own resource envelope. A checker constructed directly from
a caller-owned map is a hostile/unit-test interface and cannot issue production
wire-validation evidence.

The normative core has no named macro, opaque function, callback, backend term,
or implicit coercion. Surface notation is accepted only after a separate
expander emits fully expanded core terms and the core checker validates them.

The machine wire uses ASCII identifiers, represents a module as `ModuleName`,
and represents a qualified declaration identifier as the exact pair
`[module_name, local_name]`. Primitive wire forms, including
nonnegative natural numbers, lower-case SHA-256 values, and closed metadata
enums, are fixed by the machine grammar. A wire spelling is never a new
semantic carrier: the checker decodes it into the carrier declared here or
rejects it.

The model also carries a canonical nonempty `ActiveModules` set. It is a subset
of the embedded root closure and contains the root. Dependency and activation
are distinct:

```text
DependencyModules = Reach*(root)
ActiveModules     subseteq DependencyModules, root in ActiveModules
```

`ActiveModules` is deliberately not required to be import-closed. Activation
is explicit, not inherited through a dependency edge. An active module may use
an inactive dependency's signature, but that edge cannot activate the
dependency's premise, init, action, or claim bodies. Any future behavioral
activation dependency must be a separate checked declaration, not an inference
from `imports`.

Linking forms the abstract model deterministically. `Sigma` is the disjoint
qualified union of all declarations in `DependencyModules`, so dormant library
artifacts remain type-checkable and name-resolvable. Named class premises,
actions, and base claims enter the linked model only from `ActiveModules`.
`InitBody` is the conjunction of active `init_contribution` terms in ascending
canonical `ModuleName` order; the one-active-module case is that contribution
itself. Every embedded body is still statically checked before activation.
Changing activation changes the model identity; a dependency cannot silently
activate code merely because it was imported. No root-only, first-wins, or host
iteration-order rule is permitted.

The machine linker must project declaration headers before selecting bodies.
It must not copy a source `DECL_ACTION`, `DECL_PREMISE`, or
`DECL_CLAIM_BASE_ALWAYS` node wholesale into `Sigma`, because those wire nodes
contain both header and body. Action headers retain the qualified name,
parameter sort, and canonical branch-name domain; premise and claim headers
retain only their qualified name and declaration kind. Their executable or
assumption bodies are stored only in the corresponding active body map. The
exact typed source-module, declaration, action, and body-origin identities live
in a separate `source_binding` construction trace and are not an alternate body
lookup path.

Construction exposes two distinct digests. `ModelArtifactId` binds the exact
canonical source `MODEL`, including dormant bodies, import pins, and
`ActiveModules`. A construction-only linked semantic projection digest binds
the projected `Sigma`, carriers, constraints, and active bodies, but is not a
`LinkedModelSemanticId` and authorizes no proof reuse until the complete
semantic context and reference graph are bound.

Every issued construction identity has a domain-separated, machine-declared
preimage and invalidation scope:

```text
ModelArtifactId
  H_MODEL_ARTIFACT(canonical source MODEL)

ModuleArtifactId(m)
  H_MODULE_ARTIFACT(owner ModuleName, exact Module node)

SourceDeclarationArtifactId(d)
  H_SOURCE_DECLARATION_ARTIFACT(owner ModuleName, exact declaration node)

BodyOriginId(o)
  H_BODY_ORIGIN(ModuleArtifactId(owner(o)), exact body locator)

SourceActionArtifactId(a)
  H_SOURCE_ACTION_ARTIFACT(ModuleArtifactId(owner(a)), ActionQName)
```

`SourceDeclarationArtifactId` is component-scoped and remains stable when an
unrelated declaration in the same module changes. `ModuleArtifactId`,
`BodyOriginId`, and `SourceActionArtifactId` are owner-module-occurrence scoped
and therefore all invalidate on any owner Module node change. This asymmetry is
intentional and appears in the machine preimage table; a verifier cannot infer
one scope from another. Binder spelling is identity-significant for every v5
source and construction ID. The alpha-normalization policy for future semantic
IDs is unresolved, so those final IDs remain forbidden rather than silently
inheriting the construction policy.

All state-product and event-channel declarations in `Sigma`, including those
owned by inactive dependency modules, remain in the state and event carrier.
Inactive state products therefore still have typed cells, and inactive
channels still have a bundle coordinate that defaults to typed `None`; only
body activation changes. Typed constant constraints from every dependency are
signature-interpretation constraints and always apply. Named ClassPremise
bodies are distinct model assumptions and enter `ClassPremiseBodies` only from
active modules. This distinction prevents activation from changing the meaning
of a referenced constant while preventing a dormant module from silently
adding behavioral assumptions.

## F05-00-002: Sort Grammar and Security State Normal Form

Core data sorts are:

```text
tau ::=
    Bool | One | Atom(a) | Enum(e) | Qty(u,l)
  | Record(r) | Variant(v) | Option(tau)
  | FinSet(tau) | TotalMap(key_tau,value_tau)
```

Every Record has at least one uniquely named field. Every Enum and Variant has
at least one uniquely named tag. The structural dependency graph is finite and
acyclic. Every sort is an equality sort. Map keys must be equality sorts.

`KeySort` and `CellSort` are each the least class containing Bool, One, Atom,
Enum, and Qty and closed under Record, Variant, and Option when every member is
in the same class. Both exclude FinSet and TotalMap. Every state product `q`
declares:

```text
KeySort(q)   one KeySort
ValueSort(q) one CellSort
```

Thus neither a mutable cell nor its identity hides an unbounded collection.

This is the F0 security state normal form. Mutable collections are represented
as state products whose policy-visible keys identify the independently framed
cells. A later refinement may use a coarser implementation object only after
proving recursive leaf-location and whole-object-access preservation; it cannot
silently replace many authority cells with one abstract location.

FinSet and TotalMap remain legal in parameters, constants, event payloads, and
intermediate terms. They cannot be nested inside mutable state-product values.

## F05-00-003: Interpretations and Inhabited Carriers

Every Atom declaration carries one exact carrier class:

```text
FINITE       every admitted interpretation gives this Atom a finite carrier
UNRESTRICTED no finiteness premise is introduced by the declaration
```

`UNRESTRICTED` does not mean infinite. A finite profile may instantiate such an
Atom with a finite carrier; a general admissible interpretation may instantiate
it with a finite or infinite carrier.

For a declaration-closed signature `Sigma`, an interpretation `I` assigns:

```text
I(a)  a nonempty set for every Atom a
I(l)  a natural number for every Limit l
I(c)  a member of the declared sort for every Constant c
```

and satisfies the explicit typed constant constraints. Other carriers are:

```text
[[Bool]]I          = {false,true}
[[One]]I           = {one}
[[Atom(a)]]I       = I(a)
[[Enum(e)]]I       = its declared nonempty closed tag set
[[Qty(u,l)]]I      = {(u,n) | n in Nat and n <= I(l)}
[[Record(r)]]I     = named Cartesian product of field carriers
[[Variant(v)]]I    = disjoint tagged sum of payload carriers
[[Option(tau)]]I   = disjoint None(One) + Some([[tau]]I)
[[FinSet(tau)]]I   = all finite subsets of [[tau]]I
[[TotalMap(k,v)]]I = all total functions [[k]]I -> [[v]]I
```

Units are nominal identities. Equality and order never cross sorts. Quantity
operations require the exact same unit and limit declarations. Infinite Atom
carriers and full function spaces have set-theoretic meaning; no executable
enumeration is promised outside a validated finite instance.

## F05-00-004: Typed Class Premises

A model may declare finite `ClassPremise` formulas over interpretation facts:

```text
constant equality or inequality within one sort
limit equality, inequality, and natural ordering
Atom carrier cardinality equality or lower bound
Boolean combination of the above
```

The closed atomic premise `LimitGeNat(l,n)` means `I(l) >= n`. It is an ordinary
explicit model assumption, not a term-typing witness. Term occurrences never
generate, infer, or silently add a limit premise. Contradictory or
over-restrictive premise sets remain visible model assumptions and are later
subject to scope inhabitation, nonvacuity, and F3 anti-narrowing checks.

Their satisfaction `I |= premise` is fixed by ordinary equality, natural order,
and set cardinality. Atom carrier finiteness is supplied by the declaration's
carrier class, not by treating `not finite` as an unrestricted premise.
Cardinality equality implies finiteness. Premises cannot read model state,
transitions, claims, solver results, digests, files, or evaluator callbacks.
Premises are named assumptions and never filter executions inside one
interpretation.

## F05-00-005: State, Locations, and Cells

For state products `q`:

```text
StateI    = product_q TotalMap([[KeySort(q)]]I, [[ValueSort(q)]]I)
LocationI = dependent sum_q ({q} x [[KeySort(q)]]I)
CellI     = dependent sum_q,k ({q} x {k} x [[ValueSort(q)]]I)
```

`Read(s,(q,k))=(q,k,s[q](k))`. `Put(s,(q,k),v)` changes exactly that location
when `v in [[ValueSort(q)]]I`. `Diff(s,s')` is the set of tagged locations whose
same-carrier values differ. Cross-product values are never compared after
erasing the product tag.

Absence, vacancy, tombstone, stale identity, exhaustion, and lookup failure are
explicit CellSort variants. Host-language absence and null have no meaning.

## F05-00-006: Provenance and Closed Judgments

Dynamic provenance is a subset of:

```text
Source = {PARAM, PRE, POST, EVENT}
```

A context maps a variable to `(tau,R)`. Variable lookup retains `R`; let binding
and substitution never reset it. The judgment is:

```text
Sigma ; Gamma |- t : tau ! R
```

Static provenance unions every operand and every syntactic branch. It never
uses a runtime selector to hide a forbidden source in an untaken branch.
Dynamic evaluation and `Reads` evaluate only the selected branch. Required
views are:

```text
StaticTerm(tau) = tau ! {}
StateTerm(tau)  = tau ! R, R subseteq {PRE}
StatePred       = Bool ! R, R subseteq {PRE}
ActionTerm(tau) = tau ! R, R subseteq {PARAM,PRE}
ActionPred      = Bool ! R, R subseteq {PARAM,PRE}
RelTerm(tau)    = tau ! R, R subseteq {PARAM,PRE,POST,EVENT}
RelPred         = Bool ! R, R subseteq {PARAM,PRE,POST,EVENT}
```

`Init`, base invariants, state antecedents, and state observations are closed
`StatePred` terms checked under empty `Gamma`. An action `a` checks every body
under exactly `Gamma={p:(ParamSort(a),{PARAM})}`. There is no unindexed
`current_parameter` primitive. Relation obligations additionally bind the
exact pre-state, post-state, event bundle, and explicit action parameter.

The current source `Model` grammar has no relation-body or observer-body entry
point. Consequently `RelTerm`, `RelPred`, `post_get`, and `event_get` are
reserved semantic constructors for the pending claim/morphism/observer AST.
They may be type-checked by a component test, but they are unreachable in an
accepted source body: placing POST or EVENT provenance in Init, a base claim,
or an action body rejects at the phase boundary. No relation claim is available
until a machine node binds the exact action identity, parameter, PRE, POST, and
EVENT context.

## F05-00-007: Fully Expanded Term Constructors

Every machine term is the checked wrapper:

```text
Term = TYPED_TERM(result_sort, node: TermNode)
```

`TermNode` is the following closed constructor union. Every recursive term
position contains another complete `Term`, never a raw node. The result sort is
not trusted annotation: the checker derives the unique sort of the node and
requires exact equality with `result_sort`.

The closed core `TermNode` AST contains only:

```text
Bool, One, qualified Enum, Qty zero, and checked Nat-to-Qty construction
qualified constant and variable
let
qualified Record construction and field projection
qualified Variant injection and exhaustive Variant match
typed Option None/Some and exhaustive Option match
typed FinSet empty/insert/remove/member/subset/union/difference
TotalMap get/set
Boolean and/or/not/implies/iff
same-sort equality
same-Qty lt/le/gt/ge
checked Qty add/subtract
typed if-then-else
forall/exists over QuantSort
pre_get(q,key)
post_get(q,key)
event_get(channel)
```

The wrapper makes the result sort explicit for every constructor. Constructor-
specific sort fields still identify operands such as typed None or empty set.
`QuantSort` is identical to KeySort and therefore excludes FinSet and TotalMap.

`event_get(channel)` has result `Option(EventPayload(channel))` and provenance
EVENT. Event payload is a qualified Variant sort. Construction and matching use
the ordinary fully qualified Variant and Option forms; no unconstructible
Event meta-sort exists.

All fields/tags are exact and exhaustive, map/set operands have identical
sorts, binders are fresh, and conditional/match branches share one result sort.
Atom values have no source literals. They enter through constants, variables,
parameters, or state reads.

There is no unchecked nonzero Qty literal. The two constructors are:

```text
Unit(u)    Limit(l)
-----------------------------------------
Sigma;Gamma |- QtyZero(u,l) : Qty(u,l) ! {}

Unit(u)    Limit(l)    ArithResult[Qty(u,l)] = v
------------------------------------------------
Sigma;Gamma |- QtyChecked(u,l,n:Nat) : Variant(v) ! {}
```

`QtyZero` is in every `Qty(u,l)` carrier because every interpreted limit is a
natural number. `QtyChecked` evaluates to `Ok((u,n))` when `n <= I(l)` and to
`Overflow(one)` otherwise; it never yields `Underflow`. Thus every valid
interpretation has a total result and a term occurrence cannot narrow the
admissible interpretation class as a side effect of typing. A model may still
branch on the explicit result, which remains observable behavior subject to
nonvacuity and F3 checks.

Checked arithmetic has exactly one declared nominal result binding for every
Qty sort used by checked construction, addition, or subtraction:

```text
ArithResult[Qty(u,l)] = Variant(Ok:Qty(u,l), Overflow:One, Underflow:One)
```

The binding names an ordinary declared Variant and the checker verifies this
exact tag/payload shape. The `Term` result annotation for checked construction,
addition, or subtraction must name that Variant; a structurally similar unbound
Variant is not accepted.

Addition produces Ok exactly when the natural sum is at most `I(l)`;
subtraction produces Ok exactly when the subtrahend is no larger. Every other
case produces the corresponding explicit tag. Elimination is exhaustive.

There is no String, host integer, float, null, partial lookup/projection,
unchecked arithmetic, arbitrary choice, recursion, digest, I/O, backend source,
or opaque call.

## F05-00-008: One Recursive Evaluation and Observation Relation

For a derivation `Sigma;Gamma |- t:tau!R`, define one simultaneous dynamic
observation:

```text
ObsD(M,I,Gamma,rho,Inputs_R,t) = (v,D)
  where v in [[tau]]I and D subseteq InputDepI

Eval(...)    = first(ObsD(...))
DynDeps(...) = second(ObsD(...))
```

Dynamic input dependencies are a disjoint tagged sum:

```text
InputDepI = ParamDep(ParamSlot)
          + PreDep(q,k)
          + PostDep(q,k)
          + EventDep(c)
```

`ParamSlot` is supplied by the checked body occurrence and is not inferred from
a variable spelling. A root occurrence has exactly one of two contexts:

```text
ClosedRoot
ActionParamRoot(ActionOccurrenceId, ParamVar, ParamSort, ParamSlot)
```

`ClosedRoot` has empty `Gamma` and empty `rho`. `ActionParamRoot` has exactly
`Gamma={ParamVar:(ParamSort,{PARAM})}` and one coherent initial binding
`rho(ParamVar)=(p,{ParamDep(ParamSlot)})`, where `p` belongs to the declared
carrier. No PRE, POST, EVENT, arbitrary external, or caller-described value may
enter an initial `rho` binding. Such values are obtained only by evaluating the
corresponding primitive term. This exact rule is `RootEnvWF`.

`Inputs_R` contains exactly the PRE, POST, and EVENT views named by `R`; PARAM
is represented exactly once by the coherent action-parameter binding. Let and
match binders inherit the dynamic dependencies of the value that they bind.
Quantifier binders have the empty dependency set. Model bodies are closed under
their exact initial `Gamma` after surface expansion.

`ObsD` is well-founded structural recursion. It computes a value and selected-
path dependencies together; `DynDeps` is not reconstructed from the value or
from a later trace. This makes dynamic key and selector dependencies part of
the same judgment that selected them.

Evaluation is structural: literals/constants/variables select their declared
values; records and variants use mathematical tuples/disjoint sums; matches are
exhaustive; maps are total functions; sets use finite-set operations; Boolean
operators are classical and strict; equality is same-carrier equality;
conditionals evaluate the condition then the selected branch; quantifiers use
set-theoretic quantification; state reads use PRE or POST input; event reads use
the channel component of the EVENT input.

Constants, limits, Atom carriers, arithmetic-result bindings, and declaration
shapes are interpretation dependencies bound by the semantic context. They are
recorded separately as a typed `InterpretationRef` sum:

```text
DeclarationRef(DeclarationKind,QName)
AtomCarrierRef(AtomName)
LimitValueRef(LimitName)
ConstantValueRef(ConstantName)
ArithmeticBindingRef(UnitName,LimitName,ResultVariantName)
```

`CarrierRefs_I(S)` is structural: Bool and One add none; Atom adds its
declaration and carrier; Enum adds its declaration; Qty adds Unit/Limit
declarations and the Limit value; Record and Variant add their declaration and
recurse through every field/payload sort; Option and FinSet recurse through the
element sort; TotalMap recurses through key and value sorts. Dynamic
`InterpretationRefs` follows the same selected evaluation path as `ObsD` and
adds every declaration/value/binding actually consulted. In particular,
quantification adds `CarrierRefs_I(S)`, quantity construction/arithmetic adds
the relevant carrier and arithmetic-binding refs, state/event reads add their
declaration refs, and nominal record/variant/enum/constant construction adds its
nominal refs. These refs are neither runtime `InputDep` values nor authority.

No normative clause may use an abbreviated evaluator arity. Abbreviations in
later documents explicitly bind `M,I,Gamma,rho,Inputs_R` before use.

## F05-00-009: Dynamic Dependencies, State Reads, and Access Bounds

`DynDeps` is a set, not an ordered execution. Its recursion is part of `ObsD`:

```text
literals/constants                                    {}
variable                                              dependencies of its rho binding
ordinary strict constructor/operator                  union operand DynDeps
let                                                   DynDeps(bound) union DynDeps(body)
if                                                    DynDeps(cond) union DynDeps(selected branch)
variant/option match                                  DynDeps(scrutinee) union DynDeps(selected branch)
pre_get(q,key)                                        DynDeps(key) union {PreDep(q,Eval(key))}
post_get(q,key)                                       DynDeps(key) union {PostDep(q,Eval(key))}
forall/exists x:S.body                                union over x in [[S]]I of DynDeps(body[x])
event_get(c)                                          {EventDep(c)}
```

The selected body in let, match, and quantifier rules is evaluated in the
correspondingly extended environment. Boolean operators and quantifiers do not
short circuit. Only if and exhaustive matches select one syntactic branch.

The phase-preserving state projection is:

```text
StateReads(t) = {PreDep(q,k),PostDep(q,k) in DynDeps(t)}
Reads(t)      = StateReads(t)
```

`Reads` is retained as this exact compatibility alias. It is not a complete
PARAM/EVENT dependency set and is not an authority grant. PRE and POST are
never erased into a bare `(q,k)` pair. An action body is statically PRE-only,
so its state-read projection contains only `PreDep` values.

`Delta` is an input-independent origin-bound environment distinct from dynamic
`rho`. At a closed root it is empty; at an action root it maps only `ParamVar`
to `{ParamDep(ParamSlot)}`. A let binder receives `MayDeps(bound)`, a
variant/option payload binder receives `MayDeps(scrutinee)`, and a quantifier
binder receives the empty set. `Delta` never contains caller-supplied dynamic
origin coordinates.

`MayDeps(M,I,Gamma,Delta,t)` is the dynamic-input-independent structural upper
bound. It includes every syntactic branch, propagates these `Delta` bounds, and
replaces each `pre_get(q,key)` or `post_get(q,key)` by the complete corresponding
key carrier for `q`. It may be infinite. Required containment is:

```text
RootEnvWF(Gamma,rho,Delta)
DynDeps(M,I,Gamma,rho,Inputs_R,t) subseteq MayDeps(M,I,Gamma,Delta,t)
sourceKinds(DynDeps(...)) subseteq R
```

An implementation cannot first perform unmediated reads and then treat the
resulting `DynDeps` as authorization. A concrete refinement must either
authorize the conservative `MayDeps` bound before evaluation or mediate each
primitive PARAM/PRE/POST/EVENT access before it occurs. This F0 dependency
semantics supplies observations and proof obligations, not a hidden capability
check.

For a validated finite interpretation, `EvalF` additionally emits a canonical
ordered `AccessTrace`. The trace records primitive input accesses in the fixed
strict evaluation order; derived binder lookup does not replay the access that
created its value. Its set projection for a complete well-formed root request
equals `DynDeps`. Resource accounting and `InterpretationRefs` are separate
trace coordinates. Infinite interpretations may yield infinite dependency
sets; this is denotationally well defined and makes no ordered-execution claim.

An executable request is one immutable canonical snapshot. It binds the source
model, linked-model construction, source-derived `CheckedTermOccurrenceId`,
finite interpretation profile, exact parameter/PRE/POST/EVENT presence and
values, requester resource profile, and `ValidationContextDigest`. The term,
`Gamma`, `Delta`, provenance `R`, and input-presence domain are derived from the
checked occurrence. Supplying any of them independently is not a positive
evaluation request.

The requester resource profile is a semantic exploration bound and is part of
the request identity. A separately owned operator hard envelope protects every
implementation phase, including ingress, parse, wire validation, static
checking, link expansion, occurrence construction, profile/input decode,
evaluation, result construction, and serialization. For shared evaluation
coordinates:

```text
effectiveLimit(c) = min(requestedLimit(c), operatorCeiling(c))
```

The operator envelope and external process-supervisor policy are bound by the
validation context and cannot be enlarged by the requester. Pre-allocation
products such as action-branch by global-event-channel expansion are charged
with saturating arithmetic before allocation. CPU, wall-clock, memory, process,
file-descriptor, and output-frame limits require an external supervisor; an
in-process counter is not evidence for those coordinates.

The executable result taxonomy is disjoint and has unique issuance conditions:

```text
Success(value,DynDeps,StateReads,AccessTrace,usage,requested/effective profile,
        validation context, bounded canonical result, normal worker exit)
Reject(deterministic malformed or semantically ill-formed finite input only)
InconclusiveResource(named requester/operator meter or supervisor quota only)
InconclusiveUnsupported(well-formed checkpoint followed by a versioned
                        support-matrix miss only)
InternalFailure(any other exception, crash, module drift, corrupt frame, or
                unattributed host failure; never evidence)
```

Qty Overflow and Underflow are ordinary successful Variant values. Resource or
support exhaustion is never semantic rejection or positive evidence. A raw
`MemoryError`, `RecursionError`, `TypeError`, assertion failure, unknown signal,
or partial result is `InternalFailure`, not resource evidence. Supervisor-issued
resource results require an identified quota and worker identity. Every finite
result binds requested and effective resource profiles, operator-envelope and
validation-context identities, and a separate execution-result identity;
per-request carrier memoization cannot leak usage or success across requests.

Required one-sided dependency stability is:

```text
let ObsD(C0,t)=(v0,D0). If another well-formed context C1 for the same M, I,
checked root occurrence, Gamma, RootEnvWF origin map, derivation, and term agrees
with C0 on every input named by D0, then ObsD(C1,t)=(v0,D0).
```

Selector equality is a conclusion of this theorem, not an extra premise. Cells
or non-state inputs outside `D0` may differ. The theorem does not require a
dependency to be semantically influential: strict evaluation can read a value
whose change leaves the result unchanged.

The finite operational trace requires finite carriers, canonical enumeration,
and explicit strict evaluation order. It cannot replace or narrow `ObsD`,
`DynDeps`, or `MayDeps`.

## F05-00-010: Phase and Substitution Metatheory Interface

The core package must prove or supply independently checkable certificates for:

```text
type uniqueness
weakening for fresh variables
capture-avoiding substitution preserves sort and provenance
evaluation totality for well-typed terms
phase noninterference under well-typed related environments
one-sided dynamic-dependency stability without a selector premise
dynamic-source and MayDeps containment
StateReads/Reads is exactly the phase-preserving state projection of DynDeps
finite AccessTrace set projection equals DynDeps
finite executable evaluation refines set-theoretic Eval and DynDeps
```

There is no arbitrary root `rho` to hold syntactically equal. `RootEnvWF` ties
the sole possible root value to its exact checked action parameter slot; all
other bindings are generated by the structural evaluation rules. The related-
environment judgment preserves the checked occurrence, static source set,
`Delta`, exact dynamic origin, and binder construction rule, and permits input
variation only outside the dependency set observed by the theorem. Part 02
fixes theorem identities and the proof/checker boundary.
