# Dynamic Residency R11 G0 v1 Rejection and Epoch-2 Semantic Kernel

## Status

The exact R11 G0 v1 candidate is locally rejected before external review.
R11 G0 epoch-2 architecture work is authorized. Machine-source construction,
semantic freeze, TLA+, model support, Linux behavior change, and every
protection or deployment claim remain unauthorized.

The machine-readable disposition is
`dynamic-residency-r11-g0-v1-rejection-and-epoch2-kernel-v1.json`.

## Exact Rejected Snapshot

```text
candidate manifest path
  capsched-models/policy/r11/g0-candidate-bundle-v1.json
manifest bytes
  7073
manifest sha256
  bcdd6c26c5a651f7630df5d218cbd6fb2f20922e2e03cdf109b68b69a7250037
captured artifacts
  17
declared exact mutations
  12/12 rejected at their expected structural/protocol locations
```

This snapshot is retained byte-for-byte. Its passing result means that the
local snapshot, references, hashes, and declared checks are internally
consistent. It does not mean that the named semantics are defined or that a
positive review decision would be trustworthy.

## Fresh Hostile Review

Three role-separated, read-only reviews first verified the exact manifest
digest and independently returned `LOCAL_ADVISORY_REJECT`:

| Review axis | Exact-digest check | Authority | Verdict |
| --- | --- | --- | --- |
| security and trust boundary | pass | local advisory | reject |
| formal encodability and proof closure | pass | local advisory | reject |
| scenario, scale, and composition | pass | local advisory | reject |

These reviews are not external attestations. They are design input and negative
evidence only. Their findings normalize to twelve blockers.

### B1: Undefined semantic templates

All 73 `canonical_template` and `candidate_binding_schema` values are names.
No external artifact defines their parameter signatures, typing contexts, or
formulas. Two independent encoders could produce incompatible models while
claiming to implement the same registry.

### B2: Prose provider and progress contracts

Provider triggers, prestates, success relations, fault partitions, bounds, and
fairness classes are nonempty strings. Invariants have names rather than
formulas. Progress has no executable trigger/rank/action relation. Resource
units and consistency-domain axes are likewise unconstrained labels.

### B3: Ambiguous branch and join semantics

The D11-D14 prose does not define whether predecessor lists are conjunction,
alternatives, or mere documentation. A `NeverEntered` retry appears to require
an entered observation if D14 conjunctively depends on D12 and D13. If the
edges are alternatives, no operator defines that fact.

### B4: Missing exact settlement writers

The required settlement product names `BoundaryReceipt`, `StopReceipt`,
`OverheadReceipt`, and `ChargeMeasurementReceipt`, but no exact provider/action
map assigns the authoritative writer and linearization point for each product.
A broad state class is not a product-to-writer partition.

### B5: Untyped cross-domain identity and conservation

Several consistency-domain axes are undeclared strings. Fenced export,
destination install, import, acknowledgement, refund, and one-use consumption
do not yet form a typed state machine with exact source and destination writers.

### B6: Witness mappings are labels, not true traces

Rules map cross-domain async and settlement obligations to profiles that do not
contain the required remote action, destination ledger apply, or subject
lifecycle transition. A witness ID can be swapped without changing acceptance.

### B7: Vacuous scenario profiles

Seven semantically used dimensions can be set to zero without rejection.
Actions and outcomes can be renamed to meaningless strings, witness mappings
can be swapped, and profile/action assignments can be rotated while preserving
checker acceptance.

### B8: No executable composition obligation

Modes are mostly isolated profiles. Required cross-feature products are not
generated. For example, a nominal safe-gap or continuity-loss transfer profile
can retain a local-only partition mode while still naming a partition action.

### B9: No derived cuts or reachability

Cut generation is future prose. There is no durable typed action registry,
enabledness predicate, antecedent-reachability witness, or equality check
between generated cuts and the required cut set.

### B10: Incomplete hostile campaign

The exact campaign covers only a small subset of declared policy/profile
weakening classes. Checker-skip and stale-review use synthetic protocol
fixtures rather than mutating the real checker invocation and real receipt
chain.

### B11: Forgeable review and gate acceptance

The schemas allow failed and duplicate checks, open blockers with a zero count,
duplicate review roles, one principal in every role, and a positive gate with
failed checks. No review-set schema, external authority registry semantics,
canonical signed payload, or executable promotion verifier closes those gaps.

### B12: Local consistency is not external authority

The policy, schema, checker, catalog, runner, and manifest remain under one
local change authority. A separate directory, process, AI context, or role name
does not establish independence.

## Executable Counterexamples

Two deterministic negative tests convert the review into replayable evidence:

```text
test-r11-g0-semantic-vacuity.py
  script sha256  dc8935f4b6a59229a65f60c68d9d444f0a484731a219b68b3aa52e5f9218f3d7
  output sha256  d5f6900e21aaab2175aaed34a2b6e41cf2a928907a6dc0fd53ff737bd9068042
  result         12/12 semantic weakenings accepted

test-r11-g0-review-gate-schema-vacuity.py
  script sha256  2592662a01c7bf82da273b6f09773ca97d044e1639b003cf9d58d8847787733f
  output sha256  0e6c61b1a62252f3c38e1d9167d84c651030bc0002a5ea06cb03c097aba7ec69
  result         5/5 forged-positive documents accepted by their schemas
```

Each output was reproduced byte-identically twice. Acceptance is the failure
condition: it proves the current checker or schema does not observe the
weakened meaning.

## Why Patching v1 Is Rejected

An in-place repair would invalidate the exact 17-artifact review target while
leaving its name and prior passing record intact. More importantly, adding
stronger regexes or more required strings would preserve the same category
error: syntax would still stand in for semantics. R11 therefore advances to a
new G0 epoch while preserving the v1 bytes and negative evidence.

## Epoch-2 Semantic Authority

Epoch 2 separates five kinds of authority that v1 partially conflated:

| Layer | Normative owner | Candidate may do | Candidate may not do |
| --- | --- | --- | --- |
| language kernel | external policy authority | reference language version | add operators or reinterpret typing |
| semantic templates | external policy authority | bind typed holes | replace formulas or success criteria |
| architecture IR | candidate | define concrete state and action relations | assert proof or promotion |
| proof/evaluation | pinned independent tools | emit checked receipts | infer omitted semantics |
| promotion | external gate authority | receive a decision | select reviewers or self-promote |

External here means outside the candidate change authority and rooted in a
gate-selected authority registry. A project-authored draft may be built and
locally attacked, but it remains a draft until that external boundary exists.

## Backend-Neutral Typed Kernel

The external kernel is a small many-sorted transition logic represented only
as strict JSON AST. It has no embedded TLA+, SMT, Python, shell, or natural
language expressions.

### Sorts

```text
Bool
bounded Nat with an explicit unit and upper bound
finite Enum
opaque finite Identity with generation and namespace kind
Option<T>, Product<T...>, Vector<ResourceComponent>, Set<T>, Map<K,V>
```

Every identity and consistency-domain coordinate has a declared sort. Numeric
comparison and arithmetic require equal units. Checked addition and guarded
subtraction are distinct operators; overflow and underflow are explicit
outcomes.

### Formula contexts

```text
STATIC       constants and type relations only
STATE        current state only
GUARD        current state plus typed action parameters
TRANSITION   current and next state plus typed action parameters
INVARIANT    universally quantified current-state predicate
RANK         well-founded bounded tuple over current state
TEMPORAL     restricted trigger/response schema over named actions
```

The type checker rejects primed symbols outside `TRANSITION`, state symbols in
`STATIC`, unbounded quantification, unit mismatch, partial map access without a
guard, undeclared functions, and context-dependent impure expressions.

### Operators

The kernel supplies a deliberately small closed operator set: Boolean
connectives, typed equality/order, bounded quantifiers, membership, product
projection, map lookup/update, set insertion/removal, checked numeric/vector
operations, `old`/`next` state references in transition context, and explicit
finite choice. Every backend must prove or test conformance against the same
operator corpus before its proof receipt is accepted.

## External Template Library

Every `SEM-*` rule resolves to an object containing:

```text
template id and digest
typed hole signature
allowed formula context
normative formula AST
required action and state-product roles
generated proof-obligation constructors
required reachability antecedents
required semantic mutation operators
claim and non-claim projection
```

A binding maps each hole to one declared candidate symbol of a compatible type
and context. Bindings are total, injective where the template requires distinct
roles, and acyclic. The materializer substitutes holes mechanically. It never
chooses a formula from a template name and never accepts candidate-supplied
backend source as the template meaning.

## Concrete State and Writer Products

State ownership is defined per concrete product, not per broad class. Each
entry records:

```text
product sort and key
authoritative owner role
consistency-domain key function
genesis origin or Vacant state
exact writer action set
atomic write product and linearization point
reader set and visibility rule
write-once/monotonic/reusable discipline
failure successor and reconciliation action
```

The compiler derives exact frame conditions: every action must write exactly
its declared products, and all other products remain unchanged. The settlement
map must assign separate authoritative writers for entry, boundary, stop,
overhead, measurement, settlement-root, and ledger-apply receipts.

## Explicit Branch Semantics

D0-D17 remain architectural landmarks, not an executable dependency language.
The action registry defines control flow. Entry preparation has an explicit
sum outcome:

```text
PrepareEntry
  -> CommitEntered(EnteredReceipt)
  |  AbortNeverEntered(NeverEnteredReceipt)

CommitEntered
  -> ObserveEntered
  -> BoundaryOrStop
  -> SettlementRoot
  -> LedgerApply
  -> EnteredTerminal

AbortNeverEntered
  -> ReleaseOrRefundReservedProducts
  -> NeverEnteredTerminal

EnteredTerminal | NeverEnteredTerminal
  -> FreshRetry or NextOccurrence under a newer ordinal
```

No retry depends on an entered observation. A graph edge cannot silently mean
both conjunction and alternative; each action guard names its required prior
state and receipt.

## Provider Contracts

A provider contract is an executable assume/guarantee record:

```text
typed trigger and admissible precondition
exact owned products and single writer actions
success transition relation and immutable receipt
total disjoint fault partition
fail-closed successor relation
frame condition
finite work/time/overrun bound with a declared unit
named trusted fairness actions only
consumer obligation ids
```

Provider genesis facts use a separate sealed-bootstrap template. Runtime
receipts begin `Vacant`; a candidate cannot satisfy an obligation by placing a
success receipt in Init.

## Safety, Progress, and Noninterference

Invariants contain executable AST and are checked simultaneously. A preserved-
by list is only an obligation declaration; proof receipts must discharge
`Init => Inv` and `Inv /\ Action => Inv'` for every concrete action.

A progress obligation contains a reachable typed trigger, a success predicate,
a well-founded rank or finite deadline, allowed stutter actions, named trusted
fair actions, adversarial actions, and an exact bound unit. External withdrawal,
rejection, fail-stop, and service success are separate outcomes. A liveness
claim cannot count authority withdrawal as successful service.

Noninterference obligations identify high and low projections, declassification
events, observation functions, scheduler/timing leakage policy, and paired
execution assumptions. They are not inferred from a generic `Domain` label.

## Scenario and Cut Semantics

The scenario layer imports the same typed signature and action registry. A
profile is a finite valuation plus relation constraints, initial-state
constructor, action-availability set, expected terminal partition, and exact
obligation set. Names alone have no effect.

The profile compiler must generate a mandatory interaction basis including:

```text
sync and async-distinct and async-aliased x revoke/cancel
prepare/claim/commit/stop/settle x CPU offline and provider failure
each settlement receipt x crash/restart and duplicate delivery
strong/safe-gap/continuity-loss transfer x partition and restart
namespace exhaustion/rekey x stale references and late receipts
two lanes x shared resource pressure and one-lane failure
two nodes/clusters x partition, clock uncertainty, fence, import, recovery
management bootstrap x tenant admission and management compromise
```

Cuts are derived at every durable write and externally visible
linearization point. Required cuts must equal the generated set for each
transaction family. Every invariant and progress antecedent needs at least one
reachable positive witness; every safety family needs a mutation that creates
a reachable violation.

## Cross-Consistency-Domain Transfer

The distributed protocol uses typed one-use records:

```text
source reserve -> source fence/no-reissue -> quiescence or conservative horizon
-> immutable destination-bound ExportReceipt -> in-transit conservation bucket
-> destination verify -> idempotent ConsumeReceipt -> destination install
-> acknowledgement and source terminalization
```

Refund is permitted only through a typed proof that destination installation
never occurred and can no longer occur. Silence is never that proof. Source,
destination, export, consume, epoch, horizon, and resource-vector identities
are all part of the receipt type. No action writes mutable state in two
consistency domains atomically.

## Promotion Semantics

Epoch 2 requires schemas plus an executable verifier. The authority registry
is selected outside the candidate and maps roles to credentials and separation
constraints. A review set binds one exact candidate digest to an exact unique
role/principal/authority tuple set. Review receipts bind canonical payloads and
all assigned check results.

For `accept`, the gate recomputes:

```text
required check set == unique passed result set
required review-role set == unique verified receipt-role set
all assigned checks appear exactly once
all blocking findings are closed and the count equals the findings
candidate author, reviewers, gate authority and required organizations are
  disjoint according to the external registry
every predecessor digest and anti-rollback epoch is current
every detached signature verifies over the canonical payload
the real checker and real receipt chain survive checker-skip and stale-review
```

JSON Schema remains a shape prefilter. It is never the promotion decision.

## G0 Epoch-2 Exit Conditions

G0 may become true only after all of the following hold together:

1. The typed kernel and conformance corpus are externally pinned.
2. Every policy rule, provider contract, invariant, progress property, and
   scenario primitive has executable semantics.
3. Every candidate binding is total, type-correct, context-correct, and cannot
   redefine its template.
4. Product writers, CD keys, branches, settlement, and transfer are exact.
5. Mandatory scenario interactions and derived cuts are complete and reachable.
6. The mutation campaign instantiates every declared semantic weakening and
   attacks the real checker and review chain.
7. Fresh authority-disjoint reviews bind the final candidate bytes.
8. An independently rooted promotion verifier issues a valid gate decision.

Until then:

```text
G0                              false
R11 machine-source construction false
semantic freeze                 false
TLA+ translation                false
model support                   false
Linux behavior change           false
protection claim                false
```

## Immediate Next Artifact

Construct only the epoch-2 semantic-kernel contract and its hostile conformance
corpus in a new `capsched-models/policy/r11/epoch2/` namespace. Do not create
Formal 0150 or translate D0-D17 until the complete epoch-2 G0 bundle has passed
its real external gate.
