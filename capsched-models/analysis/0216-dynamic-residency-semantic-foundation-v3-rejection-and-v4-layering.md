# Dynamic Residency Semantic Foundation v3 Rejection and v4 Layering

## Status

The exact `DL-SemFoundation-3` local K0 candidate is rejected. Its structural
inventory is reproducible, but all four independent local advisory reviews
found semantic blockers. No external authority participated. K0/G0, candidate
IR, semantic freeze, TLA+, model support, and protection claims remain false.

The machine-readable disposition is
`dynamic-residency-semantic-foundation-v3-rejection-v4-layering-v1.json`.

## Exact Reviewed Bytes

```text
semantic-foundation-v3.md
  9fbb5fd5c5e2d4da8246114b2eb136b8795bb3c20a44801d5947cb8cf1fe1734

semantic-foundation-schema-v3.json
  4880f50071f4299bc0e88b9cf1072e551bd36a9a9894e17a33e8e945fa2585ae

semantic-foundation-v3.json
  d38891c32bd9449df60777f2e421c98549b01e56409d1bff92a6cef37fda93b4
```

The local validator hash is
`c64ce526c11ecf3beb2ea6061449e14d94045c03b30d68af535efccbf4e12615`.
Two runs produced the same output hash
`4ee41dd00b62bc6e0121cd1978f171844d2d540433b72d7c06d04fdaa5913c12`.
That output says only `local_structural_regression_only` and keeps every
promotion field false.

## Review Provenance

Four read-only sessions independently checked the exact three v3 hashes:

| Axis | Session | Verdict |
| --- | --- | --- |
| denotation and type soundness | `019fe9df-bdd8-7e02-a487-be2e87714cb5` | `LOCAL_ADVISORY_REJECT` |
| concurrency, liveness, durability, distribution | `019fe9df-ead0-77a0-a7d6-4e4222edfd3d` | `LOCAL_ADVISORY_REJECT` |
| security, threat closure, noninterference | `019fe9df-a3da-75d0-a608-7356439dd052` | `LOCAL_ADVISORY_REJECT` |
| assurance, gate acyclicity, backend/TCB | `019fe9df-d47a-7072-bace-9ba338a83d2c` | `LOCAL_ADVISORY_REJECT` |

These sessions are local design evidence. They do not satisfy the external K0
roles or independence policy.

## What v3 Improved

The rejection does not erase valid progress. v3 correctly separated the
mathematical definition from interpreters, used total state maps and explicit
absence, introduced checked quantity arithmetic, distinguished phase-labelled
terms, made stutter explicit, separated action labels from events, stated
instance versus family fairness, required nonvacuity, separated finite-profile
results from general claims, and kept backends outside the default TCB.

Those decisions survive into v4. The failure is that the semantics around them
is not yet closed enough to carry K0 authority.

## Normalized Blockers

### B0: No complete semantic subject

An interpretation `I` assigns Atom, Limit, and Constant meanings, but there is
no complete well-formed model object containing `Init`, action bodies,
parameter/event declarations, metadata, and obligations. Later judgments use
`I |=` even though `I` alone cannot determine a transition system.

v4 must define:

```text
WFSignature(Sigma)
Model = (Sigma, InitBody, ActionBodies, Metadata, ClaimBodies)
WFModel(Model)
Eval(Model, I, environment, phase-indexed inputs, term)
Satisfies(Model, I, claim)
```

### B1: Ill-typed heterogeneous carriers

Action parameters differ by family and state-product values differ by product.
The untyped `(a,p)` and `location` notation therefore hides dependent sums.

```text
LabelI    = StutterLabel(One) + Sigma(a in Action).[[ParamSort(a)]]I
LocationI = Sigma(q in StateProduct).[[KeySort(q)]]I
```

Read, write, equality, frame, and occurrence operations must eliminate these
tags without comparing values from different carriers.

### B2: Incomplete signature and syntax

`Function` appears in Analysis 0215 but not the normative signature. `Constant`
is omitted from the pairwise-disjoint list and has no expression node.
`StutterEvent(Unit)` confuses a measurement namespace with singleton `One`.
Declaration arity, uniqueness, sort dependencies, nonempty enum/sum conditions,
constant distinctness, and quantifiable-sort restrictions are missing.

v4 needs one syntax-directed grammar and complete declaration well-formedness.
Set-theoretic denotation may be parametric and infinite; executable evaluation
is promised only for finite profiles and a declared executable fragment.

### B3: Phase laundering

Marking a variable effect-free permits a post-state or event-derived value to
be bound and reused in a `StatePred`. Evaluation also always receives
`s,s',e`, contradicting the claim that an unavailable phase cannot be supplied.

Every environment binding must carry provenance:

```text
STATIC | PARAM | PRE | POST | EVENT
```

`Eval_R` receives only the inputs indexed by `R`, and substitution must preserve
provenance. F0 requires a phase noninterference lemma.

### B4: Action and frame circularity

`[[a]]I` is not connected to one action AST. May-write is called exact while
actual writes are derived from pre/post difference. If observed differences can
define permission, every relation frames itself.

v4 constructs each branch relation in one direction:

```text
RawBranch       = evaluation of exact guard/body
SyntacticBound  = locations permitted by the declared, typed update forms
Frame           = equality at every location outside SyntacticBound
EventConstraint = exact branch event constructor and payload typing
ClosedBranch    = RawBranch and Frame and EventConstraint
ClosedAction    = disjoint union of named ClosedBranch relations
```

Semantic support and operational access traces may be checked against the
syntactic upper bound, but cannot enlarge it.

### B5: Safety can be made vacuous

`InitNonempty` is defined but not a mandatory premise of every claim decision.
The phrase admitted trace does not distinguish all base executions from traces
filtered by progress assumptions. Safety could be checked only on a fair subset
that removes an attack trace.

F0 must define `Exec(Model,I)` independently. Safety ranges over all executions.
An assumption-qualified trace set is used only by the exact progress/timed
claim that names it. Every claim judgment includes required nonvacuity premises.

### B6: Hostile behavior can be narrowed by the candidate

Requiring an action-family name does not ensure that `HostileLinux` models all
operations reachable after kernel compromise. A candidate can use a harmless
self-loop, narrow guard, or small footprint.

F2/F3 must own a `CompromisedStep(principal)` over-approximation. It is enabled
whenever that principal is compromised and havocs every state/observation not
physically excluded by the Monitor/platform contract. Candidate actions may
refine it only after proving inclusion; they cannot shrink it.

### B7: Abstract-state omission hides attacks

Frame closure protects only declared state. Omitting direct maps, translation
state, TLBs, IOMMU, DMA, IRQ/NMI, firmware, device queues, per-CPU globals,
cache/predictor state, or an observation channel removes the corresponding
attack from the model.

F2 needs a physical coverage ledger and abstraction/concretization relation.
Every relevant machine component is represented, proved unreachable from the
attacker, or recorded as a claim-blocking assumption/nonclaim. Unknown state
fails closed.

### B8: Progress and fairness are not claim semantics

Family fairness permits one request to starve while another is repeatedly
served. Fairness over too many continuously enabled parameters can make the
fair-trace set empty. Rank classification permits infinite decrease/increase
oscillation.

F1 must define request-correlated response, exact instance/family fairness,
`FairExecNonempty`, well-founded rank relations, bounded or impossible rank
increase, terminal enabledness, and fairness feasibility. Hostile Linux and an
asynchronous network receive no fairness. Monitor-owned progress and service
curves are separate provider assumptions or guarantees.

### B9: Time is not represented

Step count is not elapsed time. Stutter, stopped clocks, rebooted clock epochs,
reused conversion receipts, and Zeno traces remain possible. F1 must define
timed traces, monotonic/divergent clocks, uncertainty composition,
incarnation-bound conversions, bound-linearization events, provider response
bounds, and the exact availability assumptions under which a real-time result
holds.

### B10: Crash/durability is not represented

A visible effect may execute, crash before durable deduplication, recover, and
execute again. Lists of durable groups and cuts do not define stable/volatile
state or a durable happens-before relation.

F1 must give durable and volatile projections, flush/order actions, generated
cut states, crash transition, recovery transition, re-crash closure, external
visibility rules, and idempotence/at-most-once obligations.

### B11: Distribution and refund are underspecified

A source action can read remote mutable destination state as an oracle. A
finite timeout cannot establish that a delayed export will never install.
Partitioned safety and refund availability cannot both be unconditional.

Remote authority decisions may consume only authenticated immutable receipts.
Refund requires an irreversible destination fence/revocation proof or an
explicit quorum/consensus assumption. Safety remains unconditional over message
drop/duplicate/reorder/replay; success availability is qualified by named
connectivity and membership assumptions.

### B12: Composition is absent

Two locally safe lanes can each consume a replicated root credit and violate
global conservation. F1 needs state/action composition, synchronization sets,
shared-authority ownership, conflict and commuting-diamond obligations,
fairness lifting, and rely/guarantee discharge. Product composition by itself
does not preserve conservation or progress.

### B13: Noninterference and robust integrity are open

The v3 noninterference section allows an empty initial relation, empty coupling,
constant low observation, or universal declassification. It does not fix
quantifier order, strategy coupling, stutter alignment, termination, or timing.
Writer ACLs also do not establish robust integrity against compromised services
or confused deputies.

F1 must define paired reachable initial states, nonconstant observation
adequacy, total/productive public-strategy coupling, weak-stutter alignment,
trace-observation comparison, restricted authority-scoped declassification,
and explicit timing/termination modes. A separate robust-integrity module owns
endorsement, provenance, attenuation, and compromise coalitions.

### B14: Platform concurrency and raw interfaces are open

Sequential interleaving does not by itself cover multicore weak memory,
speculation, IRQ/NMI, DMA, raw Monitor bytes, decode failure, cryptographic
forgery, key compromise, or replay. F2 must model them or bind a narrow platform
assumption/refinement that justifies their abstraction.

### B15: Finite/general derivation and backend evidence are open

A finite counterexample refutes a general claim only when the finite instance
belongs to the quantified model class and preserves all claim premises. A
counterexample-free finite run remains bounded evidence. Symmetry, induction,
and refinement require explicit scope-widening rules.

Backend agreement is not proof. Source-level counterexamples may be replayed in
the normative semantics. Positive bounded safety needs an accepted VC/certificate
path; liveness needs fairness/rank proof objects; a TLA/TLC no-counterexample
result alone cannot support a positive source claim.

### B16: K0 source-set and trust closure are absent

The three v3 artifacts are not the complete ADR-0018 K0 input. Missing inputs
include policy templates, threat/action basis, scenario/cut/mutation generators,
claim catalog, proof policy, certificate formats, externally fixed trust root,
and a K0-specific verifier transition. Candidate source, campaign capsule, and
finding catalog must be separated to avoid identity cycles.

## Successor Architecture

ADR-0019 separates the successor into:

| Layer | Content | Promotion condition |
| --- | --- | --- |
| F0 | typed calculus, model, executions, safety, nonvacuity | exact metatheory and hostile review |
| F1 | progress/time/durability/distribution/composition/relational claims | module denotation, projection, composition, mutants |
| F2 | physical refinement, compromised steps, topology, platform threat surface | coverage/refinement and coalition closure |
| F3 | externally owned templates, action basis, generators, claims, proof and trust policy | immutable complete source set and external K0 decision |

This is decomposition, not weakening. No F1 claim may silently assume an F2
boundary; no F2 abstraction may invent an F0 action; and no F3 review artifact
may provide semantics missing from F0-F2.

## Disposition

```text
v3 structural inventory             PASS, local only
v3 mathematical closure             REJECT
v3 claim-extension closure          REJECT
v3 platform/threat refinement       ABSENT
v3 K0 source-set/assurance closure  ABSENT
v3 external authority               ABSENT
K0/G0                               false
candidate construction              unauthorized
semantic freeze                     false
TLA+/backend translation            unauthorized
model support                       false
Linux/Monitor implementation        out of scope and unauthorized
```

The next allowed work is F0 v4 design and local hostile review. It is not K1
candidate construction.
