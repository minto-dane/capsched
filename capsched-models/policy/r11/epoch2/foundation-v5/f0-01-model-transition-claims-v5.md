# DL-F0-5 Part 01: Models, Transitions, and Base Claims

Status: local normative design draft; package incomplete

Date: 2026-08-10

This part imports every definition from Part 00.

## F05-01-001: Event Channels and Bundles

Every EventChannel `c` declares one qualified Variant payload sort
`EventPayload(c)`. `Channels(M)` is the set of channels declared by every
dependency module in `Sigma`, whether its bodies are active or dormant. For a
finite signature:

```text
EventBundleI = product_c Option([[EventPayload(c)]]I)
EmptyEventI  = the bundle with None at every channel
```

A bundle carries at most one typed event per channel per transition. Independent
modules use fresh disjoint channels; a module requiring multiple simultaneous
records declares multiple channels or a payload Record/Variant containing the
finite batch. Channel projection is structural and never parses an opaque byte
string.

For an action declared in module `m`, `OwnedChannels(a)` is the complete set of
EventChannels declared by `m` itself. Each branch explicitly declares exactly
one typed emit term for every channel in `OwnedChannels(a)`.
For every model channel outside that set, linking supplies the unique typed
`None(EventPayload(c))`; this default is semantic elaboration, not a candidate
choice. Thus independently linked sibling modules do not acquire cyclic imports
merely to enumerate one another's channels. A later fresh-channel observer node
may replace only such a fresh default under the Part-02 extension rules; that
node and its checks remain a separate completion obligation.

Every elaborated coordinate records whether it came from a source-declared
emit or from the linker rule. A source action may explicitly emit a well-typed
`None`; that value remains source-declared and must never be relabeled as a
generated default. Conversely, generated defaults have a structured linker
origin and never receive a fabricated source-body origin.

Full transition labels are semantic occurrence witnesses. Event bundles are
semantic observations available to relation claims. Neither is automatically a
public, tenant, timing, or attacker observation; F1/F2 defines those observation
functions explicitly.

## F05-01-002: Complete Model Object

A core model is:

```text
M = (
  Sigma,
  ClassPremiseBodies,
  InitBody,
  ActionBodies,
  BaseClaimBodies
)
```

`InitBody` is the canonical conjunction of the active module contributions from
Part 00 and is one closed StatePred. `ClassPremiseBodies` contains exactly the
named premises of active modules. Every action declared by an active module has
exactly one body and no inactive or undeclared body enters the linked model:

```text
dom(ActionBodies) = ActiveActionName
```

There is no candidate-owned required-action subset inside `ActiveActionName`.
F3 later checks that the active set contains the complete mandatory
threat/action basis, but every active action is unconditionally part of F0 Step.

The linked construction has a separate exact `source_binding` and semantic
projection. Dormant body ASTs occur in neither `ClassPremiseBodies`,
`InitBody`, `ActionBodies`, nor `BaseClaimBodies`; their exact module and body
origin identities may remain in `source_binding`. All dependency declaration
headers, constant constraints, arithmetic bindings, state products, and event
channels remain in `Sigma`. This split prevents both dormant-body activation
and accidental loss of carrier/frame coordinates.

The construction and its local cross-check are functions of immutable source
bytes and fixed rule identity, never of a previously checked mutable module or
activation map. A local second implementation that reparses those bytes may
establish only cross-implementation reconstruction. It is not external review,
does not complete `CoreSyntaxWF`, and does not authorize transition or claim
semantics. Both parsers reject over-depth, over-size, excessive-node,
overlong-integer, duplicate-key, non-ASCII, and noncanonical inputs with a
stable rejection or explicit inconclusive result rather than a host exception.

## F05-01-003: Action and Branch Bodies

Each action `a` declares:

```text
ParamVar(a)        one explicit fresh variable name
ParamSort(a)       one exact data sort
Invoke(a)          one ActionPred
Branches(a)        a finite nonempty set
```

Each branch `b` declares:

```text
Guard(a,b)          one ActionPred
Updates(a,b)        a finite ordered list of Update
DeclaredEmit(a,b,c) one ActionTerm<Option(EventPayload(c))>
                     for every c in OwnedChannels(a)
Emit(a,b,c)         DeclaredEmit(a,b,c), or typed None for every other model c
```

Every body is closed under exactly
`Gamma={ParamVar(a):(ParamSort(a),{PARAM})}`. The binder is part of the action
declaration; there is no reserved implicit spelling and no body may capture or
shadow it. There are no actor, authority, writer, trusted-role, or evidence
semantics hidden in F0 metadata. Later modules introduce such state and
predicates through ordinary typed declarations and prove their projection.

For every InstanceWF interpretation, invocation and guards satisfy:

```text
Eval(Invoke(a),s,p) iff exactly one b in Branches(a) has Eval(Guard(a,b),s,p)
```

Thus an invoked operation has exactly one outcome branch and a non-invoked
operation has none. Nondeterministic environment, provider, or adversary choices
are explicit fields of `p`; they are not hidden evaluator choices. F2/F3 may
require `Invoke` input-enabledness or a candidate-non-narrowing inclusion
theorem for compromise actions.

The denotational relation and an executable dispatcher are distinct. A
`BranchWitness(a,b,s,p)` evaluates `Invoke(a)` and only the named `Guard(a,b)`;
under `InstanceWF`, a true witness uniquely identifies `b`. A finite
`DispatchF(a,s,p)` evaluates `Invoke(a)` and every guard in canonical branch
order without short circuit, then returns exactly one of `NotInvoked`,
`Selected(b)`, or `PartitionViolation`. `DispatchF` is a diagnostic/generation
operation and does not add all-guard reads to `BranchStep`. A replay of a label
`Do(a,b,p)` uses the named branch witness. Any concrete dispatcher that reads
more guards exposes those accesses in its own operational trace and must account
for them in platform refinement.

At least one `Emit(a,b,c)` evaluates to Some for every selected branch. Equal
event payloads may be emitted by different actions, branches, or parameters.
Only the transition label provides occurrence inversion.

## F05-01-004: Point and Finite Patch Updates

Update syntax is:

```text
PutUpdate(q, key, value)
  key   : ActionTerm<KeySort(q)>
  value : ActionTerm<ValueSort(q)>

PatchUpdate(q, domain, values)
  domain : ActionTerm<FinSet(KeySort(q))>
  values : ActionTerm<TotalMap(KeySort(q),ValueSort(q))>
```

For pre-state `s` and parameter `p`, every key/domain/value expression in every
update is evaluated against the original `(s,p)`. A Put has one write location.
A Patch has the exact finite write set:

```text
PatchLocations(q,D) = {(q,k) | k in D}
```

Within one Patch all cells change simultaneously to `values(k)`. The ordered
update list is then folded left to right; a later update wins on overlapping
locations. Since every expression reads the original pre-state, list order only
resolves writes and never creates an implicit intermediate-state read phase.
This is an intentional finite pre-state-computable atomic language, not general
sequential program composition.

Define `WriteTrace(a,b,s,p)` as the finite ordered sequence of each Put location
and each Patch's finite location set in update-list order. A finite profile may
canonically order keys for execution, but the normative write footprint is:

```text
Writes(a,b,s,p) = union of every Put/Patch location
```

The selected branch `DynDeps` is the union of Part-00 dependencies for Invoke,
the named Guard, all update expressions, and every Emit expression. Its
`StateReads`/`Reads` footprint is the phase-preserving state projection. The
separate `DispatchF` dependency set additionally includes every guard. Neither
dynamic set is a pre-issued authority grant; concrete access must use a
conservative `MayDeps(M,I,Gamma,Delta,t)` authorization or per-access mediation.

## F05-01-005: Generated Branch Relation and Frame

Let `Apply(a,b,s,p)` be the deterministic ordered fold from F05-01-004 and
`Bundle(a,b,s,p)` the product of every evaluated Emit channel. The generated
branch relation is:

```text
BranchStep(M,I,a,b,s,p,s',ev) iff
  Eval(Invoke(a),s,p) = true
  and Eval(Guard(a,b),s,p) = true
  and s' = Apply(a,b,s,p)
  and ev = Bundle(a,b,s,p)
  and ev != EmptyEventI
```

No arbitrary candidate relation is conjoined or substituted. Its frame is a
derived theorem:

```text
Diff(s,s') subseteq Writes(a,b,s,p)
```

Operational access permission cannot be inferred from `Diff`; same-value Put
and Patch cells remain writes. A semantic or concrete support computation may
prove a narrower actual difference, but may not enlarge the generated write
footprint.

For fixed `(M,I,a,s,p)`, at most one branch, post-state, and event bundle exist.
This follows from guard partitioning and total term evaluation.

## F05-01-006: Labels, Stutter, and Complete Step

The label carrier is:

```text
LabelI = StutterLabel(One) +
         dependent sum_a,b ({a} x {b} x [[ParamSort(a)]]I)
```

`Do(a,b,p)` is well typed only for the matching action, branch, and parameter
carrier. Define:

```text
Stutter(s,label,ev,s') iff
  s'=s and label=StutterLabel(one) and ev=EmptyEventI

Step(M,I,s,label,ev,s') iff
  Stutter(s,label,ev,s')
  or exists a in ActiveActionName, b in Branches(a), p in [[ParamSort(a)]]I:
       label=Do(a,b,p) and BranchStep(M,I,a,b,s,p,s',ev)
```

Every active action is in Step. Every non-stutter label uniquely determines
`a,b,p`; events need only satisfy bundle/channel/payload typing. Define
EnabledBranch/Action by existential post-state and bundle in the generated
relation, and Taken by exact label equality.

## F05-01-007: Three Well-Formedness Levels

`CoreSyntaxWF(M)` is interpretation independent and requires:

```text
finite qualified declaration and import closure
acyclic sort definitions and CellSort state values
fully expanded core terms
exact linked body domain equal to ActiveActionName
syntax-directed type/provenance derivation for every premise/body/claim
closed initial Gamma/rho/Delta for Init/claims and exact coherent p slot for actions
well-typed Put/Patch and event-channel expressions
all referenced names resolved exactly once
```

`InstanceWF(M,I)` requires:

```text
CoreSyntaxWF(M)
I is a valid interpretation of Sigma
I satisfies every ClassPremiseBody
constant constraints are satisfiable in I
Invoke/Guard exact-one equivalence for every action, state, parameter
InitNonempty(M,I)
```

`ClaimPackageWF(M,Scope,C,P)` requires:

```text
C is in dom(BaseClaimBodies), hence is declared by an active module, closed,
  and well typed; a dormant dependency claim is ineligible
Scope denotes an inhabited set of InstanceWF interpretations
P binds all nonvacuity, coverage, mutation, and proof obligations to C and Scope
every positive exact-instance result binds one exact I in Scope
```

F3 conformance is not part of `CoreSyntaxWF`; it later decides whether exact
claim-package obligations satisfy external policy. F3 cannot change these three
judgments.

## F05-01-008: Initialization, Finite Runs, and Infinite Executions

Using the one evaluator from Part 00:

```text
Init(M,I,s) iff Eval(InitBody,{PRE=s}) = true
InitNonempty(M,I) iff exists s: Init(M,I,s)
```

A finite run of length `n` is defined independently:

```text
s0,label0,ev0,s1,...,label(n-1),ev(n-1),sn
```

with `Init(s0)` and Step at every index below `n`. A zero-step run is legal for
every initial state. An infinite execution has the analogous Step condition at
every natural index. `Exec(M,I)` is the set of all infinite executions, without
fairness or environment assumptions.

Every finite run extends to an infinite execution by repeating explicit
stutter from its final state. Therefore:

```text
Reach(M,I) = states occurring in finite runs
            = states occurring in Exec(M,I)
```

Later assumption sets define subsets `Exec_A={tau in Exec | A(tau)}` for their
own claim only. They do not modify Init, Step, Reach, or base safety.

For one named finite interpretation, the machine replay form contains a
complete canonical finite state, typed event bundle, dependent Stutter/Do
label, transition, and finite run. Every state enumerates exactly one typed cell
for every state-product key; every event bundle enumerates exactly one Option
payload for every channel; adjacent transitions agree on their shared state.
The replay checker reconstructs Init and Step from the normative rules.

Before replay, `FiniteInterpretationWireWF` requires exactly one nonempty
carrier for every Atom, one natural value for every Limit, and one sort-directed
GroundValue for every Constant. A `VALUE_TOTALMAP` has exactly one semantic key
for every value in its finite key carrier; raw JSON equality is never used in
place of nominal, recursive carrier equality. All dependency constant
constraints hold. This establishes only a finite signature interpretation. It
does not establish active ClassPremises, Invoke/Guard partitioning,
InitNonempty, `InstanceWF`, or any claim.

These finite wire carriers do not serialize or redefine arbitrary infinite
states, total function spaces, or executions. General denotational objects are
quantified in checked theorem/proof systems. Failure to enumerate one is not
evidence that it is empty.

## F05-01-009: Exact Base Safety Semantics

A base invariant `Inv` is a closed StatePred. For one InstanceWF pair:

```text
M,I |= BaseAlways(Inv) iff
  for every tau in Exec(M,I), every state s in tau:
    Eval(Inv,{PRE=s}) = true
```

`InstanceWF` already includes InitNonempty, and stutter makes Exec inhabited.
The semantic definition is not a solver exit or proof-node name.

Sufficient inductive obligations are:

```text
InitSafe:
  forall s. Init(s) implies Inv(s)

BranchPreserves(a,b):
  forall s,p,s',ev.
    Inv(s) and BranchStep(a,b,s,p,s',ev) implies Inv(s')
```

All simultaneous invariants are conjoined before generating one InitSafe and
one preservation obligation for every branch of every active action. Stutter
preservation follows from state equality. Fairness cannot remove a safety
counterexample.

## F05-01-010: Interpretation and Claim Scopes

```text
Admissible(M) = {I | InstanceWF(M,I)}
Finite(I)     iff every Atom carrier in I is finite
FiniteClass(M)= {I in Admissible(M) | Finite(I)}
```

Claim scopes are:

```text
Exact(I)       one named InstanceWF interpretation identity
FiniteClass    every I in FiniteClass(M)
Admissible     every I in Admissible(M)
```

`ClaimPackageWF` requires an explicit witness that the selected scope is
inhabited. FiniteClass additionally requires one admitted finite witness. The
claim judgments quantify only over their denoted sets.

A finite execution profile is one machine-replayable realization of a named
exact interpretation `I_F`: every Atom carrier, Limit, Constant, and
ClassPremise fact is fixed and the profile binds the exact model digest. It is
not the only possible representation of Exact scope. A general exact
interpretation may instead be bound inside an admitted checked proof object.
Every exact-scope reference must resolve uniquely through the claim package's
interpretation registry. Search depth, state limits, symmetry settings,
timeout, and solver resources are not members of `I_F`; they are evidence
metadata.

A source-replayed counterexample in `I_F` refutes every claim scope that
contains that InstanceWF interpretation and uses the same premises. A checked
exhaustive positive result supports only `Exact(I_F)`. FiniteClass or Admissible
scope requires a separately checked induction, refinement, symmetry/cutoff, or
other sound widening proof.

## F05-01-011: Claim-Bound Nonvacuity

The obligation package `P` is indexed by `(claim_id, scope_id)` and, for every
bounded positive result, `interpretation_id`. It may require:

```text
BranchReachable(a,b,I)
AntecedentReachable(predicate,I)
EnabledWitness(a,b,I)
AssumedExecNonempty(assumption,I)
DistinguishingInitialPair(I) for later relational claims
```

For an exact bounded safety result, every policy-mandatory success, deny,
stale, exhaustion, fault, crash, recovery, compromise, and adversary branch is
reachable in that same `I`, or a named static impossibility is part of the exact
claim and externally accepted. Reachability in another profile is no substitute.

For a general proof, universal branch preservation still covers unreachable
branches. F3 additionally requires at least one in-scope witness per mandatory
branch and forbids a premise chosen only to make the branch impossible.

Every assumption-qualified later claim proves `Exec_A` nonempty in each exact
instance receiving positive evidence. Base safety has no assumption filter.

## F05-01-012: Discriminating Semantic Mutations

A claim mutation record binds:

```text
exact source and scope digest
unchanged claim formula and class premises
one designated semantic site and typed mutation operator
mutated model that remains CoreSyntaxWF and has an InstanceWF witness in scope
expected violated claim ID
source-level reachable counterexample and replay result
```

Changing the claim to false/true, emptying Init or the interpretation class,
removing an action, making a mandatory branch unreachable, altering an
assumption, or mutating an unrelated site is not a discriminating mutant. A
mutation runner is an untrusted producer; a small replay checker validates the
typed mutation identity and counterexample under the normative semantics.

These obligations prevent literal-true invariants, cross-profile coverage, and
claim-editing mutants from supplying positive credit.
