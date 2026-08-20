# Analysis 0204: Dynamic Residency R7 Executable Semantic IR Architecture

Status: rejected pre-IR architecture candidate; exact snapshot retained

Date: 2026-08-09

Work record: `N-192`

Requirement: `RESIDENCY-DYN-001`

Post-review disposition: four independent reviews returned `FREEZE_NO` for raw
SHA-256 `6d08ec4371c8832ff413626fcbb804eb157e3ebc555d7d4ef7d79fe45a97e8ec`.
Analysis 0205 records the normalized blockers and fixed R8 choices.

## Purpose

R7 replaces the rejected R6 v2 semantic core. It is not another patch layer
whose unchecked prose inherits every old contradiction. The normative R7
machine artifact will be a closed preformal semantic IR from which TLA+ can be
translated without choosing new state, authority, action, crash, progress, or
refinement semantics.

R7 remains a conditional node-local dynamic-residency component. Physical
ENTRY/CODE/STATE/device truth, complete mutable-state isolation, cluster
producer correctness, process-to-container refinement, Linux trace refinement,
and measured cost remain named system-completion obligations. R7 may consume
their typed interfaces but may not count them as discharged.

## Semantic IR Contract

The machine IR has six closed registries:

```text
TypeRegistry
ObjectSchemaRegistry
MutableFieldOwnerRegistry
FormulaRegistry
ActionRegistry
ClaimAndRefinementRegistry
```

Every reference is an exact stable ID. Registry key sets are closed: unknown,
duplicate, missing, stale alias, or extra entries reject. Each action record
contains:

```text
action ID and actor authority
source and target phases
guard AST
exact read set
exact write set
update AST
UNCHANGED complement
atomic group and linearization cell
crash class and every recovery successor
abstract action or named stutter
finite-rank delta and bound unit
protected-work ticket or external-action classification
```

Every mutable field has exactly one writer authority. A joint operation is one
explicit protected linearization action or writes disjoint fields through a
specified handshake. A role name such as "shard plus hardware" is not a writer.

## Identity And Dependency Closure

The canonical byte and digest transcript from R6 remains useful, but R7 uses a
closed typed object schema as the authority source. For each immutable object,
the schema separately lists:

```text
identity ancestors: exact parent CIDs used in this CID constructor
payload ancestors: exact parent CIDs and payload digests authenticated by payload
stable-cell references: identity plus generation, never mutable payload digest
external roots: exact typed interface object
mutable descendant observations: permitted only in later cell versions and
                                 never an ancestor of that descendant's CID
```

The construction graph is generated from identity and payload ancestors. The
declared graph must equal the generated graph, not merely contain a selected
subset. Stable-cell and mutable-descendant references are checked separately.

The R7 construction order is:

```text
OpportunityReservation
  -> ActivationDecisionCellIdentity
  -> CurrentOpportunity
  -> ActivationAttemptReservation
  -> ActivationAttemptID
  -> ExecutionCellLeaseCore
  -> ActivationPrerequisiteCoreSet
  -> NormalizedAuthorityHorizonVector
  -> ExecutionCellLease
  -> ExecutionCellUseCellIdentity
  -> ConnectivityFreshnessUseReceiptSet
  -> ActivationIntent
  -> ExecutionContextCore
  -> RequiredActivationReceiptSet
  -> EntryAuthorityHorizon
  -> ExecutionContextKey
  -> PrepareInertTxnIdentity
  -> PreEntryPermit
  -> EntryTxnIdentity
  -> EntryCommitRecord
  -> ActivationID
  -> ActivationCommitReceipt
  -> ExecutionRuntimeCellIdentity
  -> DeliveryAccountingCellIdentity
  -> RunToken
  -> ExecutionDeliveryReceipt
  -> OpportunityTerminalReceipt
```

`AuthoritySourceCoreSet` is an external-root input to
`ActivationPrerequisiteCoreSet`; it is not a descendant. Optional policy
classes use an exact typed empty set, never an omitted edge.

`ActivationIntent` binds the target opportunity, attempt, final lease, use-cell
identity, desired context profile, and resource endpoint profile. It does not
contain `ExecutionContextCore`, a receipt, final context key, permit, or token.

## Horizons Without Back Edges

R7 divides authority into pre-install cores and post-install evidence.

`ActivationPrerequisiteCoreSet` contains exact, already-existing authority for:

```text
FrozenLeaseUse
NodeLeaseImportCertificate
GlobalPlacementUse
SecurityUseVector
RetirementFenceUseSnapshot
ExecutionCellLeaseCore
MemoryViewReservationCore
CodeAuthorityCore
EntryStateReservationCore
MutableStateReservationCore
DeviceAuthorityOrProtectedAbsenceInventoryCore
StopAndBudgetReservationCore
conditional ConnectivityFreshnessAuthorizationCore
root budget
```

`NormalizedAuthorityHorizonVector` is the conservative minimum over only those
cores after direct clock conversion. It never names the final lease, use cell,
context, receipt, or token.

After physical state has been staged inertly, every required receipt binds one
prerequisite core and has an expiry no later than that core. Then:

```text
EntryAuthorityHorizon =
  minimum(NormalizedAuthorityHorizonVector.notAfter,
          every exact RequiredActivationReceipt.notAfter)
```

`EntryAuthorityHorizon` is a descendant of the receipt set. The permit,
context key, entry record, runtime cells, and token bind it. No ancestor feeds
on it.

## Stable Decision And Attempt Allocation

`OpportunityReservation` atomically allocates one stable logical activation
shard and one `ActivationDecisionCellIdentity`. The logical shard is not a CPU;
CPU loss cannot change the writer identity. Monitor restart advances
`MonitorBootEpoch` and invalidates unfinished predecessor work.

The DecisionCell owns:

```text
phase
nextAttemptOrdinal
activeAttemptID or None
prepared transaction and permit IDs or None
entry generation and ActivationID or None
activated and served monotonic bits
stop generation
terminal cause and terminal receipt ID or None
```

`AllocateAttempt` is a durable sole-writer CAS:

```text
guard:
  phase = Open
  activeAttemptID = None
  nextAttemptOrdinal < MaxActivationAttempts

atomic update:
  n := nextAttemptOrdinal
  nextAttemptOrdinal := n + 1
  activeAttemptID := CID(CurrentOpportunityID, n)
  publish ActivationAttemptReservation(CurrentOpportunityID, n)
```

The ordinal is burned even if later work fails. At most one nonterminal attempt
exists per opportunity. An attempt cannot own more than one bound use cell.
Failure terminalizes that attempt before another allocation. Exhaustion without
a claim-excluded external cause is `InternalGuaranteeViolation`, not expiry.

## Connectivity Meaning

The compatibility name `CONNECTED_ONLY` is interpreted precisely as
fresh authorization per attempt. A certificate proves an authenticated
issuer/channel observation during a bounded source interval and authorizes one
specified attempt purpose until a conservative local expiry. It does not prove
future physical connectivity and safety never assumes that the network remains
up after observation.

The immutable certificate binds `ActivationAttemptID`, operation purpose,
challenge, issuer checkpoint, and expiry before the base horizon is built. It
does not bind a future execution use cell. A protected one-use cell is consumed
atomically with publication of
`ConnectivityFreshnessUseReceipt(AttemptID, UseCellID, inputDigest)`. Either
both exist or neither exists. Crash recovery returns the same receipt or the
same unconsumed state; it cannot lose the operation and consume the certificate,
or commit the operation while leaving the certificate reusable.

Once consumed, the attempt must eventually reach a typed terminal result under
the internal work guarantee. A failed attempt needs a fresh ordinal and fresh
certificate. `CONTINUE_TO_CONSERVATIVE_EXPIRY` and `RECOVERY_ONLY` retain their
separate bounded meanings.

## Prepare Transaction

Physical components may stage pages, translation roots, entry state, code,
mutable-state bindings, device isolation, and stop state before prepare commit.
Staging is non-executable and is guarded by the protected execution gate.

`PrepareInertTxn` has one owner and states:

```text
Allocated -> Staging -> Ready -> CommittedPrepared
                         \-> AbortPending -> Aborted
```

Before commit, a crash may leave physical dirty-inert staging, but no bound use
cell, permit, executable owner, token, activation ID, or service credit.
Recovery must either clean it or complete the same transaction identity.

`CommitPrepareInert` is one protected atomic action:

```text
ExecutionCellUseCell Unbound -> Bound(exact AttemptID, IntentID)
DecisionCell Open -> PreparedInert
AttemptCell -> Prepared
PrepareTxn -> CommittedPrepared
staging generation becomes visible but remains non-executable
one sealed PreEntryPermit is published
```

The action checks every receipt generation and `EntryAuthorityHorizon`. No
other action can bind the use cell or publish a permit. Cancellation before
commit produces `SuppressedBeforeEntry`; cancellation after commit produces
`StopPending` and revokes the permit. It never rolls the phase backward.

## Entry And Runtime Authority

Initial entry uses only:

```text
PreEntryEligible =
  valid unconsumed PreEntryPermit
  and exact PreparedInert decision generation
  and Bound use cell
  and current complete receipt generations
  and current EntryAuthorityHorizon
  and due physical cell
  and no stop or conflicting active owner
```

`TokenExecutable` is post-entry only. It can never authorize initial entry.

The physical interface supplies a single protected execution-gate primitive:
all complex view, code, entry, device, and stop state is prepared inertly; one
atomic gate publishes an active hardware owner only after exact validation.
This primitive is a typed external interface guarantee until the later
ENTRY/CODE/STATE/device model refines it.

`CommitEntry` atomically:

```text
consumes the permit and Bound use cell exactly once
sets the protected active owner
publishes EntryCommitRecord and ActivationID
publishes ActivationCommitReceipt
creates ExecutionRuntimeCell in Active state
creates DeliveryAccountingCell in Unaccounted state
creates RunToken from already-existing ancestors
sets DecisionCell to EnteredUnserved and activated=true
sets one entry-bundle commit bit
```

Without the commit bit there is no executable context, even if physical staging
is dirty. Every pre-commit crash cleans or resumes the same transaction. Every
post-commit crash recovers the same bundle and ActivationID.

The token binds stable DecisionCell identity, the reserved entry generation,
stable runtime/accounting cell identities, and current stop generation. It does
not bind a mutable DecisionCell payload digest. The DecisionCell may store the
token ID after construction because the token's CID does not depend on that
later cell version.

`ExecutionRuntimeCell` is solely written by the protected runtime engine. It
owns active/stop/settled state, active owner, next resume sequence, remaining
budget, and checked execution intervals. `DeliveryAccountingCell` is solely
written by the settlement owner. It owns deterministic receipt publication and
one service-accounting bit. This replaces the ambiguous composite writer.

Every continuation or interrupt return checks the current runtime cell and
monotonic resume sequence atomically. Stop-generation advance makes all older
tokens non-executable. Budget never increases. One delivery receipt may set the
DecisionCell served bit once; duplicate receipts are idempotent.

## Total Lifecycle Refinement

The concrete product has exact finite domains for opportunity stage, decision
phase, attempt state, prepare/entry transaction state, use-cell state, runtime
state, accounting state, activated bit, served bit, stop generation, and
terminal cell.

`Abs(concreteState)` is executable. Its predicates are mutually exclusive and
cover every product value. Invalid products map only to
`InternalGuaranteeViolation`; they never receive service or external-withdrawal
credit. `ActivationIntentPending` maps to the existing `ActivationPending`
state, not to a phantom state.

Decision transitions are complete:

```text
Open -> Open                 failed attempt terminal append
Open -> PreparedInert
Open -> SuppressedBeforeEntry
Open -> ExternalExpiredBeforeEntry
Open -> InternalGuaranteeViolation
PreparedInert -> EnteredUnserved | StopPending | InternalGuaranteeViolation
EnteredUnserved -> StopPending | Settling | InternalGuaranteeViolation
StopPending -> Settling
SuppressedBeforeEntry -> Settling
ExternalExpiredBeforeEntry -> Settling
InternalGuaranteeViolation -> StopPending | Settling
Settling -> ServedTerminal | UnservedTerminal
ServedTerminal and UnservedTerminal are absorbing
```

The served and activated bits are monotonic. Terminal states have no execution
authority and fix disposition, service accounting, and budget settlement once.
Every concrete action refines one abstract action or an explicitly listed
stutter.

## Publication, Close, And Failure

Each scope has a protected gate:

```text
phase: Open | Closing | Closed
generation
enrollNext
closeCut
terminalPrefix
canonicalFailureID
```

`EnrollScope(txn, scope)` atomically checks `Open`, allocates sequence
`enrollNext`, persists a nonempty reverse slot, and increments `enrollNext`.
There can be no reservation hole below the cursor. `BeginClose` atomically
changes `Open -> Closing` and copies `closeCut := enrollNext`. Enrollment after
that linearization rejects. Therefore:

```text
enrollmentLinearization < closeLinearization
  iff sequence < closeCut and txn is in the preclose set
```

Each publication has one protected outcome cell:

```text
Preparing -> Committed
Preparing -> Aborted
```

Commit, failure-forced abort, timeout abort, and restart recovery use the same
CAS. If commit wins, recovery completes every bounded reverse slot and only
then publishes `CommitVisible`; authority is non-executable before that bit. If
abort wins, every slot becomes terminal Aborted. A closer neither waits for nor
trusts Linux.

`Closed(scope, cut)` requires every slot `0 .. cut-1` durably terminal and the
contiguous terminal prefix equal to `cut`. A high numeric sequence with a hole
is not a prefix. GC requires terminal authority, a durable checkpoint, no live
closure cursor below the prefix, and generation advance.

Failures have a durable union-find-style `FailureJoinCell`. If two closures
discover a shared use or scope after closing different gates, a protected CAS
chooses the canonical minimum failure identity, unions worklists and fenced
scopes, and records parent links. No gate reopens. Workers resolve their current
canonical root before every write. Disjoint components commute.

The durable closure journal contains canonical failure root, closed scopes,
frontier, per-scope terminal prefix and scan cursor, discovered uses, topology
generations, pass generation, and fixed-point bit. Restart reconstructs all of
it and never changes `Closing` or `Closed` to `Open` in the same generation.
Completion requires an empty frontier and one complete no-change pass over all
closed prefixes and topology generations. Bounds are admission-charged; a
post-authority bound fault uses a pre-reserved stop path and is an internal
liveness violation unless an external rely actually failed.

## Typed Time And Transfer

There is one clock relation schema. `ServiceCalendar` always uses issuer-owned
`CalendarTimeDomainID/CalendarEpoch`. Node lease, stop, and execution use exact
`LeaseClockID/LeaseClockEpoch`. Destination scheduling may use a third domain.
Arithmetic is legal only inside one exact domain/epoch or through one direct,
current `ClockRelationCertificate` bound to the exact transfer and boundary.
Transitive inference and naked integer comparison reject.

Every predecessor `GlobalPlacementUse` has one
`PredecessorTransferDecisionCell`:

```text
Open -> Committed(TransferID, exact successor placement)
Open -> ContinuityLost(TransferID, new stream incarnation)
```

It is consumed once. Later quorum certificates may order after the first but
cannot name another successor for that predecessor.

The replicated lifecycle log records exact per-ordinal states:

```text
reserved
attempt allocated
prepared inert
entered
delivery accounted
terminal disposition
```

After a write-close fence, the closure certificate defines:

```text
IssuedSet
PreparedSet
EnteredSet
DeliveredSet
TerminalSet
ClosedReplicatedPrefix
UnknownSuffix =
  (IssuedSet union PreparedSet union EnteredSet union DeliveredSet)
  minus TerminalSet minus ClosedReplicatedPrefix
```

Strong continuity requires an empty unknown suffix at and above `qCut`.
Safe-gap chooses `qCut` strictly above every bounded ambiguous ordinal and
publishes one nonservice disposition per skipped ordinal. For guaranteed work,
each such disposition must bind a valid claim-excluded
`AuthorizedExternalWithdrawalReceipt` whose cause began before that ordinal's
deadline; otherwise the result is safe but an internal liveness counterexample.
Continuity loss advances `ServiceStreamIncarnation`.

Transfer work never waits forever for source quiescence. At its reserved work
occurrences it deterministically selects the first fully valid branch:

```text
SourceQuiesced
QuorumSupersededStrongContinuity
QuorumSupersededSafeGap with valid external withdrawal
ContinuityLost with new incarnation and valid external withdrawal
typed rejection with the source remaining stopped
```

Destination activation is strictly after direct-converted source stop,
residual-effect, uncertainty, and independent stop upper bounds.

## Item-Level Protected Progress

The nine-slot parent frame remains a capacity partition, not a fairness proof.
Admission and renewal allocate exact `ProtectedWorkOccurrenceID`s to every
bounded microstep of every guaranteed item. A ticket contains:

```text
item identity and owner
work class
ordered exact occurrence list
steps remaining
deadline
terminal result cell
```

A protected hardware turn for an assigned occurrence executes that exact
microstep or a typed fail-closed result; it cannot internally stutter. This is
a narrow hardware-progress rely, not fairness from Linux or a free Monitor
picker. Empty occurrences may become revocable slack only.

For one opportunity the executable lexicographic rank is:

```text
(attemptFailureBudgetRemaining,
 currentAttemptPhaseRank,
 currentWorkMicrostepsRemaining,
 protectedTurnsToNextAssignedOccurrence,
 settlementStepsRemaining)
```

Each component has a finite natural domain. A failed attempt decreases the
first component before later components reset. A normal action strictly
decreases the first differing component; a permitted stutter is named and
cannot consume an assigned protected occurrence. The admission witness converts
the worst-case rank through the exact reserved occurrence calendar and proves
it fits between release and deadline.

`OperationalPreservation` covers every internal action ID. Under the exogenous
window, no internal action may create owner loss, overdraft, deadlock,
unexplained fail-stop, permanent protected-work suppression, or rank-bound
exhaustion. The per-opportunity theorem consumes explicit exported formulas for
eligibility, reservations, rank, and withdrawal; it does not consume the word
"Operational" as an assumption.

## Restart And Locality

R7 distinguishes restart scopes:

```text
opportunity or activation shard restart
failure-component restart
lane restart
node Monitor boot-epoch replacement
```

The first three preserve disjoint live components through generation-fenced
recovery. Node-wide withdrawal is permitted only when a named root object,
hardware time root, protected registry, or boot epoch is lost. It remains a
later system-completion obligation to prove the physical implementation and to
measure blast radius.

Live metadata is bounded by admitted live and retiring authority, not completed
history. Terminal objects are reclaimed only after durable checkpoints and all
reference/failure/transfer cursors pass them. Parent CIDs are references to
bounded canonical keys; payloads do not recursively inline transitive objects.
Exact size and reclamation ranks will be part of the IR.

## Formal Dependency And Claims

The proof component set remains 16 nodes, with the single canonical external
name `ENV_ENTRY_CODE_STATE_DEVICE_INTERFACE`. The component ledger is replaced
as a whole. Every row instantiates the exact formal-node schema; proof order and
ledger key sets are equal.

Formula free variables are checked against owner classes. External assumptions
may mention only environment-owned variables. Any external formula containing
internal `Operational`, protocol success, internal fail-stop, or a theorem
conclusion rejects. A constructive trace with admitted guaranteed work, no
withdrawal, and service demonstrates that the exogenous window is nonempty.

Every claim and nonclaim names formulas, providers, remaining assumptions,
validator obligations, and future evidence class. No boolean claim flag is
sufficient by itself.

## Mandatory R7 Witness Families

The 40 findings in Analysis 0203 are the minimum coverage inventory. R7 adds
crash and concurrency families beyond the rejected 16-scenario draft:

```text
schema-derived dependency equality and all cycle mutants
attempt allocation races and all cancel orderings
every prepare and entry crash cut
receipt generation changes and device-absence invalidation
publication enroll/close and commit/abort permutations
reverse-prefix holes and GC races
late-intersecting failure merge and every restart cut
three-clock mapping and relation expiry
dual successor and unknown activation suffix
connectivity consume crash and post-observation partition
safe-gap liveness classification
exact work-ticket selection and internal-stutter lasso
rank reset and deadline conversion
complete low-product abstraction and action simulation
proof-ledger, formula-provider, owner, action, claim, and mutation-meta closure
```

## Current Claim Ceiling

```text
R7_architecture_draft_written = true
R7_machine_IR_written = false
R7_witness_executed = false
R7_findings_closed = false
architecture_frozen = false
tla_authorized = false
tla_written = false
model_checked = false
RESIDENCY_DYN_model_supported = false
hypervisor_level_protection_evidenced = false
performance_or_cost_efficiency_evidenced = false
multi_cluster_correctness_evidenced = false
Linux_compatibility_evidenced = false
deployment_ready = false
```
