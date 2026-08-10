# DL-SemFoundation-3 Normative Denotation

Status: local K0 candidate; external adoption absent

Date: 2026-08-10

This document defines the normative mathematical meaning of the R11 epoch-2
semantic foundation. A parser, evaluator, solver encoding, model checker, or
backend translation implements this meaning; none of them defines it.

## SF-DEN-001: Signature and Interpretation

A signature is:

```text
Sigma = (Sort, Unit, Limit, Product, Constant, Event, Action)
```

`Sort`, `Unit`, `Limit`, `Product`, `Event`, and `Action` are pairwise-disjoint
identifier namespaces. An interpretation `I` assigns:

```text
I(k)  a nonempty carrier to every nominal Atom sort k
I(l)  a natural value to every Limit l
I(c)  a member of the declared sort of every Constant c
```

Enums, structural sorts, and all derived carriers have the meanings below.
An architecture interpretation may be infinite. A finite execution profile is
a separate object and never changes these definitions.

## SF-DEN-002: Sort Carriers

For interpretation `I`:

```text
[[Bool]]I                   = {false, true}
[[Atom(k)]]I                = I(k)
[[Enum(e1,...,en)]]I        = the declared closed set {e1,...,en}
[[Qty(u,l)]]I               = {(u,n) | n in Nat and 0 <= n <= I(l)}
[[Prod(f1:s1,...,fn:sn)]]I = product of the named [[si]]I carriers
[[Sum(t1:s1,...,tn:sn)]]I  = disjoint tagged union of the [[si]]I carriers
[[One]]I                    = {one}
[[Option(s)]]I              = [[Sum(None:One, Some:s)]]I
[[FinSet(s)]]I              = all finite subsets of [[s]]I
[[TotalMap(k,v)]]I          = all total functions [[k]]I -> [[v]]I
```

`One` is the singleton structural sort. It is distinct from every identifier
in the measurement-unit namespace `Unit`. Structural sort definitions are
finite and acyclic. Recursive or partial sorts are not in the foundation.
Identity, namespace, slot, generation, epoch,
incarnation, ordinal, and clock-domain identifiers use distinct Atom sorts.

Two `Qty` values may be compared or combined only when their complete Qty sort,
including unit and limit, is identical. A conversion is a separately declared
typed relation and, when security-relevant, requires an explicit provider
receipt in the architecture model.

## SF-DEN-003: State Products

Every state product `p` declares a key sort `Kp` and value sort `Vp`.

```text
[[State]]I = product over p in Product of [[TotalMap(Kp,Vp)]]I
```

Thus every state-product lookup is total. Object absence, failed lookup,
vacancy, and tombstones are explicit values in `Vp`, normally through a Sum or
Option. An absent key is never represented by evaluator failure or host `null`.

A state valuation is written `s`. `s[p][k]` denotes the total value of product
`p` at key `k`.

## SF-DEN-004: Events, Parameters, and Action Relations

`EventI` is one closed disjoint sum containing every declared architecture,
provider, environment, fault, adversary, and audit event plus
`StutterEvent(Unit)`.

Each action family `a` declares a parameter sort `Pa` and denotes:

```text
[[a]]I subseteq [[State]]I x [[Pa]]I x [[State]]I x [[Event]]I
```

`[[a]]I(s,p,s',e)` means one occurrence of action family `a` with parameters
`p` relates pre-state `s` to post-state `s'` and emits event `e`. Action labels
are `(a,p)` and are distinct from events. The actor requesting an action, the
authority permitting it, and the writer owning the affected state are separate
typed fields.

## SF-DEN-005: Phase-Safe Terms

Term typing computes a read effect `R`, where:

```text
R subseteq {PRE, POST, EVENT}
```

The principal judgment is:

```text
Gamma |- t : Term<T,R>
```

with these named restrictions:

```text
StaticTerm<T> = Term<T,{}>
PreTerm<T>    = Term<T,R> where R subseteq {PRE}
PostTerm<T>   = Term<T,R> where R subseteq {POST}
StatePred     = Term<Bool,R> where R subseteq {PRE}
ActionRel     = Term<Bool,R> where R subseteq {PRE,POST,EVENT}
```

Composition unions read effects. A static term may therefore appear in any
phase. A pre read never becomes a post read, and an event read is legal only in
an ActionRel. There is no temporal-next term. A temporal predicate is not a base
term.

For a well-typed term, denotation is the total function:

```text
[[t]]I,rho,s,s',e
```

over the environment `rho` and precisely the pre-state, post-state, and event
named by `R`. Supplying or observing another phase is a type error, not a
runtime convention.

## SF-DEN-006: Total Expression Forms

The closed base expression set contains:

```text
typed literals and variables
let binding
product construction and total field projection
sum construction and exhaustive sum matching
total-map lookup and functional update
finite-set empty, insert, remove, membership, subset, union, and difference
Boolean conjunction, disjunction, negation, implication, and equivalence
same-sort equality
same-Qty-sort ordering
checked Qty addition and subtraction
total conditional
universal and existential quantification over a declared carrier
pre-state product read, post-state product read, and event read
```

For well-typed operands, expression denotation is fixed as follows:

```text
literal and variable       = the declared carrier member or rho binding
let x=t in body            = body evaluated under rho[x := [[t]]]
product construction       = the named mathematical tuple of field values
product field              = total projection of that named tuple
sum construction           = the declared tag paired with its payload
sum match                  = the branch for that tag with payload bound;
                             all declared tags must have exactly one branch
map_get(m,k)               = the total function value m(k)
map_set(m,k,v)(x)          = v when x=k, otherwise m(x)
set_empty                  = the empty finite subset
set_insert/remove          = mathematical finite-set insertion/removal
member/subset/union/diff   = mathematical finite-set operations
and/or/not/implies/iff     = classical two-valued Boolean operations
eq                         = equality in one identical declared carrier
qty_order                  = order of the natural components of one Qty sort
if b then x else y         = x when b=true, otherwise y
forall x:s. p              = true iff p is true for every x in [[s]]I
exists x:s. p              = true iff p is true for some x in [[s]]I
pre_get(p,k)               = s[p][k]
post_get(p,k)              = s'[p][k]
event                      = e
```

Checked arithmetic returns:

```text
ArithResult(q) = Sum(Ok:q, Overflow:One, Underflow:One)

qty_add((u,x),(u,y)) =
  Ok((u,x+y)) when x+y <= I(limit(q)); otherwise Overflow(one)

qty_sub((u,x),(u,y)) =
  Ok((u,x-y)) when y <= x; otherwise Underflow(one)
```

and is eliminated only by exhaustive matching. There is no raw semantic
String, host Int, floating point, null, unchecked arithmetic, partial map,
partial sum projection, arbitrary or empty choice, digest, file/network access,
backend source, recursion, or evaluator callback.

Typing is syntax directed. Literals inhabit only their declared carrier;
variables use exactly the sort in `Gamma`; product construction supplies every
field once; projection names a field of the inferred product; sum construction
uses one declared tag; and sum matching supplies every declared tag once with
one common result sort. Map keys/values and set elements match their exact
declared sorts. Boolean operators accept only Bool. Equality requires identical
sorts. Quantity ordering and arithmetic require one identical Qty sort.
Conditional branches have one identical sort. Quantifier binders are fresh and
the body is Bool. `pre_get` and `post_get` match the exact product key sort;
`event` has Event sort.

Read effects are empty for literals, variables, and constants; are `PRE`,
`POST`, or `EVENT` for the corresponding primitive read; and otherwise are the
union of all operand and branch effects. A binder never masks an existing
identifier. A StatePred rejects `POST` or `EVENT`; an ActionRel is the only
judgment that admits either of those effects.

Named definitions are finite acyclic capture-avoiding macros. They are fully
expanded before typing and have no independent dynamic semantics.

## SF-DEN-007: Read, May-Write, and Frame Semantics

Each action instance declares an exact may-read footprint and exact may-write
footprint. A may-write location is permitted, but not required, to differ. For
every action occurrence:

```text
location not in MayWrite(a,p,s) implies s'[location] = s[location]
```

The frame relation is generated from the complete state-product signature and
conjoined with the candidate action relation. Reads and actual writes are
derived from typed terms and pre/post comparison; candidate lists do not
override those derivations.

Every authoritative product has an owner role and consistency-domain key
function. Every locally atomic action instance has one atomicity-domain value.
An authoritative action cannot atomically write mutable products in two
different consistency domains. Cross-domain protocols are sequences of local
actions and immutable messages/receipts.

## SF-DEN-008: Init, Required Action Closure, Next, and Stutter

`Init` is a StatePred. K0 policy supplies `RequiredActions`, including all
mandatory candidate, provider, environment, fault, and adversary families for
the claim scope. K1 cannot remove a family by omitting a feature label.

```text
Stutter(s,s',e) iff s' = s and e = StutterEvent(one)

Next(s,s',label,e) iff
  label = STUTTER and Stutter(s,s',e)
  or exists a in RequiredActions, p in [[Pa]]I:
       label = (a,p) and [[a]]I(s,p,s',e)
```

No non-stutter action may emit `StutterEvent`. Every declared action emits one
event variant from its exact event set.

## SF-DEN-009: Enabledness and Occurrence

```text
Enabled(a,s,p) iff exists s',e: [[a]]I(s,p,s',e)
EnabledFamily(a,s) iff exists p: Enabled(a,s,p)
Taken(a,p,i) iff trace label at step i is (a,p)
TakenFamily(a,i) iff exists p: Taken(a,p,i)
```

Instance fairness and family fairness are distinct. Family fairness alone does
not imply fairness among parameters or Domains.

## SF-DEN-010: Traces and Prefixes

An infinite trace is:

```text
tau = s0,label0,event0,s1,label1,event1,...
```

such that `Init(s0)` and `Next(si,si+1,labeli,eventi)` hold for all natural
`i`. A finite execution is a finite prefix of such a trace. Every valid finite
prefix can be extended by explicit stutter. A finite prefix establishes only
prefix properties and reachability, never liveness by termination of the
checker.

## SF-DEN-011: Safety and Reachability Satisfaction

For StatePred `Inv` and `Q`:

```text
I |= InitSafe(Inv)
  iff for all s, Init(s) implies Inv(s)

I |= Inductive(Inv,a)
  iff for all s,p,s',e,
       Inv(s) and [[a]]I(s,p,s',e) imply Inv(s')

I |= Always(Inv)
  iff every state of every admitted trace satisfies Inv

I |= Reachable(Q)
  iff some finite admitted prefix ends in a state satisfying Q
```

All simultaneous safety invariants are conjoined before generating
`InitSafe` and one `Inductive` obligation per required concrete action family.
An action-name list or proof-node name has no proof meaning.

Nonvacuity is explicit:

```text
I |= InitNonempty
  iff some s satisfies Init(s)

I |= ActionReachable(a,branch)
  iff some admitted finite prefix reaches s and some p,s',e realize the named
      branch of [[a]]I(s,p,s',e)
```

Every mandatory success/fault/deny branch and every progress antecedent must
have a policy-required reachability obligation. An impossible guard, empty
initial state, or unreachable success cannot discharge safety or progress.

## SF-DEN-012: Progress and Fairness Extension

The progress extension has structured trace predicates and no temporal-next
term. For every admitted trace and action instance `(a,p)`:

```text
WF(a,p) iff for every i,
  (for every j >= i, Enabled(a,sj,p))
  implies (there exists k >= i, Taken(a,p,k))

SF(a,p) iff for every i,
  (for every j >= i, there exists k >= j with Enabled(a,sk,p))
  implies (there exists m >= i, Taken(a,p,m))
```

Family WF/SF replaces instance occurrence with family occurrence and is weaker
with respect to parameter starvation. Fairness is an explicit rely assumption,
not a property inferred from a trusted actor name. Hostile Linux and network
behavior receive no fairness assumption.

A response obligation separately declares trigger, service success, rejection,
withdrawal, fail-stop, continuity-loss, rely assumptions, fairness instances,
and claim scope. Service success cannot be satisfied by another terminal class.
A rank argument names a well-founded order and classifies every required action
as decreasing, preserving, or potentially increasing the rank.

## SF-DEN-013: Timed and Provider Extension

Logical steps are not time. A real-time obligation declares a clock-domain
sort, typed timestamp/interval quantities, uncertainty, timer/provider action
relations, conversion receipts, drift/error assumptions, and the event that
linearizes the bound. Values from distinct clock domains are incomparable
without a valid typed conversion receipt.

Provider fairness and maximum response/overrun are explicit assumptions or
proved guarantees. A provider name does not create either property.

## SF-DEN-014: Transaction, Durability, Crash, and Recovery Extension

A transaction declares:

```text
member local action families
atomicity and durability domain functions
ordered durable write groups
externally visible and commit events
idempotence and generation keys
generated crash cuts
recovery relation at every cut
re-crash closure of every recovery prefix
terminal outcome partition
```

Failure semantics belongs to the transaction/action relation, not to one
product-level failure-successor string. A crash exposes exactly the durable
projection for its cut and may discard the declared volatile projection.
Every durable group, externally visible event, message visibility event, and
recovery durable group generates a cut. The generated set must equal the
required cut set.

## SF-DEN-015: Distributed Extension

Network state is explicit and supports typed send, deliver, drop, duplicate,
reorder, replay, reconnect, and stale-epoch behavior. Network silence is never
a fence, acknowledgement, or quiescence proof.

Cross-consistency-domain authority transfer is a sequence:

```text
source reserve
source fence and no-reissue
quiescence proof or conservative horizon
destination-bound immutable export
in-transit conservation
destination verification and one-use consume
destination install
acknowledgement and source terminalization
```

A refund requires positive evidence that install did not occur and cannot
later occur. Source, destination, resource vector, epoch, export, consume,
install, horizon, and refund identities are typed and destination bound.

## SF-DEN-016: Two-Trace Noninterference Extension

Confidentiality uses self-composition, not a one-trace Domain predicate. A
noninterference obligation supplies:

```text
left and right initial-state relation
allowed high-state differences
low-equivalence relation
public environment and scheduler coupling relation
high-action coupling/independence policy
declassification events and released value relation
low observation function
termination sensitivity policy
timing sensitivity policy
co-tenancy leakage policy
```

For every pair of admitted traces satisfying the coupling and initial relation,
low observations must remain related except at an explicit declassification.
If timing or termination is excluded, the resulting nonclaim is mandatory.
Integrity remains a separate writer/authority safety property; availability
remains a separate progress property.

## SF-DEN-017: Parametric and Finite Claim Boundary

The mathematical model is parameterized by interpretation `I`. A finite
profile `F` supplies finite carrier values and concrete limits to construct an
executable instance `I_F`.

```text
counterexample in I_F        refutes the corresponding general claim
no counterexample in I_F     supports only the exact bounded-instance claim
general or arbitrary-finite  requires induction, refinement, symmetry with
                             checked premises, or another accepted proof
```

Every result records interpretation cardinalities, limits, symmetry/induction
assumptions, and exact claim quantification. Scale labels never widen a bounded
result.

## SF-DEN-018: Backend and TCB Boundary

The trusted semantic base is limited to the strict parser/canonicalizer,
phase/type checker, a faithful implementation of these denotations or a small
certificate checker, translation-certificate checker, and root/checkpoint/
high-water verifier.

Reference evaluators, SMT encoders, TLA+ translators, Alloy models, scenario
generators, model checkers, solvers, and mutation runners are untrusted
producers. Differential agreement is regression evidence. An accepted backend
claim requires a compositional preservation argument or proof-producing
per-artifact translation validation that covers values, state, action/event,
stutter, fairness, traces, and the exact obligation class used.

This foundation contains no K1 candidate state or action definitions and does
not authorize candidate construction until an external K0 decision binds the
complete foundation package.
