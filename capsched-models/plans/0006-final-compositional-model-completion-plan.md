# Plan 0006: Final Compositional Model Completion

Status: Active; supersedes model-complete scheduling optimization as the
critical path

Date: 2026-08-10

## Objective

Complete a compositional semantic model of the hostile-kernel,
process-through-container, monitor-backed, multi-cluster DomainLease-Linux
architecture before promoting another Linux scheduling mechanism.

This plan implements ADR-0012 and Analysis 0185. It does not discard existing
models. It supplies the missing system contracts between them.

## Exit Condition

The plan is complete only when all of the following are true:

```text
ROOTSCHED-001 closed
RESIDENCY-001 closed
RESIDENCY-DYN-001 closed
ENTRY-001 closed
CODE-001 closed
STATE-001 closed
SVC-001 closed
MGMT-001 explicitly modeled or bounded by an accepted threat assumption
CLUSTER-PART-001 closed
COMPOSE-001 closed
GRANULARITY-001 has a complete-path evaluation contract
EVIDENCE-001 closes positive-evidence provenance
```

Closure means more than a checklist boolean. Each requirement needs a human
contract, machine-readable record, formal or otherwise executable semantics,
negative cases, and an assurance mapping.

## Architecture-First Formalization Rule

ADR-0015 fixes the order for every remaining component:

```text
claim and non-claim scope
  -> current source/architecture constraints
  -> identity, authority, lifecycle, and conservation model
  -> threats, failures, impossibility, scale, and composition
  -> independent hostile contradiction/minimality review
  -> semantic freeze
  -> decomposed TLA+/other executable specification and mutants
  -> claim-specific validation and decision
```

TLA+ is the final executable expression of a reviewed architecture contract,
not the initial architecture generator. A counterexample reopens the semantic
contract; it is forbidden to obtain a passing model by weakening the target or
granting fairness to adversarial Linux. Provers and validators serve the
security objective and do not replace it.

ADR-0018 and ADR-0019 refine this order for R11. Before candidate architecture
construction, the pre-candidate K0 foundation closes in four layers:

```text
F0 typed transition calculus and metatheory
  -> F1 claim-specific semantics and composition
  -> F2 physical/platform refinement and threat over-approximation
  -> F3 external policy, generators, mutations, proof and trust policy
  -> external K0 decision
  -> K1 candidate construction
```

A local validator or advisory review cannot substitute for the external K0
transition. Claim modules cannot hide missing physical attack state, and
fairness-qualified progress traces cannot remove safety counterexamples.

## Phase A: Evidence and State Trust

Purpose:

```text
make future positive decisions depend on captured evidence rather than on the
producer's mutable workspace or summary
```

Deliverables:

1. Evidence Capsule v1 contract.
2. Producer/validator role separation.
3. Validator-owned capture-before-read rule.
4. Transitive manifest for source, config, tool, command, image, raw output,
   and derived result.
5. Revalidation classification for existing positive gates.
6. Compact HEAD-fresh AI state with a machine check.

Gate:

```text
no new positive promotion gate may consume uncaptured producer summaries
negative evidence and counterexamples remain usable with explicit provenance
```

Current status: the compact state check and minimal Evidence Capsule v1
Collector/structural Verifier are complete. ROOTSCHED-001 and RESIDENCY-001
have separate claim-specific EC1 Validators and approval bindings.
EVIDENCE-001 remains open because historical migration and EC2/EC3 evidence do
not yet exist.

## Phase B: Root Execution and Scale

### B1: Adversarial Root Scheduler

Current status: closed at Model-supported EC1 by Analysis 0187, Formal 0147,
and Validation 0288. Production policy refinement, implementation, wall-clock
bounds, and protection remain outside this model closure.

Model the Linux scheduler state as attacker-controlled after Domain compromise.
The Monitor must independently enforce:

```text
root lease admission
root budget/deadline expiry
bounded overrun
handoff away from an expired or revoked Domain
eventual service for another eligible guaranteed Domain
reserved management/recovery service
```

The model must distinguish safety from availability:

```text
safety:
  an unauthorized Domain does not run

liveness:
  an admitted guaranteed Domain is not permanently suppressed by Linux
```

Expected tool: TLA+ with explicit weak/strong fairness assumptions limited to
Monitor and hardware actions. Do not assume fairness from adversarial Linux.

### B2a: Finite Bounded-Residency Reference

Current status: Model-supported at EC1 by Analysis 0188, Formal 0148, and
Validation 0289. The accepted claim is limited to a fixed finite
Monitor-pre-admitted population and one modeled request per guaranteed Domain.
It does not close the broader dynamic-residency requirement.

### B2b: Dynamic Admission and Recurring Residency

Current status: the exact pre-formal candidate `24bb1320...174f` passed its
finite internal checks but was rejected by Analysis 0199 and Validation 0292.
The materialized R6 v2 successor `24887ac2...a62d` was then rejected by
Validation 0293 after four hostile reviews and a strict-baseline proof-ledger
failure. The exact R7 pre-IR snapshot `6d08ec43...e8ec` was rejected by
Analysis 0205 and Validation 0294 with 41 normalized blockers.

Analysis 0206 contained a clean R8 human architecture candidate. It added
protected persistence, a local-only publication consistency domain, a
protected ready state and scheduler portal, context/residency/dispatch
granularity, exact RunAuthorization/SchedContext/charge authority,
same-activation-only resume, a CPU-enable entry root, service-threshold
linearization, generation-safe failure closure, and an honest quorum
no-reissue transfer boundary. Four exact hostile reviews nevertheless returned
`IR_ENCODING_READY=NO` and `FREEZE_NO` for `4f30f2b8...7b5b`. Analysis 0207
and Validation 0295 normalize 54 raw findings to 40 R8-local blockers and fix
the clean R9 redesign boundary. R8 is rejected, no machine IR or witness has
been accepted, and TLA+ remains unauthorized.

Analysis 0208 then materialized the R9 discovery candidate with 77 mutable-cell
kinds, 138 action names, 43 crash cuts, 29 invariant names, and a 21-node proof
DAG. Four fresh exact reviews of `f7e9f3df...11362` nevertheless found that
those registries were not a closed transition system: state domains and Init,
immutable-object existence, exact schemas and formulas, location-level action
effects, writer authority, deterministic recovery, dispatch causality, and
several distributed lifecycles remained open or contradictory. Analysis 0209
and Validation 0296 preserve 78 raw findings and normalize them to 42 R9-local
blockers. R9 is rejected. R10 must use a typed machine IR as the normative
source, pass structural/witness/mutation checks and a new exact hostile review,
and only then may authorize TLA+ translation.

R10 Formal 0149 subsequently demonstrated useful typed-AST, transaction,
materialization, witness, and structural-mutation machinery. Exact structural
campaigns killed 29 mutants, but Analysis 0212 and three independent hostile
reviews found that candidate-controlled claims, formulas, proof-name nodes,
provider contracts, roles, partitions, bounds, blocker evidence, and mutation
oracles permit semantic self-certification. Thirteen of thirteen locally
executed semantic-vacuity variants were accepted, 26 of 42 blockers remained
`PENDING-*`, Init bypassed management bootstrap, and physical entry was
unreachable. ADR-0016 and Analysis 0213 therefore reject R10 and authorize a
clean policy-derived R11 successor. R11 must complete its modular D0-D17
architecture and W0-W12 witness set before semantic freeze; TLA+ remains the
post-freeze executable translation.

The first R11 G0 candidate then passed exact local byte-integrity and 12
declared structural/protocol mutations, but it did not close semantic meaning.
Three fresh local hostile reviews rejected it; 12/12 semantic weakenings and
5/5 forged-positive review/gate documents were accepted by the current
checker or schemas. ADR-0017, Analysis 0214, and Validation 0303 retain that
exact v1 snapshot as negative evidence and require a clean G0 epoch 2 with an
executable external typed-semantic kernel. Formal 0150 remains unauthorized.

The first epoch-2 v2 language inventory was rejected before interpreter work by
ADR-0018, Analysis 0215, and Validation 0304: it had no independent denotation
and mixed foundation, candidate, review, and proof gates. The exact v3
denotational successor then passed deterministic local structural checks, but
four exact-hash local reviews rejected it. Analysis 0216 and Validation 0305
record incomplete model/action/frame typing, vacuous progress and relational
claims, prose-only time/durability/distribution/composition, missing
abstract-to-physical refinement, candidate-narrowable compromise behavior, and
an absent complete K0 source set. ADR-0019 therefore retains v3 unchanged and
authorizes only F0 v4 design. F1-F3, external K0, K1 IR, and Formal 0150 remain
unauthorized.

The exact first F0 v4 target then passed deterministic identity checks and
21/21 structural/authority mutations, but all four exact-hash local reviews
rejected its semantics. Analysis 0217 and Validation 0306 preserve the
unconstructible event grammar, parameterized-state-invariant type error,
candidate-owned action omission, undefined infinite read trace, nested-map
granularity collapse, empty model-class and cross-profile nonvacuity, single
event composition, and projection-without-morphism counterexamples. ADR-0020
authorizes only F0 v5 with a fully expanded core grammar, all-action closure,
finite typed patches and event channels, three well-formedness levels,
claim-bound nonvacuity, separate extension/platform morphisms, and an F0-fixed
proof-object/checker boundary. F1 remains blocked.

The first F0 v5 machine draft passed only shape checks and 38/38 structural
mutations. Analysis 0218 and Validation 0307 reject it for representation and
semantic-parity gaps. The successor now has a canonical wire, immutable
byte-only `WireValidatedModelSnapshot`, source static checker, deterministic
LinkedModel construction, seven typed construction-ID preimage policies, and a
local source-byte cross-implementation reconstruction. Analysis 0219 and
Validation 0308 close this substage with 61 grammar, 83 static-rule, 23 wire,
51 Core, 56 link-field, and 21 cross-verifier hostile cases. This does not
promote `CoreSyntaxWF` by itself. Analysis 0220 through 0225 subsequently add
checked evaluation and three supervisor generations while retaining each
rejected predecessor as negative evidence. Analysis 0226 and Validation 0313
record Candidate-4 as a restartable pre-full local checkpoint: child 274,
parent 715, and runner 44 hostile regressions plus the fast validator pass.
The full child/parent reachability and declared-commutation claims remain
`NOT_RUN`; component receipts are candidate-validator observations checked for
internal consistency by a same-UID runner, not authority-disjoint evidence.
External review, F0 acceptance, K0/G0, candidate IR, semantic freeze, Formal
0150, TLA+, Linux behavior, and protection claims remain unauthorized.

`RESIDENCY-DYN-001` remains open; ADR-0014 makes this split mandatory, and
finite EC1 evidence cannot close B2b. All rejected digests remain regression
targets rather than inherited normative input.

Model more global Domains than per-CPU slots. Include:

```text
stable DomainKey and issuer-owned epoch
boot-fixed NodeConfig and bounded hierarchy/ancestor capacity
slot generation
admit, reject, evict, and reuse
running and referenced-slot quiescence
cross-CPU migration
parent-conserved physical CPU execution cells and target-local control turns
CPU hotplug
typed partition lease import and globally fenced exclusive placement
guaranteed versus best-effort classes
churn and overflow
total failure cover with admission-charged reverse-edge cleanup
non-executable activation intent and joint ENTRY/CODE/STATE commit receipt
complete normalized authority horizon and independent watchdog
publication-fenced failure least fixed point and cover-ancestor cleanup charge
boot-root management/recovery bootstrap capacity
```

The model must refine all B2a invariants while adding Monitor-owned feasibility
admission/rejection, recurring request identity and cancellation, bounded
coalescing and churn work, explicit overflow behavior, and safe generation
saturation through scoped namespace renewal or terminal quarantine. R6 is
accepted only as a local refinement candidate if its
slot and selector actions refine both B2 stages.

B2b closure additionally requires the following decomposed executable
instances; no single-lane result can substitute for them:

```text
DYN-ADMIT: NodeConfig/hierarchy authority, ancestor capacity, admission,
           conflict-local feasibility, and publication
DYN-REQUEST: request identity, coalescing, cancellation, and member disposition
DYN-CHURN: bounded work, overload, total failure cover/cleanup, recovery, and
           target-control service
DYN-SHARD: at least two plan shards/lanes under conserved physical control and
           CPU execution parents, with commuting actions
DYN-RENEW-RESTART: typed partition lease import, management bootstrap, clocks,
                   restart, namespace, and typed receipt renewal
DYN-COMPOSE: ActivationIntent, complete ExecutionContextKey/receipt set, joint
             ActivationCommitReceipt, and one bounded full composition
DYN-MULTILANE-COMPOSE: two live lanes plus shared control/failure/transfer work
DYN-LIVENESS-THEOREM: unbounded recurrence induction under exact relies
DYN-REGRESSION: migration, hotplug, revoke, replication, GlobalPlacementUse,
                and quorum-supersession horizon
```

Before those TLA+ instances are translated, the architecture capsule must
freeze an acyclic proof-dependency DAG and component assume/guarantee ledger.
Every internal rely must point to a predecessor guarantee; only explicitly
named CLUSTER/ISSUER/TIME/ENTRY/CODE/STATE interfaces may remain external.
`Operational` and descendant liveness guarantees may not be assumed to prove
their own predecessors.

`DYN-SHARD` is a semantic scale gate, not a benchmark. It must demonstrate
that disjoint control-plane transition publication, local boundary apply,
stop, expiry-cleanup, and failure actions commute; that tentative or committed-
pending plan entries cannot execute; that an already committed transition
cannot be revalidated, rejected, or rolled back at local apply; that local apply
never waits for another shard; that exclusive placement commits
destination only after an exact source-quiescence receipt; that one lane cannot
block another lane's protected progress; and that a selected accepted,
authorized, feasible nonconflicting control operation commits. Cross-node
destination activation may instead use a typed quorum supersession
only strictly beyond the predecessor's maximum executable horizon, uncertainty,
and stop bound; network silence is never quiescence. Lane independence also
requires distinct parent-reserved physical CPU cells, and one shard turn can
advance at most one exact target turn. A pre-formal
two-lane architecture witness must establish the ownership and rely/guarantee
shape before semantic freeze. Executable `DYN-SHARD` and
`DYN-MULTILANE-COMPOSE` follow that freeze and remain mandatory before B2b
closure. The architecture contract and executable instances must
also state and preserve these
asymptotic/locality bounds:

```text
candidate validation and storage: O(NodeConfig-bounded affected lineages,
                                     shards, proof size, and hierarchy depth)
lease expiry authority invalidation: O(1) shared record update plus
                                     O(active affected lanes) stop work
pure lease extension: O(1) shared record update; no admission/plan republish
ordinary release and settlement: no scan over all admitted Domains
local namespace exhaustion: no whole-node epoch renewal or disjoint-lane stop
scoped failure: no disjoint-lane stop or unbounded audit allocation while fenced
failure authority point: O(KFailureClosureEdges + KFailureClosureScopes *
                         KDepth) through a NodeConfig-bounded least fixed point,
                         or pre-reserved node fail-stop
failure cleanup: incremental over at most the selected cover ancestor's
                 admission-charged aggregate reverse edges and cleanup
                 reservations with protected service, no population scan
namespace wear: sponsor-conserved; best-effort cannot force peer renewal
```

These are structural bounds over modeled ownership and transition footprints.
They are not latency, throughput, memory-size, or cost claims.

Expected tool: TLA+ for temporal behavior; Alloy may be used as a bounded
structural cross-check for identity/slot aliasing, but is not required.

## Phase C: Privileged Address-Space Integrity

### C1: Entry, MemoryView, and Translation

Compose activation with syscall, exception, IRQ, NMI-class entry, nested entry,
stacks, per-CPU state, TLB, and return. Model stale, reordered, duplicate, and
interrupted transitions.

Key properties:

```text
NoEntryWithWrongView
NoEntryStackCrossDomain
NoNestedEntryEpochConfusion
NoReturnToRevokedView
NoStaleTranslationAfterOwnershipTransfer
```

### C2: Executable Integrity

Model shared read-only executable pages, W^X, code epochs, and controlled
mutation for modules, livepatch, alternatives/static keys, tracing probes,
text pokes, and JIT pages.

Key properties:

```text
NoDomainWritableSharedExecutable
NoExecuteBeforeSeal
NoOldCodeEpochAfterCommit
NoLinuxMintedExecutableProvenance
```

Expected tools: TLA+ for transitions; later architecture-specific page-table
tests and LKMM litmus tests for publication/invalidation ordering.

## Phase D: State, Services, and Management

### D1: Exhaustive Mutable-State Ownership

Create an ownership algebra for privileged mutable pages and objects. Unknown
classification is an error, not shared Linux state.

The model must include allocator metadata, stacks, credentials, fd tables,
VFS/page-cache state, network state, async queues, and device metadata as
representative classes. It need not enumerate every Linux type in TLA+, but the
refinement ledger must map every implementation allocation family to an owner.

### D2: Compromised Service Domain

Assume arbitrary kernel-context execution inside one service Domain. Prove that
its effects remain limited to typed endpoint operations, explicitly shared
buffers, service-local objects, caller-frozen authority, and budgets.

### D3: Management and Recovery

Separate:

```text
offline signing root
online cluster control plane
node-local Monitor
management Domain
recovery/break-glass authority
```

Record which compromise cases are prevented, contained, recoverable, or out of
scope. Do not hide all of them behind one trusted-root sentence.

## Phase E: Multi-Cluster Failure Semantics

Model at least two clusters, multiple nodes, delayed/reordered/duplicated/lost
messages, a network partition, local monotonic clocks with declared drift
bounds, node restart, and migration.

Required decisions:

```text
lease signature and delegation chain shape
maximum offline lease duration
renewal and expiry rules
epoch/quorum recovery rule
fencing token and ownership transfer rule
global Domain/endpoint namespace uniqueness
source/destination migration non-duplication
partition behavior by workload class
```

Required non-claim:

```text
instantaneous global revocation and unrestricted partition availability are
not both promised
```

Expected tool: decomposed TLA+ models with symmetry and bounded topology. Use a
separate refinement model instead of retrying an unbounded monolith.

## Phase F: Composition and Refinement

Create a machine-readable component contract ledger. Each row records:

```text
component id
owned variables
read-only dependencies
trusted actions
adversarial actions
assumptions
guarantees
failure/recovery actions
refinement mapping
consumers
unresolved incompatibilities
```

Then build cross-component models for the six compositions listed in Analysis
0185. `COMPOSE-001` closes only when:

1. Every assumption is discharged by a named guarantee or accepted threat
   assumption.
2. No variable has conflicting owners.
3. No Linux-visible shadow is promoted to Monitor authority.
4. Revocation and failure actions compose without stale carrier escape.
5. Safety and required liveness properties survive adversarial Linux actions.
6. The architecture objects have refinement mappings to eventual Linux and
   Monitor implementation surfaces.

TLAPS may be introduced for stable inductive invariants. Apalache may provide a
symbolic cross-check. Neither is required merely for tool diversity.

## Phase G: Granularity and Cost Contract

Define experiments only after Phases B through F fix the complete transition
path. Required workload classes:

```text
same-Domain threads
process-per-Domain high-risk service
container/service Domain
tenant Domain with nested process Domains
cross-node service call
device-queue owner Domain
```

Required baselines:

```text
ordinary Linux process/container
KVM VM
microVM
DomainLease-Linux Linux-only prototype
Monitor-backed DomainLease-Linux
```

Measure throughput, p50/p95/p99/p999 latency, CPU overhead, memory density,
TLB behavior, service IPC, device path, recovery time, and operational cost.
Security envelopes must be matched before cost comparisons are accepted.

## Linux Work During This Plan

Allowed:

```text
read current upstream source
refresh source anchors and semantic drift maps
preserve existing patch queue and disposable prototypes
build no-behavior measurement or conformance helpers only when a model requires
them and a separate gate approves them
```

Paused:

```text
new behavior-changing scheduler enforcement
promotion of R6 as the node-wide architecture
R6 E4 as an assurance or cost promotion gate
new public ABI
claims of final model completion
```

## Long-Running Validation Rule

TLC, symbolic checking, full kernel builds, QEMU matrices, sanitizer matrices,
and performance runs that are expected to outlive an interactive session must
be launched through the existing detached job mechanism. Launch and immutable
input capture complete the interactive task; result acceptance is a later,
independent task. An interactive agent must not spend context repeatedly
polling a healthy long-running job.

## Immediate Next Artifact

The immediate target is an authority-disjoint Candidate-4 capture and launcher
contract, not another candidate-controlled result and not a full run from the
same-UID shell. It must specify root-owned immutable input capture, a dedicated
unprivileged execution UID, nondelegated cgroup-v2 descendant containment,
direct component lifecycle observation, kill-and-drain behavior, authenticated
tool/input identity, and output retention outside candidate authority.

After hostile review of that launcher contract, capture exact inputs and launch
the long full bounded campaign detached. A later independent session reduces
the retained child, parent, and commutation receipts. Even a local full pass can
only disposition the three registered local claims; it cannot authorize F0,
external R11 review, or K0/G0.

The earlier R11 G0 v1 predecessor remains fixed as:

```text
manifest     capsched-models/policy/r11/g0-candidate-bundle-v1.json
byte length  7073
sha256       bcdd6c26c5a651f7630df5d218cbd6fb2f20922e2e03cdf109b68b69a7250037
artifacts    17 exact path/role/length/digest entries
mutations    12/12 declared structural/protocol cases rejected
semantic     12/12 hostile weakenings accepted by the checker
promotion    5/5 forged-positive conditions accepted by schemas
disposition  rejected before external review
G0           false
```

Epoch 2 is built under `capsched-models/policy/r11/epoch2/` without modifying
the captured v1 artifacts. It must define a backend-neutral many-sorted logic,
typed external template formulas, total non-redefining candidate bindings,
exact product-to-writer/CD/linearization maps, executable provider and progress
contracts, explicit branch semantics, typed distributed transfer, generated
mandatory interaction/cut profiles, and an exhaustive semantic mutation
catalog.

Its promotion layer must contain an externally selected authority registry,
an exact unique review set, canonical signed payloads, and an executable gate
that recomputes check completeness, blocker closure, identity disjointness,
freshness, and signatures. Checker-skip and stale-review attacks must target
the real checker and receipt chain rather than protocol fixtures.

G0 authorizes only draft R11 machine-source construction. It does not authorize
semantic freeze, proof success, TLA+, model support, Linux behavior changes, or
protection claims. Until G0 exists, work may strengthen policy, validators,
negative tests, and review readiness, but must not create a normative R11 IR.

Only after a valid epoch-2 G0 decision, Formal 0150 may bind the accepted
policy/profile bundle, materialize
D0-D17, generate and execute W0-W12, kill the G2 IR mutation families, and
receive a fresh exact review before one semantic freeze. TLA+ decomposition
begins only from that frozen IR and must not invent missing semantics. Any
positive `RESIDENCY-DYN-001` result still requires a new claim-specific
Evidence Capsule decision rather than reusing ROOTSCHED or finite RESIDENCY
evidence.

## Non-Claims

This plan is not a proof, implementation approval, Monitor implementation,
Linux hook selection, protection result, scalability result, cost result, or
deployment approval.
