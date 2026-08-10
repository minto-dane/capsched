# Dynamic Residency Epoch-2 Kernel v2 Rejection and v3 Denotation

## Status

The first epoch-2 semantic-kernel v2 contract is locally rejected before
implementation. A v3 design is authorized only after splitting K0-K3 and
defining mathematical denotation independently of tools. G0/K0, candidate IR,
semantic freeze, TLA+, model support, and protection claims remain false.

The machine-readable review disposition is
`dynamic-residency-epoch2-kernel-v2-rejection-v3-denotation-v1.json`.

## Exact Rejected Kernel Draft

```text
schema
  capsched-models/policy/r11/epoch2/semantic-kernel-contract-schema-v2.json
  f30bf42e28a527904d0663feec7e34dc3494c7708169d0f3741fa2d0b4ae13ad

contract
  capsched-models/policy/r11/epoch2/semantic-kernel-contract-v2.json
  a70489bf816569f382268d69e23e147a0319b7c0370717cc1367f3b1834f8c8a
```

The strict schema passes and the contract has unique inventories of 8
contexts, 10 sort kinds, 38 total operator names, 7 structured obligation
kinds, and 21 reject classes. Those are shape facts only. No reference
interpreter was built because three fresh reviews found the language meaning
and gate ordering unsound before implementation.

## Hostile Review Disposition

Three read-only local reviews returned `LOCAL_ADVISORY_REJECT`:

| Axis | Principal finding |
| --- | --- |
| language and formal semantics | no denotation; phase, partiality, finite/general claims, liveness, noninterference, and translation semantics remain open |
| assurance | trust-root cycle, input verdicts, freshness, signature payload, assignment and real-runner semantics remain open |
| scenario and composition | current coverage is a union of labels; hostile actors, process/container lifecycle, message protocol, reachable interactions, and generated cuts remain absent |

These are advisory reviews, not external K0 receipts. Their exact agent session
identities are retained in the machine-readable disposition.

## Why the v2 Contract Is Not Implemented

The v2 statement made a pinned interpreter plus corpus the canonical semantics.
That would place an implementation where a definition is required. An
interpreter bug and a matching corpus omission would then agree with each
other. The contract also required candidate bindings inside G0 while forbidding
candidate construction until G0, and its finite carriers could be mistaken for
architecture-wide theorems.

Writing more code against that boundary would increase the trusted code base
without resolving the category errors. The exact v2 files are therefore
retained and a new revision is required.

## Acyclic Gate Ladder

### K0 / G0: Foundation adoption

Inputs fixed before any candidate exists:

```text
mathematical semantic kernel and syntax/type mapping
externally owned policy-template formulas and role-hole signatures
threat-derived mandatory environment/adversary action basis
scenario-generator, cut-generation, reachability, and mutation requirements
claim/nonclaim catalog
reference checker plus certificate-checker policy
out-of-band TrustRoot, GatePolicy, tool/runtime pins, checkpoint and high-water
```

K0 acceptance authorizes only construction of one candidate against those
exact bytes. It cannot freeze architecture or support a model claim.

### K1 / G1: Candidate readiness

The candidate supplies concrete architecture choices:

```text
state products, keys, values, owner and consistency-domain bindings
action/event signatures, guards, relations, may-write sets and frames
transactions, durability domains, commit events, cuts and recovery relations
total typed role bindings to K0 templates
feature-to-mandatory-action closure
generated finite profiles, traces, negative schedules and obligations
```

K1 is a local mechanical readiness decision. It checks construction but cannot
self-approve semantic adequacy.

### K2 / G2: Exact semantic review and freeze

External reviews bind final K1 bytes, instantiated formulas, generated
interactions/cuts, reachable traces, mutation results, and every open finding.
The deterministic gate may authorize backend translation only. A formal
counterexample reopens K1 and invalidates the freeze for successor bytes.

### K3 / G3: Proof and evidence

Proof and model-checking results bind a frozen K2 candidate, exact backend
translation, translation-validation evidence, tool/runtime identity, hostile
mutants, and claim-specific capsule. K3 derives only an allowlisted model claim
transition. It cannot authorize implementation or protection evidence.

## v3 Mathematical Universe

Let a semantic signature be:

```text
Sigma = (Sort, Unit, Limit, Product, Constant, Function, Event, Action)
```

An interpretation `I` assigns each nominal carrier a nonempty set, each enum a
fixed finite set, each unit a nominal identity, and each limit a natural value.
The architecture signature is parametric; an executable profile `F` separately
chooses finite subsets/cardinalities and concrete limit values.

### Sort carriers

```text
[[Bool]]I                  = {false, true}
[[Atom(k)]]I               = I(k), nonempty and otherwise uninterpreted
[[Enum(e)]]I               = declared closed atoms of e
[[Qty(u,l)]]I              = {n in Nat | 0 <= n <= I(l)}, tagged by unit u
[[Product(s1,...,sn)]]I    = product of [[si]]I
[[Sum(tag_i: si)]]I        = disjoint tagged union of [[si]]I
[[Option(s)]]I             = None + Some([[s]]I)
[[FinSet(s)]]I             = finite subsets of [[s]]I
[[TotalMap(k,v)]]I         = total functions [[k]]I -> [[v]]I
```

Identity, namespace, slot, generation, epoch, incarnation, and ordinal use
distinct nominal sorts. A profile may make their carriers equally sized but
cannot make the sorts interchangeable. Exhaustion, wrap, reuse, rekey, and
stale-reference behavior are explicit actions and outcomes, not host-integer
accidents.

### State, event, and action

Each state product `p` has key sort `Kp` and value sort `Vp`:

```text
StateI = product over p of TotalMap([[Kp]]I, [[Vp]]I)
EventI = declared disjoint event sum, including explicit StutterEvent
```

An action family `a` with parameter carrier `Pa` denotes a relation:

```text
[[a]]I subseteq StateI x Pa x StateI x EventI
```

Its signature records actor class, authority role, atomicity/consistency
domain, may-read products, may-write products, event variants, and transaction
membership. A may-write product is permission to differ, not a claim that it
must differ on every step. The derived frame requires equality for every
location outside the instantiated may-write footprint.

Cross-consistency-domain protocols are sequences of locally atomic actions.
They never receive one fictional global linearization point.

### Phase-safe terms

The base syntax has distinct judgments:

```text
Gamma |- t : StaticTerm<T>
Gamma |- t : PreTerm<T>
Gamma |- t : PostTerm<T>
Gamma |- p : StatePred
Gamma |- r : ActionRel
```

Static terms may lift into pre or post terms. A pre term cannot become a post
term and vice versa. `StatePred` reads one state. `ActionRel` may combine
explicit pre and post terms, action parameters, and one event. There is no
general temporal AST and no temporal `next` operator in the base language.

Term evaluation is a total function under `I`, an environment, and the states
required by its phase. State-product lookup is total. Object absence is encoded
in the value sort. Record projection is total; options and sums require
exhaustive matching. Quantity addition/subtraction returns:

```text
ArithResult<T> = Ok(T) | Overflow | Underflow
```

and every caller must match all outcomes. The base kernel contains no raw
String, host Int, partial map, unchecked arithmetic, empty choice, digest, file
access, backend source, or evaluator callback.

### Init, Next, stutter, and enabledness

`Init` is a `StatePred`. The external policy supplies mandatory action-family
closure `RequiredActions`; candidate action declarations cannot shrink it.

```text
Stutter(s,s',e) iff s' = s and e = StutterEvent

Next(s,s',label,e) iff
  label = STUTTER and Stutter(s,s',e)
  or exists a in RequiredActions, params in Pa:
       label = (a,params) and [[a]]I(s,params,s',e)

Enabled(a,s,params) iff exists s',e: [[a]]I(s,params,s',e)
EnabledFamily(a,s) iff exists params: Enabled(a,s,params)
```

Every architecture execution is closed under explicit stutter and all
policy-required hostile/fault actions. A missing adversary action is a K1
construction failure, not an assumption of benign behavior.

### Traces and satisfaction

An infinite trace is:

```text
tau = s0, label0, event0, s1, label1, event1, ...
```

with `Init(s0)` and `Next(si,si+1,labeli,eventi)` for every `i`. A finite
execution is a prefix that can be extended by explicit stutter; finite-prefix
success cannot silently establish liveness.

```text
I |= InitSafe(Inv)
  iff for every s: Init(s) implies Inv(s)

I |= Inductive(Inv,a)
  iff for every s,p,s',e:
       Inv(s) and [[a]]I(s,p,s',e) imply Inv(s')

I |= Reachable(q)
  iff some finite execution prefix ends in state s with q(s)
```

All safety invariants are conjoined before Init and per-action preservation
obligations are generated. A `preserved_by` name is never proof.

## Conservative Extensions

### Progress and fairness

Trace predicates are a separate extension with no temporal-next primitive.
For an action family `a`:

```text
WF(a): on every suffix, continuous EnabledFamily(a) implies a later a-step
SF(a): on every suffix, infinitely recurring EnabledFamily(a) implies a later a-step
```

Fairness is an explicit environment/provider assumption, never inferred from
the word trusted. Adversarial Linux and network actions receive no fairness.
Each progress obligation separates service success, rejection, withdrawal,
fail-stop, and continuity-loss. A rank proof names every action that may
decrease, preserve, or increase the rank. Real-time bounds require the timed
extension and explicit clock/timer/provider assumptions.

### Transactions, crash, and durability

Atomicity and failure are action/transaction properties, not one product-level
successor. A transaction declares locally atomic actions, durability domains,
durable write groups, visibility/commit events, generated crash cuts, recovery
relations, idempotence keys, and re-crash behavior. Cuts are generated after
each durable group and externally visible event, including message visibility.

### Distributed behavior

The network is an explicit multiset/queue state with send, deliver, drop,
duplicate, reorder, replay, reconnect, and stale-epoch actions. Clock values
from different domains are incomparable without a typed conversion receipt and
uncertainty interval. Silence is not quiescence. Cross-domain transfer uses
source fence, destination-bound export, in-transit conservation, one-use
consume/install, acknowledgement, and a refund proof that excludes future
installation.

### Two-trace noninterference

Isolation uses a separate self-composed semantics over left and right traces.
It declares initial low-equivalence, high-difference allowance, public
environment/scheduler coupling, declassification events, low observation,
termination policy, timing policy, and allowed co-tenancy leakage. The proof
obligation compares observations under the declared coupling; a one-trace
`Domain` predicate cannot establish confidentiality.

## Mandatory Scenario Generators

W0-W12 become coverage views over digest-derived cases. K0 owns fourteen
generators:

```text
GEN-00 typed case envelope and digest-derived identity
GEN-01 bootstrap and honest/failed/compromised management
GEN-02 process/container/nested-process/service-Domain topology
GEN-03 clone/spawn/exec/exit/reparent and stale generations
GEN-04 sync/distinct/aliased async x cancel/revoke/exit/service failure x phase
GEN-05 entry stages x offline/revoke/provider fault/crash
GEN-06 every settlement receipt x crash/restart/duplicate/reorder/late delivery
GEN-07 dynamic residency, class, churn, migration, hotplug, recurrence and rekey
GEN-08 two-lane conservation, conflict, commuting diamond and isolated failure
GEN-09 failure closure, late facts, cleanup, tombstone, stale ref and exhaustion
GEN-10 transfer outcome x partition cut x endpoint restart x message adversary
GEN-11 multi-cluster import, clock, fence, heal, namespace and key rotation
GEN-12 tenant/Linux/service/management/network attackers and paired NI traces
GEN-13 progress and six component-interface composition products
```

Coverage is a relation from each required interaction tuple to at least one
reachable trace. Union-of-label coverage is forbidden. The generated ledger
also covers action guard MC/DC, branch totality/exclusivity, product/owner/CD/
writer/linearization uniqueness, transaction/cut/fault/recovery/re-crash,
topology/lifecycle/product, adversary/operation/target/outcome, progress
trigger/success/hostile schedule, component rely/guarantee, and each
claim/invariant with both a positive witness and a violating mutant.

## Assurance v3.1 Boundary

Analysis 0201 Protocol v3 is imported as the baseline. v3.1 removes the
remaining trust-root cycle:

```text
verify_gate(root_pin, trusted_checkpoint, persistent_high_water, closure)
  -> Reject(reason) | Accept(exact_transition, new_high_water)
```

`TrustRoot`, `AuthorityRegistry`, `GatePolicy`, schema/tool/runtime pins, root
checkpoint, and consumer high-water are out-of-band inputs fixed before the
candidate or review roster. TOFU is forbidden. The policy fixes exact
`(review-role, check-id)` assignments and unique principal/change-authority
separation. Review and gate documents contain evidence, not an authoritative
accept bit; the verifier derives the disposition.

Signed RFC 8785 payloads include type/domain separation, protocol version,
every predecessor digest, key and policy epoch, algorithm, and actual signature
bytes. Two independent measured runners bind argv, executable/runtime bytes,
exit, signal, timeout, truncation, live children, and every result. Decisions
advance a persisted high-water only after external log inclusion/consistency
verification. Unknown, duplicate, stale, revoked, partial, timeout, split-view,
or unverifiable input rejects or remains incomplete.

Evidence Capsule v1 may capture bytes. It supplies neither authenticity nor
external authority. A separately authenticated seal binds its capsule ID to
the policy, root, checkpoint, and exact candidate.

Mechanics can establish byte identity, signature validity, exact-set
completeness, declared separation, relative freshness, and deterministic
derivation under trusted roots. They cannot prove organizational independence,
non-collusion, review quality, key custody, semantic-policy completeness, or
that a consumer obtained the globally latest checkpoint. Those remain explicit
governance assumptions.

## Translation and TCB Boundary

The minimal trusted base is:

```text
strict parser/canonicalizer
phase/type checker
mathematical-semantics implementation or small certificate checker
translation-certificate checker for the claimed backend relation
root-key/checkpoint/high-water policy verifier
```

Template compilers, scenario generators, materializers, translators, solvers,
model checkers, and mutation runners are untrusted producers. Differential
tests remain useful regression evidence. They do not prove that TLA+ unbounded
integers, SMT bit-vectors, maps, stuttering, fairness, or finite traces preserve
kernel meaning. Each accepted backend needs a compositional preservation proof
or proof-producing per-artifact translation validation appropriate to the
claim scope.

## Immediate Next Artifact

Create a v3 denotational-kernel package, not an interpreter for v2. It must
separate the mathematical signature from finite execution profiles, encode the
K0-only artifact boundary, and include machine-checkable phase and totality
fixtures. G0 remains false until a real out-of-band K0 authority accepts the
final foundation bytes.
