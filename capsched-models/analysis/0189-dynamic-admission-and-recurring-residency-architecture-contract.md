# Analysis 0189: Dynamic Admission and Recurring Residency Architecture Contract

Status: Architecture contract before executable specification; adversarial
semantic freeze pending; no implementation or Linux behavior change approved

Date: 2026-08-09

Work record: N-177

Requirement: `RESIDENCY-DYN-001`

## Question

What dynamic admission, recurring-service, cancellation, overload, namespace
renewal, and restart semantics can refine the accepted finite residency model
without trusting Linux, silently losing guaranteed service, or turning
attacker-driven control work into an unbounded Monitor denial of service?

## Verdict

`RESIDENCY-DYN-001` is not a cache replacement algorithm and cannot be
obtained by putting a loop around Formal 0148. It is a Monitor-owned service
contract with three independently finite resources:

```text
authority capacity
  node admission records, root-service contracts, and eligible execution
  capacity

control-work capacity
  admission, residency, drain, revoke, cleanup, and renewal work

namespace capacity
  operation, request, plan, projection, slot, CPU, and boot incarnations
```

All three require admission, ownership, and exhaustion behavior. Bounding only
resident slots prevents an authority alias but still lets hostile Linux starve
guaranteed Domains by filling work state, forcing cleanup, or exhausting a
generation namespace.

The selected semantic shape is:

```text
signed global Domain authority
  -> typed NodeLeaseImportCertificate and GlobalPlacementUse
    -> Monitor-owned node-local AdmissionContract
    -> immutable, capacity-certified RootServicePlan epoch
      -> Monitor-generated one-shot ResidencyObligation sequence
        -> bounded PhysicalResidencyTxn
          -> exact held ResidentBinding
            -> non-executable ActivationIntent
              -> joint ROOTSCHED/ENTRY/CODE/STATE activation commit
                -> exact budgeted execution and settlement

Linux-originated best-effort hints
  -> attributed, bounded, separately serviced proposal mailbox
  -> no guaranteed obligation, admission, cancellation, or authority
```

The active service plan remains valid while a candidate is built and checked.
A candidate becomes authoritative at one Monitor-owned commit point only after
all root-service, residency-work, operation-state, eligible-context, recovery,
and namespace-renewal resources have been reserved. A rejected or abandoned
candidate leaves the current contract unchanged.

An immutable plan epoch is a semantic requirement, not a choice of a literal
cyclic table. A verified deadline/deficit server, hierarchical reservation
tree, or another bounded policy may refine it later if it preserves the same
capacity, debt, cutover, and progress obligations.

## Exact Scope of Dynamic Join

This contract begins with a typed `NodeLeaseImportCertificate` and, for every
exclusive or replicated placement, an exact `GlobalPlacementUse`. It models
validating and attenuating those imported objects into one node-local service
contract. It does not issue global Domain identity, implement cluster quorum,
or promise instantaneous remote revocation. It does define the complete input
schema and conservative partition behavior that later `CLUSTER-PART-001` must
refine; an untyped "valid lease" is not an admissible rely.

Those responsibilities remain with `MGMT-001` and `CLUSTER-PART-001`:

```text
global identity issuance and delegation
  outside RESIDENCY-DYN-001

node-local validation, attenuation, capacity reservation, and admission
  inside RESIDENCY-DYN-001

remote lease issuance, quorum operation, and no-fork evidence production
  later CLUSTER-PART-001 component

typed lease import, conservative local horizon, immutable partition mode,
and cross-node placement-fence consumption
  inside RESIDENCY-DYN-001
```

A valid management authority may explicitly withdraw, demote, or revoke a
contract within its delegated rights. Continuous service for that withdrawn
contract is then impossible by definition. The Monitor must still reject a
signed overcommit, rollback, malformed transition, or removal of the sealed
management/recovery reserve. The consequences of a malicious but valid
management principal remain a named `MGMT-001` obligation.

## Threat Subjects and Trust Boundary

For this contract, adversarial Linux means the entire Linux-visible adapter
surface may be controlled after a Domain-originated kernel exploit. It may:

```text
omit, delay, duplicate, reorder, corrupt, or misroute every hint and reply
forge arbitrary unsealed Domain IDs, task state, rq state, cgroup state, and
Linux object lifetimes
flood malformed, stale, valid best-effort, and lost-reply retransmissions
coalesce or overwrite Linux work carriers and execute work in another kthread
race wakeup, migration, affinity, hotplug rollback, cancellation, and restart
retain stale pointers and present stale receipts after slot or boot reuse
refuse all Domain-local runnable progress after a valid token is issued
```

No Linux action receives fairness, and no Linux omission may gate guaranteed
release, residency preparation, token stop, or joint `ActivateHeld`. The model is
therefore at least as hostile as a compromised Linux scheduling/control
context for its scoped variables; it does not assume that Linux merely has a
buggy policy.

The scoped trusted computing base is the Domain Monitor transition machine,
its protected state and key use, the hardware enforcement actions named by the
model, and authenticated issuer inputs. The formal model assumes those actions
follow the specification; arbitrary Monitor code execution is a Monitor
escape and outside this component proof. Cryptographic forgery, rollback of
the declared external freshness root, and hardware behavior outside the
declared failure envelope are explicit relies or failures, not conclusions.

An authenticated management principal can be malicious within its delegated
rights. This contract prevents it from manufacturing node capacity, removing
the sealed recovery reserve, rolling epochs backward, or mutating unrelated
lineages, but cannot promise continued service to a Domain that authority is
validly permitted to revoke. Delegation confinement, management compromise,
and break-glass recovery are `MGMT-001`; partitioned lease truth and global
fencing are `CLUSTER-PART-001`.

This model does not yet show that a `ResidentBinding` corresponds to isolated
physical memory, correct entry state, immutable executable code, or contained
mutable kernel state. Those are `ENTRY-001`, `CODE-001`, and `STATE-001`
guarantees consumed through typed receipts. Consequently, passing this model
alone cannot support a hypervisor-equivalent isolation claim.

## Objects That Must Not Collapse

| Object | Identity and purpose | Owner | Never means |
| --- | --- | --- | --- |
| `DomainKey` | global realm, principal, and non-reusable execution instance | issuing root and Domain Monitor | local slot or Linux task |
| `NodeConfig` | boot-bound immutable maxima for every hierarchy, vector, proof, replica, target, and reverse-edge width accepted on this node | protected boot root | a per-request caller-selected bound |
| `DomainHierarchyCertificate` | exact root-to-leaf parent, sponsor, delegation, epoch, fence, and resource-reservation path for one Domain | Domain Monitor validates; management authority supplies within policy | an optional optimization or an unbounded ancestry walk |
| `NodeLeaseImportCertificate` | typed cluster-authority import, clock-conversion envelope, offline horizon, rights ceilings, and immutable partition mode | cluster authority produces; Domain Monitor validates | network reachability, wall-clock guess, or permission to extend locally |
| `GlobalPlacementUse` | globally fenced owner/replica use, quorum epoch, resource set, maximum new-authority horizon, and per-resource residual-effect horizons | cluster authority produces; Domain Monitor consumes | local `PlacementGeneration`, lease-only extension, or proof from network silence |
| `ControlOp` | bounded idempotent mutation transaction and receipt | Domain Monitor | admission before commit |
| `ConflictIntentReservation` | fair logical intent over one exact derived read/write/resource conflict footprint while a selected guaranteed-control operation reaches its finite terminal point | Domain Monitor | a physical lock, write-only footprint, or pause of root service |
| `CommitDeltaTemplate` | bounded certificate parameterized over permitted live-ledger suffixes and final current-state boundary instantiation | Domain Monitor validates; untrusted planner may construct | an exact stale copy of every hot cursor |
| `AdmissionContract` | node-local class, eligible scope, service parameters, and capacity reservation | Domain Monitor | execution now |
| `AdmissionSnapshot` | complete immutable authority-envelope, service, descriptor, and reservation version | Domain Monitor | current lease term or resident-backing identity by itself |
| `FrozenLeaseUse` | exact extension-term attestation, original expiry, and authority envelope selected for one release or accepted best-effort use | Domain Monitor | a mutation of `AdmissionSnapshot` or permission to inherit a later extension |
| `StreamLedger` | mutable recurring cursor, current opportunity, settlement, and debt for one service lineage | Domain Monitor | immutable admission identity or caller queue |
| `PlanMembership` | exact membership of one stream in one independently advancing root-plan shard | Domain Monitor | admission snapshot or global node barrier |
| `PlanTransitionRecord` | atomically sealed intent containing independently applicable future-effective local shard deltas | Domain Monitor | a cross-lane wait barrier or exclusive-placement transfer receipt |
| `ApplyCell` and `EntryFailClosedFence` | one shard-owner-written terminal apply disposition and its local no-successor fence | exact shard apply owner | a failure-scope fence or a second writer's status |
| `EscrowReclaimCell` | capacity-owner receipt that releases one immutable component-wise maximum apply escrow after cleanup | exact capacity owner | capacity returned by local apply itself |
| `BindingAuthorityKey` | exact security/view/placement subset required to reuse protected resident backing | Domain Monitor | current lease term, service budget, or RunToken |
| `SecurityDependencyCertificate` | immutable admission-bounded failure-scope closure and exact topology/ownership incarnation from which one use vector is derived | Domain Monitor | a caller-selected scope list or mutable global topology lookup |
| `SecurityUseVector` | exact bounded set of failure/security scope generations and fence observations required for one release, hold, activation, or token | Domain Monitor | node-wide security-log high-water equality |
| `RetirementFence` | monotonic post-publication release/activation/token cutoff for one snapshot authority-use | Domain Monitor | a mutation of the snapshot or service success |
| `RetiringOpportunityReservation` | exact root-service and terminal-work reservation that keeps an already released old-membership opportunity schedulable after plan cutover | Domain Monitor/ROOTSCHED | permission for the old membership to release again |
| `CommitDependencyVector` | complete conflict-local read/write/dependency closure for one control commit | Domain Monitor | a whole-node mutable snapshot or free witness bit |
| `ClockBridgeAuthorityRecord` | current lineage over one exact hardware-progress proof, conserved service-allocation path, and target-local quota anchor | Monitor/hardware contract | a single mixed clock/fairness assumption |
| `ClockBridgeCertificate` | immutable bundle of those three separately owned proofs plus the checked rank and stop horizon | Monitor/hardware contract | wall-clock evidence or Monitor fairness by itself |
| `HardwareCapacityRootCertificate` | one literal non-overlapping schedule partitioning shared physical contexts among control, Domain execution, management, emergency, and slack | protected hardware-capacity root | two independently conserved virtual frames on one CPU |
| `HardwareProgressCertificate` | immutable trusted upper relation from protected service opportunities to lease ticks | trusted timer/hardware root | a claim that Monitor dispatch is fair |
| `ServiceAllocationCertificate` | immutable parent-conserved protected-service path, schedules, and positive child reservations | Domain Monitor capacity allocator | a nominal rate with no burst/gap schedule |
| `TargetControlReservation` | immutable bounded schedule cells for one active control target below a conserved control shard | Domain Monitor capacity allocator | target-specific external fairness or reuse of another target's microstep |
| `TargetLaneQuotaAnchor` | target-local post-selection lane and `TargetControlTurn` counters plus positive quota | exact opportunity/control lifecycle owner | credit from shard turns or target turns that occurred before the target existed |
| `ControlServiceReservation` | exact physical protected-entry capacity owned along one hierarchy path | Domain Monitor capacity allocator | virtual `ControlTurn` or unowned aggregate bandwidth |
| `TrustedLeaseClock` | Linux-independent lease time whose comparison gates every active lane without admission fanout | Monitor/hardware | a lane clock or Linux time |
| `RootExecutionAllocationCertificate` | exact parent-conserved physical CPU/pool schedule path, shared hardware root, contexts, cell duration/guard, co-tenancy/failure scopes, and current/pending/retiring/management shares for one root lane | Domain Monitor capacity allocator | independent lane rate or authority to spend the same CPU cell twice |
| `RootServicePlan` | immutable certified service schedule/policy epoch | Domain Monitor | resident binding |
| `ResidencyObligation` | one contract release that must receive one activation opportunity | Domain Monitor/ROOTSCHED | reusable request or physical work item |
| `ResidencyRequest` | idempotent transport and cancellation identity for one intent | Domain Monitor for guaranteed work; attributed caller for best effort | authority merely because accepted |
| `PhysicalResidencyTxn` | bounded drain/install/hold work that may satisfy compatible consumers | Domain Monitor | one consumer's authority or budget |
| `ResidencyWorkReservation` | conserved forward/cleanup service and cost reservation | Domain Monitor | CPU RunToken or execution authority |
| `NamespacePublicationReservation` | nonrefundable wear/headroom entitlement for one shared finite namespace root and sponsor | Domain Monitor | reusable work credit or permission to force shared renewal |
| `ResidentBinding` | exact protected cache binding to one projection generation | Domain Monitor | RunToken |
| `ExecutionCellLease` | one immutable allocator-issued future schedule occurrence already debited to one lane through every shared parent, with exact start/end, context, budget ceiling, and authority horizon | protected root execution allocator | mutable consumption state, a carry-forward credit, or a token |
| `ExecutionCellUseCell` | one-way `Unbound/Reserved/Consumed/Expired/Settled` use state for one exact lease and physical occurrence | protected root-execution cell state machine | a second allocator, a reusable credit, or lane-owned authority |
| `ActivationIntent` | exact non-executable join request over obligation, held binding, future execution-cell lease, imported authority, and dependency receipts | ROOTSCHED/residency composition | a RunToken, consumed physical cell, service success, or executable CPU state |
| `ActivationDecisionCell` | one-way decision keyed by one intent/lease pair, retaining the only ActivationID, receipt, token, staging generation, boot epoch, and due-cell end across retry/crash cuts | joint activation state machine | delivered service, a mutable retry request, or authority outside the due cell |
| `ExecutionContextKey` | exact Domain/CPU/projection/view/code/entry/translation/backing/mutable-state/global-placement epoch tuple installed at activation | joint ROOTSCHED/ENTRY/CODE/STATE action | a digest that may omit one dependency class |
| `ActivationCommitReceipt` | hardware-visible proof that one due cell was consumed, the exact context valid gate was published, and bounded budget/stop enforcement was armed | joint activation owner | delivered CPU service by itself |
| `ExecutionDeliveryReceipt` | exact entry, delivered ticks or authenticated post-entry voluntary yield, cell exit, and budget settlement for one activation | protected hardware execution owner | useful application work or an activation receipt alone |
| `ActivationID` and `RunToken` | one cell-bound, budgeted execution authority created bijectively from an intent and consumed cell | joint activation owner and hardware | admission, residency readiness, reusable cell credit, or service alone |
| `SettlementPrefixCertificate` | fault-tolerant exact settled service prefix, debt, last delivery, and open-ordinal disposition used after source loss | cluster settlement authority | proof from a silent or volatile source |
| `ContinuityLossRecord` | explicit new stream-incarnation boundary when safety can be restored but exact old settlement state cannot | cluster recovery authority | exactly-once or maximum-gap continuity |
| `PlacementTransferRecord` | monotonic source-fence/quiescence/destination-publication protocol for exclusive placement | Domain Monitor and architecture receipts | simultaneous cross-shard apply or copied authority |
| `ServiceCalendar` | immutable ordinal-to-trusted-due-time identity shared by source and destination | Monitor service admission | a source or destination lane-turn conversion |
| `CalendarTransferRecord` | total checked exact-ordinal mapping result after source quiescence | exact transfer owner | a nondeterministic destination cursor or new maintenance skip |
| `FailureSourceIdentity` | complete authenticated channel/resource/incarnation/namespace/timebase identity | Monitor/hardware/authenticated source | a digest or caller label |
| `FailureSourceEvidence` | structured direct protected observation or authenticated source-sequenced receipt whose exact source identity and freshness remain replay-detectable after detail GC | Monitor/hardware/authenticated source | a Linux-forwarded event body, digest alone, or caller-selected scope |
| `FailureScopeIdentity` | complete typed owner/incarnation/scoped-root identity for one authority fence domain | protected ownership map | an inner generation without its enclosing root |
| `FailureCoverCertificate` | total canonical union over source, current, and every live-authority-referenced topology generation, then exact closure, unique LCA in a boot-fixed cover tree, or node-fail-stop result | protected ownership map and failure authority | an unordered DAG choice, truncated caller-selected vector, or reject-and-continue result |
| `SourceReplayCell` | source-owned `Unseen/DurablePending/Terminal` replay state, terminal high-water, and source-health fence | protected source shard | authority fence, audit position, or high-water advance before semantic commit |
| `ScopeTransitionTxn` | bounded failure/recovery transaction with canonical scope set, prepared successors, and one semantic commit bit | protected transaction shard | an audit append or multi-object atomic write |
| `ScopeAuthorityCell` | scope-owned current generation/fences plus at most one prepared transition reference | protected failure-scope shard | event detail, source replay state, or node-global affected-contract list |
| `AuthorityAuditOutbox` | immutable audit payload derived from one committed authority transaction | protected transaction shard | a prerequisite for the authority fence to take effect |
| `AuthorityRetireReceipt` | exact no-reference/audit/checkpoint/reconciliation proof preceding transaction-slot reuse | protected transaction shard | a free Boolean or permission to reuse an old generation |
| `SecurityAuditShard` | independently appendable and checkpoint-renewable event-detail hash chain for a bounded audit shard | protected audit root | execution authority or an infinite unprovisioned log |
| `AuditReceipt` | audit-shard-owned durable append/checkpoint acknowledgement for one transaction | protected audit shard | authority settlement or permission to clear a fence |
| `CheckpointAggregate` | asynchronously computed root/vector over audit and transition shard checkpoints | protected reconciliation service | an authority linearization point, synchronous global append barrier, or execution gate |
| `ManagementRecoveryBootstrapContract` | boot-root-installed immutable management context plus independently reserved execution, control, clock, namespace, audit, and failure resources | protected boot root | ordinary delegated authority or an unexplained liveness oracle |
| `NodeMode` | guarded Normal/maintenance/failure/fail-stop state and affected set | Domain Monitor/hardware receipts | arbitrary liveness escape |
| replay/retirement state | bounded high-water marks, tombstones, current/retiring plans and generations | Domain Monitor | unbounded history or Linux recovery source |
| Linux projection | local queue and picker optimization | adversarial Linux | admission, quiescence, cancellation, or authority |

### Node-wide bounds and hierarchy

`NodeConfig` is sealed from the protected boot root before management bootstrap
or ordinary admission. It fixes positive finite maxima for at least:

```text
KDepth, KEligibleContexts, KSecurityScopes, KFailureScopesPerEvent,
KDelegationEdges, KReplicas, KTransitionShards, KControlTargets,
KLiveAuthorityUsesPerScope, KQuiescenceReceipts, KProofBytes,
KVectorBytes, KMutationFootprintEntries, and every local certificate width
```

No admission may replace one of these node maxima with a larger descriptor-
local value. Normalization that exceeds a maximum terminates before authority
publication as `TooWide`; insufficient hierarchy capacity terminates as
`NoParentCapacity`. The accepted memory and validation bounds are therefore
functions of `NodeConfig` and admitted objects, never attacker-provided lengths
or the total identity population of a multi-cluster realm.

Every admitted Domain, including a process-granular Domain nested below a
container or tenant, carries one `DomainHierarchyCertificate`:

```text
exact DomainKey and DomainEpoch
ordered root-to-leaf parent DomainKey/epoch/fence path of length <= KDepth
exact sponsor and delegation edge at each step
exact rights attenuation and resource reservation at each step
exact hierarchy topology incarnation and certificate generation
```

For each ancestor `a` and resource dimension `r`, the capacity owner preserves:

```text
Current[a,r] + Pending[a,r] + Retiring[a,r] + FailureEscrow[a,r]
  <= AncestorReservation[a,r]
```

All terms name disjoint ownership partitions. A leaf may consume only the
intersection of rights and capacity along its exact path. Every release,
activation intent, execution context, token, failure use, and cleanup use binds
the complete ancestor fence vector. Reparenting first fences the old path,
stops or settles every old-path use, and publishes typed zero-reference
receipts before a new path can become executable; it cannot relabel a live use.
A depth-one flat hierarchy is the valid v1 specialization. Hierarchical servers
and process-scale delegation are therefore semantic instances of one contract,
not optional prose or a selected scheduling data structure.

`DomainKey` is `(GlobalRealmID, PrincipalID, InstanceID)`, and `InstanceID` is
never reused for another logical execution instance. Every imported identity
also binds the exact `ClusterIssuerIncarnation`. `DomainEpoch` is the
issuer-controlled authority/revocation version of that same instance; it can
invalidate old authority without allowing `InstanceID` reuse. A node Monitor
may advance it only when the global issuer explicitly delegated that right.
Ordinary node-local rejection advances `LocalAuthorityGeneration` and fences
old uses instead.

Two distinct `ResidencyObligation` releases must not be discharged by one
activation. They may reuse an already-current resident binding, and compatible
physical preparation work may be shared, but every release retains its own
sequence, deadline/debt, activation receipt, and terminal outcome.

## Identity and Version Algebra

The following namespaces have different revocation and reuse meanings:

```text
DomainKey / DomainEpoch
  never-reused instance identity and issuer-controlled authority version

ClusterIssuerIncarnation
  authenticated non-rollback issuer/signing incarnation enclosing every
  DomainEpoch, NodeLeaseID, NodeLeaseEpoch, and issuer attestation accepted by
  this node

LocalAuthorityGeneration / LocalLeaseFenceGeneration
  Monitor-owned non-rollback local rejection versions; they may narrow or stop
  imported authority but can neither advance DomainEpoch/NodeLeaseEpoch nor
  manufacture an issuer successor

NodeLeaseID / NodeLeaseEpoch / LeaseTermGeneration / LeaseAttestationID
  stable node-delegation lineage, issuer-controlled authority-envelope epoch,
  monotonic extension-only validity-term version, and exact boot/reconciled/
  security-checkpoint-bound authenticated lease statement

FrozenLeaseUse
  derived, non-allocating identity for the exact lease attestation selected at
  one release or accepted best-effort use; it retains that term's original
  LeaseClockEpoch and half-open expiry until every referencing opportunity,
  hold, and token settles

AdmissionID / AdmissionGeneration
  node admission-record identity and atomic record version

AdmissionIncarnation
  enclosing namespace for admission-generation renewal

ServiceStreamID / ServiceStreamIncarnation / ServiceContractGeneration
  stable recurring-service lineage, renewal incarnation, and parameter version

DescriptorIncarnation / ResidencyDescriptorGeneration
  renewal namespace and version for MemoryView, eligible scope, exclusivity,
  and binding-relevant descriptor

PlanShardID / RootPlanEpoch / PlanMembershipGeneration / OpportunitySequence
  independent immutable service-plan shard, exact stream membership, and one
  recurring guaranteed opportunity

PlanNamespaceEpoch / RequestNamespaceEpoch / ControlNamespaceEpoch
CancelNamespaceEpoch / WorkNamespaceEpoch
  enclosing namespaces for finite plan and operation sequence renewal

ControlOpID / CancelOpID / ResidencyRequestID / WorkID
  control mutation, cancellation, logical request, and physical work identities

ControlOpSequence / CancelOpSequence / ResidencyRequestSequence / WorkSequence
  explicit finite inner counters enclosed by their matching namespace epochs

FailureEventSequence
  replay-fenced event counter inside one failure namespace/resource scope

ScopeTransitionNamespaceEpoch / ScopeTransitionSequence /
ScopeTransitionGeneration
  non-aliasing namespace, transaction identity counter, and recyclable slot
  generation shared by the failure/recovery prepare-commit protocol

SourceReplayGeneration / SourceHealthGeneration
  source-cell structural generation and monotonic source-availability fence

AuditReceiptGeneration / CheckpointAggregateGeneration
  independently renewed audit acknowledgement and asynchronous aggregate
  observation identities; neither is execution authority

FailureScopeGeneration
  Monitor-owned local generation for the exact authoritative resource/contract
  closure changed by a failure or recovery; unrelated scopes do not advance it

ServiceOpportunityClockEpoch / ServiceOpportunityTurn,
LaneClockEpoch / LaneTurn, ControlClockEpoch / ControlTurn,
LeaseClockEpoch / LeaseTick
  independently owned non-wrapping physical protected-entry opportunity,
  logical lane service, control dispatch, and trusted lease-time counters with
  explicit outer incarnations

NodeConfigGeneration / DomainHierarchyGeneration
  protected boot configuration and exact compiled ancestor path incarnation

RootExecutionClockEpoch / RootExecutionTurn /
RootExecutionAllocationGeneration
  physical execution-pool opportunity lineage and exact parent-debited lane
  allocation; lane turns cannot substitute for these counters

TargetControlTurn / TargetControlReservationGeneration
  exact target-owned microstep count and immutable target schedule reservation

NodeLeaseImportGeneration / GlobalPlacementOwnershipEpoch /
GlobalPlacementFencingToken / QuorumEpoch
  typed cluster import and globally fenced placement lineage

FailureCoverGeneration
  exact ownership-graph incarnation and total failure-cover derivation

ActivationIntentGeneration / ExecutionContextGeneration /
ActivationCommitGeneration
  non-executable intent, installed context, and exact joint activation receipt

ManagementBootstrapGeneration
  protected boot-root management/recovery contract incarnation

DirectoryLayoutEpoch
  pinned to the MonitorBootEpoch in the v1 reference

ProjectionEpoch / CpuIncarnation / SlotGeneration / ActivationNamespaceEpoch
  local projection, activation, and safe slot reuse namespaces

PlacementIncarnation / PlacementGeneration
  exclusive-placement transfer namespace

MonitorBootEpoch
  invalidates every volatile node-local token, receipt, request, and binding

NodeSecurityEpoch
  non-rollback authenticated reconciliation checkpoint over transition-shard,
  scope-cell, source-replay, and audit-shard roots that survives Monitor
  restart; advancing it is observation, not execution authority or a universal
  fence

SecurityScopeFence
  Monitor-owned typed enforcement fence over an authoritative resource/Domain/
  node ownership closure; its exact scope and disposition determine which
  releases, activations, tokens, or recoveries are blocked

SecurityUseVector
  bounded canonical vector of every relevant full FailureScopeIdentity,
  generation, and fence observation for one use; a token remains executable
  only while the enclosing namespace/resource incarnation and inner state all
  exactly match current protected scope state

FailureScopeIdentity
  (MonitorBootEpoch, canonical owner/root identity, FailureNamespaceEpoch,
  source/resource identity and incarnation, FailureScopeID); inner generation
  equality without this complete identity is never freshness

SecurityDependencyCertificate
  immutable tuple of the admitted resource/topology/ownership incarnations and
  sorted FailureScopeID closure; every SecurityUseVector key set equals this
  certificate exactly, and a closure-changing transition fences old uses before
  the changed resource graph becomes usable

ReconciledEpoch / DirtyArmGeneration
  issuer-acknowledged reconciliation state and separate persistent running-boot
  dirty marker generation

ActivationGeneration
  one exact root execution opportunity

RetirementFenceGeneration
  monotonic narrowing record for one immutable snapshot authority-use
```

No field substitutes for another. In particular:

```text
class change does not rename the Domain
slot replacement does not change DomainEpoch
plan update does not reset service debt
transport retransmission reuses the same RequestID and exact digest
a new logical attempt after terminal settlement uses a fresh RequestID
ProjectionEpoch renewal does not revive an old binding
Monitor restart does not recover authority from Linux shadow state
Monitor local revoke does not mint an issuer DomainEpoch or NodeLeaseEpoch
LeaseTick is never compared across LeaseClockEpoch
```

The effective execution-authority freshness tuple is
`(ClusterIssuerIncarnation, DomainEpoch, NodeLeaseEpoch,
LocalAuthorityGeneration, LocalLeaseFenceGeneration, relevant scoped fences)`.
The first three components are issuer-owned; the latter components are
Monitor-owned narrowing state. Earlier finite reference models used one
Monitor-owned abstract epoch. Their refinement maps that abstract value to this
complete effective tuple, not directly to issuer-owned `DomainEpoch`.

`NodeLeaseEpoch` changes when the delegated rights envelope is revoked or
semantically replaced, and is interpreted only under its exact non-rollback
`ClusterIssuerIncarnation`. `LeaseTermGeneration` is extension-only in v1: the
rights digest is identical and trusted expiry is nondecreasing. A term renewal
cannot shorten validity, attenuate or add rights, clear a local rejection
fence, or advance the authority epoch. An issuer-requested shortening,
attenuation, or revoke supplies a new issuer-owned `NodeLeaseEpoch`; the
Monitor first publishes an `IssuerLeaseFence`, blocks releases/activations, and
stops old-epoch tokens before the replacement envelope can become current. A
node-local emergency rejection instead advances the exact
`LocalLeaseFenceGeneration`, publishes `LocalRejectFence` or
`SecurityScopeFence`, using the protected scope prepare/commit protocol before
attempting the asynchronous audit append. It never forges the issuer-owned lease
epoch. A rights expansion also requires ordinary admission revalidation and an
issuer-owned new envelope.

The mutable current extension term lives only in the shared
`LeaseAuthorityRecord`, not in `AdmissionSnapshot` or `PlanMembership`. At a
guaranteed release or accepted best-effort use, the Monitor atomically selects
the latest valid term and creates a derived `FrozenLeaseUse` containing the
exact ClusterIssuerIncarnation, NodeLeaseID/epoch/term/attestation, rights
digest, LocalAuthorityGeneration/LocalLeaseFenceGeneration,
MonitorBootEpoch/reconciliation/dirty tuple, LeaseClockEpoch, issued tick, and
original expiry. Pure extension is therefore one conflict-local record update and does
not republish every admission, stream, or plan membership. Referenced old terms
remain retained until their frozen uses settle. A frozen use never inherits a
later expiry; all later releases select the new current term. An authority-
envelope change still requires ordinary admission revalidation and new
authority-use publication. Protected resident backing may survive either kind
of service-only change only when its complete `BindingAuthorityKey` remains
equal.

An unrelated `NodeSecurityEpoch` audit high-water advance does not invalidate
another scope's admission, dirty receipt, or frozen lease use. Relevant scope
state is enforced through the exact `SecurityUseVector` and typed fences.

### Typed lease import and partition modes

`NodeLeaseImportCertificate` is the only cluster-authority input accepted by
admission. Its canonical fields are:

```text
GlobalRealmID, ClusterIssuerIncarnation, issuer/quorum identity and no-fork epoch
exact delegation chain, NodeLeaseID, NodeLeaseEpoch, rights digest and resource ceilings
node identity, MonitorBootEpoch, ReconciledEpoch, and DirtyArmReceipt identity
issuer validity interval and exact LeaseClockEpoch conversion interval
bounded drift/uncertainty, conservative local release/activation/stop deadlines
MaxOfflineDuration and one immutable PartitionMode
policy, signature, encoding, and anti-rollback identities
```

Clock conversion produces an interval, never a guessed point. New authority
uses stop at the earliest locally possible issuer expiry; a superseding remote
owner waits beyond every latest possible predecessor residual-effect horizon
plus its certified uncertainty and stop/quiescence bound. Arithmetic is
checked, monotonic, epoch-local, and
fail-closed. Disconnection can remove evidence but cannot select a different
mode, extend a term, increase rights, reset an offline timer, or create a later
local deadline.

The exact partition modes are:

```text
CONNECTED_ONLY
  release and joint activation require current authenticated connectivity
  evidence; loss blocks both and starts protected stop of existing authority
  within the sealed stop deadline

CONTINUE_TO_CONSERVATIVE_EXPIRY
  already imported rights may release and activate only before the minimum of
  the conservative issuer-expiry deadline, last-connected plus
  MaxOfflineDuration, and every narrower local/security horizon; disconnect
  never renews or lengthens any term

RECOVERY_ONLY
  ordinary release and activation are disabled from certificate installation;
  connectivity cannot reopen them, and only actions admitted by
  ManagementRecoveryBootstrapContract may run
```

At any mode's deadline the Monitor blocks release and joint activation and
arms or executes protected stop independently of Linux. Reconnection imports a
fresh authenticated certificate and never reopens a predecessor frozen use.
`CLUSTER-PART-001` must refine production of these objects and their no-fork
truth; RESIDENCY proves only conservative consumption.

For exclusive or bounded-replica placement, every snapshot additionally binds:

```text
GlobalPlacementUse =
  (GlobalRealmID, DomainKey, DomainEpoch, OwnershipEpoch, FencingToken,
   OwnerNodeID, OwnerNodeIncarnation, ReplicaMode, MaxNodes, exact ResourceSet,
   QuorumEpoch, issuer validity horizon, maximum new-authority horizon,
   maximum residual-effect horizon per resource, and exact effect classes that
   cannot use time-based supersession)
```

The exact `GlobalPlacementUse` is part of `AdmissionSnapshot`,
`BindingAuthorityKey`, `SecurityDependencyCertificate`, `ActivationIntent`,
`ExecutionContextKey`, `RunToken`, and `ExecutionDeliveryReceipt`. Every new
release, intent, activation, and token stops at the minimum placement, lease,
security, retirement, cell, and root-budget horizon. A lease-only extension
cannot extend placement authority; a fresh globally fenced placement use is
required first. Destination activation requires either
an exact source quiescence receipt or a superseding quorum fence whose
`activationNotBefore` is strictly after the source's maximum possible
residual-effect horizon for every resource, including conversion uncertainty
and the protected stop/quiescence bound. A resource with unbounded or
irreversible residual effects cannot use time alone and requires exact source
quiescence. Quorum supersession also supplies an exact replicated
`SettlementPrefixCertificate`; otherwise it advances the stream incarnation
under `ContinuityLossRecord` and makes no exactly-once or maximum-gap claim.
Network silence is never quiescence. Reconnection cannot reopen an old
ownership epoch or fencing token. Local `PlacementGeneration` still orders
node-local binding changes but cannot substitute for global fencing.

The scope **membership** of that vector is not recomputed from mutable topology
on the execution path. Admission seals a `SecurityDependencyCertificate` whose
bounded ordered scope set and exact resource/ownership incarnations are part of
the immutable snapshot. Release copies current generations and fence
observations for exactly those keys. A Monitor topology, placement, queue, or
ownership transition that changes the closure must publish monotonic
retirement/security fences for every old authority-use and update its protected
reverse dependency membership before the new graph can become usable. An
unexpected physical change first fences a covering old scope. Thus neither a
newly added dependency nor deletion/reparenting of an old one can make a live
token silently consult a different scope set.

Semantic separation does not require one machine word per name. An
implementation may pack fields, seal a canonical digest, or use one enclosing
incarnation for several scopes only after a refinement proves that every
consumer observes the same non-aliasing and renewal rules. Storage
deduplication cannot collapse revocation meanings or make a local churn event
invalidate an unrelated global identity.

`rekey` is retained only as an explanatory alias. The normative residency term
is **ProjectionEpoch renewal**. It describes a quiescent namespace replacement,
not necessarily a cryptographic key rotation.

## Authority Ownership

The Domain Monitor owns every fact required for safety or cross-Domain
availability:

```text
admission lifecycle, class, generation, and capacity journal
NodeLease authority envelope, extension-only term, TrustedLeaseClock,
FrozenLeaseUse retention, RetirementFence, and local rejection fence
current, committed-pending, and retiring per-shard plan epochs
immutable PlanTransitionRecord, bounded apply ledger, per-shard plan membership,
and independent lane clocks
StreamLedger cursor, CurrentOpportunity, last terminal settlement, next
release, and service debt
operation and request high-water marks
cancel authority, coalescing membership, and terminal outcomes
reserved management, guaranteed, cleanup, and renewal work lanes
resident transaction state and exact hold owner
slot binding, reverse replica index, and all local generations
trusted active, entry, drain, cleanup, and backing-quiescence references
CPU authoritative online/accepting state
ProjectionEpoch, CpuIncarnation, and MonitorBootEpoch
replay-fenced source evidence, SourceReplayCells, ScopeTransitionTxns,
ScopeAuthorityCells, guarded causes, FailureScopeGeneration,
SecurityDependencyCertificate and SecurityUseVector state, derived
NodeModeSummary, independently owned audit outboxes/shards/receipts,
NodeSecurityEpoch checkpoint high-water, and exact typed SecurityScopeFences
```

Linux may provide only:

```text
runnable, idle, NUMA, LLC, cache-hotness, and utilization hints
best-effort residency and eviction proposals
within-Domain task fairness and scheduling state
non-authoritative transport and local projection state
Linux object lifetime and RCU information for compatibility
```

Caller identity for a Monitor entry is derived from the active Monitor token
or an authenticated management channel, never from a caller-supplied
`DomainID`. Linux cannot create or cancel a guaranteed obligation, upgrade a
class, reset debt, select a generation, report trusted quiescence, or recover
authority after restart.

## Control Operation Protocol

Every join, update, demotion, leave, planned hotplug, or plan replacement uses
a bounded `ControlOp`:

```text
ControlOpID
  (MonitorBootEpoch, exact authenticated Channel/DelegationScopeID,
   full control ScopedNamespaceRoot identity, ControlNamespaceEpoch,
   ControlOpSequence)

immutable fields
  canonical operation digest, target AdmissionID/lineage, requested change,
  charge subject, and exact DelegationScope/authorization receipt

lifecycle
  Submitted -> Preparing -> Reserved -> CommitSealPending
    -> CommitReady -> Committed
        |           |          |          |
        +-----------+----------+----------+-> Rejected
        +-----------+----------+----------+-> CancelPending -> Cancelled
```

The same `ControlOpID` and digest is an idempotent lost-reply retransmission.
The same ID with a different digest is equivocation and cannot mutate state.
Committed, rejected, and cancelled receipts are queryable until a bounded
high-water mark/tombstone protocol makes older IDs return `Stale`.

`DelegationScope` names the issuer/epoch, authorized target lineage set,
allowed operations and fields, maximum resource delta, and an exact
`(LeaseClockEpoch, notBeforeLeaseTick, commitNotAfterLeaseTick,
effectNotAfterLeaseTick)` interval. It states whether delayed effect is
authorized. Every local effective boundary has a numeric clock-bridge proof
that its worst-case apply/stop horizon is strictly within
`effectNotAfterLeaseTick`; otherwise commit is forbidden. Expiry after commit
therefore cannot leave an irrevocable transition authorized beyond its sealed
horizon. Emergency issuer revocation still uses the monotonic pre-effect
fence/stop path. The scope also states whether a named plan-shard
representation path may be rebuilt. The operation
also freezes a `MutationFootprint` containing exact authority lineages, plan
shards/lanes, capacity reservations, CPU/projection resources, namespace
roots, and ordered cross-shard locks it may write. The separate dependency
vector contains its complete read closure. A candidate delta
from an untrusted builder is never authority merely because it is feasible.
Commit computes `CandidateDeltaConfinedToDelegation(current, delta, scope)`:

```text
changed authority/service lineages are a subset of the delegated target set
every changed field and resource delta is authorized by the exact receipt
for every unaffected lineage, service envelope, next release, open
opportunity/rank, debt, retirement fence, and reserved capacity are equal
under the canonical semantic projection
management/recovery reservation and global anti-rollback state are unchanged
the write set is a subset of both DelegationScope and MutationFootprint
```

The candidate may rebuild only named persistent plan paths when its certificate
proves semantic equality for untouched membership nodes. Removing Domain B to
make a Domain-A request feasible is therefore an authorization failure, not a
valid capacity optimization. An emergency multi-lineage operation requires an
explicit scope granting exactly that power.

`CommitDependencyVector` is the total canonical read closure for that
footprint. Every entry has one Monitor-defined validation relation, never a
caller-selected comparator:

```text
ExactGuard
  issuer/delegation/identity/fence/topology/capacity-owner state must be equal

MonotoneSuffix
  token/reference countdown, CurrentOpportunity phase, and retiring burden may
  advance only to a certified suffix whose remaining cost does not exceed the
  template's reserved upper envelope

RecomputeAtCommit
  lease margin, exact cursor/debt, and sufficiently future local boundaries are
  sampled and checked inside final commit
```

Every canonical dependency path is assigned exactly one relation and an exact
successor predicate. The minimum table is:

| Path class | Relation | Accepted successor | Intent treatment |
| --- | --- | --- | --- |
| issuer/delegation identity, rights, epochs, and fences | `ExactGuard` | exact equality | every possible writer conflicts |
| boot, reconciliation, dirty-arm, security dependency, topology, and ownership identity | `ExactGuard` | exact equality | every possible writer conflicts |
| plan predecessor, membership, transition, namespace root, and capacity owner | `ExactGuard` | exact equality | every possible writer conflicts |
| stream cursor, debt, current opportunity, active/held/retiring burden | `MonotoneSuffix` | same lineage and identities, with remaining burden no larger than the sealed envelope | a writer conflicts unless its transition is proved to satisfy this predicate |
| current lease tick/margin, current cursor value, and future local boundary | `RecomputeAtCommit` | the final numeric equation remains inside the sealed reservation/horizon | natural clock/service progress does not conflict; another operation conflicts through any capacity/resource it may consume |
| clock epochs, certificate lineage, and non-weakenable envelope | `ExactGuard` | exact epochs and a retained certificate satisfying the admitted envelope | certificate replacement/rebase conflicts; ordinary checked counter advance does not |

The derived `ConflictFootprint` is the union of the mutation/write set, exact
resource-reservation set, every `ExactGuard` read, and every `MonotoneSuffix`
read for which a proposed writer lacks the certified accepted-successor
predicate. Two operations conflict symmetrically when either write/resource
set intersects the other's derived conflict footprint. A
`RecomputeAtCommit` value is not a free starvation hole: competing capacity is
already reserved through the resource footprint, while trusted clock and
ordinary service suffix actions are not control operations and remain enabled.
No caller may relabel a dependency to shrink this set.

It contains every version and value read by `Feasible`,
`LeaseValidForNewRelease`, `CandidateDeltaConfinedToDelegation`, clock-horizon
evaluation, and failure/recovery guards, including:

```text
delegation generation, revocation fence, rights and effective interval
MonitorBootEpoch, ReconciledEpoch/reconciled-through-security checkpoint, and
DirtyArmReceipt
only the authoritative SecurityDependencyCertificate,
SecurityScopeFence/failure projection, and ownership/topology incarnations
intersecting the mutation footprint; unrelated NodeSecurityEpoch audit
high-water is receipt metadata outside the commit guard
current lease envelope/term/fences plus live leaseTick margin evaluation
affected AdmissionSnapshot, StreamLedger, PlanMembership, RetirementFence,
and plan-shard versions
exact held/active/retiring artifact identities plus their certified
MonotoneSuffix upper envelopes in the footprint
owned capacity reservations and hierarchical parent residual certificates
affected topology, CPU/projection, NodeMode event-set, and failure-scope state
namespace roots/headroom and transition-work reservations
```

This is a full typed tuple or injective symbolic structure in formal models,
never a free digest-valid bit. Commit atomically recomputes all derived
predicates under each field's fixed relation. A changing `leaseTick` does not
cause a false version conflict; the current numeric residual margin is
reevaluated. Ordinary release, settlement, token consumption, or trusted drain
inside the target lineage also does not stale a template when it is a certified
`MonotoneSuffix`. A
relevant security-scope fence, reconciliation change, or conflict inside the
footprint rejects. An unrelated `NodeSecurityEpoch` high-water advance or other
change outside the declared read/write/resource closure commutes and cannot
make the operation stale.

The v1 Monitor accepts a control operation only when its bounded record and
control-service reservation are available. Excess valid submissions return
`RejectedControlBusy`; they are not accepted into an unbounded deferred queue.
Once accepted, an operation reaches one terminal result under the external
stable-input and trusted-service assumptions. If its own dependency footprint
remains stable and its delta is feasible, `NonConflictingControlProgress`
requires `Committed`, not repeated stale rejection. Invalid, infeasible, or
genuinely conflicting operations terminate as typed rejection without changing
current authority.

Candidate input is immutable after acceptance. It is a bounded
`CommitDeltaTemplate`, not an exact copy of hot `StreamLedger` cursor state.
The template proves its deltas for every permitted live-ledger suffix inside a
finite envelope. At final `CommitControlOp`, a bounded Monitor-owned
instantiator atomically samples exact cursor, debt, open opportunity and
remaining rank, selects each effective boundary from current lane turn plus
minimum lead, checks the typed dependency relations, and seals those concrete
values into the immutable transition. Normal recurrence can therefore continue
during preparation without requiring a nonexistent quiet instant.

The reference operation gets a bounded number of preparation steps and exactly
one conflict-local commit revalidation. An `ExactGuard` mismatch,
non-monotone suffix, or current numeric infeasibility reaches terminal
`RejectedStaleSnapshot`; the operation does not rebuild under the same ID. A
caller may submit a fresh ID after that receipt. Unrelated state and certified
monotone service progress do not cause this result.

A guaranteed-control ticket selected by the fair cursor first obtains a
bounded `ConflictIntentReservation` over its exact derived full conflict
footprint. This is a logical
ordering record, not a lock: root service, trusted countdown, and monotone
settlement continue, and no lock is held across a lane or hardware wait. Later
symmetrically conflicting control commits cannot overtake the selected ticket
before its finite commit/reject/cleanup rank ends; operations whose complete
conflict footprints are disjoint commute. Invalid,
revoked, or infeasible selected work still terminates in bounded time and
releases the intent. Authorized peer churn can therefore cause a justified
conflict before intent selection, but cannot force one fairly selected stable
feasible principal to lose every commit race.

A successful revalidation atomically publishes an immutable
`PlanTransitionRecord` keyed by the `ControlOpID`. It binds an exact affected
shard set with `0 < size <= MaxTransitionShards`, each predecessor and
successor plan/membership digest, reserved
capacity, and one future effective `laneTurn` per shard. Every local delta must
be independently applicable at its recorded boundary from state already sealed
at control commit; a boundary entry may not contain a wait predicate on another
lane. Tentative shard entries are not authority; readers ignore them until one
Monitor-owned commit seal makes the complete exact record visible. This
publication is the `Committed` linearization point and may touch only the
bounded declared shard set. It does not wait for a lane, token, hardware drain,
or Linux action while holding locks.

Each affected shard later applies its already committed local delta at the
recorded boundary. Application cannot become a stale-candidate rejection and
cannot roll back the commit; it either performs the reserved deterministic
cutover or enters exactly one terminal `FailedFenced` disposition already named
by the record. One exact `ShardApplyOwner` owns each entry and is the only
writer of its `ApplyCell`. `Applied` publishes the successor, retirement fences, any exact
retiring-opportunity reservation, and capacity transfers. `FailedFenced`
publishes no successor execution authority, atomically publishes the owner-
local `EntryFailClosedFence`, assigns every same-boundary due/open obligation its predeclared
non-service outcome, retains old/new capacity until cleanup, and records either
an objective external failure or a software-invariant fail-stop. It never waits
for a source lane, another apply ledger, or a future
receipt while holding its boundary. A bounded Monitor-owned apply ledger
records `Pending`, `Applied`, or `FailedFenced` for every entry without changing
the immutable transition. A failure-scope owner publishes only its typed
`SecurityScopeFence`; `ShardApplyOwner` may reference but never advance it, and
alone atomically settles `Pending -> FailedFenced` with its local fail-closed
fence. Every entry reaches a terminal status under its
declared lane/failure relies; the transition settles only after all entries are
terminal and all retiring/failure cleanup artifacts settle. At most one
committed-pending ordinary transition may
name a shard in v1. Disjoint shard transactions publish and apply
independently; intersecting transactions are ordered by predecessor identity
and canonical lock order.

Because local applies occur in different orders, commit accepts a multi-shard
record only under this structural compositional grammar:

```text
LocalDeltaCertificate[i]
  exact ShardApplyOwner and predecessor/successor identity
  OwnerLocalWriteSet[i] contained in that shard's disjoint namespace partition
  typed ExactGuard, MonotoneSuffix, Recompute, and TrustedProgress reads
  component Demand[i, Pending|Applied|FailedFenced, ancestor, resource]
  immutable component Escrow[i, ancestor, resource] equal to their maximum
  local authorization monotonicity and one total Applied/FailedFenced step

AggregateContributionCertificate
  sorted sparse fold of every local escrow along its exact ancestor path
  plus unaffected baseline and reserved slack
  literal equality/inequality checks for every touched capacity root
  no caller-supplied pairwise commutation assertions
```

`OwnerLocalWriteSet` partitions are validated by owner/range membership, not by
comparing every pair. Shared ancestors are never directly written by local
deltas. For every exact ancestor/resource component:

```text
Escrow[i,n,r] = max(Demand[i,Pending,n,r],
                    Demand[i,Applied,n,r],
                    Demand[i,FailedFenced,n,r])

Capacity[n,r] = Baseline[n,r] + Slack[n,r] + SUM i: Escrow[i,n,r]

Residual[i,status,n,r] = Escrow[i,n,r] - Demand[i,status,n,r]
```

All arithmetic is checked and component-wise. Escrow remains owned until exact
cleanup and a capacity-owner `EscrowReclaimCell` settle; apply never mints or
returns it. The current aggregate is the commutative fold of demand plus owned
residual. `ExactGuard`
reads are frozen at commit; `MonotoneSuffix` reads may only narrow authority or
advance certified service; `Recompute` values are derived from those owned
inputs; trusted progress has no delta writer. Any noncommuting read or resource
effect must be moved into the entry's owned partition or encoded as a monotonic
release-receipt-then-acquire protocol.

The all-pending state is the induction base. One owner-local terminal step
preserves its local invariant, changes only demand/residual inside its escrow, and the
aggregate fold re-establishes every shared conservation equation; therefore
every reachable mixture of `Pending`, `Applied`, and `FailedFenced` is safe.
Validation and retained proof size are `O(k * Dmax + P)` for `k` affected shards,
bounded hierarchy depth `Dmax`, and bounded local proof size `P`, with no
`O(k^2)` pairwise certificate. A free Boolean, unchecked all-subsets assertion,
or nominal rate sum is forbidden. Thus atomic intent publication is never
mistaken for atomic effective state.

An operation with a cross-shard safety dependency is not encoded as one such
waiting local apply. In particular, exclusive placement uses a monotonic
`PlacementTransferRecord`: destination capacity is reserved, source release and
activation authority is fenced at a source-local boundary, protected stop and
drain produce an exact `SourcePlacementQuiescenceReceipt`, and only then may a
fresh destination-local transition be committed for a future destination
boundary. The gap is allowed; overlap is forbidden. A source failure leaves
the transfer stopped or failed and cannot hold the destination lane clock.
This compound operation has bounded phase/rank and one final terminal receipt,
but intentionally has more than one authority-publication point rather than
pretending that independent lane clocks share an atomic effective instant.

The v1 acceptance path receives a complete bounded delta certificate whose
storage and validation work are bounded by affected lineages plus certified
plan/capacity hierarchy depth, not total node population or the number of
control principals. An untrusted planner may compute it before submission but is not part of accepted
operation progress. An implementation that asks an untrusted service Domain to
build after acceptance must reserve the request state and enforce a
Monitor-owned bounded watchdog. Missing, malformed, or late output terminates
as `RejectedBuilderTimeout` or `RejectedInvalid`; planner fairness is never an
external rely and old current authority continues.

Control abort is typed separately from residency-request cancellation. An
authenticated issuer may submit `AbortControl(ControlOpID, exact digest)`; its
idempotent response is `AbortAccepted`, `TooLateCommitted`,
`AlreadyTerminal`, `Unauthorized`, `Stale`, or `Equivocation`. If abort
linearizes before the admission/plan publication point, no candidate authority
is published and the operation reaches `CancelPending -> Cancelled` only after
its reservations and partial preparation effects settle. If commit linearizes
first, abort is `TooLateCommitted` and cannot roll back the committed schedule
or any already-applied shard plan. A lost abort reply is recovered from the
same bounded control receipt; it does not allocate a residency `CancelOpID` or
a second control operation.

For a guaranteed admission, commit atomically creates the service lineage,
absolute first `nextReleaseTurn`, committed-pending plan membership,
transition record, reserved first-release schedule, and admission receipt. It
does not materialize `CurrentOpportunity` before the recorded future due
boundary. For every new membership applied after source turn `t`, the sealed
inequality is `initialFirstReleaseTurn >= t + 1`; its stronger preparation-lead
bound is also checked. Equality at or before `t` is rejected because `Due_t`
belongs to the predecessor plan. A lost reply cannot create a second admission
or first release.

## Admission Lifecycle and Linearization

The reference lifecycle is:

```text
Absent or Tombstoned
  -> Preparing
  -> CommittedPendingEffective
  -> CurrentRecord
  -> Updating with old current authority-use still authoritative
  -> CommittedUpdatePendingEffective with old use still authoritative
  -> CurrentRecord under an applied new generation/use
  -> Retiring, LeaseExpiredQuiescing, or RevokedQuiescing
  -> Tombstoned
```

This is administrative record lifecycle, not an ambient authority bit.
`AdmissionUsable(snapshot, use)` is a derived predicate requiring a current
record/use, valid lease mode, current fences, an armed dirty-state relation,
and all exact enclosing generations. Lease expiry therefore makes execution
authority false without first scanning or rewriting every admission record;
the record may enter `LeaseExpiredQuiescing` lazily for bounded cleanup.
`Preparing`, `Updating`, tentative shard entries, and committed-pending
membership are never execution authority. A committed-pending record is an
irrevocable future contract schedule, not a currently usable authority-use.

New guaranteed admission uses this transaction:

```text
1. authenticate and normalize the global descriptor or node lease
2. reserve a bounded directory/control-operation record
3. construct and validate a feasibility witness from current live state
4. reserve root service, residency work, request storage, eligible execution,
   recovery, and namespace-renewal capacity
5. prepare a conflict-local immutable plan delta and transition witness
6. atomically publish one complete AdmissionSnapshot, StreamLedger,
   committed-pending PlanMembership, PlanTransitionRecord, reservations, and
   future first-release schedule
7. return a sealed node-local admission receipt naming the snapshot,
   transition, exact effective boundary vector, and first release
8. at each recorded lane boundary, apply the committed membership before any
   new-plan release can become usable
```

A best-effort-only process admission publishes no guaranteed `StreamLedger` or
`PlanMembership` and does not replace a root plan. Promotion to guaranteed is
a later capacity-certified transaction. Step 6 is conflict-local: it writes
only the exact admission, stream, plan-shard, capacity-reservation, and
namespace objects named by its mutation footprint.

Step 6 is the only admission-contract linearization point. Before it, no
guarantee is visible. After it, the future schedule is irrevocable and every
promised resource is already reserved, but `AdmissionUsable` remains false
until the exact membership application boundary. Failure, cancel, invalid
input, capacity exhaustion, or witness rejection before commit restores
`Absent` for a new admission or preserves the old current contract for an
update.

The immutable `AdmissionSnapshot` contains:

```text
MonitorBootEpoch, ClusterIssuerIncarnation, ReconciledEpoch,
reconciled-through NodeSecurityEpoch
checkpoint, and exact DirtyArmReceipt identity
NodeConfig identity and exact DomainHierarchyCertificate with ancestor fences
exact NodeLeaseImportCertificate, conservative local horizons, and immutable
PartitionMode
DomainKey, DomainEpoch, and LocalAuthorityGeneration
issuer/channel epoch; NodeLeaseID and NodeLeaseEpoch; stable authority-envelope
and rights digest; LocalLeaseFenceGeneration; exact shared LeaseAuthorityRecord
identity, but no mutable
LeaseTermGeneration, LeaseAttestationID, or expiry
AdmissionID, AdmissionIncarnation, and AdmissionGeneration
DescriptorIncarnation, ResidencyDescriptorGeneration, canonical descriptor
digest, MemoryViewID/ViewEpoch, and BackingOwnershipEpoch
PlacementIncarnation, PlacementGeneration, eligible contexts,
placement/exclusivity, and co-tenancy constraints
exact GlobalPlacementUse for exclusive or replicated placement
exact RootExecutionAllocationCertificate and reserved parent execution cells
exact immutable SecurityDependencyCertificate with full FailureScopeIdentity
set and ownership/topology incarnation tuple
ServiceStreamID, ServiceStreamIncarnation, and ServiceContractGeneration
when guaranteed; class/charge subject and exact lineage-local reservation IDs
initialFirstReleaseTurn, period, deadline, ActivationTurnBound, and
TerminalTurnBound and required bridge-envelope limits, but no live cursor or
current ClockBridgeCertificate
```

The following mutable or plan-relative state is deliberately **not** part of
the snapshot:

```text
StreamLedger
  current snapshot identity, nextOpportunityOrdinal, CurrentOpportunity,
  last settled ordinal/disposition, live nextReleaseTurn, carried debt, and
  current service/rank envelope

PlanMembership
  PlanShardID, PlanNamespaceEpoch, RootPlanEpoch, MembershipID/generation,
  exact StreamLedger and AdmissionSnapshot identity, root lane/cell,
  lineage-local root reservation, and certified rank contribution

PlanTransitionRecord and apply ledger
  future effective boundary vector, predecessor/successor plan identities,
  independently applicable local deltas, commit seal, and per-shard apply status

FrozenLeaseUse and SecurityUseVector
  exact term/expiry and relevant scope generations selected for a particular
  release, accepted best-effort request, hold, activation, or token

ClockBridgeCertificate
  exact current shared lane/lease clock relation selected for a release or
  control horizon; it is not immutable admission identity
```

An ordinary release mutates only `StreamLedger`. A plan change publishes a new
`PlanMembership` in the affected shard and may reuse an unchanged
`AdmissionSnapshot`; it never rewrites the snapshot or an unrelated lineage.
An open opportunity freezes the exact membership, current `FrozenLeaseUse`,
current relevant `SecurityUseVector`, and exact current
`ClockBridgeCertificate` under which it was released. A pure lease or bridge-
certificate extension changes only its shared authority record and creates no
new snapshot or membership.

Obligation, guaranteed-consumer, control receipt, and RunToken records carry
the exact snapshot identity or its collision-resistant canonical digest. A
root token additionally carries the exact `FrozenLeaseUse` and
`SecurityUseVector`. Its expiry cannot exceed the frozen term's original
expiry, the current monotonic authority-use retirement fence, Domain epoch
validity, relevant scope-generation equality, or its own root-budget deadline.

The full canonical `AdmissionSnapshot` tuple is the semantic identity. A
digest is only a sealed representation optimization. The executable model
compares the full tuple or an injective symbolic encoding; it does not assume
that an arbitrary equal-sized bit string proves equality. A concrete digest or
MAC requires a later cryptographic rely that binds encoding version, length,
field order, issuer context, and anti-substitution domain. Digest collision or
ambiguous encoding must fail validation rather than select one authority.

Resident backing has a narrower but explicit semantic key:

```text
BindingAuthorityKey
  MonitorBootEpoch
  NodeConfig and complete DomainHierarchyCertificate/fence vector
  ClusterIssuerIncarnation, DomainKey, DomainEpoch, and
  LocalAuthorityGeneration
  exact NodeLeaseImportCertificate stable authority/conversion/mode identity,
  NodeLeaseID and NodeLeaseEpoch, excluding extension-only
  LeaseTermGeneration/expiry
  DescriptorIncarnation, ResidencyDescriptorGeneration, descriptor digest,
  MemoryViewID/ViewEpoch, and BackingOwnershipEpoch
  PlacementIncarnation, PlacementGeneration, and every
  placement/exclusivity/co-tenancy field that affects this binding
  exact GlobalPlacementUse and RootExecutionAllocationCertificate identity
```

A `ResidentBinding` carries the exact `BindingAuthorityKey`. Every input of
`BindingAuthorityKeyOf` is present explicitly in the canonical snapshot; a
descriptor digest is not treated as a free oracle for missing view/ownership
fields. A held binding also carries its complete consumer set; a worker or late completion carries
`WorkID`, expected binding key/generation, and membership generation. A
RunToken binds the full admission snapshot, exact `PlanMembership` or
best-effort authority-use, exact `FrozenLeaseUse`, current
`SecurityUseVector`, and exact resident binding key. The Monitor validates an explicit
`BindingAuthorityKeyOf(AdmissionSnapshot)` function and requires exact equality
with the resident key before activation. That pure projection names every
source field above; it is computed from canonical state and is never a stored
free Boolean. Equality of the whole admission digest is sufficient but not
required.

Pure extension-only lease-term renewal preserves both the resident binding and
the existing immutable admission snapshot. A priority, budget, class, or other
service-contract change publishes a new immutable snapshot/generation for
future use, while it may reuse the old resident binding when
`BindingAuthorityKey` remains equal. It never mutates or relabels an open
opportunity's frozen snapshot or rank. Any update to eligible placement,
exclusivity, co-tenancy,
MemoryView, backing ownership, `DomainEpoch`, or `NodeLeaseEpoch` advances the
appropriate binding key component and forces drain/rebind before activation.
An expired term may leave an inaccessible protected cache entry, but can never
authorize a token. This is a typed compatibility relation, not an implementer
choice to ignore changed fields.

Cutover-derived authority is not stored in or written back to this immutable
snapshot. A separate Monitor-owned `RetirementFence` is keyed by the exact
`(AdmissionSnapshot identity, AuthorityUseID)`, where `AuthorityUseID` is a
guaranteed `PlanMembershipID` or best-effort admission-use identity:

```text
RetirementFence
  AdmissionSnapshot identity
  exact AuthorityUseID
  RetirementFenceGeneration
  state: Current, Retiring, Revoked, LeaseExpired, or Settled
  preservedCurrentOpportunityID or None
  releaseNotAfterTurn
  activationNotAfterTurn
  tokenNotAfterLeaseTick
  cause and transition-witness reservation IDs
```

The current fence begins open only inside the authenticated lease and contract
horizon. Plan cutover advances only old membership-use fences to `Retiring`;
the same snapshot may remain current through a new membership. Obligations
already released retain their frozen old membership, exact opportunity ID,
precomputed activation deadline, and terminal reservation. The opportunity
records the fence generation observed at release for history, but activation
does not require that obsolete generation to remain equal. It reads the live
monotonic fence and succeeds only when the exact opportunity is its sole
`preservedCurrentOpportunityID`, its release and activation horizons still fit,
and the state is `Current` or `Retiring`. The lane boundary protocol publishes
the new retirement fence before its post-cutover `PrepareIntent`, so the
future-cell joint activation and newly issued token are sealed with the
then-current exact fence generation. No token or
unnamed predecessor-generation artifact survives. Security revoke,
issuer lease fence, local rejection, or independent lease expiry narrows the
affected use and invokes protected stop. Fence generations never reopen or
lengthen a cutoff. Capacity remains charged until every exact old artifact
settles. Thus retirement narrows a separate authority-use record without
mutating the digest-bound snapshot.

Each root lane has an independent monotonic `laneTurn`; lease time is a
separate Monitor/hardware monotonic `leaseTick`. Both are independent of Linux.
The shared `LeaseAuthorityRecord` is keyed by `NodeLeaseID/NodeLeaseEpoch` and
holds the issuer envelope, current extension-only term, expiry, and rejection
fences. Admission snapshots bind its stable envelope identity and rights digest
without embedding its mutable current term. Each release or accepted
best-effort operation derives and retains one exact `FrozenLeaseUse`; referenced
old term attestations cannot be garbage-collected until all such uses settle.
Lease validity is half-open and use-specific:

```text
LeaseValidForNewRelease(snapshot, authorityRecord) ==
  snapshot authority envelope and rights equal the current record
  and ClusterIssuerIncarnation, LocalAuthorityGeneration, and
      LocalLeaseFenceGeneration are exact
  and record current term is the latest extension-only term
  and currentTerm.LeaseClockEpoch = current LeaseClockEpoch
  and leaseIssuedTick <= leaseTick < currentTerm.leaseExpiryTick
  and current term boot/reconciliation/dirty-arm relation is exact
  and no current LocalRejectFence, SecurityScopeFence, or failure state whose
      authoritative ownership closure intersects this use blocks release

LeaseValidForFrozenUse(frozenUse) ==
  its exact retained term was current when the Monitor created that use
  and its ClusterIssuerIncarnation, NodeLeaseEpoch, local generations, and
      rights digest still match the current effective envelope
  and frozenUse.LeaseClockEpoch = current LeaseClockEpoch
  and leaseTick remains before that frozen term's sealed original expiry
  and no issuer, local, security-scope, or affected-failure fence rejects the
      envelope or frozen use
  and its SecurityUseVector exactly matches every relevant current scope
```

An extension therefore cannot invalidate an already frozen old-term
opportunity, but that opportunity cannot inherit the extension's later expiry.
Only future uses select the latest term. Extension does not create a new
`AdmissionSnapshot`, `PlanMembership`, or per-admission update. An issuer
envelope change or relevant local security fence invalidates both forms
immediately.

Changing `LeaseClockEpoch` is not term extension. The old timebase cannot be
replaced until every old-epoch opportunity, hold, and token is terminal or
permanently fenced and every old certificate is retired. Numeric expiry is
never compared across epochs.

`TrustedLeaseAdvance` advances only the trusted timebase and bounded timer
index; extension updates one `LeaseAuthorityRecord`, and neither operation
performs an atomic scan over all admissions. Executability is defined
combinationally by exact `LeaseClockEpoch`, `leaseTick < token.expiry`, exact
full FailureScopeIdentity/generation entries, and current fences. Hardware
checks those sealed conditions on
every active lane. At or after expiry, after a relevant scope-generation
advance, or while a relevant fence is active, the token is non-executable even
if lazy bookkeeping still says `Current`. Stop bookkeeping is bounded by the
fixed active-lane set; per-admission retirement and cleanup are lazy,
scope-charged work that cannot extend authority.

`ClockBridgeCertificate` is executable data, but it is only a typed bundle of
three separately owned proofs. It cannot turn a Monitor service guarantee into
an external clock assumption:

```text
HardwareProgressCertificate
  LeaseClockEpoch, ServiceOpportunityClockEpoch,
  HardwareProgressGeneration
  baseLeaseTick, baseServiceOpportunityTurn
  initialLeaseTickBurst, maxLeaseTicksPerOpportunity > 0
  [validFromLeaseTick, validUntilLeaseTick)

ServiceAllocationCertificate
  ServiceOpportunityClockEpoch, ServiceAllocationGeneration
  exact shared HardwareCapacityRootCertificate or disjoint service-hardware identity
  exact protected-service pool path and every parent schedule generation
  immutable frame length, phase, and positive child-slot count at every level
  exact leaf ControlClockEpoch and control-shard identity

TargetLaneQuotaAnchor
  exact opportunity/control-operation identity
  LaneClockEpoch, ControlClockEpoch
  exact TargetControlReservation identity
  anchorLaneTurn, anchorTargetControlTurn
  minControlTurnsPerLaneTurn >= 1, finite maxInitialLaneLead

ClockBridgeCertificate
  exact identities of all three records, BridgeCertificateGeneration,
  admitted rank envelope, tokenStopBoundLeaseTicks, and validity horizon
```

`ServiceOpportunityTurn[pool]` advances only on a real protected Monitor entry
that supplies one physical dispatcher opportunity. `ProtectedServiceStep`
advances that turn and dispatches exactly the slot named by the immutable
parent schedule; it may advance at most one selected child/control turn per
owned slot. Hardware supplies the protected entry opportunity. Which shard is
selected and whether its `ControlTurn` advances are Monitor guarantees. A
dispatch failure cannot mint a virtual turn and enters the typed protected-
service fail-stop path.

The external hardware/time rely is only, for natural deltas from one exact
`HardwareProgressCertificate`:

```text
dQ = LeaseTick - baseLeaseTick
dH = ServiceOpportunityTurn - baseServiceOpportunityTurn
dQ >= 0 /\ dH >= 0
0 < maxLeaseTicksPerOpportunity
dQ <= initialLeaseTickBurst + maxLeaseTicksPerOpportunity * dH
validFromLeaseTick <= LeaseTick < validUntilLeaseTick
```

It contains no lane/control quota or Monitor target-selection fairness premise.
In addition, protected `LeaseTick` must eventually advance or an independent
watchdog must fail-stop every scope whose authority is time bounded. The upper
relation alone does not forbid an indefinitely stalled clock, so unbounded
`LeaseTick` stutter withdraws every time-bounded liveness claim. Violation of
either clock rely fences the
exact service/clock scope and invokes reserved token stop. Safety remains
fail-closed; target liveness is no longer claimed.

Monitor service allocation is conserved at every hierarchy node `n`:

```text
FrameLength[n]
  = EmergencySlots[n]
  + ManagementSlots[n]
  + LocalProtectedSlots[n]
  + SUM child in Children[n] : Slots[n, child]
  + SlackSlots[n]

all terms are natural
every protected child reservation has Slots[n, child] > 0
the immutable schedule contains exactly those occurrences
```

Every shard certificate binds one exact root-to-leaf path and all schedule
generations. `Visits(n, child, phase, turns)` counts child appearances in the
next finite parent turns. `Distance(n, child, phase, k)` is the least `t` whose
visit count is at least `k`; positive finite schedules make it total.
`PathDistance` recursively composes those distances. Residual capacity is
updated along only that path, so independently issued certificates cannot
overbook a shared physical executor. A sum of nominal rates alone is rejected
because it does not bound burst or maximum gap.

Each control-shard turn dispatches at most one exact bounded microstep for one
target named by its immutable `TargetControlReservation`. That microstep cannot
block while holding its schedule cell: it advances one monotonic target state,
returns a typed terminal result, or consumes its reserved fail-stop path. The
protected sparse nonempty-target index controls membership and O(1) successor
lookup; an immutable bounded target schedule or equivalent certified server
controls occurrences. Neither structure receives external fairness.

`TargetControlTurn[x]` advances only when a microstep owned by `x` executes.
For every physical control-shard step:

```text
SUM x in ActiveTargets[shard] :
  delta(TargetControlTurn[x]) <= delta(ControlTurn[shard]) <= 1
```

Thus one operation for target A cannot pay target B's rank. For each active
target `x`, quota is measured only after its own anchor:

```text
dL_x = LaneTurn[x.lane] - anchorLaneTurn[x]
dC_x = TargetControlTurn[x] - anchorTargetControlTurn[x]
m_x * max(0, dL_x - maxInitialLaneLead_x) <= dC_x
m_x >= 1
```

`LaneBoundaryAdvance` is enabled only if the next state preserves this
inequality for every member of its bounded active-target set. `ControlTurn`
may continue while that lane is held, and another lane never waits on this
guard. Shard or target turns accumulated before target selection cannot satisfy
it. Admission reserves enough target occurrences to derive the quota from the
parent-conserved schedule; target-picker fairness is never an assumption.

Rank conversion is constructive. For a finite ordered stage list,
`ControlTurnsFor(stages, phase)` sequentially adds the fixed-frame distance to
each stage's required class slot. `PoolTurnsForRank` maps that value through
`PathDistance`. The conservative v1 equations are:

```text
RankToLaneTurns
  = checked sequential sum of
      rootCellDistance
      + maxInitialLaneLead
      + ceilDiv(ControlTurnsFor(stages, phase), m)
      + declared trusted-countdown lane bounds

LeaseTicksForRank
  = checked sequential sum over protected pool stages of
      residualBurst + maxLeaseTicksPerOpportunity * PoolTurnsForStage
      + declared external-countdown tick bounds
      + tokenStopBoundLeaseTicks
```

`max` may replace a sum only where a separate composition certificate proves
parallel progress and noninterference. Every operator is total and monotone on
naturals, and overflow rejects admission. Final control commit and every
release select current exact component certificates and create a fresh target
anchor. Live predecessor certificates remain retained, but extension/rebase
updates no opportunity, admission, or membership and traverses no users.

The derived `ClockBridgeInvariant` is the conjunction of the external
`HardwareProgressInvariant`, internal `ServiceCapacityInvariant`, and internal
target `LaneControlQuotaInvariant`; only the first is an external rely.
Admission requires `LeaseTicksForRank` plus stop headroom to lie strictly inside
the frozen half-open lease and certificate horizons. Production wall-clock
acceptance still requires later protected-entry, timer, WCET, and hardware
refinement. Without all three exact proofs, guaranteed publication or release
is forbidden.

At most `current + retiring` authoritative admission generations may exist for
one `DomainKey` in the reference contract. One separately bounded candidate
operation may prepare their successor but is not authority. Another update is
serialized until the retiring generation settles. This bound prevents valid
control-plane churn from creating unbounded version state.

`AdmissionGeneration` changes service and placement policy. It does not by
itself revoke the Domain's security identity. `DomainEpoch` changes only for
security reincarnation/revocation. Binding-relevant descriptor changes use a
separate `ResidencyDescriptorGeneration`, so a pure priority or class change
does not needlessly invalidate every resident page/view binding.

## Feasibility Witness

A count of guaranteed Domains or a scalar CPU-utilization sum is not a
sufficient admission test. Affinity, finite slots, setup work, non-preemptible
trusted drain, exclusive migration, management service, and renewal all create
additional constraints.

The candidate contract must carry or produce a Monitor-verifiable witness for:

```text
root CPU service capacity and root quantum/deadline obligations
NodeConfig width compliance and exact DomainHierarchyCertificate path
every ancestor current/pending/retiring/failure-escrow capacity equation
parent-conserved RootExecutionAllocationCertificate with exact physical cells
bounded root release fanout and certified root-grant position after preparation
KTransitionShards and the fixed compositional local/commutation/aggregate
certificate grammar for every mixed terminal apply prefix
authenticated lease and retiring-snapshot horizon covering every admitted
release deadline and token lifetime
typed NodeLeaseImportCertificate partition mode and conservative clock horizon
exact GlobalPlacementUse or typed nonexclusive NotApplicable placement receipt
eligible CPU/lane assignment and co-tenancy constraints
residency transition service capacity
finite operation, request, member, physical-work, and replay-result storage
separate component-wise control-work credit and operation-record equations
slot occupancy and worst-case turnover/setup work
KReplicas and reserved worst-case revoke/descriptor-change cleanup
maximum residual root lease and trusted-reference drain blocking
MemoryView/binding preparation ordering
bounded canonical security/failure dependency closure for every execution use
KFailureScopesPerEvent, per-scope incident/audit capacity, and
AuditHeadroomWindow/checkpoint-renewal reservation for claimed liveness
management and recovery reservation
complete ManagementRecoveryBootstrapContract disjoint from ordinary capacity
existing contracts' carried service debt and next due release
planned hotplug/failure envelope promised by the contract
exclusive placement destination reservation plus source-quiescence-receipt-
before-destination-commit ordering and cross-lane calendar/debt mapping
ProjectionEpoch renewal headroom or an admitted maintenance interval
```

Candidate construction first freezes a `PreparationSnapshot`. An
`AdmissionControl` cell may move it to `CommitSealPending`, but not directly to
commit. A separately reserved bounded `SealCommitReady` action validates the
static `CommitDeltaTemplate`, reserves worst-case transition intervals, and
freezes typed dependency envelopes; it does **not** freeze hot cursors or choose
an absolute boundary. It waits for no token, handoff, drain, or Linux action.
Linux and root/control service may continue around preparation. Final commit
instantiates the template from current monotone suffixes. An `ExactGuard`
change inside the footprint stales the one attempt; outside changes and
certified service progress do not. The static record contains at least:

```text
exact DelegationScope, MutationFootprint, canonical read set, and write set
affected capacity reservations and parent residual certificates
affected current/committed-pending/retiring identities plus parameterized
StreamLedger/open-opportunity suffix envelope
target PlanShardID, exact predecessor, successor template, minimum lead, and
delegation effect horizon for every written shard
current lease/fence/security/reconciliation/dirty-arm and clock-bridge inputs
affected CPU/projection/failure-scope and active/held/retiring artifact summary
the bounded compositional CommitDeltaTemplate for future due-release, every
Applied/FailedFenced mixture, retiring root service, and control microsteps
```

Commit does not trust a free `witnessValid` bit. In the same control-plane
atomic transition that publishes the transition record and committed-pending
memberships, the Monitor requires a pre-state `CommitReady` record, obtains the
selected operation's conflict intent, samples exact current ledgers, chooses
future boundaries satisfying minimum lead and delegation horizon, reconstructs
the typed dependency closure, verifies reservations, instantiates only the
enumerated footprint-local deltas, recomputes finite capacity/clock equations,
and checks
`CandidateDeltaConfinedToDelegation`. A dependency mismatch reaches terminal
`RejectedStaleSnapshot`; it never rebuilds under the same `ControlOpID`, and
the old memberships remain active. A new attempt requires a fresh ID and
dependency vector. Once this transition commits, later lane application is not
a second feasibility decision and cannot return `RejectedStaleSnapshot`.

The witness is checked against the actual current capacity journal. It is not a
Linux assertion. A witness feasible from an empty node is insufficient: plan
replacement also needs a **transition witness** covering active tokens,
pending and held obligations, current residents, retiring generations, and
unpaid debt across the cutover.

Complex plan construction may run in an untrusted management/service Domain.
The v1 builder completes before ControlOp acceptance; a future asynchronous
builder is fenced by the bounded watchdog defined above. The Monitor TCB need
only validate a bounded certificate and execute the result. Exact certificate
representation and scheduling algorithm remain unselected. This avoids
putting a large general scheduler or an attacker-sized search in the Monitor
without making that untrusted solver a liveness dependency.

## Dynamic Root Plan Sub-contract

Formal 0147 proves recurring service only for a fixed `RootFrame`. Dynamic
guaranteed admission therefore requires a versioned root-plan refinement. It
is a mandatory sub-contract of `RESIDENCY-DYN-001`; this analysis does not add
a second top-level claim merely to rename the same dependency.

The sub-contract requires:

```text
active plan is immutable
candidate construction and control commit cannot pause active guaranteed service
control commit atomically publishes an immutable future-effective transition;
each shard applies only its local entry at the recorded Monitor-owned boundary
current cursor and debt are Monitor-owned
surviving ServiceStreamID debt, sequence, and next due state carry across
commit
new contracts receive an explicit first effective release
removed contracts remain valid through their authorized effective boundary
new insertions cannot reset the cursor or replay an earlier prefix
ordinary plan updates cannot remove management/recovery reservation
```

The architecture has a finite `RootLaneSet` partitioned into independently
advancing `PlanShardID` objects. Each shard owns an immutable root-plan table,
its own `PlanNamespaceEpoch/RootPlanEpoch`, capacity journal, and monotonic
`laneTurn`. A v1 stream belongs to one lane; a later multi-lane reservation is
a bounded transaction over an explicit lane set whose boundary deltas are
independently applicable. Each committed
guaranteed stream owns protected service in its shard, every node reserves an
independently bootstrappable management/recovery lane, and remaining cells are
empty or explicit slack.

`DYN-COMPOSE` may instantiate one lane to expose detailed residency state, but
`DYN-SHARD` must instantiate at least two lanes and prove that disjoint
boundary, token, stop, failure, and commit actions commute. A token or drain on
one lane cannot prevent another lane's boundary or guaranteed progress unless
an authenticated failure selects a cover containing that lane or the node
fail-stops. This
noninterference is architecture, not a deferred scheduler optimization. A
production hierarchy may replace the literal tables only by refining these
per-lane owners and bounds.

Independent lane clocks do not imply independent physical CPUs. Every physical
context first has one `HardwareCapacityRootCertificate` whose literal schedule
partitions all uses of that context:

```text
HardwareFrameCapacity[c] =
  ProtectedControlCells[c] + DomainExecutionCells[c]
  + ManagementCells[c] + EmergencyCells[c] + SlackCells[c]
```

Control and Domain-execution certificates on shared hardware descend from the
same root and own disjoint occurrences. Independent roots are permitted only
for disjoint hardware identities. Every live lane then carries a
`RootExecutionAllocationCertificate` naming that hardware root, its exact
physical CPU or execution-pool incarnations, parent schedule path, eligible
context set, co-tenancy/failure scopes, cell duration and entry/exit guard, and
disjoint current/pending/retiring/management capacity. At every parent
execution pool:

```text
ExecutionFrameCapacity[p] =
  ManagementExecution[p] + EmergencyStopExecution[p]
  + SUM lane in Children[p] : LaneExecutionCells[p,lane]
  + SlackExecution[p]
```

The immutable parent schedule contains exactly the reserved occurrences. The
root allocator may issue an immutable `ExecutionCellLease` only for an
occurrence already debited to that lane through every shared parent. Protected
preparation binds one such future lease to an opportunity and creates a
non-executable `ActivationIntent`; neither action consumes the physical cell.
All mutable use state is instead held in the lease's single-writer
`ExecutionCellUseCell`. Preparation performs only its `Unbound -> Reserved`
transition. When the cell becomes current, the physical root-execution state
machine either consumes `Reserved -> Consumed` in the joint activation or
publishes `Reserved -> Expired`. Exit settlement alone publishes
`Consumed -> Settled`. A missed cell cannot wait, carry forward, or be reused.
One schedule occurrence maps to at most one lease/use cell and one token.

The token budget is bounded by the cell duration minus entry/exit guard and by
every lease, placement, security, retirement, and root-budget horizon. Each
physical context has zero or one active token owner. Cell end forces protected
exit, budget stop, and handoff before another owner can activate; unused budget
does not roll into another lane or later cell. Two lanes have independent
progress only when their execution contexts are disjoint or their distinct
cells are simultaneously reserved through every shared parent. Admission and
plan transition preserve the equation across current, committed-pending,
retiring, failure-escrow, and management shares. CPU loss consumes the admitted
failure reserve or fences the affected allocation; it never silently leaves
two certificates backed by one surviving cell.

The root CPU-service plane and the Monitor control-work plane are distinct
finite resources and clocks:

```text
Domain-execution plane
  consumes parent-conserved physical execution cells only at due joint
  activation, then enforces cell budget, exit, delivery receipt, and handoff

protected control/release plane
  advances lane contracts, releases obligations, pays carried debt, reserves
  binds allocator-issued future ExecutionCellLeases, creates ActivationIntents, prepares, drains,
  installs, renews, and cleans resident bindings
```

A `LaneBoundaryAdvance(l)` consumes one bounded protected schedule occurrence
for lane `l`; it does not consume a Domain execution cell. Protected control
microsteps advance an independently reserved per-shard or
node-management control cursor and may run while a lane turn is held for token
stop or terminal settlement. Doing work in one plane does not spend or
replenish capacity in the other. The plan certificate bounds release fanout and
root work per lane turn.
`MaxReleaseMaterializationsPerTurn = 1` and
`MaxRootDispatchesPerTurn = 1` per lane in the first reference, so no boundary
hides an attacker-sized scan or batch. Larger bounded fanout is a parameterized
refinement, not an unbounded loop.

Each Monitor-owned `laneTurn[l]` never resets inside its `LaneClockEpoch`. It
is the trusted discrete clock for that lane's periods, releases, deadlines, and
logical service bounds. Linux noise does not advance it. Finite counter
exhaustion follows the scoped renewal contract and cannot alias old deadlines.

Candidate membership/plan-shard commit occurs in one
`CommitControlOp` action on the independent control plane. At lane turn `t`,
`LaneBoundaryAdvance(l)` is enabled only after that lane's prior root token is
cleared and mandatory handoff is complete. A token on another lane is
irrelevant. If a stream is due at `t`, its prior
`CurrentOpportunity` must already be terminal and cleared; otherwise the
boundary cannot advance and the violated terminal rank is exposed rather than
silently skipping the release. Trusted stop/settlement actions may run while
`laneTurn[l]` is held at `t`. All choices are pure functions of the pre-state
or earlier staged results in this fixed order:

```text
Due_t
  at most one release owned by the old plan and due exactly at t

ApplyCommittedTransition_t
  consume only the exact immutable transition entry already commit-sealed for
  this shard and effective after t; publish its successor membership, every
  old-use fence, and an exact RetiringOpportunityReservation for any Due_t or
  earlier unfinished old-membership opportunity, or follow its total
  FailedFenced disposition; no cross-shard wait, feasibility revalidation, or
  stale-candidate result exists here

PrepareIntent_t
  one protected action for the pre-state CurrentOpportunity interpreted under
  the staged post-commit membership/fence state; it may bind one exact,
  already allocator-issued future ExecutionCellLease by reserving its use cell
  and create one non-executable ActivationIntent,
  but cannot consume a physical cell or Due_t materialized in this boundary
```

The Monitor composes these bounded, ownership-disjoint staged updates. A valid
local apply publishes the committed successor membership/plan for the
post-apply `PrepareIntent_t` and future releases, and creates every old
authority-use `RetirementFence` before intent preparation. Therefore the later
due-cell joint activation and token carry the already-current fence generation. Candidate stale
rejection occurred earlier at control commit; local apply is deterministic.
The action then increments only `laneTurn[l]`. No other action interleaves
inside this lane-local reference transition:

```text
old plan owns releases with releaseTurn <= t
new plan owns releases with releaseTurn >= t + 1
table position = laneTurn[l] modulo that shard's fixed table length
surviving CurrentOpportunity, last settlement, next release, and debt state is
in StreamLedger outside the table and carries over
```

Applying a successor table never strands an opportunity already released by
the predecessor. The transition certificate reserves a bounded
`RetiringOpportunityReservation` keyed by the exact old membership and
`ObligationID`, including the same-boundary `Due_t` case. The staged effective
root schedule is the successor table plus these exact finite retiring cells;
its deterministic selector preserves both successor guarantees and every
frozen old rank. A retiring reservation can activate or settle only its named
opportunity, creates no later release, and remains charged until terminal
cleanup. Plan removal therefore cannot turn a preserved old obligation into an
unscheduled side record.

The root-service cell may prepare exact joint `ActivateHeld`, record a bounded
no-work advance, or decrease an already certified debt/rank. A release may be
scheduled ahead of its corresponding root-grant cell by a certified
preparation lead. The transition witness proves that every stable release has
a root-grant opportunity after its preparation bound and before its numeric
deadline; an empty or unrelated cell cannot reset that obligation's rank.
Only the joint activation action described below can convert that prepared
intent into execution authority. Token consumption, expiry/stop, and handoff are separate trusted actions
between lane boundaries. `SettleCurrentOpportunity` and mandatory cleanup are
named bounded protected actions that remain enabled while the lane turn is
held. Linux cannot complete or postpone them. The next turn on that lane cannot
run past a still-active prior token; other lanes continue independently.

New insertion cannot replay a table prefix because each `laneTurn` is absolute
inside its incarnation.
Every stream has an absolute `nextReleaseTurn`; unrelated plan commits cannot
move it later, reset it, or make a due release disappear. A new stream receives
an explicit first release after its certified preparation lead. Empty cells
advance the same cursor. A stable guaranteed contract must continue to receive
service despite unrelated admissions, removals, candidate-plan failures, or
best-effort churn.

An emergency Domain revoke is not an ordinary plan update. It fences new
requests and activations immediately, stops bounded active authority through
the root mechanism, and then drains. It may terminate that Domain's service
obligation, but it cannot erase unrelated debt or management service.

At most one current, one committed-pending, and one retiring root plan exist
**per shard** in the reference contract. Local apply fences creation of new
releases from old memberships, but old pending, held, or active obligations
retain their exact membership until settlement. Storage and epochs are not
reused while an artifact can complete. Another ordinary commit touching that
shard is rejected/busy until its pending and retiring transition settles;
disjoint shards remain independent.

Every root token created from a dynamic plan binds at least:

```text
MonitorBootEpoch
NodeConfigGeneration and complete DomainHierarchyCertificate/fence vector
PlanShardID, PlanNamespaceEpoch, RootPlanEpoch, and exact PlanMembershipID
DomainKey, DomainEpoch, exact FrozenLeaseUse/LeaseAttestationID and original
trusted lease expiry, exact SecurityUseVector, and RetirementFenceGeneration
exact NodeLeaseImportCertificate and GlobalPlacementUse
AdmissionID, AdmissionIncarnation, and AdmissionGeneration
full AdmissionSnapshot identity and exact BindingAuthorityKey
ServiceStreamID, ServiceStreamIncarnation, and ServiceContractGeneration
OpportunitySequence
exact CPU, projection, slot, and resident-binding generations
HardwareCapacityRootCertificate, RootExecutionAllocationCertificate,
ExecutionCellLease, ActivationID, ExecutionContextKey, and
ActivationCommitReceipt
MemoryView and exact code/entry/translation/backing/mutable-state epochs
LaneClockEpoch/laneTurn release context, ActivationNamespaceEpoch,
ActivationGeneration, root budget, and expiry
```

A plan cutover does not replenish or forget an old token. The affected lane
has no active pre-state token. `ApplyCommittedTransition_t` publishes its
fences before `PrepareIntent_t`, so every newly created intent and later
due-cell joint-issued token binds exactly one current or retiring membership and its already-
current fence. Its entire
remaining budget and interference stay reserved until bounded expiry/stop.
Capacity cannot be released to a successor while old authority can still
spend it; current and retiring tokens cannot double-count one root reservation.

## Recurring Opportunity Semantics

A guaranteed service contract contains at least:

```text
ServiceStreamID, ServiceStreamIncarnation, and ServiceContractGeneration
NodeConfigGeneration and exact DomainHierarchyCertificate
DomainKey, DomainEpoch, NodeLeaseID, NodeLeaseEpoch, and stable rights envelope;
each release separately freezes the current LeaseTermGeneration
exact NodeLeaseImportCertificate and GlobalPlacementUse when required
class and charge subject
eligible CPU/lane set and placement mode
RootExecutionAllocationCertificate and parent-reserved execution cells
minimum service quantum or opportunity
period/minimum separation and maximum gap/deadline
residency/setup work bound
maximum simultaneous releases
declared hardware-failure/hotplug envelope
```

The first reference restricts each guaranteed stream to exactly:

```text
0 < ActivationTurnBound <= deadline <= TerminalTurnBound < period
release at nextReleaseTurn when CurrentOpportunity = None
nextReleaseTurn' = nextReleaseTurn + period
```

`TerminalTurnBound` includes activation, finite root-token lifetime/stop, and
terminal settlement. It is what makes at most one unfinished opportunity an
inductive finite-memory rule rather than an assumption. These are reference
semantics, not a universal production ABI decision. `period`, `deadline`,
`nextReleaseTurn`, `ActivationTurnBound`, and `TerminalTurnBound` use the
stream's absolute `laneTurn`; physical lease expiry remains in `leaseTick` as
defined above.

ROOTSCHED generates each logical obligation as:

```text
(PlanShardID, PlanNamespaceEpoch, RootPlanEpoch, PlanMembershipID,
 ServiceStreamID, ServiceStreamIncarnation, ServiceContractGeneration,
 OpportunitySequence, exact AdmissionSnapshot identity)
```

`ServiceStreamID` is a stable debt lineage, not a caller-selected escape from
old debt. A compatible plan update increments `ServiceContractGeneration` but
preserves sequence and debt. An incompatible replacement must carry an
explicit predecessor/successor settlement mapping, or withdraw the old stream
at its authorized effective boundary before creating a genuinely new stream.
`ServiceStreamIncarnation` changes only after quiescent sequence-namespace
renewal and also carries debt forward.

Near `OpportunitySequence` exhaustion, future release publication stops with
reserved headroom. The existing `CurrentOpportunity` must reach terminal under
its old incarnation first. A typed `StreamSuccessorRecord` then transfers the
last settlement, live `nextReleaseTurn`, debt, contract parameters, and skipped
maintenance ranges into a fresh incarnation before release resumes. No live
old-incarnation obligation or token is relabeled as new; preserving the live
current record applies to ordinary plan cutover, not incarnation renewal.

The lifecycle is:

```text
Released
  -> Preparing
  -> HeldReady
  -> ActivationIntentPending
  -> ActivatedUnserved
  -> Served
  -> Settling
  -> Completed
```

Authorized withdrawal or revoke may instead produce:

```text
Released, Preparing, or HeldReady
  -> WithdrawOrRevokePending
  -> Cleanup
  -> Withdrawn or Revoked

ActivatedUnserved or Served
  -> StopPending
  -> Settling
  -> ActivatedAndStopped or ActivatedAndStoppedWithoutDeliveredService

independent trusted lease expiry
  -> LeaseExpired when not activated
  -> StopPending -> ActivatedAndStopped when a token was active
```

The machine lifecycle refines `Activated` to `ActivatedUnserved or Served`,
maps `WithdrawOrRevokePending` by receipt presence to
`SuppressedBeforeActivation or StopPending`, maps `Cleanup` to `Settling`, and
maps every named terminal disposition to `Terminal`. Pending publication also
has one order: the source owner durably publishes `DurablePending`; only then
does the transaction owner allocate and link `PhysicalResidencyTxn`.

Linux cannot suppress release by withholding a runnable hint. It cannot cancel
the obligation by reporting idle, timing out, moving a task, or changing a
cgroup. The Monitor guarantees an activation opportunity, not useful
Domain-local application progress.

One bounded current record represents recurrence without an unbounded queue or
an invalid arithmetic assumption about contiguous service:

```text
nextOpportunityOrdinal
  next never-reused ordinal inside ServiceStreamIncarnation

CurrentOpportunity
  None, or exact ObligationID, frozen AdmissionSnapshot, PlanMembership,
  FrozenLeaseUse, SecurityUseVector, AuthorityUseID/RetirementFence, and
  release-observed fence generation/horizon, BindingAuthorityKey, exact
  ClockBridgeCertificate,
  frozen eligible lane/root rank, releaseTurn, activationDeadlineTurn,
  terminalDeadlineTurn, ExecutionCellLeaseID or None, ActivationIntentID or
  None, ActivationID or None, ActivationCommitReceipt or None,
  ExecutionDeliveryReceipt or None, and terminal disposition or None

lastSettledOrdinal and lastTerminalDisposition
  advance only when CurrentOpportunity reaches one immutable terminal result;
  then CurrentOpportunity becomes None

terminal disposition
  ActivatedAndExpired, ActivatedAndStopped,
  ActivatedAndStoppedWithoutDeliveredService, Withdrawn, Revoked,
  LeaseExpired, FailedByGuardedExternalFailure, or ContinuityLost
```

Residency readiness reserves the `ExecutionCellUseCell` for one exact,
already allocator-issued future `ExecutionCellLease` and creates only a
non-executable `ActivationIntent`. It binds the exact opportunity, held
binding, future cell identity and interval, CPU incarnation, frozen
lease/import/placement/security uses, and the complete required receipt set.
Intent creation neither consumes the physical cell nor changes executable
hardware state. If readiness is absent when that cell becomes current, the
cell expires unused; no stale intent can spend it later.

At the exact due cell, `ActivateHeld` is the physical `RootExecutionStep` and
one joint ROOTSCHED/ENTRY/CODE/STATE action. It first validates every bound
identity and installs one exact `ExecutionContextKey`:

```text
DomainKey/DomainEpoch and complete hierarchy fence vector
CPU/pool, RootExecutionAllocation, ProjectionEpoch, CpuIncarnation, SlotGeneration
MemoryViewID/ViewEpoch and translation/TLB epoch
CodeEpoch and immutable executable-root identity
entry-stack, exception-entry, and return-context epochs
BackingOwnershipEpoch and every mutable Domain-state/service epoch
GlobalPlacementUse, FrozenLeaseUse, SecurityUseVector, and RetirementFence
```

`RequiredQuiescenceReceiptSet(binding)` enumerates every dependency class and
its exact object/epoch set. A class that truly has no predecessor is represented
by a typed `NotApplicable(class, reason, context)` receipt; absence is never
interpreted as not applicable. The physical refinement CASes the use cell
`Reserved -> Consumed`, writes the context into a hardware-inert staging bank,
and commits one `ActivationDecisionCell` keyed by the intent/lease pair. That
decision derives one exact `ActivationID`, retains the staging generation,
arms budget bounded by the remaining cell after entry/exit guard and every
authority horizon, arms independent stop, and names exactly one RunToken. One
final valid entry-gate publication makes the context executable and enters it;
the recoverable `ActivationCommitReceipt` binds that linearization. Before
this gate, even a committed decision is not execution or service. A crash
before the gate can only discard or resume the same staging generation and
ActivationID within the same due cell and `MonitorBootEpoch`. A crash after
the gate is bounded by independent hardware stop; recovery settles only that
same decision. Changing `MonitorBootEpoch` permanently invalidates the old
decision and cannot re-execute it. Failed validation CASes the due use cell to
`Expired`, leaves no partial executable state, and terminates or retries only
with a fresh future cell. A retry of a terminal intent/lease pair returns the
stored result and cannot mint another ActivationID, receipt, or token.

`activated` is the derived predicate `ActivationCommitReceipt != None` and may
become true only in that joint action, but activation alone is not recurring
service. Cell exit emits an `ExecutionDeliveryReceipt` over the exact entry,
positive delivered execution ticks or authenticated post-entry voluntary
yield, forced exit reason, and budget settlement. Only that qualifying receipt
sets `served`; zero delivered ticks without such a post-entry yield do not.
Cancellation, withdrawal, revoke, lease expiry, and failure may settle without
service and never masquerade as it. No subtraction such as
`dueSequence - servedSequence` is used, and no ordinal comparison crosses
`ServiceStreamIncarnation`. The guarantee is that CPU authority was physically
entered and offered for the certified quantum, not that compromised
Domain-local Linux performed useful application work.

The plan may materialize a guaranteed release only when the authenticated
latest lease term, exact `GlobalPlacementUse`, security horizon, and membership
authority-use fence cover that release's certified activation, delivery,
terminal, and cell lifetime in the logical reference clock. The effective
horizon is their minimum. A future renewal is not current authority. If a
fresh extension-only
term is committed in time, later releases freeze that term from the shared
record without replacing their `AdmissionSnapshot` or `PlanMembership`, but it
does not extend `GlobalPlacementUse`; an
already released opportunity may continue only within its old
`FrozenLeaseUse` and authority-use horizons. Without renewal the lineage stops
releasing at its authorized boundary, pending authority stops at expiry, and
terminal `LeaseExpired` does not count as service. Mapping this logical horizon
to wall-clock leases requires the later timer/WCET refinement named in the
bound section.

A duplicate transport for the same exact opportunity is idempotent. A later
opportunity is not a duplicate and cannot be folded into the earlier
activation. If an earlier opportunity remains unfinished at its next release
in the reference contract, that is a service-contract breach or declared
degraded state, not permission to overwrite it.

For the first reference, `CurrentOpportunity` is the only unfinished record.
A due release created by `LaneBoundaryAdvance(l, t)` is not visible to that
same action's `PrepareIntent`; it first becomes eligible at turn `t + 1`. While a stream
remains committed, stable, guaranteed, and outside guarded failure, that exact
record must set `activated = true` by `activationDeadlineTurn`, set
`served = true` by its separate delivery bound, and reach its terminal
disposition by `terminalDeadlineTurn`, strictly before the next release.
`SettleCurrentOpportunity` and its required protected cleanup may run
while the lane turn is held and have an explicit finite rank/fair-action
contract; they do not depend on a later lane boundary. Ordinary plan cutover
preserves the full current record, last settlement, and `nextReleaseTurn`; it
cannot overwrite it.

The current record freezes its `FrozenLeaseUse`, `SecurityUseVector`,
`ClockBridgeCertificate`, `BindingAuthorityKey`, eligible lane, and remaining
rank. A service-only update may publish a successor admission/contract
generation for future use, but it neither changes this frozen record nor
increases its rank. A binding-relevant or lane-changing ordinary update waits
for terminal settlement in v1. Security
revoke, lease fence, or guarded failure may instead settle it through their
typed non-service path. Therefore repeated otherwise non-weakened updates
cannot restart residency work or increase the open opportunity's bound.

## Logical Requests and Physical Work

Transport identity and physical operation identity are separate:

```text
ResidencyRequestID
  (MonitorBootEpoch, exact issuer/sponsor identity and epoch,
   full request ScopedNamespaceRoot identity, RequestNamespaceEpoch,
   monotonic request sequence)

recorded request payload
  immutable canonical intent digest stored beside ResidencyRequestID

PlanMembershipID
  (MonitorBootEpoch, exact PlanShardID/root identity, PlanNamespaceEpoch,
   RootPlanEpoch, PlanMembershipGeneration, ServiceStreamID,
   ServiceStreamIncarnation)

ObligationID
  (PlanShardID, PlanNamespaceEpoch, RootPlanEpoch, PlanMembershipID,
   ServiceStreamID, ServiceStreamIncarnation, ServiceContractGeneration,
   OpportunitySequence, exact AdmissionSnapshot identity)

ConsumerKey
  guaranteed: ObligationID, frozen full AdmissionSnapshot and
  BindingAuthorityKey, SecurityDependencyCertificate, FrozenLeaseUse,
  SecurityUseVector, plus internal ResidencyRequestID
  best effort: ResidencyRequestID, payload digest, frozen full
  AdmissionSnapshot, SecurityDependencyCertificate, FrozenLeaseUse,
  SecurityUseVector, exact operation right, LocalRejectFence observation,
  BindingAuthorityKey, and charge subject/sponsor

BestEffortAuthorityUseID
  (MonitorBootEpoch, exact sponsor/principal and request ScopedNamespaceRoot,
   ResidencyRequestID, immutable consumer digest, FrozenLeaseUse identity)
  retained with its per-use RetirementFence until terminal settlement

PhysicalKey
  exact BindingAuthorityKey
  operation kind, work provenance class, and charge subject
  normalized target scope and eligible set
  placement/exclusivity constraints
  MemoryView/binding descriptor digest

WorkID
  (MonitorBootEpoch, exact provenance lane/shard and full work
   ScopedNamespaceRoot identity, WorkNamespaceEpoch, monotonic work sequence)
  exact PhysicalKey, bounded member slots, and membership generation
```

The same `ResidencyRequestID` with the same digest is idempotent. The same ID
with a different body is equivocation and is rejected without mutation. A
stale ID can return `Stale` rather than requiring an unbounded history of old
results.

Guaranteed requests originate only from a committed root stream. A root lane
has a bounded serial request cell in the reference model. Best-effort requests
use separately bounded, attributed mailboxes. Operation records are
preallocated or otherwise capacity-reserved before acceptance.

A `PhysicalResidencyTxn` may attach multiple logical consumers only when every
field of `PhysicalKey` is exactly equivalent. Attachment never overwrites the
older request's age, authority, charge, cancellation state, or terminal
outcome. The first reference does not merge different guaranteed streams or
opportunity sequences. A later typed aggregate may share physical preparation
only if it preserves each logical activation, charge, cancel, and settlement
obligation independently.

Guaranteed, recovery, control, and best-effort provenance do not coalesce into
one physical transaction in the first reference even when their target binding
would be compatible. In particular, best-effort cancellation or accounting
cannot attach to a guaranteed work reservation. A later request may observe an
already published compatible resident binding, but that is reuse after
publication, not shared in-flight authority or credit.

Admission generation, service stream/generation, opportunity sequence,
frozen lease term/expiry, rights, security-scope versions, and local rejection-
fence observation remain in each tagged `ConsumerKey`; they are deliberately
absent from `PhysicalKey` unless they change `BindingAuthorityKey`. This permits
physical preparation to be reused across a service-only update without making
the older service authority current. The Monitor revalidates the complete
consumer authority, exact relevant scope generations, and current fences before
Held publication and again at any activation. A best-effort consumer whose
frozen term expires, scope vector becomes stale, or authority is revoked does
not inherit a later term or recovered generation; it settles stale/expired and
must be resubmitted under fresh authority.

The reference transaction has `MaxMembers` preallocated member slots. Before
the first shared physical side effect, attachment or removal advances
`MembershipGeneration`. Starting drain/install freezes an immutable
`SealedMemberSet` of complete keys and `SealedMembershipGeneration`; no later
action changes either. Every physical worker step and receipt names
`(WorkID, SealedMembershipGeneration, PhysicalKey)`.

Post-seal cancellation changes only Monitor-owned per-member state:

```text
MemberDisposition[slot]
  Active, CancelPending, Cancelled, Activated, or Terminal

DispositionGeneration
  advances on a post-seal member-state change

SurvivorMask
  derived from current MemberDisposition; never supplied by a worker
```

A worker completion can advance the physical transaction but cannot publish a
cancelled member or overwrite `MemberDisposition`. Final Held/publication
revalidates every surviving complete authority tuple. A later request cannot
mutate the sealed carrier merely because a Linux `work_struct` is pending; it
receives a bounded typed response and may observe the eventual exact resident
binding through a new logical operation.

`DYN-COMPOSE` uses exactly one logical consumer per physical work item.
`DYN-REQUEST` separately uses `MaxMembers = 2` to make exact coalescing and
one-member cancellation non-vacuous. Neither model permits an unbounded waiter
list. A held binding stores immutable `SealedMemberSet` and
`SealedMembershipGeneration` plus the current Monitor-owned disposition vector
and generation, never a bare sequence, mutable member identity, or
overwriteable latest caller. The singleton specialization is used for every
guaranteed obligation in the first reference.

For a guaranteed stream, one outstanding `ObligationID` has exactly one
Monitor-internal `ResidencyRequestID`; retransmission does not create another
request. No Linux submission is needed to create that request.

## Cancellation Linearization

Cancellation is not a bit and timeout is not cancellation.

`CancelOpID = (MonitorBootEpoch, exact issuer/principal identity and epoch,
full cancel ScopedNamespaceRoot identity, CancelNamespaceEpoch,
monotonic cancel sequence)` is distinct from
`ResidencyRequestID` and has its own canonical payload digest and idempotent
terminal receipt. The response and state types are disjoint:

```text
CancelResponse
  CancelAccepted, CancelInProgress(winning CancelOpID), TooLate,
  TooLateAuthorityStopped, AlreadyTerminating, AlreadyTerminal, Unauthorized,
  Stale, Equivocation, RejectedBusy

RequestTerminalDisposition
  ActivatedAndExpired, ActivatedAndStopped, CancelledBeforeReservation,
  CancelledAfterCleanup, Withdrawn, Revoked, LeaseExpired,
  FailedByGuardedExternalFailure
```

Voluntary request cancellation applies only to an authorized best-effort
request. A guaranteed obligation is not voluntarily cancellable: management
withdrawal and security revoke are separate authority operations with their
own effective boundary and stop semantics.

Every member/request has one exact Monitor-owned `OpportunityLifecycleOwner`,
but it does not compress the lifecycle into one one-shot CAS. It owns three
separate monotonic records:

```text
ActivationDecision
  Undecided -> Activated(exact ActivationID)
            | SuppressedBeforeActivation(exact cause)

StopRequest, meaningful only after Activated
  None -> StopPending(exact first stop cause and cleanup reservation)

TerminalSettlement
  Open -> Terminal(exact disposition and cleanup/charge receipt)
```

Cancel, activation, and a pre-activation authority stop race only on
`ActivationDecision`. A live revoke, expiry, or failure fence is independent
enforcement state: it prevents a later activation even before the lifecycle
owner records `SuppressedBeforeActivation`, and after activation it causes the
owner to publish `StopPending`. A later fence cannot be hidden by an earlier
activation winner. It may add audit evidence, but it neither rewrites the
first request-result/stop label nor creates duplicate cleanup. Terminal
settlement occurs exactly once after all effects and references covered by the
winning lifecycle path are absent. The v1 table is total:

| Request state when cancel commits | Cancel response | Request result |
| --- | --- | --- |
| before reservation | `CancelAccepted` | immediate `CancelledBeforeReservation` |
| reserved, draining, or installing | `CancelAccepted` | `CancelPending -> Cleanup -> CancelledAfterCleanup` |
| `HeldReady`, before `ActivateHeld` | `CancelAccepted` | release hold, cleanup, then `CancelledAfterCleanup` |
| `ActivateHeld` already committed | `TooLate` | original request continues; authorized revoke may separately enter `StopPending` |
| pre-activation authority fence has suppressed activation, or post-activation non-cancel `StopPending` exists | `TooLateAuthorityStopped` | existing authority cause and cleanup continue |
| `CancelPending`, `Cleanup`, or `Settling` owned by the same winning cancel | `CancelInProgress(winning CancelOpID)` | existing cancel cleanup continues |
| `CancelPending`, `Cleanup`, or `Settling` owned by another cause | `AlreadyTerminating` | existing immutable cause and cleanup continue |
| terminal | `AlreadyTerminal` | immutable existing disposition |

`Ready` alone never makes cancellation too late. The pre-activation race has
one atomic `ActivationDecision` linearization. If cancel wins, future
activation for that consumer is forbidden. If activation wins, voluntary
cancellation is `TooLate`, while a later authorized revoke/expiry/failure still
publishes an independent fence and the post-activation `StopRequest`. If an
authority fence wins before activation, cancellation receives the typed
non-cancel response above. An authorized revoke remains a different stop
operation and cannot be represented as successful retroactive cancellation.

Stale generation or RequestID cannot affect newer work. One coalesced member's
cancellation cannot cancel another member. Cleanup is protected work. Capacity
and charge are not refunded merely when `CancelAccepted` is recorded; they
settle only after all Monitor/hardware effects, holds, and trusted references
associated with that request have settled. No terminal disposition can reopen
or change.

Exactly one `CancelOpID` may own `CancelPending` for a request. Retransmission
of that exact ID/digest is idempotent. A different fresh authorized cancel ID
arriving while cancellation is pending receives
`CancelInProgress(winning CancelOpID)` after bounded lookup and allocates no
second cancel record, waiter, or cleanup reservation. After request terminal it
receives `AlreadyTerminal`; an unauthorized caller does not receive the
winning identity. Thus cancel floods cannot turn one request into an unbounded
operation set.

For coalesced best-effort work, the table applies to the named member rather
than implicitly to the whole transaction. After seal, cancellation advances
that slot's `MemberDisposition` and `DispositionGeneration`; it never rewrites
`SealedMemberSet` or the worker's generation. Shared work and a held binding
continue for the derived surviving mask; only cancellation of the last active
member enters whole-transaction cleanup. A cancelled member may reach terminal
only after its member-specific effects are absent, while the shared work
reservation remains charged to the surviving transaction. This is why Held
state carries both immutable membership and mutable Monitor-owned disposition.

## Work Lanes and Churn Control

The Monitor service is not one FIFO. The minimum classes are:

```text
management/recovery
root expiry, revoke, and safety-critical stop
guaranteed residency obligations
mandatory cleanup and ProjectionEpoch renewal
best-effort residency proposals
admission/control candidate work
```

Management/recovery, expiry/revoke, guaranteed residency, and mandatory
cleanup/renewal receive protected capacity. Best-effort and candidate-plan
work may consume only declared slack or their own reservations. Donated slack
is reclaimable before the next protected service point and cannot create debt
against a protected lane.

Authority stop and physical cleanup are separate. Token expiry, revoke fence,
and `accepting = false` execute through the protected root/architecture stop
path and never wait for Linux, a best-effort mailbox, or cleanup completion.
Their later reference release, unmap, slot retirement, accounting settlement,
and evidence retention consume the provenance-correct cleanup lane. Cleanup
may delay reuse but cannot extend a stopped token or permit another activation.

The v1 executable reference uses this fixed protected-work frame:

```text
SafetyCleanup
ManagementRecovery
GuaranteedResidency
GuaranteedCleanup
ProjectionRenewal
GuaranteedResidency
AdmissionControl
BestEffortCleanup
Slack
```

One `ControlTurn[work-shard]` is completion or an explicit bounded no-work
advance of one frame cell. Best-effort forward work can run only in `Slack`; its mandatory
cleanup runs only in `BestEffortCleanup`. A vacant protected cell may be
donated only with an atomic reclaim-before-next-cell rule. The literal ratios
are reference-model parameters, not a production choice.

Control service has its own `ControlClockEpoch/ControlTurn` per provenance
shard; it is not the same clock as any `laneTurn`. Protected prepare, commit,
cleanup, settlement, and static-template validation microsteps advance only under their
reserved control clock and may do so while a lane is held. A lane boundary does
not gate control progress, but its next advance must satisfy the exact
lane/control quota inequality in the live `ClockBridgeCertificate`. This is a
bounded service relation, not an assumption that weak fairness implies a turn
bound. Disjoint lane/work shards do not share a progress barrier. Linux actions
are stuttering with respect to all trusted clocks.

The formal weak-fairness set is exact: continuously enabled
`ControlTurn[shard]`, `LaneBoundaryAdvance[lane]`, trusted countdown/stop, and
typed receipt actions receive `WF`; no Linux, per-request, or target-specific
picker action does. The deterministic frame and lane/control guard turn those
component actions into target service. Strong fairness is not used to conceal
an intermittently enabled target.

Cleanup and renewal service are partitioned by provenance. Safety/revoke
cleanup, guaranteed cleanup, projection renewal, and best-effort cleanup cannot
consume each other's reserved cells. Best-effort acceptance reserves and
rate-limits its worst-case forward and cleanup work before any side effect.

Monitor entry dispatch has a preemptible ingress gate. When a protected frame
cell is due, Linux-originated ingress is rejected or left in its already
bounded mailbox after fixed dispatch work; an infinite sequence of individually
bounded calls cannot execute ahead of the owed protected turn. Linux cannot
mask or retime this gate.

Strict priority alone is insufficient because an unbounded higher-priority
recovery stream can starve guaranteed service. The normal-mode service policy
must reserve finite service for each protected class. A separately declared
catastrophic/emergency mode may suspend ordinary guarantees, but entering it
is an authoritative failure transition and not a hidden priority side effect.

`NodeMode` is Monitor-owned and typed:

```text
Normal
PlannedMaintenance
DegradedExternalFailure
EmergencySafety
FailStop
```

`NodeMode` is a coarse node aggregate, not the predicate that discharges every
contract. Each admitted stream has a derived `ContractOperationalState` from
its immutable `SecurityDependencyCertificate` and current per-scope incident/
fence cells:

```text
Operational
PlannedMaintenanceAffected
DegradedAffected
EmergencyStopped
FailStopped
```

`PlannedMaintenance` requires a precommitted transition witness and maintenance
interval in every affected contract. `DegradedExternalFailure` requires an
explicit Monitor/hardware receipt for a declared CPU, memory, timer, freshness,
or reference-release failure. The Monitor derives at most
the total `CanonicalFailureCover`: an exact vector within
`KFailureScopesPerEvent`, the unique lowest common ancestor in the boot-fixed
`FailureCoverTree`, or node fail-stop.
A receipt does not name victims. It fences the selected scopes once and
does not materialize or lock an O(number of dependent Domains) affected-
contract list. Each stream evaluates its already bounded certificate lazily,
and management enumeration is asynchronous observation outside the authority
point.
`EmergencySafety` requires an objective architecture fault receipt demanding
immediate stop. `FailStop` is the only response to a software invariant breach
such as reserved-guaranteed overflow; the safe model treats that breach as a
counterexample, not as permission to relabel it hardware degradation.

Every non-Normal scoped transition records cause, exact affected scope
identities, pending-obligation disposition, entry lane/timebase state, and the
typed recovery rule. `NodeModeSummary` is a lazy observation over authoritative
scope cells; it has no writer and no authority generation. The baseline safe-
liveness configuration sets all external failure guards false. A second
required covered-failure configuration injects one disjoint scoped failure and
proves `FailureCannotWeakenUnaffectedContract`. An affected stream cannot
satisfy recurring service by cancellation, withdrawal, degradation,
emergency, or fail-stop.

Failure identity is structured; no digest is allowed to stand in for its typed
fields:

```text
FailureSourceIdentity
  authenticated source authority/channel
  source resource type, resource identity, and source incarnation
  full source-failure ScopedNamespaceRoot
  SourceFailureNamespaceEpoch and SourceFailureClockEpoch

FailureSourceEvidence
  exact FailureSourceIdentity
  SourceFailureSequence or exact one-use Monitor challenge generation
  typed cause and source state
  observed architecture incarnation tuple
  canonical evidence bytes digest, source seal, and verification algorithm ID

FailureScopeIdentity
  FailureScopeType, canonical owner identity, owner incarnation
  full ScopedNamespaceRoot, FailureScopeNamespaceEpoch

FailureEventID
  (MonitorBootEpoch, ScopeTransitionNamespaceEpoch, ScopeTransitionSequence,
   exact FailureSourceIdentity, exact source sequence/challenge,
   canonical bounded FailureScopeIdentity vector and transition digest)

SecurityScopeFence
  exact FailureEventID and FailureScopeIdentity
  predecessor/successor FailureScopeGeneration
  fence class, authority disposition, and recovery/issuer-clear policy

RecoveryReceipt
  exact affected FailureScopeIdentity/current-generation vector
  exact active-fence digest and topology/incarnation snapshot
  recovery action digest, quiescence receipts, and issuer authorization class
```

The v1 authority protocol has four independently owned state families:

```text
SourceReplayCell[source]                    -- source-shard writer only
  terminalHighWater
  pending = None | DurablePending(source sequence, evidence digest,
                                  normalized evidence, canonical scope vector,
                                  precharged transaction slot identity)
  bounded terminal tombstones and SourceReplayGeneration

ScopeTransitionTxn[txn]                    -- transaction-shard writer only
  kind = Failure | Recovery
  phase = Allocated | Reserving | Sealed | Prepared | Materialized | Recyclable
  decision = Open | Committed | AbortedNeutral | AbortedCovered
  canonical bounded scope vector and predecessor/successor cells
  decision = Committed                      -- sole semantic linearization
  immutable AuthorityAuditOutbox and AuthorityRetireReceipt state

ScopeAuthorityCell[scope]                  -- scope-shard writer only
  current generation and current fence set
  slot = None | Reserved(txn)
              | Prepared(txn, predecessor generation, successor generation/fences)

SecurityAuditShard[event] = Absent
  | DurablePending(position, previous head, event digest)
  | Appended(AuditReceipt)
  | Checkpointed(checkpoint)                -- audit-shard writer only
AuditReceipt[txn]                          -- audit-shard writer only
CheckpointAggregate                        -- asynchronous observation only
```

`PersistPending` authenticates `FailureSourceEvidence`, classifies replay,
derives the total `CanonicalFailureCover` result, and consumes the precharged
transaction/scope/audit or node-fail-stop entitlement named by its exact
`FailureCoverCertificate`. Its sole durable write changes
that source's cell from `None` to a self-contained `DurablePending`. The record
contains enough normalized authenticated evidence, cover derivation, identity, and
reserved slot information for recovery to finish without source retransmission
or an existing transaction record. It does **not** advance
`terminalHighWater` or change authority.

`BuildTxn` is the transaction-shard-only creation of the exact precharged slot
named by `DurablePending`. `ReserveScope` installs `Reserved(txn)` in canonical
order. After all reservations are present, `SealTxn` freezes every exact
predecessor/successor, `FailureEventID`, and outbox. `PrepareScope` replaces its
exact reservation with the sealed preparation. Overlapping transitions
serialize on the one scope slot; disjoint transitions commute. Reservation,
seal, and preparation change no effective authority.

Strict replay lookup prioritizes exact pending and tombstone matches. The same
pending sequence and digest resumes; the same identity with a different digest
invokes the pre-reserved source-health fence; a sequence at or below terminal
high-water is stale; exactly high-water plus one with no pending record is
fresh; a gap, second pending sequence, or arithmetic overflow is fail-closed.

`CommitScopeTransition` is the transaction owner's one-way
`decision: Open -> Committed`; it is permitted only after every named scope
contains the exact preparation and all precommit stop/quiescence guards hold.
This single bit is the authority linearization point for the whole bounded
scope vector. For every scope:

```text
EffectiveScope(scope) =
  slot.successor, if slot = Prepared(txn, ...) and txn.decision = Committed
  current,        otherwise
```

Every release, hold, activation, token check, and recovery reads
`EffectiveScope`, never raw `current`; check and use serialize against the
commit action. `MaterializeScope` is a scope-owner-only
representation fold that copies a committed successor to `current` and clears
the prepared reference; it cannot change effective authority. Once committed,
the source owner may advance `terminalHighWater`, clear its exact pending cell,
and retain the bounded stale/idempotence tombstone. Reordering this finalization
before commit is forbidden. `AbortTxn` may clear a recovery transaction that
has changed no authority, or a failure transaction only after a separately
committed permanent fence covers every named scope. It records
`AbortedNeutral` or `AbortedCovered`; stale predecessors cannot leave an
unfinishable valid failure occupying protected state forever.

The immutable `AuthorityAuditOutbox` is a pure function of the sealed committed
transaction. `AuditReserve` durably assigns exactly one position and previous
head to an event; retry reuses that event/position. `AuditCommit` atomically
appends the chain entry and receipt. Checkpoint aggregation observes receipts
asynchronously. Authority fencing never waits for an audit append, and audit
order is excluded from `FailureEventID` and authority commutation. A stalled or
full audit shard withdraws only the liveness envelope that depended on its
headroom and eventually enters its pre-reserved audit fail-stop path; it cannot
undo a committed fence. `CheckpointAggregate` may serialize reporting but
cannot gate execution, rename an event, clear a scope, or update authority.

Recovery uses the same prepare/commit/materialize protocol in a fresh
`ScopeTransitionTxn(kind = Recovery)`. Its predecessor binds only the affected
effective generations, exact fence set, topology incarnation, and typed
quiescence/issuer receipts. An unrelated scope or audit checkpoint cannot stale
it; a new affected transition does. Recovery advances generations and removes
only fences whose policy the receipt satisfies. It never rolls a generation
back. Before commit, predecessor tokens are stopped and holds are settled or
rebound. Consequently an old `SecurityUseVector` cannot become current when a
recoverable fence clears.

Source namespace/freshness exhaustion is itself a protected transition over a
canonical `SourceHealthScope`. It commits a permanent
`SourceUnavailableFence` through a pre-reserved emergency transaction whose
identity and capacity do not come from the exhausted namespace; it is not
merely an ingress rejection. Source health is derived only from
`EffectiveScope(SourceHealthScope)`, never duplicated as an independently
writable field in `SourceReplayCell`. Every
`SecurityDependencyCertificate` whose continuing validity depends on that
source includes the corresponding source-health scope. Omission is allowed
only when an independently authenticated coverage certificate proves the
declared alternate-source policy before the live use is created. A live use
cannot switch coverage alternatives after failure or exhaustion.
This prevents sequence exhaustion from leaving dependent authority executable.

`CanonicalFailureCover(event)` is total for every authenticated real failure.
`NodeConfig` contains a boot-fixed rooted `FailureCoverTree` with one parent per
node, a stable total node order, and one leaf mapping per dependency scope.
`FailureSourceEvidence` freezes the source-time topology generation. Processing
computes the conservative union of that source-time closure, the current
topology closure, and every intermediate topology generation still named by a
live reverse-indexed authority use in the candidate impact closure. This last
term matters after repeated reparenting: source/current alone could omit an
authority that remains bound to an intermediate path. If the union size is
within `KFailureScopesPerEvent`, that exact vector is used. Otherwise its
unique lowest common ancestor in the cover tree is selected. Selecting the
root, inability to authenticate any required topology generation, inability
to enumerate the precharged live references, or inability to represent a
sound result selects the pre-reserved node fail-stop successor. A real event
is never truncated, rejected while authority continues, or left to stutter
because its exact closure is too large. `FailureCoverCertificate` records all
source/current/live-referenced topology generations, the union closure or
unique-LCA derivation, chosen vector or node-stop result, and checked bound.

At the transaction commit bit, every selected cover's resource charge moves
atomically from `Current`, `Pending`, or `Retiring` into exact
`FailureEscrow`, without duplication, before the successor fence becomes
effective. Cleanup releases that escrow only after the covered effects are
terminal. "Unaffected" means outside the selected cover and outside node
fail-stop; choosing a covering ancestor may intentionally stop siblings inside
that cover and node fail-stop withdraws all lane noninterference claims.

All failure resources are partitioned and bounded. Admission of each live
authority use consumes one reverse-edge slot from
`MaxLiveAuthorityUses[scope]` for every scope in its security certificate and
reserves the corresponding `ScopeCleanupReservation`. Publication is rejected
before authority exists if either charge is unavailable. Scope or transaction
capacity exhaustion consumes a pre-reserved permanent fail-stop successor for
the exact covering scope; source-state exhaustion consumes the source-health
successor. Neither borrows a disjoint scope's storage.

Authority processing is `O(m * KDepth)` for bounded cover size `m` and never
scans Domain population. Cleanup follows only charged reverse edges and is
bounded by the admitted actual-use cap; each step owns protected cleanup
service. Recovery may commit only after predecessor-use count is zero or every
remaining predecessor is covered by a permanent non-executable fence. Reverse-
edge overflow or conservation mismatch is an invariant breach and commits node
fail-stop; it is never ignored. Cleanup remains incremental, but its total rank
and capacity are now explicit rather than an unbounded deferred traversal.

Event detail or a transaction slot is recyclable only after all scope
reserved/prepared and authority-reader references are gone,
the transaction shard has issued an exact `AuthorityRetireReceipt`,
all lane apply/recovery references are terminal,
the source terminal high-water/tombstone covers it, its
outbox is terminal, an `AuditReceipt` and authenticated checkpoint cover both
failure and any recovery, the exact reconciliation acknowledgement covers that
checkpoint, no recovery references it, and the recycled slot advances its full
namespace/generation identity. Failure of any predicate retains the record or
uses the pre-reserved fail-stop path; it never aliases a new event.

The crash matrix is normative:

```text
before DurablePending
  retry is fresh and no durable effect exists
after DurablePending before BuildTxn
  RecoveryOnly builds the exact named precharged transaction
after partial reservation/preparation
  predecessor authority remains; resume or commit a covering permanent fence
after all preparation before commit
  every scope remains predecessor
after commit before partial materialization/source finalization
  every scope is already successor through EffectiveScope
after source finalization before audit
  replay is terminal/stale and the outbox remains independently deliverable
after audit position reservation or append
  retry finishes the same position and never allocates another
after AuthorityRetireReceipt before free
  retain the old slot; after free only the fresh full generation is valid
```

Restart enters `RecoveryOnly` and reconstructs authority only from protected
source, transaction, and scope state, never Linux, a summary root, or audit
completion. `Ordinary` mode additionally requires no unresolved pending ingress,
consistent committed/materialized authority, exact reconciliation and dirty
arm, fresh boot-bound leases, and an explicit mapping or issuer acknowledgement
for every old-boot fence.

Recurring liveness never assumes an infinite finite audit log. Each claimed
`StableWindow` carries an `AuditHeadroomWindow` covering the admitted maximum
unrelated-failure events and required shard checkpoint/renewal actions during
that interval. Longer recurrence uses induction over authenticated checkpoint
renewal. Without it, only safety and eventual scoped fail-stop are claimed.

Best-effort ingress requires:

```text
caller attribution from active Monitor authority
fixed maximum parsing and validation work
direct bounded lookup through a sealed local handle or equivalent
per-principal or tenant work credits
fixed mailbox/operation-state capacity
no allocation, global task scan, all-rq scan, drain, or renewal on malformed
or stale input
bounded replacement candidate examination
```

A best-effort request cannot initiate a drain of a running, held, or
trusted-referenced victim. If no immediately replaceable binding exists, it is
rejected. Guaranteed work may initiate a bounded drain because its admission
witness already reserved that work and the victim root lease/reference release
has a declared bound.

Continuous attacker hint churn may keep best-effort availability false. It
must not increase guaranteed queue depth, reset guaranteed age/debt, occupy a
guaranteed operation cell, or add work to the guaranteed transition bound.

Authenticated control-plane work is also finite. Each authority has bounded
candidate-operation credits, one successor candidate per affected lineage in
the reference, and an explicit control-work reservation. Duplicate compatible
input never mutates an accepted candidate. A duplicate valid submission is
only a retransmission of the same immutable `ControlOpID` and digest; a distinct
update must use a fresh ID and is rejected busy while the bounded successor
cell is occupied. No update can mutate the active plan or reset its debt.
Operations are never accepted without a terminal progress obligation.
Candidate-plan construction and verification cannot consume protected
root-expiry or guaranteed-residency turns.

Dynamic-control availability uses a separate finite arbitration contract. The
node admits a bounded `ControlPrincipalSet`; a principal with a guaranteed
control reservation has one protected immutable ticket slot. Occupied slots
are linked exactly once into a Monitor-owned sparse nonempty ring on
`Empty -> Occupied` and removed exactly once on terminal `Occupied -> Empty`.
The cursor selects its successor in `O(1)` without scanning empty principal
IDs; insertion cannot move the cursor behind a continuously occupied older
member. Ring integrity is protected state and corruption is fail-stop.
`RejectedControlBusy`
means that principal's own slot is occupied or the caller has no reserved
control class, not that another principal captured a single global mailbox.
`AdmissionControl` cells first service cleanup owed by an accepted operation,
then select the next nonempty principal slot with a Monitor-owned round-robin
cursor per control shard. One candidate commits at a time **per intersecting
mutation footprint**; disjoint shard commits commute. A bounded multi-shard
operation acquires its declared shard set in canonical order and cannot expand
it after acceptance. Every selected operation has a finite
prepare/retire/terminal rank before that cursor advances. Thus infinite valid churn from one delegated principal cannot starve
another admitted guaranteed-control principal. Availability for arbitrary or
unadmitted management callers under overload is not claimed.

## Control-Work Conservation

`ResidencyWorkReservation` is a Monitor-internal DoS and cost entitlement. It
is not a RunCap, root CPU budget, resident binding, or permission to activate.

Before an accepted operation can start side effects, the Monitor reserves a
declared component-wise upper bound for its prepare, drain, install,
cancellation, and cleanup path. State cells, executable work units, cumulative
charges, root reservations, execution-cell leases, token budgets, and delivered
ticks have different units and are never added together. The v1 reference has
no generic accounting-epoch refill:

```text
WorkUnitCapacity[k]
  = FreeWorkUnits[k]
  + ReservedWorkUnits[k]
  + ExecutingWorkUnits[k]

OperationRecordCapacity[k]
  = FreeRecords[k]
  + NonterminalRecords[k]
  + RetainedTerminalRecords[k]

RootReservationCapacity[lane]
  = FreeRootReservation[lane]
  + CandidateRootReservation[lane]
  + CommittedPendingPlanRootReservation[lane]
  + CurrentPlanRootReservation[lane]
  + RetiringPlanRootReservation[lane]

NamespacePublicationCapacity[root]
  = UnassignedPublicationHeadroom[root]
  + ReservedManagementPublication[root]
  + ReservedGuaranteedPublication[root]
  + ReservedRenewalPublication[root]
  + ReservedBestEffortSponsorPublication[root]
  + ConsumedNonreusablePublication[root]

ProtectedServiceFrameCapacity[node]
  = EmergencySlots[node]
  + ManagementSlots[node]
  + LocalProtectedSlots[node]
  + SUM child in Children[node] : ChildReservedSlots[node, child]
  + SlackSlots[node]

RootExecutionFrameCapacity[pool]
  = ManagementExecutionCells[pool]
  + EmergencyStopExecutionCells[pool]
  + SUM lane in Children[pool] : LaneExecutionCells[pool, lane]
  + SlackExecutionCells[pool]

HardwareFrameCapacity[context]
  = ProtectedControlCells[context]
  + DomainExecutionCells[context]
  + ManagementCells[context]
  + EmergencyCells[context]
  + SlackCells[context]

ScheduledExecutionCells
  = UnreservedFuture + IntentReservedFuture + ActiveCurrent
  + ExpiredUnused + SettledConsumed

CellDuration
  = EntryExitGuardBudget + ReservedTokenBudget + UnusedCellBudget

all terms are non-negative, disjoint, and Monitor-owned
```

`ProtectedServiceFrameCapacity` is physical dispatcher capacity, not a sum of
virtual shard rates. Every `ControlServiceReservation` owns one exact root-to-
leaf path, exact parent schedule generations, positive child occurrences, and
the residual-capacity debit at every node on that path. Publication validates
the equation and literal occurrence count simultaneously for all live child
reservations. One real `ProtectedServiceStep` consumes one scheduled physical
opportunity and advances at most one selected descendant `ControlTurn`; a
single entry cannot satisfy two shards. The two-lane witness must contain two
simultaneously live control shards under one parent and demonstrate distinct
owned occurrences, so independently valid leaf certificates cannot overbook a
shared executor.

`HardwareFrameCapacity` is mandatory whenever protected control and Domain
execution share a physical context; separate frame roots require disjoint
hardware identities. `RootExecutionFrameCapacity` applies the same root-to-leaf ownership and exact-
occurrence rule to physical CPU execution. Current, committed-pending,
retiring, failure-escrow, and management allocations must all be simultaneously
represented in one parent equation. Intent preparation moves one future cell
to `IntentReservedFuture` but consumes no physical opportunity. At the exact
due turn, one cell can consume at most one `ExecutionCellLease`, intent, and
token; cell end moves it to one terminal state and forces handoff. A lane rate
without the exact parent debit is not a feasibility witness.

Namespace publication capacity is wear, not recyclable work. Publishing a
plan epoch, slot generation, activation, or other registered generation moves
one exact sponsor reservation to `ConsumedNonreusablePublication`; settlement
does not return it inside the same root incarnation. Candidate rejection and
malformed ingress consume none. Best-effort publication is rejected before it
can spend management, guaranteed, or renewal headroom. Admission reserves the
worst-case publication and renewal budget needed over its certified lease
horizon, including shared projection/plan effects. Crossing a shared renewal
threshold that can pause another contract additionally requires that
contract's precommitted maintenance/failover witness. One tenant can therefore
exhaust only its sponsor allowance, not deliberately wear a shared CPU lane or
plan shard to permanent shutdown while another guarantee depends on it.

Starting a step moves its exact units from `ReservedWorkUnits` to
`ExecutingWorkUnits`; units return to their original owner only after that
step's effects settle. Best-effort/control units then return to the same finite
pool. A recurring guaranteed stream's unused or completed units return to its
dedicated recurring reservation and cannot become best-effort slack until a
plan transition explicitly removes that contract. There is no rollover action
that creates a fresh capacity total while old work remains.

Control commit transfers each exact candidate reservation to
`CommittedPendingPlanRootReservation`; it is never temporarily ownerless.
Local apply atomically transfers the successor share to current and the
predecessor/open-opportunity share to retiring. `FailedFenced` transfers the
entry to its charged failure/cleanup owner until settlement. Every transfer is
per shard and preserves the equation.

An active token is not another root-capacity summand. It names exactly one
current or retiring root reservation, and its token equation remains
`issuedBudget = consumedBudget + remainingBudget`. Candidate commit transfers
already reserved ownership into current/retiring partitions; old residual
budget remains attributed to the retiring partition until expiry/stop. A
candidate, current plan, retiring plan, and active residual can therefore
never charge the same root reservation twice.

`ChargedWork[principal, class]` is a separate monotonic audit/cost ledger with
bounded checkpoint/watermark rollover; changing it cannot free a work unit or
mint execution authority. Terminal operation records remain occupied until the
bounded replay/tombstone watermark permits deterministic garbage collection.

Every accepted side effect records immutable `CleanupClass`. Rollback of an
original best-effort, guaranteed, or control operation uses its pre-reserved
class even if revoke triggers it; revoke's additional authority fence/unmap
work uses `SafetyCleanup`. Reclassification cannot steal another lane.
`AdmissionControl` reserves worst-case abort/failed-candidate cleanup and
services that cleanup before preparing another ticket.

The remaining conservation rules are mandatory:

```text
retry or retransmission does not reserve a second copy of the same operation
coalescing does not mint work units
one member cannot spend or refund another member's charge
CancelAccepted does not refund work required for cleanup
rejection before side effects leaves no committed-work leak
stale completion cannot settle or free units owned by a newer WorkID
unused guaranteed worst-case work returns to its stream reservation only after
terminal settlement
best-effort work is charged to its authenticated principal or sponsor
mandatory cleanup has reserved service even after the caller loses authority
```

Guaranteed contracts reserve worst-case recurring work in their feasibility
witness. Best-effort admission and control operations reserve from separate
finite pools before acceptance. A malformed ingress rejection consumes only
its fixed ingress allowance and cannot trigger a downstream reservation.

## Overflow and Typed Outcomes

Overflow never overwrites an older operation, falls back to Linux authority,
or silently drops a guaranteed obligation.

Submission responses are distinct from operation phase, cancel response,
terminal disposition, and `NodeMode`:

```text
SubmissionResponse
  Accepted
  AcceptedAlreadyResident
  DuplicateSameIntent
  CoalescedExactPhysicalWork
  RejectedMalformed
  RejectedStale
  RejectedEquivocation
  RejectedUnadmitted
  RejectedNoCredit
  RejectedBestEffortOverflow
  RejectedNoImmediateVictim
  RejectedAdmissionInfeasible
  RejectedDirectoryCapacity
  RejectedControlBusy

ControlTerminalDisposition
  Committed
  RejectedInvalid
  RejectedInfeasible
  RejectedConflict
  RejectedStaleSnapshot
  RejectedBuilderTimeout
  Cancelled

OperationPhase
  Submitted, Reserved, WaitingForDrain, Installing, HeldReady,
  Activated, CancelPending, StopPending, Cleanup, Settling, Terminal

CancelResponse
  as defined by the cancellation linearization table

RequestTerminalDisposition
  as defined by the opportunity and cancellation contracts
```

Best-effort overflow is a bounded rejection. Admission/control overflow rejects
the candidate and leaves current authority unchanged. Overflow of a reserved
guaranteed request cell is not a normal runtime outcome; it is an invariant
violation. The formal safe model fails on it; a production Monitor enters
`FailStop`, preserves evidence, and retains only its independently defined
recovery path. A separately observed hardware failure may enter guarded
`DegradedExternalFailure`, but cannot excuse software overflow.

## Resident Transaction and Replacement

The accepted finite binding semantics remain authoritative, but transaction
progress and published slot state are orthogonal. Reserving a transaction must
not overwrite an old binding that is still published.

```text
txnPhase
  None
    -> Reserved(WorkID, old binding identity, expected next generation)
    -> WaitingForDrain, when required
    -> Installing(PhysicalKey)
    -> AwaitingActivation(ConsumerKey)
    -> Cleanup, when cancelled/aborted
    -> Settled

publishedSlotState
  Empty
  Resident(exact BindingID)
  Draining(exact old BindingID, no new activation)
  Held(exact new BindingID, immutable SealedMemberSet and
       SealedMembershipGeneration, current MemberDisposition vector and
       DispositionGeneration)
```

A slot reservation records the current `ProjectionEpoch`, `CpuIncarnation`,
old BindingID/generation, expected next generation, and `WorkID` separately
from `publishedSlotState`. While draining, the old exact binding remains
visible but cannot activate. It becomes `Empty` only after modeled trusted
references reach zero and the required abstract quiescence receipt exists.

Installation publishes a fully sealed new `Held` binding atomically; no
partially initialized binding is visible. A stale worker cannot complete a new
transaction. Held state binds immutable complete membership plus current
Monitor-owned disposition, not a bare sequence, and cannot be stolen by
best-effort replacement. Exact activation names one member whose current
disposition is `Active`; the first guaranteed reference always has a singleton
set. Per-member cancellation cannot release a hold still needed by another
derived survivor. Whole-transaction cancellation enters cleanup and releases
the hold only at its deterministic settlement point.

Replacement uses Monitor-owned bounded state. Linux locality may rank an
already safe candidate set but cannot choose the final victim. Running, held,
trusted-referenced, management, recovery, or non-settled bindings are not
replaceable.

The Monitor needs a bounded authoritative way to enumerate every local replica
of a Domain during revoke and descriptor change. A preallocated reverse link
per physical slot and a canonical bounded owner/shard are viable refinement
candidates. The semantic requirement is exact bounded enumeration without a
global Linux task/rq scan; the data structure is not selected here. Admission
fixes `MaxReplicasPerDomain` and reserves its cleanup bound. Authority stop uses
the Domain/local fence and active-lane hardware path without waiting for this
enumeration; physical reclamation is O(actual replicas) but bounded by the
admitted maximum and cannot consume another Domain's cleanup reserve.

## Linux Lifetime Is Not Trusted Quiescence

Linux RCU, `refcount_t`, task lifetime, rq locks, and workqueue ownership remain
necessary for Linux memory safety and compatibility. They do not prove that a
root token, nested privileged entry, DMA use, physical backing reference, or
Monitor operation has drained.

The ownership split is:

```text
Linux lifetime
  prevents a Linux shadow object from being freed while Linux still uses it

Monitor trusted reference
  prevents authority binding or protected backing from being reused while a
  Monitor/hardware-visible use can still complete
```

An RCU grace period does not by itself drain later readers or hardware state.
A saturated Linux refcount may conservatively leak a shadow object. Neither
event may pin an authoritative resident slot forever or authorize reuse. Linux
shadow state must instead be generation-discardable, Domain-private, or
unmapped/retyped after the later trusted backing and translation fence.

The dynamic invariants therefore include:

```text
LinuxReferenceCannotMintOrExtendAuthority
LinuxReferenceCannotVetoTrustedRetirement
RcuGraceIsNotTrustedHardwareQuiescence
TrustedReuseRequiresMonitorAndArchitectureReceipts
```

## Common Namespace-Renewal Algebra

Slot reuse is only one ABA surface. Every finite implementation counter has a
declared enclosing incarnation and the same fail-closed rule:

| Finite sequence | Enclosing freshness namespace | Renewal prerequisite |
| --- | --- | --- |
| `ClusterIssuerIncarnation` | external issuer anti-rollback/signing root | node accepts only authenticated monotonic successor; old issuer signatures remain stale |
| `DomainEpoch` | exact `ClusterIssuerIncarnation` and issuer-owned `GlobalAuthorityEpoch` | only global issuer or explicitly delegated authority may advance; node stores a rejection fence |
| `LocalAuthorityGeneration`, `LocalLeaseFenceGeneration` | exact Domain/admission local fence root inside `MonitorBootEpoch` | old uses stop/settle; never changes issuer epoch or reopens a fence |
| `NodeLeaseEpoch` | exact `ClusterIssuerIncarnation` and NodeLeaseID | node cannot replace or expand remote authority locally; local rejection fence carries forward |
| `LeaseTermGeneration` | `NodeLeaseEpoch`, then cluster issuer incarnation | old term/token expires or settles; renewal is issuer-authenticated and cannot expand the epoch's rights envelope |
| `AdmissionGeneration` | `AdmissionIncarnation`, then `MonitorBootEpoch` | current/retiring admission artifacts settle or map explicitly to successor |
| `ResidencyDescriptorGeneration` | `DescriptorIncarnation`, then `AdmissionIncarnation` | all descriptor-bound holds/bindings/tokens settle or move by an exact successor mapping |
| `ServiceContractGeneration` | `ServiceStreamIncarnation` | old contract-bound obligations settle; a successor record transfers debt and next due |
| `OpportunitySequence` | `ServiceStreamIncarnation` | stop release, settle the old current opportunity/token, then transfer debt/next due; never relabel a live artifact |
| `RootPlanEpoch`, `PlanMembershipGeneration` | per-`PlanShardID` `PlanNamespaceEpoch` | that shard's current/retiring plans and all plan-bound tokens/holds settle |
| `ResidencyRequestSequence` | `RequestNamespaceEpoch` | no old request can complete; bounded replay watermark is retired |
| `CancelOpSequence` | `CancelNamespaceEpoch` | no old cancel can affect an active request; watermark is retired |
| `ControlOpSequence` | `ControlNamespaceEpoch` | accepted control operations and receipts settle |
| `WorkSequence` | `WorkNamespaceEpoch` | every old worker/completion is fenced or settled |
| `SourceFailureSequence` | source-owned `SourceFailureNamespaceEpoch` and exact source incarnation/channel root | authenticated high-water or challenge state makes replay stale before Monitor event allocation |
| `FailureEventSequence`, `FailureScopeGeneration` | `FailureNamespaceEpoch` and source/affected resource incarnations | event remains retained or acknowledged below scoped high-water; never discard on wrap or advance an unrelated scope |
| `ActivationGeneration` | `ActivationNamespaceEpoch`, then `CpuIncarnation` | active token expires/stops and activation receipts settle |
| `SlotGeneration` | `ProjectionEpoch`, then `CpuIncarnation` | projection stops accepting and every old binding/receipt/reference settles |
| `PlacementGeneration` | `PlacementIncarnation`, then `AdmissionIncarnation` | source authority stops and exclusive placement references settle |
| `ServiceOpportunityTurn` | exact protected-service-pool `ServiceOpportunityClockEpoch` | stop new guarantees on that pool, settle or permanently fence live component certificates, then offline only that pool for the boot |
| `HardwareProgressGeneration` | exact service-opportunity and lease-clock epochs | retain live hardware-progress certificates; successor cannot weaken a live admitted envelope |
| `ServiceAllocationGeneration` | exact protected-service pool and schedule path | transfer only fully reserved parent/child slots; live target anchors retain their predecessor allocation |
| `LaneTurn` | per-lane `LaneClockEpoch` | stop new releases, settle/fence exact deadlines, successor-map calendars, or offline that lane |
| `ControlTurn` | `ControlClockEpoch` for one provenance shard | settle accepted work, advance only that shard, or quarantine it |
| `LeaseTick` | hardware/Monitor `LeaseClockEpoch` | no modular comparison across epochs; tokens stop and a fresh trusted timebase is authorized independently |
| `BridgeCertificateGeneration` | exact hardware-progress, service-allocation, and target-quota component identities | retain all live bundles; successor rebase proves every component predecessor relation and cannot weaken bounds |
| `SecurityLogSequence` | per-audit-shard `SecurityLogNamespaceEpoch` | durable external checkpoint acknowledgement, no unlogged cell members, then shard-local renewal |
| `NodeSecurityEpoch` | protected non-rollback security checkpoint root | authenticated checkpoint over scoped cells/audit-shard heads; advance alone is not an authority fence |
| `ReconciledEpoch` | `MonitorBootEpoch`, then `BootFreshnessRoot` | exact issuer acknowledgement CAS records `reconciledThroughNodeSecurityEpoch` with all ordinary execution stopped |
| `DirtyArmGeneration` | current `(MonitorBootEpoch, ReconciledEpoch)` and its reconciled-through checkpoint | exact arm/clean-shutdown CAS; later unrelated security-log append does not invalidate it |
| `MonitorBootEpoch` | `BootFreshnessRoot` plus current `NodeSecurityEpoch` | all old execution contexts stop and fresh boot/security-bound leases are re-attested |
| local directory handles | fixed layout inside `MonitorBootEpoch` in v1 | no live layout renewal; restart fences every direct handle |
| all node-local namespaces | `MonitorBootEpoch` | complete node/hardware quiescence and authenticated reimport |

For each row:

```text
near saturation blocks allocation before wrap
new publication in the old namespace stops
old effects and late completions are drained or made permanently ineffectual
the enclosing incarnation advances without rollback or collision
state is rebuilt from Monitor or authenticated authority, never Linux shadow
only then may the inner sequence restart
```

Debt, charge, and unsettled effects cross renewal by an explicit successor
mapping; renewal is not an accounting reset. If an enclosing namespace cannot
advance safely, that scope remains quarantined or fail-stop.

Namespace ownership and exhaustion scope are also explicit:

| Namespace | Allocator / scope | Hostile jump rule |
| --- | --- | --- |
| guaranteed request/opportunity | Monitor, per service stream | Linux supplies no sequence |
| best-effort request | authenticated principal/sponsor namespace | accept only next or a fixed replay window; oversized forward jump is rejected without advancing state |
| request cancel | same bounded request-principal scope | cancel ID cannot move request high-water or another principal's namespace |
| control operation | authenticated management channel/delegation scope | bounded next/window rule; no global node watermark jump |
| physical work | Monitor, per provenance lane/shard; best effort is separate from guaranteed/recovery | only accepted and reserved work consumes sequence; one lane cannot exhaust another's namespace |
| plan | Monitor, per plan shard namespace | candidate rejection does not consume an authoritative epoch; one shard cannot block another |
| activation/slot | Monitor, per CPU/projection incarnation | Linux supplies neither generation |
| node configuration/management bootstrap | protected boot root | installed before ordinary admission; Linux and delegated management supply no generation |
| Domain hierarchy | Monitor commit under `NodeConfig` | reparent cannot advance another path or relabel a live old-path use |
| lease import/global placement | authenticated cluster issuer/quorum | node consumes but cannot mint no-fork, ownership, fencing, or quorum epochs |
| root execution/target control | exact protected pool/capacity/dispatch owner | only physical execution or exact target microstep advances its counter |
| failure cover | protected ownership graph | total cover publication or node fail-stop; caller supplies neither closure nor generation |

Every Monitor-allocated local family is rooted in a finite preallocated object:

```text
ScopedNamespaceRoot
  (MonitorBootEpoch, NamespaceClass, OwnerScopeID, RootSlotID,
   RootGeneration)
```

Every textual `XNamespaceEpoch` denotes the full pair
`(ScopedNamespaceRoot, LocalEpoch)`, not a node-global bare integer. Every
derived operation ID repeats or injectively seals the exact owner/root identity.
Equal local epoch/sequence numbers under two channels, work shards, principals,
plans, or failure sources therefore cannot alias.

`OwnerScopeID` is an already admitted Domain/stream/principal/channel,
provenance lane/shard, CPU/projection, or node-control object. The node has a
fixed pool of root slots per class; accepting authority reserves a slot and any
required alternate. `RootGeneration` never wraps. Exhausting an inner epoch
drains it and advances only that root generation. Exhausting the root retires
that slot for the current boot and either uses a pre-reserved alternate or
quarantines that owner scope. It never requests, triggers, or treats a fresh
`MonitorBootEpoch` as attacker-controlled recovery.

The total parent families are:

| Child family | Immediate scoped parent | Terminal local exhaustion |
| --- | --- | --- |
| `AdmissionGeneration` | `AdmissionIncarnation` -> admission root for `(DomainKey, AdmissionSlotID)` | retire admission slot; current contract may continue but no new generation |
| `ResidencyDescriptorGeneration` | `DescriptorIncarnation` -> descriptor root for exact admission | quarantine binding updates; old exact authority remains until its own boundary |
| `ServiceContractGeneration`, `OpportunitySequence` | `ServiceStreamIncarnation` -> stream root | stop new releases, settle old current, successor-map debt/next due, then advance or withdraw |
| `RootPlanEpoch`, `PlanMembershipGeneration` | `PlanNamespaceEpoch` -> exact plan-shard root | current shard plan continues; reject only that shard's commits and alert management |
| `ResidencyRequestSequence` | `RequestNamespaceEpoch` -> guaranteed-stream or best-effort-principal root | quarantine only that request scope; guaranteed root has reserved alternate/headroom |
| `CancelOpSequence` | `CancelNamespaceEpoch` -> request-principal root | reject new cancels in that scope; request authority is unchanged |
| `ControlOpSequence` | `ControlNamespaceEpoch` -> management-channel root | reject that channel's new control tickets; other channels continue |
| `WorkSequence` | `WorkNamespaceEpoch` -> provenance-lane/shard root | stop accepting that lane, drain, then alternate or lane-local quarantine |
| `SourceFailureSequence`, `SourceReplayGeneration`, `SourceHealthGeneration` | `SourceFailureNamespaceEpoch` -> authenticated source/channel/resource root | commit permanent `SourceUnavailableFence` over its canonical source-health scope if freshness cannot renew |
| `ScopeTransitionSequence`, `ScopeTransitionGeneration` | `ScopeTransitionNamespaceEpoch` -> exact protected transaction-shard root | retain or fail-stop the exact transaction/scope; never alias a failure and recovery or reuse an unmaterialized commit |
| `SlotGeneration`, `DrainGeneration` | `ProjectionEpoch` -> projection root for one CPU | projection non-accepting; other CPUs/scopes continue |
| `ProjectionEpoch`, `ActivationNamespaceEpoch` | `CpuIncarnation` -> CPU root | CPU lane remains offline/non-accepting for this boot if no alternate |
| `ActivationIntentGeneration`, `ExecutionContextGeneration`, `ActivationCommitGeneration`, `ActivationGeneration` | exact activation namespace, root-execution allocation, projection/context, and joint-commit roots | stop new intent/commit/token issuance on that CPU; intent alone never executes |
| `PlacementGeneration` | `PlacementIncarnation` -> Domain placement root | stop new placement transfer; current exact owner remains fenced |
| `GlobalPlacementOwnershipEpoch`, `GlobalPlacementFencingToken`, `QuorumEpoch` | authenticated global authority/quorum roots | external fence and retire; local placement cannot substitute or reopen predecessor use |
| `RootExecutionTurn`, `RootExecutionAllocationGeneration` | exact `RootExecutionClockEpoch` physical pool root | execution pool offline or exact allocation fenced; no lane double-spend |
| `TargetControlTurn`, `TargetControlReservationGeneration` | exact control-target reservation under `ControlClockEpoch` | retire/quarantine only that target; another target's turn is not credit |
| `RetirementFenceGeneration` | exact `(AdmissionSnapshot, AuthorityUseID)` retirement root | fail-stop/quarantine that use; never reopen it |
| membership/disposition generations | exact `WorkID` operation root | operation cleanup/fail-stop; never alias another work item |
| `FailureEventSequence`, `FailureScopeGeneration`, and `SecurityScopeFence` identity | source/transaction and resource roots with full FailureScopeIdentity | advance only affected effective scopes; derived aggregate mode and audit checkpoint are not authority; consume the pre-reserved exact-scope fail-stop successor on exhaustion |
| `FailureCoverGeneration` | exact ownership-graph/FailureNamespace/NodeConfig root | exact bounded cover or pre-reserved node fail-stop; never truncate a real failure |
| `SecurityLogSequence`, `AuditReceiptGeneration`, `CheckpointAggregateGeneration` | exact audit-shard/checkpoint roots | require authenticated checkpoint and terminal outbox before recycle; audit exhaustion cannot undo authority and uses its reserved audit fail-stop path |
| `BridgeCertificateGeneration` | exact hardware-progress/service-allocation/target-quota component tuple | retain live predecessors; stop the affected target/service scope if a safe successor cannot be certified |
| `ServiceOpportunityTurn`, `LaneTurn`, `ControlTurn`, `LeaseTick` | their exact pool/lane/shard/timebase clock epochs | scope-local stop/offline; only an independent authorized lifecycle may replace a boot/timebase |
| `ReconciledEpoch` | `MonitorBootEpoch` -> `BootFreshnessRoot`, recording acknowledged `NodeSecurityEpoch` high-water | management/recovery-only fail-stop |
| `DirtyArmGeneration` | exact current reconciled tuple | management/recovery-only until a fresh arm receipt exists |
| `NodeConfigGeneration`, `ManagementBootstrapGeneration` | protected boot root for exact `MonitorBootEpoch` | node fail-stop; ordinary execution cannot replace either |
| `DomainHierarchyGeneration` | exact `NodeConfig`, Domain epoch, and boot root | fence/drain/retire only that path before successor publication |
| `NodeLeaseImportGeneration` | authenticated NodeLease/LeaseClock/boot tuple | stop imported authority and require fresh cluster input; no local extension |
| `MonitorBootEpoch`, `NodeSecurityEpoch` | independent external/protected non-rollback roots | permanent node retirement/fail-stop if required freshness or log high-water cannot advance |
| `LocalAuthorityGeneration`, `LocalLeaseFenceGeneration` | exact Domain/admission local fence roots inside current boot | local permanent fence/fail-stop; never advance issuer identity |
| `ClusterIssuerIncarnation`, `DomainEpoch`, lease IDs/epochs/terms | external/global cluster issuer roots | node cannot allocate or advance them without delegation and exact current issuer incarnation |

`AdmissionID`, `ServiceStreamID`, channel/principal scope IDs, and local slot
IDs are fixed slot identities inside their named root, not freely reusable
integers. `DirectoryLayoutEpoch` is fixed for one boot in v1. The machine-
readable contract enumerates every finite ID/generation as external, fixed-slot,
inner-sequence, enclosing-root, or derived tuple; none is left with an implicit
allocator.

Caller-chosen values are idempotency identities, not allocator commands. A
malicious principal can spend its own accepted operation credits and eventually
force its own bounded namespace to renew or quarantine, but cannot force a
node-wide epoch bump, consume the guaranteed internal request namespace, or
advance another principal's replay watermark. Namespace renewal work is
charged and reserved in that scope before an accepted operation approaches
saturation.

For any namespace root shared by several principals or contracts, operation
credit is insufficient: acceptance also consumes the caller's exact
`NamespacePublicationReservation`. The nonrefundable wear ledger preserves
management, guaranteed, and renewal headroom. A best-effort slot churner cannot
drive `SlotGeneration` to projection renewal, and one delegated planner cannot
wear a shared `RootPlanEpoch` to shard quarantine, unless a preauthorized
cross-contract maintenance/failover witness already covers that effect.

The same confinement applies to failure input. While a scope is fenced, a
duplicate or additional receipt for the already represented cause consumes no
new `FailureEventSequence`, `FailureScopeGeneration`, or
`SecurityLogSequence`. A new audit-shard position for that scope
requires either a genuinely distinct concurrently representable event within
its reserved allowance or an authorized recovery that first made the scope
operational again. Source-receipt freshness is checked before either allocation.
Consequently an executing hostile scope cannot by Linux replay alone drive any
audit root through an unbounded sequence. Event-detail
capacity exhaustion uses its pre-reserved scope quarantine; corruption or
exhaustion of the protected node audit root itself remains an explicit
node-lifetime fail-stop boundary.

Authoritative generations are consumed only at their semantic publication
point: `AdmissionGeneration` and `RootPlanEpoch` at atomic commit,
`SlotGeneration` at sealed binding publication, and `ActivationGeneration` at
token issuance. Candidate preparation uses its `ControlOpID` and digest;
rejection, malformed ingress, or a failed pre-publication attempt cannot burn
an unbounded sequence of authoritative generations. `WorkID` is allocated only
after operation-state and work-credit reservation succeeds.

## ProjectionEpoch Renewal and Generation Exhaustion

No generation wraps into trust. Near saturation, the containing projection is
quarantined before another binding would require reuse:

```text
Saturated or RenewalRequired
  -> accepting = false
  -> block new requests, publications, and activations in that projection
  -> cancel eligible best-effort work; retain guaranteed ObligationID/debt and
     retarget or resume it with a fresh WorkID after renewal
  -> expire or stop active root tokens
  -> drain trusted active, nested-entry, hold, cleanup, and backing references
  -> retire every old binding and invalidate every old receipt
  -> obtain required MemoryView/shadow/translation quiescence receipt
  -> advance to a never-used enclosing ProjectionEpoch or CpuIncarnation
  -> publish an empty protected projection
  -> accepting = true
```

Slot generations may restart only inside a fresh enclosing incarnation. If the
`ProjectionEpoch` space saturates, the CPU or projection renews under a fresh
`CpuIncarnation`. If that CPU root and its reserved alternates saturate, the
lane remains offline/non-accepting for the rest of the current boot. Namespace
exhaustion cannot request or trigger a fresh `MonitorBootEpoch`. A separately
authorized node lifecycle operation may later reboot after complete hardware
quiescence, but it is not the recovery action of the exhausted scope. If the
external boot freshness root cannot advance, the node remains fail-stop or is
permanently retired.

This hierarchy exposes a hard impossibility: finite-width identifiers cannot
provide infinite non-reuse without quiescent enclosing-namespace replacement,
a probabilistic freshness assumption, or eventual permanent retirement.

Renewal work is part of admission feasibility. A real-time contract that
cannot tolerate a renewal pause needs reserved alternate execution capacity or
an explicit maintenance interval. Safety holds while renewal is stalled;
liveness requires Monitor/hardware renewal progress.

A maintenance interval changes the release calendar only through a typed
`MaintenanceSkipRecord` committed before its first covered release. The record
binds the exact stream/incarnation, interval `[start, end)`, old
`nextReleaseTurn`, first skipped ordinal, finite skipped count, successor
`nextReleaseTurn`, and capacity/debt treatment. Commit advances the cursor over
that preauthorized range before equality with a due turn can occur; a boundary
never simply suppresses an exact-due release and increments past it. No already
released opportunity is skipped. The interval cost is included in the maximum
gap, and repeated renewal cannot manufacture a new interval or move the cursor
to evade a stable deadline.

Physical Linux-shadow backing is not made safe by generation comparison.
Unmap/retype, TLB/cache maintenance, entry-stack references, and nested entry
remain `ENTRY-001`, `STATE-001`, and architecture refinement obligations.
`DYN-RENEW-RESTART` can prove only that renewal waits for zero modeled
references plus a typed trusted quiescence receipt. It cannot prove that the
receipt corresponds to physical TLB, backing, or nested-entry quiescence until
those later components discharge the rely.

The typed receipt is not a free `quiesced` Boolean:

```text
QuiescenceReceiptID
  (MonitorBootEpoch, CpuIncarnation, ProjectionEpoch, DrainGeneration,
   QuiescenceNamespaceEpoch)

QuiescenceReceipt
  exact receipt ID, issuer component and seal, drain target object-set digest,
  old BindingID/SlotGeneration set, zero modeled reference summary,
  MemoryView/backing/translation scope, and issuance action
```

`DYN-RENEW-RESTART` permits issuance only for the current drain generation,
after its explicit modeled reference counters and held/active/worker sets are
zero and the typed external countdown/receipt action is enabled. There is
exactly one idempotent receipt identity per drain generation; no independent
finite receipt sequence can wrap or alias. Consumption
requires exact boot/CPU/projection/drain/object-set equality; replay from an old
or different scope is stale. `ENTRY-001` and `STATE-001` must later guarantee
that the issuing action's physical TLB, entry, backing, and translation claims
are true. Here that physical truth is an external component rely, but identity,
replay, scope, and the zero modeled-reference guard are executable state.

## Management and Recovery Bootstrap

Management/recovery progress is not an ambient assumption. Before any ordinary
admission, the protected boot root installs exactly one
`ManagementRecoveryBootstrapContract` binding:

```text
NodeConfig and MonitorBootEpoch
fixed management DomainKey/DomainEpoch and complete hierarchy path
immutable MemoryView, CodeEpoch, entry, translation, backing, and mutable-state roots
exact Management ExecutionContextKey profile and RootExecutionAllocationCertificate
TargetControlReservation, target quota, and protected service-allocation path
TrustedLeaseClock and HardwareProgressCertificate identities
reserved namespace publication, audit, failure, reverse-edge, stop, and cleanup capacity
authenticated issuer/reconciliation/failure channels and their key/policy epochs
closed list of boot, stop, fence, reconcile, audit, renew, and fail-stop actions
ManagementBootstrapGeneration and complete dependency/fence vector
```

Ordinary delegation, plan update, best-effort load, failure cleanup, or namespace
wear cannot debit, revoke, replace, or borrow these resources. The bootstrap
lane still consumes explicitly conserved physical execution and control cells;
it is not free capacity. Its joint activation obeys the same complete context
and receipt rule as any other executable Domain.

Later `MGMT-001`, `ENTRY-001`, `CODE-001`, and `STATE-001` models must prove
authorization, compromise containment, and physical correctness of the bound
objects. Until then this component may rely only on a typed bootstrap import,
not an unexplained statement that management is available. If its boot root,
immutable context, clock, reserved service, or authenticated channel contract
fails, the only result is node fail-stop and withdrawal of recovery liveness;
ordinary execution cannot continue by borrowing a weaker path.

## Monitor Restart Fence

Monitor crash/restart invalidates all volatile node-local state. Recovery is:

The v1 `BootFreshnessRoot` is a protected non-rollback boot incarnation from a
hardware monotonic/persistent root or a cluster-issued fresh node challenge
whose anti-rollback state is protected outside Domain Linux. If neither source
can prove a never-used `MonitorBootEpoch`, ordinary restart cannot resume and
the node remains fail-stop.

To avoid unbounded persistent per-Domain tombstones in v1, restart requires
online fresh lease re-attestation bound to the new `MonitorBootEpoch` and
current non-rollback `ClusterIssuerIncarnation`. An old
still-valid-looking descriptor from Linux storage is insufficient. If the
authority service is partitioned, only the independent management/recovery
path starts; ordinary Domain reimport waits for reconciliation. Partitioned
restart availability is therefore not claimed here.

Fresh boot identity alone does not remember a node-local emergency revoke that
crashed before issuer acknowledgement. The protected root therefore separates
`ReconciliationRequired` for the current restart from `ExecutionDirty` for the
running boot. `ReconciledEpoch` advances only when exact issuer reconciliation
is cleared. `DirtyArmGeneration` is a separate local persistent CAS generation;
arming or clearing it never changes `ReconciledEpoch`. After exact
reconciliation, the Monitor atomically arms `ExecutionDirty` for the exact
`(MonitorBootEpoch, ReconciledEpoch,
reconciledThroughNodeSecurityEpoch)` before requesting a fresh ordinary lease.
An unclean Monitor stop converts that persistent marker into
`ReconciliationRequired` on the next boot. A node-originated security event
first reaches `DurablePending`, prepares every bounded scope successor, and
commits the transaction bit that makes its exact typed fences effective.
Independent audit delivery and authenticated checkpointing may later advance
the protected non-rollback `NodeSecurityEpoch`. A node-scope fence stops all
ordinary authority; a Domain/resource-scope fence does not. Neither the
checkpoint nor a derived node summary is a fence. Source, transaction, scope,
outbox, audit, and receipt shards are admitted protected state with a stable
protected directory; no event synchronously updates a node-global incident
root. Exact issuer acknowledgement may garbage-collect only records satisfying
the complete recycle predicate and cannot clear an effective fence, restart
requirement, or `ReconciledEpoch`.

Fresh leases bind `MonitorBootEpoch`, `ReconciledEpoch`, and its
`reconciledThroughNodeSecurityEpoch` checkpoint. Admission snapshots
additionally bind the exact local `DirtyArmReceipt`; activation requires that
its boot/reconciled/dirty tuple is still current, its exact
`SecurityUseVector` matches every full certified scope identity, generation,
and fence observation, and no relevant
scope fence blocks the use. A later unrelated `NodeSecurityEpoch` high-water
does not invalidate that tuple. Any predecessor-vector token remains stale
after recovery even though a recoverable fence is later cleared.
Issuer-originated revokes remain durable in issuer state; node-originated
revokes require either an authenticated issuer acknowledgement or successful
recovery of the protected authority shards before ordinary reimport. If a
crash or audit failure prevents durable detail after authority commit, the
transaction commit bit and effective scope successors still enforce the typed
stop while the immutable outbox remains pending. If protected transaction or
scope state cannot be recovered, the node is fail-stop; it never guesses the
affected Domain set from audit or Linux. Scope-capacity exhaustion consumes the
pre-reserved permanent scope fail-stop successor, while source freshness
exhaustion commits its `SourceUnavailableFence`; disjoint scopes remain
operational unless their dependency certificates include that source. A clean
transition may clear the restart root only after all Domains are stopped and
all events are acknowledged. This intentionally trades broad restart
availability for fail-closed recovery without an unbounded trusted per-Domain
tombstone table.

Reconciliation clearing has one exact linearization object:

```text
ReconciliationSnapshot
  BootFreshnessRoot generation
  MonitorBootEpoch and NodeSecurityEpoch
  current ReconciledEpoch, reconciledThroughNodeSecurityEpoch, and
  ReconciliationRequired state
  exact protected directory/layout identity
  source-replay, scope-transition, scope-authority, outbox, audit-head, and
  audit-receipt shard root vectors captured after authority writers stop
  exact unacknowledged transition/outbox digest and audit-fault state
  ordinary-Domain execution state = Stopped

IssuerReconciliationAck
  issuer-sealed digest of that complete ReconciliationSnapshot
```

`ClearReconciliation` is an atomic compare-and-swap: the current protected
tuple must equal the acknowledgement byte-for-byte, no ordinary Domain may be
active or admitted, and no event may have arrived after the snapshot. Success
advances `ReconciledEpoch`, checkpoints acknowledged detail, and clears the
current restart requirement. The new reconciled record stores the exact
acknowledged `NodeSecurityEpoch` as `reconciledThroughNodeSecurityEpoch`.
`ArmExecutionDirty` then advances only `DirtyArmGeneration` and returns an exact
`DirtyArmReceipt` for that boot/reconciled/checkpoint tuple. Only a clean
shutdown CAS with every Domain stopped and every event acknowledged may clear
that running marker and advance the dirty-arm generation. Any delayed,
duplicate-after-success, old-boot, old-root, or
lower-high-water acknowledgement is `Stale` and changes nothing. Fresh lease
reimport occurs only after `ArmExecutionDirty` and binds the resulting boot,
reconciled epoch, and reconciled-through-security checkpoint; execution cannot
begin with a different or cleared dirty-arm tuple. Security events accepted
after that checkpoint are evaluated through their scope fences.

```text
stop or reset all node execution contexts and device authority
establish a fresh non-rollback MonitorBootEpoch
read and preserve NodeSecurityEpoch checkpoint high-water plus every protected
source-replay, transition, scope-authority, outbox, audit, and receipt shard
bootstrap the independent management/recovery path
discard all Linux-authored admission, request, binding, and completion state
reconcile local revoke receipts/fences with the issuing authority
atomically clear reconciliation only with an exact current acknowledgement
arm ExecutionDirty for the exact resulting reconciled tuple
obtain fresh online node leases bound to the resulting boot, reconciled epoch,
and reconciled-through-security checkpoint
prepare node-local feasibility candidates without publishing authority
create fresh plans, projections, bindings, and tokens
resume ordinary service only after hardware quiescence receipts
```

Old tokens, receipts, requests, work completions, bindings, CPU incarnations,
and Linux shadows are invalid under the new boot epoch. The Monitor does not
infer whether an old external service effect occurred. At-most-once endpoint
effects across crash require later service/cluster persistent-settlement
semantics; residency only guarantees that an old local activation artifact
cannot become current authority.

## Join, Update, Leave, Revoke, Hotplug, and Migration

### Join and class upgrade

`BestEffort -> Guaranteed` is a new capacity-certified admission generation.
The guarantee begins only at plan commit and includes a first effective
release. Existing resident bindings may remain if their binding-relevant
descriptor is unchanged, but they cannot satisfy a new root opportunity
without current contract validation.

### Demotion and graceful leave

Demotion has an explicit effective plan boundary. Old guaranteed obligations
before that boundary are preserved or explicitly settled. Graceful leave
blocks new work, removes future plan releases, settles pending/held/active
authority, retires bindings, and only then releases capacity and publishes a
tombstone.

### Security revoke

Revoke outranks continued service for the target Domain. It blocks new
obligations and activation, stops bounded active authority, drains all trusted
replicas and work, and records a node-local `LocalRejectFence` plus revoke
receipt. The immediate stop is the committed scope successor and does not wait
for event-detail logging. Failure to deliver detail leaves its protected outbox
pending; failure to recover the authoritative transaction/scope shards leaves
the node fail-stop with `ReconciliationRequired`, so audit loss or restart
cannot revive the revoked authority.
The node first advances its `LocalAuthorityGeneration` and permanently fences
every old local authority-use. It advances `DomainEpoch` only if the global issuer delegated
that authority; otherwise the issuer supplies any fresh epoch during
reconciliation. Within one boot, the fence/tombstone rejects stale replay.
Across restart, v1 requires the fresh online lease re-attestation described
above and refuses reimport while protected reconciliation is owed, so volatile
tombstone loss cannot silently resurrect an old descriptor. Revoke cannot
discharge unrelated guaranteed or management obligations.

### Planned hotplug

Administrative offlining commits only with a transition witness or prechecked
failover plan that preserves all promised contracts. Linux `cpu_online_mask`
cannot authorize the change.

Monitor hotplug has a separate prepare/commit point. Before Monitor commit, a
Linux CPU-hotplug rollback may return to the old authoritative incarnation if
the Monitor never stopped accepting or invalidated it. After Monitor commit,
the old incarnation can never return: any Linux callback rollback, partial
startup, or later online attempt remains non-authoritative until the Monitor
performs a fresh online transaction with a new `CpuIncarnation`. Recursive or
partial Linux hotplug failure therefore leaves the Monitor CPU lane
non-accepting rather than reconstructing authority from Linux callback state.

### Unexpected hardware loss

Safety remains fail-closed. Liveness is guaranteed only for contracts whose
declared failure envelope and reserved redundancy cover the loss. Otherwise
an objective Monitor/hardware failure receipt may move the node to
`DegradedExternalFailure`, reject new guaranteed admission, preserve the
certificate-derived unaffected-contract predicate where feasible, and report rather than hide
the guarantee breach.

### Exclusive migration

Destination capacity and transition work may be reserved first, but authority
does not copy and independent lane boundaries never wait for each other. The
source and destination bind distinct monotonic `GlobalPlacementUse` ownership
epochs and fencing tokens. A local transfer on one node still binds those
fields; a cross-node transfer additionally consumes a cluster-produced
supersession object. The
prevalidated `PlacementTransferRecord` reserves only resource and timing
bounds; it does not freeze a live source calendar. It precommits any required
`MaintenanceSkipRecord` before the first covered due release. The source-local
release gate is installed at a certified boundary, then the existing
`CurrentOpportunity` must reach terminal and clear. Only with
`CurrentOpportunity = None` may source activation stop permanently, root
authority expire, trusted references drain, and the source binding retire.

The one-use `SourcePlacementQuiescenceReceipt` then seals
`(MonitorBootEpoch, PlacementIncarnation/Generation, exact source
PlanMembership/AuthorityUseID and final RetirementFenceGeneration, source
LaneClockEpoch/turn, no-current-opportunity fact, final last-settled ordinal and
disposition, exact last qualifying `ExecutionDeliveryReceipt` and trusted
delivery tick, OpportunitySequence, nextReleaseTurn, debt, exact source
ClockBridgeCertificate/LeaseClockEpoch/tick anchor, drained reference/binding
set, and receipt namespace identity)`. Only that exact receipt permits a fresh
destination-local plan transition to commit at a later destination boundary.
For cross-node failure where exact source quiescence cannot be obtained, a
`QuorumSupersessionFence` may replace that receipt only when it names the exact
predecessor and successor `GlobalPlacementUse` and its destination
`activationNotBefore` is later than every predecessor resource's maximum
residual-effect horizon, including the upper clock-conversion uncertainty and
protected stop/drain bound. Time supersession is forbidden for an unbounded or
irreversible effect class. To preserve the stream it must also carry a
fault-tolerant `SettlementPrefixCertificate` identifying the last delivery,
settled prefix, debt, and any open ordinal. Without that certificate, safety
may recover only by advancing `ServiceStreamIncarnation` under a
`ContinuityLossRecord`; exactly-once and maximum-gap continuity are withdrawn.
Silence, timeout without the certified horizons, or a local placement
generation is never such a receipt.
Failure before the destination commit leaves a safe stopped gap and releases or
retains reserved destination capacity through the transfer's typed cleanup
path; it never restores source authority from Linux state. Outstanding service
debt and final terminal ledger state follow the transfer and are not reset. A
live opportunity is never relabeled across lane clocks.
Reconnection rejects the predecessor ownership epoch and cannot reopen its
source release gate.

Independent lane turns are not numerically interchangeable. The transfer uses
one total deterministic function rather than a relation that lets an
implementation choose a convenient cursor:

```text
CalendarTransferV1(
  exact SourcePlacementQuiescenceReceipt,
  exact destination reservation and immutable service calendar,
  current destination lane/clock/certificate tuple,
  preauthorized TransferReleaseEnvelope [notBeforeTick, notAfterTick),
  authorityExpiryTick, preparationLead, checked rank envelope)
    -> Ok(CalendarTransferRecord) | Reject(CalendarTransferReject)
```

Both endpoints must share the exact `LeaseClockEpoch` and authenticated trusted-
time domain. A cross-domain or cross-epoch transfer is rejected; v1 never
converts numeric ticks. The source receipt must be boundary-final with no open
opportunity and must seal the next ordinal, final last-settlement record,
last qualifying delivery receipt/tick, source calendar cursor, debt, source
fence, final lane turn, and trusted clock anchor.
`[notBeforeTick, notAfterTick)` is either issuer-authorized for this
transfer or covered by a precommitted `MaintenanceSkipRecord`; it is not minted
after source stop.

The common immutable service calendar is defined in trusted time, not either
lane's turn namespace:

```text
ServiceCalendar =
  (CalendarID, LeaseClockEpoch, baseOrdinal, baseTick, periodTicks > 0)

DueTick(C,q) = checkedAdd(C.baseTick,
                  checkedMul(q - C.baseOrdinal, C.periodTicks))
DueEndTick(C,q) = DueTick(C,q + 1)

DestinationCalendar.Cell(q) =
  the unique reserved destination lane turn for exact ordinal q
```

`Cell` is a validated strictly increasing partial function over the finite
reserved ordinal range, not an arbitrary predicate over convenient turns. Any
maintenance is applied before source quiescence: its first skipped ordinal must
equal the source next ordinal; checked cursor/debt updates and exact non-service
skip range are committed; last service settlement is unchanged. Transfer
itself creates no skip.

The boundary-final source receipt additionally binds `TransferID`, exact
destination reservation, `CalendarID`, post-maintenance `nextOrdinal`,
`DueTick(nextOrdinal)`, debt and skip digest, source fence, trusted stop tick,
and drained state. Let:

```text
q = sourceReceipt.nextOrdinal
d = DestinationCalendar.Cell(q)
lower = checkedAdd(currentDestinationTurn, 1 + preparationLead)
due = DueTick(calendar,q)
dueEnd = DueEndTick(calendar,q)

releaseU = ReleaseUpperLeaseTick(d,destinationCertificate)
activateU = checkedAdd(releaseU, LeaseTicksForRank(activationRank(d)))
firstDeliveryU = checkedAdd(activateU, LeaseTicksForRank(deliveryRank(d)))
terminalU = checkedAdd(firstDeliveryU, LeaseTicksForRank(terminalRank(d)))
activateNotBefore = max(envelope.notBeforeTick, due)
gapU = checkedSub(firstDeliveryU, sourceReceipt.lastDeliveryTick)
```

`Ok` requires `d >= lower`, exact calendar/timebase identity,
`activateNotBefore <= firstDeliveryU < min(envelope.notAfterTick,dueEnd)`,
`terminalU < min(effectiveAuthorityExpiryTick,dueEnd)`,
`gapU <= maxGapTicks`, and
`RankUpperLeaseTicks(d) <= rankBoundTicks`. It copies `q`, debt, last service
settlement, last qualifying delivery, and skip digest exactly and records every input/certificate
identity. No raw source/destination lane rank is compared, and no activation or
token is possible before `activateNotBefore`.

Reject precedence is fixed:

```text
CT01 MalformedOrEquivocatingSourceReceipt
CT02 SourceNotQuiescentOrNotDrained
CT03 TransferOrDestinationBindingMismatch
CT04 TrustedTimeDomainOrLeaseEpochMismatch
CT05 CalendarCursorOrMaintenanceSuccessorMismatch
CT06 InvalidHalfOpenEnvelope
CT07 ArithmeticOverflow
CT08 MissingPrecommittedSkipCoverage
CT09 NoReservedCellForExactOrdinal
CT10 CertificateOrFunctionHorizonInsufficient
CT11 DestinationCellNotFuture
CT12 PeriodOrMaximumGapViolation
CT13 CommonRankBoundViolation
CT14 DestinationPredecessorReservationOrFenceConflict
```

The first failed predicate is the sole result. Transfer progress is derived
from a prefix-closed chain of independently owned monotonic cells:

```text
sealed TransferIntent and destination reservation       -- transfer owner
committed SourceReleaseGate                              -- source-lane owner
SourcePlacementQuiescenceReceipt                        -- quiescence owner
CalendarTransferRecord or StoppedFailed(reason)          -- transfer owner
destination PlanTransitionRecord                         -- destination control owner
destination ApplyCell                                    -- destination lane owner
terminal cleanup and capacity-reclaim receipts           -- exact cleanup/capacity owners
```

There is no mutable scalar `TransferPhase`; restart resumes from the longest
valid receipt prefix. Because `CalendarTransferV1` runs only after source
quiescence, every rejection seals `StoppedFailed(reason)`, preserves the stopped
gap, and never reopens source authority. If an
external failure later prevents the selected boundary, the affected contract
receives its typed failure rather than a debt reset or false service result. A
contract that cannot tolerate this stopped interval must reserve overlap-free
alternate service in advance; ordinary migration is otherwise outside its
`StableWindow`.

## Safety Invariants

The dynamic contract must preserve the generic Formal 0148 subset named in the
refinement section, carry its scenario-specific obligations into
`DYN-REGRESSION`, and add at least:

```text
UniqueCurrentAdmissionRecord
NoUsableAdmissionWithoutValidLocalLease
PreparingIsNotAuthority
AdmissionCommitHasFeasibilityWitness
CommitDependencyVectorIsCompleteAndCurrentAtCommit
CommitDependencyRelationsAreTypedAndNotCallerSelected
OrdinaryServiceProgressIsCertifiedMonotoneSuffixNotConflict
SelectedGuaranteedControlIntentCannotBeOvertakenByOverlap
DelegationCommitAndEffectStayInsideExactLeaseClockHorizon
AdmissionSnapshotPublishesAtomically
AdmissionSnapshotIsImmutable
AdmissionSnapshotContainsNoLiveCursorOrPlanEpoch
StreamLedgerOwnsMutableRecurrence
PlanMembershipBindsSnapshotWithoutMutatingIt
CommittedScheduleIsNotExecutionAuthority
PlanTransitionCommitIsAtomicAcrossDeclaredFootprint
CompositionalApplyCertificateImpliesEveryMixedTerminalPrefixSafe
OwnerPartitionAndAggregateContributionInductionReplacesPairwiseProof
SharedAncestorCapacityIsNeverDirectlyWrittenByLocalDelta
EachApplyEntryHasExactlyOneStatusWriter
ApplyEscrowDominatesPendingAppliedAndFailedFencedDemand
FailedFencedNeverWritesSecurityScopeFence
TransitionShardSetIsAdmissionBounded
EveryCommittedApplyEntryTerminatesAppliedOrFailedFenced
PendingPlanEntryCannotReleaseOrActivate
FirstReleaseScheduleCannotMaterializeOpportunityBeforeDue
FirstReleaseIsStrictlyAfterMembershipEffectiveBoundary
AtMostOnePendingTransitionPerShard
CommittedTransitionAppliesOnlyAtExactBoundary
LocalApplyCannotRevalidateOrRollbackCommittedSchedule
BestEffortAdmissionDoesNotReplaceGuaranteedPlan
RetirementFenceIsPerAuthorityUseMonotonicAndCannotReopen
ReleasedOpportunityUsesLiveRetirementFenceAndTokenBindsCurrentGeneration
LeaseTermRenewalIsExtensionOnly
FrozenOldTermUseCannotInheritLeaseExtension
LeaseExtensionDoesNotRepublishAdmissionOrPlanMembership
LeaseFenceStopsOldEpochBeforeReplacement
TrustedLeaseExpiryIsIndependentOfLaneTurn
FrozenLeaseUseAndTokenBindExactLeaseClockEpoch
LeaseClockEpochReplacementRequiresOldUseQuiescenceOrPermanentFence
NoTokenOrActivationAtOrAfterLeaseExpiry
LeaseExpiryInvalidationHasNoAdmissionFanout
ClockBridgeInvariantIsNumericAndCurrent
ClockBridgeBindsLaneControlLeaseEpochsAndExactCertificate
HardwareProgressIsTheOnlyExternalClockBridgeRely
ProtectedServiceCapacityIsParentConservedAcrossAllLiveChildren
OnePhysicalServiceOpportunityAdvancesAtMostOneDescendantControlTurn
TargetLaneQuotaCannotUsePreAnchorCredit
LaneCannotOutrunCertifiedControlServiceQuota
ClockViolationHasTypedFenceAndStopTransition
AdmissionSnapshotContainsNoCurrentClockBridgeCertificate
CurrentOpportunityFreezesExactClockBridgeCertificate
BridgeCertificateExtensionDoesNotRepublishAdmissionOrMembership
BindingAuthorityKeyOfSnapshotIsTotalAndComplete
ServiceOnlyUpdateCannotMintBindingAuthority
CandidateDeltaIsConfinedToDelegation
CommitWritesOnlyDeclaredMutationFootprint
DisjointDependencyChangesCannotStaleCommit
UnrelatedAuditCheckpointCannotStaleCommit
FirstReleaseScheduleCreatedAtAdmissionCommit
NoReleaseBeyondLeaseOrRetirementFence
RetiringAuthorityUseOnlyServesPreBoundaryObligations
LeaseExpiryCannotSetOpportunityActivated
CapacityConservedAcrossCommitRejectAndCancel
ClassAndPlanMembershipScheduleAndLocalApplyAreAtomic
ContractAndPlanEpochsNeverRollBack
SurvivingServiceDebtNeverResets
BoundaryDueReleaseMaterializedBeforePlanCutover
LaneBoundaryAdvanceUsesOneStagedOrder
RetirementFencePublishesBeforePostApplyToken
NewDueCannotActivateInItsCreationBoundary
AtMostOneCurrentOpportunity
OpportunityActivationAndTerminalRemainDistinct
TerminalSettlementHasStrictPrePeriodHeadroom
MaintenanceCannotSkipUnrecordedDueRelease
StreamIncarnationRenewalCannotRelabelLiveArtifact
CurrentOpportunityRankCannotIncreaseUnderStableUpdate
RetiringPlanArtifactsRemainUntilSettlement
RetiringOpportunityRemainsRootSchedulableUntilTerminal
PlanCutoverDoesNotDoubleCountRootBudget
CommittedPendingPlanRootReservationIsNeverOwnerless
RunTokenBindsExactAdmissionStreamPlanAndBindingTuple
RunTokenBindsExactFrozenLeaseUseAndSecurityUseVector
SecurityUseVectorKeysEqualImmutableSecurityDependencyCertificate
SecurityUseVectorEntryBindsFullFailureScopeIdentity
ClosureChangingTopologyTransitionFencesOldUsesBeforeEffect
DisjointLaneActionsCommute
DisjointTransitionPublicationAndApplyCommute
FailureCannotDisableLaneOutsideSelectedCoverUnlessNodeFailStop
BoundaryApplyNeverWaitsForAnotherShard
ExclusivePlacementDestinationRequiresSourceQuiescenceOrBoundedQuorumSupersession
ExclusivePlacementTransferNeverDuplicatesAuthority
ExclusivePlacementTransferPreservesCalendarAndDebtAcrossLaneClocks
ExclusivePlacementSourceReceiptRequiresNoCurrentOpportunity
ExclusivePlacementCalendarComesFromBoundaryFinalSourceReceipt
CalendarTransferMapsExactNextOrdinalThroughCommonTrustedCalendar
CalendarTransferRejectCannotReopenSourceAuthority
MigrationGapStartsAtLastDeliveredServiceNotSourceStop
QuorumSupersessionWithoutSettlementPrefixCannotClaimContinuity
TransferProgressIsDerivedFromPrefixClosedMonotonicReceipts
LinuxCannotCreateGuaranteedObligation
LinuxCannotGateActivateHeld
ControlOpIsIdempotentAndEventuallyTerminalWhenAccepted
SelectedIntentProtectsAllNoncommutingReadWriteAndResourceDependencies
ControlAbortAndCommitHaveDeterministicLinearization
CancelledControlNeverPublishesAuthority
RequestTupleImmutable
DuplicateRequestIsIdempotent
RequestIDEquivocationRejected
CoalesceOnlyExactPhysicalKey
NoCrossProvenanceInflightCoalescing
DistinctOpportunitiesRemainDistinct
OneTerminalOutcomePerRequest
CancellationIsNonRetroactive
CancelAndActivateHeldHaveDeterministicLinearization
ActivationDecisionIsOneShotAndSeparateFromStopAndTerminalSettlement
PostActivationFenceAlwaysCreatesOrJoinsStopPending
TerminalSettlementIsOneShotAfterCoveredEffectsAreAbsent
OnlyOneWinningCancelRecordPerRequest
CancelledRequestCannotBecomeReadyOrActivate
OneMemberCancelCannotDropAnotherMember
GuaranteedIngressAndWorkAreReserved
BestEffortCannotConsumeProtectedCapacity
WorkUnitsAndOperationRecordsAreSeparatelyConserved
RootCurrentRetiringCandidateReservationsAreConserved
CommittedPendingRootReservationsAreConserved
ActiveTokenResidualBelongsToExactlyOneRootReservation
RetryCancelAndCoalesceCannotMintWorkUnits
CleanupRetainsItsReservationUntilSettlement
CleanupClassIsImmutable
AcceptedControlCleanupHasReservedAdmissionControlService
CleanupDelayCannotExtendStoppedAuthority
PendingStateAndWaitersAreBounded
OverflowCannotAlterAuthority
HeldBindingMatchesExactOpportunity
SealedMemberSetIsImmutableBoundedAndExact
MemberDispositionIsSeparateReplayFencedState
CancelledMemberCannotPublishOrActivate
TransactionStateDoesNotOverwritePublishedBinding
StaleWorkerCannotCompleteNewWork
ReverseReplicaEnumerationExactAndBounded
ReplicaCleanupBoundIsAdmissionReserved
NoGenerationWrap
EveryFiniteSequenceHasAnEnclosingRenewalNamespace
EveryReplaySensitiveFiniteSequenceIsRegistered
EveryConsumerChecksCompleteEnclosingFreshnessTuple
NamespaceParentGraphIsTotalAcyclicAndScopeBounded
NamespaceRegistryAndCheckedParentGraphAgree
UntrustedSequenceJumpCannotAdvanceWatermark
NamespaceExhaustionIsConfinedToOwnedScope
NamespacePublicationWearIsSponsorChargedAndConserved
BestEffortCannotConsumeGuaranteedOrRenewalNamespaceHeadroom
AuthoritativeGenerationConsumedOnlyAtPublication
ProjectionRenewalRequiresZeroModeledRefsAndExactTypedReceipt
RenewalRetainsStableGuaranteedObligationAndDebt
LinuxReferenceCannotMintExtendOrVetoAuthority
RcuGraceIsNotTrustedHardwareQuiescence
TrustedReuseRequiresMonitorAndArchitectureReceipts
HotplugRollbackCannotReviveCommittedCpuIncarnation
NodeModeTransitionsHaveObjectiveGuards
FailureScopeIsDerivedFromAuthoritativeOwnership
FailureAuthorityPointNeverMaterializesAffectedContractPopulation
FailureEventUsesNodeConfigBoundedCanonicalCoverOrNodeFailStop
FailureCannotWeakenUnaffectedContract
NodeSecurityHighWaterAdvanceIsNotUniversalAuthorityFence
RelevantSecurityScopeFencePublishesBeforeAuditAppendOrCheckpoint
UnrelatedSecurityEventCannotInvalidateAdmissionOrDirtyArm
GlobalSecurityStopRequiresNodeScopeFence
FailureRecoveryUsesAffectedScopeGenerationNotAggregateMode
SourceFailureReceiptIsFreshBeforeInternalEventAllocation
SourceFailureReceiptMapsOneToOneToFailureEvent
FailureEventIdentityIsIndependentOfAuditOrder
DisjointFailureAuthorityEffectsCommute
OldSecurityUseVectorCannotResumeAfterRecovery
RepeatedFencedFailureCannotConsumeNewEventOrAuditShardPosition
ScopeFailureCapacityExhaustionCannotStopDisjointScope
SourceDurablePendingPrecedesScopeCommitHighWaterAndForgettableDetail
SourceTerminalHighWaterCannotAdvanceBeforeScopeCommit
ReplayHighWaterImpliesCommittedOrCoveringFailStop
DurablePendingIsSelfContainedAndRecoverableWithoutSourceRetransmission
CommittedTransactionRetainsPreparedOrMaterializedSuccessorClosure
CommittedScopeTransitionBitIsSoleMultiScopeAuthorityLinearization
EveryAuthorityConsumerReadsEffectiveScopeNotRawMaterializedState
MaterializationCannotChangeEffectiveAuthority
AuditAppendCheckpointAndAggregateCannotGateOrUndoAuthorityFence
OneFailureEventHasAtMostOneRecoverableAuditPosition
SourceExhaustionCommitsSourceHealthFenceBeforeDependentAuthorityContinues
LiveAuthorityCannotSwitchSourceCoverageAfterFailure
FailureRecordRecycleRequiresNoReferencesAuditCheckpointReconciliationAndFreshGeneration
OrdinaryRestartRequiresClosedPendingAuthorityAndOldBootFenceReconciliation
AuditShardRenewalRequiresCheckpointAndTerminalOutbox
AuditHeadroomWindowBoundsFailureLivenessClaim
FailureEventBindsCanonicalSourceAndBoundedScopeVector
SecurityUseVectorIsCanonicalAndAdmissionBounded
FailureReceiptReplayCannotReenterRecoveredMode
RecoveryCASCannotClearNewerFailure
NoOldBootArtifactUse
RestartRequiresFreshBootBoundLeaseReattestation
RestartLeaseBindsCurrentClusterIssuerIncarnation
UncleanRestartRequiresSecurityReconciliation
SourceTransitionScopeOutboxAuditCrashCutsRemainFailClosed
NodeLocalRevokeCannotBeForgottenByRestart
ReconciliationAckBindsExactStoppedShardRootsAndHighWater
ExecutionDirtyArmedBeforeOrdinaryAuthority
DirtyArmDoesNotAdvanceReconciledEpoch
LeaseAndAdmissionBindReconciledDirtyTuple
SecurityAuditFailureCannotUndoFenceOrResumeOrdinaryDomains
GuaranteedControlPrincipalCannotBeStarvedByPeerChurn
SparseNonemptyControlRingNeverScansEmptyPrincipals
LocalRevokeCannotMintIssuerEpoch
ScopedOperationIDsBindFullNamespaceOwnerRoot
BestEffortAuthorityUseIDCannotAlias
NodeConfigBoundsEveryAcceptedVectorAndProof
HierarchyCapacityConservedAtEveryAncestor
EveryAuthorityUseBindsCompleteHierarchyFencePath
ReparentFencesAndQuiescesOldPathBeforeNewUse
RootExecutionCapacityIsParentConservedAcrossAllLiveLanes
SharedControlAndExecutionHardwareHasOneCapacityRoot
OnePhysicalExecutionOpportunityChargesAtMostOneLane
ActivationIntentPreparationConsumesNoPhysicalExecutionCell
ExecutionCellLeaseIsImmutableAndOnlyUseCellCarriesOneWayState
ExecutionCellUseCellHasOneRootExecutionStateMachineWriter
OnePhysicalExecutionCellConsumesAtMostOneLeaseAndToken
ExecutionCellLeaseCannotCarryForwardOrBeReused
OnePhysicalContextHasAtMostOneActiveTokenOwner
RunTokenBudgetNeverExceedsCellOrAuthorityHorizon
CellEndForcesExitBeforeNextOwner
IndependentLanesHaveDisjointOrSeparatelyReservedPhysicalCells
OneControlShardTurnAdvancesAtMostOneTargetControlTurn
TargetQuotaUsesOnlyExactPostAnchorTargetControlTurns
NodeLeaseImportBindsNoForkClockOfflineAndPartitionSemantics
DisconnectionCannotExtendOrChangeImportedAuthority
PartitionDeadlineBlocksReleaseAndJointActivation
RecoveryOnlyBlocksOrdinaryAuthorityFromInstallation
GlobalPlacementUseBindsEveryExclusiveExecutableArtifact
LeaseExtensionCannotExtendGlobalPlacementHorizon
NewAuthorityStopsAtMinimumPlacementLeaseSecurityCellAndBudgetHorizon
NetworkSilenceIsNotSourceQuiescence
SupersedingPlacementWaitsBeyondEveryPredecessorResidualEffectHorizon
UnboundedOrIrreversibleEffectRequiresExactSourceQuiescence
CanonicalFailureCoverIsTotalAndNeverTruncates
OversizedFailureUsesUniqueFailureCoverTreeLCAOrNodeFailStop
FailureCoverBindsSourceCurrentAndEveryLiveAuthorityReferencedTopologyGenerationUnion
FailureImpactClosureIsPublicationFencedBoundedLeastFixedPoint
FailureCommitAtomicallyTransfersCapacityToFailureEscrow
EveryLiveScopeUseHasChargedLeafAndPotentialCoverAncestorReverseEdgeAndCleanupReservation
FailureCleanupCannotExceedAdmittedCoverAncestorAggregateUseCap
PhysicalOccurrencePartitionsAreExactDisjointParentChildSets
ResidentReadyAndActivationIntentAreNotExecutionAuthority
AllocatorActivationSlotBreaksImmutableLeaseIntentCycle
ActivationIDIncludesFullNamespacePhysicalSlotLeaseAndIntentParents
CanonicalActivationDecisionCellLinearizesCancelPrepareEntryAndStop
TokenExecutableAndActiveContextExecutableAreCompleteAndRunTokenIsOneUse
DeliverySettlementCellMakesBudgetResumeReceiptAndServiceExactlyOnce
AuthorityDeadlinesNormalizeToOneLeaseClockEpochBeforeMinimum
IndependentWatchdogProgressOrAutonomousTimeScopeFailStop
CrossNodeCalendarUsesIntervalClockRelationOrWithdrawsContinuity
SettlementPrefixFollowsPredecessorWriteCloseAndQuorumCheckpoint
ActivationRequiresCompleteExecutionContextKey
MissingDependencyReceiptCannotMeanNotApplicable
ActivationCommitReceiptAloneDoesNotCountService
OnlyQualifyingExecutionDeliveryReceiptCountsService
ZeroDeliveredTicksWithoutPostEntryYieldIsNotService
JointActivationCannotLeavePartialExecutableState
PreValidBitCrashCannotExposeExecutableContext
FiniteFreshnessNeverImpliesUnconditionalOmegaRecurrence
ProofDependencyDAGIsAcyclicAndStableWindowIsNonvacuous
ManagementBootstrapConsumesReservedPhysicalAndControlCapacity
OrdinaryAuthorityCannotDebitOrReplaceManagementBootstrap
ManagementBootstrapFailureForcesNodeFailStop
ManagementRecoveryIndependent
NoProtectionClaim
```

An accepted response, resident bit, request status, workqueue pending bit,
Linux queue membership, cgroup membership, or successful plan compilation is
never execution authority.

## Availability and Bound Semantics

Safety does not require Linux fairness. Availability separates external relies
from guarantees that the dynamic models must prove.

External relies for a target stream are limited to:

```text
input authority and lease authentication is sound and non-rollback
NodeLeaseImportCertificate and GlobalPlacementUse producers satisfy their
typed no-fork, issuer-time, conversion-uncertainty, and fencing contracts
concrete seals preserve the full canonical tuple without forgery,
encoding ambiguity, or cross-context substitution
the temporal StableWindow assumption holds for the target through its numeric
activation and terminal bound windows
at least one eligible authoritative execution context remains functional
root expiry and modeled trusted hardware/reference release are represented by
explicit finite countdowns
the exact external HardwareProgressInvariant holds for the selected protected-
service pool and lease timebase; Monitor service allocation and target quota
are not external assumptions
declared external trusted-countdown, lease-stop, and typed-receipt components
satisfy their finite component contracts; no Monitor target picker, control
shard, lane action, or Linux action receives external fairness
the AuditHeadroomWindow or authenticated audit-shard renewal progress covers
the admitted unrelated-failure envelope
future typed quiescence receipts satisfy their later component contracts
a boot-root-authenticated ManagementRecoveryBootstrapContract exists for the
exact immutable context and reserved resources named here; failure withdraws
recovery liveness and enters node fail-stop
a fresh BootFreshnessRoot exists when boot-level renewal is required
protected NodeSecurityEpoch/ReconciliationRoot state is non-rollback and
authenticated log detail is either recoverable or forces fail-stop
```

`StableState(target)` is a derived current-state predicate over the exact
`DomainKey`, issuer envelope, usable lease horizon, stream identity,
operational failure scope, service/eligibility envelope, and current fences.
For an open opportunity it also requires the frozen `BindingAuthorityKey`,
`PlanMembership`, `FrozenLeaseUse`, `SecurityUseVector`, lane, and rank envelope
to remain valid.

`StableWindow(target, lo, hi)` is a temporal rely over a trace: `StableState`
holds at every state in the interval and no authorized withdrawal, revoke, or
target-affecting failure occurs. It is not a stored field or a predicate of one
state. A pure extension-only lease renewal or service-only generation change
may occur when the old frozen use remains valid and successor mapping preserves
the lane and non-increasing rank. Unrelated joins, leaves, disjoint-shard
commits, best-effort flood, and Linux noise may interleave without changing the
target rank. Scoped failures outside the dependency closure may recur only
inside the exact `AuditHeadroomWindow` or under proved audit-shard checkpoint
renewal; finite audit state is not silently treated as infinite.

The executable specifications must establish, rather than assume:

```text
every commit has a historical feasibility witness and, while its declared
Operational/stable failure envelope holds, conserved reservations continue to
satisfy that witness
ROOTSCHED materializes releases no faster and no slower than the contract
parent-conserved physical execution cells cannot be double-spent by lanes
the one CurrentOpportunity reaches joint activation commit and terminal by its
separate bounds
the fixed protected frame services guaranteed and mandatory cleanup work
each control target receives only its own reserved microsteps and one shard
turn cannot decrease two target ranks
renewal preserves a guaranteed ObligationID/debt and progresses under its relies
every stable due release reaches deterministic joint ActivateHeld
within ActivationTurnBound
unrelated valid plan commits do not increase the target's remaining rank
nonconflicting accepted feasible control operations commit within their
control rank
scoped failure does not weaken an unaffected contract or lane
every real failure reaches exact cover, covering ancestor, or node fail-stop
management bootstrap retains its independently conserved service or node
fail-stop withdraws its liveness claim
```

The witness supplies a typed lexicographic progress tuple:

```text
ActivationRank = <<
  root plan cells remaining,
  protected guaranteed work units remaining,
  victim-stop countdown steps remaining,
  trusted-reference countdown steps remaining,
  residency transaction phases remaining,
  admitted renewal steps remaining
>>

ActivationTurnBound >= RankToLaneTurns(initial ActivationRank,
  protected-frame frequencies, ClockBridgeCertificate)
TerminalTurnBound >= ActivationTurnBound
  + RankToLaneTurns(token/stop/settlement rank, same certificates)
```

Tuple components are natural numbers in their own units and are never added
without an explicit conversion. `ControlTurnsFor` is the checked sequential sum
of deterministic frame distances for the ordered stages. `PoolTurnsForRank`
maps those turns through the exact root-to-leaf `PathDistance`.
`RankToLaneTurns` conservatively adds root-cell distance, the target-local
`maxInitialLaneLead`, `ceilDiv(ControlTurnsFor, m)` for positive anchored quota
`m`, and declared countdown lane bounds. `LeaseTicksForRank` sequentially adds
the hardware residual burst, `maxLeaseTicksPerOpportunity * PoolTurnsForStage`,
external countdown tick bounds, and token-stop bound. `max` is legal only under
a separate parallel-progress/noninterference certificate. All operators are
total monotone natural-number functions with checked overflow rejection; none
is a stored free result. Monitor-owned deterministic service, capacity, and
quota are internal proof obligations. This is a logical-turn guarantee;
production wall-clock time still needs WCET/timer refinement.

Each opportunity records `releaseTurn` and
`activationDeadlineTurn = releaseTurn + ActivationTurnBound` plus its terminal
deadline. On every enabled owed target step, the deterministic root/work policy
or a named bounded environment countdown decreases the lexicographic rank.
Unrelated plan/control churn cannot increase it. Joint `ActivateHeld` and root
target selection receive no fairness assumption of their own. Protected
preparation creates the exact intent and reserves its future cell without
consuming it. At the due physical cell, complete ENTRY/CODE/STATE receipts make
the joint commit the deterministic action; a typed failure expires the cell
without carry-forward. A second bounded rank covers hardware-visible delivered
execution or post-entry voluntary yield and the exact cell-end handoff.

The baseline safe recurring configuration begins with one committed stable
guaranteed stream, every external failure guard false, and no planned
maintenance in the witness window. It must demonstrate at least two distinct
releases, matching `ActivateHeld`, qualifying `ExecutionDeliveryReceipt`, and
terminal settlement events within their separate bounds. A second
configuration injects a covered failure outside the
target's dependency closure and must demonstrate the same target property.
Cancellation, withdrawal, revoke, target-affecting maintenance/degradation,
emergency, or fail-stop cannot satisfy or discharge that target's service
property.

No fairness is assumed for Linux, best-effort request production, Linux
quiescence reports, adapter calls, `LocalValidate`, or Domain-local application
work. Infinite changes that weaken or revoke the target's own authority can
prevent activation; they make `StableWindow` false rather than proving
successful service.

Bounds use different units:

| Claim | Required basis |
| --- | --- |
| queue/storage bound | configured admitted contracts, streams, lanes, and fixed pools |
| attacker amplification bound | maximum parsing, lookup, and rejection work per attributed ingress |
| transition bound | protected Monitor service turns and declared hardware-release turns |
| recurring wait bound | certified plan turns plus carried debt and residency transition bound |
| wall-clock bound | Monitor WCET, timer/interrupt latency, root expiry, drain, view install, firmware, and hardware assumptions |

`waitTurns` counts protected Monitor service turns whose reservation cannot be
consumed by Linux or best-effort churn, not arbitrary TLA transitions or
wall-clock time.

Best-effort starvation freedom under overload is not promised. Conditional
best-effort fairness may later require finite principals, a persistent request,
reserved slack, bounded collision, and a stable window.

## Impossibility Boundaries

The contract explicitly rejects all of these combinations:

```text
unbounded guaranteed population with a finite service bound
unbounded outstanding requests or waiter sets in finite protected memory
infinite finite-width generation reuse without outer renewal or retirement
guaranteed liveness while every eligible CPU is lost
guaranteed completion while trusted hardware references never release
wall-clock bounds with unbounded firmware/SMI/interrupt suppression
unconditional best-effort progress under overload
service for a contract after an authorized revoke or withdrawal
at-most-once external endpoint effects from volatile residency state alone
instant dynamic plan replacement that discards debt or active obligations
safe cancellation that retroactively erases an issued root token or effect
zero-cost process-granular switching for every workload
```

These are admission and threat-model boundaries, not implementation defects to
hide behind fairness assumptions.

## Scalability and Datacenter Shape

The semantic hierarchy remains:

```text
global signed Domain namespace
  -> node-local Monitor admission directory
    -> bounded-depth DomainHierarchyCertificate paths
      -> optional immutable per-NUMA/LLC descriptor cache
        -> parent-conserved root execution allocation
          -> fixed bounded per-CPU projection
            -> exact activation-committed token
```

The required memory envelope is:

```text
O(node-admitted Domains)
+ O(NodeConfig-bounded admitted hierarchy edges and ancestor reservations)
+ O(committed guaranteed streams)
+ O(fixed current/retiring plans per shard, memberships, and StreamLedgers)
+ O(authenticated lease authority records, not per-snapshot expiry copies)
+ O(bounded control, request, cancel, work, and cleanup pools)
+ O(bounded replay watermarks, tombstones, and retirement state)
+ O(namespace renewal, source replay, transition/scope authority, outbox,
    audit/receipt shards, and derived NodeMode state)
+ O(admission-charged failure reverse edges and cleanup reservations)
+ O(total physical resident slots)
+ O(root-execution allocations and immutable parent schedule cells)
+ O(optional locality descriptor caches)
+ O(CPUs and root lanes)
```

It is independent of the global cluster Domain count. Dormant best-effort
process Domains need not consume per-rq state and may leave the node-admitted
working set, while a sealed global descriptor remains outside the hot path.

For a large node, a canonical home shard per Domain and immutable shard layout
within a `MonitorBootEpoch` are strong implementation candidates. The semantic
reference has independent plan/lane owners rather than a node-wide serialized
coordinator. Frozen requirements are one canonical mutation owner per Domain,
bounded lookup and critical sections, no lock held across drain or hardware
wait, and no global Linux runqueue or heap as authority. Exact hashing, tree,
shard count, and live-reshard policy remain unselected.

The asymptotic contract is mandatory before model closure:

```text
candidate storage and commit validation
  O(affected lineages + bounded declared shard set + certified proof size and
  hierarchy depth), not
  O(all node Domains * control principals)

partial-apply certificate validation
  O(affected shards * bounded hierarchy depth + bounded local proof size),
  with structural write partitions and one sparse aggregate fold rather than
  pairwise or all-prefix enumeration

unrelated commit conflict
  disjoint read/write/resource footprints commute and cannot stale each other

lease expiry authority invalidation
  O(1) shared LeaseAuthorityRecord/time comparison plus O(active root lanes)
  hardware stop; per-admission cleanup is lazy and authority-free

pure extension-only lease renewal
  O(1) update to the shared LeaseAuthorityRecord with no traversal or rewrite
  of frozen uses; no AdmissionSnapshot or PlanMembership republish

retained lease-term memory
  O(current live FrozenLeaseUse references), reclaimed only after their exact
  opportunities, holds, and tokens settle

clock-bridge component publication
  O(1) per exact component record, with no traversal of live users and no
  admission-population republish

retained clock-bridge certificate memory
  O(current live opportunity/control/hold/token component references),
  reclaimed only after exact terminal settlement

service-allocation path update
  O(bounded service-hierarchy depth), debiting residual capacity at every
  parent on the exact path

namespace wear
  sponsor-charged O(1) publication ledger updates preserve shared guaranteed,
  management, and renewal headroom; best-effort cannot force peer renewal

lane progress
  stop, drain, failure, namespace exhaustion, or plan retirement on one lane
  cannot block a disjoint lane's clock, token, or commit

security-event locality
  authority updates cost O(KFailureScopesPerEvent * KDepth), using exact
  source/current topology union closure, unique FailureCoverTree LCA, or node
  fail-stop, and never enumerate
  dependent Domains; cleanup follows at most admission-charged
  KLiveAuthorityUsesPerScope reverse edges with protected quota; independent
  audit append/checkpoint is observation, and replayed input allocates no new
  position

execution security validation
  O(MaxSecurityScopesPerUse) over an admission-certified canonical closure,
  never O(all admitted Domains or node resources)

guaranteed-control selection
  O(1) sparse nonempty-ring successor plus exact reserved target schedule cell;
  one target microstep advances only that target's rank
```

`DYN-SHARD` and its negative mutations are the executable scale/refinement
gate. Cost measurement cannot replace this semantic noninterference proof.

Process and container Domains use the same execution identity type. A process
may be a leaf below a container and tenant, but every path is bounded by
`NodeConfig`, compiled into an immutable `DomainHierarchyCertificate`, and
charged at every ancestor. Hierarchy supplies sponsorship, quotas, delegation,
and subtree fences without turning parent Linux state into child authority.
The depth-one flat case remains a valid specialization.

A scalable production root scheduler may use a hierarchy of protected servers
and capacity certificates. Every child budget is conserved beneath its parent,
and no compromised leaf can alter a sibling's service. No global datacenter
runqueue or synchronously shared kernel heap is required.

The intended path costs are:

```text
same-Domain task switch and ordinary syscall
  no residency transaction and no plan update

resident root activation
  bounded local exact-binding validation plus required Monitor activation

residency miss
  bounded node directory resolution and fixed candidate examination

admission or plan update
  charged conflict-local slow path with bounded delta-certificate validation

global signature/delegation validation
  admission slow path, never ordinary scheduler selection
```

These are architecture constraints, not measured performance claims.

## Linux Projection Adapter Contract

The Linux adapter is a compatibility and optimization layer, not the root of
admission or activation. Exact fields, hooks, and ABI remain unselected, but
the semantic interface is bounded to:

| Interface | Meaning | Authority rule |
| --- | --- | --- |
| `IdentitySnapshot` | immutable Domain/epoch/descriptor tuple plus Linux lifetime reference | a task pointer, cgroup, or current CPU is never identity authority |
| `ResidencyHint` | attributed locality or best-effort proposal | bounded, replay-safe, and non-authoritative |
| `ProjectionReceipt` | cached exact admission/CPU/projection/slot generations | useful only after current Monitor validation; never a RunToken |
| `LocalValidate` | allocation-free, non-sleeping `Ready/Pending/Stale/Deny` projection check | Linux result can narrow or accelerate best-effort work, never authorize or veto guaranteed work |
| `ActivationHint` | optional best-effort candidate plus cached receipt | omission, `Deny`, or stale data cannot delay a guaranteed obligation |

If Linux omits, delays, duplicates, corrupts, or misroutes an adapter action,
best-effort performance or Domain-local application progress may degrade, but
authority cannot increase and a guaranteed opportunity cannot be suppressed.
The guaranteed path is the Monitor-internal
`ActivateHeld(ObligationID, BindingID)`, driven by the trusted root plan and
held binding without a Linux call or Linux `LocalValidate` result. A missing or
stale Linux receipt causes best-effort denial or a bounded Monitor residency
transaction. Ordinary task migration remains Linux policy; only an explicit
exclusive Domain placement transfer is a Monitor authority migration.

The reviewed Linux source remains commit
`74311ca1ac4937e0e62f1e0f6a3e5bfa4fc77d6f`, tree
`54f685aad94f28f0027cbba18cf5e29aadce234a`. Current source constrains the
adapter without selecting patch points:

| Linux surface | Current anchor | Semantic consequence |
| --- | --- | --- |
| task/rq state | `kernel/sched/core.c:570-657` | `on_rq`, `on_cpu`, blocked, delayed, and proxy/donor state are compatibility state, not one Domain-runnable truth |
| wakeup and remote queueing | `kernel/sched/core.c:4069-4435` | selected CPU may change through wakelist, IPI, hotplug, or fallback; a pre-enqueue slot observation cannot authorize final placement |
| queued migration | `kernel/sched/core.c:2542-2680` | stopper and rq-lock transitions are projection mechanics, not one atomic authority move |
| affinity coalescing | `kernel/sched/core.c:2961-3214` | concurrent Linux requests may share pending state and wait for migrate-disable; carrier overwrite is forbidden |
| scheduler hotplug | `kernel/sched/core.c:8556-8862` | active masks, rq callbacks, and task drain refine but do not define Monitor CPU authority |
| CPUHP rollback | `Documentation/core-api/cpu_hotplug.rst:295` | callback failure and rollback require the separate Monitor prepare/commit and incarnation rule |
| workqueue coalescing | `include/linux/workqueue.h:674`, `kernel/workqueue.c:3206` | pending work may merge and executes in worker context; caller/request authority is not naturally preserved |
| RCU | `Documentation/RCU/whatisRCU.rst:198` | a grace period is not trusted entry, hardware, or backing quiescence |
| refcount saturation | `include/linux/refcount.h:11` | conservative Linux lifetime leakage cannot pin Monitor authority forever |

Linux XArray, Maple Tree, IDR, and rhashtable are possible shadow/index
mechanisms only. They cannot become the protected admission directory. In
particular, rhashtable resize/walk behavior is asynchronous and restartable.
Local `upstream/master` contains UAF fix
`8173f7e2ce67e6ca1d4763f3da14e5b01ce77456` (`rhashtable: clear stale
iter->p on table restart`), while the reviewed work commit does not. This is
not evidence of a current DomainLease-Linux vulnerability; it is evidence that
implementation must rebase and that source-drift coverage must include the
chosen directory/shadow substrate.

Before implementation, the drift gate must add watch groups for:

```text
kernel/cpu.c and CPUHP documentation/callback contracts
scheduler wake, migration, affinity, hotplug, and proxy/donor paths
workqueue pending/publication/worker execution
the selected XArray, Maple Tree, IDR, or rhashtable shadow paths
RCU and refcount lifetime semantics
architecture entry, TLB, timer, and trusted quiescence paths once selected
```

An upstream change in these groups stales the affected refinement/source map;
it does not silently invalidate the architecture contract or authorize a patch.

## Rely/Guarantee Interfaces

| Component | Relies on | Guarantees here |
| --- | --- | --- |
| cluster authority | typed no-fork `NodeLeaseImportCertificate`, clock interval, partition mode, and `GlobalPlacementUse` | conservative node-local import only; no direct executable remote authority |
| admission Monitor | protected capacity journal and root-plan verifier | atomic admission/plan commit, no overcommit, no Linux class upgrade |
| ROOTSCHED | committed plan, parent-conserved execution allocation, and held exact binding until settlement | bounded guaranteed release and non-executable `ActivationIntent`, debt preservation |
| residency service | bounded root expiry/reference release and valid contract | exact held binding, bounded protected work, stale completion rejection |
| ENTRY/CODE/STATE | exact `ActivationIntent`, immutable binding tuple, and complete receipt-class schema | joint context install, budget/stop arm, and `ActivationCommitReceipt`; physical proof remains a later model obligation |
| Linux | no safety or liveness cooperation | hints, transport, and local policy only; no authority guarantee |
| management/recovery | boot-root-installed `ManagementRecoveryBootstrapContract` with conserved physical/control/namespace/audit/failure capacity | only its closed recovery action set remains reachable; authorization and compromise semantics refine in MGMT-001 |

Rows between ROOTSCHED, residency, and ENTRY/CODE/STATE are component
interfaces, not top-level assumptions. `DYN-COMPOSE` must discharge their
cycle: ROOTSCHED creates the bounded obligation and execution-cell-backed
intent; residency creates and holds the exact binding; joint `ActivateHeld`
consumes both plus the complete context receipt set atomically.

`ResidentReady` means only that the exact binding is sealed and held.
`ActivationIntent` means only that all pre-joint identities are fixed. Neither
means that a MemoryView is active, executable code is current, backing reuse is
physically safe, or service occurred. Those guarantees become executable only
with the exact `ActivationCommitReceipt` supplied by later composition.

## Refinement Obligations

### Formal 0148

When the admission set is fixed, class/descriptor updates and renewal are
disabled, and each guaranteed stream is restricted to one release:

```text
committed current AdmissionContract -> admitted[d]
derived effective tuple
  (ClusterIssuerIncarnation, DomainEpoch, NodeLeaseID, NodeLeaseEpoch,
   LocalAuthorityGeneration, LocalLeaseFenceGeneration,
   exact scoped fences) -> globalEpoch[d]
current logical obligation -> requestDomain/requestCPU
PhysicalResidencyTxn phases -> prepare/drain/retire/bind
publishedSlotState only -> finite slot state/binding
constant ProjectionEpoch + CpuIncarnation + SlotGeneration -> exact slot tuple
retiring admission -> remains abstractly admitted until settlement
held ConsumerKey -> Held binding/request
ROOTSCHED activation -> ActivateRequest
Linux hints and candidate-plan work -> stuttering actions
```

These are not assumed preserved merely because variables have similar names.
Under the stated fixed-admission/no-renewal/single-opportunity restriction,
`DYN-REGRESSION` must define each abstraction function and check that its
dynamic invariant **implies** the following Formal 0148 property. The candidate
property set is:

```text
MonitorOwnsGlobalRegistry
MonitorOwnsCPUOnlineState
EmptyBindingExact
MonitorOwnsResidentBindings
ResidentEpochCurrent
ResidentBindingSealed
SlotGenerationFresh
NoSlotAlias
ActiveBindingExact
NoEvictWhileRunningOrReferenced
HeldBindingMatchesRequest, strengthened to exact ConsumerKey
NoDuplicateExclusiveResidency
ExclusiveAuthoritySingleCPU
OfflineCPUHasNoAuthority
NoActivationIssuedDuringRevocation
ManagementRecoveryIndependent
NoProtectionClaim
```

For the representation-specific management property, the abstraction maps the
dynamic independently protected management/recovery binding to
`managementBindingSealed = TRUE`, `managementSource = "Monitor"`, and keeps it
outside the ordinary projection slot image. If that abstraction cannot be
proved, the property is removed from the implication set rather than assumed.
The hard-coded request CPU, migration destination, fixed generation, and phase
predicates are likewise supplied only by the exact scenario restriction.

The hard-coded population, scenario-specific migration/hotplug completion, and
old wait-counter assertions are regression scenarios, not universal trace-
refinement properties. `DYN-REGRESSION` checks their dynamic counterparts.

### Formal 0147

Formal 0147 has a constant frame, immediate dispatch, and a wait bound that
does not include residency preparation. The dynamic plan is therefore not a
direct trace refinement. `DYN-ADMIT` first defines a new
`DynamicRootServicePlan` abstract specification. Its inherited restriction is
one lane with a fixed plan and always-resident exact binding, target
`Operational`, no withdrawal/revoke/maintenance/target-affecting failure,
valid clock bridge, and timely extension-only lease renewal for the entire
infinite trace. The abstract recurrence theorem also excludes terminal outer
freshness exhaustion; the concrete finite-width model handles that as a
separate terminal behavior. Under this full restriction, the following are
**property implication obligations**:

```text
NoRootRunWithoutLease
NoRootBudgetOverrun
LinuxCannotExtendRootLease
CurrentEpochOnly
ReservedSlotIntegrity
GuaranteedOnlyUsesReservedSlot
BestEffortOnlyUsesSlack
ExpiredOrRevokedAuthorityCleared
ManagementAlwaysAdmitted
LinuxCannotMintRootAuthority
NoProtectionClaim
```

Under the same restriction, the infinite properties
`AdmittedGuaranteedEventuallyRuns`, `GuaranteedRecurringService`,
`ManagementRecurringService`, and `TrustedHandoffProgress` remain inherited
obligations over exact token issuance and handoff events. The finite
`DYN-COMPOSE` two-cycle configuration is a non-vacuity and bounded-rank check;
it does not by itself discharge those `[]<>` properties for every admitted
stream. Closure requires an explicit abstraction plus induction/TLAPS theorem,
or another accepted infinite-state proof over the stable safe restriction.
The abstraction must map exact dynamic token/handoff events to Formal 0147's
`activeDomain` and handoff state; plan-fixed and resident alone are
insufficient.

Formal 0147's literal `BoundedGuaranteedWait <=
FrameLength` is not preserved unchanged: the dynamic contract replaces and
strengthens its role with a proved `ActivationTurnBound` that includes plan
distance, residency work, old-token expiry/reference drain, and admitted
renewal. Dynamic cutover then adds debt/cursor continuity and proves that
unrelated churn cannot increase that rank.

### Later entry and state composition

The exact snapshot/binding interface names `MemoryViewID`, `ViewEpoch`, backing
ownership, hierarchy, imported lease, global placement, and root-execution
identities so its pre-joint projection is total. Later composition must supply
their physical meaning plus `CodeEpoch`, entry/translation/mutable-state epochs,
and the complete `RequiredQuiescenceReceiptSet`. RESIDENCY produces only
`ActivationIntent`; the composed action installs `ExecutionContextKey` and
emits `ActivationCommitReceipt`. A token without that receipt, or whose receipt
omits any current projection/slot/boot/dependency incarnation, is invalid.

## Executable Specification Decomposition

TLA+ is intentionally deferred until this architecture receives hostile
review. The final executable contract should be decomposed rather than built as
one unbounded monolith:

The proof order is itself normative state. The machine contract stores each
node as structured `internal_predecessors`, `temporal_relies`,
`conditional_omega_relies`, `guarantee`, and `discharge_state` fields. A model
may rely only on an earlier named guarantee. It may not say "all predecessors",
assume `Operational`, assume its own liveness result, or import an unnamed
external oracle. The only unresolved authority interfaces are
`ENV_HARDWARE_TIME_ROOT`, `ENV_CLUSTER_ISSUER_QUORUM_TIME`, and
`ENV_ENTRY_CODE_STATE_INTERFACE`; their claims remain interface-conditional
until separate refinement models discharge them.

```text
ENV_HARDWARE_TIME_ROOT
ENV_CLUSTER_ISSUER_QUORUM_TIME
ENV_ENTRY_CODE_STATE_INTERFACE
  -> RESOURCE_HIERARCHY_SET_ALGEBRA
  -> DYN_ADMIT
  -> DYN_REQUEST and DYN_CHURN
  -> DYN_RENEW_RESTART
  -> DYN_SHARD
  -> DYN_COMPOSE
  -> DYN_MULTILANE_COMPOSE
  -> PER_OPPORTUNITY_RANK_THEOREM
  -> DYN_LIVENESS_THEOREM
  -> DYN_REGRESSION
```

This drawing is only a topological summary; the JSON predecessor arrays are
the complete edge set. `StableWindow`, `AuditHeadroomWindow`, and
`ProtectedClockProgressOrFailStop` are explicit temporal relies rather than
stored state. `InfiniteFreshnessSupply` occurs only on the separately
conditional omega theorem. Finite-horizon recurrence does not inherit it.

```text
DYN-ADMIT
  delegated control arbitration, conflict-local dependency/read/write sets,
  prepare/seal/commit/reject, immutable snapshot plus StreamLedger/
  PlanMembership, immutable PlanTransitionRecord plus bounded apply ledger,
  RetirementFence, capacity ledgers, join/leave/class change, and debt-
  preserving future-effective cutover with every partial-apply prefix safe

DYN-REQUEST
  tagged authority-complete ConsumerKey, exact coalescing, immutable sealed
  membership, mutable member disposition, cancel races, one terminal result

DYN-CHURN
  fixed work units/frame, control-principal fairness, best-effort flooding,
  malformed ingress, cleanup provenance, scoped security/failure fences,
  full FailureScopeIdentity recovery, SourceReplayCell DurablePending,
  ScopeTransitionTxn prepare/commit/materialize, asynchronous outbox/audit/
  checkpoint, source-health fencing, NodeMode observation, scoped overflow,
  and authority commutation

DYN-SHARD
  two or more independent plan/root/control shards, disjoint commuting commits,
  future-effective local applies, lane-local token/stop/failure/exhaustion,
  boundary apply with no cross-shard wait, covered-failure noninterference, and
  source-quiescence-before-destination exclusive placement transfer with
  cross-lane calendar/debt mapping

DYN-RENEW-RESTART
  total scoped namespace graph, quarantine, drain, exact quiescence receipt,
  ProjectionEpoch renewal, typed finite inner sequences, lane/control/lease
  clock epochs, separately owned hardware/service/quota bridge proofs,
  source/transition/scope/outbox/audit phases at every crash cut,
  boot/security/reconciled/dirty CAS, stale
  shared lease extension versus FrozenLeaseUse, security-log checkpoint versus
  scope-fence/use-vector separation, shared bridge-certificate renewal, replay,
  and completion rejection

DYN-COMPOSE
  small ROOTSCHED + dynamic residency integration, exact CurrentOpportunity,
  two bounded non-vacuous cycles, and property-implication checks under
  adversarial Linux

DYN-MULTILANE-COMPOSE
  two recurring guaranteed streams on independent lanes, their provenance
  control shards and shared protected-frame rules, one scoped failure, one
  retiring opportunity, and exclusive-transfer state; discharges cross-model
  interference not visible in isolated DYN-CHURN or DYN-SHARD

DYN-LIVENESS-THEOREM
  induction over a finite stable admitted stream set showing every stream and
  management recur under the deterministic rank/fair-action contract; not a
  finite TLC trace surrogate

DYN-REGRESSION
  migration, hotplug, revoke, replication, and exclusive placement refinement
```

Minimum state and progress evidence are frozen as follows:

| Model | Required state | Required rank/history |
| --- | --- | --- |
| `DYN-ADMIT` | snapshots, StreamLedgers, plan memberships/shards/fences, PlanTransitionRecord/apply ledger, delegated control tickets/cursor, MutationFootprint/CommitDependencyVector, root/work/record/transition capacity ledgers | read-closure and authorization-delta implication; every partial-apply prefix safe; nonconflicting commit, committed-apply, and retiring-artifact ranks |
| `DYN-REQUEST` | request/cancel cells, tagged ConsumerKey, immutable member slots/seal, disposition vector, WorkID, `MaxMembers=2`, charge | replay high-water, one winning cancel, terminal immutability, member/cleanup rank |
| `DYN-CHURN` | fixed work-unit frame, immutable CleanupClass, ingress gate, control-principal cursor/ConflictIntentReservation, canonical source/event identity, bounded SecurityDependencyCertificate/SecurityUseVector, scope cells/audit shards and derived NodeMode state | control-turn and ticket ranks unaffected by attacker ingress or peer churn; exact scoped failure/recovery, source replay, cell-before-log order, checkpoint renewal, and authority commutation |
| `DYN-SHARD` | at least two lane/plan/control shards, per-shard clocks/journals, disjoint and intersecting footprints, independently applicable committed future-effective entries, scoped failure/exhaustion, PlacementTransferRecord/calendar mapping | publication/apply commuting diamonds, every partial prefix safe, independent-lane rank, no boundary cross-shard wait, and source-quiescence-before-destination/calendar transfer rank |
| `DYN-RENEW-RESTART` | total instance-scoped namespace graph, local quarantine/wear ledger, typed inner sequences, three-clock bridge, shared lease term plus LeaseClockEpoch-bound FrozenLeaseUse, delayed stale artifacts, modeled refs, exact receipt, scoped incident/log phases at every crash cut, checkpoint/SecurityUseVector/ReconciledEpoch/DirtyArm CAS | used incarnation history; drain/renew/reconciliation ranks, no extension fanout, old-use rejection after recovery, source-event replay rejection, and exact acknowledgement history |
| `DYN-COMPOSE` | stable stream, StreamLedger/CurrentOpportunity/PlanMembership, lane root/control cells, singleton txn, binding/hold, RetirementFence, lease clock, token/budget | typed ActivationRank mapped to lane turns plus terminal rank; two releases, activations, and settlements |
| `DYN-MULTILANE-COMPOSE` | two streams/lanes, two provenance control cursors, shared management/safety rules, retiring-opportunity service, scoped audit/failure, and placement-transfer phases | one lane's cleanup/migration/failure cannot violate the other's activation/terminal bound; service-clock certificate and component rely/guarantee composition |
| `DYN-LIVENESS-THEOREM` | abstract finite stable stream set and deterministic service/rank relation | induction that each current opportunity terminates and next release recurs; exact 0147 liveness implication |
| `DYN-REGRESSION` | CPUs, replicas/reverse index, placement owner, carried debt, hotplug/migration/revoke phase | remaining authority/ref/binding/receipt lexicographic rank |

The executable models may use finite symmetry sets and bounded pools. An
unbounded conceptual sequence and a finite explicit-state checker cannot both
have a finite reachable graph. The proof boundary is therefore explicit:

```text
DYN-COMPOSE
  identity-erased finite liveness abstraction with a committed stable stream,
  at least two distinct release/ActivateHeld/terminal cycles and separate
  activation/terminal bounds

DYN-LIVENESS-THEOREM
  infinite recurrence for all stable admitted guaranteed streams and management
  over natural-number lane/control turns; required before claiming inherited
  0147 liveness

DYN-SHARD
  finite commuting/noninterference checks plus an invariant that one lane's
  stalled token, failure, or namespace retirement cannot disable a disjoint
  lane, and a separate monotonic exclusive-transfer trace in which destination
  commit requires an exact source-quiescence receipt; required before any
  scalable architecture closure

DYN-RENEW-RESTART
  concrete bounded-prefix non-aliasing through inner namespace exhaustion,
  renewal, delayed stale artifacts, and possible terminal outer failure

full infinite concrete recurrence with finite-width identities
  additionally requires an unbounded non-rollback outer-epoch theorem or an
  abstract contract that permits terminal freshness exhaustion
```

A finite model whose outer namespace may fail-stop cannot by itself prove an
infinite concrete service implementation. The liveness and freshness models
need an explicit refinement relation rather than one pretending to establish
both properties at once.

Current-state predicates such as `Feasible`, `LeaseValidForNewRelease`,
`LeaseValidForFrozenUse`, `AdmissionUsable`, `StableState`,
`BindingAuthorityKeyOf`, `CandidateDeltaConfinedToDelegation`,
receipt validity, `ClockBridgeInvariant`, and rank eligibility are operators
over canonical state, never stored Booleans. `StableWindow` is instead a
temporal trace rely. Only rollback/replay history needed to derive these facts
is state.

TLAPS is the leading candidate for the required stable recurrence induction
over natural-number turns. TLC remains useful for finite transition and
mutation exploration.
Neither tool result may be treated as protection or implementation evidence.

## Required Negative Matrix

At minimum, independent mutations must exercise:

```text
AdmissionWithoutWitness
IncompleteCommitDependencyVectorCommits
UnrelatedChangeStalesConflictLocalCommit
SignedOvercommitAccepted
PartialClassPlanCommit
PartialAdmissionSnapshotPublication
CutoverMutatesImmutableAdmissionSnapshot
LiveCursorStoredInImmutableAdmissionSnapshot
GlobalPlanEpochForcesUnrelatedSnapshotRepublish
TentativeShardEntryBecomesAuthority
PartialMultiShardTransitionCommit
PartialApplyPrefixViolatesCapacityOrAuthorization
PairwiseCommutationCertificateRequiresQuadraticProof
SharedAncestorDirectWriteBreaksMixedApplyInduction
FailureAndLaneRaceAsTwoApplyStatusWriters
CommittedPendingMembershipReleasesEarly
FirstReleaseOpportunityMaterializedAtControlCommit
SecondPendingTransitionEntersSameShard
LocalApplyRejectsCommittedTransitionAsStale
CommittedTransitionRollsBackOnApplyFailure
BoundaryAppliesWrongTransitionOrTurn
IntersectingTransitionBypassesPredecessorOrder
CrossShardCommitWaitsWithLocksHeldAcrossLaneOrHardwareWait
BoundaryApplyWaitsForAnotherShard
ExclusiveMigrationUsesOneSimultaneousCrossShardApply
DestinationCommitWithoutSourcePlacementQuiescenceReceipt
MigrationResetsCalendarOrDebtAcrossLaneClocks
CalendarTransferChoosesNonminimalDestinationTurn
CalendarTransferConvertsAcrossLeaseClockEpochOrTrustedTimeDomain
CalendarTransferActivatesBeforeNotBeforeTick
CalendarTransferRejectAfterSourceFenceRestoresSourceAuthority
BestEffortAdmissionReplacesGuaranteedPlan
RetirementFenceReopensOrLengthens
RetirementFenceForOneUseInvalidatesAnotherUse
LeaseTermRenewalExpandsAuthority
LeaseTermRenewalShortensExpiry
LeaseExtensionInvalidatesFrozenOldOpportunity
FrozenOldOpportunityInheritsExtendedExpiry
LeaseExtensionRepublishesEveryAdmissionOrPlanMembership
AdmissionSnapshotEmbedsMutableCurrentLeaseTerm
LeaseFenceReplacesEpochBeforeOldTokenStops
ExpiredLeaseTermActivatesCachedBinding
LeaseExpiredAdministrativeRecordRemainsUsable
LaneTurnStallsWhileTrustedLeaseExpires
ExpiredLeaseTickLeavesTokenExecutable
LeaseExpiryScansAllAdmissionsAtomically
ClockBridgeIdentityWithoutNumericInvariant
HardwareProgressCertificateAssumesMonitorControlOrLaneFairness
IndependentLeafServiceCertificatesOverbookSharedParentExecutor
OnePhysicalServiceOpportunityAdvancesTwoControlShards
TargetQuotaConsumesTurnsBeforeItsAnchor
RankUsesMaximumWithoutParallelNoninterferenceCertificate
AdmissionSnapshotEmbedsCurrentClockBridgeCertificate
BridgeExtensionRepublishesAdmissionOrMembership
FutureLeaseRenewalUsedAsCurrentAuthority
OldAuthorityUseReleasesAfterCutover
RetiringActivationPastAuthorizedHorizon
LeaseExpiryMarksOpportunityActivated
BindingKeyProjectionOmitsParentIncarnation
BindingKeyProjectionOmitsExplicitViewOwnershipInput
BindingRelevantChangePassesCompatibility
ServiceOnlyUpdateMintsNewBindingAuthority
CandidateDeltaWeakensUnrelatedLineage
CommitWritesOutsideMutationFootprint
RejectLeaksCapacity
PlanCommitResetsDebt
PlanInsertResetsCursor
PlanCutoverDropsBoundaryRelease
PrepareIntentConsumesReleaseCreatedInSameBoundary
ControlStepCreatesAndCommitsCandidateSameBoundary
PlanChurnStarvesSurvivor
PlanChurnPreventsReleaseCreation
NonConflictingControlNeverCommits
FailureStopsLaneOutsideSelectedCoverWithoutNodeFailStop
DisjointShardCommitStalesOtherShard
LinuxCreatesGuaranteedObligation
LinuxOmitsActivateForever
LinuxDenyGatesGuaranteed
RootIssuesMultipleOutstandingSequence
NonServiceSettlementMarksOpportunityActivated
TerminalSettlementMissesNextReleaseBoundary
MaintenanceSkipsExactDueReleaseWithoutRecord
StreamRenewalRelabelsLiveOpportunity
BindingRelevantUpdateResetsOpenOpportunityRank
FailureModeVacuouslySatisfiesLiveness
ScopedFailureWeakensUnaffectedContract
FailureReceiptNamesUnrelatedVictim
NodeSecurityHighWaterAdvanceInvalidatesAllAdmissions
SecurityEventAdvancesHighWaterBeforeScopeFence
UnrelatedSecurityEventInvalidatesDirtyArm
GlobalStopWithoutNodeScopeFence
RecoveryUsesAggregateModeAndUnrelatedFailureStalesIt
FailureNamespaceParentRotatesOnEverySecurityEvent
FailureEventIdentityDependsOnGlobalAuditOrder
DisjointFailureAuthorityUpdatesDoNotCommute
RecoveredFenceReenablesPreFailureToken
RepeatedReceiptForFencedScopeConsumesAuditEpoch
ScopeFailureCapacityOverflowStopsDisjointLane
SourceHighWaterAdvancesBeforeScopeCommitAndCrashLeavesReceiptStaleUnfenced
DurablePendingReferencesUndurableTxnOrNeedsSourceRetransmission
ScopeCommitsPerCellInsteadOfOneTransactionDecision
PreparedScopeSuccessorTreatedEffectiveBeforeCommitBit
CommittedScopeReadsRawCurrentBeforeMaterialization
ScopeConflictHasNoResumeAbortCoveredOrEmergencyFencePath
AuditCompletionGatesClearsOrRenamesAuthorityFence
AuditRetryAllocatesSecondPositionForSameEvent
SourceFreshnessExhaustionRejectsIngressButLeavesDependentAuthorityExecutable
FailureRecordRecycledWithScopeReferencePendingOutboxOrUnacknowledgedCheckpoint
RestartResumesOrdinaryWithUnresolvedPendingOrUnmappedOldBootFence
FailureEventHasNoCanonicalSourceOrBoundedScopeVector
UnboundedSecurityUseVectorOrPopulationScan
RequestIDBodyEquivocationAccepted
RequestIDReused
IncompatibleIntentCoalesced
BestEffortCoalescesIntoGuaranteedWork
DistinctOpportunitiesCoalesced
LaterRequestOverwritesOlderAgeOrCharge
AttachAfterSharedPhysicalSideEffect
StaleSealedMembershipGenerationPublishesHeld
StaleDispositionGenerationPublishesCancelledMember
CancelDropsOtherMember
SecondCancelAllocatesAnotherPendingRecord
StaleCancelHitsNewEpoch
CancelCompleteBeforeCleanup
CancelledRequestBecomesReady
ReadyMakesCancelNondeterministic
CompletionAfterRevokeMutatesNewWork
BestEffortConsumesGuaranteedCell
WorkAccountingMixesCreditsAndRecordUnits
GenericRefillMintsWorkUnitsOverUnsettledWork
ActiveTokenResidualIsUnownedOrDoubleCharged
RevokeReclassifiesCleanupToStealProtectedLane
PeerControlChurnStarvesGuaranteedControlPrincipal
ControlCursorScansAllEmptyPrincipalSlots
BestEffortCancelFloodStarvesCleanup
CleanupBacklogExtendsStoppedToken
InfiniteBoundedIngressStarvesProtectedTurn
OverflowDropsOrOverwritesGuaranteed
OverflowEntersUnguardedDegradedMode
StaleFailureReceiptReentersRecoveredMode
FailureEventReplayAmbiguousAcrossSecurityAdvance
StaleRecoveryReceiptClearsNewerFailure
MalformedHintTriggersGlobalScan
BestEffortDrainsPinnedVictim
UnboundedVictimDrainAssumedComplete
HeldBindingStolen
StaleWorkerCompletesNewSlot
GenerationWrapAlias
FiniteNamespaceWithoutAllocatorOrTerminalExhaustion
ReplaySensitiveSequenceMissingFromRegistry
NamespaceRegistryParentDisagreesWithCheckedGraph
NamespaceOwnerScopeEscapesOnExhaustion
AttackerSequenceJumpForcesNamespaceRenewal
PrincipalExhaustionBumpsNodewideEpoch
RejectedCandidateConsumesAuthoritativeGeneration
ProjectionRenewalBeforeDrain
QuiescenceReceiptFromWrongDrainOrProjectionAccepted
QuiescenceReceiptReplayAcceptedAfterRenewal
ProjectionRenewalCancelsGuaranteedObligation
OldBootArtifactAccepted
RestartRestoresLinuxShadowAuthority
RestartReimportsOldRevokedLease
CrashBeforeLocalRevokeAckReimportsDomain
ReconciliationRootClearedWithActiveDomains
DelayedReconciliationAckClearsNewerEvent
DirtyArmAdvancesReconciledEpoch
FreshLeaseInvalidatedByDirtyArm
OrdinaryAuthorityPublishedBeforeExecutionDirtyArmed
SecurityAuditFailureResumesOrdinaryDomainsOrUndoesFence
ControlLostReplyDuplicatesCommit
ControlAbortAfterCommitRollsBackPlan
ControlAbortLeaksReservation
ControlOperationAcceptedWithoutTerminalProgress
UntrustedBuilderStallsAcceptedControlOp
HotplugWithoutTransitionWitness
MigrationActivatesBeforeSourceStop
HardwareTimeoutTreatedAsQuiescence
ManagementRecoveryReserveRemoved
LinuxGatesGuaranteedProgress
RekeyTerminalStutter
ObligationIdentityDefinitionsDiverge
ProtectionClaimFromModel
SecurityUseVectorOmitsFailureNamespaceOrResourceIncarnation
TopologyClosureChangesWithoutFencingOldSecurityDependencyCertificate
UnboundedTransitionShardSetOrUncheckedPrefixCertificate
MixedAppliedFailedFencedPrefixLeaksAuthorityOrCapacity
CommittedPendingPlanReservationHasNoOwner
BestEffortChurnConsumesGuaranteedNamespaceWearHeadroom
SharedNamespaceRenewalPausesUnwitnessedPeerContract
ConflictPeerOvertakesSelectedGuaranteedControlIntent
NormalRecurringLedgerProgressStalesEveryControlCommit
DelegationEffectOccursAfterSealedAuthorizationHorizon
FrozenLeaseUseComparedAcrossLeaseClockEpoch
ClockBridgeFieldsWithoutDeltaInequalities
LaneAdvancesBeyondCertifiedControlQuota
ClockViolationStuttersWithoutFenceAndStop
LeaseTickStuttersForeverWhileTimeBoundedLivenessRemainsClaimed
FirstReleaseAtOrBeforeMembershipEffectiveBoundary
CancelDuringRevokeExpiryFailureOrCleanupHasNoTotalResult
SingleLaneComposeHidesCrossLaneControlWorkInterference
FailureInputReplayAllocatedBeforeSourceReceiptFreshnessCheck
FailureAuthorityMaterializesAllDependentContracts
FailureEventExceedsKFailureScopesWithoutCanonicalCover
AuditStateAssumedInfiniteAcrossUnboundedUnrelatedFailures
IncidentCrashCutMissingFromRestartComposition
MigrationFencesSourceWithOpenCurrentOpportunity
MigrationUsesPrevalidationCalendarInsteadOfFinalSourceReceipt
PlanCutoverStrandsReleasedRetiringOpportunity
CurrentOpportunityRequiresObsoleteRetirementFenceGeneration
ScopedOperationIDOmitsNamespaceOwnerRoot
BestEffortAuthorityUseIDAliasesAnotherUse
OldClusterIssuerIncarnationLeaseAccepted
MonitorLocalRevokeMintsIssuerDomainEpoch
Formal0147RestrictionOmitsLeaseFailureOrClockPremise
AdmissionAcceptsVectorOrProofWiderThanNodeConfig
HierarchyLeafOverbooksAncestorReservation
ReparentRelabelsLiveOldPathAuthority
ControlAndExecutionCertificatesDoubleSpendOneSharedHardwareCell
TwoLaneCertificatesDoubleSpendOnePhysicalCpuCell
ActivationIntentConsumesCellBeforeJointActivation
LanePublishesExecutionCellLeaseWithoutAllocatorDebitedScheduleOccurrence
ExecutionCellLeaseMutableStateHasMultipleWriters
ExpiredExecutionCellLeaseCarriesForwardToLaterTurn
OnePhysicalExecutionCellConsumesTwoLeasesOrTokens
TwoActiveTokenOwnersShareOnePhysicalContext
RunTokenBudgetExceedsExecutionCellDuration
ControlMicrostepForAAdvancesTargetControlTurnB
TargetQuotaUsesShardControlTurnAsReusableCredit
UntypedNodeLeaseOrNetworkReachabilityAcceptedAsAuthority
DisconnectedNodeExtendsOrChangesPartitionMode
ConnectedOnlyActivatesWithoutCurrentConnectivityEvidence
RecoveryOnlyAllowsOrdinaryActivationWhileConnected
ConservativeExpiryUsesLatestRatherThanEarliestSafeLocalDeadline
ExclusiveSnapshotOmitsGlobalPlacementUse
LeaseExtensionCreatesAuthorityBeyondGlobalPlacementHorizon
NetworkSilenceAcceptedAsSourceQuiescence
DestinationActivatesBeforeMaximumPredecessorResidualEffectHorizonAndStopBound
TimeSupersessionAcceptedForUnboundedOrIrreversibleEffect
QuorumSupersessionClaimsContinuityWithoutSettlementPrefix
MigrationGapMeasuredFromSourceStopInsteadOfLastDeliveredService
OversizedFailureClosureIsTruncatedRejectedOrAllowedToStutter
FailureCoverChoosesNonuniqueAncestorWithoutTreeOrTieBreak
FailureCoverIgnoresSourceTimeTopologyGeneration
FailureCoverOmitsIntermediateTopologyGenerationStillReferencedByLiveAuthority
FailureCommitLeavesCapacityBothCurrentAndFailureEscrow
LiveScopeUsePublishesWithoutReverseEdgeOrCleanupReservation
FailureCleanupTraversesBeyondChargedActualUseCap
ResidentReadyOrActivationIntentCountsAsService
ActivationCommitReceiptWithoutDeliveredExecutionCountsAsService
ZeroDeliveredTicksWithoutPostEntryYieldCountsAsService
ActivationContextOmitsEntryCodeViewTranslationOrStateEpoch
MissingQuiescenceClassTreatedAsNotApplicable
RunTokenExistsWithoutActivationCommitReceipt
ActivationRetryMintsSecondActivationIDReceiptOrRunToken
ExecutionCellLeaseReferencesFutureActivationIntent
RunTokenReplayAfterCellOrSettlementReentersContext
MixedClockDeadlinesUseNakedIntegerMinimum
CancelAndActivationWinDifferentDecisionCells
DeliveryCrashRecountsBudgetServiceOrReceipt
FailureClosureStopsBeforeLeastFixedPoint
FailureLCAExceedsUnchargedAncestorCleanupCapacity
HardwareAndChildFramesDoubleAssignPhysicalOccurrence
WatchdogAndLeaseClockBothStutterWhileTimeLivenessRemains
CrossNodeGapSubtractsUnrelatedClockTicks
SettlementPrefixPredatesSourceWriteClose
FiniteNamespaceExhaustionStillClaimsOmegaRecurrence
ComponentAssumesDescendantGuaranteeOrInternalOperationalState
PreGateCrashRetryMintsNewActivationDecisionOrExecutesOutsideOriginalCell
JointActivationFailureLeavesPartialExecutableContext
CrashBeforeFinalValidBitLeavesExecutableStagingContext
ManagementRecoveryProgressAssumedWithoutBootstrapContract
OrdinaryAdmissionBorrowsManagementExecutionOrNamespaceReserve
ManagementBootstrapFailureFallsBackToOrdinaryLinux
FreezeRequiresExecutableModelThatIsForbiddenBeforeFreeze
ReviewCapsuleReusesReviewerOrOmitsFindingDisposition
CandidateBytesMutateAfterCapsuleSealBeforeReview
UnpinnedRepositoryLocalTrustPolicyAcceptedAsReal
UnsignedReviewerNamesAcceptedAsIndependentIdentity
LocalFixtureClaimsArchitectureFrozen
```

Faults that remove a declared liveness assumption must fail the associated
liveness property rather than being hidden by an unrelated safety invariant.
Mutation-to-property specificity remains an EC1 validation requirement.

## Alternative Analysis

| Decision surface | Smaller or tempting alternative | Failure | Frozen reference direction |
| --- | --- | --- | --- |
| guaranteed activation | Linux submits or approves every activation | omission, stale `Deny`, or rq corruption becomes cross-Domain availability authority | Monitor-generated obligation and internal `ActivateHeld` |
| admission state | one mutable object owns authority, recurrence cursor, and plan placement | renewal or plan movement silently rewrites frozen authority and makes replay identity ambiguous | immutable `AdmissionSnapshot`, mutable `StreamLedger`, and replaceable `PlanMembership` |
| root policy | one mutable node-wide plan edited in place | no atomic old/new release owner; unrelated updates serialize and one lane can stop all service | independently advancing immutable plan shards with conflict-local boundary commits |
| plan algorithm | put a production hierarchical scheduler in the first model | obscures the minimum transition contract and expands TCB assumptions | fixed finite table as executable reference; bounded certificate refinement later |
| residency identity | full `AdmissionSnapshot` equality for every binding | safe service-only updates force global cache churn and hide which fields actually protect backing | explicit complete `BindingAuthorityKey` plus compatibility predicate |
| plan cutover fence | one fence per snapshot or a same-boundary survivor exception | one membership can revoke another, or ordering admits a token under retired authority | monotonic fence per exact `AuthorityUseID`, published before post-commit token issue |
| lease identity | one version for rights and every term extension | either term renewal needlessly invalidates frozen use or stale rights survive attenuation | issuer authority epoch plus extension-only terms; old frozen use keeps only its original expiry |
| lease term placement | embed current term/expiry in every immutable admission snapshot | each extension requires population/plan republish and contradicts the shared-record locality bound | stable envelope in AdmissionSnapshot; current term in shared LeaseAuthorityRecord; exact FrozenLeaseUse at release |
| lease expiry | scan every admission and publish administrative state changes atomically | expiry cost scales with population and cleanup delay becomes authority | shared lease record plus trusted lease tick; token validity is combinational and active lanes stop within a numeric bound |
| time | one logical service turn for release, control, and expiry | held service or control work freezes unrelated authority expiry and progress | independent lane, control, and trusted lease clocks connected by checked numeric certificates |
| bridge certificate placement | embed one current lane/timebase certificate in every admission snapshot | certificate renewal or lane movement republishes immutable authority and scales with population | one shared record per lane/control/lease triple; control/release freeze exact live certificate in operation/opportunity |
| control commit | revalidate one node-wide or exact hot-cursor snapshot | unrelated churn or ordinary recurrence rejects stable operations and creates a serialized coordinator | parameterized delta template, typed dependency relations, fair conflict intent, and final atomic current-state instantiation |
| multi-shard cutover | require independent lane boundaries to commit simultaneously or wait on a predecessor at apply | independent clocks have no common boundary; locks, wait guards, or a barrier couple unrelated progress | atomically commit only independently applicable local deltas; exclusive placement is source fence/quiescence followed by destination commit |
| asynchronous apply safety | prove only the all-old and all-new plan states | a reachable partial-apply subset can overcommit or violate a cross-lineage invariant | commit certificate covers every reachable apply prefix and retains union capacity until settlement |
| migration calendar | copy source `nextReleaseTurn` directly or choose a fresh destination cursor | independent lane turns are incomparable and service debt can disappear | exact source/destination clock bridge, last settlement, debt, gap, and first-release mapping in PlacementTransferRecord |
| async work | overwrite one pending Linux work carrier with latest caller | `queue_work()` coalescing loses age, authority, charge, and cancellation identity | Monitor `WorkID`, sealed bounded member slots, stale-generation rejection |
| coalescing | attach compatible callers at any txn phase | late authority changes after shared effects create unprovable cancel/refund ownership | attach only before side effect and seal membership in v1 |
| overload | one strict-priority FIFO | attacker or recovery flood can starve another protected class; cleanup can be orphaned | provenance-partitioned fixed protected frame and reservations |
| accounting | one scalar for records, work, and CPU budget | units mix; rollover/refund can mint service or execution authority | no generic refill in v1; separate records, work units, root reservations, token budget, and charge ledger |
| stale feasibility | retry/rebuild forever under one accepted op | valid churn pins a protected operation cell and defeats terminal progress | one bounded preparation and atomic revalidation, then typed stale rejection |
| recurrence state | keep live `nextReleaseTurn` in immutable admission authority | each release changes authority identity and makes plan reuse impossible | mutable ledger owns cursor, sequence, current opportunity, settlement, debt, and rank envelope |
| maintenance | suppress a release when its due boundary arrives | an already-due obligation disappears without an auditable predecessor transition | finite skip record committed before the first covered release and cursor advanced before equality |
| stream renewal | relabel a live opportunity with a new incarnation | completion and debt can be attributed to authority that never released the work | terminal-first renewal and an explicit successor record carrying continuity state |
| failure scope | receipt names arbitrary affected Domains or node mode weakens all contracts | compromised control can revoke unrelated guarantees and failure handling becomes a policy escape | Monitor-derived ownership closure and per-stream operational state; unaffected contracts remain unchanged |
| security event ordering | use node-wide security-log high-water as every admission's exact authority epoch | one scoped event revokes every Domain and unrelated churn stales recovery | publish typed ownership-scoped fence first; high-water is reconciliation/audit history, and recovery compares affected scope generations |
| failure identity and logging | put global audit positions in FailureEventID, trust Linux-forwarded evidence, or append before fencing | replay allocates fresh events, disjoint effects couple, or log failure forgets an unfenced incident | source-owned replay identity, bounded per-scope incident cell/fence first, independent audit-shard append and checkpoint |
| failure recovery token freshness | clear a recoverable fence without versioning each execution use | a sealed pre-failure token can become executable again after clear | every release/hold/token binds exact SecurityUseVector; scope generation never rolls back |
| failure/use scope representation | unbounded resource closure or caller-selected event owner | hot-path population scan, ambiguous replay namespace, or attacker-chosen victims | admission-bounded canonical SecurityUseVector and source-derived canonical FailureEventOwnerScopeID |
| generation exhaustion | finite counter wrap or probabilistic ignore | old completion or receipt can alias current authority | stop, drain, typed receipt, outer renewal, or fail-stop |
| restart | reconstruct from Linux shadow, or advance one generation for both reconciliation and dirty arming | revoked authority resurrects, or freshly obtained leases self-invalidate | non-rollback boot/security roots, distinct reconciled and dirty-arm generations, and tuple-bound re-attestation |
| liveness evidence | store `SemanticallyStable` as a Boolean or add heterogeneous counters | the model can assert its own rely and compare quantities with no common unit | temporal stable-window rely plus typed lexicographic rank and checked conversion to lane turns |
| namespace exhaustion | bump a whole-node boot epoch when a local sequence ends | a local attacker obtains global restart authority | complete typed parent graph; local owner is quarantined or its lane is nonaccepting until independently authorized reboot |
| residency scale | eagerly resident global Domain set | memory and scheduler state scale with datacenter population | node admission directory plus bounded per-CPU projections |

The fixed table, one commit revalidation, pre-side-effect membership seal, and
one release materialization plus one root dispatch per turn are conservative
reference choices. They may be
replaced for production performance only by a refinement that preserves the
frozen identities, owners, conservation equations, terminal outcomes, and
numeric progress rank. The Monitor should validate bounded plans and
certificates; general optimization and large searches remain outside its TCB.

## Rejected Designs

```text
one Linux FIFO for guaranteed, best-effort, and cleanup work
Linux runnable state as the source of guaranteed requests
Linux result or callback as a gate for guaranteed ActivateHeld
coalescing by DomainID alone
overwriting a pending work carrier with the latest caller
attaching a new consumer after shared physical side effects begin
mutating sealed membership after side effects instead of separate disposition
timeout treated as cancellation or quiescence
free quiesced Boolean or receipt without exact drain/object-set identity
admission by guaranteed-Domain count or CPU utilization alone
mutable plan update in place
one node-wide plan, commit lock, or service clock for independent lanes
node-wide candidate snapshot equality as the commit conflict rule
exact equality on a normally advancing StreamLedger as the commit conflict rule
control fairness without a bounded conflict-intent ordering point
an incomplete commit dependency vector or an undeclared commit write
staling an accepted operation because only an unrelated shard changed
committing one multi-shard operation independently at several lane boundaries
putting a cross-shard predecessor wait inside a lane-boundary apply
accepting a multi-shard transition without a bounded compositional proof for
every mixed terminal prefix
an unbounded transition shard set or a free all-prefixes-safe Boolean
an apply failure branch without total membership/fence/capacity effects
exclusive migration as one simultaneous source/destination boundary update
copying or resetting a service calendar between incomparable lane clocks
migrating an open CurrentOpportunity or freezing its calendar before source
quiescence
holding cross-shard locks while waiting for a lane, token, drain, or hardware
tentative or committed-pending membership treated as execution authority
local apply that revalidates, rejects, or rolls back an already committed plan
plan cutover that resets debt or cursor
plan cutover that preserves an old opportunity record but removes all root
service reserved to activate or settle it
putting cutover-derived retirement horizons inside immutable AdmissionSnapshot
putting a live recurrence cursor or plan epoch inside AdmissionSnapshot
one retirement fence per snapshot when several authority uses can coexist
an unspecified or reusable best-effort AuthorityUseID
same-boundary token survivor exceptions after a plan cutover
best-effort permission to drain active/held victims
global task/rq scan on a residency miss or revoke
slot generation wrap or whole-node epoch bump on every replacement
restart recovery from mutable Linux shadow state
restart reimport from an old unbound node lease
lease reimport without exact current ClusterIssuerIncarnation
Monitor local rejection represented by minting an issuer-owned DomainEpoch
advancing reconciliation identity while arming the execution-dirty marker
whole AdmissionSnapshot equality as the only binding-compatibility rule
lease-term extension that silently expands the authority envelope
embedding the mutable current lease term in every AdmissionSnapshot or membership
lease-term extension that invalidates an already-frozen opportunity
an old frozen opportunity inheriting a later extension expiry
lease shortening or attenuation without stopping the old authority epoch
lease expiry implemented as an atomic scan over all admissions
lease expiry driven by a service lane rather than a trusted lease clock
clock identity without a checked numeric rate and stop-bound relation
lane/control fairness without an executable service-quota inequality
reusing one shard ControlTurn as progress credit for every active target
independent lane certificates that double-spend one physical CPU opportunity
per-admission maxima larger than boot-sealed NodeConfig widths
optional hierarchy semantics with no ancestor capacity or fence equation
an untyped cluster lease, network reachability, or silence as placement truth
cross-node destination activation before the predecessor's maximum possible
executable horizon and stop bound
numeric lease comparison across LeaseClockEpoch
storing the current ClockBridgeCertificate in every AdmissionSnapshot
all guaranteed Domains simultaneously resident despite fewer slots
unbounded waiter, retry, replay-result, or terminal-history storage
cancellation table that omits revoke, expiry, failure, cleanup, or settling
strict priority without reserved normal-mode service
one accounting scalar that adds operation records to service credits
accounting-epoch rollover that frees unfinished work
recycling namespace publication wear or allowing best-effort churn to spend
shared guaranteed renewal headroom
maintenance that notices an exact-due release and suppresses it afterward
stream-incarnation renewal that relabels a live opportunity or token
failure receipts that choose victims outside authoritative ownership closure
truncating or rejecting an oversized real failure while authority continues
failure cleanup with no admission-charged reverse-edge and service bound
NodeSecurityEpoch high-water equality used as a universal execution fence
recovery CAS over aggregate NodeMode instead of affected scope generations
putting global audit pre/post positions inside FailureEventID
failure replay lookup keyed only by the internal event ID allocated afterward
materializing every dependent Domain at the scope-fence authority point
clearing a recoverable fence without permanently staling predecessor tokens
allocating new audit positions for repeated receipts while a scope is fenced
logging forgettable event detail before a protected incident cell and scope fence
clearing an incident cell while another pending event remains
caller-selected failure-event owner or unbounded SecurityUseVector
one lane failure, stop, or namespace exhaustion that blocks a disjoint lane
reconciliation acknowledgement without exact current-root compare-and-swap
an incomplete namespace parent/allocator/exhaustion map
duplicate or divergent definitions of opportunity identity
stored stability truth in place of an explicit temporal rely
ResidentReady or ActivationIntent treated as a RunToken or service event
an activation receipt that omits a dependency class or interprets absence as N/A
management/recovery availability with no boot-root context and capacity contract
one scalar sum of counters with different dimensions
unguarded degraded mode as an escape from a software invariant breach
weak fairness presented as a numeric or wall-clock bound
```

## Architecture Freeze Candidate

TLA+ begins only after a separate valid freeze record has authenticated the
exact candidate bytes and unresolved-finding disposition.  This section lists
freeze candidates; it is not itself that record.

The following are candidates to freeze before TLA+:

```text
NodeConfig fixes every accepted hierarchy/vector/proof/reverse-edge width;
DomainHierarchyCertificate binds an exact ancestor capacity and fence path,
including the valid depth-one flat specialization
typed NodeLeaseImportCertificate fixes no-fork lineage, conservative clock
interval, offline horizon, and immutable partition mode; GlobalPlacementUse
fences every exclusive/replicated executable artifact and residual effect
across nodes; new authority uses the minimum horizon and lease-only extension
cannot extend placement
guaranteed admission atomically publishes AdmissionSnapshot, StreamLedger,
committed-pending PlanMembership, immutable PlanTransitionRecord, reservations,
and a future first-release schedule for the exact affected shard set
best-effort-only admission publishes no guaranteed stream or plan membership
AdmissionSnapshot is immutable lineage authority and contains no live cursor or
global/plan-shard epoch or mutable lease term; StreamLedger owns recurrence,
PlanMembership owns current plan placement, and release creates FrozenLeaseUse
delegation-confined CommitDeltaTemplate declares an exact MutationFootprint,
typed dependency relations, and an effect horizon; final commit instantiates
live cursor/debt/boundaries atomically
a selected guaranteed-control ConflictIntentReservation cannot be overtaken by
an overlapping peer; stable authorized feasible input must commit, while every
typed reject has a false-premise witness
control commit seals the complete bounded future-effective shard transaction;
tentative/pending entries cannot run, and local boundary apply cannot revalidate,
reject, roll back, or wait for another shard
owner-partitioned local deltas and a sparse aggregate-contribution induction
imply safety for every mixed Pending/Applied/FailedFenced state without
pairwise proof; each entry has one status writer and union transition/failure
capacity remains charged until settlement
exclusive placement is a monotonic source fence/quiescence-receipt then
destination-commit protocol: source receipt requires no current opportunity and
seals the boundary-final calendar/debt/last delivery used at destination;
quorum supersession waits beyond every residual-effect horizon and requires a
replicated settlement prefix or explicit continuity loss, never a simultaneous
independent-lane apply
root CPU service and Monitor control work are distinct planes but share one
HardwareCapacityRootCertificate whenever they use the same physical context
root execution is partitioned into finite lane allocations; the allocator
issues immutable already-debited ExecutionCellLeases, protected control binds
one through its single-writer ExecutionCellUseCell and prepares an
ActivationIntent without consuming a cell, and one due physical cell consumes
at most one lease/token, never carries forward, and forces exit/handoff before
another owner
disjoint boundary, commit, stop, and failure actions commute
lease/hardware-progress, protected-service-opportunity, control, and lane clocks
are distinct; external hardware progress, internal parent-conserved service,
and target-local anchored quota over exact TargetControlTurn form the checked
ClockBridgeCertificate; one shard turn can pay at most one target microstep
bridge records bind exact hardware-progress proof, service-allocation path, and
fresh target quota anchor; admission stores only requirements and each live
operation/opportunity freezes its full component identity
surviving service debt and ledger cursor continuity cross plan epochs
guaranteed obligations are Monitor-generated and one-shot per sequence
one bounded CurrentOpportunity freezes exact snapshot, membership, authority
use, FrozenLeaseUse, SecurityDependencyCertificate/SecurityUseVector,
release-observed fence history, binding key, lane, and rank until terminal;
residency binds only an allocator-issued future immutable cell lease through
its single-writer use cell and produces a non-executable intent; due-cell joint
ROOTSCHED/ENTRY/CODE/STATE activation validates the complete context and typed
receipt set, commits one ActivationDecisionCell, stages inert state, publishes
one final valid gate, derives one ActivationID/token, and emits a recoverable
ActivationCommitReceipt; only a qualifying ExecutionDeliveryReceipt counts
service
terminal settlement and cleanup have protected progress and complete strictly
before the next period under the admitted bound
new first release is strictly after its membership effective boundary
logical service obligations and physical residency work are distinct
immutable full AdmissionSnapshot projects through total
BindingAuthorityKeyOf; monotonic RetirementFence is separate
RetirementFence is monotonic per exact AuthorityUseID, publishes before a
post-commit token, names at most one preserved released opportunity, and has no
predecessor-token generation exception
lease issuer authority epoch is distinct from extension-only term renewal;
frozen old-term use keeps its original rights and expiry but cannot inherit the
extension
one shared LeaseAuthorityRecord and TrustedLeaseClock invalidate new and active
use without per-admission fanout; extension republishes no snapshot or plan
membership, and active lanes stop within the certified bound
plan cutover ends old membership release authority while preserving only
bounded already-released opportunity settlement authority
maintenance records and advances every skipped finite release interval before
its first covered due boundary
stream-incarnation renewal settles all live artifacts first and transfers only
explicit continuity state through a StreamSuccessorRecord
only exact immutable PhysicalKey values may share physical work
coalesced membership is bounded and sealed before shared side effects
post-seal cancellation changes only replay-fenced member disposition;
pre-activation cancel/stop and activation share one ActivationDecision while
post-activation stop and one terminal settlement remain separately monotonic,
with a response for every phase
protected work lanes and capacity-reserved operation state are mandatory
work units, operation records, root reservations, execution-cell states, token
budget, delivered ticks, and charges use separate conservation ledgers with no
generic refill; committed-pending root
capacity has an explicit owner and namespace publication wear is nonrefundable
and sponsor-reserved
best-effort overflow is bounded rejection; guaranteed overflow is a fault
generation wrap is forbidden; a total scoped namespace graph quarantines local
exhaustion without attacker-triggered boot renewal
every replay-sensitive finite sequence is present in that same checked registry
and parent graph; renewal requires zero modeled references and an exact typed
receipt whose physical meaning is discharged by later components
fresh MonitorBootEpoch fences restart; Linux shadow never restores authority
current ClusterIssuerIncarnation plus issuer Domain/lease epochs are distinct
from Monitor-owned local narrowing generations; scoped IDs bind full owner roots
protected NodeSecurityEpoch checkpoint and reconciliation root prevent crash-forgotten
node-local revoke from silent reimport; ReconciledEpoch and DirtyArmGeneration
advance separately, and leases/admissions bind the exact reconciled/dirty tuple
structured source failure evidence first enters source-owned DurablePending;
the transaction owner then allocates and links its exact precharged slot before
fencing or high-water advance; failure/recovery uses total
CanonicalFailureCover over the source/current and every live-authority-
referenced intermediate topology-generation union: exact bounded closure,
unique boot-fixed FailureCoverTree LCA, or node fail-stop, and never materializes an affected-Domain
population at the authority point; every live scope use precharges a reverse
edge and protected cleanup reservation; the commit bit atomically transfers
selected capacity to FailureEscrow
NodeSecurityEpoch is a non-rollback reconciliation/audit high-water, not a
universal fence; typed SecurityScopeFence publishes first, and recovery compares
only exact affected FailureScopeGeneration values
FailureEventID binds a canonical source and bounded scope vector independent of
audit positions; DurablePending precedes one commit-bit scope fence, while
outbox/audit/checkpoint remain asynchronous; disjoint authority effects commute
and replay cannot consume new audit state
every release, hold, activation, and token binds current SecurityUseVector;
recovery never rolls generations back or revives a predecessor token
failure events have structured source identity; SecurityUseVector keys equal an
immutable admission-bounded SecurityDependencyCertificate with full enclosing
freshness and required source-health scopes; recycle requires no scope refs,
terminal outbox, audit/checkpoint/reconciliation coverage, and a fresh generation
guaranteed control principals receive deterministic bounded arbitration
ManagementRecoveryBootstrapContract is installed from the protected boot root
before ordinary admission and owns independent physical execution, control,
clock, namespace, audit, failure, and cleanup resources; failure is node fail-stop
fixed finite pools, explicit temporal stable windows, typed lexicographic ranks,
checked sequential hardware/service/quota rank conversion, and explicit audit-headroom/renewal windows
bound liveness claims
dynamic root-plan behavior remains a mandatory RESIDENCY-DYN sub-contract
a pre-formal two-lane architecture trace/witness checks locality, commutation,
independent progress, and noninterference before candidate sealing; the sealed
candidate is reviewed only through externally pinned Assurance Protocol v2,
which derives a separate freeze record without mutating candidate bytes;
executable DYN-SHARD follows a valid freeze record before model closure
```

Still deliberately unselected:

```text
production root scheduler algorithm and certificate encoding
flat versus hierarchical server implementation
directory hash/tree/shard representation and exact capacity
literal queue implementation and work-lane ratios
exact period/deadline public ABI
cryptographic token format and key hierarchy
Linux adapter, task fields, hooks, or public syscall/API
architecture-specific timer, interrupt, TLB, and backing-quiescence mechanism
process/container granularity policy thresholds
```

## Non-Claims

This architecture contract is not yet an executable proof, EC1 decision,
Monitor implementation, Linux patch, source-hook selection, protection result,
wall-clock guarantee, performance result, cost result, multi-node protocol, or
deployment approval. It does not complete `RESIDENCY-DYN-001` until hostile
redesign, externally attested semantic freeze, decomposed executable models, negative validation,
claim-specific Evidence Capsule validation, and an explicit approval decision
all succeed.

The next step is to complete semantic hostile mutations and a fresh internal
counterexample review, then implement Assurance Protocol v2.1 checkpoint,
retention, hermetic-receipt, and commit/reveal verification. One exact capsule
must then receive a valid external freeze. TLA+ begins only when the separate
freeze record authorizes formalization of that unmodified capsule.
