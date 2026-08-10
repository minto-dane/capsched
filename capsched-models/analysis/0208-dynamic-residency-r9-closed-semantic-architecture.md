# Analysis 0208: Dynamic Residency R9 Closed Semantic Architecture

Status: rejected by Analysis 0209 and Validation 0296; exact reviewed snapshot
`f7e9f3df695af3015681da99a48bffcc44fe916588da66230fff82be5b411362`;
retained as discovery and regression evidence only

Date: 2026-08-09

Work record: `N-196`

Requirement: `RESIDENCY-DYN-001`

Predecessor disposition: Analysis 0207 and Validation 0295 reject the exact R8
snapshot. This R9 candidate was reviewed at the digest above and rejected by
Analysis 0209 and Validation 0296. Rejected R6 through R9 prose is
counterexample input only and is not inherited normatively by R10.

## Purpose And Exact Claim Ceiling

R9 defines the node-local dynamic admission, recurring opportunity, execution-
authority, protected dispatch, runtime accounting, failure closure, and
transfer protocol needed before a machine semantic IR can be encoded. Its
purpose is to remove implementer choice, not to make the model appear complete
by hiding physical or distributed assumptions.

The strongest eventual R9 component claim is conditional:

```text
Given the exact provider formulas in this artifact, every physical CPU interval
attributed to a Domain is authorized by one current, parent-conserved,
generation-bound dispatch use; no such use executes twice or after its local
authority horizon; root, SchedContext, and execution budgets are conserved;
scope close, failure, crash, migration, and transfer cannot resurrect or
duplicate CPU execution authority; and every admitted guaranteed opportunity
reaches its required verified CPU service or one exact claim-excluded outcome
under its reserved finite protected work and named temporal relies.
```

R9 models delivered CPU service. It does not equate CPU service with correct
application behavior or exactly-once endpoint effects.

The adversary controls Linux, every Domain-visible kernel mapping, task and rq
metadata, cgroups, namespaces, credentials, LSM/BPF policy output, asynchronous
workers, service requests, proposed certificates, storage outside protected
persistence, and network scheduling. The adversary may omit, delay, duplicate,
reorder, corrupt, replay, or equivocate through every untrusted channel. No
Linux action receives a fairness assumption.

R9 does not prove the provider formulas. It does not yet establish physical
MemoryView, code, stack, mutable-state, IOMMU, DMA, IRQ, device, clock, quorum,
cryptographic, or fail-stop correctness. It also does not establish Linux
refinement, measured cost, TCB size, multi-cluster availability, or deployment
readiness. Those are later composition obligations and remain false even if
the R9 local state machine eventually passes.

## Normative Scope And Rejection Rule

Only this artifact's explicit registries are normative. The future machine IR
must reject rather than infer any missing value.

```text
closed registries:
  ImportManifest
  LocalProviderFormulaRegistry
  BoundAndTypeRegistry
  ActorRegistry
  ConsistencyDomainRegistry
  ImmutableObjectSchemaRegistry
  MutableCellSchemaRegistry
  IdentityEdgeRegistry
  AllocatorRegistry
  OwnerRegistry
  ActionRegistry
  CrashRecoveryRegistry
  ProtectedWorkRegistry
  RankAndTemporalRegistry
  AbstractionRegistry
  ProofRegistry
  ClaimRegistry
  MutationObligationRegistry
```

For every registry, the declared key set must equal the schema-derived key set.
Unknown, duplicate, absent, unreachable, ownerless, multiply owned, unallocated,
unreferenced, or wildcard entries reject. A prose alias cannot add semantics.

Every bound is a positive nonwrapping natural fixed by `NodeConfig`. Each sort
has a distinct typed `None`. Exhaustion before authority yields a typed Reject
or Backpressure outcome. Exhaustion after authority consumes admission-reserved
stop, settlement, failure, audit, and recovery capacity; exhaustion of that
reserved path is `InternalGuaranteeViolation`, never an external withdrawal.

## Closed Import Manifest

R9 imports only four exact artifacts. Formula names below are an allowlist;
matching a file digest does not import every formula in the file.

| Import ID | Artifact raw SHA-256 | Formula allowlist | R9 use |
| --- | --- | --- | --- |
| `IMP-ROOT-CONTRACT` | `3df32d6e3991b335e1fe6575077eec7ea76035ceadebe39ad1591f6ed8dcd42c` | claim IDs and nonclaims only | contract vocabulary; no executable state imported |
| `IMP-ROOT-TLA` | `491d02fb75317fec31868c7a7e57a7f85512f10d7a1ba12eba8f48fab565a3b1` | `NoRootRunWithoutLease`, `NoRootBudgetOverrun`, `LinuxCannotExtendRootLease`, `ReservedSlotIntegrity`, `ExpiredOrRevokedAuthorityCleared`, `GuaranteedRecurringService`, `TrustedHandoffProgress` | refinement target for each bounded R9 root-service projection |
| `IMP-RES-CONTRACT` | `650d579ed0507a142501166045e50e37bc81ca69e3980cdf1aa3276fe9868295` | claim IDs and nonclaims only | finite-reference vocabulary; no dynamic guarantee assumed |
| `IMP-RES-TLA` | `1efd0719569d31657c0b7aaf50e103f5fdcdc94dfce7499fc0f149780982a431` | `MonitorOwnsGlobalRegistry`, `ResidentEpochCurrent`, `SlotGenerationFresh`, `NoSlotAlias`, `ActiveBindingExact`, `NoEvictWhileRunningOrReferenced`, `NoDuplicateExclusiveResidency`, `ExclusiveAuthoritySingleCPU`, `OfflineCPUHasNoAuthority`, `HotplugCreatesFreshCpuIncarnation`, `ManagementRecoveryIndependent` | safety refinement target for every finite projected R9 population |

The root variable map is exact:

```text
activeDomain       <- PhysicalCpuState[cpu].CpuOwner.Domain or NoDomain
root lease         <- RootServiceCell[rootCellID]
root budget        <- RootBudgetUseCell[dispatch].reserved/settled projection
admitted           <- ResidencyAggregateCell[residency].status = Current
reserved slot      <- RootSlotOutcomeCell[rootSlotID]
epoch              <- DomainRecord[domain].epoch and CpuIncarnationCell[cpu]
hardware consume   <- IntervalSettlementOutcome[interval].Committed
```

The finite-residency variable map is exact:

```text
global registry    <- DomainRecord and DomainIncarnationRecord
resident binding   <- ResidencyStatusCell plus ResidencyAggregateCell
slot generation    <- ResidencySlotCell nonwrapping generation
active binding     <- PhysicalCpuState[cpu].CpuOwner
trusted reference  <- exact ReferenceClassRegistry live predicates
CPU online state   <- provider-owned CpuIncarnationCell
migration fence    <- SourceIssuanceFenceCell or local pre-entry retarget fence
management path    <- BootPhaseCell and reserved management residency
```

The dynamic model must prove these refinement mappings; it may not assume the
mapped conclusions. A changed imported byte, formula allowlist, or variable map
is a new architecture input and reopens review.

Each allowlisted formula becomes one machine `ImportEntry`:

```text
ImportEntry =
  (importID,
   artifactPath,
   artifactRawSHA256,
   moduleID,
   sourceFormulaID,
   sourceFormulaRawSliceSHA256,
   canonicalFormulaASTSHA256,
   formulaKind,
   exactFreeVariableMap,
   exactConstantMap,
   exactTypeMap,
   assumptionFormulaIDs,
   faultFormulaID or TypedNone,
   faultBoundConstants,
   guaranteeFormulaID or TypedNone,
   providerID or TypedNone,
   consumerProofIDs)
```

The four imports above have `formulaKind = RefinementTarget`. Therefore their
assumption, fault, guarantee-consumed, and provider fields are typed None; R9
does not borrow their conclusions. For the root projection, exact constants map
to one selected `{management, guaranteed1, guaranteed2, bestEffort1}` tuple and
its selected root frame. For finite residency, they map to one selected
`{management, G1, G2, G3, BE1, BE2}` and two-CPU projection. All other dynamic
objects are hidden by the refinement map. P18 proves those selected projections,
while R9's generic bounded theorems are proved independently.

The machine manifest extracts free variables, constants, and types from the
source formula AST and requires exact key equality with the three maps. The raw
formula slice hash and canonical AST hash are derived checks; artifact hash plus
module and formula ID already fixes source identity. Any extractor ambiguity or
map mismatch rejects rather than choosing a formula boundary.

## Local Provider Formula Registry

Unimplemented lower layers are represented by exact local formulas rather than
unversioned prose imports. They are assumptions of the R9 theorem and mandatory
guarantees of later provider models.

Let `PC` be protected control variables, `PV` provider-owned variables,
`UE` untrusted environment variables, and `NodeHealthy` a provider fact.

| Formula ID | Exact formula and fault bound |
| --- | --- |
| `PF-CANON-01` | Within one key epoch, canonical encoding is injective over every declared typed schema; seals cannot be forged by `UE`; key rollback either fails verification or advances the boot epoch. Compromise of the sealing root is excluded. |
| `PF-STORE-01` | Every action declared atomic in one `NodeProtectedCD` has one total linearization order, all-or-none durable writes, monotonic nonwrapping generations, and crash recovery to the last committed prefix. Arbitrary protected-store corruption is excluded. |
| `PF-TIME-01` | For each `(ClockDomainID, ClockEpoch)`, protected time is monotonic; the provider supplies conservative lower/upper observations and an unsuppressible deadline event while `NodeHealthy`. Cross-domain comparison exists only through one direct relation certificate with finite error and horizon. Clock-root compromise is excluded. |
| `PF-CPU-ENTRY-01` | `ProviderCommitPhysicalEntry(req)` is the sole `Idle -> ActiveRunning` transition. In one `NodeProtectedCD` linearization it rechecks the request's current local generations, writes `EntryOutcome=Entered`, `CpuOwner=Active`, `Quantum=Armed`, `Portal=ActiveRunning`, and enables the CPU gate; otherwise it writes no execution state. |
| `PF-CPU-BOUNDARY-01` | While `NodeHealthy`, an armed quantum reaches `ProviderCommitBoundary(actualTicks)` before its upper bound or deadline. The action disables the CPU gate before or atomically with recording `actualTicks <= quantumUpperBound`. On detected provider crash, `ProviderCrashBoundary` disables the gate and records the full upper bound. |
| `PF-CPU-STOP-01` | A valid stop request causes provider state `ActiveRunning/ActivePaused -> Stopping -> Idle` within the admitted residual bound, or the CPU is physically fail-stopped. The stopped Domain performs no required stop work. |
| `PF-OCC-01` | For each due reserved protected work item while `NodeHealthy`, the provider eventually publishes its exact next occurrence grant or physically fail-stops the node. No other item can consume that grant. Maximum outstanding grants and expiry are NodeConfig-bounded. |
| `PF-CLUSTER-CERT-01` | Under authenticated crash/omission quorum with at most `FCrash` faulty members, an accepted finite certificate does not equivocate for its issuer/configuration epoch and remains valid only to its conservative local horizon. Byzantine quorum or issuer-root compromise is excluded. |
| `PF-NOREISSUE-01` | A committed quorum no-reissue record is unique for `(streamIncarnation, ordinal)`, binds the complete recorded payload, survives any `FCrash` failures, and no valid successor authority for that ordinal is issued. It proves consumption/non-reissue, not physical entry or endpoint effect. |
| `PF-PHYSICAL-CONTEXT-01` | A current context receipt denotes inertly staged MemoryView, entry state, code, mutable-state, and declared device/absence generations. CPU enable uses only the exact installed generation; stop returns a finite residual bound. This is an interface assumption, not R9 proof of isolation. |

Exact temporal forms used by R9 are:

```text
OccurrenceDelivery ==
  forall item:
    []((Due(item) /\ NodeHealthy)
       => <>(GrantForNext(item) \/ NodeFailStopped))

MonitorGrantConsumption ==
  forall grant, action:
    WF_PC(ConsumeGrantFor(action, grant))
    /\ []((GrantLive(grant) /\ MonitorHealthy)
          => <>(Acked(grant) \/ MonitorFailStopped))

PhysicalBoundary ==
  forall quantum:
    []((Armed(quantum) /\ NodeHealthy)
       => <>(BoundaryCommitted(quantum) \/ NodeFailStopped))

PhysicalStop ==
  forall stop:
    []((StopRequested(stop) /\ NodeHealthy)
       => <>(OwnerIdle(stop.cpu) \/ CpuFailStopped(stop.cpu)))
```

`WF_PC` applies only to the exact protected consume action while its grant and
guard remain live. It is never applied to Linux, a Domain, an untrusted
service, a network response, or an unavailable external certificate.

## Actors And Consistency Domains

The actor set is exact:

```text
UE_Linux
UE_Domain
UE_Service
UE_NetworkStorage
PP_Seal
PP_Time
PP_ProtectedStore
PP_PhysicalCPU[cpu]
PP_ClusterQuorum
PP_PhysicalContext
MP_Boot
MP_AuthorityRegistry
MP_DomainRegistry
MP_Context[ProtectionDomain]
MP_Admission[transaction]
MP_Residency[residency]
MP_RootScheduler
MP_Stream[stream]
MP_Dispatch[dispatchUse]
MP_Scope[scope]
MP_FailureRegistry
MP_Transfer[streamIncarnation]
MP_Checkpoint
```

`UE_*` writes only environment input cells. `PP_*` writes only provider facts
and cells explicitly assigned below. `MP_*` is protected protocol logic and
writes only its assigned cells. Linux-visible data never owns an authority
cell.

All node-local protected control cells and physical CPU entry cells carry the
same `NodeProtectedCD(NodeID, MonitorBootEpoch)`. `PF-STORE-01` and the physical
provider primitives define one linearization order for actions that race on
entry, close, revoke, hotplug, stop, or aggregate generation. This does not
require a population scan or one global software lock: disjoint writes may
commute, but their observable commits are linearizable.

Separate consistency domains are:

```text
NodeProtectedCD(NodeID, MonitorBootEpoch)
QuorumCD(QuorumConfigurationEpoch)
IssuerCD(GlobalIssuerID, IssuerEpoch)
EndpointCD(EndpointID, EndpointEpoch)       [later model]
DeviceCD(DeviceID, DeviceEpoch)             [later model]
```

No action is called atomic across two entries in this list. Remote facts enter
`NodeProtectedCD` only as immutable finite-horizon certificates. A local action
may consume a certificate, but cannot update its remote source atomically.

## Identity Axes And Protection Granularity

R9 keeps five identity axes distinct:

```text
AdministrativeDomainKey:
  policy, delegation, quota, naming, and container/tenant hierarchy

ProtectionDomainKey:
  one physical MemoryView and mutable privileged-state isolation boundary

ExecutionSubjectKey:
  exact process, thread, service invocation, or async-carrier generation

SchedContextKey:
  independently delegated CPU budget and scheduling constraints

DispatchUseID:
  one protected ready-to-entry-to-settlement CPU authority use
```

Only a leaf `ProtectionDomainKey` may become physical `CpuOwner`. An
administrative container parent is never a CPU owner. A container can contain
many physically isolated process leaves. Explicitly sharing one leaf between
processes creates one physical trust Domain and cannot claim protection against
arbitrary kernel execution by either process inside that leaf.

Thread granularity inside one leaf remains an execution-authority boundary, not
a physical confidentiality boundary. Hypervisor-grade process separation uses
one leaf per process or another separately protected child context.

## Immutable Object Schemas

Immutable objects are content-addressed typed records. They are not variables
and have no writer after publication. The exact schema key set is:

```text
NodeConfig
BootRootRecord
DomainCore
ProtectionDomainCore
SubjectCore
ProgramImageCore
SchedContextCore
RunAuthorizationCore
SpawnAuthorizationCore
ChargeRuleCore
AuthorityDelegationCore
DomainContextInstallCore
DomainContextCapsule
AdmissionCore
ResidencyActivationCore
ResidencyDependencyTranscript
ResidencyValidationAggregateCore
CompactCalendarDescriptor
RequestMemberCore
OpportunityCore
DispatchDescriptorCore
FrozenRunUse
DispatchSnapshotV1
ActivationInputCore
ConnectivityCertificate
NoConnectivityRequired
PublicationCore
EnrollmentSeal
PreparedBundleDescriptor
PreEntryPermit
PhysicalEntryRequest
PhysicalBoundaryReceipt
IntervalSettlementCore
SettlementCore
AsyncOperationCore
CallerFrozenAuthorityCore
ServiceAuthorityCore
AsyncCarrierCore
FailureTopologyCore
FailureWorkCore
TransferPlanCore
QuorumNoReissueFenceCore
SuccessorTransferAuthorizationCore
CheckpointVectorCore
TombstoneCore
ProtectedOccurrenceCore
```

Every core names schema version, complete parent identities, all relevant
nonwrapping generations, owner consistency domain, conservative horizon, and
canonical digest. Typed absence is an explicit schema member and cannot be
represented by an omitted field.

## Parent-Conserved Authority

An authority record is never created from policy output alone. The root of each
authority chain is an issuer or boot-root object named by a provider formula.
Every child is produced by one `AuthorityIssueDecisionCell` and binds:

```text
parentAuthorityID and parent generation
issuer and delegation depth
target AdministrativeDomain/ProtectionDomain/Subject set
operation-right set
CPU and NUMA set
priority/class ceiling and co-tenancy constraint
validity interval
maximum child-use count
delegation permission and remaining depth
parent reservation ID
```

The issue guard is exact:

```text
child.targets subseteq parent.targets
child.operations subseteq parent.operations
child.cpus subseteq parent.cpus
child.validity subseteq parent.validity
child.priorityAuthority no stronger than parent.priorityAuthority
child.coTenancy no weaker than parent.coTenancy
child.maxUses <= reserved parent uses
child.delegationDepth < parent.delegationDepth
```

`CommitAuthorityIssue` atomically reserves parent capacity and changes the
decision from `Open` to `CommitIntent(childCore)` in `NodeProtectedCD`.
`CompleteAuthorityIssue` publishes the immutable child and marks `CommitDone`.
`AbortIntent` returns the exact reservation. Crash recovery can only complete
the selected intent.

RunAuthorization has a protected `RunUseAllocatorCell`:

```text
(generation, nextUseOrdinal, usesRemaining, status)
status in {Open, Closing, Revoked, Exhausted, Retired}
```

`AllocateFrozenRunUse` is one atomic action. It decrements `usesRemaining`,
burns `nextUseOrdinal`, creates one `RunUseCellID`, and publishes a
`FrozenRunUse` bound to the exact subject/process/program, ProtectionDomain,
constraints, revocation generation, and horizon. A reusable authorization can
allocate only its finite reserved count. Renewal is a new parent-conserved
authority generation. `FrozenRunUse` is therefore an allocated one-use object,
not a cost-free snapshot.

Every revocable authority/status generation has an admission-bounded reverse
set of active use cells and pre-reserved stop credits. Revocation atomically
advances the authority generation, makes every future entry/re-arm comparison
stale, and publishes one exact stop work item for every currently active use in
that reverse set. This may cost `O(active uses of that exact authority)` but
never scans tasks or Domains. A request whose maximum active-use fanout cannot
be bounded and precharged is rejected before authority issuance.

SpawnAuthorization uses the same conserved allocator pattern. The exact spawn
sequence is:

```text
IssueSpawnAuthorization
  -> AllocateSpawnUse
  -> ReserveChildGlobalIdentity
  -> CreateLeafProtectionDomain or ExplicitSharedLeafBinding
  -> ConsumeSpawnUse
  -> RegisterSubject
  -> InstallChildContext
  -> AdmitChildResidency
  -> PublishChildReady
```

Failure before `ConsumeSpawnUse` follows the transaction's `AbortIntent` and
returns the reservation. Failure after consumption never creates a second
child identity. A container administrative parent and a physical leaf have
different types and cannot be substituted.

## Exec, Exit, And Async Authority

Exec preserves `ProtectionDomainKey` and advances `ProgramGeneration`. Its
ordered protocol is:

```text
BlockOldReady
AdvanceProgramTransitionGeneration
RevokeOldRunUseAllocatorGeneration
RequestStopForOldProgramActivations
ObserveStopAndSettlementAcknowledgment
DrainAsyncCarriers or commit explicit typed carrier transfer
CommitProgramImageAndGeneration
PublishNewProgramReady
```

No new-program ready cell exists while an old-program owner, permit, carrier,
or unsettled use remains. An explicitly transferable carrier must authorize
the new program generation; otherwise it drains or terminalizes.

Exit begins by closing the subject generation and blocking ready publication.
It then stops and settles active dispatches, drains or transfers carriers under
typed authority, commits terminal subject status, and only then permits identity
reclamation after checkpoint dominance. Worker `current`, task pointers, and
Linux process state are never authority provenance.

A Domain-originated asynchronous operation has:

```text
CallerFrozenAuthorityCore
ServiceAuthorityCore
AsyncOperationCore
ValidatedAuthorityIntersection
AsyncCarrierCore
AsyncCarrierUseCell
```

The intersection is exact:

```text
effective.operations = caller.operations intersect service.operations
effective.objects    = caller.objects intersect service.objects
effective.cpus       = caller.cpus intersect service.cpus
effective.horizon    = conservative intersection of both horizons
effective.budget     = separately conserved caller/service charge rule
effective.domain     = service leaf executing for exact caller leaf
```

An empty intersection rejects before queue publication. `CreateAsyncCarrier`
allocates one use from both parent authorities, fixes caller, service,
operation, charge, generations, and horizon, and publishes one immutable
carrier. `ConsumeAsyncCarrier` may create exactly one ActivationRequestCore.
Its consumed status is later derived from that dispatch's EntryOutcome.

Authority-level coalescing is forbidden. A non-authoritative computation
descriptor may be shared, but every member retains an independent carrier,
DispatchUseID, authority DAG, cancellation cell, budget, and terminal result.
Reusing one pending `work_struct` cannot overwrite or merge these records.

Generic kernel work must be classified as exactly one of:

```text
MonitorInternalWork
LeafDomainLocalWork
TypedServiceInvocation
```

Unclassified or Domain-derived work without a valid carrier is non-executable.

## Management Bootstrap

`Init` contains an immutable `BootRootRecord`, fixed management/recovery
capacity, empty physical CPU owners, and no tenant or management execution
authority. `BootPhaseCell` is the sole bootstrap root:

```text
Reset
BootRootInstalled
ManagementDomainRegistered
ManagementContextInstalled
ManagementResidencyAdmitted
ManagementTemplatePublished
TenantAdmissionEnabled
BootFailed
```

The only forward sequence is:

```text
InstallBootRoot
RegisterManagementDomain
InstallManagementContext
AdmitManagementResidency
PublishManagementTemplate
EnableTenantAdmission
```

Each step has a preallocated same-ID transaction decision. A crash completes
its durable intent or aborts to `BootFailed`; it never skips a phase or creates
a second management identity. Tenant admission requires exactly
`TenantAdmissionEnabled`. Tenant work cannot consume management root cells,
stop credits, ready capacity, or namespace capacity.

Loss of the boot root or management recovery path is `NodeRootFailure`. It is
not disguised as one tenant's external withdrawal.

## Dynamic Admission And Conserved Resource Vectors

`NodeConfig` fixes a finite hierarchy depth and an exact resource vector:

```text
DomainExecutionTicks
RootPhysicalTicks
SchedContextTicks
ExecutionCellCount
TargetControlTurns
ProtectedOccurrenceCredits by work class
ReadyCells
AttemptCells
LiveSuffixRecords
LocalScopeReverseSlots
FailureEdges
FailureCoverCredits
StopAndResidualRecords
SettlementRecords
TransferRecords
ReferenceAndTombstoneRecords
AuditAndCheckpointRecords
NamespaceGenerations
```

Management/recovery reserves are disjoint from tenant vectors. Guaranteed
admission reserves its worst-case recurring execution, pre-entry, stop,
settlement, failure, audit, and namespace-retirement work before any executable
authority exists. BestEffort consumes only revocable slack and receives no
recurrence liveness guarantee.

`AdmissionCore` fixes one affected lineage and mutation footprint. The lineage
contains every modified ancestor up to the NodeConfig depth and no unrelated
node. Admission validates exact set equality, current generations, parent
conservation, disjoint or explicitly shared cells, placement and partition
certificates, failure cover envelope, reverse-edge capacity, and future local
work.

`AdmissionDecisionCell` uses the deterministic transaction state:

```text
Open
CommitIntent(AdmissionCoreID, futureEffectiveBoundary,
             exactReservationVector)
AbortIntent(reason)
CommitApplied(admissionGeneration)
AbortApplied(reason)
```

`CommitAdmission` writes CommitIntent and every parent reservation in one
bounded `NodeProtectedCD` transaction after exact local enrollment is sealed.
`ApplyAdmissionBoundary` is an idempotent projection at the fixed future
boundary; it cannot reject, widen, or reinterpret the committed plan. A
committed plan that is not yet due is non-executable.

Service-class transitions never mutate current authority in place:

```text
BestEffort -> Guaranteed:
  complete full future-generation guaranteed admission first

Guaranteed -> BestEffort or narrower constraint:
  commit replacement generation, close/stop/settle old generation, then retire

constraint widening or parent change:
  new admission and new residency aggregate generation
```

If the affected set or write set exceeds its admitted transaction bound, the
request rejects before authority. The model does not pretend to perform an
unbounded atomic update.

`ResidencySlotCell` is a bounded projection cache:

```text
Vacant(slotGeneration)
Reserved(slotGeneration, residencyID)
Live(slotGeneration, residencyID)
Closing(slotGeneration, residencyID)
Retired(slotGeneration, residencyID)
Quarantined(slotGeneration)
```

Reuse requires aggregate Stopped, no physical owner, all Ready/attempt/async
and residual references terminal, settlement fully applied, close prefixes
complete, checkpoint dominance, and nonwrapping generation advance. A stale
slot index or Linux pointer cannot authenticate the next occupant.

## Request Members, Cancellation, And Coalescing

Each recurring ordinal may contain one or more independently authorized request
members. `RequestMemberCore` fixes RequestID, caller authority, operation,
charge rule, cancellation generation, required service share, and terminal
result identity.

`RequestCancellationCell` is monotonic:

```text
Open(g)
CancelRequested(g + 1, cause, requestTick)
CancelledBeforeReady(g + 1, resultID)
CancelledNeverEntered(g + 1, settlementID)
CancelledAfterEntry(g + 1, stopGeneration, settlementID,
                    effectDisposition)
Terminal(g + 1, resultID)
```

Before Ready, cancellation terminalizes without a DispatchUse. Between Ready
and entry, it wins the same ready/entry ordering domain, revokes the permit,
obtains NeverEntered, and releases reservations. After entry, it requests stop,
preserves verified service and endpoint uncertainty, settles, then terminalizes.
It never rolls an opportunity backward or reuses an ordinal.

Authority-level coalescing remains forbidden. A bounded immutable computation
descriptor may be referenced by several members only when it has no authority,
caller-private mutable input, charge, cancellation, or externally visible
effect. Every member retains its own carrier/use/dispatch/result chain.

Suffix capacity is `ClosedPrefix + at most KLiveSuffix`. Admission or renewal
backpressures before creating an ordinal that cannot receive a live/retiring/
uncertain record. A guaranteed release after admission that finds its reserved
suffix absent is InternalGuaranteeViolation.

## Connectivity One-Use Input

Connectivity is an authenticated bounded observation/authorization, never a
promise of future reachability. `ConnectivityCertificate` binds:

```text
certificate and issuer/configuration epoch
ActivationInputCore and AttemptID
operation purpose
source and exact destination Node/Monitor/boot epoch/CPU incarnation
challenge, channel, and checkpoint
typed clock relation and conservative local expiry
```

One local `ConnectivityUseCell` is allocated from the certificate. Its atomic
state is `Unused -> Consumed(receiptID)` or `Unused -> Expired`. Crash before
consume leaves Unused; crash after returns the same receipt. Binding one
Monitor boot does not imply distributed one-use. Globally transferable one-use
authority requires a quorum-owned consumable object.

Post-observation partition may end liveness at the typed timeout or withdrawal
boundary but cannot make the local receipt reusable. A no-connectivity class
uses `NoConnectivityRequired` with a protected absence proof.

## Static Context And Residency Aggregate

Static `DomainContextCapsule` construction validates variable-size physical
receipts outside ordinary dispatch. Its mutable roots are
`ContextInstallDecisionCell`, `CurrentCapsuleCell`, and one
`InstalledContextCell[cpu]`. Staging is inert. Only a committed install
decision publishes a capsule; closing its current generation prevents new
residency activation and triggers bounded stop of dependent aggregates.

Residency activation validates every variable-size local dependency, remote
certificate, static receipt, hierarchy reservation, placement rule, failure
cover, protected-ready capacity, and future work reservation exactly once per
residency generation. The immutable transcript is
`ResidencyDependencyTranscript`. The committed result is:

```text
ResidencyValidationAggregateCore =
  (residencyID,
   aggregateGeneration,
   ProtectionDomainKey,
   DomainEpoch,
   DomainContextCapsuleID/generation,
   placement and partition certificate IDs,
   root and hierarchy reservation IDs,
   execution-cell pool ID,
   failure/stop/settlement/work reservation IDs,
   local dependency set digest,
   remote certificate set digest,
   conservative horizon,
   co-tenancy class,
   continuity class,
   transcript digest)
```

`ResidencyAggregateCell` is:

```text
Empty(g)
Current(g, aggregateCoreID, revocationGeneration, horizon)
Revoking(g, aggregateCoreID, revocationGeneration + 1, cause)
Stopped(g, settlementID)
Retired(g + 1)
Rejected(g, reason)
```

Every local dependency has a precharged reverse registration to each aggregate
that consumes it. `InvalidateLocalDependency` is one bounded
`NodeProtectedCD` transaction over the declared reverse set:

```text
close or advance the dependency generation
advance every affected aggregate revocationGeneration
make every pre-entry dispatch snapshot stale
publish one exact stop item for each physically active affected lane
```

The transaction may cost `O(affected aggregates + active lanes)` and admission
must reserve that work. It never scans the Domain population. Disjoint
aggregates are unchanged. Remote revocation is not magically atomic: imported
remote facts remain valid only to their conservative local horizon, after
which entry/resume fails closed.

This aggregate is the only variable-dependency value read by ordinary
dispatch. A changed underlying local dependency without the required aggregate
generation update violates `PF-STORE-01` and is a later provider/refinement
failure, not a permitted R9 execution.

## Constant-Size Dispatch Snapshot

`DispatchSnapshotV1` has exactly 20 top-level components regardless of the
number of residency dependencies:

```text
1  schemaVersion
2  DispatchUseID
3  OpportunityID and ActivationAttemptID
4  ProtectionDomainKey and DomainEpoch
5  ExecutionSubjectKey, SubjectGeneration, ProcessGeneration, ProgramGeneration
6  DomainContextCapsuleID and generation
7  ResidencyAggregateID, aggregateGeneration, revocationGeneration
8  FrozenRunUseID and RunUseCellID
9  SchedContextID/generation and SchedBudgetUseCellID
10 RootServiceCellID and RootBudgetUseCellID
11 ChargeRuleID/generation and ChargeUseCellID
12 ExecutionCellUseID and execution upper bound
13 ProtectedReadyCellID/generation and RootSlotClaimID
14 target CPU ID and CpuIncarnation
15 RequestCancellationGeneration
16 PreEntryPermitID/generation
17 EntryOutcomeCellID, RuntimeStopCellID, and SettlementOutcomeCellID
18 conservative EntryAuthorityHorizon
19 QuorumNoReissueFenceReceiptID or TypedLocalOnly
20 ConnectivityUseID or TypedNoConnectivity plus AsyncCarrierUseID or TypedSync
```

All nested records have fixed schemas. No receipt set, ancestor set, scope set,
or topology list appears here. New dispatch construction validates a constant
number of one-use cells and one current residency aggregate. Same-activation
resume compares an even smaller fixed protected tuple and performs no durable
publication, remote operation, signature verification, or population scan.

Any semantic addition to these 20 components changes `DispatchSnapshotV1` and
reopens architecture review. Optional data uses typed values, not omission.

## Recurring Release And Protected Ready

Each stream has one `StreamCursorCell` in the same `NodeProtectedCD` ordering
domain as its source issuance fence:

```text
(streamIncarnation, streamGeneration, nextOrdinal,
 ClosedPrefix, KLiveSuffix, status, sourceFenceGeneration)
```

`CommitReleaseOrdinal` is one atomic transaction. For due ordinal `q` it
advances `nextOrdinal` and commits exactly one `ReleaseOutcomeCell[q]`:

```text
Released(OpportunityID, DispatchUseID, ProtectedReadyCellID)
BurnedExternalWithdrawal(cause)
InternalGuaranteeViolation(cause)
```

The ordinal is burned in every branch. Crash before the transaction leaves it
unreleased; crash after it reconstructs the same outcome and identities.
Capacity is reserved before the due release. A guaranteed internal capacity
failure cannot masquerade as backpressure after admission.

`OpportunityID` is injectively derived from stream incarnation, generation,
ordinal, and ReleaseOutcome identity. `DispatchUseID` and
`ProtectedReadyCellID` therefore exist before ready publication.

The exact ready lifecycle is:

```text
Allocated(g)
Ready(g, DispatchDescriptorCoreID, cancellationGeneration)
Preparing(g, ActivationAttemptID)
EntryEligible(g, PreEntryPermitID, permitGeneration)
Claimed(g, RootSlotClaimID, selectionGeneration)
Consumed(g, entryGeneration)
Cancelled(g + 1, phase, cause)
Terminal(g, TerminalOutcomeID)
```

`PublishReady` validates the current residency aggregate and exact immutable
descriptor. `ClaimReadyForPreparation` changes Ready to Preparing and allocates
the attempt through the same opportunity-shard transaction. `PublishEligible`
requires a live permit for the same ActivationInputCore. `RootSelectReady`
may claim only EntryEligible. Cancellation and selection compare the same ready
generation in `NodeProtectedCD`; exactly one wins. `Consumed` is a deterministic
projection of provider-committed EntryOutcome, not a second execution truth.

Hostile Linux may suggest best-effort ready descriptors but cannot publish,
hide, retarget, cancel, or consume a protected Ready cell. Guaranteed calendar
release and preparation are Monitor-owned and do not wait for Linux enqueue.

## Root Scheduler Refinement

The exact chain from the accepted root reference is:

```text
RootFrameRelease(rootCellID, DomainKey)
  -> RootServiceOpportunity(rootCellID, due interval)
  -> EntryEligible ProtectedReadyCell for that Domain and interval
  -> RootSlotClaim(rootCellID, ReadyID, readyGeneration, selectionGeneration)
  -> ProviderCommitPhysicalEntry
  -> verified IntervalSettlementOutcome records delivered service
```

`RootSlotOutcomeCell` is exactly one of:

```text
Open
Claimed(RootSlotClaimID)
ClosedNoEligible(typed external withdrawal or InternalGuaranteeViolation)
Delivered(serviceTicks, settlementIDs)
```

Absence of eligible work never counts as service. Guaranteed admission proves
that its preparation deadline and protected work precede its root service
cell, or selects a named external-withdrawal branch. Best-effort may use only
root slack. Linux cannot substitute a different ReadyID into a claim.

## Attempt And Authority Reservation

An opportunity has one `AttemptAllocatorCell`:

```text
(nextAttemptOrdinal, activeAttemptID or None, everEntered, status)
```

`AllocateAttempt` atomically burns one bounded ordinal and publishes the exact
CAS receipt from which `ActivationAttemptID` is derived. At most one
nonterminal attempt exists. Attempt exhaustion under valid guaranteed inputs is
`InternalGuaranteeViolation`.

The authority reservation tuple is fixed:

```text
one RunUseCell
one SchedBudgetUseCell
one RootBudgetUseCell
one ChargeUseCell
one ExecutionCellUseCell
optional AsyncCarrierUseCell
optional ConnectivityUseCell
```

All local cells reside in `NodeProtectedCD`. `ReserveDispatchAuthority` checks
the complete tuple and atomically changes `AuthorityReservationDecisionCell`
from `Open` to either `CommitIntent(exact tuple)` or `AbortIntent(reason)`.
`CommitIntent` binds every cell to the same AttemptID in that transaction.
There is no visible partial reservation.

Every use cell has the same pre-entry authority states:

```text
Available -> Bound(AttemptID) -> ReleasedBeforeEntry(settlementID)
```

Budget, charge, carrier, and execution-cell use schemas may also contain the
fixed idempotent settlement-application cursor named by LedgerApplyCell. That
cursor performs accounting or aftermath closure; it is not execution truth.
The predicates `UseConsumed` and `UseSettled` are pure functions of the exact
EntryOutcome and SettlementOutcome that bind the use ID. No action separately
writes a Consumed bit. Thus crash recovery cannot disagree about which of seven
authority cells physical entry consumed.

## Typed Budget Equation

All CPU amounts are nonnegative integer `PhysicalCpuTick` values in one CPU
incarnation and accounting epoch. NodeConfig fixes `MaxAttempts`, `MaxQuanta`,
`MaxCrashBoundaries`, and every overhead upper bound. Before
`CommitIntent(ReservedAll)`, R9 checks:

```text
crashChargeAllowance = MaxCrashBoundaries * MaxQuantumTicks
domainSlack >= 0
execEscrow = requiredService + crashChargeAllowance + domainSlack
schedDebit = execEscrow
protectedOverheadDebit =
  MaxAttempts * preEntryOverheadBound
  + entryOverheadBound
  + MaxQuanta * (armOverheadBound + boundaryOverheadBound)
  + stopOverheadBound
rootDebit = execEscrow + protectedOverheadDebit

requiredService > 0
rootAvailable >= rootDebit
schedAvailable >= schedDebit
executionCellUpperBound = execEscrow
rootCellPhysicalBound >= rootDebit
```

Pre-entry, portal, arm, boundary, entry, and stop overhead are provider-measured
protected time and cannot be charged as Domain service. Monitor control turns,
protected persistence operations, failure closure, and audit use separate typed
reservation vectors and cannot borrow Domain execution escrow. At final
settlement:

```text
0 <= verifiedService <= domainExecutionCharged <= execEscrow
0 <= protectedOverheadActual <= protectedOverheadDebit

rootConsumed  = domainExecutionCharged + protectedOverheadActual
schedConsumed = domainExecutionCharged
rootReturned  = rootDebit - rootConsumed
schedReturned = schedDebit - schedConsumed

rootConsumed + rootReturned = rootDebit
schedConsumed + schedReturned = schedDebit
```

A guaranteed Served outcome additionally requires
`verifiedService >= requiredService` by its deadline end tick. Pessimistic crash
charge contributes to `domainExecutionCharged` but only intervals with the
exact physical owner contribute to verified service.

## Prepare, Permit, And Deterministic Transactions

Every crashable multi-step transaction uses one common state type:

```text
TxnDecision =
  Open
  CommitIntent(payloadDigest)
  AbortIntent(reason)
  CommitApplied(payloadDigest)
  AbortApplied(reason)
```

Only one action changes Open to an intent. Recovery is a total function:

```text
Recover(Open)          = AbortIntent(CrashBeforeDecision)
Recover(CommitIntent)  = complete exact idempotent commit projections
Recover(AbortIntent)   = complete exact idempotent releases/cleanup
Recover(CommitApplied) = unchanged committed result
Recover(AbortApplied)  = unchanged aborted result
```

No transaction says "abort or complete." A transaction whose safety requires
commit writes its CommitIntent and all authority-changing local fields in the
same protected transaction. Later projections cannot change the outcome.

Dynamic staging is inert. `PreparedBundleDescriptor` binds the fixed dispatch
snapshot, staging generation, context plan, complete dynamic receipt transcript
digest, current aggregate generation, physical prerequisites, and horizon.
`PrepareDecisionCell` commits it or aborts it under the generic rule.

`PermitCell` is:

```text
Unpublished
Live(permitGeneration, PreparedBundleDescriptorID)
Revoked(revocationGeneration, cause)
```

`EffectivePermitLive` is the pure predicate:

```text
PermitCell = Live
/\ EntryOutcomeCell = Pending
/\ ReadyCell = EntryEligible or Claimed for the same generation
/\ every fixed DispatchSnapshot generation is current
/\ protected time is inside EntryAuthorityHorizon
```

After physical entry, permit consumption is derived from EntryOutcome and
`EffectivePermitLive` is false. It is not necessary or legal to race a second
mutable `Live -> Consumed` transition against physical entry.

## Protected Portal And Physical CPU State

The physical entry provider is the sole writer of the four physical truth
cells for one CPU. They share one atomic product version even though the
schemas remain separately typed:

```text
PortalCell:
  Fenced(portalGeneration)
  Quiescing(oldActivationID, requestGeneration)
  ContextInstalled(capsuleID, capsuleGeneration, cpuIncarnation)
  QuantumPrepared(entryRequestID, quantumGeneration)
  ActiveRunning(ActivationID, quantumGeneration)
  ActivePaused(ActivationID, lastBoundaryGeneration)
  Stopping(ActivationID, stopGeneration)
  Failed(cpuIncarnation)

CpuOwnerCell:
  Idle(cpuIncarnation)
  Entering(entryRequestID, cpuIncarnation)
  Active(ActivationID, entryGeneration, cpuIncarnation)
  Stopping(ActivationID, stopGeneration, cpuIncarnation)
  Failed(cpuIncarnation)

EntryOutcomeCell:
  Pending(entryOutcomeGeneration)
  Entered(entryGeneration, ActivationID, DispatchSnapshotV1ID,
          quantumGeneration, physicalStartTick)
  NeverEntered(reason, providerDecisionGeneration)

QuantumCell:
  Idle(nextQuantumGeneration, totalCharged)
  Prepared(quantumGeneration, ActivationID, upperBound, deadline)
  Armed(quantumGeneration, ActivationID, upperBound, deadline, startTick)
  BoundaryCommitted(quantumGeneration, chargedTicks, endTick,
                    PhysicalBoundaryReceiptID)
```

The exact owner-changing sequence for a Domain switch is:

```text
ActiveRunning(A)
  -> ProviderCommitBoundary(A)
  -> Quiescing(A)
  -> ProviderStopOwner(A)
  -> Fenced(owner = Idle)
  -> ProviderInstallContext(B)
  -> ContextInstalled(B)
  -> ProviderPrepareEntry(B)
  -> QuantumPrepared(B)
  -> ProviderCommitPhysicalEntry(B)
  -> ActiveRunning(B)
```

No Monitor action writes these physical fields. The Monitor writes immutable
requests and revocation/stop cells. Provider actions validate those requests
against current protected generations in the common node-local order.

`PhysicalEntryRequest` binds the complete DispatchSnapshotV1, exact live
permit, current Ready claim, current aggregate generation, Prepared quantum,
installed context, EntryOutcome identity/generation, CpuOwner incarnation,
Portal generation, and the optional no-reissue receipt.

`ProviderPrepareEntry` can move an idle owner to Entering and a prepared portal
state only while all request generations are current. It enables no Domain
instruction. `ProviderCommitPhysicalEntry` is the one CPU-enable primitive
specified by `PF-CPU-ENTRY-01`. Its success atomically:

```text
EntryOutcome := Entered
CpuOwner      := Active
Quantum       := Armed
Portal        := ActiveRunning
timerEnabled  := TRUE
executionGate := TRUE
```

Its failure leaves the CPU gate false. `ProviderRejectPhysicalEntry` is the
sole `Pending -> NeverEntered` writer and is required after a request becomes
permanently invalid. Entry-derived projections reconstruct the same
ActivationID after crash and cannot issue another physical entry.

## Exact Current-Executability Predicate

`CurrentExecutable(cpu, dispatch)` is a provider-enforced predicate, not a
Linux scheduler decision. It is exactly `NormalExecutable \/ StopResidual`.

```text
NormalExecutable ==
  CpuOwner = Active(exact ActivationID, entryGeneration, cpuIncarnation)
  /\ Portal = ActiveRunning(exact ActivationID, quantumGeneration)
  /\ Quantum = Armed(exact ActivationID, quantumGeneration)
  /\ timerEnabled /\ executionGate
  /\ EntryOutcome = Entered(exact DispatchSnapshotV1)
  /\ RuntimeStopCell = Open(stopGeneration)
  /\ ResidencyAggregateCell = Current(exact aggregate/revocation generation)
  /\ CurrentCapsuleCell and InstalledContextCell match the snapshot
  /\ subject, program, RunAuthorization, SchedContext, charge,
     cancellation, Ready, root cell, and CPU generations match
  /\ protectedNow < min(quantumDeadline, EntryAuthorityHorizon)
  /\ ExecutionBudgetRemaining > 0
  /\ required co-tenancy state matches

StopResidual ==
  the same owner and already-Armed quantum existed before RequestStop
  /\ RuntimeStopCell = StopRequested(exact stopGeneration, residualID)
  /\ no continuation arm or new resume has occurred
  /\ protectedNow < min(original quantumDeadline,
                          residualStopDeadline,
                          EntryAuthorityHorizon)
  /\ executionGate remains under PF-CPU-STOP-01 control
```

`RequestStop` never grants new authority. `StopResidual` is the unspent suffix
of the already reserved physical interval and is bounded at admission. The
latest legal entry time is conservatively earlier than natural authority
expiry by `stopOverheadBound + residualStopBound`; therefore natural lease
expiry is never crossed by residual execution. Administrative early close can
consume only this pre-reserved suffix. No new quantum is armed after close.

Every CPU instruction attributed to a Domain implies `CurrentExecutable` at
that provider step. Linux may corrupt every shadow state and still cannot make
the provider predicate true.

## Repeated Quantum Protocol

One physical entry may contain several bounded accounting quanta while the
same exact owner remains installed. Quantum generation never wraps.

```text
Idle(g)
  -> Prepared(g)
  -> Armed(g)
  -> BoundaryCommitted(g)
  -> IntervalSettlementCommitted(g)
  -> Idle(g + 1)
```

The first `Prepared -> Armed` transition is part of
`ProviderCommitPhysicalEntry`. For a later continuation, the Monitor first
publishes the fixed continuation request, `ProviderPrepareContinuation` moves
`Idle -> Prepared`, and `ProviderArmContinuation` moves `Prepared -> Armed`
only from `ActivePaused` for the same ActivationID, use cells, budget, stop
generation, aggregate generation, and CPU incarnation. It creates no new
EntryOutcome.

`ProviderCommitBoundary` first disables `executionGate` and `timerEnabled`,
then atomically records the exact actual ticks and moves Portal to
`ActivePaused`. `ProviderCrashBoundary` records the full upper bound after
physical fail-stop. No action can reset or reuse the QuantumCell until its
boundary receipt has been consumed by exactly one interval settlement.

An interrupt or protected exception may return to the same activation within
an already Armed quantum through `ProviderResumeSameActivation`. It compares
the exact owner, quantum, stop, aggregate, CPU, and context generations and
creates no durable authority. A subject switch, SchedContext switch, charge
switch, execution-cell switch, portal owner replacement, or completed boundary
is not a same-activation resume.

## Interval Charge And Service Linearization

Every physical boundary has one `IntervalSettlementOutcomeCell`:

```text
Open(boundaryReceiptID, quantumGeneration)
Committed(chargedTicks, verifiedServiceDelta, endTick,
          nextServiceAccumulator, chainDigest)
RejectedInternal(reason)
```

`ConsumePhysicalInterval` is one `NodeProtectedCD` transaction. It validates a
previously unconsumed boundary generation and atomically:

```text
commits IntervalSettlementOutcome
decrements ExecutionBudgetRemaining by chargedTicks
advances the one-use interval cursor
adds verifiedServiceDelta to ServiceProgress
records ThresholdReached(endTick) on the first crossing
extends the nonoverlapping interval-chain digest
```

`verifiedServiceDelta` is `chargedTicks` only when the boundary receipt proves
the exact physical owner and service interval. A pessimistic crash upper-bound
charge may exceed verified service. Replay finds the same committed outcome and
cannot charge, refund, or credit service twice.

`ServiceProgressCell` is:

```text
BelowThreshold(totalVerified, nextIntervalGeneration, chainDigest)
ThresholdReached(totalVerified, firstEndTick, nextIntervalGeneration,
                 chainDigest)
ClosedBelowThreshold(totalVerified, cause, chainDigest)
```

ThresholdReached is monotonic. The deadline compares `firstEndTick`, never the
time at which a later receipt or audit record is published.

## Runtime Stop And Settlement

`RuntimeStopCell` is the sole protected stop authority:

```text
Open(stopGeneration)
StopRequested(stopGeneration + 1, cause, requestTick,
              residualStopDeadline, residualID)
StopAcknowledged(stopGeneration, ownerIdleReceipt,
                 finalBoundaryGeneration)
SettlementReady(stopGeneration, finalChargeUpperBound)
Settled(stopGeneration, SettlementOutcomeID)
```

`RequestStop` advances the generation once and is idempotent for later causes;
cause precedence is fixed in NodeConfig. The provider moves physical owner
state through Stopping to Idle. `AcknowledgeStop` only records a provider-owned
idle/fail-stop receipt and cannot depend on the stopped Domain or Linux.

`SettlementOutcomeCell` is the only final accounting decision:

```text
Open
Committed(SettlementCoreID,
          domainExecutionCharged,
          verifiedService,
          protectedOverheadBreakdown,
          protectedOverheadActual,
          rootConsumed, rootReturned,
          schedConsumed, schedReturned,
          runUseDisposition,
          chargeDisposition,
          deliveryDisposition)
InternalGuaranteeViolation(reason)
```

The committed tuple must satisfy the typed budget equations. One
`LedgerApplyCell` records idempotent application bits:

```text
(rootApplied,
 schedApplied,
 executionCellApplied,
 runUseApplied,
 chargeApplied,
 asyncCarrierApplied,
 deliveryApplied,
 auditApplied)
```

Each bit changes `FALSE -> TRUE` at most once after validating the exact
SettlementOutcome. Re-execution with a true bit is a no-op receipt, not a
second debit or refund. `SettlementFullyApplied` is the conjunction of all
applicable bits, with typed NotApplicable values fixed before entry.

The one-use authority predicates are:

```text
UseBound(use)    == AuthorityReservationDecision = CommitIntent including use
UseConsumed(use) == EntryOutcome = Entered binding use
UseSettled(use)  == SettlementOutcome = Committed binding use
UseReleased(use) == EntryOutcome = NeverEntered
                    /\ SettlementOutcome commits ReleasedBeforeEntry(use)
```

They are mutually exclusive where required and cannot be independently
mutated.

## Attempt And Opportunity Terminal Order

`AttemptOutcomeCell` is:

```text
Open
TerminalNeverEntered(reason, SettlementOutcomeID)
TerminalEntered(SettlementOutcomeID)
InternalGuaranteeViolation(reason)
```

The only legal terminal order is:

```text
effective permit becomes dead
physical EntryOutcome resolves
every bound reservation is released or SettlementOutcome is committed
all applicable ledger bits are applied
AttemptOutcome CASes to terminal
if NeverEntered: activeAttemptID clears, then a bounded retry may allocate
if Entered: everEntered becomes true and activeAttemptID never clears for retry
```

No action clears an attempt after Entered. Pre-entry CPU retarget may terminalize
the old attempt and allocate a new attempt under the same opportunity. Once any
attempt enters, the opportunity receives no retry or in-place target migration.

`TerminalOutcomeCell` for the opportunity may commit only after:

```text
AttemptOutcome is terminal
CpuOwner is Idle or a provider fail-stop receipt exists
QuantumCell is Idle at the next generation
RuntimeStopCell is Settled or EntryOutcome is NeverEntered
SettlementOutcome is committed and fully applied
ServiceProgress is ThresholdReached or ClosedBelowThreshold
all typed endpoint/device residual obligations are terminal
```

It does not wait for its own publication reverse-slot prefix or failure-root
completion. After TerminalOutcome commits, the reverse slot becomes terminal;
then the scope prefix can advance; then failure fixed point can complete. This
order removes the R8 terminal/closure cycle.

## Local Publication And Enrollment

Every publication names a finite `DeclaredLocalDependencySet` and one reverse
slot per member. For scope `s`, the only enrollment action atomically writes:

```text
ScopeGateCell[s].generation remains the expected Open generation
EnrollmentCursorCell[s].next := n + 1
ReverseEnrollmentSlot[s,n] := Enrolled(publicationID, publicationGeneration)
```

There is no cursor advance without a slot. `SealEnrollment` commits an
immutable `EnrollmentSeal` only when the exact completed slot set equals the
declared dependency set. Unknown, duplicate, missing, or extra slots reject.

`PublicationDecisionCell` follows the deterministic transaction type:

```text
Open
CommitIntent(EnrollmentSealID, payloadDigest)
AbortIntent(reason)
CommitApplied(CommittedVisible generation)
AbortApplied(reason)
```

`CommitPublication` locks the bounded local gate set in canonical ID order,
rechecks every exact Open generation, and writes CommitIntent plus the
CommittedVisible generation in one `NodeProtectedCD` transaction. A remote
certificate is an immutable prerequisite, never a participant in this atomic
action. CommittedVisible cannot become Aborted or be revalidated into rejection.

`BeginClose(scope)` uses the same local order and atomically:

```text
ScopeGateCell: Open(g) -> Closing(g + 1, closeCut = enrollNext)
all reverse-registered ResidencyAggregate generations: advance/revoking
all already active affected uses: allocate exact reserved stop work IDs
```

New entry loses the same order to close. An already Armed quantum can consume
only its bounded StopResidual and cannot re-arm. A reverse slot below closeCut
is terminal only after publication abort, or after committed use reaches
TerminalOutcome with physical/device residual and accounting settled.

`AdvanceClosePrefix` advances by one contiguous terminal slot. `Closed` requires
`terminalPrefix = closeCut`. A cursor beyond a hole proves nothing.

## Failure Roots, Merge, And Bounded Closure

Admission records an immutable `FailureTopologyCore` with exact bounded reverse
edges. Every edge carries a precharged `FailureEdgeCredit`; every allowed merge
has a `CoverReservationUseCell`. Failure work cannot discover an unadmitted
edge or scan the Domain population.

`FailureRootCell` is:

```text
Open(rootID, rootGeneration, membershipGeneration,
     topologyGeneration, journalGeneration)
Closing(...)
FixedPointCandidate(..., noChangePassGeneration)
Complete(..., completionReceiptID)
MergedInto(canonicalRootID, mergeGeneration)
```

Intersecting roots in the same `NodeProtectedCD` use one preallocated
`MergeOutcomeCell`:

```text
Open
Merged(canonicalRootID, newRootGeneration, newMembershipGeneration,
       exactUnionDigest, consumedCoverReservationID)
RejectedNoCover(reason)
```

`CommitFailureMerge` compares both root versions, the exact precharged union,
and cover reservation, then commits the MergeOutcome as the sole linearization
root. Root-parent fields and fixed-point invalidation are deterministic
idempotent projections. Until projection completes, canonical-root resolution
consults the committed MergeOutcome. Another merge involving either component
waits for those projections, preventing ambiguous merge chains.

Failure append validates canonical root, root generation, membership
generation, topology generation, journal generation, edge credit, and exact
work ID. Discovery consumes one credit before publishing bounded work. It never
creates credit.

Every finite item owns a `ProtectedWorkCreditCell`. Admission computes and
reserves its exact upper bound. A protected microstep atomically consumes one
credit and must either advance the registered phase or select a typed terminal
failure. Internal actions never increase credit. A merge transfers the sum of
both remaining credit sets plus a pre-reserved cover set and consumes one merge
credit; it does not allocate fresh potential.

For failure component `f`:

```text
FailureRank(f) =
  sum(remaining edge credits with their precomputed expansion weights)
  + sum(remaining explicit work credits)
  + sum(closeCut[s] - terminalPrefix[s] for included scopes)
  + remaining no-change-pass credits
  + remaining merge-projection credits
```

Each edge expansion weight is fixed at admission to
`1 + maximum total explicit work it can expose`. Discovering that edge removes
the weighted credit and adds at most the smaller explicit-work total, so rank
strictly decreases. Merge uses only precharged cover weights and consumes its
outer merge credit before inner ranks combine.

`CommitFailureComplete` requires the exact current root/membership/topology
generations, empty frontier, every included close prefix complete, all residual
drains terminal, and one no-change pass. A late merge advances generation,
invalidates the completion candidate, and performs another bounded pass. Gates
never reopen.

Complex topology proposals may come from an untrusted service, but the Monitor
validates one exact predeclared edge per protected occurrence. Corrupt or absent
proposals select the generic protected cursor or the precharged cover fail-stop
path. They do not create Linux fairness or enlarge authority.

## Source Issuance Fence And Transfer

`StreamCursorCell` and `SourceIssuanceFenceCell` share the same
`NodeProtectedCD`. `BeginSourceFence` atomically fixes
`qCut = nextOrdinal`, advances source-fence generation, and commits the complete
immutable TransferPlanCore. After that linearization, no release, opportunity,
permit, or entry for an ordinal `q >= qCut` can be created at the predecessor.

`TransferDecisionCell` is exactly:

```text
Open
RejectedBeforeFence(reason)
FenceCommitIntent(TransferPlanCoreID, successor, qCut, fenceGeneration)
MintFenced(TransferPlanCoreID, successor, qCut, fenceGeneration)
FinalizedStrong(terminalPrefixEvidence, residualEvidence)
FinalizedSafeGap(uncertaintySet, withdrawalEvidence)
FinalizedContinuityLost(uncertaintySet, requiredNewIncarnation)
```

There is no post-fence `Rejected` state. A failure after MintFenced retains
TransferID, successor, qCut, source fence generation, plan, ordinal ownership,
and uncertainty set. Recovery completes one of the three Finalized branches;
it never forgets the fence or reopens source issuance.

For `QUORUM_NO_REISSUE_FENCE`, the provider creates an immutable
`QuorumNoReissueFenceCore` and one local imported-use cell. The receipt binds:

```text
quorum configuration epoch and fault threshold
quorum commit position
stream key, incarnation, generation, and ordinal
source Node/Monitor/boot epoch and placement
ActivationInputCore ID and digest
EntryOutcomeCell identity and preallocated generation
DispatchUseID and ProtectionDomainKey/epoch
EntryAuthorityHorizon
TransferID and continuity policy
```

Permit publication and `ProviderCommitPhysicalEntry` both require the same
current imported receipt. EntryOutcome records its ID. The record means the
ordinal is irrevocably consumed and cannot be reissued; it does not assert
that entry, service, or an endpoint effect occurred. It remains reference-live
until a quorum closed-prefix certificate subsumes it.

Successor authority has one order:

```text
SourceIssuanceFence committed
  -> source terminal/residual evidence collected
  -> TransferDecision finalized
  -> authenticated FinalizedTransferCertificate
  -> SuccessorTransferAuthorizationCore
  -> one-use destination installation decision
  -> successor StreamCursor initialized at qCut
  -> destination release/admission/ready
```

No successor entry is possible from MintFenced alone. FinalizedStrong requires
an exact replicated terminal result for every predecessor ordinal below qCut.
FinalizedSafeGap requires qCut above every issued or ambiguous predecessor
ordinal and one timely claim-excluded withdrawal for each skipped guaranteed
ordinal. It preserves CPU-authority nonduplication but does not claim absence
of effects. FinalizedContinuityLost requires a new stream incarnation and makes
no same-incarnation service claim.

`LOCAL_ONLY` does not import a quorum receipt. Source loss after uncertain entry
can only FinalizeContinuityLost or remain stopped. It cannot continue the same
incarnation under exactly-once or gap-free language.

## Typed Time And Partition

Every time value is:

```text
(ClockDomainID, ClockEpoch, lowerBound, upperBound, TickUnit)
```

Only values in one domain/epoch may be compared directly. A direct relation
certificate binds source/destination domains and epochs, relation identity,
drift/error bounds, validity horizon, and monotonic direction. Transitive clock
inference is forbidden.

```text
not-before / source-stop conversion:
  destination lowerBound >= latest possible converted source boundary

not-after / expiry / deadline conversion:
  destination upperBound < earliest possible converted expiry
```

Physical entry rechecks the direct relation and local protected observation.
The latest entry time already subtracts the full residual stop bound. Raw Linux
time and wall-clock labels never authorize execution.

Partition policy is one of:

```text
CONNECTED_ONLY
CONTINUE_TO_CONSERVATIVE_EXPIRY
RECOVERY_ONLY
```

Quorum loss creates no new no-reissue receipt, strong transfer, renewal, or
remote lease. Already sealed local authority may continue only to its exact
conservative horizon. Afterward only predeclared stop, settlement, audit, and
recovery work can run. R9 does not jointly claim instant global revocation,
same-incarnation continuity, and unbounded partition availability.

## CPU Hotplug And Migration

The physical provider alone executes `ProviderOfflineCPU`. In one physical
action it disables the CPU gate, records a final or crash boundary, removes the
owner or marks fail-stop, advances `CpuIncarnationCell`, invalidates installed
context state, and emits an immutable OfflineOutcome receipt. It does not
write budget, service, or RuntimeStop ledgers.

The protected protocol separately consumes that receipt, requests/acknowledges
stop, pessimistically charges an unresolved armed interval, applies settlement,
and closes affected Ready/Lane projections. `ProviderOnlineCPU` creates an
empty new incarnation. Capacity is usable only after a future-effective
admission transition.

Pre-entry retargeting may preserve OpportunityID but must:

```text
ProviderRejectPhysicalEntry on the old target
release every old attempt reservation
commit AttemptOutcome = TerminalNeverEnteredRetargeted
clear activeAttemptID
allocate a new AttemptID, CPU incarnation, snapshot, permit, and entry cell
```

Post-entry migration never moves a RunToken, EntryOutcome, AttemptID, physical
interval, or service accumulator. It first stops and terminalizes the old
opportunity. If policy permits remaining CPU service to continue, it allocates:

```text
ContinuationOpportunityID =
  CID(oldOpportunityID,
      oldEntryGeneration,
      oldTerminalOutcomeID,
      migrationOrdinal,
      targetPlacement,
      oneUseServiceCarryReceiptID)
```

The carry receipt fixes only verified CPU service already credited and the
remaining service target. It is consumed once by the new opportunity. Endpoint
or device effects remain uncertain unless their own later models supply a
typed transfer/settlement receipt. No continuation is created after service is
already terminally delivered.

## Restart, Checkpoint, And Garbage Collection

`RestartBarrierCell[ConsistencyDomainID]` blocks new authority after boot or
protected-store restart until:

```text
every provider CPU owner is Idle or fail-stopped
every Open transaction deterministically selects CrashBeforeDecision abort
every durable intent completes its same-ID projections
every armed quantum has a committed actual or pessimistic boundary
every stop generation resumes to acknowledgment and settlement
all indexes are reconstructed from authoritative cells
```

Restart never creates a replacement identity for an unfinished transaction.
Committed generations never reopen. Boot-epoch replacement invalidates every
old token, installed context, occurrence grant, and CPU incarnation binding.

The exact `ReferenceClassRegistry` is:

```text
AUTHORITY_CHAIN
CONTEXT_RESIDENCY
REQUEST_SUFFIX
PUBLICATION_FORWARD
PUBLICATION_REVERSE
READY_ATTEMPT
ENTRY_RUNTIME
ASYNC_CARRIER
FAILURE_CLOSURE
FAILURE_MERGE
TRANSFER_SOURCE
TRANSFER_QUORUM
TRANSFER_SUCCESSOR
PHYSICAL_PROVIDER
ENDPOINT_RESIDUAL
REMOTE_CERTIFICATE
CHECKPOINT_AUDIT
TOMBSTONE_REDIRECT
```

Each class record fixes its edge extractor, sole cursor owner, authorization
horizon, checkpoint-vector component, and tombstone-clear predicate. The union
of extracted reference edges must equal the object-schema reference edges.

`CheckpointVectorCell` advances only after every class cursor up to the proposed
watermark is durably represented. Collection requires:

```text
authority and object terminal
nonwrapping generation fence committed
checkpoint vector dominates every local reference cursor
every remote authenticatable reference expired or issuer epoch revoked
no-reissue records incorporated into a quorum closed-prefix certificate
tombstone redirect safe for every still-authenticatable old identity
```

Otherwise the tombstone remains. GC is never required for stop or settlement
of already issued authority. Namespace exhaustion triggers scoped quiescence
and replacement, or permanent quarantine; it never wraps and never stops a
disjoint namespace merely to preserve an aliasing implementation.

## Protected Occurrence Grant Protocol

Every internal microstep that may be needed after authority publication has a
pre-reserved `ProtectedOccurrenceCore` and work credit. The provider owns:

```text
OccurrenceGrantCell =
  Absent(nextOccurrenceID)
  Granted(grantID, occurrenceID, exactActionInstanceID,
          providerEpoch, issuedTick, expiresTick)
  Acknowledged(grantID, resultDigest)
  ExpiredFailStop(grantID)
```

The protected protocol owns:

```text
OccurrenceOutcomeCell =
  Pending(grantID)
  Consumed(grantID, exactActionInstanceID,
           preStateDigest, postStateDigest, result)
```

Provider `DeliverOccurrenceGrant` publishes one immutable grant for the exact
next action instance. The machine IR contains a distinct action
`ConsumeGranted_<ActionID>` for every protected ActionID. That action atomically:

```text
validates the live grant and exact pre-state
consumes one work credit
commits the named protocol effect or its typed fail-closed result
writes OccurrenceOutcome
advances the item's occurrence cursor
```

The target microstep is not also a separate `Next` disjunct. There is no
generic `DoWork` or `ExecuteProtectedOccurrence` branch. Provider acknowledgment
is a later projection. Grant replay finds the consumed outcome and cannot
repeat the protocol effect.

An unconsumed expiry is not service success. Under the formula registry it
produces authenticated hardware/Monitor fail-stop or
`InternalGuaranteeViolation`; it cannot be counted as an external withdrawal.
The initial management bootstrap and every recovery item draw from boot-root
reserved occurrences, avoiding a self-scheduling cycle.

External evidence must exist in a typed environment readiness cell before an
action requiring it becomes the exact granted action. Waiting for a network,
issuer, disk, operator, or service response consumes no protected work credit.
The trusted time provider eventually records either valid evidence readiness or
the named finite timeout branch.

## Finite Work And Exact Ranks

NodeConfig fixes maximum microstep counts for each work class:

```text
BOOT
AUTHORITY_ISSUE
CONTEXT_INSTALL
ADMISSION
RESIDENCY_VALIDATE
RELEASE_PREPARE_ENTRY
RUNTIME_SETTLEMENT
SCOPE_CLOSE
FAILURE_CLOSE
TRANSFER
RESTART
CHECKPOINT_GC
EMERGENCY_STOP
```

Each admitted item owns a finite credit vector. Internal actions consume one
named credit and cannot create credit. A spawn/discovery operation may expose
child work only by consuming a preexisting weighted parent credit whose weight
is strictly greater than the maximum child total.

For item `i`:

```text
CreditRank(i) = sum(weight[class, phase] * remainingCredits[i,class,phase])
ProjectionRank(i) = number of false required idempotent projection bits
ItemRank(i) = (outerGenerationCredits(i), CreditRank(i), ProjectionRank(i))
```

Lexicographic order uses natural numbers and the explicit phase weights in the
future IR. Every `ConsumeGranted_<ActionID>` has delta `ItemRank' < ItemRank`,
or commits the item's absorbing InternalGuaranteeViolation when no legal
progress state exists. Provider-only physical actions use the bounded provider
formulas; they do not pretend to decrease a Monitor rank.

Attempt allocation consumes one outer attempt credit before inner attempt work
is initialized. Failure merge consumes a generation/cover credit before lower
component work is combined. Recurring release creates a new finite item from a
pre-admitted stream release cell; it is proved by induction over ordinals, not
by one globally decreasing rank over infinite operation.

Exact phase weights, child expansion maxima, and every action delta are
machine-IR fields. A validator recomputes them from ActionRegistry effects and
rejects a declared delta that does not match the transition.

## Datacenter Shards And Structural Cost

A logical shard is an ownership and admission partition, not a CPU and not a
Linux lock. Each local action writes one shard or one explicitly shared root
cell. Disjoint-key actions in `NodeProtectedCD` commute. Remote mutable state is
never read as if it shared the local consistency domain.

At least two independent guaranteed lanes must be represented with distinct
root cells, SchedContexts, execution cells, ready cells, aggregates, CPU
projections, and work credits. Shared administrative ancestors remain
conserved. Closing, failure, transfer, or namespace replacement in one lane
cannot wait for or invalidate the other unless an admitted shared dependency
and cover envelope explicitly contains both.

The structural cost contract is exact:

```text
admission and residency aggregate construction:
  O(declared bounded hierarchy + dependency + receipt + reverse-edge sets)

Ready preparation and new dispatch:
  exactly one ResidencyAggregate generation plus the fixed 20-component
  DispatchSnapshotV1; no dependency, Domain-population, or history scan

Root claim:
  fixed protected Ready/calendar index operations; no Linux rq dependence

physical entry:
  fixed provider guard schema and four-field physical product commit

same-activation resume:
  fixed owner/quantum/stop/aggregate/context comparisons; no durable write

local dependency close:
  O(exact reverse-registered affected aggregates + active affected lanes)

failure closure:
  O(precharged connected cover-envelope edges and prefix slots)

settlement and release:
  fixed ledger count and no closed-history scan

GC:
  incremental per-class cursors; never on the dispatch or stop critical path
```

These are transition-footprint properties, not cycle, latency, cache, TLB,
throughput, energy, memory, or cost-efficiency evidence. Strong continuity adds
quorum cost. Process-leaf isolation adds context/view switch cost. R9 makes no
claim that every workload is cheaper than a VM.

## Linux And Single-Image Refinement Boundary

Linux is a Domain-local ABI and policy/mechanism producer. It may propose
subject readiness, affinity, placement, SchedContext choice, migration,
certificate input, failure work, and typed async invocation. It cannot write
an R9 authority, owner, gate, budget, generation, physical-entry, stop, or
settlement cell.

The eventual Linux refinement must cover all scheduler classes and bypass
paths, including:

```text
CFS/EEVDF, RT, deadline, sched_ext, core scheduling, proxy execution,
stop/idle and scheduler-class iteration
wakeup, enqueue, dequeue, pick, context switch, tick, NO_HZ and timer paths
migration, affinity, cpuset, hotplug, push/pull, swap and core-cookie steal
fork/clone, exec, exit, ptrace/control and post-exit aftermath
workqueue, task_work, io_uring, softirq, IRQ, timers, RCU and kthreads
service-Domain IPC, endpoint completion and device completion
```

When disabled, a future Linux implementation must preserve upstream behavior
and layout contracts selected by its patch series. When enabled, no Linux-only
fallback may bypass protected entry. `sched_ext` remains policy experimentation,
not an enforcement root.

One logical datacenter OS means a global typed identity and authority namespace
compiled into finite node-local leases. It does not mean one global runqueue,
one synchronously shared kernel heap, or cross-cluster mutable-state atomicity.
R9 models one node-local enforcement component plus typed transfer imports.
Multi-node namespace, quorum, clock, migration, service, and management
composition remains a later model.

## Mutable Cell And Owner Registry

The following 77 cell kinds are the exact R9 mutable-state key set. A cell kind
may have a bounded map of instances; the map and every record field inherit the
same sole writer. Immutable cores named above are not cells.

Every `MP_*` subowner resolves to one protected writer authority
`MonitorOwner(NodeProtectedCD, cellKind, shardKey)`. The subowner name chooses
the only registered transition family for that kind; it is not a second
process with ambient write access. A bounded transaction over several `MP_*`
kinds is one `MonitorOwner` action with an exact write set. Provider cells never
participate in such a Monitor write set.

| ID | Mutable cell kind | Sole writer | State role |
| --- | --- | --- | --- |
| `MC-001` | BootPhaseCell | `MP_Boot` | bootstrap phase or BootFailed |
| `MC-002` | DomainRegistryCell | `MP_DomainRegistry` | global/local Domain incarnation status |
| `MC-003` | ProtectionDomainCell | `MP_DomainRegistry` | leaf/admin kind, epoch, lifecycle |
| `MC-004` | AuthorityIssueDecisionCell | `MP_AuthorityRegistry` | deterministic child issue intent/outcome |
| `MC-005` | RunAuthorizationCell | `MP_AuthorityRegistry` | live/revoke/retire generation |
| `MC-006` | RunUseAllocatorCell | `MP_AuthorityRegistry` | finite use quota and ordinal |
| `MC-007` | RunUseCell | `MP_AuthorityRegistry` | bound or released-before-entry use |
| `MC-008` | SpawnUseCell | `MP_AuthorityRegistry` | one child identity consumption |
| `MC-009` | SubjectLifecycleCell | `MP_DomainRegistry` | live/exec/exit/drain/retire |
| `MC-010` | ProgramTransitionCell | `MP_DomainRegistry` | ordered exec generation transition |
| `MC-011` | SchedContextStatusCell | `MP_AuthorityRegistry` | scheduling authority generation |
| `MC-012` | SchedBudgetAllocatorCell | `MP_AuthorityRegistry` | conserved SchedContext ticks |
| `MC-013` | SchedBudgetUseCell | `MP_AuthorityRegistry` | one dispatch debit/return binding |
| `MC-014` | RootBudgetUseCell | `MP_RootScheduler` | one root-cell debit/return binding |
| `MC-015` | ChargeRuleStatusCell | `MP_AuthorityRegistry` | charge authority generation |
| `MC-016` | ChargeUseCell | `MP_AuthorityRegistry` | one dispatch attribution binding |
| `MC-017` | AsyncCarrierUseCell | `MP_AuthorityRegistry` | one carrier-to-dispatch disposition |
| `MC-018` | ContextInstallDecisionCell | `MP_Context` | inert install commit/abort |
| `MC-019` | CurrentCapsuleCell | `MP_Context` | current reusable capsule generation |
| `MC-020` | InstalledContextCell | `PP_PhysicalCPU` | exact capsule installed per CPU incarnation |
| `MC-021` | AdmissionDecisionCell | `MP_Admission` | future-effective admission decision |
| `MC-022` | ParentResourceLedgerCell | `MP_Admission` | exact hierarchy resource reservations |
| `MC-023` | ResidencySlotCell | `MP_Residency` | bounded slot generation/lifecycle |
| `MC-024` | ResidencyDecisionCell | `MP_Residency` | residency publication intent/outcome |
| `MC-025` | ResidencyAggregateCell | `MP_Residency` | current/revoking/stopped aggregate generation |
| `MC-026` | ResidencyLaneProjectionCell | `MP_Residency` | per-CPU eligibility generation |
| `MC-027` | ScopeGateCell | `MP_Scope` | Open/Closing/Closed generation and cut |
| `MC-028` | EnrollmentCursorCell | `MP_Scope` | next reverse-slot ordinal |
| `MC-029` | ReverseEnrollmentSlotCell | `MP_Scope` | enrollment and terminal receipt |
| `MC-030` | PublicationDecisionCell | `MP_Scope` | CommittedVisible or aborted intent/outcome |
| `MC-031` | StreamCursorCell | `MP_Stream` | ordinal, prefix, suffix, generation |
| `MC-032` | SourceIssuanceFenceCell | `MP_Transfer` | irreversible qCut issuance fence |
| `MC-033` | ReleaseOutcomeCell | `MP_Stream` | released/burned exact ordinal result |
| `MC-034` | RequestCancellationCell | `MP_Stream` | monotonic cancellation disposition |
| `MC-035` | OpportunityStatusCell | `MP_Dispatch` | opportunity open/entered/terminal state |
| `MC-036` | ProtectedReadyCell | `MP_Dispatch` | ready/preparing/eligible/claimed/terminal |
| `MC-037` | RootServiceCell | `MP_RootScheduler` | imported/refined root service occurrence |
| `MC-038` | RootSlotOutcomeCell | `MP_RootScheduler` | exact claim/no-ready/delivery outcome |
| `MC-039` | AttemptAllocatorCell | `MP_Dispatch` | attempt ordinal, active pointer, ever-entered |
| `MC-040` | AttemptOutcomeCell | `MP_Dispatch` | never-entered/entered terminal root |
| `MC-041` | AuthorityReservationDecisionCell | `MP_Dispatch` | all-bound or all-aborted tuple |
| `MC-042` | ExecutionCellUseCell | `MP_Dispatch` | one physical execution-cell binding |
| `MC-043` | ConnectivityUseCell | `MP_Dispatch` | local one-use certificate consumption |
| `MC-044` | PrepareDecisionCell | `MP_Dispatch` | inert prepared bundle outcome |
| `MC-045` | PermitCell | `MP_Dispatch` | unpublished/live/revoked pre-entry permit |
| `MC-046` | EntryRequestStatusCell | `MP_Dispatch` | request published/cancelled/provider-resolved |
| `MC-047` | RuntimeStopCell | `MP_Dispatch` | open/requested/ack/settled stop generation |
| `MC-048` | ExecutionBudgetCell | `MP_Dispatch` | exact escrow and remaining ticks |
| `MC-049` | IntervalSettlementOutcomeCell | `MP_Dispatch` | one boundary charge/service outcome |
| `MC-050` | ServiceProgressCell | `MP_Dispatch` | verified ticks and first threshold time |
| `MC-051` | SettlementOutcomeCell | `MP_Dispatch` | sole final accounting decision |
| `MC-052` | LedgerApplyCell | `MP_Dispatch` | fixed idempotent application bits |
| `MC-053` | TerminalOutcomeCell | `MP_Dispatch` | absorbing opportunity result |
| `MC-054` | PortalCell | `PP_PhysicalCPU` | quiesce/context/quantum/active phase |
| `MC-055` | CpuOwnerCell | `PP_PhysicalCPU` | idle/entering/active/stopping/fail-stop |
| `MC-056` | EntryOutcomeCell | `PP_PhysicalCPU` | Pending/Entered/NeverEntered truth |
| `MC-057` | QuantumCell | `PP_PhysicalCPU` | repeated physical interval generation |
| `MC-058` | CpuIncarnationCell | `PP_PhysicalCPU` | online/offline nonaliasing identity |
| `MC-059` | OfflineOutcomeCell | `PP_PhysicalCPU` | final boundary and incarnation receipt |
| `MC-060` | OccurrenceGrantCell | `PP_Time` | exact due provider grant/expiry/fail-stop |
| `MC-061` | OccurrenceOutcomeCell | owning `MP_*` action actor | grant consumption and exact effect receipt |
| `MC-062` | ProtectedWorkCreditCell | owning `MP_*` item actor | finite class/phase credits |
| `MC-063` | FailureRootCell | `MP_FailureRegistry` | canonical root and fixed-point generations |
| `MC-064` | FailureJournalSlotCell | `MP_FailureRegistry` | one generation-checked work result |
| `MC-065` | FailureEdgeCreditCell | `MP_FailureRegistry` | prepaid discovery potential |
| `MC-066` | CoverReservationUseCell | `MP_FailureRegistry` | one bounded merge/fail-stop cover use |
| `MC-067` | MergeOutcomeCell | `MP_FailureRegistry` | sole component-union truth |
| `MC-068` | FixedPointOutcomeCell | `MP_FailureRegistry` | exact no-change completion result |
| `MC-069` | TransferDecisionCell | `MP_Transfer` | pre-fence reject or retained final outcome |
| `MC-070` | NoReissueImportCell | `MP_Transfer` | local one-use import of quorum fact |
| `MC-071` | SuccessorAuthorizationCell | `MP_Transfer` | finalized one-use successor install |
| `MC-072` | RestartBarrierCell | `MP_Checkpoint` | block/reconcile/reopen local CD |
| `MC-073` | CheckpointVectorCell | `MP_Checkpoint` | durable per-reference-class watermark |
| `MC-074` | ReferenceAndGCCell | `MP_Checkpoint` | class cursors, GC decisions, tombstones |
| `MC-075` | EnvironmentEvidenceCell | exact named `UE_*` actor | non-authoritative input/readiness only |
| `MC-076` | ExecutionCellPoolAllocatorCell | `MP_Residency` | finite resident execution-cell quota/ordinal |
| `MC-077` | ChargeUseAllocatorCell | `MP_AuthorityRegistry` | finite charge-rule use quota/ordinal |

Provider certificate records not listed as mutable cells are immutable facts.
`PP_ProtectedStore` supplies atomicity but owns no semantic value. The future IR
must prove:

```text
keys(MutableCellSchemaRegistry) = keys(OwnerRegistry)
keys(MutableCellSchemaRegistry) = union(ActionRegistry.exactWriteCellKinds)
for every cell kind: cardinality(writers) = 1
```

## Allocator And Identity Registry

Every fresh identity has one allocator and one burn point:

| Identity kind | Allocator / burn action |
| --- | --- |
| GlobalDomainKey, DomainIncarnation | issuer certificate consumed by `RegisterDomain` |
| ProtectionDomainKey | `ReserveProtectionLeaf` from Spawn/management transaction |
| ExecutionSubjectKey | `RegisterSubject` after one SpawnUse |
| SchedContextKey | `CommitSchedContextIssue` from parent budget reservation |
| RunAuthorizationID | `CommitAuthorityIssue` parent child ordinal |
| RunUseID | `AllocateFrozenRunUse` use ordinal |
| SchedBudgetUseID | `ReserveDispatchAuthority` from SchedBudgetAllocator |
| RootBudgetUseID | `ReserveDispatchAuthority` from exact RootServiceCell |
| ChargeUseID | `ReserveDispatchAuthority` from ChargeUseAllocator |
| ExecutionCellUseID | `ReserveDispatchAuthority` from resident pool allocator |
| AsyncCarrierID | `CreateAsyncCarrier` paired parent-use ordinals |
| DomainContextCapsuleID | `CommitContextInstall` decision identity |
| AdmissionID | `BeginAdmission` transaction slot |
| ResidencyID, aggregate generation | `ReserveResidency` and `CommitResidencyAggregate` |
| ResidencySlot generation | `ReuseResidencySlot` after complete retirement |
| PublicationID and reverse-slot ordinal | `BeginPublication` and atomic `EnrollScope` |
| Stream ordinal | atomic `CommitReleaseOrdinal` or source fence cut |
| OpportunityID, DispatchUseID, ReadyID | exact `ReleaseOutcomeCell` commit |
| ActivationAttemptID | `AllocateAttempt` CAS receipt |
| RootSlotClaimID | `RootSelectReady` root/ready joint claim |
| EntryOutcome generation, ActivationID | preallocation then provider Entered outcome |
| Quantum generation | `QuantumCell Idle(g) -> Prepared(g)` |
| Stop generation | `RequestStop` CAS |
| Interval settlement ID | exact boundary receipt generation consume |
| SettlementID | `CommitSettlementOutcome` CAS |
| FailureRootID | `CreateFailureRoot` from precharged failure event slot |
| MergeID | `CommitFailureMerge` consumes merge/cover credit |
| TransferID | `BeginSourceFence` transaction slot |
| Successor authorization ID | finalized transfer certificate consume |
| OccurrenceID and GrantID | compact calendar derivation and provider grant ordinal |
| Checkpoint, tombstone, namespace generation | checkpoint/GC owner nonwrapping cursor |

Burned, aborted, fenced, or terminal identities are never reused. A content ID
derived from an allocation receipt supplements but never replaces the protected
allocation CAS.

## Action Contract Schema And Closure Equalities

Every ActionRegistry row has exactly:

```text
actionID
bounded parameter sorts and parameter source
actor and writer authority
ConsistencyDomainID expression
guard formula ID and canonical AST
deterministic effect-function ID and canonical AST
exact read locations
exact write locations
exact UNCHANGED root-variable complement
exact local map-index/record-field frame
linearization location and old/new transition
crash class and deterministic successor formula
abstract refinement target and mapping
protected work class/credit or provider classification
rank ID and exact rank-delta formula
```

No protected effect uses an unconstrained `CHOOSE`. A selected value must be a
preexisting allocator result, provider input, or environment input. For action
`a` the machine validator recomputes:

```text
reads(a) = free state locations in guard/effect ASTs
writes(a) = primed locations in effect AST
unchanged(a) = StateVariables minus rootVariables(writes(a))
localFrame(a) = every unwritten bounded map index and record field preserved
ConsistencyDomainID(mutable atomic reads(a) union writes(a)) is a singleton
```

And globally:

```text
StateVariables = VariableRegistry keys = generated TLA VARIABLES
ActionIDs = ActionRegistry keys = generated Next disjunct IDs
ActionIDs = ProofRegistry operational-action coverage
Allocator kinds = every schema fresh-identity field kind
Owner cell kinds = MutableCellSchemaRegistry keys
```

`WellFormed` is an invariant. It is not inserted into action guards to hide
malformed products. Init implies WellFormed and every action preserves it.
Malformed low-level products refine to `A_ModelError`, which must be
unreachable.

## Closed Action Registry

The semantic ActionID key set is exactly the list below. For each protected
ActionID, generated `Next` contains one
`ConsumeGranted_<ActionID>(grant, boundedParameters)` branch. The unwrapped
name is a registry identifier, not another transition. Exact read locations,
record-field frames, guards, crash successors, and rank deltas are materialized
from the contracts above into the machine IR before review.

In the tables, compact notation such as `MC-001,002,003` means the exact set
`{MC-001, MC-002, MC-003}`. The effective write set of every generated protected
branch is its listed semantic set union `{MC-061, MC-062}` for that exact
occurrence outcome and work-credit instance. Provider and untrusted rows do not
receive this union. This expansion is part of the ActionRegistry generator and
the owner/action equality check.

### Boot, authority, subject, and context actions

| ActionID | Actor | Exact mutable cell kinds written | Linearization root |
| --- | --- | --- | --- |
| `ACT-B001-InstallBootRoot` | `MP_Boot` | `MC-001` | BootPhase |
| `ACT-B002-RegisterManagementDomain` | `MP_Boot` | `MC-001,002,003` | BootPhase |
| `ACT-B003-AcceptManagementContext` | `MP_Boot` | `MC-001,018,019` | BootPhase |
| `ACT-B004-AdmitManagementResidency` | `MP_Boot` | `MC-001,021,022,023,024,025` | BootPhase |
| `ACT-B005-PublishManagementTemplate` | `MP_Boot` | `MC-001,031,036,037` | BootPhase |
| `ACT-B006-EnableTenantAdmission` | `MP_Boot` | `MC-001` | BootPhase |
| `ACT-A001-BeginAuthorityIssue` | `MP_AuthorityRegistry` | `MC-004` | AuthorityIssueDecision |
| `ACT-A002-CommitAuthorityIssue` | `MP_AuthorityRegistry` | `MC-004,005,006` | AuthorityIssueDecision |
| `ACT-A003-CompleteAuthorityIssue` | `MP_AuthorityRegistry` | `MC-004` | AuthorityIssueDecision |
| `ACT-A004-AbortAuthorityIssue` | `MP_AuthorityRegistry` | `MC-004,005,006` | AuthorityIssueDecision |
| `ACT-A005-RevokeRunAuthorization` | `MP_AuthorityRegistry` | `MC-005,006,047,062` | RunAuthorization |
| `ACT-A006-AllocateFrozenRunUse` | `MP_AuthorityRegistry` | `MC-006,007` | RunUseAllocator |
| `ACT-A007-IssueSpawnAuthorization` | `MP_AuthorityRegistry` | `MC-004,008` | AuthorityIssueDecision |
| `ACT-A008-AllocateSpawnUse` | `MP_AuthorityRegistry` | `MC-008` | SpawnUse |
| `ACT-A009-RegisterSubject` | `MP_DomainRegistry` | `MC-002,003,008,009` | SpawnUse |
| `ACT-A010-CreateSchedContext` | `MP_AuthorityRegistry` | `MC-011,012` | SchedContextStatus |
| `ACT-A011-CloseSchedContext` | `MP_AuthorityRegistry` | `MC-011,012,047,062` | SchedContextStatus |
| `ACT-A012-CreateChargeRule` | `MP_AuthorityRegistry` | `MC-015,077` | ChargeRuleStatus |
| `ACT-A013-RevokeChargeRule` | `MP_AuthorityRegistry` | `MC-015,047,062,077` | ChargeRuleStatus |
| `ACT-A014-CreateAsyncCarrier` | `MP_AuthorityRegistry` | `MC-007,016,017` | AsyncCarrierUse |
| `ACT-A015-ConsumeAsyncCarrier` | `MP_AuthorityRegistry` | `MC-017` | AsyncCarrierUse |
| `ACT-A016-CancelAsyncCarrier` | `MP_AuthorityRegistry` | `MC-017` | AsyncCarrierUse |
| `ACT-S001-BeginExecTransition` | `MP_DomainRegistry` | `MC-009,010,047,062` | ProgramTransition |
| `ACT-S002-FenceOldProgramReady` | `MP_DomainRegistry` | `MC-009,010,036` | ProgramTransition |
| `ACT-S003-CommitProgramGeneration` | `MP_DomainRegistry` | `MC-009,010` | ProgramTransition |
| `ACT-S004-BeginSubjectExit` | `MP_DomainRegistry` | `MC-009,047,062` | SubjectLifecycle |
| `ACT-S005-CompleteSubjectDrain` | `MP_DomainRegistry` | `MC-009` | SubjectLifecycle |
| `ACT-S006-RetireSubject` | `MP_DomainRegistry` | `MC-002,003,009` | SubjectLifecycle |
| `ACT-C001-BeginContextInstall` | `MP_Context` | `MC-018` | ContextInstallDecision |
| `ACT-C002-CommitContextInstall` | `MP_Context` | `MC-018,019` | ContextInstallDecision |
| `ACT-C003-AbortContextInstall` | `MP_Context` | `MC-018` | ContextInstallDecision |
| `ACT-C004-BeginContextClose` | `MP_Context` | `MC-019,025,026,047,062` | CurrentCapsule |
| `ACT-C005-RetireContext` | `MP_Context` | `MC-019` | CurrentCapsule |

### Admission, residency, publication, and request actions

| ActionID | Actor | Exact mutable cell kinds written | Linearization root |
| --- | --- | --- | --- |
| `ACT-D001-BeginAdmission` | `MP_Admission` | `MC-021` | AdmissionDecision |
| `ACT-D002-EnrollAdmissionScope` | `MP_Admission` | `MC-027,028,029` | EnrollmentCursor |
| `ACT-D003-CommitAdmission` | `MP_Admission` | `MC-021,022` | AdmissionDecision |
| `ACT-D004-AbortAdmission` | `MP_Admission` | `MC-021,022` | AdmissionDecision |
| `ACT-D005-ApplyAdmissionBoundary` | `MP_Admission` | `MC-021,022,023` | AdmissionDecision |
| `ACT-D006-BeginServiceClassReplacement` | `MP_Admission` | `MC-021,022` | AdmissionDecision |
| `ACT-D007-ReserveResidency` | `MP_Residency` | `MC-023,024` | ResidencyDecision |
| `ACT-D008-CommitResidencyAggregate` | `MP_Residency` | `MC-024,025,026,076` | ResidencyDecision |
| `ACT-D009-RejectResidency` | `MP_Residency` | `MC-023,024,025` | ResidencyDecision |
| `ACT-D010-BeginResidencyClose` | `MP_Residency` | `MC-023,025,026,047,062,076` | ResidencyAggregate |
| `ACT-D011-StopResidency` | `MP_Residency` | `MC-023,025,026,076` | ResidencyAggregate |
| `ACT-D012-RetireResidency` | `MP_Residency` | `MC-023,024,025,026,076` | ResidencySlot |
| `ACT-D013-ReuseResidencySlot` | `MP_Residency` | `MC-023` | ResidencySlot |
| `ACT-P001-BeginPublication` | `MP_Scope` | `MC-030` | PublicationDecision |
| `ACT-P002-EnrollScope` | `MP_Scope` | `MC-027,028,029` | EnrollmentCursor |
| `ACT-P003-SealEnrollment` | `MP_Scope` | `MC-030` | PublicationDecision |
| `ACT-P004-CommitPublication` | `MP_Scope` | `MC-027,030` | PublicationDecision |
| `ACT-P005-AbortPublication` | `MP_Scope` | `MC-029,030` | PublicationDecision |
| `ACT-P006-BeginScopeClose` | `MP_Scope` | `MC-025,026,027,029,047,062` | ScopeGate |
| `ACT-P007-TerminalizeReverseSlot` | `MP_Scope` | `MC-029` | ReverseEnrollmentSlot |
| `ACT-P008-AdvanceClosePrefix` | `MP_Scope` | `MC-027,029` | ScopeGate |
| `ACT-R001-CommitReleaseOrdinal` | `MP_Stream` | `MC-031,033,035,036,062` | ReleaseOutcome |
| `ACT-R002-RequestCancellation` | `MP_Stream` | `MC-034,036,045,047,062` | RequestCancellation |
| `ACT-R003-CompleteCancellation` | `MP_Stream` | `MC-034` | RequestCancellation |
| `ACT-R004-ClaimReadyForPreparation` | `MP_Dispatch` | `MC-036,039,062` | ProtectedReady |
| `ACT-R005-PublishEntryEligible` | `MP_Dispatch` | `MC-036` | ProtectedReady |
| `ACT-R006-CancelProtectedReady` | `MP_Dispatch` | `MC-034,036,045` | ProtectedReady |
| `ACT-R007-RootSelectReady` | `MP_RootScheduler` | `MC-036,037,038` | RootSlotOutcome |
| `ACT-R008-CloseRootSlotNoEligible` | `MP_RootScheduler` | `MC-037,038` | RootSlotOutcome |

### Dispatch, entry request, runtime, and settlement actions

| ActionID | Actor | Exact mutable cell kinds written | Linearization root |
| --- | --- | --- | --- |
| `ACT-X001-AllocateAttempt` | `MP_Dispatch` | `MC-039,040` | AttemptAllocator |
| `ACT-X002-ReserveDispatchAuthority` | `MP_Dispatch` | `MC-007,012,013,014,016,017,037,041,042,043,048,076,077` | AuthorityReservationDecision |
| `ACT-X003-AbortDispatchAuthority` | `MP_Dispatch` | `MC-007,012,013,014,016,017,037,041,042,043,048,076,077` | AuthorityReservationDecision |
| `ACT-X004-ConsumeConnectivityUse` | `MP_Dispatch` | `MC-043` | ConnectivityUse |
| `ACT-X005-BeginPrepare` | `MP_Dispatch` | `MC-044` | PrepareDecision |
| `ACT-X006-CommitPreparedBundle` | `MP_Dispatch` | `MC-044` | PrepareDecision |
| `ACT-X007-AbortPrepare` | `MP_Dispatch` | `MC-044` | PrepareDecision |
| `ACT-X008-PublishPermit` | `MP_Dispatch` | `MC-045` | Permit |
| `ACT-X009-RevokePermit` | `MP_Dispatch` | `MC-045,046` | Permit |
| `ACT-X010-PublishEntryRequest` | `MP_Dispatch` | `MC-046` | EntryRequestStatus |
| `ACT-X011-CancelEntryRequest` | `MP_Dispatch` | `MC-045,046,047` | EntryRequestStatus |
| `ACT-X012-ObserveEntryOutcome` | `MP_Dispatch` | `MC-035,036,038,039,046` | EntryOutcome-derived projection receipt |
| `ACT-X013-RequestStop` | `MP_Dispatch` | `MC-047` | RuntimeStop |
| `ACT-X014-AcknowledgeStop` | `MP_Dispatch` | `MC-047` | RuntimeStop |
| `ACT-X015-ConsumePhysicalInterval` | `MP_Dispatch` | `MC-048,049,050` | IntervalSettlementOutcome |
| `ACT-X016-AcknowledgeIntervalForRecycle` | `MP_Dispatch` | `MC-049` | IntervalSettlementOutcome acknowledgment |
| `ACT-X017-PrepareContinuationQuantum` | `MP_Dispatch` | `MC-046,048` | EntryRequestStatus |
| `ACT-X018-CommitSettlementOutcome` | `MP_Dispatch` | `MC-047,051` | SettlementOutcome |
| `ACT-X019-ApplyRootLedger` | `MP_Dispatch` | `MC-014,037,052` | LedgerApply.rootApplied |
| `ACT-X020-ApplySchedLedger` | `MP_Dispatch` | `MC-012,013,052` | LedgerApply.schedApplied |
| `ACT-X021-ApplyExecutionAndRunLedger` | `MP_Dispatch` | `MC-007,042,048,052,076` | LedgerApply execution/run bits |
| `ACT-X022-ApplyChargeCarrierLedger` | `MP_Dispatch` | `MC-016,017,052,077` | LedgerApply charge/carrier bits |
| `ACT-X023-ApplyDeliveryAndAudit` | `MP_Dispatch` | `MC-038,052` | LedgerApply delivery/audit bits |
| `ACT-X024-CommitAttemptTerminal` | `MP_Dispatch` | `MC-039,040` | AttemptOutcome |
| `ACT-X025-ClearNeverEnteredAttempt` | `MP_Dispatch` | `MC-039` | AttemptAllocator |
| `ACT-X026-CommitOpportunityTerminal` | `MP_Dispatch` | `MC-035,036,053` | TerminalOutcome |

### Failure, transfer, recovery, and reclamation actions

| ActionID | Actor | Exact mutable cell kinds written | Linearization root |
| --- | --- | --- | --- |
| `ACT-F001-CreateFailureRoot` | `MP_FailureRegistry` | `MC-062,063,064,065` | FailureRoot |
| `ACT-F002-ConsumeFailureEdge` | `MP_FailureRegistry` | `MC-062,064,065` | FailureEdgeCredit |
| `ACT-F003-ApplyFailureWork` | `MP_FailureRegistry` | `MC-025,026,027,047,062,064` | FailureJournalSlot |
| `ACT-F004-CommitFailureMerge` | `MP_FailureRegistry` | `MC-062,063,066,067,068` | MergeOutcome |
| `ACT-F005-ApplyMergeProjection` | `MP_FailureRegistry` | `MC-063,067,068` | MergeOutcome projection bit |
| `ACT-F006-BeginNoChangePass` | `MP_FailureRegistry` | `MC-062,063,068` | FixedPointOutcome |
| `ACT-F007-CommitFailureComplete` | `MP_FailureRegistry` | `MC-063,068` | FixedPointOutcome |
| `ACT-T001-BeginSourceFence` | `MP_Transfer` | `MC-031,032,062,069` | SourceIssuanceFence |
| `ACT-T002-ImportNoReissueReceipt` | `MP_Transfer` | `MC-070` | NoReissueImport |
| `ACT-T003-FinalizeStrongTransfer` | `MP_Transfer` | `MC-069` | TransferDecision |
| `ACT-T004-FinalizeSafeGapTransfer` | `MP_Transfer` | `MC-069` | TransferDecision |
| `ACT-T005-FinalizeContinuityLost` | `MP_Transfer` | `MC-069` | TransferDecision |
| `ACT-T006-RejectTransferBeforeFence` | `MP_Transfer` | `MC-069` | TransferDecision |
| `ACT-T007-IssueSuccessorAuthorization` | `MP_Transfer` | `MC-069,071` | SuccessorAuthorization |
| `ACT-T008-InstallSuccessorStream` | `MP_Transfer` | `MC-031,071` | SuccessorAuthorization |
| `ACT-T009-BeginPreEntryRetarget` | `MP_Dispatch` | `MC-039,040,045,046,047` | AttemptOutcome |
| `ACT-T010-CreateContinuationOpportunity` | `MP_Transfer` | `MC-031,033,035,036,069` | one-use service carry receipt |
| `ACT-G001-EnterRestartBarrier` | `MP_Checkpoint` | `MC-072` | RestartBarrier |
| `ACT-G002-RecoverOpenTransaction` | owning `MP_*` | exact transaction decision cell | transaction decision |
| `ACT-G003-ApplyNextIntentProjection` | owning `MP_*` | decision cell plus one declared projection cell | projection bit/cursor |
| `ACT-G004-ReconcileOfflineCPU` | `MP_Checkpoint` | `MC-046,047,048,049,051,072` | OfflineOutcome consume |
| `ACT-G005-LeaveRestartBarrier` | `MP_Checkpoint` | `MC-072` | RestartBarrier |
| `ACT-G006-CommitCheckpointVector` | `MP_Checkpoint` | `MC-073,074` | CheckpointVector |
| `ACT-G007-CollectTerminalObject` | `MP_Checkpoint` | `MC-074` plus exact reclaimed vacant cell | GC decision |
| `ACT-G008-ReplaceOrQuarantineNamespace` | `MP_Checkpoint` | `MC-072,073,074` | namespace generation decision |

`ACT-G002` and `ACT-G003` are schema-generated finite families, not generic
semantic choices: each transaction kind has one statically named expanded
ActionID, exact decision cell, exact projection order, and exact write set in
the machine IR. If the generator leaves an unexpanded generic branch, closure
validation rejects.

### Provider and untrusted actions

These are direct `Next` branches and do not consume Monitor occurrence grants:

| ActionID | Actor | Exact mutable cell kinds written |
| --- | --- | --- |
| `ACT-V001-DeliverOccurrenceGrant` | `PP_Time` | `MC-060` |
| `ACT-V002-AcknowledgeOccurrence` | `PP_Time` | `MC-060` |
| `ACT-V003-ExpireOccurrenceFailStop` | `PP_Time` | `MC-060` and provider fail-stop fact |
| `ACT-V004-AdvanceProtectedClock` | `PP_Time` | provider time fact only |
| `ACT-V005-ProviderInstallContext` | `PP_PhysicalCPU` | `MC-020,054` |
| `ACT-V006-ProviderPrepareEntry` | `PP_PhysicalCPU` | `MC-054,055,057` |
| `ACT-V007-ProviderCommitPhysicalEntry` | `PP_PhysicalCPU` | `MC-054,055,056,057` |
| `ACT-V008-ProviderRejectPhysicalEntry` | `PP_PhysicalCPU` | `MC-054,055,056,057` |
| `ACT-V009-ProviderCommitBoundary` | `PP_PhysicalCPU` | `MC-054,057` |
| `ACT-V010-ProviderCrashBoundary` | `PP_PhysicalCPU` | `MC-054,055,057` |
| `ACT-V011-ProviderArmContinuation` | `PP_PhysicalCPU` | `MC-054,057` |
| `ACT-V012-ProviderResumeSameActivation` | `PP_PhysicalCPU` | no durable semantic write; provider trace only |
| `ACT-V013-ProviderStopOwner` | `PP_PhysicalCPU` | `MC-054,055,057` |
| `ACT-V014-ProviderOfflineCPU` | `PP_PhysicalCPU` | `MC-054,055,057,058,059` |
| `ACT-V015-ProviderOnlineCPU` | `PP_PhysicalCPU` | `MC-054,055,057,058` |
| `ACT-V016-PublishClusterCertificate` | `PP_ClusterQuorum` | immutable provider fact only |
| `ACT-V017-CommitQuorumNoReissue` | `PP_ClusterQuorum` | immutable provider fact only |
| `ACT-V018-ProviderNodeFailStop` | exact `PP_*` | provider fail-stop facts and physical gate fields only |
| `ACT-V019-ProviderRecycleQuantum` | `PP_PhysicalCPU` | `MC-054,057` |
| `ACT-V020-ProviderPrepareContinuation` | `PP_PhysicalCPU` | `MC-054,057` |
| `ACT-V021-PublishPhysicalContextReceipt` | `PP_PhysicalContext` | immutable provider fact only |
| `ACT-E001-PublishExternalEvidence` | exact `UE_*` | `MC-075` |
| `ACT-E002-WithdrawExternalEvidence` | exact `UE_*` | `MC-075` |
| `ACT-E003-PartitionUntrustedChannel` | `UE_NetworkStorage` | `MC-075` |
| `ACT-E004-RestoreUntrustedChannel` | `UE_NetworkStorage` | `MC-075` |

`Next` is exactly the disjunction of these provider/untrusted actions and every
expanded `ConsumeGranted_<protected ActionID>`. Standard TLA state stuttering
remains possible at the temporal-specification level; liveness follows only
from the explicit provider and Monitor formulas, never from deleting stutter.

## Deterministic Crash-Cut Registry

Crash occurs only between registered atomic actions. Volatile staging fields
are not authority and are explicitly discarded. The recovery function for each
cut is exact:

| Cut ID | Durable state at cut | Unique recovery successor |
| --- | --- | --- |
| `CUT-001` | authority issue Open | AbortIntent(CrashBeforeDecision); burn transaction identity |
| `CUT-002` | authority CommitIntent | complete same child publication; never choose abort |
| `CUT-003` | RunUse allocation committed | same finite use ordinal remains burned and bound |
| `CUT-004` | SpawnUse consumed, child incomplete | complete same child identity or terminalize it; no second child |
| `CUT-005` | exec CommitIntent | finish stop/drain/new program or terminal exit; never restore old ready |
| `CUT-006` | context staging, install Open | discard inert staging and AbortIntent |
| `CUT-007` | context CommitIntent | complete same capsule/current generation projection |
| `CUT-008` | admission Open or partial inert proof | AbortIntent and return only uncommitted reservations |
| `CUT-009` | admission CommitIntent | complete exact future-effective reservation and apply at same boundary |
| `CUT-010` | enrollment before atomic slot/cursor action | neither slot nor cursor exists |
| `CUT-011` | enrollment after atomic slot/cursor action | exact slot below the cursor and future closeCut |
| `CUT-012` | publication CommitIntent/Visible | remain committed; close may follow, abort cannot |
| `CUT-013` | scope close committed | same closeCut and aggregate generations remain revoked; stop work resumes |
| `CUT-014` | recurring release before commit | same ordinal remains next and unreleased |
| `CUT-015` | recurring release committed | ordinal burned and same Opportunity/Dispatch/Ready IDs reconstruct |
| `CUT-016` | attempt allocation committed | ordinal burned and same active AttemptID remains |
| `CUT-017` | dispatch reservation Open | AbortIntent(CrashBeforeDecision), no visible partial binding |
| `CUT-018` | dispatch CommitIntent | same seven-cell tuple remains bound; projections complete |
| `CUT-019` | connectivity before consume | local use remains Unused until expiry |
| `CUT-020` | connectivity after consume | same receipt; no second consume |
| `CUT-021` | inert prepare Open | discard staging and AbortIntent |
| `CUT-022` | prepared CommitIntent before permit | complete same descriptor, then publish same permit or revoke by current fact |
| `CUT-023` | permit live, EntryOutcome Pending | provider commits Entered or current invalidity commits NeverEntered in the common order |
| `CUT-024` | physical Entered committed | same ActivationID/owner/quantum; never call initial entry again |
| `CUT-025` | quantum Prepared but not Armed | CPU gate remains false; provider rejects or arms same request |
| `CUT-026` | quantum Armed without boundary | provider fail-stop and full-upper-bound CrashBoundary |
| `CUT-027` | boundary committed before interval consume | same boundary remains pending and consumes once |
| `CUT-028` | interval consume committed | budget/service/cursor all reflect same generation; no second charge |
| `CUT-029` | stop requested | same generation resumes to owner Idle/fail-stop and acknowledgment |
| `CUT-030` | physical owner Idle before Monitor ack | owner stays Idle; same receipt completes stop/settlement |
| `CUT-031` | SettlementOutcome committed, ledgers partial | apply least missing exact bit in canonical order |
| `CUT-032` | AttemptTerminal committed before clear | NeverEntered may clear once; Entered never clears |
| `CUT-033` | FailureJournal append | old or new whole journal version, never torn edge consumption |
| `CUT-034` | MergeOutcome committed, roots partial | committed outcome is canonical; complete exact projections before another merge |
| `CUT-035` | fixed-point candidate before late merge | late merge generation invalidates candidate; gates stay closed |
| `CUT-036` | source fence intent committed | qCut remains irreversible; same plan finalizes |
| `CUT-037` | no-reissue quorum fact committed | ordinal remains consumed even if local entry is unknown |
| `CUT-038` | transfer finalized, successor partial | same one-use successor authorization completes or stays fenced |
| `CUT-039` | provider CPU offline committed | old incarnation remains invalid; Monitor reconciles same final boundary |
| `CUT-040` | checkpoint before vector commit | no GC uses the proposed watermark |
| `CUT-041` | checkpoint vector committed before GC | same vector may authorize only exact class-safe reclamations |
| `CUT-042` | occurrence grant delivered, unconsumed | consume exact action before expiry or authenticated fail-stop; never reassign |
| `CUT-043` | occurrence effect and outcome committed | provider acknowledgment may replay; protocol effect cannot |

An Open transaction observed after boot deterministically selects
AbortIntent(CrashBeforeDecision), unless its decision and all authority-changing
writes were one already committed atomic action. No row contains a favorable
recovery choice.

## Total Abstraction And Safety Invariants

The abstraction function has a fixed precedence. Contradictory products map to
`A_ModelError`; they are not coerced into an ordinary terminal state.

```text
if not WellFormed                              -> A_ModelError
else if TerminalOutcome committed             -> A_Terminal
else if SettlementOutcome committed/partial   -> A_Settling
else if RuntimeStop requested/acknowledged     -> A_Stopping
else if EntryOutcome Entered and threshold     -> A_EnteredServed
else if EntryOutcome Entered                   -> A_EnteredUnserved
else if Root Ready claimed                     -> A_EntryClaimed
else if Ready EntryEligible                    -> A_EntryEligible
else if Prepare committed                      -> A_Prepared
else if authority reservation committed        -> A_AuthorityBound
else if Attempt active                         -> A_AttemptActive
else if Ready                                  -> A_Ready
else if ReleaseOutcome Released                -> A_Released
else if opportunity exists                     -> A_Open
else                                           -> A_Absent
```

The simultaneous invariant set is exact:

```text
INV-R9-TYPE                 WellFormed and bounded nonwrapping values
INV-R9-OWNER                one writer authority per mutable location
INV-R9-ID                   injective allocated identities, no reuse/alias
INV-R9-AUTH                 every child/use is parent-conserved and attenuated
INV-R9-USE                  one DispatchUse has at most one Entered outcome
INV-R9-READY                Ready/root claims are injective and generation-current
INV-R9-AGGREGATE            entry/resume uses one current aggregate generation
INV-R9-ENTRY                Domain instructions imply CurrentExecutable
INV-R9-PHYSICAL             one CPU has at most one physical owner
INV-R9-STOP                 revoked authority cannot arm a new quantum
INV-R9-BUDGET               root/Sched/execution equations and nonnegative escrow
INV-R9-INTERVAL             each quantum generation charges/credits at most once
INV-R9-SERVICE              verified service is a subset of charged owned intervals
INV-R9-SETTLEMENT           one outcome and idempotent fixed ledger applications
INV-R9-TERMINAL             terminal implies no physical owner or unsettled authority
INV-R9-PUBLICATION          visible publication has exact sealed local enrollment
INV-R9-CLOSE                close prefix is contiguous and never precedes terminals
INV-R9-FAILURE              closure traverses only precharged topology/cover
INV-R9-MERGE                one canonical merge outcome per compared generations
INV-R9-TRANSFER             qCut ownership disjoint and post-fence state retained
INV-R9-NOREISSUE            strong successor cannot reissue a fenced ordinal
INV-R9-TIME                 every authority comparison is typed and conservative
INV-R9-ASYNC                effective carrier authority is a subset of both parents
INV-R9-COALESCE             no authority, charge, cancellation, or result coalescing
INV-R9-BOOT                 no tenant authority before management bootstrap
INV-R9-SHARD                no cross-CD mutable atomicity or disjoint-lane wait
INV-R9-GC                   no reclaim while any registered reference can authenticate
INV-R9-OCCURRENCE           one grant consumes one exact action and one work credit
INV-R9-LINUX                untrusted state is never execution authority
```

All operational actions are proved against this set as one simultaneous
inductive invariant. One invariant may use the other invariants in the same
pre-state induction hypothesis; no derived theorem is an action assumption.

## Proof Dependency DAG

The proof key set and topological order are exactly:

```text
R9-P00-PINNED-REFERENCE-TARGETS
R9-P01-LOCAL-PROVIDER-INTERFACE-CONSISTENCY
R9-P02-CLOSED-IR-EQUALITY
R9-P03-FINITE-TYPE-SET-RESOURCE-ALGEBRA
R9-P04-INIT-WELLFORMED
R9-P05-IDENTITY-ALLOCATOR-NONALIAS
R9-P06-PARENT-AUTHORITY-CONSERVATION
R9-P07-PROTECTED-WORK-CREDIT-ALGEBRA
R9-P08-OPERATIONAL-SAFETY-SIMULTANEOUS-INVARIANT
R9-P09-DERIVED-AUTHORITY-ENTRY-BUDGET-SAFETY
R9-P10-DERIVED-PUBLICATION-FAILURE-TRANSFER-SAFETY
R9-P11-RANK-WELLFOUNDEDNESS-AND-ACTION-DELTAS
R9-P12-FINITE-OPPORTUNITY-PROGRESS
R9-P13-FINITE-FAILURE-CLOSURE-PROGRESS
R9-P14-FINITE-TRANSFER-RECOVERY-PROGRESS
R9-P15-FINITE-RESTART-GC-PROGRESS
R9-P16-FINITE-RECURRENCE-INDUCTION
R9-P17-CONDITIONAL-OMEGA-RECURRENCE
R9-P18-ROOT-AND-RESIDENCY-REFINEMENT
R9-P19-MULTILANE-NONINTERFERENCE
R9-P20-REGRESSION-AND-CLAIM-BOUNDARY
```

The exact predecessor relation is:

| Node | Direct predecessors |
| --- | --- |
| P00 | none |
| P01 | none |
| P02 | P00, P01 |
| P03 | P02 |
| P04 | P03 |
| P05 | P03, P04 |
| P06 | P03, P05 |
| P07 | P03, P05, P06 |
| P08 | P01, P02, P03, P04, P05, P06, P07 |
| P09 | P08 |
| P10 | P08, P09 |
| P11 | P02, P03, P07, P08 |
| P12 | P01, P08, P09, P11 |
| P13 | P01, P08, P10, P11 |
| P14 | P01, P08, P10, P11 |
| P15 | P01, P08, P10, P11 |
| P16 | P12, P13, P14, P15 |
| P17 | P01, P16 |
| P18 | P00, P08, P09, P10, P12 |
| P19 | P08, P09, P10, P12, P13, P14 |
| P20 | P02, P17, P18, P19 |

P01 requires an explicit finite joint witness in which all local provider
formulas hold simultaneously. This prevents inconsistent assumptions from
proving the system ex falso. It is only an interface-consistency witness, not
evidence that hardware or quorum implementations satisfy those formulas.

P08 covers every operational ActionID and is the only simultaneous invariant
component. Request/failure identity and topology are definitions/lemmas inside
P03-P07, not terminal theorems that depend back on runtime. Terminal closure is
proved in P10 after P08. This removes the R8 DYN_REQUEST/DYN_CHURN/DYN_COMPOSE
cycle.

The reference imports in P00 are refinement targets, not assumptions. In
particular, R9 must derive its exact Ready-to-entry service chain before mapping
to `GuaranteedRecurringService`; it cannot assume that imported liveness as its
own delivery receipt.

## Exact Progress Claims

Finite opportunity progress assumes only:

```text
current imported certificates remain valid to their declared horizon or
  publish the exact claim-excluded withdrawal in time
PF-OCC-01 and MonitorGrantConsumption
PF-CPU-BOUNDARY-01 and PF-CPU-STOP-01
reserved protected work and resource vectors remain uncorrupted
the protected protocol/Monitor root does not fail-stop
```

It does not assume Operational, successful completion, useful Domain work,
Linux fairness, endpoint success, or absence of InternalGuaranteeViolation.
Under those premises an admitted opportunity reaches ServedTerminal or its
exact claim-excluded outcome within its finite credit/rank and calendar bound.
InternalGuaranteeViolation falsifies the service theorem and is a model defect
or provider-premise failure to investigate; it is not a success branch.

Finite recurrence proves the property for every ordinal below a configured
bound. Conditional omega recurrence additionally assumes an infinite supply of
fresh nonwrapping namespace generations, finite-horizon external authority, and
provider progress. A finite implementation instead performs scoped renewal or
quarantine before exhaustion; it never wraps.

## Mutation Obligation Registry

Every normative requirement has a stable obligation ID. At minimum the
registry contains all 40 Analysis 0207 IDs, every prior unresolved regression
ID, all 29 R9 invariants, all 21 proof nodes, all ActionIDs, all crash cuts, all
owner/allocator/import equalities, and every claim/nonclaim flag.

Each mutation row is:

```text
mutationID
obligationID
exact registry ID and JSON pointer
operator ID
before canonical AST hash
after canonical AST hash
required witness ID
expected rejecting validator rule ID
validation stage
```

Required mutation families are:

```text
representation and typed-None substitution
identity edge deletion, back-edge, alias, reuse, and generation wrap
owner deletion, duplication, and wrong actor
authority widening, quota duplication, and parent reservation omission
Ready/root claim replay, cancel/claim race, and stale aggregate entry
physical entry partial commit, second entry, timer omission, and owner overlap
quantum replay, crash undercharge, service overcredit, and settlement double-refund
enroll/close hole, CommittedVisible rollback, prefix skip, and terminal self-cycle
failure stale append, late merge, missing cover, rank increase, and population scan
source fence/cursor split, post-fence reject, no-reissue omission, dual successor
async ambient worker authority and authority coalescing
cross-CD mutable read/write and expired remote certificate
recovery branch choice, replacement identity, and skipped intent projection
proof edge deletion/addition, hidden cycle, vacuous premise, and self-assumption
zero-mutant, disabled check, unknown-field acceptance, always-pass validator,
  baseline-mutant equivalence, wrong expected rule, and validator crash
```

The validator is not its own trust oracle. A separate hash-pinned meta-runner
mutates the validator and confirms that each meta-mutant is rejected. A campaign
with zero generated mutants, missing obligation coverage, aggregate-only
failure, or a rejecting rule different from the expected stable ID fails.

## R9 Blocker Closure Ledger

The human architecture claims candidate closure, not proof, for the 40 R9
blockers:

```text
R9-IMPORT-01                  Closed Import/Provider formula registries
R9-SCHEMA-OWNER-01            77-cell owner and action equality boundary
R9-RECOVERY-01                one intent branch and deterministic recovery
R9-RANK-FORMULA-01            finite credits, weights, temporal formulas
R9-PROOF-CYCLE-01             one simultaneous invariant and acyclic DAG
R9-MUTATION-01                stable obligation/pointer/rule schema
R9-ISSUANCE-01                parent-conserved attenuating child issue
R9-RUNUSE-ALLOC-01            finite use quota and burned ordinal
R9-SPAWN-LEAF-01              typed administrative parent versus physical leaf
R9-EXEC-EXIT-01               one-way ready/stop/drain/program ordering
R9-READY-01                   preallocated DispatchUse and generation lifecycle
R9-ROOT-READY-REFINE-01       no-ready gives zero service credit
R9-PORTAL-01                  exact provider portal sequence
R9-ENTRY-TIMER-01             one four-field CPU-enable primitive
R9-ENTRY-PROJECTION-01        consumed truth derived from EntryOutcome
R9-EXEC-PREDICATE-01          Normal plus bounded StopResidual predicate
R9-QUANTUM-01                 repeatable nonwrapping quantum cycle
R9-ATTEMPT-TERMINAL-01        settlement/terminal before retry clear
R9-OCCURRENCE-HANDSHAKE-01    provider grant plus exact generated consume action
R9-RELEASE-OUTCOME-01         ordinal and identity atomic outcome
R9-BUDGET-EQUATION-01         typed execution/crash/overhead conservation
R9-INTERVAL-SETTLEMENT-01     one boundary charge and service transaction
R9-BUDGET-SETTLEMENT-01       one outcome plus fixed idempotent ledger bits
R9-TERMINAL-CLOSE-01          terminal then reverse slot then prefix/fixed point
R9-ENROLL-CLOSE-01            slot/cursor atomicity and exact closeCut
R9-MERGE-OUTCOME-01           one local merge root and canonical projections
R9-COVER-RANK-01              weighted prepaid edge/merge/cover credits
R9-SOURCE-FENCE-01            stream cursor and qCut in one local transaction
R9-NOREISSUE-ENTRY-01         exact quorum receipt in permit and entry
R9-SUCCESSOR-AUTH-01          finalized transfer precedes successor authority
R9-FENCED-REJECTION-01        no post-fence rejection or payload loss
R9-CLOSE-RESUME-01            aggregate generation rejects re-arm/resume
R9-OFFLINE-ACTOR-01           provider physical result then Monitor reconciliation
R9-MIGRATION-01               terminal old and new continuation identity
R9-REFERENCE-REGISTRY-01      exact 18-class reference/GC registry
R9-ASYNC-CARRIER-01           typed caller/service/operation intersection
R9-COALESCING-01              authority-level coalescing forbidden
R9-RESIDENCY-AGGREGATE-01     variable validation off hot path, fixed dispatch
R9-CONSISTENCY-DOMAIN-01      local atomic order and certificate-only remote input
R9-MGMT-BOOTSTRAP-01          boot root through tenant-enable sequence
```

This ledger is a review checklist. Only machine IR equality checks, executable
witnesses, mutations, and fresh hostile review can mark these obligations
validated.

## Required Pre-IR And Review Evidence

Before semantic freeze, R9 requires:

```text
strict machine-readable registries with exact key equality
canonical formula ASTs and formula-slice hashes for every import/provider formula
one finite simultaneous-provider consistency witness
one accepting and one obligation-specific rejecting trace for every blocker
all crash-cut, race, replay, stale-generation, and exhaustion cases
all owner/allocator/action/read/write/frame/rank/proof graph equalities
two live disjoint lanes plus an admitted shared ancestor and scoped failure
LOCAL_ONLY, strong, safe-gap, continuity-loss, and quorum-loss transfer traces
process-leaf, shared-container-leaf, exec, exit, and async carrier traces
complete low-product abstraction and A_ModelError unreachability
representation, type, behavior, concurrency, crash, rank, and meta-mutations
four fresh exact hostile reviews with no encoder-created semantic choice
```

Only then may R9 become a frozen semantic IR source. TLA+ translation starts
after that freeze and must be generated or mechanically checked against the
same ActionRegistry, not rewritten from memory.

## Deferred System Models

R9 deliberately leaves these next components open:

```text
ENTRY/CODE:
  privileged entry/return, MemoryView/TLB, stack, shared executable integrity

STATE/SVC/MGMT:
  exhaustive mutable privileged-state ownership, typed service compromise,
  management/signing compromise and recovery

DEVICE:
  IOMMU, DMA, queue, IRQ, reset, firmware and device residual isolation

CLUSTER-PART:
  quorum/crypto/clock implementation, Byzantine variants, namespace and
  migration behavior across clusters

ENDPOINT:
  typed storage/network/GPU/service effect idempotency and settlement

LINUX-REFINE:
  complete scheduler/process/async hook refinement and upstream compatibility

COST/TCB:
  measured complete-path latency, throughput, memory, energy, switch cost,
  attacker amplification, TCB size and comparison with KVM/Firecracker
```

Each later model must implement the exact formula interface consumed here or
force R9 review to reopen. It cannot claim composition merely by sharing names.

## Current Claim Ceiling

```text
R8_candidate_rejected = true
R9_human_architecture_written = true
R9_machine_IR_written = false
R9_executable_witness_written = false
R9_independent_review_passed = false
R9_semantic_frozen = false
tla_authorized = false
tla_written = false
model_checked = false
RESIDENCY_DYN_model_supported = false
ENTRY_CODE_model_supported = false
STATE_SERVICE_MANAGEMENT_model_supported = false
CLUSTER_PART_model_supported = false
final_compositional_model_complete = false
Linux_implementation_authorized = false
hypervisor_level_protection_evidenced = false
performance_or_cost_efficiency_evidenced = false
multi_cluster_correctness_evidenced = false
deployment_ready = false
```

R9 is now eligible only for internal consistency checks and fresh read-only
hostile review. It is not eligible for TLA+, implementation, or any public
security/performance claim.
