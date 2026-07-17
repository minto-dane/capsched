---------- MODULE P5AR3E3BucketConcurrencyEvidencePlan ----------
EXTENDS Naturals

CONSTANT Fault

ExactE2Closure == Fault # "E2ClosureMoved"
ExactCandidate == Fault # "CandidateMoved"
DirectCandidateParent == Fault # "CandidateNotDirect"
ExactTwoFileScope == Fault # "ScopeExpanded"
E2LayoutPreserved == Fault # "E2LayoutDrift"
ProbeValuesPreserved == Fault # "ProbeValuesDrift"
PrimaryFrozen == Fault # "PrimaryMoved"
PatchQueueFrozen == Fault # "PatchQueueMoved"
DefaultOff == Fault # "ConfigNotDefaultOff"
BuiltinKUnitDependency == Fault # "KUnitDependencyMissing"
SameTranslationUnit == Fault # "SeparateTranslationUnit"
NoMakefileOrHeaderChange == Fault # "MakefileOrHeaderChanged"
NoRuntimeHooks == Fault # "RuntimeHookAdded"
NoExportOrAbi == Fault # "ExportAbiAdded"
FiniteBMax == Fault # "UnboundedBMax"
SlotBeforeContribution == Fault # "SlotAfterContribution"
Slot65FailsClosed == Fault # "Slot65Accepted"
AllocationRollback == Fault # "PartialAllocationVisible"
AllAllocationFaultSites == Fault # "FaultSiteMissing"
NoAllocationUnderLocks == Fault # "AllocationUnderLock"
RqThenOneMembership == Fault # "WrongLockOrder"
PublisherNoRq == Fault # "PublisherTakesRq"
QueueOutsideLocks == Fault # "QueueUnderLock"
CancelOutsideLocks == Fault # "CancelUnderLock"
WorkRefBeforeQueue == Fault # "MissingWorkRef"
QueueFalseKeepsOwner == Fault # "QueueFalseDropsOwner"
WorkerPublisherHandshake == Fault # "ClearRepublishRace"
GenerationNeverWraps == Fault # "GenerationWrap"
StaleWorkerCannotFresh == Fault # "StaleWorkerFresh"
FreshSnapshotEveryPublish == Fault # "SnapshotOmitted"
ActiveBitTracksContribution == Fault # "ActiveBitEarlyClear"
AllContributionClasses == Fault # "ContributionClassMissing"
MigrationNeutral == Fault # "MigrationNotNeutral"
DestinationFailureFailsClosed == Fault # "DestinationFailureLeaks"
OnlineInitBeforeAccept == Fault # "OnlineAcceptsEarly"
OfflineStopsAdmission == Fault # "OfflineAcceptsNew"
OfflineDrainsResidual == Fault # "OfflineForgetsResidual"
UnboundWork == Fault # "CpuBoundWork"
RetireStopsQueueing == Fault # "RetireAllowsQueue"
DrainBeforeFree == Fault # "FreeBeforeCancel"
RcuGraceBeforeFree == Fault # "MissingRcuGrace"
ReadersDrainBeforeFree == Fault # "ReaderAfterFree"
IndependentOracle == Fault # "OracleSharesHelpers"
CompleteCaseFamilies == Fault # "MissingRequiredFamily"
DeterministicRaceControl == Fault # "TimeOnlyRace"
FullBuildMatrix == Fault # "BuildMatrixReduced"
RequiredDiagnostics == Fault # "DiagnosticMissing"
NoWarningAccepted == Fault # "WarningAccepted"
E4RemainsSeparate == Fault # "E4Premature"
CrossPathNonClaim == Fault # "CrossPathClaim"
ProductionNonClaim == Fault # "ProductionClaim"

BMax == IF FiniteBMax THEN 64 ELSE 65

VARIABLES phase,
          initialized,
          accepting,
          allocationComplete,
          slots,
          contributions,
          activeBit,
          desiredGeneration,
          observedGeneration,
          workOwned,
          workPending,
          workRunning,
          neutral,
          queueingDisabled,
          unpublished,
          taskRefs,
          contributionRefs,
          projectionRefs,
          readers,
          rcuGrace,
          freed

vars == <<phase, initialized, accepting, allocationComplete, slots,
          contributions, activeBit, desiredGeneration, observedGeneration,
          workOwned, workPending, workRunning, neutral, queueingDisabled,
          unpublished, taskRefs, contributionRefs, projectionRefs, readers,
          rcuGrace, freed>>

Init ==
    /\ phase = "Start"
    /\ initialized = FALSE
    /\ accepting = FALSE
    /\ allocationComplete = FALSE
    /\ slots = 0
    /\ contributions = 0
    /\ activeBit = FALSE
    /\ desiredGeneration = 1
    /\ observedGeneration = 1
    /\ workOwned = FALSE
    /\ workPending = FALSE
    /\ workRunning = FALSE
    /\ neutral = TRUE
    /\ queueingDisabled = FALSE
    /\ unpublished = FALSE
    /\ taskRefs = 0
    /\ contributionRefs = 0
    /\ projectionRefs = 0
    /\ readers = 1
    /\ rcuGrace = FALSE
    /\ freed = FALSE

Prepare ==
    /\ phase = "Start"
    /\ phase' = "Prepared"
    /\ allocationComplete' = AllocationRollback
    /\ projectionRefs' = IF AllocationRollback THEN 1 ELSE 0
    /\ UNCHANGED <<initialized, accepting, slots, contributions, activeBit,
                    desiredGeneration, observedGeneration, workOwned,
                    workPending, workRunning, neutral, queueingDisabled,
                    unpublished, taskRefs, contributionRefs, readers,
                    rcuGrace, freed>>

Online ==
    /\ phase = "Prepared"
    /\ phase' = "Online"
    /\ initialized' = OnlineInitBeforeAccept
    /\ accepting' = TRUE
    /\ UNCHANGED <<allocationComplete, slots, contributions, activeBit,
                    desiredGeneration, observedGeneration, workOwned,
                    workPending, workRunning, neutral, queueingDisabled,
                    unpublished, taskRefs, contributionRefs, projectionRefs,
                    readers, rcuGrace, freed>>

AdmitAtBoundary ==
    /\ phase = "Online"
    /\ phase' = "Admitted"
    /\ slots' = IF ~FiniteBMax THEN 65
                  ELSE IF SlotBeforeContribution THEN 64 ELSE 0
    /\ contributions' = 1
    /\ activeBit' = ActiveBitTracksContribution
    /\ neutral' = FALSE
    /\ taskRefs' = 1
    /\ contributionRefs' = 1
    /\ UNCHANGED <<initialized, accepting, allocationComplete,
                    desiredGeneration, observedGeneration, workOwned,
                    workPending, workRunning, queueingDisabled, unpublished,
                    projectionRefs, readers, rcuGrace, freed>>

Publish ==
    /\ phase = "Admitted"
    /\ phase' = "Published"
    /\ desiredGeneration' = 2
    /\ workOwned' = WorkRefBeforeQueue
    /\ workPending' = TRUE
    /\ UNCHANGED <<initialized, accepting, allocationComplete, slots,
                    contributions, activeBit, observedGeneration, workRunning,
                    neutral, queueingDisabled, unpublished, taskRefs,
                    contributionRefs, projectionRefs, readers, rcuGrace,
                    freed>>

BeginWork ==
    /\ phase = "Published"
    /\ phase' = "Working"
    /\ workPending' = FALSE
    /\ workRunning' = TRUE
    /\ UNCHANGED <<initialized, accepting, allocationComplete, slots,
                    contributions, activeBit, desiredGeneration,
                    observedGeneration, workOwned, neutral, queueingDisabled,
                    unpublished, taskRefs, contributionRefs, projectionRefs,
                    readers, rcuGrace, freed>>

Republish ==
    /\ phase = "Working"
    /\ phase' = "Republished"
    /\ desiredGeneration' = 3
    /\ UNCHANGED <<initialized, accepting, allocationComplete, slots,
                    contributions, activeBit, observedGeneration, workOwned,
                    workPending, workRunning, neutral, queueingDisabled,
                    unpublished, taskRefs, contributionRefs, projectionRefs,
                    readers, rcuGrace, freed>>

FinishWork ==
    /\ phase = "Republished"
    /\ phase' = "Settled"
    /\ observedGeneration' = IF WorkerPublisherHandshake
                              THEN desiredGeneration ELSE 2
    /\ workOwned' = FALSE
    /\ workPending' = FALSE
    /\ workRunning' = FALSE
    /\ UNCHANGED <<initialized, accepting, allocationComplete, slots,
                    contributions, activeBit, desiredGeneration, neutral,
                    queueingDisabled, unpublished, taskRefs,
                    contributionRefs, projectionRefs, readers, rcuGrace,
                    freed>>

RemoveForMigration ==
    /\ phase = "Settled"
    /\ phase' = "Neutral"
    /\ contributions' = IF MigrationNeutral THEN 0 ELSE 1
    /\ contributionRefs' = IF MigrationNeutral THEN 0 ELSE 1
    /\ activeBit' = IF MigrationNeutral THEN FALSE ELSE TRUE
    /\ neutral' = TRUE
    /\ UNCHANGED <<initialized, accepting, allocationComplete, slots,
                    desiredGeneration, observedGeneration, workOwned,
                    workPending, workRunning, queueingDisabled, unpublished,
                    taskRefs, projectionRefs, readers, rcuGrace, freed>>

RejectDestination ==
    /\ phase = "Neutral"
    /\ phase' = "DestinationRejected"
    /\ contributions' = IF DestinationFailureFailsClosed THEN 0 ELSE 1
    /\ contributionRefs' = IF DestinationFailureFailsClosed THEN 0 ELSE 1
    /\ activeBit' = IF DestinationFailureFailsClosed THEN FALSE ELSE TRUE
    /\ UNCHANGED <<initialized, accepting, allocationComplete, slots,
                    desiredGeneration, observedGeneration, workOwned,
                    workPending, workRunning, neutral, queueingDisabled,
                    unpublished, taskRefs, projectionRefs, readers, rcuGrace,
                    freed>>

DetachTask ==
    /\ phase = "DestinationRejected"
    /\ phase' = "Detached"
    /\ taskRefs' = 0
    /\ UNCHANGED <<initialized, accepting, allocationComplete, slots,
                    contributions, activeBit, desiredGeneration,
                    observedGeneration, workOwned, workPending, workRunning,
                    neutral, queueingDisabled, unpublished, contributionRefs,
                    projectionRefs, readers, rcuGrace, freed>>

Offline ==
    /\ phase = "Detached"
    /\ phase' = "Offline"
    /\ accepting' = ~OfflineStopsAdmission
    /\ contributions' = IF OfflineDrainsResidual THEN 0 ELSE 1
    /\ contributionRefs' = IF OfflineDrainsResidual THEN 0 ELSE 1
    /\ activeBit' = IF OfflineDrainsResidual THEN FALSE ELSE TRUE
    /\ UNCHANGED <<initialized, allocationComplete, slots,
                    desiredGeneration, observedGeneration, workOwned,
                    workPending, workRunning, neutral, queueingDisabled,
                    unpublished, taskRefs, projectionRefs, readers, rcuGrace,
                    freed>>

Retire ==
    /\ phase = "Offline"
    /\ phase' = "Retiring"
    /\ queueingDisabled' = RetireStopsQueueing
    /\ unpublished' = TRUE
    /\ UNCHANGED <<initialized, accepting, allocationComplete, slots,
                    contributions, activeBit, desiredGeneration,
                    observedGeneration, workOwned, workPending, workRunning,
                    neutral, taskRefs, contributionRefs, projectionRefs,
                    readers, rcuGrace, freed>>

Drain ==
    /\ phase = "Retiring"
    /\ phase' = "Drained"
    /\ workOwned' = ~DrainBeforeFree
    /\ workPending' = FALSE
    /\ workRunning' = FALSE
    /\ projectionRefs' = IF DrainBeforeFree THEN 0 ELSE projectionRefs
    /\ slots' = IF DrainBeforeFree THEN 0 ELSE slots
    /\ allocationComplete' = ~DrainBeforeFree
    /\ UNCHANGED <<initialized, accepting, contributions, activeBit,
                    desiredGeneration, observedGeneration, neutral,
                    queueingDisabled, unpublished, taskRefs,
                    contributionRefs, readers, rcuGrace, freed>>

WaitForReadersAndRcu ==
    /\ phase = "Drained"
    /\ phase' = "Quiescent"
    /\ readers' = IF ReadersDrainBeforeFree THEN 0 ELSE readers
    /\ rcuGrace' = RcuGraceBeforeFree
    /\ UNCHANGED <<initialized, accepting, allocationComplete, slots,
                    contributions, activeBit, desiredGeneration,
                    observedGeneration, workOwned, workPending, workRunning,
                    neutral, queueingDisabled, unpublished, taskRefs,
                    contributionRefs, projectionRefs, freed>>

Free ==
    /\ phase = "Quiescent"
    /\ phase' = "Freed"
    /\ freed' = TRUE
    /\ UNCHANGED <<initialized, accepting, allocationComplete, slots,
                    contributions, activeBit, desiredGeneration,
                    observedGeneration, workOwned, workPending, workRunning,
                    neutral, queueingDisabled, unpublished, taskRefs,
                    contributionRefs, projectionRefs, readers, rcuGrace>>

StayFreed == phase = "Freed" /\ UNCHANGED vars

Next == Prepare \/ Online \/ AdmitAtBoundary \/ Publish \/ BeginWork \/
        Republish \/ FinishWork \/ RemoveForMigration \/ RejectDestination \/
        DetachTask \/ Offline \/ Retire \/ Drain \/ WaitForReadersAndRcu \/
        Free \/ StayFreed

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ phase \in {"Start", "Prepared", "Online", "Admitted", "Published",
                    "Working", "Republished", "Settled", "Neutral",
                    "DestinationRejected", "Detached", "Offline", "Retiring",
                    "Drained", "Quiescent", "Freed"}
    /\ initialized \in BOOLEAN
    /\ accepting \in BOOLEAN
    /\ allocationComplete \in BOOLEAN
    /\ slots \in Nat
    /\ contributions \in Nat
    /\ activeBit \in BOOLEAN
    /\ desiredGeneration \in Nat
    /\ observedGeneration \in Nat
    /\ workOwned \in BOOLEAN
    /\ workPending \in BOOLEAN
    /\ workRunning \in BOOLEAN
    /\ neutral \in BOOLEAN
    /\ queueingDisabled \in BOOLEAN
    /\ unpublished \in BOOLEAN
    /\ taskRefs \in Nat
    /\ contributionRefs \in Nat
    /\ projectionRefs \in Nat
    /\ readers \in Nat
    /\ rcuGrace \in BOOLEAN
    /\ freed \in BOOLEAN

StateSafety ==
    /\ slots <= BMax
    /\ accepting => initialized
    /\ contributions > 0 =>
        /\ allocationComplete
        /\ slots > 0
        /\ activeBit
        /\ accepting
        /\ contributionRefs > 0
    /\ activeBit = (contributions > 0)
    /\ workPending => workOwned
    /\ workRunning => workOwned
    /\ desiredGeneration > observedGeneration =>
        workOwned \/ workPending \/ workRunning
    /\ neutral => contributions = 0 /\ ~activeBit
    /\ phase \in {"Offline", "Retiring", "Drained", "Quiescent", "Freed"}
       => ~accepting
    /\ phase \in {"Retiring", "Drained", "Quiescent", "Freed"} =>
        /\ queueingDisabled
        /\ unpublished
    /\ freed =>
        /\ ~allocationComplete
        /\ slots = 0
        /\ contributions = 0
        /\ ~activeBit
        /\ ~workOwned
        /\ ~workPending
        /\ ~workRunning
        /\ taskRefs = 0
        /\ contributionRefs = 0
        /\ projectionRefs = 0
        /\ readers = 0
        /\ rcuGrace

PlanContract ==
    /\ ExactE2Closure
    /\ ExactCandidate
    /\ DirectCandidateParent
    /\ ExactTwoFileScope
    /\ E2LayoutPreserved
    /\ ProbeValuesPreserved
    /\ PrimaryFrozen
    /\ PatchQueueFrozen
    /\ DefaultOff
    /\ BuiltinKUnitDependency
    /\ SameTranslationUnit
    /\ NoMakefileOrHeaderChange
    /\ NoRuntimeHooks
    /\ NoExportOrAbi
    /\ FiniteBMax
    /\ SlotBeforeContribution
    /\ Slot65FailsClosed
    /\ AllocationRollback
    /\ AllAllocationFaultSites
    /\ NoAllocationUnderLocks
    /\ RqThenOneMembership
    /\ PublisherNoRq
    /\ QueueOutsideLocks
    /\ CancelOutsideLocks
    /\ WorkRefBeforeQueue
    /\ QueueFalseKeepsOwner
    /\ WorkerPublisherHandshake
    /\ GenerationNeverWraps
    /\ StaleWorkerCannotFresh
    /\ FreshSnapshotEveryPublish
    /\ ActiveBitTracksContribution
    /\ AllContributionClasses
    /\ MigrationNeutral
    /\ DestinationFailureFailsClosed
    /\ OnlineInitBeforeAccept
    /\ OfflineStopsAdmission
    /\ OfflineDrainsResidual
    /\ UnboundWork
    /\ RetireStopsQueueing
    /\ DrainBeforeFree
    /\ RcuGraceBeforeFree
    /\ ReadersDrainBeforeFree
    /\ IndependentOracle
    /\ CompleteCaseFamilies
    /\ DeterministicRaceControl
    /\ FullBuildMatrix
    /\ RequiredDiagnostics
    /\ NoWarningAccepted
    /\ E4RemainsSeparate
    /\ CrossPathNonClaim
    /\ ProductionNonClaim

Safety == TypeOK /\ StateSafety /\ PlanContract

=============================================================================
