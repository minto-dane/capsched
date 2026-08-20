# DL-F0-Core-4 Typed Transition Calculus

Status: local F0 design candidate; exact hostile review pending

Date: 2026-08-10

This document defines only the common typed transition calculus required by
ADR-0019 F0. It does not define progress, real time, durability, distribution,
composition, noninterference, robust integrity, a physical-machine refinement,
an external K0 policy, or any DomainLease candidate architecture.

The mathematical clauses are normative. Parsers, evaluators, translators,
solvers, and model checkers implement or consume these clauses; none defines
their meaning.

## F0-DEN-001: Syntactic Universes and Namespace Separation

A signature has finite syntactic declarations:

```text
Sigma = (
  AtomName, EnumName, UnitName, LimitName,
  RecordName, VariantName, ConstantName, DefinitionName,
  StateProductName, EventTag, ActionName, BranchName,
  declarations
)
```

Every listed identifier namespace is pairwise disjoint. `BranchName` is scoped
by `ActionName`; every other namespace is global. There is no opaque `Function`
namespace. Reusable definitions are finite, typed, capture-avoiding macros and
have no independently supplied interpretation.

All declaration sets and every record field, variant tag, action branch, and
update list are finite. Names are unique in their scope. Declaration references
must resolve exactly once. The sort-dependency graph is finite and acyclic.
Unresolved, duplicate, cyclic, shadowed, or unknown declarations reject.

The sort grammar is:

```text
tau ::=
    Bool
  | One
  | Atom(alpha)
  | Enum(epsilon)
  | Qty(unit, limit)
  | Record(record_name)
  | Variant(variant_name)
  | Option(tau)
  | FinSet(tau)
  | TotalMap(tau_key, tau_value)
```

`EventSigma` is a distinguished derived meta-sort whose carrier is defined in
F0-DEN-004. It may appear only as the result of an event constructor, as the
current-event input of a `RelPred`, or under exhaustive event matching. It
cannot occur in Atom/Enum/record/variant definitions, constants, state-product
types, action parameter types, sets, maps, or event payloads; this prevents a
recursive Event carrier.

Each named record has at least one uniquely named field. Each named variant and
enum has at least one uniquely named tag. `One` represents a zero-information
payload; empty records and empty variants are forbidden. A map key sort must be
an equality sort. Every F0 sort is an equality sort under the mathematical
equality of its carrier.

Constants declare one exact sort. A signature may declare equality and
distinctness constraints among constants of the same sort. Cross-sort equality
or aliasing constraints are ill typed. Atom values have no source literal;
they enter terms only through typed constants, variables, state reads, or
action parameters.

## F0-DEN-002: Interpretations and Sort Carriers

An interpretation `I` of a well-formed signature assigns:

```text
I(alpha)  a nonempty set to each AtomName alpha
I(limit)  a natural number to each LimitName
I(c)      a member of the declared carrier of each ConstantName c
```

and satisfies every declared same-sort equality/distinctness constraint.
Units are nominal identities, not numbers or singleton values. Enums, records,
variants, and structural sorts have the fixed meanings below:

```text
[[Bool]]I                     = {false, true}
[[One]]I                      = {one}
[[Atom(alpha)]]I              = I(alpha)
[[Enum(epsilon)]]I            = the declared nonempty closed tag set
[[Qty(u,l)]]I                 = {(u,n) | n in Nat and n <= I(l)}
[[Record(r)]]I                = product of its named field carriers
[[Variant(v)]]I               = disjoint sum of its named tag/payload carriers
[[Option(tau)]]I              = [[Variant(None:One, Some:tau)]]I
[[FinSet(tau)]]I              = all finite subsets of [[tau]]I
[[TotalMap(k,v)]]I            = all total functions [[k]]I -> [[v]]I
```

All carriers are nonempty. Two quantities may be compared or combined only
when unit and limit declarations are identical. A unit or clock conversion is
not an F0 primitive; a later module must represent it as an explicit typed
relation and evidence-bearing transition.

The mathematical interpretation may contain infinite Atom carriers and full
function spaces. F0 promises executable enumeration only for a separately
validated finite profile and executable fragment. Set-theoretic totality is not
a claim that an infinite carrier can be enumerated by a program.

## F0-DEN-003: State, Dependent Locations, and Cells

Each state product `q` declares one key sort `Kq` and one value sort `Vq`.
There is at least one state product.

```text
StateI    = product over q of [[TotalMap(Kq,Vq)]]I
LocationI = dependent sum over q of ({q} x [[Kq]]I)
CellI     = dependent sum over q,k of ({q} x {k} x [[Vq]]I)
```

For `loc=(q,k)`, `Read(s,loc)` is the tagged cell `(q,k,s[q](k))`. `Write`
is defined only when the supplied value belongs to `[[Vq]]I`:

```text
Write(s,(q,k),v)[q](x) = v       when x=k
Write(s,(q,k),v)[q](x) = s[q](x) when x!=k
Write(s,(q,k),v)[r]    = s[r]    when r!=q
```

`Diff(s,s')` is the set of locations `(q,k)` whose same-carrier values differ.
Comparisons never erase the `q` tag. Absence, vacancy, tombstone, lookup
failure, and exhaustion are explicit members of `Vq`, normally using a Variant
or Option. A missing host map entry or `null` has no semantic meaning.

## F0-DEN-004: Events, Branches, and Dependent Labels

The event carrier is one closed disjoint sum:

```text
EventI = StutterEvent(One) +
         disjoint sum over declared EventTag payload carriers
```

`StutterEvent` is reserved and cannot be declared or emitted by a non-stutter
branch.

Each action `a` declares a parameter sort `Pa` and a finite nonempty set of
branches `Branches(a)`. Branch identity is observable in the transition label:

```text
LabelI = StutterLabel(One) +
         dependent sum over a of
           dependent sum over b in Branches(a) of
             ({a} x {b} x [[Pa]]I)
```

Thus parameters from different actions are never placed in one untagged
carrier. `Do(a,b,p)` is well typed only for `b in Branches(a)` and
`p in [[Pa]]I`.

An action declaration also identifies its actor-role expression, authority-role
expression, writer-role expression, and later-module metadata slots. Those
fields have no ambient authority semantics in F0. A later policy must bind and
interpret them; their mere names prove nothing.

## F0-DEN-005: Provenance-Indexed Typing Contexts

The primitive provenance set is:

```text
Phase = {PARAM, PRE, POST, EVENT}
```

A typing environment maps every variable to `(tau,R)`, where
`R subseteq Phase` records every dynamic source on which its value may depend.
Constants and closed literals have `R={}`. A variable lookup preserves the
stored `R`; binding never resets provenance.

The principal judgment is:

```text
Sigma; Gamma |- t : Term<tau,R>
```

Composition takes the union of all operand and branch provenance. Named views
are restrictions, not new term kinds:

```text
StaticTerm<tau> = Term<tau,{}>
ParamTerm<tau>  = Term<tau,R> where R subseteq {PARAM}
PreTerm<tau>    = Term<tau,R> where R subseteq {PARAM,PRE}
PostTerm<tau>   = Term<tau,R> where R subseteq {PARAM,POST}
InitPred        = Term<Bool,R> where R subseteq {PRE}
GuardPred       = Term<Bool,R> where R subseteq {PARAM,PRE}
UpdateTerm<tau> = Term<tau,R> where R subseteq {PARAM,PRE}
EventTerm       = Term<EventSigma,R> where R subseteq {PARAM,PRE}
RelPred         = Term<Bool,R> where R subseteq Phase
```

F0 action bodies use `GuardPred`, `UpdateTerm`, and `EventTerm`; they do not use
free-form `RelPred`. `RelPred` exists only for specifications and proof
obligations over an already constructed transition. It cannot define or widen
an action's operational writes.

An environment cannot bind a name already in scope. Macro expansion and let
substitution are capture avoiding and preserve the bound term's sort and
provenance. This prevents a post-state or event value from being laundered
through an apparently static variable.

## F0-DEN-006: Closed Term Syntax

The F0 expression grammar contains exactly:

```text
boolean, One, enum, and Qty literals
typed constant and variable reference
let binding
record construction and named field projection
variant construction and exhaustive variant matching
Option construction through its Variant definition
total-map lookup and functional update
finite-set empty, insert, remove, member, subset, union, difference
Boolean and, or, not, implies, iff
same-sort equality
same-Qty-sort lt, le, gt, ge
checked Qty add and subtract
total conditional
forall and exists over QuantSort
pre-state product read
post-state product read
current action parameter
current event
```

`QuantSort` is the least class containing Bool, One, Atom, Enum, and Qty and
closed under named Record, Variant, and Option whose members are QuantSort.
It excludes FinSet and TotalMap. Quantification has ordinary set-theoretic
meaning; executable enumeration still requires a finite profile.

Typing is syntax directed. Constructors supply every field once; matches supply
every tag once and one common result sort; map and set operands use identical
declared sorts; Boolean operators accept Bool; equality requires one identical
sort; quantity operations require one identical Qty sort; conditional branches
have one identical sort; quantifier binders are fresh; and state reads use the
exact product key/value declarations.

Checked arithmetic returns:

```text
ArithResult(q) = Variant(Ok:q, Overflow:One, Underflow:One)

add((u,x),(u,y)) = Ok((u,x+y)) when x+y <= I(limit(q))
                   Overflow(one) otherwise

sub((u,x),(u,y)) = Ok((u,x-y)) when y <= x
                   Underflow(one) otherwise
```

Every result is eliminated through exhaustive matching. There is no raw String,
host integer, float, null, partial projection, partial map, unchecked
arithmetic, arbitrary or empty choice, recursion, file/network access, digest
operator, backend source, evaluator callback, or opaque function call.

## F0-DEN-007: Indexed Evaluation and Phase Noninterference

For `Sigma;Gamma |- t:Term<tau,R>`, evaluation is the total mathematical
function:

```text
Eval(M,I,Gamma,rho,R-inputs,t) in [[tau]]I
```

where `R-inputs` contains exactly the parameter, pre-state, post-state, and
event components named by `R`. A component outside `R` is neither supplied nor
observable. Environment `rho` supplies a correctly typed value together with
the declared provenance for every variable.

Expression meanings are the standard carrier operations fixed in
F0-DEN-002/003: mathematical tuple construction/projection, tagged-sum
construction/exhaustive elimination, total function application/update,
finite-set operations, classical two-valued Boolean logic, same-carrier
equality, natural-number order inside one Qty carrier, exhaustive checked
arithmetic, and set-theoretic quantification.

Primitive reads have provenance:

```text
parameter        {PARAM}
pre_get(q,k)     {PRE} union provenance(k)
post_get(q,k)    {POST} union provenance(k)
current_event    {EVENT}
```

The required phase noninterference theorem is:

```text
if two evaluation contexts agree on rho and every component in R,
then Eval of t is equal, regardless of components not in R.
```

This theorem is a metatheory obligation for any F0 parser/type checker/evaluator
pair. Tests alone do not establish it.

## F0-DEN-008: Model Bodies and Well-Formedness

A model body over `Sigma` is:

```text
M = (
  Sigma,
  InitBody,
  ActionBodies,
  RequiredActionSet,
  MetadataBindings,
  BaseClaimBodies
)
```

`InitBody` is one `InitPred`. Every action in `RequiredActionSet` has exactly
one action body, and no action body exists outside the signature. Every action
body supplies, for each branch `b`:

```text
Guard(a,b)       one GuardPred
Updates(a,b)     a finite ordered list of typed Update records
Emit(a,b)        one EventTerm constructing one non-stutter EventTag
BranchMetadata   closed, schema-typed data for later layers
```

An Update record is `(q,key,value)`, with `key:UpdateTerm<Kq>` and
`value:UpdateTerm<Vq>`. Repeated dynamic locations are legal and apply in list
order; they remain one finite syntactic write trace. This removes any need to
prove key disequality merely to define the transition.

`WFModel(M,I)` holds only when:

1. `Sigma` and `I` satisfy F0-DEN-001/002.
2. every body and metadata reference resolves and type checks;
3. every required action has a nonempty branch set and exact body;
4. each branch event is non-stutter and in its declared event set;
5. branch guards of one action are pairwise disjoint for the same `(s,p)`;
6. no body contains a phase or operation forbidden by its judgment;
7. all BaseClaim bodies type check and name only required actions/branches;
8. all mandatory nonvacuity obligations named in F0-DEN-014 are present.

Branch disjointness makes all nondeterminism explicit in action parameters and
branch identity. An environment, fault, or attacker choice is represented by a
typed parameter selected for that step, not by an implicit evaluator choice.
F0 does not require guards to be exhaustive over every state/parameter; a
disabled action has no branch whose guard holds. Later invocation contracts may
require outcome totality over an explicit invocation precondition.

## F0-DEN-009: Instrumented Reads, Writes, and Derived Frames

Evaluation has an instrumented form that returns the same value plus an ordered
read trace. `ReadTrace(t,rho,s,p)` records each dynamic state location read by a
`pre_get`; ordinary mathematical operations add no state location. The
instrumented evaluator must satisfy value erasure:

```text
erase(InstrumentedEval(t)) = Eval(t)
```

For branch `(a,b)` in pre-state `s` with parameter `p`, evaluate its guard. If
false, the branch has no transition. If true, evaluate the update list from
left to right. Every key and value expression reads the original pre-state `s`,
not an intermediate post-state; writes themselves fold over an accumulating
state:

```text
s0 = s
s(i+1) = Write(si, evaluated_location(update_i), evaluated_value(update_i))
s_raw = sN
```

Define:

```text
WriteTrace(a,b,s,p) = ordered evaluated locations of Updates(a,b)
WriteSet(a,b,s,p)   = set of WriteTrace(a,b,s,p)
ReadSet(a,b,s,p)    = union of instrumented reads from guard, updates, and event
Frame(a,b,s,p,s')   iff every loc outside WriteSet(a,b,s,p)
                      has Read(s,loc) = Read(s',loc)
```

The frame permission is therefore derived before and independently of the
observed post-state difference. The required frame theorem is:

```text
Diff(s,s_raw) subseteq WriteSet(a,b,s,p)
```

An actual write may preserve the prior value. Operational-access claims use
`WriteTrace`, not only `Diff`. Later platform refinement may prove that a
concrete implementation's physical access trace refines these abstract traces;
it may not infer permission from a concrete write that was absent here.
Metadata has no operational reads in F0. A later module that gives a metadata
field semantic force must add its evaluated reads to that module's footprint
and prove projection back to this F0 transition.

## F0-DEN-010: Closed Branch and Action Relations

For a well-formed model, a branch relation is not supplied by the candidate as
an arbitrary set. It is uniquely generated:

```text
ClosedBranch(M,I,a,b,s,p,s',e) iff
  Eval(Guard(a,b), rho[p], {PARAM=p, PRE=s}) = true
  and s' = FoldUpdates(a,b,s,p)
  and e  = Eval(Emit(a,b), rho[p], {PARAM=p, PRE=s})
  and e is in the exact declared event set for (a,b)
  and Frame(a,b,s,p,s')
```

`FoldUpdates` and `Emit` are total for well-typed operands. The action relation
is the disjoint branch union:

```text
ClosedAction(M,I,a,s,p,s',e) iff
  exists exactly one b in Branches(a): ClosedBranch(M,I,a,b,s,p,s',e)
```

The exact-one property follows from guard disjointness. A branch relation is
deterministic for fixed `(s,p)`; all nondeterministic choices are explicit in
`p`. Event inversion and label inversion identify the exact action, branch,
and parameter of every non-stutter transition.

Free-form `RelPred` may state a theorem about `ClosedBranch` or compare pre/post
state in an obligation. It cannot replace `Guard`, `Updates`, `Emit`, `Frame`,
or `ClosedAction`.

## F0-DEN-011: Init, Step, Enabledness, and Stutter

Initialization is:

```text
Init(M,I,s) iff Eval(InitBody, {}, {PRE=s}) = true
```

Stutter is the one reserved transition:

```text
Stutter(s,s',label,e) iff
  s'=s and label=StutterLabel(one) and e=StutterEvent(one)
```

The complete base step relation is:

```text
Step(M,I,s,label,e,s') iff
  Stutter(s,s',label,e)
  or exists a in RequiredActionSet, b in Branches(a), p in [[Pa]]I:
       label=Do(a,b,p)
       and ClosedBranch(M,I,a,b,s,p,s',e)
```

No feature label, candidate claim, scenario selection, or proof node changes
`RequiredActionSet`. Its completeness against the external threat/action basis
is an F3 condition; F0 only gives that exact set transition meaning.

Enabledness and occurrence are:

```text
EnabledBranch(M,I,a,b,s,p) iff exists s',e:
  ClosedBranch(M,I,a,b,s,p,s',e)

EnabledAction(M,I,a,s,p) iff exists b:
  EnabledBranch(M,I,a,b,s,p)

Taken(tau,a,b,p,i) iff tau.label[i] = Do(a,b,p)
```

Stutter is always enabled. This ensures finite-prefix extension but proves no
progress.

## F0-DEN-012: Base Executions and Reachability

An infinite base execution is:

```text
tau = s0,label0,event0,s1,label1,event1,...
```

such that `Init(M,I,s0)` and
`Step(M,I,si,labeli,eventi,s(i+1))` hold for every natural `i`.
`Exec(M,I)` is the set of all such executions. It is defined without fairness,
provider, network, scheduler, or environmental assumptions.

A finite execution prefix contains `n+1` states and `n` label/event pairs and is
a prefix of an element of `Exec(M,I)`. Explicit stutter extends every valid
finite prefix to an infinite base execution. Define:

```text
Reach(M,I) = {s | s occurs in some tau in Exec(M,I)}
```

An assumption-qualified set used by a later claim module is always written
`Exec_A(M,I,A) = {tau in Exec(M,I) | A(tau)}`. It never changes `Exec`, `Step`,
or base reachability. In particular, safety cannot silently quantify only over
`Exec_A`.

## F0-DEN-013: Base Safety and Proof Obligations

A base invariant is a `PreTerm<Bool>`. Its semantic claim is:

```text
BaseAlways(M,I,Inv) iff
  InitNonempty(M,I)
  and for every tau in Exec(M,I), every state of tau satisfies Inv
```

where:

```text
InitNonempty(M,I) iff exists s: Init(M,I,s)
```

The usual inductive obligations are sufficient proof obligations, not the
definition of `BaseAlways`:

```text
InitSafe(M,I,Inv) iff
  for every s, Init(M,I,s) implies Inv(s)

BranchPreserves(M,I,Inv,a,b) iff
  for every s,p,s',e,
    Inv(s) and ClosedBranch(M,I,a,b,s,p,s',e) imply Inv(s')
```

All simultaneous invariants are conjoined before generating `InitSafe` and one
`BranchPreserves` obligation for every branch of every required action. Stutter
preservation follows from state equality. An action name, branch list, proof
node, or solver exit code has no proof meaning by itself.

Safety under an explicit rely is a differently named, assumption-qualified
claim and must justify why the rely is permitted by F3. It cannot support the
unqualified hypervisor-boundary safety claim.

## F0-DEN-014: Mandatory Nonvacuity and Discrimination

Every F0 claim decision includes `InitNonempty`. In addition, the external F3
policy classifies branches and antecedents and requires exact obligations:

```text
BranchReachable(a,b) iff
  exists a finite base prefix ending at s, parameter p, post-state s', event e:
    ClosedBranch(M,I,a,b,s,p,s',e)

AntecedentReachable(P) iff
  exists s in Reach(M,I): Eval(P,{PRE=s}) = true

EnabledWitness(a,b) iff
  exists s in Reach(M,I),p: EnabledBranch(M,I,a,b,s,p)
```

Every mandatory success, deny, exhaustion, stale, fault, compromise, crash,
recovery, and adversary branch must be reachable in at least one policy-required
profile unless F3 records a narrower claim-blocking impossibility proof. Every
progress trigger and rely antecedent introduced later requires a reachable
witness in its own module.

Each claimed invariant also requires a policy-owned discriminating mutant that
violates the invariant and an accepted source-level counterexample replay. A
checker that accepts a literal-true invariant, empty initial set, unreachable
branch, empty assumption-filtered trace set, or mutant that does not change the
claim cannot promote the claim.

Existential reachability does not establish attacker input-enabledness. F2/F3
separately require compromised-step coverage/inclusion at every state in which
the principal is compromised.

## F0-DEN-015: Finite Profiles and Claim Quantification

Let `Admissible(M)` be the class of interpretations satisfying the signature,
constant constraints, and every explicit model-class premise. A finite profile
`F` provides finite nonempty Atom carriers, concrete limit values, constants,
and any finite executable-fragment bounds. Its instantiation `I_F` is valid only
after a checker proves `I_F in Admissible(M)`.

Claim scopes are distinct judgments:

```text
M,I_F |= C                         exact finite-instance claim
M |=_finite_class C                every admitted finite interpretation
M |=_admissible C                  every I in Admissible(M)
```

A source-replayed counterexample in `I_F` refutes a broader claim only when
`I_F` belongs to that claim's quantified class and preserves every premise. No
counterexample in `I_F` supports only the exact finite-instance claim.

Scope widening requires a named proof rule with checked premises, such as an
induction over a declared well-founded measure, a refinement theorem, or a
symmetry reduction whose orbit and cutoff premises are proved. Scale labels,
larger bounds, backend agreement, or repeated bounded runs never widen scope.

## F0-DEN-016: F0 Metatheory Obligations

F0 is locally complete only after the exact syntax and inference rules have
accepted proof or independently checkable certificate evidence for:

```text
WF-DECIDABLE-FINITE-SYNTAX
CARRIER-NONEMPTY
TYPE-UNIQUENESS
SUBSTITUTION-PRESERVES-SORT-AND-PROVENANCE
EVALUATION-TOTALITY
PHASE-NONINTERFERENCE
INSTRUMENTED-VALUE-ERASURE
FRAME-SOUNDNESS
BRANCH-DETERMINISM
LABEL-EVENT-INVERSION
STUTTER-CLOSURE
FINITE-PREFIX-EXTENSION
INDUCTIVE-SAFETY-SOUNDNESS
FINITE-PROFILE-ADMISSIBILITY
```

The proof/calculus and certificate format are F3 inputs. A reference evaluator,
JSON Schema, mutation runner, SMT result, or differential test cannot serve as
its own metatheory proof.

## F0-DEN-017: F1 and F2 Interface Boundary

F1 modules may add typed state products, event tags, action bodies, and claim
forms for progress, time, durability, distribution, composition,
noninterference, and robust integrity. Each module must provide:

```text
well-formedness extension
state/action/event contribution
exact satisfaction relation
mandatory nonvacuity obligations
erase map to an F0 model and execution
projection theorem for every extended transition
cross-module composition obligations
assumption and nonclaim boundary
```

Calling a module conservative additionally requires a stated conservativity
theorem. An assumption-qualified refinement that removes base executions is not
silently called conservative.

F2 supplies physical state/observation coverage, abstraction/concretization,
compromise over-approximations, platform concurrency and raw-interface models,
and the proof that a concrete or lower-level execution projects to F0/F1. F0
does not infer physical isolation from typed abstract state.

## F0-DEN-018: Backend, TCB, and Authorization Boundary

The normative source is this mathematical calculus plus the later exact machine
grammar and inference rules that survive review. A minimal positive-evidence TCB
may include a canonical decoder, type/provenance checker, small proof or
certificate kernel, translation-certificate checker, and the separately rooted
gate/checkpoint/high-water verifier. Its exact composition is fixed by F3.

Reference evaluators, materializers, scenario generators, translators, SMT
solvers, TLA+/TLC, Alloy, mutation runners, and report generators are untrusted
producers. A source-level counterexample may be checked by a small replay path.
Positive backend evidence requires a claim-specific preservation theorem or an
independently checkable translation/proof certificate covering the exact
semantic features used.

This document is a local F0 design candidate. It supplies no F1, F2, or F3
closure, no external K0 decision, no K1 candidate IR, no architecture freeze,
no TLA+ authorization, no model-supported claim, no Linux behavior change, and
no claim of protection, performance, cost, scalability, cluster availability,
or deployability.
