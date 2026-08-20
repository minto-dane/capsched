# Analysis 0206: Dynamic Residency R8 Semantic Closure Architecture

Status: rejected architecture candidate; exact reviewed snapshot retained; no
semantic IR, freeze, proof, or implementation authorization

Date: 2026-08-09

Work record: N-194

Requirement: RESIDENCY-DYN-001

Predecessor disposition: Analysis 0205 and Validation 0294 reject the exact R7
snapshot. R8 is a clean successor, not an overlay on R6 or R7.

Post-review disposition: four independent reviews returned both
`IR_ENCODING_READY=NO` and `FREEZE_NO` for raw SHA-256
`4f30f2b85b67c3209661461f6cc82bff44575e1e00ca8b3ec0833f4f41837b5b`.
Analysis 0207 and Validation 0295 retain 40 normalized R8-local blockers and
fix the clean R9 redesign boundary.

## Purpose And Claim Boundary

R8 defines the human semantic architecture that a later machine IR must encode
without inventing authority, state, failure, progress, or refinement rules. It
covers dynamic admission, recurring opportunities, activation, protected
entry, bounded execution, publication, failure closure, restart, transfer, and
process-through-container granularity.

The target conditional claim is:

~~~text
Given the exact external interface guarantees named by the proof DAG,
adversarial Linux cannot mint, duplicate, retain, replay, overspend, or
transfer executable Domain authority outside the admitted identities,
generations, resource cells, time horizons, and stop bounds; admitted
guaranteed work receives its required service within its reserved calendar
unless a named claim-excluded external withdrawal begins in time.
~~~

The adversary controls all Linux code and mutable Linux state reachable from a
compromised Domain, including scheduler policy, task metadata, workqueues,
kernel threads, packet and block completion, and proposed protocol messages.
Linux may omit, duplicate, reorder, delay, corrupt, or replay every unprotected
operation. No fairness is assumed from Linux.

In this component, delivered service means verified physical CPU ticks while
the exact protected dispatch use owns the CPU. It does not mean application
progress, endpoint completion, or correct behavior by compromised Domain code.

R8 does not prove MemoryView, entry, code, mutable-state, device, crypto,
protected persistence, cluster issuer, quorum, or hardware-time guarantees. It
consumes exact typed interfaces for them. Until their later models and
composition are closed, R8 supports no hypervisor-level isolation,
multi-cluster correctness, performance, cost, Linux compatibility, or
deployment claim.

## Clean-Scope Rule

The normative R8 machine artifact will be self-contained. It may import only:

~~~text
accepted finite-reference formulas with exact artifact SHA-256 and formula ID
closed canonical encoding and cryptographic interface registries by hash
closed external hardware/time/persistence/cluster/entry registries by hash
~~~

Rejected R6/R7 JSON, prose, witness, or validator output is regression input
only. There is no recursive merge, implicit inheritance, wildcard import,
latest-version alias, or prose fallback. An imported registry key has one
pinned digest; a changed digest is a different input and reopens review.

The currently selected accepted reference bytes are:

| Import | Raw SHA-256 |
| --- | --- |
| monitor-owned-root-scheduling-reference-contract-v1.json | 3df32d6e3991b335e1fe6575077eec7ea76035ceadebe39ad1591f6ed8dcd42c |
| MonitorRootScheduler.tla | 491d02fb75317fec31868c7a7e57a7f85512f10d7a1ba12eba8f48fab565a3b1 |
| global-domain-identity-bounded-residency-reference-contract-v1.json | 650d579ed0507a142501166045e50e37bc81ca69e3980cdf1aa3276fe9868295 |
| BoundedDomainResidency.tla | 1efd0719569d31657c0b7aaf50e103f5fdcdc94dfce7499fc0f149780982a431 |

The future IR imports named formulas from a closed manifest over these bytes;
it does not import every assertion merely because the file hash matches.

## Actor Classes

The model separates three actor classes:

~~~text
UntrustedExternal:
  Linux, Domain code, network delivery, storage services, policy producers,
  and certificate/work proposal paths

TrustedInterfaceProvider:
  canonical seal, hardware time/watchdog, protected persistence/atomicity,
  cluster issuer/quorum, and physical entry/code/state/device interfaces

ProtectedProtocol:
  Monitor-owned bounded validation, capacity, generation, gate, entry, stop,
  budget, settlement, transfer, and work-dispatch state
~~~

UntrustedExternal actions write only environment-owned input cells. A trusted
provider writes only its declared interface state. ProtectedProtocol actions
may consume provider output but cannot write provider facts. Calling all three
"external" would hide the trust boundary and is forbidden.

## Bounded Configuration And Exhaustion

NodeConfig is immutable for one Monitor boot epoch and fixes finite positive
bounds for Domains, subjects, SchedContexts, CPUs, hierarchy depth, shards,
scopes per transaction, prerequisites, receipts, attempts, live suffixes,
failure edges, work items, transfer records, clock relations, and namespace
generations.

Every bounded set has an explicit None, Full, Exhausted, or Quarantined
representation. Arithmetic is checked and nonwrapping.

~~~text
exhaustion before authority:
  reject or backpressure without minting executable authority

exhaustion after authority:
  consume admission-reserved cleanup, stop, settlement, audit, and recovery
  capacity; inability to do so is InternalGuaranteeViolation

generation maximum:
  never wrap; quiesce and perform scoped namespace replacement, or permanently
  quarantine that scope while disjoint scopes continue
~~~

Best-effort demand cannot consume capacity reserved for guaranteed service,
management/recovery, stop, settlement, or namespace retirement.

## Dynamic Admission And Hierarchy

GlobalDomainKey and DomainIncarnationKey are issuer-owned global identities.
A node-local ResidencySlotKey is only:

~~~text
(NodeID, slotIndex, nonwrapping slotGeneration)
~~~

It is a bounded projection cache, never global identity or authority.

NodeConfig fixes a finite hierarchy and exact resource algebras for:

~~~text
physical CPU occurrence sets
root and SchedContext budgets
target-local control turns
protected cleanup and stop occurrences
failure reverse edges and cover reservations
audit/checkpoint capacity
ready/live-suffix/namespace storage
management and recovery capacity
~~~

Admission input names one immutable affected-lineage set and mutation
footprint. The Monitor validates every ancestor to the bounded depth, exact set
disjointness or declared sharing, parent conservation, placement/partition
certificates, cleanup cover, and future local work. An unrelated lineage is
neither read nor locked.

The local admission transaction has:

~~~text
AdmissionTxnIdentity
AdmissionSnapshot of exact lineage/gate generations
immutable feasibility proof and mutation footprint
local scope enrollments and EnrollmentSeal
AdmissionOutcome: Preparing -> CommittedVisible or Rejected
future-effective PlanTransitionRecord
~~~

CommittedVisible is linearized by the local publication protocol. Local apply
is deterministic and cannot revalidate a committed result into rejection.
Authority remains non-executable until its effective boundary and all physical
preconditions exist. A tentative plan or a committed outcome without due local
apply cannot execute.

Guaranteed admission reserves exact recurring CPU cells and every control,
stop, failure, settlement, audit, and namespace microstep needed to retire
them. BestEffort admission uses revocable slack, receives no recurrence
liveness claim, and can be rejected or evicted before it delays guaranteed or
management work.

A service-class change is a new future-effective residency generation:

~~~text
promotion to Guaranteed:
  pass full admission and reserve all future work before old generation closes

demotion or constraint narrowing:
  publish replacement generation, stop and settle old active uses, then retire

constraint widening:
  never mutate current authority in place; perform a new admission
~~~

Slot eviction/reuse requires Closing, all active uses stopped, every reference
and async aftermath drained, budget and failure work settled, checkpoint-vector
dominance, and generation advance. Stale slot indices cannot authenticate a new
occupant.

NodeConfig includes a boot-fixed management/recovery residency, root CPU cells,
ready template, stop path, and cleanup capacity. Dynamic tenants cannot evict,
borrow, or exhaust it. Loss of that protected bootstrap is a named node-root
failure, not an ordinary tenant withdrawal.

## Recurring Request Identity

Each admitted recurring stream has:

~~~text
ServiceStreamKey
ServiceStreamIncarnation
StreamGeneration
CompactCalendarDescriptor
next release ordinal
ClosedPrefixCertificate
KLiveSuffix bounded live/retiring/uncertain records
~~~

OpportunityID is derived injectively from stream identity, incarnation,
generation, and release ordinal. Release burns the ordinal even if later
cancelled. Replayed release messages cannot create another opportunity.

A request member has its own RequestID, caller authority, charge rule,
cancellation generation, and terminal disposition. Coalescing may share
untrusted computation or one bounded immutable work descriptor only when
members have the same operation and compatible nonauthority inputs. It never
merges executable authority, budget cells, cancellation, service credit, or
terminal results. Every member retains an exact one-use disposition.

Cancellation is monotonic:

~~~text
before protected ready:
  terminal CancelledBeforeReady

after ready but before entry:
  advance cancellation generation, revoke permit, release reservations, settle

after entry:
  advance cancellation generation, RequestStop, acknowledge, settle, then
  terminalize without erasing any verified service or effect uncertainty
~~~

Cancellation cannot roll a phase backward, reuse an ordinal, or turn an
internal failure into an external withdrawal. Bounded suffix or request
capacity exhaustion backpressures before release authority is published.

## Three Independent Identity Axes

R8 never collapses these keys:

~~~text
ProtectionDomainKey:
  the hardware-isolated MemoryView, mutable-state realm, code policy, device
  view, and Domain epoch

ExecutionSubjectKey:
  the exact process, thread, async carrier, or service invocation generation
  targeted by RunAuthorizationCore

SchedContextKey:
  the independently owned CPU budget, period, priority/class constraints,
  allowed CPU set, co-tenancy policy, and accounting generation
~~~

The protected CPU owner is always a ProtectionDomainKey, never a PID,
task_struct pointer, cgroup ID, namespace ID, or Linux credential.
RunAuthorizationCore targets an exact ExecutionSubjectKey generation and
ProtectionDomain. SchedContextUse targets an exact SchedContext generation.
Neither implies the other, and neither authorizes spawn, thread control,
budget mutation, affinity mutation, or capability minting.

One process per ProtectionDomain gives a process-granular physical boundary.
Several processes may deliberately share one ProtectionDomain to form a
container/service trust Domain. Threads in one ProtectionDomain may avoid a
MemoryView reinstall, but thread-level RunAuthorization remains a scheduler
authority rule, not isolation from arbitrary kernel execution already inside
that same ProtectionDomain. Nested administrative Domains do not imply shared
physical ownership: child process Domains may use distinct
ProtectionDomainKeys while inheriting bounded policy and budget delegation.

Therefore the architecture does not promise all three of:

~~~text
hostile kernel execution inside one ProtectionDomain
per-subject physical isolation inside that same ProtectionDomain
Monitor-free subject switches inside that ProtectionDomain
~~~

Hypervisor-level process separation requires a distinct process
ProtectionDomain, or a separately protected leaf under a container parent.

## Subject, Scheduling, And Run-Authority Registries

The following protected registry records exist before a dispatch use:

~~~text
ExecutionSubjectRecord
  subject generation, process generation, program generation,
  ProtectionDomainKey, lifecycle, and async-drain generation

SchedContextRecord
  SchedContext generation, parent budget reservation, policy constraints,
  lifecycle, and settlement cursor

RunAuthorizationRecord
  issuer, target subject/process/program generations, ProtectionDomain,
  allowed operation, CPU constraints, validity horizon, use policy, and
  revocation generation

ExecutionChargeRule
  executor/caller/donor/service principals, charge target, precedence rule,
  generation, and validity horizon
~~~

Their mutable status cells are Monitor-owned projections of issuer-approved
typed authority. Linux credentials, task pointers, cgroups, and task state
cannot update them directly.

~~~text
SubjectStatus:
  Reserved -> Live -> Closing -> Drained -> Retired

SchedContextStatus:
  Open -> Closing -> Settled -> Retired

RunAuthorizationStatus:
  Open -> Revoked or Exhausted

ChargeRuleStatus:
  Open -> Revoked
~~~

FrozenRunUse is created only from exact current records and binds every
generation above. A cancellation or generation change makes it stale.

Fork or clone requires a distinct SpawnAuthorization and creates a new subject
record before any protected ready publication. Thread creation may share the
same ProtectionDomain but receives a new subject generation. Exec preserves
ProtectionDomain and Domain epoch, advances program generation, and invalidates
every old FrozenRunUse. Exit changes SubjectStatus to Closing before new ready
publication is forbidden; retirement waits for registered async aftermath and
charge settlement to drain.

SchedContext budget creation, delegation, reservation, charge, unused return,
and retirement are one conserved hierarchy. A one-use budget reservation has
exactly one settlement outcome.

## Static Domain Context

Static isolation evidence is installed once per exact Domain context
generation and is not rebuilt for every execution cell.

The acyclic static construction order is:

~~~text
ProtectionDomainRecord
  -> DomainContextReservation
  -> DomainContextInstallTxnIdentity
  -> DomainContextInstallInputCore
  -> DomainContextInstallOutcomeCellIdentity
  -> CurrentCapsuleCellIdentity
  -> StaticIsolationReceiptSet
  -> DomainContextCapsule
  -> InstalledContextCellIdentity per CPU incarnation
~~~

DomainContextInstallInputCore binds:

~~~text
ProtectionDomainKey and Domain epoch
MemoryView ID and generation
code image/policy ID and code epoch
entry-state profile and generation
mutable-state realm ID and generation
device-view or typed protected-absence inventory and generation
co-tenancy and side-channel policy generation
Monitor boot epoch and applicable CPU-incarnation class
DomainContextInstallTxnIdentity
~~~

All physical staging is inert. Each static receipt binds the input core,
install transaction, exact prerequisite, staging generation, issuer, physical
predicate, and conservative validity interval. The protected install outcome
has one of:

~~~text
Uncommitted | Installed | Aborted
~~~

CurrentCapsuleCell has one nonwrapping generation and:

~~~text
Open(capsuleID) | Closing | Revoked | Retired
~~~

DomainContextCapsule is an immutable descriptor published only for an
Installed outcome. It grants no CPU execution. Per-use validation accepts it
only while the exact CurrentCapsuleCell generation is Open and every static
dependency generation remains current. Closing invalidates new use and
reserves bounded stop work for active users.

InstalledContextCell records which exact capsule generation is installed on
one CPU incarnation. Full receipt and signature validation occurs at install
or generation change. A continuation of the same activation may use protected
handle, generation, and local gate comparisons.

## Residency Activation Plane

One static Domain context may be admitted on a node for a bounded residency
epoch without being physically active on a CPU. The acyclic residency order is:

~~~text
DomainContextCapsule
  -> ResidencyReservation
  -> ResidencyStatusCellIdentity
  -> ExecutionCellPoolIdentity
  -> ResidencyPublicationTxnIdentity
  -> ResidencyActivationCore
  -> ResidencyEnrollmentSeal
  -> ResidencyPublicationOutcome
  -> ResidencyActivationReceipt
~~~

ResidencyActivationCore binds exact node/partition lease, placement,
ProtectionDomain and capsule generations, execution-cell pool, protected
ready/calendar capacity, failure/cleanup reservation, transfer policy, and
conservative horizon. All local scopes are enrolled and sealed before one
CommittedVisible publication. Remote authority appears only as typed imported
certificates.

ResidencyStatusCell is:

~~~text
Reserved -> Open -> Closing -> Stopped -> Retired
Reserved -> Rejected
~~~

It has one nonwrapping generation. Open permits protected dispatch
registration; Closing rejects new registration and stops/drains active uses.
ResidencyActivationReceipt is an immutable projection of the exact
CommittedVisible outcome and current status generation. It grants no execution
without a per-dispatch use.

## Per-Opportunity Object DAG

The complete per-opportunity construction order is:

~~~text
ResidencyActivationReceipt
  -> OpportunityReservation
  -> ActivationDecisionCellIdentity
  -> CurrentOpportunity
  -> ProtectedReadyCellIdentity
  -> ServiceProgressCellIdentity
  -> DeliveryAccountingCellIdentity
  -> TerminalOutcomeCellIdentity
  -> AllocateAttemptCASReceipt
  -> ActivationAttemptReservation
  -> ActivationAttemptID
  -> AttemptCellIdentity
  -> PrepareOutcomeCellIdentity
  -> PermitOutcomeCellIdentity
  -> EntryOutcomeCellIdentity
  -> RuntimeStopCellIdentity
  -> ExecutionBudgetCellIdentity
  -> ActivationRequestCore
  -> AuthorityReservationTxnIdentity
  -> AuthorityReservationOutcomeCellIdentity
  -> RunAuthorizationUseReservation
  -> RunAuthorizationUseCellIdentity
  -> SchedContextBudgetReservation
  -> SchedContextBudgetUseCellIdentity
  -> RootBudgetReservation
  -> RootBudgetUseCellIdentity
  -> ChargeUseCellIdentity
  -> ExecutionCellLeaseCore
  -> ActivationPrerequisiteCoreSet
  -> BaseAuthorityHorizon
  -> ExecutionCellLease
  -> ExecutionCellUseCellIdentity
  -> ActivationInputCore
  -> ConnectivityAuthorizationCertificate or TypedNoConnectivityRequirement
  -> ConnectivityAuthorizationUseCellIdentity
  -> ActivationIntent
  -> PrepareStagingTxnIdentity
  -> ExecutionContextPlanCore
  -> DynamicActivationReceiptSet
  -> ContextUseSnapshot
  -> EntryAuthorityHorizon
  -> PreparedBundleDescriptor
  -> PreEntryPermit
  -> EntryCommitRecord
  -> ActivationID
  -> ActivationCommitReceipt
  -> RunToken
  -> ExecutionDeliveryReceipt
  -> OpportunityTerminalReceipt
~~~

All mutable cell identities needed by prepare, entry, stop, budget, service,
delivery, and terminalization exist before staging starts. The generated
dependency graph must equal the schema's exact identity and payload ancestor
edges. Stable mutable cells are referenced by identity plus generation, never
by a mutable payload digest. No descendant object may feed its own CID or an
ancestor CID.

## Opportunity And Attempt Allocation

OpportunityReservation allocates one stable logical owner shard and one
DecisionCell. CPU migration, hotplug, or Linux task migration cannot change
that writer.

AllocateAttempt is the only allocation action. It performs a sole-writer
durable CAS on the DecisionCell:

~~~text
guard:
  opportunity is Open
  activeAttemptID = None
  nextAttemptOrdinal < MaxActivationAttempts

linearization:
  reserve ordinal n
  increment nextAttemptOrdinal
  write AllocateAttemptCASReceipt and resulting DecisionCell version

ActivationAttemptID:
  CID(type, CAS receipt CID, resulting DecisionCell identity and version)
~~~

An ordinal is burned when the CAS succeeds. A losing CAS creates no
reservation. AttemptID identifies the exact winning allocation, not merely a
reproducible opportunity/ordinal pair. At most one nonterminal attempt exists
for an opportunity. A failed attempt is terminal and its use cell is
permanently unavailable before another attempt is allocated.

DecisionCell owns allocation and stable pointers only. Decision phase,
activated, served, stop, and settlement are pure projections from their sole
authority cells.

Attempt exhaustion under an otherwise valid internal service window is an
InternalGuaranteeViolation. A claim-excluded external withdrawal may
terminalize the opportunity without consuming remaining attempts.

## Activation Input And Authority

ActivationRequestCore binds the exact:

~~~text
CurrentOpportunity and compact-calendar occurrence
ResidencyActivationReceipt and status generation
RunAuthorizationCore/FrozenRunUse
ExecutionSubjectKey and subject generation
ProtectionDomainKey, Domain epoch, and DomainContextCapsule
SchedContextUse and SchedContext generation
ExecutionChargeUseKey and charge generation
requested CPU cell, affinity, NUMA, priority/class, and co-tenancy constraints
requiredServiceTicks and deadline
continuity policy class
endpoint/resource profile
~~~

RunAuthorizationUseReservation, SchedContextBudgetReservation, and
RootBudgetReservation are separate, conserved, one-use reservations.
ExecutionCellLeaseCore is non-executable escrow under those parent
reservations.

AuthorityReservationOutcomeCell is the deterministic crash root for acquiring
the complete set:

~~~text
Preparing -> ReservedAll(exact use-cell set)
Preparing -> ReleasedAll(reason)
~~~

Partial internal reservations are never visible to ActivationInputCore.
Recovery completes ReservedAll for the same transaction or returns every
partial reservation and commits ReleasedAll.

Each reservation and charge decision has one protected use cell:

~~~text
Available
  -> Bound(AttemptID)
  -> Consumed(entryGeneration)
  -> Settled(exact disposition)

Available or Bound
  -> ReleasedBeforeEntry(exact disposition)
~~~

No other terminal transition exists. Consumed cannot return to Available.
Root and SchedContext unused escrow is returned once from Settled; duplicate
settlement returns nothing. RunAuthorization and Charge use cells permanently
record the dispatch consumption even when their parent authority remains open
for a separately allocated future use.

ActivationPrerequisiteCoreSet binds all already-existing lease, placement,
security, retirement, budget, context, code, state, device, and conditional
ConnectivityRequirementCore authority. It does not contain the later
connectivity certificate. Optional classes use a typed empty value.

BaseAuthorityHorizon is the conservative intersection of only those
preexisting cores through direct typed clock conversions. The final
ExecutionCellLease and its one-use cell are then fixed.

ActivationInputCore is the canonical digest input for every later dynamic
receipt. It binds the request, all three authority/budget reservations, final
lease, use-cell identity, prerequisite set, BaseAuthorityHorizon, continuity
class, boot epoch, CPU incarnation, and publication dependency set. No receipt
may authenticate an informal tuple or recompute a narrower subset.

ActivationIntent binds ActivationInputCore and the exact conditional
connectivity certificate/use-cell identity, but no future receipt or permit.
PrepareStagingTxnIdentity is then allocated. ExecutionContextPlanCore binds the
intent, DomainContextCapsule and current generation, subject and SchedContext
generations, desired hardware context, and that already-existing staging
identity.

## Connectivity One-Use Semantics

A connectivity certificate is an authenticated bounded observation and
authorization, not proof of future reachability. It binds:

~~~text
CertificateID
ActivationInputCore
AttemptID and operation purpose
exact destination NodeID, MonitorID, MonitorBootEpoch, and CPU incarnation
issuer/channel/checkpoint/challenge
source clock interval and conservative local expiry
~~~

There is exactly one local
ConnectivityAuthorizationUseCellIdentity derived from CertificateID. Binding
the certificate to one exact Monitor boot means another Monitor rejects it;
distributed one-use is not inferred from independent local cells. A policy
that needs transferable global one-use authority must instead use an
issuer/quorum-owned consumable object from the cluster interface.

The protected consume action atomically changes the local cell from Unused to
Consumed and publishes one receipt. Crash recovery returns the same receipt or
the same unused state.

The receipt also binds ActivationIntent, ExecutionContextPlanCore,
PrepareStagingTxnIdentity, Monitor boot epoch, CPU incarnation, and staging
generation. Post-observation partition does not violate safety. It may prevent
future evidence and end liveness through an exact claim-excluded withdrawal;
it never makes the receipt reusable.

## Dynamic Receipt Transcript

Every member of DynamicActivationReceiptSet binds:

~~~text
receipt type and schema version
ActivationAttemptID
ActivationInputCore ID and digest
ActivationIntent ID
ExecutionContextPlanCore ID
PrepareStagingTxnIdentity
staging generation
Monitor boot epoch
exact CPU incarnation
DomainContextCapsule ID and current generation
exact prerequisite core ID and digest
physical predicate or typed NotApplicable proof
issuer and issuer epoch
notBefore and notAfter in a named clock domain
result and canonical payload digest
~~~

The set has exact type equality with the required receipt inventory. Missing,
duplicate, unknown, stale, extra, wrong-subject, wrong-CPU, or NotApplicable
without a protected absence proof rejects.

ContextUseSnapshot is a compact protected record of the exact capsule, subject,
SchedContext, lease, gate, receipt, and boot/CPU generations validated for this
attempt. EntryAuthorityHorizon is the conservative intersection of
BaseAuthorityHorizon and every dynamic receipt interval. Both are constructed
only after the exact receipt set exists. Every later object binds them.

## Prepare And Permit Protocol

The prepare transaction stages translation, entry state, code, mutable state,
device state, stop state, and local budget escrow inertly. The protected
execution gate remains closed.

PrepareOutcomeCell is the sole prepare outcome authority:

~~~text
Uncommitted -> Prepared(PreparedBundleDescriptorID, prepareGeneration)
Uncommitted -> Aborted(reason)
~~~

PreparedBundleDescriptor is immutable and binds all receipts, horizons,
context, cell identities, staged generation, and publication dependencies. It
is distinct from the early staging transaction identity.

CommitPrepare compares the complete transcript, current gates, local time, and
one-use cells, then CASes the outcome to Prepared. The execution-cell use is
logically bound by this outcome. Losing or crashed attempts cannot bind it
elsewhere.

PermitOutcomeCell is:

~~~text
Unpublished -> Live(permitGeneration)
Unpublished -> Revoked(reason)
Live -> Consumed(entryGeneration)
Live -> Revoked(stopGeneration, reason)
Consumed and Revoked are terminal
~~~

PublishPermit can publish only the deterministic PreEntryPermit for the same
Prepared outcome. A crash between prepare and permit publication leaves the
context inert; recovery publishes the same permit or revokes it. Expiry,
dependency invalidation, cancellation, failure close, or stop before entry
must drive the permit to Revoked and the attempt to a typed terminal path.
There is no indefinitely live PreparedInert state.

## Publication And Scope Closing

Publication atomicity is local to one protected consistency domain. Every
multi-scope publication has:

~~~text
PublicationTxnIdentity
immutable DeclaredLocalDependencySet
one nonempty reverse slot per exact local scope
EnrollmentSealCell
PublicationOutcomeCell
~~~

A dependency owned by another Monitor or node cannot participate in a local
multi-cell CAS. It must first be reduced by its owning consensus/issuer state
machine to one immutable typed certificate with a finite horizon. That
certificate is one local prerequisite. R8 neither assumes distributed shared
memory nor treats two-phase commit as available during partition.

EnrollScope checks a local scope gate is Open, allocates the next sequence
without holes, and durably writes the reverse slot before incrementing the
cursor. SealEnrollment changes Open to EnrollmentSealed only if the completed
slot set equals DeclaredLocalDependencySet exactly.

CommitVisible is one bounded protected transaction. It locks local gates in
canonical identity order, verifies every exact generation is Open, and CASes:

~~~text
Preparing -> CommittedVisible
~~~

BeginClose uses the same canonical ordering domain. There is no separate
Committed then Visible transition. AbortPublication wins the same outcome CAS.

Executable authority requires both CommittedVisible and current dependency
gates. A gate changing to Closing rejects all later entry and resume. An
already executing quantum is not claimed to stop instantaneously: BeginClose
also requests protected stop, and the admitted hardware residual upper bound
applies until StopAcknowledged. Device/DMA or endpoint residuals have separate
typed drain receipts and bounds.

BeginClose atomically changes:

~~~text
Open -> Closing
closeCut := enrollNext
generation := generation + 1
~~~

A reverse slot below closeCut is closure-terminal only when:

~~~text
publication Aborted
or
publication CommittedVisible and every dependent runtime is physically
fenced, active owner is absent, device/DMA residual is drained, budget and
delivery are settled, and terminal disposition is durable
~~~

Committed alone is not terminal. Closed requires a contiguous terminal prefix
equal to closeCut; a high cursor with a hole does not close the scope.

## Physical Entry Linearization

EntryOutcomeCell is a constant-size protected physical cell colocated with the
execution gate. It is the only truth that physical execution may have begun:

~~~text
Pending
  -> Entered(entryGeneration, ProtectionDomainKey, ContextUseSnapshotID,
             ExecutionBudgetCellID, RuntimeStopCellID, permitGeneration)
  -> no second entry

Pending
  -> NeverEntered(reason)
~~~

CommitEntry and every local close/revocation update that can invalidate entry
are serialized by the same protected canonical ordering domain. The entry CAS
checks at its linearization point:

~~~text
live exact permit and PreparedBundleDescriptor
bound one-use execution cell
CommittedVisible publication
current DomainContextCapsule and all local gate generations
exact subject RunAuthorization and SchedContext generations
current EntryAuthorityHorizon and typed clock relation
due CPU/cell and compatible co-tenancy
RuntimeStopCell in Armed/Open generation
positive local execution budget escrow
no conflicting active ProtectionDomain owner
~~~

If entry wins before a stop request, the stop path observes Entered and removes
that owner within the pre-reserved hardware stop bound. If stop or close wins
first, entry fails. Entry and revocation never use an unsynchronized
check-then-act path.

The Entered payload and physical owner change are one primitive. Complex
variable-size receipts are immutable inputs, not part of the atomic write.
EntryCommitRecord, ActivationID, ActivationCommitReceipt, and RunToken are
deterministic projections of the committed cell and preexisting ancestors. A
crash after Entered reconstructs the same IDs; it never replays entry.

ActivationCommitReceipt is evidence, not authority. Initial entry is
authorized by the live permit and entry CAS. Continuation is authorized only
by RunToken plus current protected cells.

## Runtime, Budget, Stop, And Service

ExecutionBudgetCell contains budget escrow already carved from root and
SchedContext reservations. Runtime spending cannot draw from an unrelated
parent. Unused escrow is returned only during settlement.

~~~text
Unreserved
  -> Reserved(rootUseID, schedUseID, amount)
  -> Active(entryGeneration, remaining)
  -> ChargePending(final upper bound)
  -> Settled(consumed, returned, settlementID)

Unreserved or Reserved
  -> ReleasedBeforeEntry(settlementID)
~~~

Consumed plus returned equals the original escrow. Remaining never increases.
Exactly one of Settled or ReleasedBeforeEntry closes both parent budget use
cells.

RuntimeStopCell is the sole runtime revocation authority:

~~~text
Armed/Open(stopGeneration)
  -> StopRequested(stopGeneration + 1, cause)
  -> StopAcknowledged(finalChargeUpperBound, ownerRemoved)
  -> Settled(finalCharge, unusedEscrowDisposition)
~~~

Stop generation is monotonic and nonwrapping. A token binds the entry and stop
generations current at creation. Any later generation is non-executable.
Protected stop/acknowledgment uses management/emergency hardware capacity and
never waits for work owned by the Domain being stopped.

The protected CPU runtime has a bounded RuntimeChargeAccumulator:

~~~text
Unarmed
  -> Armed(executionCellID, quantumUpperBound, localDeadline)
  -> BoundaryRecorded(actualTicks) or CrashCharged(quantumUpperBound)
~~~

Hardware timer and view-exit logic prevent execution beyond the loaded quantum
and local deadline even if Linux disables its tick. A crash with an armed,
unrecorded interval pessimistically consumes the full quantum upper bound.
This prevents budget creation without requiring a durable write on every
resume.

The hot-path distinctions are:

~~~text
InstallContext:
  validate and install a capsule only when the protected CPU context
  generation differs

ArmExecutionQuantum:
  O(1) protected checks for one new activation or execution cell and load one
  bounded quantum

ResumeSameActivation:
  only the same CPU incarnation, ProtectionDomain, ActivationID, subject,
  execution cell, budget account, and stop generation; compare protected
  handles and re-enter within the already armed quantum
~~~

ResumeSameDomain is deliberately not a fast-path authority. A different
subject, FrozenRunUse, SchedContext, activation, execution cell, or budget
account requires a new protected ArmExecutionQuantum even when the MemoryView
does not change. Otherwise hostile Linux could evade budget or subject checks
by relabeling a switch as a resume.

Root budget, SchedContext budget, and execution-cell budget are distinct
conservation ledgers. Admission escrow plus one-time settlement provides the
refinement between them.

requiredServiceTicks is fixed in CurrentOpportunity. ServiceProgressCell is:

~~~text
BelowThreshold(accumulatedTicks)
  -> ThresholdReached(endTick, exact verified interval set)

BelowThreshold(accumulatedTicks)
  -> ClosedBelowThreshold(cause)
~~~

The protected runtime engine is the sole writer. Intervals are nonoverlapping,
belong to the exact ActivationID, and are capped by its escrow. ThresholdReached
is the service linearization point. Deadline claims compare endTick, not later
receipt-publication time.

DeliveryAccountingCell is:

~~~text
Unaccounted
  -> Accounted(ExecutionDeliveryReceiptID)
  -> terminal

Unaccounted
  -> NotDelivered(typed cause)
  -> terminal
~~~

The qualifying receipt is published once after active owner removal and final
charge. Duplicate completion is idempotent. A served terminal requires
ThresholdReached plus Accounted. An unserved terminal records a claim-excluded
external withdrawal or InternalGuaranteeViolation.

TerminalOutcomeCell can commit only when the permit is nonlive, no physical
owner exists, RuntimeStopCell is Settled or entry never occurred,
ExecutionBudgetCell is settled, ServiceProgressCell and
DeliveryAccountingCell are terminal, device/DMA residuals are drained, and
every publication/failure obligation is closure-terminal. Terminal states are
absorbing.

## Boot-Crash Choice

MonitorBootEpoch replacement invalidates every old RunToken and installed
context generation. R8 chooses safety over transparent activation resumption:

~~~text
post-entry boot crash:
  remove or fail-stop the physical owner through the boot root
  pessimistically charge every armed quantum
  force the same ActivationID through stop, accounting, and terminal recovery
  never issue a replacement token for that ActivationID
~~~

A later recurring opportunity may allocate a new activation. Cluster
continuity policy decides whether the stream incarnation may remain the same.
Recovery without durable entry evidence never performs another physical entry.

## CPU Hotplug And Local Migration

CPU identity is the pair of hardware CPU ID and nonwrapping CpuIncarnation.
OfflineCPU advances the protected incarnation, rejects new ready/entry work,
requests stop for its active owner, pessimistically charges any armed quantum,
and invalidates every old InstalledContextCell, receipt, lease, and token for
that incarnation.

OnlineCPU begins empty in a new incarnation. Capacity enters the hierarchy only
through a new future-effective admission transition.

Local migration never moves a live RunToken or EntryOutcomeCell. It performs:

~~~text
source mint fence and stop request
source StopAcknowledged, charge, and residual settlement
new target execution-cell and CPU-incarnation reservation
new attempt, context snapshot, permit, and EntryOutcomeCell
target entry after the source residual upper bound
~~~

Within one Monitor consistency domain, the local transfer cell supplies this
ordering without quorum. Cross-node migration uses the no-reissue transfer
protocol. Linux affinity or migration state is only a proposal.

## Total Lifecycle

The abstract lifecycle is a total function of authoritative cells:

~~~text
Open
AttemptAllocated
InputBound
StagingInert
PreparedPermitPending
PreEntryEligible
EnteredUnserved
ServiceThresholdReached
StopRequested
StopAcknowledged
Settling
ServedTerminal
UnservedTerminal
InternalGuaranteeViolation
~~~

Every finite product value maps to exactly one abstract state. Malformed or
contradictory products map to A_ModelError; WellFormed proves that state
unreachable. They do not silently receive withdrawal credit or become an
ordinary internal violation.

Activated and served bits are derived monotonic observations. They do not
authorize an action. No terminal state is reachable while an executable token,
live permit, active owner, unsettled budget, unresolved device effect, or
dependent publication remains.

## Failure Closure And Merge

Admission records exact bounded reverse edges and cleanup reservation for each
authority object. A failure can traverse only the canonical component's
precharged topology. It cannot scan all Domains, tasks, scopes, or node memory.

Capacity is charged for the maximum connected failure component permitted by
the admitted topology. If two individually admitted components may merge
beyond their local reservations, admission must also reserve a cover-ancestor
or node fail-stop path sufficient to fence both. Merge never creates
unreserved cleanup capacity.

Each failure has a protected FailureJoinCell:

~~~text
canonicalRootID
rootGeneration
membershipGeneration
parentRootID or None
fixedPointGeneration or None
~~~

Every journal append CASes:

~~~text
expected canonicalRootID
expected rootGeneration
expected membershipGeneration
expected journal version
one exact precharged edge/work result
~~~

Workers resolve the canonical root before every append. Intersecting failures
merge through one protected operation that compares both root versions,
selects the deterministic canonical parent, advances membershipGeneration,
unions only precharged work, and invalidates every old fixed-point claim. A
late merge into a completed root creates a new generation and completion pass;
gates never reopen.

The durable journal contains closed gates, frontier slots, discovered uses,
topology generations, per-scope closeCut and terminal prefixes, scan cursors,
pass generation, and checkpoint cursor. Discovery consumes one prepaid
unexplored-edge credit before creating explicit work. The sum of undiscovered
credit and explicit work potential never increases.

Completion is one protected fixed-point CAS over:

~~~text
canonical root and rootGeneration
membershipGeneration
all included scope generations and closeCuts
topology generations
empty bounded frontier
complete terminal prefixes and residual drains
one no-change pass at those exact versions
~~~

Complex discovery and proof construction may run in an untrusted service
Domain. The Monitor applies only bounded, generation-checked cell operations
against predeclared edges. This is an optimization only. The protected
protocol retains a complete generic fallback cursor over the same precharged
adjacency and can execute every closure microstep through reserved protected
occurrences. Missing or corrupt service output selects that fallback or
fail-closed cover; it never creates a Linux-fairness rely or expands authority.
Failure cleanup cannot depend on renewal of a scope it has closed.

## Restart, Checkpoint, And Garbage Collection

R8 distinguishes attempt-shard, failure-component, lane, and whole Monitor
boot-epoch restart. Durable and volatile fields are explicit.

Recovery rules are deterministic:

~~~text
uncommitted outcome:
  abort or complete the same preallocated transaction according to its durable
  outcome root; never allocate a replacement identity implicitly

committed outcome:
  reconstruct the same IDs and complete idempotent projections

armed unrecorded execution quantum:
  charge its full upper bound and stop before reuse

unfinished stop:
  resume the same stop generation before any new entry
~~~

The checkpoint watermark is a version vector over every recoverable shard,
failure root, scope prefix, transfer, audit stream, publication, and reference
cursor. Garbage collection requires terminal authority, nonwrapping generation
advance, and vector dominance over every live cursor.

During an unbounded partition or delayed reference, safe collection also
requires expiry of the exact lease/epoch that could authenticate that
reference. Otherwise a tombstone is retained. A compact checkpoint may replace
a closed prefix only if it authenticates the same terminal facts. GC is never
a prerequisite for completing already issued work.

## Compact Recurrence And Storage

Each recurring stream is represented by:

~~~text
ClosedPrefixCertificate
CompactCalendarDescriptor
at most KLiveSuffix exact live, retiring, or uncertain ordinal records
~~~

The descriptor deterministically derives
ProtectedWorkOccurrenceID(stream, ordinal, workClass, microstep); it does not
require an unbounded stored occurrence array. A derived ID is accepted only
within the current descriptor epoch and admitted ordinal window.

Admission or renewal backpressures before the bounded suffix, reverse-edge,
audit, transfer, or protected-work capacity would overflow. Closed history is
compacted only after checkpoint-vector dominance. Metadata is proportional to
admitted live/retiring authority plus fixed configuration, not total
datacenter uptime.

## Typed Time

Every time value is a typed tuple of ClockDomainID, ClockEpoch, value, and
uncertainty. Arithmetic and comparison require the same domain and epoch.

A direct ClockRelationCertificate binds exact source/destination domains,
epochs, transfer identity, validity interval, drift/error bounds, and monotonic
mapping. Transitive clock inference is forbidden.

Direction is explicit:

~~~text
not-before or source-stop boundary:
  use the latest possible destination image; destination lower bound must be
  at or beyond it

not-after, expiry, or deadline:
  use the earliest possible destination image; destination upper bound must
  remain before it
~~~

The relation and both local clock observations are rechecked at physical entry.
Expiry, relation invalidation, or epoch change rejects entry and requests stop.
Wall-clock labels never authorize execution.

## Transfer And Lost-Effect Boundary

R8 replaces the misleading draft name QUORUM_ENTERED_FENCE with:

~~~text
LOCAL_ONLY
QUORUM_NO_REISSUE_FENCE
~~~

The old phrase remains only as a terminology alias in the rejection ledger.
Nothing replicated before physical entry can prove that entry occurred.

LOCAL_ONLY performs no remote pre-entry fence. After source loss, the same
service-stream incarnation cannot continue under an exactly-once or gap-free
claim. Recovery produces ContinuityLost and a new incarnation, or remains
stopped.

QUORUM_NO_REISSUE_FENCE durably replicates a NoReissueFenceRecord containing
the exact ActivationInputCore, preallocated EntryOutcomeCell generation,
ordinal, source placement, and transfer identity before the physical entry gate
may open. The record means this ordinal may execute and is irrevocably
consumed. A successor never reissues it. It does not mean execution or service
definitely occurred.

The cluster interface for R8 assumes a crash/omission quorum with authenticated
non-equivocating members under its declared fault threshold. Byzantine quorum
members or compromised Monitor roots are outside this component claim and
must be handled by a later stronger cluster/attestation model.

Every predecessor placement has one issuer/placement-owned
PredecessorTransferDecisionCell:

~~~text
Open
  -> MintFenced(TransferID, successor, qCut, sourceFenceGeneration,
                complete immutable transfer plan)
  -> FinalizedStrong(exact terminal-prefix and time evidence)
  -> FinalizedSafeGap(exact uncertainty and withdrawal evidence)
  -> FinalizedContinuityLost(new incarnation, evidence)

Open or MintFenced
  -> Rejected(reason)
~~~

MintFenced is committed before collecting final evidence so the source cannot
issue a new ordinal between evidence collection and decision. Finalization
cannot alter successor, qCut, variant eligibility, plan, or source fence.

qCut is a half-open ownership boundary:

~~~text
predecessor may own ordinals q < qCut
successor may own ordinals q >= qCut
source issuance and entry for q >= qCut are fenced at MintFenced
~~~

For FinalizedStrong, every predecessor ordinal below qCut has an exact
replicated terminal result. A NoReissueFence without a terminal result is
insufficient.

For FinalizedSafeGap, qCut is strictly above every issued, prepared,
fenced-to-enter, entered, or otherwise ambiguous predecessor ordinal. Each
skipped guaranteed ordinal needs a valid claim-excluded external withdrawal
whose cause began before its deadline. SafeGap preserves CPU-authority
nonduplication but does not assert that an uncertain physical effect did not
occur.

Pre-entry fencing alone cannot provide exactly-once socket, storage, DMA,
device, or remote-service effects. Such a claim requires endpoint-owned
idempotency keys, transactions, or durable settlement receipts in later
endpoint models.

Destination entry is later than the directly converted source stop,
residual-execution, DMA/device residual, uncertainty, old-lease expiry, and
independent watchdog upper bounds. Network silence is never source quiescence.

## Partition Semantics

Partition lease import has a finite policy class:

~~~text
CONNECTED_ONLY
CONTINUE_TO_CONSERVATIVE_EXPIRY
RECOVERY_ONLY
~~~

CONNECTED_ONLY means one fresh, consumed authorization observation per exact
attempt. CONTINUE_TO_CONSERVATIVE_EXPIRY permits only authority already sealed
before partition until its local conservative horizon. RECOVERY_ONLY permits
only predeclared stop, settlement, audit, and recovery operations.

During quorum loss, no new quorum fence, strong transfer, or renewal is
created. Existing finite local authority may continue only to its conservative
horizon. Instant global revocation and unrestricted partition availability are
not both claimed. Under unbounded partition R8 claims safety and horizon
fail-stop only, not availability, maximum service gap, or same-incarnation
continuity.

## Execution Granularity And Protected Scheduler Portal

R8 separates three costs and lifetimes:

~~~text
ContextInstall:
  rare, exact ProtectionDomain context generation; static physical receipts

ResidencyActivation:
  bounded lease/placement/partition epoch; execution-cell pool, publication,
  failure, transfer, and context-use authority

ExecutionDispatchUse:
  one exact subject/service occurrence under a resident Domain; FrozenRunUse,
  SchedContextUse, ExecutionChargeUseKey, one-use dispatch cell, budget quantum,
  entry outcome, stop, and accounting
~~~

The full context construction is not repeated for every wakeup or Linux
timeslice. CurrentOpportunity denotes one contiguous root-scheduler service
cell. Admission proves that its physical cell upper bound can contain
requiredServiceTicks plus protected entry/stop overhead. Several accounting
quanta may be armed inside the cell, but the ProtectionDomain physical owner is
not replaced between them.

ResumeSameActivation is limited to interrupt, exception, or protected-boundary
return while that same owner remains active. Once the portal removes or
replaces the owner, that ActivationID can only stop and settle; it cannot
perform a second physical entry. A later root cell is a new opportunity and
dispatch use.

Pre-entry failures may consume further bounded attempt ordinals. Once any
attempt reaches Entered, the opportunity allocates no later attempt. Execution
below the required threshold after entry is a typed external withdrawal or an
InternalGuaranteeViolation, never a silent retry that could duplicate effects.

A different subject, SchedContext, charge account, or execution-cell lease is
a different dispatch use, even when it reuses the same ResidencyActivation and
installed MemoryView.

ExecutionChargeUseKey fixes which principal is charged when executor, caller,
donor, service Domain, or proxy subject differ. It is immutable for a dispatch
use. Async or proxy execution cannot default to worker current.

Hostile Linux-owned rq state cannot be the source of guaranteed readiness.
Before TASK_RUNNING or an equivalent async-ready state, a validated
ProtectedReadyCell records a bounded one-use dispatch descriptor:

~~~text
ProtectionDomainKey and residency generation
ExecutionSubjectKey and generation
FrozenRunUse and SchedContextUse
ExecutionChargeUseKey
opportunity and dispatch-use identity
expiry, CPU constraints, and cancellation generation
~~~

Guaranteed recurring streams pre-register an immutable dispatch template.
Protected calendar release creates their ready record without waiting for a
Linux enqueue. Linux may suggest best-effort candidates or request withdrawal
only through protected validation. Once accepted, it cannot hide, replace, or
retarget the descriptor. Cancellation advances its protected generation.

Cross-Domain scheduling enters a protected scheduler portal whose mutable
state is outside every Domain MemoryView. The portal:

~~~text
stops or bounds the previous physical owner
selects a due admitted Domain from Monitor-owned ready/calendar state
selects the exact protected dispatch descriptor
installs or reuses the destination context
arms the destination execution cell and timer
commits EntryOutcomeCell as the final CPU-enable point
~~~

Linux rq, rq->curr, class pickers, core cookies, or task pointers are advisory
shadows. The physical CPU cannot cross a ProtectionDomain boundary merely
because Linux called context_switch.

The component liveness claim is delivery of protected CPU service to the exact
registered dispatch use. It cannot guarantee that compromised code inside the
selected Domain performs useful application work.

CPU entry, MemoryView staging, privileged entry state, code epoch, device
lease, IRQ routing, and DMA drain are separate typed interface state machines.
They are prepared and validated before entry. EntryOutcomeCell refines only the
final CPU-enable gate; it does not pretend that one physical CAS updates all
subsystems.

## Protected Work And Liveness

Every guaranteed internal item receives admission-reserved exact occurrences
for all bounded microsteps. Work classes are separate:

~~~text
opportunity and dispatch activation
failure closure
transfer
restart and recovery
garbage collection and namespace retirement
management and emergency stop
~~~

External evidence must be present in an environment-owned readiness cell before
an internal occurrence is assigned. Waiting for network, issuer, storage, or
operator response consumes no internal occurrence and no internal rank step.
Its absence leads only to a named external timeout/withdrawal branch.

R8 does not represent a pending ProtectedTurnPulse that TLA stuttering could
leave forever. The trusted hardware interface performs one atomic
ExecuteProtectedOccurrence action:

~~~text
choose the exact due item and occurrence from protected calendar state
emit ProtectedTurnPulse as a trace observation
execute one bounded microstep or one typed fail-closed terminal result
advance the occurrence cursor
~~~

Liveness is conditional on the explicit provider formula
ProtectedOccurrenceDeliveryOrHardwareFailStop. This is a hardware/Monitor rely,
not Linux fairness. No internal action can consume an occurrence without
advancing its exact item.

Separate well-founded ranks exist:

~~~text
OpportunityRank =
  (attemptAllocationsRemaining,
   currentAttemptPhaseRank,
   currentMicrostepsRemaining,
   protectedOccurrencesUntilNextStep,
   settlementStepsRemaining)

FailureRank =
  multiset(unexploredEdgeCredits, explicitWorkPhase, closePrefixDistance,
           noChangePassRemaining)

TransferRank =
  (decisionBranchesRemaining, sourceFenceSteps, evidenceSteps,
   destinationEnableSteps, settlementSteps)

RestartRank =
  (recordsRemaining, recoveryPhase, projectionCompletionsRemaining)

GCRank =
  (checkpointVectorDistance, cursorDistance, objectsRemaining)
~~~

Allocating a new attempt consumes the outer attempt component before any inner
component resets. Discovery transfers prepaid potential into explicit work and
strictly decreases a multiset measure. Recurring release creates a new finite
item under the recurrence theorem; it is not forced into one globally
decreasing rank.

The per-opportunity theorem is conditional only on named exogenous stability,
freshness, protected hardware occurrences, and reserved capacity. Internal
Operational, successful protocol completion, or absence of
InternalGuaranteeViolation cannot appear as an assumption.

## Shards, Locality, And Datacenter Scale

Logical owner shards are independent of CPUs. A protected action writes one
target shard or one explicitly shared root cell. Disjoint transition
publication, local apply, stop, failure, restart, and namespace retirement
commute.

At least two lanes are modeled with distinct parent-reserved physical CPU
cells and target-control turns. One target turn advances at most one exact
target item. Local apply does not wait for another shard. Tentative or
committed-but-not-visible transitions cannot execute; a committed-visible
transition is not revalidated into rejection or rolled back at apply.

The structural cost contract is:

~~~text
admission:
  O(NodeConfig-bounded affected lineages, hierarchy depth, shards, and proof)

static context install:
  O(KStaticReceipts), outside ordinary dispatch

residency activation:
  O(KPrerequisites + KDynamicReceipts + KScopesPerTxn), bounded and off the
  ordinary resume path

new dispatch use or Domain switch:
  O(1) protected handles, generations, ready cell, budget cell, and one local
  entry primitive

same-activation resume:
  O(1) compare inside an already armed quantum; no durable publication or
  remote operation

lease invalidation:
  O(1) gate generation update plus O(active affected lanes) reserved stop work

ordinary settlement/release:
  no scan over admitted Domains or closed history

scoped failure:
  O(precharged connected-component edges plus affected scope depth), no
  population scan

namespace exhaustion:
  scoped quiescence/renewal; no disjoint-lane stop
~~~

These are ownership and transition-footprint claims for later executable
checking. They are not measured latency, throughput, memory, energy, or cost
claims. Strong continuity necessarily adds quorum and endpoint-settlement
cost; R8 does not claim it is cheaper than a VM for every workload.

## Linux Refinement Boundary

Linux is an untrusted policy and mechanism producer. It may propose:

~~~text
FrozenRunUse and SchedContext selections
CPU placement and migration
context-install, residency, and dispatch descriptors
failure work and transfer evidence
async carrier provenance and charge attribution
~~~

The Monitor validates bounded typed objects and owns authority cells. Linux
task_struct, rq state, cgroup state, namespace state, credentials, LSM
decisions, BPF state, and scheduler-class metadata are shadows or policy
inputs only.

The eventual refinement must preserve existing Linux behavior when disabled
and scheduler-class semantics inside admitted authority. It must cover:

~~~text
CFS/EEVDF, RT, deadline, sched_ext, core scheduling, proxy execution,
stop/idle and class-loop selection
wakeup, enqueue, pick, context switch, tick and NO_HZ
migration, affinity, cpuset, hotplug, push/pull and swap
fork/clone, exec, exit and post-exit async aftermath
workqueue, task_work, io_uring workers, softirq, IRQ, timers, RCU and kthreads
service-Domain IPC and endpoint/device completion
~~~

Domain-derived asynchronous work requires an immutable typed carrier containing
ProtectionDomainKey, caller authority, service authority, and
ExecutionChargeUseKey. Effective authority is the intersection of service
authority and caller-frozen authority. Generic kernel-internal work is
separately classified as Monitor/core work, Domain-local work, or
service-Domain work.

Reusing one coalescing work_struct may not overwrite caller authority. A
coalesced item needs a bounded aggregate of immutable authority/charge records
or separately queued immutable items. Worker current is never provenance.

No Linux hook location is selected by this architecture. Current upstream
source identity and drift must be recaptured before later refinement or patch
approval. Earlier small-patch maintenance estimates are not architecture
evidence.

## Minimal Trusted Computing Base

The local Monitor owns only:

~~~text
canonical protected IDs and nonwrapping generations
Domain/context registry and local status gates
protected ready/calendar state and scheduler portal
constant-size attempt, publication, entry, stop, budget, and transfer cells
physical MemoryView/entry/timer/IOMMU roots through later refined interfaces
parent capacity escrow and protected occurrence dispatch
bounded certificate validation and fail-closed recovery
immutable audit root and checkpoint identity
~~~

Complex policy, certificate construction, topology search, failure worklist
proposal, logging storage, and service implementation may be outside the
Monitor. Their output is untrusted and accepted only through bounded typed
validation. Unavailable untrusted services may reduce availability but cannot
mint authority. A later TCB-size and attack-surface evaluation is mandatory;
R8 does not assert that this boundary is already smaller than KVM/VMM.

## Mutable-Cell Ownership

Each mutable field has exactly one writer authority:

| Cell | Sole writer | Authority meaning |
| --- | --- | --- |
| ContextInstallOutcome | context-install Monitor owner | static install won or aborted |
| CurrentCapsule | Domain registry owner | current reusable context generation |
| InstalledContext | protected CPU portal | exact context installed on one CPU |
| ResidencyStatus | residency owner | admitted local residency generation |
| SubjectStatus | subject registry owner | current subject/process/program generation |
| SchedContextStatus | scheduling-authority owner | current budget/policy generation |
| RunAuthorizationStatus | run-authority owner | current target/use/revocation generation |
| ChargeRuleStatus | charge-authority owner | exact executor/caller/donor/service rule |
| RunAuthorizationUse | run-use reservation owner | one dispatch binding and consumption |
| SchedContextBudgetUse | SchedContext budget owner | one escrow charge and return |
| RootBudgetUse | root budget owner | one parent escrow charge and return |
| ChargeUse | charge-rule owner | one exact dispatch attribution |
| AuthorityReservationOutcome | reservation transaction owner | all required authority reserved or all released |
| AdmissionOutcome | affected-lineage admission owner | rejected or one future-effective CommittedVisible transition |
| StreamCursor | recurring-stream owner | next release ordinal and bounded suffix |
| RequestCancellation | request-member owner | monotonic cancellation generation and disposition |
| CpuIncarnation | hardware CPU provider | online/offline identity and invalidation root |
| ProtectedReady | ready-cell owner | exact one-use dispatch candidate |
| ActivationDecision | stable opportunity shard | attempt allocation and terminal pointers |
| Attempt | attempt owner | exact attempt phase |
| PrepareOutcome | prepare owner | inert bundle committed or aborted |
| PermitOutcome | protected permit owner | one-use pre-entry permit |
| EntryOutcome | hardware CPU-enable gate | physical execution may have begun |
| RuntimeStop | protected runtime engine | stop generation, acknowledgment, settlement |
| ExecutionBudget | protected timer/accounting engine | escrow, armed quantum, final charge |
| ServiceProgress | protected runtime engine | service-threshold end tick |
| DeliveryAccounting | settlement owner | qualifying delivery or typed non-delivery |
| TerminalOutcome | opportunity settlement owner | absorbing opportunity disposition |
| ScopeGate | scope authority owner | Open/Closing/Closed and generation |
| PublicationOutcome | publication transaction owner | Aborted or CommittedVisible |
| FailureJoin | failure registry owner | canonical root and membership generation |
| FailureJournalSlot | canonical-root protected worker | one generation-checked work result |
| TransferDecision | issuer/placement owner | one successor and qCut decision |
| Environment evidence | named untrusted actor | input observation, never authority |
| Provider interface state | named trusted provider | exact conditional external guarantee |

An action needing several logical updates linearizes on one named outcome cell
or one explicitly bounded canonical local transaction. Other fields are
deterministic, idempotent projections. No prose role such as Linux plus
Monitor, shard and hardware, or quorum path is a writer.

## Closed Action Inventory

The R8 machine IR may refine these actions into bounded indexed instances but
may not add a new semantic action without reopening architecture review:

~~~text
Context:
  ReserveDomainContext, StageStaticComponent, CommitContextInstall,
  AbortContextInstall, BeginContextClose, RevokeContext, RetireContext

Subject and scheduling authority:
  RegisterSubject, SpawnSubject, AdvanceProgramGeneration,
  BeginSubjectExit, CompleteSubjectDrain, RetireSubject,
  CreateSchedContext, ReserveSchedBudget, SettleSchedBudget,
  CloseSchedContext, IssueRunAuthorization, RevokeRunAuthorization,
  FreezeRunUse, CreateChargeRule, RevokeChargeRule

Admission and recurring request:
  BeginAdmission, ValidateAdmissionFootprint, SealAdmissionEnrollment,
  CommitAdmissionVisible, RejectAdmission, ApplyFutureTransition,
  ChangeServiceClass, ReleaseOpportunity, CancelRequestMember,
  CloseRequestMember, EvictResidencySlot, ReuseResidencySlot

Residency:
  ReserveResidency, BeginResidencyPublication, CommitResidency,
  RejectResidency, BeginResidencyClose, StopResidency, RetireResidency

Ready, opportunity, and input:
  RegisterProtectedReady, CancelProtectedReady, ReserveOpportunity,
  AllocateAttempt, BindActivationRequest, ReserveAuthorityAndBudgets,
  ReserveExecutionCell, ValidatePrerequisiteSet, PublishActivationInput,
  PublishConnectivityObservation, ConsumeConnectivityAuthorization

Publication and prepare:
  BeginPublication, EnrollScope, SealEnrollment, CommitVisible,
  AbortPublication, StageDynamicComponent, SealPreparedBundle,
  CommitPrepare, PublishPermit, RevokePermit, AbortPrepare

Portal, entry, and runtime:
  RootSelectDomain, EnterSchedulerPortal, InstallContext,
  ArmExecutionQuantum, CommitEntry, RejectEntry, CompleteEntryProjection,
  ResumeSameActivation, RecordExecutionBoundary, CrashChargeQuantum,
  RecordServiceThreshold, RequestStop, AcknowledgeStop, SettleRuntime,
  CommitDelivery, CommitNonDelivery, CommitTerminal

Close and failure:
  BeginClose, AdvanceTerminalPrefix, CreateFailureRoot,
  AppendFailureWork, DiscoverFailureEdge, MergeFailureRoots,
  CompleteFailurePass, CompleteFailureRoot

Transfer:
  BeginSourceMintFence, ReplicateNoReissueFence,
  PublishTransferEvidence, FinalizeStrongTransfer,
  FinalizeSafeGapTransfer, FinalizeContinuityLoss, RejectTransfer,
  BeginLocalMigration, FinalizeLocalMigration

Recovery and reclamation:
  CrashVolatileState, RecoverOutcome, RecoverStop, RecoverFailure,
  CommitCheckpointVector, CollectTerminalObject, ReplaceScopedNamespace

Trusted provider:
  ExecuteProtectedOccurrence, AdvanceProtectedClock, OfflineCPU, OnlineCPU,

Untrusted environment:
  PublishExternalEvidence, WithdrawExternalAuthority,
  PartitionChannel, RestoreChannel
~~~

PublishConnectivityObservation and ReplicateNoReissueFence are trusted cluster
provider actions. CrashVolatileState is a typed fault action. Next is the exact
disjunction of bounded instances of this list. UntrustedExternal actions may
read immutable internal requests but write only environment-owned fields.
Trusted provider actions write only their declared provider interface fields.
Each action declares actor class, guard AST, exact read/write sets, UNCHANGED
complement, linearization cell, crash successor, abstract refinement, and rank
delta.

The following critical contracts fix the semantic choices that action ASTs
must implement:

| Action | Required current facts | Linearization and authoritative effect |
| --- | --- | --- |
| CommitAdmissionVisible | exact affected-lineage snapshot, sealed enrollment, feasible conserved capacity, every local gate current | canonical local transaction CASes AdmissionOutcome to CommittedVisible with future boundary |
| ApplyFutureTransition | CommittedVisible and due boundary, target generation unused | deterministic local projection only; cannot reject or change committed authority |
| ChangeServiceClass | current residency and complete replacement admission | publish new future generation; old generation only closes/stops/settles |
| ReleaseOpportunity | due compact calendar ordinal, suffix/ready/work capacity reserved | StreamCursor CAS burns ordinal and publishes exact OpportunityID |
| CancelRequestMember | exact current cancellation generation | RequestCancellation CAS advances generation and selects the phase-specific stop/settle path |
| OfflineCPU | exact online CpuIncarnation | provider advances incarnation and forces protected stop/charge; old CPU-bound objects become stale |
| FinalizeLocalMigration | source stopped/settled, target reservation current, residual bound passed | local transfer cell enables only a new target attempt and entry identity |
| FreezeRunUse | live exact subject/program, RunAuthorization, SchedContext, charge rule, and horizon | publish immutable FrozenRunUse; no authority cell consumed |
| RegisterProtectedReady | released guaranteed template or validated best-effort request, open residency, fresh FrozenRunUse | CAS unused ProtectedReady to Ready with exact cancellation generation |
| AllocateAttempt | Ready, opportunity Open, no active attempt, ordinal available | DecisionCell CAS burns ordinal and publishes exact CAS receipt |
| ReserveAuthorityAndBudgets | exact attempt/request, all parent cells current, complete capacity available | AuthorityReservationOutcome CAS to ReservedAll; recovery exposes all or releases all |
| PublishActivationInput | ReservedAll, final lease/use identity, complete prerequisite core set | immutable ActivationInputCore; no execution authority |
| ConsumeConnectivityAuthorization | exact local certificate and unused cell | one-use-cell CAS and same deterministic receipt |
| CommitVisible | sealed exact local enrollment set, every canonical gate Open/current | bounded local protected transaction CASes PublicationOutcome to CommittedVisible |
| BeginClose | exact gate Open/current | same local ordering domain changes gate to Closing, advances generation, fixes closeCut, and queues reserved stop |
| CommitPrepare | exact input/plan/staging/receipts/horizon, all use cells Bound, gates current | PrepareOutcome CAS to Prepared and logically binds execution-cell use |
| PublishPermit | exact Prepared outcome and current gates | PermitOutcome CAS to Live for one deterministic permit |
| RevokePermit | Live or Unpublished and stop/close/cancel/expiry cause | PermitOutcome terminal Revoked; cannot race past earlier EntryOutcome |
| RootSelectDomain | due admitted protected calendar cell and Ready descriptor | root-scheduler protected selection; Linux rq cannot suppress or substitute |
| CommitEntry | live permit, Pending entry, current local gates, Reserved budget, no conflicting owner | same ordering domain atomically sets EntryOutcome Entered and final CPU owner |
| ArmExecutionQuantum | Entered owner, same activation/use/budget/stop generations, positive remaining | protected accumulator Armed with bounded quantum/deadline |
| ResumeSameActivation | accumulator already Armed and exact physical owner never replaced | compare-only protected return; creates no new entry or budget |
| RecordExecutionBoundary | Armed accumulator and protected exit | record actual bounded ticks, decrement remaining, clear accumulator |
| CrashChargeQuantum | durable Armed without boundary | charge full upper bound, clear accumulator, request stop |
| RecordServiceThreshold | accumulated verified ticks first reach requirement | ServiceProgress CAS records exact endTick once |
| RequestStop | entry active or prepared authority invalidated | RuntimeStop CAS advances generation; new arm/resume rejects |
| AcknowledgeStop | requested generation and physical owner removed with residual receipt | RuntimeStop to StopAcknowledged; cannot depend on target Domain work |
| SettleRuntime | stop acknowledged or NeverEntered, final charge/residual known | RuntimeStop CAS to Settled fixes charge and disposition once; budget and parent returns are idempotent projections |
| CommitDelivery | threshold endTick valid and runtime settled | DeliveryAccounting CAS publishes one qualifying receipt |
| CommitTerminal | all nonauthority, residual, accounting, publication, and failure predicates terminal | TerminalOutcome CAS to absorbing exact disposition |
| MergeFailureRoots | two current roots, exact generations, admitted union or cover fail-stop reserve | compare both roots, choose canonical parent, increment membership generation, invalidate fixed point |
| CompleteFailureRoot | exact fixed-point tuple and every dependent slot terminal | FailureJoin CAS records completion for that exact generation |
| BeginSourceMintFence | transfer cell Open and source issuance state current | issuer CAS to MintFenced fixes successor, qCut, plan, and source generation before evidence |
| ReplicateNoReissueFence | quorum policy selected and exact ordinal/input pending | cluster provider records irrevocable no-reissue fact before local entry |
| FinalizeStrongTransfer | MintFenced and terminal prefix exactly reaches qCut with time/residual evidence | same decision cell to FinalizedStrong; destination not-before fixed |
| FinalizeSafeGapTransfer | MintFenced and every ambiguity below qCut has exact withdrawal evidence | same cell to FinalizedSafeGap without asserting absence of effects |
| ExecuteProtectedOccurrence | exact due protected item and provider progress condition | one atomic microstep or typed fail-closed result plus occurrence-cursor advance |
| RecoverOutcome | durable outcome root and boot/restart class fixed | complete same-ID projections or exact abort/stop branch; no new identity |
| CollectTerminalObject | terminal object, expired possible references, checkpoint vector dominates | reclaim and advance nonwrapping generation; otherwise retain tombstone |

All projection-completion actions are idempotent and cannot change an outcome
root. A machine IR may split a row only into crash-visible microsteps already
named by its outcome protocol; such a split cannot add another success choice.

## Crash-Cut Matrix

The mandatory deterministic cuts are:

| Cut | Recovery result |
| --- | --- |
| connectivity before consume CAS | certificate remains unused |
| connectivity after consume CAS | same receipt, never a second consume |
| partial authority/budget reservation | same transaction reaches ReservedAll or releases every partial cell |
| static or dynamic staging before outcome | dirty but inert; same transaction completes or aborts |
| prepare outcome before permit | same permit publishes or is revoked; no entry |
| permit before entry outcome | no physical execution; revoke or abort is safe |
| entry outcome committed | same ActivationID; never replay CommitEntry |
| execution quantum armed | pessimistically charge full quantum and stop |
| service threshold recorded | preserve exact endTick and complete settlement |
| stop requested | resume same stop generation before reuse |
| owner removed before charge projection | owner stays removed; deterministic charge completes |
| delivery outcome committed | same receipt; duplicate accounting is idempotent |
| publication before outcome | recover same transaction and enrollment seal |
| CommittedVisible outcome | never change to Aborted; close and stop dependent uses |
| failure append | old or new exact journal version, never a torn semantic append |
| failure merge | old generation rejects; new root restarts fixed-point pass |
| no-reissue fence replicated | ordinal remains consumed even if local entry is unknown |
| transfer MintFenced | source remains fenced; same plan and qCut finalize or reject |
| transfer finalized | same successor, qCut, and variant only |
| checkpoint before GC | no collection until vector dominance is durable |

Crash occurs only between declared atomic protected actions. Staging microsteps
that can tear are separate actions with explicit durable and volatile fields.
An uncommitted outcome never recovers as a fresh successful identity. A
committed outcome never recovers as a different identity.

## Formal Closure Contract

The future semantic IR has exactly these closed registries:

~~~text
TypeRegistry
ConstantAndBoundRegistry
ActorAndInterfaceRegistry
ObjectSchemaRegistry
MutableFieldOwnerRegistry
FormulaRegistry
ActionRegistry
CrashCutRegistry
RankAndWorkRegistry
ProofComponentRegistry
ClaimAndRefinementRegistry
MutationObligationRegistry
~~~

It defines every bounded type, sort-specific None value, variable, initial
value, overflow result, and exhaustion result. There is one clean Init with no
executable authority, no environment request, all one-use cells unused, all
runtime owners absent, and only declared external roots present.

WellFormed is an invariant, not a guard that hides malformed states.
Init implies WellFormed and every action preserves it. Malformed products map
to A_ModelError for abstraction-totality checking and must be unreachable.

Next is exactly the ActionRegistry disjunction. There is no generic DoWork,
implicit success, favorable recovery choice, wildcard environment action, or
unregistered semantic stutter. Standard TLA state stuttering is handled by
explicit temporal relies for protected-provider progress, never by pretending
that removing a stutter action proves liveness.

Unknown, duplicate, missing, stale alias, extra, unreachable, ownerless,
multiply owned, or unreferenced normative entries reject.

## Proof Dependency DAG

Protected persistence and atomicity is an independent interface. ROOTSCHED-001
and finite RESIDENCY-001 are hash-pinned imported component guarantees that R8
must refine. The prior number 16 is not a security invariant; the current R8
candidate has 19 exact nodes:

~~~text
ENV_CRYPTO_CANONICAL_SEAL
ENV_HARDWARE_TIME_ROOT
ENV_PROTECTED_PERSISTENCE_ATOMICITY
ENV_CLUSTER_ISSUER_QUORUM_TIME
ENV_ENTRY_CODE_STATE_DEVICE_INTERFACE
RESOURCE_HIERARCHY_SET_ALGEBRA
ROOTSCHED_001_REFERENCE
RESIDENCY_001_REFERENCE
DYN_ADMIT
DYN_REQUEST
DYN_CHURN
DYN_RENEW_RESTART
DYN_SHARD
DYN_COMPOSE
DYN_MULTILANE_COMPOSE
OPERATIONAL_PRESERVATION_THEOREM
PER_OPPORTUNITY_RANK_THEOREM
DYN_LIVENESS_THEOREM
DYN_REGRESSION
~~~

The exact predecessor and guarantee ledger is:

| Node | Internal predecessors | Guarantee consumed by successors |
| --- | --- | --- |
| ENV_CRYPTO_CANONICAL_SEAL | none | typed injective encoding, unforgeable seal, nonrollback key epoch |
| ENV_HARDWARE_TIME_ROOT | none | monotonic typed clock, unsuppressible timer, watchdog and protected occurrence delivery or hardware fail-stop |
| ENV_PROTECTED_PERSISTENCE_ATOMICITY | none | durable CAS/order, nonrollback generation, crash cut, and checkpoint-vector persistence |
| ENV_CLUSTER_ISSUER_QUORUM_TIME | none | authenticated crash/omission quorum leases, placement, no-reissue fence, direct clock relation, and threshold non-equivocation |
| ENV_ENTRY_CODE_STATE_DEVICE_INTERFACE | none | inert stage, current-generation receipts, final CPU-enable gate, stop, translation/code/state/device/IRQ/DMA residual bounds |
| RESOURCE_HIERARCHY_SET_ALGEBRA | ENV_CRYPTO_CANONICAL_SEAL, ENV_CLUSTER_ISSUER_QUORUM_TIME | exact finite set, ancestor capacity, disjoint cell, reverse-edge, and cleanup-reservation algebra |
| ROOTSCHED_001_REFERENCE | ENV_HARDWARE_TIME_ROOT, ENV_PROTECTED_PERSISTENCE_ATOMICITY | admitted root-cell conservation, hostile-Linux-independent selection, bounded stop, and guaranteed Domain service |
| RESIDENCY_001_REFERENCE | ENV_CRYPTO_CANONICAL_SEAL, ENV_HARDWARE_TIME_ROOT, ENV_PROTECTED_PERSISTENCE_ATOMICITY, RESOURCE_HIERARCHY_SET_ALGEBRA, ROOTSCHED_001_REFERENCE | fixed finite identity, generation, projection, and one-shot residency safety |
| DYN_ADMIT | ENV_CRYPTO_CANONICAL_SEAL, ENV_HARDWARE_TIME_ROOT, ENV_PROTECTED_PERSISTENCE_ATOMICITY, ENV_CLUSTER_ISSUER_QUORUM_TIME, RESOURCE_HIERARCHY_SET_ALGEBRA, ROOTSCHED_001_REFERENCE, RESIDENCY_001_REFERENCE | bounded dynamic hierarchy/capacity admission, local CommittedVisible publication, residency and protected ready/calendar reservation |
| DYN_REQUEST | ENV_CRYPTO_CANONICAL_SEAL, ENV_PROTECTED_PERSISTENCE_ATOMICITY, DYN_ADMIT | recurring request identity, coalescing, cancellation, ready publication, bounded suffix, and terminal disposition |
| DYN_CHURN | ENV_HARDWARE_TIME_ROOT, ENV_PROTECTED_PERSISTENCE_ATOMICITY, DYN_ADMIT | bounded failure/close least fixed point, merge, total cover, settlement prefix, and disjoint preservation |
| DYN_RENEW_RESTART | ENV_CRYPTO_CANONICAL_SEAL, ENV_HARDWARE_TIME_ROOT, ENV_PROTECTED_PERSISTENCE_ATOMICITY, ENV_CLUSTER_ISSUER_QUORUM_TIME, DYN_CHURN | nonaliasing generation, partition narrowing, deterministic recovery, checkpoint vector, scoped renewal, and fail-closed boot replacement |
| DYN_SHARD | ENV_HARDWARE_TIME_ROOT, ENV_PROTECTED_PERSISTENCE_ATOMICITY, RESOURCE_HIERARCHY_SET_ALGEBRA, DYN_CHURN, DYN_RENEW_RESTART | two-lane parent conservation, target-local apply, commutation, direct-clock transfer, and no cross-lane wait |
| DYN_COMPOSE | ENV_CRYPTO_CANONICAL_SEAL, ENV_HARDWARE_TIME_ROOT, ENV_PROTECTED_PERSISTENCE_ATOMICITY, ENV_CLUSTER_ISSUER_QUORUM_TIME, ENV_ENTRY_CODE_STATE_DEVICE_INTERFACE, ROOTSCHED_001_REFERENCE, DYN_ADMIT, DYN_REQUEST, DYN_CHURN, DYN_RENEW_RESTART, DYN_SHARD | acyclic context/residency/dispatch authority, exact entry/stop/budget/service lifecycle, portal, and total abstraction |
| DYN_MULTILANE_COMPOSE | DYN_SHARD, DYN_COMPOSE | two live recurring lanes with shared roots, scoped failure/transfer, independent service, and noninterference |
| OPERATIONAL_PRESERVATION_THEOREM | DYN_ADMIT, DYN_REQUEST, DYN_CHURN, DYN_RENEW_RESTART, DYN_SHARD, DYN_COMPOSE, DYN_MULTILANE_COMPOSE | every internal action preserves safety, conservation, bounded work, and absence of unexplained fail-stop |
| PER_OPPORTUNITY_RANK_THEOREM | ENV_HARDWARE_TIME_ROOT, OPERATIONAL_PRESERVATION_THEOREM | one admitted opportunity reaches qualifying service or exact claim-excluded withdrawal within its finite rank/calendar bound |
| DYN_LIVENESS_THEOREM | PER_OPPORTUNITY_RANK_THEOREM | finite-horizon recurrence and separate conditional omega recurrence under explicit infinite freshness supply |
| DYN_REGRESSION | DYN_MULTILANE_COMPOSE, DYN_LIVENESS_THEOREM | all mandatory negative models fail for the intended obligation and no claim boundary inflates |

The ledger key set and proof order must be equal. Every internal rely points
only to a predecessor guarantee. Provider formulas name exact provider-owned
variables and fault bounds. Untrusted environment formulas mention only
environment-owned variables.

No theorem may assume Operational, its own conclusion, a descendant
conclusion, internal protocol success, absence of internal fail-stop, or the
work of the Domain being stopped.

Each claim records exact formula IDs, providers, remaining assumptions,
refinement mapping, validator obligations, evidence class, and nonclaims.
Boolean claim flags without formula/provider closure reject.

The cluster provider guarantee is limited to authenticated crash/omission
quorum behavior under a declared threshold. The entry/code/state/device
provider guarantee includes independently modeled CPU enable, MemoryView,
privileged entry, code, mutable-state, device, interrupt, DMA residual, and
stop bounds. The persistence provider supplies the exact nonrollback
generation, CAS, durable ordering, and checkpoint formulas consumed by R8.

## Required Witness And Mutation Families

Before TLA translation, an executable preformal witness and validator must
cover at least:

~~~text
all 41 Analysis 0205 finding IDs with one accepting trace and one mutant
all new R8 review choices: protected persistence, local publication domain,
  no-reissue naming, two-stage transfer, portal, ready state, dispatch
  granularity, service threshold, and boot-crash stop
schema-derived DAG equality and every cycle or back-edge class
winning and losing attempt CAS and ordinal burn
static context reuse, generation invalidation, and same-activation resume
different-subject same-Domain dispatch requiring protected re-arm
hostile Linux hiding, replacing, or replaying rq candidates
every receipt transcript omission, substitution, replay, and wrong Monitor use
every prepare, permit, entry, runtime, service, accounting, and terminal cut
entry versus stop, close, expiry, budget, hotplug, and portal races
verified service threshold, deadline endTick, and pessimistic crash charging
enroll, close, seal, commit, abort, remote-certificate, and prefix-hole cases
late intersecting failure merge, capacity union, stale append, and fixed-point reset
bounded suffix pressure, checkpoint vector, tombstone, GC, and saturation
typed clock direction, relation expiry, and raw-clock rejection
connectivity consume crash and post-observation partition
LOCAL_ONLY loss, NoReissueFence uncertainty, Strong qCut, SafeGap, and dual successor
endpoint effect nonduplication remaining explicitly outside the CPU claim
two disjoint lanes, one shared root, scoped failure, transfer, and no cross-lane wait
external evidence not ready before protected occurrence
rank reset, potential transfer, recurrence induction, and deadline conversion
complete low-state-product abstraction and A_ModelError unreachability
all 19 proof rows, formula providers, owner sets, action sets, and claim mappings
CFS, RT, DL, sched_ext, core, proxy, stop/idle adapter nonclaim coverage
async caller/service/charge identity and coalescing-authority mutants
representation, trace, behavior, concurrency, crash, rank, and validator-gate mutants
~~~

The validator itself is meta-mutated. At least one mutant for every obligation
must be rejected by the intended stable validator ID; aggregate failure alone
is insufficient. A zero-mutant run, disabled check, permissive unknown field,
mutant-equivalent baseline, or validator crash rejects the campaign.

## Review Gate

R8 is eligible for semantic IR encoding only after fresh independent reviews
find no unresolved choice in:

~~~text
authority, activation, portal, and scheduler capability
distributed failure, persistence, time, partition, endpoint effect, and transfer
formal closure, crash, rank, recurrence, and refinement
Linux, async, granularity, TCB, locality, and datacenter composition
~~~

A review can accept a conditional interface while still rejecting a hidden
system-completion claim. Any newly discovered authority owner, action,
linearization point, crash successor, continuity policy, liveness rely, or
cost mechanism changes this architecture and requires another review.

## Current Claim Ceiling

~~~text
R8_human_architecture_written = true
R8_independent_review_passed = false
R8_machine_IR_written = false
R8_witness_executed = false
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
~~~
