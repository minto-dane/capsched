# Analysis 0209: Dynamic Residency R10 Pre-IR Hostile Review Rejection

Status: R9 architecture rejected; `IR_READY_NO`; `FREEZE_NO`; clean R10
machine-semantics redesign required

Date: 2026-08-09

Work record: `N-197`

Requirement: `RESIDENCY-DYN-001`

Machine disposition:
`analysis/dynamic-residency-r10-pre-ir-hostile-review-rejection-v1.json`

## Exact Target And Verdict

```text
Analysis 0208 reviewed raw SHA-256:
  f7e9f3df695af3015681da99a48bffcc44fe916588da66230fff82be5b411362
```

Four fresh read-only reviews covered authority/activation, distributed
failure/transfer, formal semantics, and system composition. All four verified
the exact digest and independently returned both `IR_ENCODING_READY=NO` and
`FREEZE_NO`. Their 78 raw findings normalize to 42 distinct R9-local blockers.

The large registries in R9 are useful discovery evidence, but counts are not
semantic closure. The 77 cell kinds, 138 action names, and 43 crash cuts do not
define map domains, initial values, immutable-object existence, exact guards,
location-level effects, frames, unique recovery successors, or executable
formulas. Encoding those gaps would make the encoder the architecture author.
A successful model of that invented system would not validate R9.

## Canonical Blockers

### Closed machine boundary

| ID | Required R10 closure |
| --- | --- |
| `R10-ARTIFACT-01` | Make the reviewed machine artifact itself complete. Schema, registries, formulas, witness, checks, and mutation obligations may not be future placeholders inside a closure claim. |
| `R10-REGISTRY-01` | Materialize exact equal-key registries for types, bounds, variables, mutable locations, immutable objects, allocators, reference edges, writer authorities, provider state, actions, invariants, relies, refinements, and claims. |
| `R10-INIT-01` | Enumerate every bounded sort and map domain, every instance source, typed absence, initial value, counter-exhaustion state, and rejected malformed initial product. |
| `R10-OBJECT-STORE-01` | Represent dynamic immutable-object existence explicitly through a bounded object store or preallocated universe plus publication state; an action cannot publish an object that is absent from the state universe. |
| `R10-SCHEMA-EDGE-01` | Give every immutable and mutable record exact fields, sorts, optionality, identity edges, reference classes, and generated edge extractors. Names or prose field lists are insufficient. |
| `R10-ACTION-01` | Expand every action to exact bounded parameters, guard AST, reads, location-level writes, deterministic effects, complete frame, linearization point, crash successor, rank delta, and refinement mapping. Wildcard and future-generated actions are forbidden. |
| `R10-WRITER-01` | Separate semantic initiator from writer authority. Each mutable location has one actual writer, and every action write must be authorized by that writer at location granularity. |
| `R10-TXN-FOOTPRINT-01` | Bind every atomic action to one shard and an exact bounded set of location instances. Ancestor, reverse-edge, lane, and failure-component fanout must be enumerated before commit or rejected by a fixed bound. |
| `R10-TXN-LIFECYCLE-01` | Distinguish unused `Vacant` slots from `Prepared`, durable decision, projection, and terminal states, with transaction identity, participants, versions, write set, and projection cursor. |
| `R10-RECOVERY-01` | Give every durable cut one state-derived successor. Phrases such as complete-or-terminalize, publish-or-revoke, and reject-or-arm are prohibited. |
| `R10-IMPORT-AST-01` | Materialize imported formula slices, canonical ASTs, exact free-variable/type/constant maps, and refinement mappings instead of promising later extraction. |
| `R10-PROVIDER-AST-01` | Express provider state, fault transitions, initial state, safety guarantees, and temporal relies as typed formulas over registered variables. Natural-language provider promises are not assumptions. |
| `R10-PROOF-FORMULA-01` | Encode every invariant, simulation relation, proof node, claim, and nonclaim as an exact scoped state or temporal formula with a machine-checkable dependency graph. |
| `R10-LIVENESS-01` | Define protected calendars, due selection, finite credits, numeric phase orders, exact action deltas, and fairness formulas for install, prepare, entry, boundary, stop, recycle, continuation, offline reconciliation, failure, and transfer. |

### Authority, lifecycle, scheduling, and execution

| ID | Required R10 closure |
| --- | --- |
| `R10-AUTH-CONSERVATION-01` | Make issue/delegation one atomic parent-ledger transfer with exact quota equations, child ordinal, attenuation proof, and no path that publishes child authority twice. |
| `R10-REVOCATION-01` | Freeze whether transferred child authority survives parent revocation. Any cascade must use an explicit generation-fenced revocation scope and reverse index rather than an implicit ancestor scan. |
| `R10-ASYNC-AUTH-01` | Debit caller and service parent uses exactly once, store the validated authority intersection, and conserve cancellation, charge, and result disposition per carrier. |
| `R10-ASYNC-ACTIVATION-01` | Define `ActivationRequestCore` exactly and route each carrier through the same release, attempt, root claim, entry, stop, and settlement DAG as synchronous execution. |
| `R10-SPAWN-01` | Define reserve, consume, commit/abort, crash recovery, leaf ProtectionDomain creation, subject creation, and initial-generation actions for process and thread spawn without ambient inheritance. |
| `R10-EXEC-EXIT-01` | Close old Ready publication, stop and settle active uses, drain/cancel/transfer async carriers, advance program generation, publish only fresh work, and retire subject/leaf in one ordered protocol. |
| `R10-DISPATCH-CAUSALITY-01` | Split pre-claim authority/preparation data from post-root-claim physical-entry binding. No immutable object may contain an identity allocated by a later action. |
| `R10-ATTEMPT-ALLOC-01` | Give attempt allocation one action and one outcome root; eliminate the competing allocation in Ready claim and initialize all attempt-owned identities and states together. |
| `R10-RETRY-NOREISSUE-01` | Allocate distinct authority, snapshot, permit, entry, and root-claim identities for every retry. After global no-reissue commit the ordinal is spent and cannot retry. |
| `R10-READY-PROJECTION-01` | Choose one truth model. If `Entered`/`Consumed` is derived from provider `EntryOutcome`, Ready is not separately written to that state; any cache is non-authoritative and excluded from safety. |
| `R10-ROOT-FRAME-01` | Add protected root-frame release, slot allocation/open, ready selection, no-ready close, delivery, and recurrence transitions with conserved root budget. |
| `R10-MGMT-NORMAL-DAG-01` | Make management bootstrap create a non-executable template and obtain execution only through the ordinary authority, release, attempt, entry, and accounting DAG. |
| `R10-BUDGET-ARM-01` | Require each armed quantum upper bound to be no greater than its remaining reserved execution escrow and conservatively bounded lease/time horizon. |
| `R10-OVERHEAD-01` | Introduce one-use provider receipts and bounded accumulators for entry, switch, stop, and fail-stop overhead; define who is charged and prevent double refund. |
| `R10-LEDGER-01` | Fix the exact applicable ledgers and initial application bitmap in the reservation outcome, then permit only idempotent application of the committed settlement vector. |
| `R10-CURRENT-EXEC-01` | Define `CurrentExecutable` over exact registered fields and retain a typed pre-stop owner/entry/quantum binding in `StopResidual`; historical prose predicates are forbidden. |
| `R10-OFFLINE-01` | Make provider offline invalidate installed context and gate state, resolve pending entry, and publish a receipt that protected reconciliation uses to close lane, Ready, stop, budget, and settlement state. |

### Publication, failure, transfer, time, and reclamation

| ID | Required R10 closure |
| --- | --- |
| `R10-PUBLICATION-SEAL-01` | Use an exact `Vacant -> Staging -> Sealed -> Visible` or `Aborted` publication lifecycle. Enrollment is immutable after seal and only Visible is consumable. |
| `R10-ADMISSION-SEAL-01` | Give admission its own sealed enrollment/resource-vector state, conservation equations, commit/apply boundary, and deterministic abort/return path. |
| `R10-ACTIVE-USE-CUT-01` | At close, freeze each enrollment's active-use cut and require a contiguous terminal prefix or aggregate stop outcome for all uses below it before reverse-slot terminality. |
| `R10-DEPENDENCY-INVALIDATE-01` | Register every dependency kind, reverse-index field, invalidation action, affected aggregate/lane/permit/owner transition, crash successor, and bounded footprint. |
| `R10-SUCCESSOR-ONEUSE-01` | Bind successor authority to one destination, boot/configuration epoch, ordinal range, and globally consumed certificate state so two destinations cannot install it. |
| `R10-CONTINUATION-CARRY-01` | Separate local continuation from cross-node migration and define a conserved one-use service-carry record/certificate and destination consumption action for each. |
| `R10-FAILURE-EPOCH-01` | Seal a failure-envelope epoch before completion. A late fact creates a linked successor epoch and cannot mutate a completed root. |
| `R10-MERGE-REBASE-01` | Define canonical component identity, CAS versions, `Committed`, `Subsumed`, and `Rebased` outcomes for overlapping concurrent merges, including credit transfer and bounded chain length. |
| `R10-MERGE-RANK-01` | Add an outer admission-precharged generation/merge credit so discovery, rebase, projection, no-change, and close actions strictly decrease a well-founded lexicographic rank. |
| `R10-TIME-PARTITION-01` | Bind exact clock-relation and partition-policy receipts into residency and physical entry, then actionize conservative expiry, new-entry denial, active stop, and aggregate closure. |
| `R10-GC-01` | Materialize per-field reference extractors, class cursors, checkpoint components, authorization horizons, vector order, and the exact tombstone predicate before any identity or slot can be reclaimed. |

## Fixed R10 Architecture Choices

The rejection fixes choices that the successor may not silently reopen:

```text
normative source:
  a typed machine IR is normative
  the human architecture explains it but cannot fill omitted semantics

local writer:
  one protected node transaction engine writes local authority state
  subsystem actors are request initiators, not independent writers
  CPU, clock, quorum, and external evidence remain separate typed providers

transaction:
  Vacant -> Prepared -> CommitIntent | AbortIntent -> Applying -> Complete
  commit decision is the semantic linearization root
  exact read versions, shard, write locations, and fixed projection order bind it

delegation:
  quota is transferred, never copied
  parent revocation does not silently revoke an already transferred child
  optional cascade uses an explicit shared revocation-scope generation

dispatch causality:
  Opportunity/Ready -> AttemptPreparation -> RootClaim -> PhysicalEntryBinding
  post-claim objects alone contain RootSlotClaimID

retry:
  every retry is a fresh attempt with fresh one-use authority and entry identities
  global no-reissue commit makes the ordinal terminal even if entry is unknown

execution truth:
  provider-owned CPU product includes portal, installed context, owner, entry,
  quantum, timer gate, execution gate, clock epoch, incarnation, and boundary
  Ready entered/consumed state is derived from EntryOutcome

revocation:
  RevocationRequested denies new quanta
  RevokedEffective is published only after stop/fail-stop receipt

budget:
  root and SchedContext reservation covers run plus attributed entry/stop overhead
  every quantum is bounded by remaining run escrow
  one-use receipts settle actual run and overhead without double application

publication:
  enrollment and admission are immutable after an explicit seal

failure and transfer:
  completed failure epochs are immutable; late facts create successor epochs
  overlapping merges rebase or become subsumed under one canonical component
  successor and service-carry authority is destination-bound and one-use

bootstrap:
  management execution follows the normal execution DAG
```

## Review Accounting

```text
authority and activation:             20 raw findings
distributed failure and transfer:     15 raw findings
formal semantics and IR readiness:    34 raw findings
system goal and composition:           9 raw findings
total:                                78 raw findings
normalized R9-local blockers:         42
```

The machine disposition records every raw finding and its canonical target.
Normalization only merges identical missing decisions; it does not defer a
local defect to a later provider or Linux implementation.

## Decision

R9 is retained as rejected discovery and regression evidence. It is not a
semantic freeze candidate, normative machine IR, TLA+ input, proof, protection
result, or performance result. R10 must be clean rather than an overlay on the
R9 tables. It must first materialize its state universe and transition system,
then pass structural validation, executable witness/mutations, and a new exact
hostile review before TLA+ translation is authorized.

```text
R9_candidate_rejected = true
R9_IR_encoding_ready = false
R9_architecture_frozen = false
R10_machine_architecture_written = false
R10_machine_IR_validated = false
tla_authorized = false
model_supported = false
hypervisor_level_protection_evidenced = false
performance_or_cost_efficiency_evidenced = false
multi_cluster_correctness_evidenced = false
Linux_compatibility_evidenced = false
deployment_ready = false
```
