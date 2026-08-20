# DL-F0-5 Part 02: Morphisms and Proof Boundary

Status: local normative design draft; package incomplete

Date: 2026-08-10

This part imports Parts 00 and 01.

## F05-02-001: Complete Signature Fragments

A `SignatureFragment` is a fresh qualified module containing any subset of the
complete declaration namespaces from Part 00, plus:

```text
imports with exact source identities
ClassPremise contributions
Init contribution
complete bodies for newly declared actions
optional fresh-channel observer contributions for imported branches
claim contributions
```

Fresh declarations cannot shadow or mutate imported declarations. Combining
fragments rejects import cycles, duplicate qualified names, incompatible
premises, conflicting state-product declaration identity, and multiple bodies
for one new action. `DeclarationOwner` means qualified namespace provenance and
freshness only; it is not runtime read, write, emit, or execution authority.
Those permissions are explicit F1/F2 state and predicates.

Initialization contributions of active fragments combine by conjunction. New
actions enter Step only when their declaring module is active, because the
composed model's body domain equals its complete `ActiveActionName` set.
An observer contribution may add only a fresh owned event channel computed from
the imported transition's pre-state, explicit parameter, post-state, and
base event bundle. It cannot change imported state, label, enabledness, or
existing channels without a separate refinement morphism.

Source artifact, source semantics, and linked occurrence identities are
distinct:

```text
H_K(x) = SHA256(
  ASCII("DL-F0-5|ID|" + K + "|v1|DL-F0-CJSON-1|") ||
  DL-F0-CJSON-1(x))

ModelArtifactId = H_MODEL_ARTIFACT(exact canonical source MODEL)
ModuleArtifactId = H_MODULE_ARTIFACT(ModuleName, exact Module node)
SourceDeclarationArtifactId = H_SOURCE_DECLARATION_ARTIFACT(
  ModuleName, exact declaration node)
BodyOriginId = H_BODY_ORIGIN(ModuleArtifactId, exact body locator)
SourceActionArtifactId = H_SOURCE_ACTION_ARTIFACT(
  ModuleArtifactId, ActionQName)
SourceActionSemanticId = H(
  ActionQName,
  canonical action body,
  canonical direct referenced declaration semantic edges,
  every channel declared by the owner module,
  static SemanticContextDigest)
SourceBranchId = (SourceActionSemanticId, BranchLocalName)
LinkedActionSemanticId = H(
  SourceActionSemanticId,
  StateCarrierDigest,
  EventCompletionPlanDigest,
  ObserverPlanDigest)
LinkedActionId = H(ModelArtifactId, LinkedActionSemanticId)
```

Runtime labels are interpreted under one exact `ModelArtifactId`; a source
action name or reusable semantic ID alone never identifies elaborated event
behavior. `SourceActionArtifactId` preserves exact source provenance, while
`SourceActionSemanticId` permits proof/cache reuse across changes to unrelated
claims or actions. Adding an owner-module channel is not unrelated because it
changes the action's complete emit/default contract and therefore changes the
semantic ID. The semantic-reference graph and its acyclicity remain machine
completion obligations; prose hashing is not an identity implementation.

All digest values are carried in typed objects containing kind, version,
algorithm, and digest; a bare 64-digit value is not interchangeable across ID
kinds. Direct semantic-reference edges are canonical records keyed by edge
role and qualified name. A flat, caller-supplied transitive digest bag is not a
valid preimage.

The machine rule table fixes every currently issued ID's domain field, ordered
preimage fields, invalidation scope, and binder policy. Construction identities
include source binder spelling. No `SourceActionSemanticId` or linked final
semantic identity may be issued until an alpha-equivalence policy and its
normalizer/checker are separately frozen; construction spelling sensitivity is
not silently promoted into semantic identity.

`SourceActionSemanticId` excludes non-owner channels, dormant bodies, model
artifact identity, and observer plans. Linker-generated typed-None coordinates
belong to `EventCompletionPlanDigest`; all dependency state products belong to
`StateCarrierDigest`. Consequently either carrier change affects
`LinkedActionSemanticId`, while an unrelated dormant claim-body edit does not.
`LinkedActionId` is deliberately the exact occurrence identity and does change
with `ModelArtifactId`.

`LinkedModelSemanticId` eventually binds the dependency signature, all constant
constraints, carriers, active premises, canonical init, active actions, active
claims, complete semantic context, and link rules. It excludes dormant
premise/init/action/claim bodies. Until those preimages, the semantic reference
Merkle DAG, and `SemanticContextDigest` are machine-checked, the implementation
may emit only explicitly named construction digests, not any of these final
semantic IDs.

## F05-02-002: Event-Channel Composition

For disjoint channel sets `C0` and `Cnew`, bundle extension is the product:

```text
extend_event(ev0,evnew)|C0   = ev0
extend_event(ev0,evnew)|Cnew = evnew
```

Projection `project_C0` drops fresh channels. Empty channels compose as
identity. Disjoint channel product is associative and commutative up to the
canonical qualified-name isomorphism. An observer cannot suppress a base event
or make a base action disabled.

The linker first computes `BaseBundle` using source-action owned emits plus the
typed-None defaults from Part 01. Every observer term is then evaluated
independently against the same `(PARAM,PRE,POST,BaseBundle)` tuple. It cannot read
another observer's output. Observer results are assembled as one canonical map
keyed by fresh qualified channel; duplicate `(SourceBranchId,channel)` entries
reject. There is no observer application order and no last-wins rule. This
simultaneous product is the only meaning of the linked `ObserverPlan`.

Stutter in an extended model may carry only None on every channel. A transition
that produces an observer event while leaving base state unchanged is therefore
an explicit non-stutter observer action, not a disguised stutter.

## F05-02-003: Pure Extension Morphism

A pure extension morphism `E : M1 -> M0` contains:

```text
injective qualified-signature embedding iSigma from M0 into M1
interpretation restriction rI from an M1 interpretation to M0
total state projection piS : State1 -> State0
label projection relation piL
event-channel projection piE
for each M1 step, a nonempty finite M0 path witness piStep
```

It satisfies:

```text
WF preservation:
  InstanceWF(M1,I1) implies InstanceWF(M0,rI(I1))

Init preservation:
  Init1(s1) implies Init0(piS(s1))

Step simulation:
  Step1(s1,l1,e1,s1') implies piStep is a nonempty finite M0 run segment from
  piS(s1) to piS(s1'), with piL/piE preserving every imported occurrence and
  channel; an internal extension step maps to exactly one M0 stutter

Execution projection:
  concatenating the nonempty finite witnesses for an infinite M1 execution
  yields an infinite M0 execution

Footprint preservation:
  every projected imported read/write is contained in the corresponding M0
  footprint; fresh-state/channel effects are explicitly erased and cannot
  alias imported locations
```

Nonempty finite path witnesses prevent infinitely many extension steps from
collapsing to a finite base prefix. A synchronized extension action may map to
more than one base step, but its witness fixes their order and does not claim a
single base linearization point.

Identity morphisms use identity maps and one-step witnesses. Composition
composes signature/interpretation/state/event maps and concatenates finite path
witnesses. The package must prove identity and associativity up to qualified
isomorphism, and commuting projection for independently composed fresh
fragments.

## F05-02-004: Conservativity and Assumption Refinement

Pure-extension projection is a sound forward refinement only. It may remove
base behaviors. The word conservative additionally requires backward lifting:

```text
every M0 initial state has at least one related M1 initial state
every finite M0 run has an M1 finite-run lift with matching projection
every infinite M0 execution has an M1 infinite-execution lift, or an accepted
finite-to-infinite compactness theorem derives it
```

If a module restricts executions using a rely, fairness condition, timing
premise, connectivity premise, or provider assumption, it is an
assumption-qualified refinement. The exact removed executions and premise are
part of the claim and no unconditional conservativity claim is allowed.

## F05-02-005: Platform Refinement Relation

Physical/concrete refinement is relational rather than forced to be functional.
A `PlatformRefinement C -> A` contains:

```text
Rstate subseteq ConcreteState x AbstractState
Rinit relating every claimed concrete initialization to an InstanceWF abstract one
Rlabel and Robs relating concrete occurrences/observations to abstract ones
Rfoot relating physical accesses to abstract read/write locations
finite-path simulation witnesses
whole-execution projection rule
```

For every claimed concrete step or bounded atomic region from `c` to `c'` and
every related abstract `a`, there exists a nonempty finite abstract path from
`a` to some `a'` with `Rstate(c',a')`, matching labels/observations and preserving
the footprint relation. Internal concrete steps map to an explicit abstract
stutter. Interrupt, DMA, weak-memory, speculation, and asynchronous physical
steps cannot be dropped unless F2 proves they are unobservable and
authority-irrelevant under the exact claim.

Every infinite claimed concrete execution projects to an infinite abstract
execution; progress claims additionally require divergence/anti-Zeno premises.
Unknown concrete state, access, or observation either receives a relation,
is proved unreachable by the lower enforcement contract, or blocks the claim.

Identity and relational composition are defined conventionally. Composition
must preserve init, finite-path simulation, whole-execution projection, and
footprints. Unlike PureExtension, PlatformRefinement may be many-to-many.

## F05-02-006: F0 Metatheory Theorem Set

The exact F0 package must bind formal statements for at least:

```text
F05-THM-001 declaration resolution and sort dependency well-foundedness
F05-THM-002 carrier nonemptiness
F05-THM-003 type uniqueness
F05-THM-004 substitution preserves sort and provenance
F05-THM-005 evaluation totality
F05-THM-006 phase noninterference
F05-THM-007 one-sided dynamic-dependency stability
F05-THM-008 Put/Patch frame soundness
F05-THM-009 invocation/guard partition implies branch determinism
F05-THM-010 label inversion and event-bundle well-typedness
F05-THM-011 finite-run stutter extension
F05-THM-012 inductive obligations imply BaseAlways
F05-THM-013 finite executable evaluator refines set-theoretic ObsD/Eval/DynDeps
F05-THM-014 PureExtension identity and composition
F05-THM-015 conservative backward lifting implies base-trace equivalence
F05-THM-016 PlatformRefinement identity and composition
F05-THM-017 source counterexample replay soundness
F05-THM-018 scope widening rule soundness for each admitted rule
F05-THM-019 DynDeps source-kind and MayDeps containment
F05-THM-020 StateReads is the phase-preserving state projection of DynDeps
F05-THM-021 finite AccessTrace projection equals DynDeps for complete roots
```

The theorem statement includes all quantifiers, premises, model/interpretation
well-formedness conditions, and exact conclusion. A theorem ID or prose title is
not a proof.

## F05-02-007: Machine Grammar and Rule Identity

Before F0 local acceptance, the package contains digest-bound machine artifacts:

```text
primitive wire types and root entry points
core declaration, checked Term wrapper, and TermNode grammar
per-collection sequence/set/map policy and canonical serialization
duplicate/unknown-field and noncanonical-input rejection
syntax-directed type/provenance rule table
recursive ObsD/Eval/DynDeps/StateReads/Delta/MayDeps rule table
finite AccessTrace order and projection rule table
sort-directed carrier/equality/enumeration, CarrierRefs, and GroundValue rules
model/action/Put/Patch/event/run/claim constructors
CoreSyntaxWF, InstanceWF, and ClaimPackageWF rule tables
PureExtension and PlatformRefinement witness schemas
formal theorem statements
proof/certificate grammar
checker input/output and reject taxonomy
```

The machine grammar is a representation of Parts 00-02 and cannot add a
semantic operator absent here. Conversely, every normative constructor and
judgment has exactly one machine representation. A parity ledger and hostile
mutations check both directions.

The type/provenance table must enumerate every recursive `Term` operand by an
exact grammar-derived selector, including terms nested in support collections
such as `values[*].value` and `branches[*].body`. Provenance is the set union of
those exact operand derivations, explicitly named context-variable sources, and
explicitly introduced PRE/POST/EVENT sources. A phrase such as "immediate
children" without selectors is not a machine rule. Binder entries separately
fix variable field, scope operand, sort source, provenance source, and freshness
domain. Typing and result rule IDs are closed dispatch keys whose checker
handlers must be independently exhaustive; they are not proof merely because
their spelling matches a table row.

Finite profile/state/event/label/transition/run objects are replay evidence for
one named finite interpretation. They do not replace the set-theoretic carriers
or quantify over only enumerable executions. `StateReads` is only the PRE/POST
projection of `DynDeps`; neither is a capability grant. A concrete evaluator
must refine either preauthorized `MayDeps` or a trace that mediates each input
access before it occurs. Infinite interpretations, executions, PureExtension
maps, and PlatformRefinement relations remain denotational objects represented
by checked theorem/proof terms rather than lossy finite JSON arrays.

`SemanticContextDigest` binds the normative source manifest, language surface,
canonicalization identity, all semantic rule tables, and formal theorem
statements. Model, finite-profile, finite-run, scope, and proof-statement objects
must bind it before F0 acceptance; a content hash without this context cannot be
interpreted authoritatively. `ValidationContextDigest` separately binds checker
protocol and closed result taxonomy, checker or proof-kernel identities, pinned
soundness statements, operator hard envelope and supervisor policy, versioned
support matrix, and externally owned acceptance policy/profile. Separating them
permits independent checkers to validate one semantic context without changing
the model's denotation. Neither digest may be candidate-self-interpreting. Their
machine fields and context manifests remain an explicit construction gap until
the underlying rule tables are frozen.

Before issuing a validation context, one immutable `RuleBundleSnapshot` captures
an exact allowlist of grammar, meta-schema, all normative parts, static/evaluation
rules, generated schemas and manifest, and implementation artifacts. Every file
is regular, non-symlink, size bounded, read from a stable descriptor, and covered
by an all-files double capture. Generated bytes are reproduced from captured
inputs and compared exactly. Grammar raw/canonical/surface identities, static
raw/canonical identities, normative domain and hashes, and evaluation bindings
must agree transitively across every captured contract.

Validation uses only captured bytes and one immutable module/class graph after
snapshot issuance. A path-based reload, mixed bundle generation, `sys.modules`
substitution, or implementation-source drift is `InternalFailure`. A content
digest identifies bytes but is not a signature, authority grant, reviewer
attestation, or proof that imported code was compiled from those bytes. Positive
evidence therefore additionally binds the actually executed artifact identity
and external supervisor result. The worker cannot read filesystem or network
state after launch, and `Success` commits only after a bounded result frame is
validated and that worker exits normally.

An executable evaluation request additionally binds one immutable
`CheckedTermOccurrenceId`. Its preimage contains the exact linked-model identity,
owner/body/branch/path occurrence, term bytes, result sort, root context,
`Gamma`, `Delta`, and static provenance `R`. Raw caller-supplied term, Gamma,
Delta, or R values cannot substitute for this occurrence in positive evidence.
The request also binds exact source/linked/occurrence byte identities, finite
profile, parameter and PRE/POST/EVENT presence wrappers and values, requester
resource profile, and `ValidationContextDigest`. A separate result identity
binds request identity, validation context, effective operator policy, outcome
tag, and canonical result body so a request content hash cannot be mistaken for
an execution receipt.

## F05-02-008: Proof Objects and Small Checker Contract

Every positive F0 theorem result binds:

```text
normative source-set digest
machine-grammar/rule digest
SemanticContextDigest
theorem statement and scope digest
all premise and dependency digests
proof-object kind and bytes
checker identity and independently pinned soundness statement
ValidationContextDigest
deterministic checker result
```

Permitted proof objects may include fully explicit derivations checked by a
small kernel, proof-assistant kernel terms under a pinned kernel/metatheory, or
claim-specific certificates with a separately proved checker soundness theorem.
Uncertified SAT/UNSAT, differential backend agreement, tests, mutation survival,
TLC completion, or an evaluator's own assertion is not a positive proof object.

Counterexamples use a smaller path: strict decode/type check, reconstruct the
finite interpretation/run, evaluate Init/Step/claim from normative rules, and
confirm the violation. Counterexample replay may refute; it never supplies a
positive general theorem.

## F05-02-009: Trust Order

F0 fixes Parts 00-02, the machine grammar, inference rules, theorem statements,
proof/certificate formats, checker interface, and soundness evidence before F3
creates a review campaign or gate policy.

F3 may pin exact accepted checker/proof-kernel identities, external roles,
thresholds, checkpoints, and allowed transition. It may reject F0 or require
successor bytes. It cannot retroactively choose a different grammar, theorem,
certificate meaning, or self-authenticating checker and apply that meaning to
old evidence.

Reference evaluators, materializers, translators, SMT solvers, TLA+/TLC, Alloy,
scenario generators, mutation runners, and report generators remain untrusted
producers. Their output receives only the credit supported by an independently
checked source-level proof/certificate or counterexample replay.

## F05-02-010: Package Authorization Boundary

The three v5 Markdown parts are an incomplete local design. F0 local acceptance
remains false until the machine grammar, rules, theorem statements,
proof/certificate grammar, checker boundary, parity validation, semantic
mutations, and fresh exact hostile review exist and pass without unresolved
blockers.

Even F0 local acceptance would authorize only F1 design. It would not supply F1
claim semantics, F2 platform/threat refinement, F3 external authority, K0/G0,
K1 candidate architecture, semantic freeze, TLA+ translation, model support,
Linux behavior, Monitor implementation, or protection/performance/cost/scale/
cluster/deployment claims.
