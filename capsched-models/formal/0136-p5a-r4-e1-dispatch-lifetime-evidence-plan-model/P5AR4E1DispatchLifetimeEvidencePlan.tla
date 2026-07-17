---------- MODULE P5AR4E1DispatchLifetimeEvidencePlan ----------
EXTENDS Naturals, FiniteSets

CONSTANT Fault

Rqs == {"rq0", "rq1"}
BMax == 2

R4InputBound == Fault # "MissingR4InputBinding"
RejectedR3NotParent == Fault # "RejectedR3SourceParent"
FiniteAdmission == Fault # "UnboundedAdmission"
PrivateEnvelope == Fault # "MissingPrivateEnvelope"
NoOrdinaryHotGrowth == Fault # "OrdinaryHotObjectGrowth"
ExactE2Scope == Fault # "WrongE2Scope"
DefaultOff == Fault # "E2NotDefaultOff"
NoE2Behavior == Fault # "E2AddsBehavior"
DualArchLayout == Fault # "MissingDualArchLayout"
ExistingProbePreserved == Fault # "ExistingProbeChanged"
BalanceCallbackRejected == Fault # "BalanceCallbackUsedAsPostLock"
TwoStageBridge == Fault # "MissingTwoStageBridge"
KickUnderRqLock == Fault # "KickWithoutRqLock"
KickWithIrqsDisabled == Fault # "KickWithIrqsEnabled"
OneIrqPerRq == Fault # "MultipleIrqPerRq"
IrqDuplicateCoalesces == Fault # "IrqDuplicateGrows"
IrqCallbackDispatchOnly == Fault # "IrqCallbackRepairs"
IrqCallbackNoSchedulerLock == Fault # "IrqCallbackTakesSchedulerLock"
IrqCallbackUnconditionalQueue ==
    Fault # "IrqCallbackDoesNotUnconditionallyQueue"
QueueFalseKeepsOwner == Fault # "QueueFalseDropsOwner"
UnboundRecoveryWork == Fault # "CpuBoundRecoveryWork"
OneRecoveryOwner == Fault # "MultipleRecoveryOwners"
DirtyDepthBounded == Fault # "DirtyDepthExceedsBMax"
PublicationDoesNotGrowQueue == Fault # "PublicationQueueGrowth"
NewestDesiredWins == Fault # "NewestDesiredLost"
OneProjectionQuantum == Fault # "MultipleProjectionQuantum"
FinalGenerationRecheck == Fault # "MissingFinalGenerationRecheck"
RqThenOneMembership == Fault # "WrongLockOrder"
OrdinaryQueueOutsideSchedulerLock ==
    Fault # "OrdinaryQueueUnderSchedulerLock"
OneNotifierOwner == Fault # "NotifierMultipleOwners"
PublisherDoesNotWalk == Fault # "NotifierWalksInPublisher"
OneNotifierVisitQuantum == Fault # "NotifierMultiVisitQuantum"
CpumaskCursor == Fault # "NotifierCursorNotCpumask"
GenerationRestart == Fault # "MissingGenerationRestart"
MembershipRestart == Fault # "MissingMembershipRestart"
AdmissionHandshake == Fault # "MissingAdmissionHandshake"
PublisherClearHandshake == Fault # "MissingPublisherClearHandshake"
NotifierLogicalBound == Fault # "NotifierBoundMissing"
CurrentSeparate == Fault # "CurrentConflatedWithPicker"
ReschedUnderRqLock == Fault # "ReschedWithoutRqLock"
ReschedNotReceipt == Fault # "ReschedClaimedAsReceipt"
MigrationSingleContribution == Fault # "MigrationDoubleContribution"
OfflineStopsAdmission == Fault # "OfflineDoesNotClearAccepting"
HotplugStateOrder == Fault # "WrongHotplugStateOrder"
SleepableDrainOutsideRq == Fault # "SleepableDrainUnderRqLock"
IrqSyncBeforeCancel == Fault # "MissingIrqSyncBeforeCancel"
StopEnqueueBeforeCancel == Fault # "RacingEnqueueDuringCancel"
ResidualRefsPreserved == Fault # "ResidualRefsForgotten"
RcuBeforeFree == Fault # "MissingRcuGrace"
NoGenerationWrap == Fault # "GenerationWrapReuse"
CompleteE3Matrix == Fault # "MissingE3RaceMatrix"
CompleteE4Diagnostics == Fault # "MissingE4DiagnosticGate"
NoGlobalSettlementGate == Fault # "GlobalSettlementRestored"
NoContinuousPublishLiveness ==
    Fault # "ContinuousPublicationLivenessClaim"
NoWallClockClaim == Fault # "WallClockClaim"
NoLinuxSource == Fault # "LinuxSourceApproved"
NoRuntimeClaim == Fault # "RuntimeClaim"
NoProtectionClaim == Fault # "ProtectionClaim"
NoPerformanceClaim == Fault # "PerformanceClaim"
NoCostClaim == Fault # "CostClaim"

VARIABLES
    phase,
    generation,
    desiredGeneration,
    repairedGeneration,
    rqLocked,
    irqsDisabled,
    irqDepth,
    workDepth,
    workRunning,
    ownerDepth,
    dirtyDepth,
    callbackRepaired,
    callbackTookSchedulerLock,
    ordinaryQueueUnderLock,
    recoveryProjectionCount,
    notifierDepth,
    stableNotifierVisits,
    notifiedCurrent,
    stopRequested,
    accepting,
    newOwnershipDisabled,
    irqSynced,
    workCanceled,
    racingEnqueue,
    residualRefs,
    rcuGrace,
    freed

vars == <<
    phase,
    generation,
    desiredGeneration,
    repairedGeneration,
    rqLocked,
    irqsDisabled,
    irqDepth,
    workDepth,
    workRunning,
    ownerDepth,
    dirtyDepth,
    callbackRepaired,
    callbackTookSchedulerLock,
    ordinaryQueueUnderLock,
    recoveryProjectionCount,
    notifierDepth,
    stableNotifierVisits,
    notifiedCurrent,
    stopRequested,
    accepting,
    newOwnershipDisabled,
    irqSynced,
    workCanceled,
    racingEnqueue,
    residualRefs,
    rcuGrace,
    freed
>>

Phases == {
    "Start", "LockedKick", "DuplicateKick", "Republished2", "Unlocked",
    "IrqQueuedWork", "WorkerRunning", "Recovered2", "Published3",
    "OldVisit0", "Stable4", "OldTail1", "Restart0", "Restart1",
    "OfflineMarked", "IrqSynced", "WorkCanceled", "RefsDrained",
    "RcuDone", "Done"
}

Init ==
    /\ phase = "Start"
    /\ generation = 1
    /\ desiredGeneration = 1
    /\ repairedGeneration = 1
    /\ rqLocked = FALSE
    /\ irqsDisabled = FALSE
    /\ irqDepth = 0
    /\ workDepth = 0
    /\ workRunning = FALSE
    /\ ownerDepth = 0
    /\ dirtyDepth = 0
    /\ callbackRepaired = FALSE
    /\ callbackTookSchedulerLock = FALSE
    /\ ordinaryQueueUnderLock = FALSE
    /\ recoveryProjectionCount = 0
    /\ notifierDepth = 0
    /\ stableNotifierVisits = 0
    /\ notifiedCurrent = {}
    /\ stopRequested = {}
    /\ accepting = TRUE
    /\ newOwnershipDisabled = FALSE
    /\ irqSynced = FALSE
    /\ workCanceled = FALSE
    /\ racingEnqueue = FALSE
    /\ residualRefs = 0
    /\ rcuGrace = FALSE
    /\ freed = FALSE

RecordMismatchAndKick ==
    /\ phase = "Start"
    /\ phase' = "LockedKick"
    /\ rqLocked' = (Fault # "KickWithoutRqLock")
    /\ irqsDisabled' = (Fault # "KickWithIrqsEnabled")
    /\ irqDepth' = IF Fault = "MultipleIrqPerRq" THEN 2 ELSE 1
    /\ ownerDepth' = IF Fault = "MultipleRecoveryOwners" THEN 2 ELSE 1
    /\ dirtyDepth' = IF Fault = "DirtyDepthExceedsBMax" THEN 3 ELSE 1
    /\ UNCHANGED <<generation, desiredGeneration, repairedGeneration,
                    workDepth, workRunning, callbackRepaired,
                    callbackTookSchedulerLock, ordinaryQueueUnderLock,
                    recoveryProjectionCount, notifierDepth,
                    stableNotifierVisits, notifiedCurrent, stopRequested,
                    accepting, newOwnershipDisabled, irqSynced, workCanceled,
                    racingEnqueue, residualRefs, rcuGrace, freed>>

DuplicateKick ==
    /\ phase = "LockedKick"
    /\ phase' = "DuplicateKick"
    /\ irqDepth' = IF Fault = "IrqDuplicateGrows" THEN 2 ELSE irqDepth
    /\ dirtyDepth' = IF Fault = "PublicationQueueGrowth" THEN 2 ELSE dirtyDepth
    /\ UNCHANGED <<generation, desiredGeneration, repairedGeneration,
                    rqLocked, irqsDisabled, workDepth, workRunning, ownerDepth,
                    callbackRepaired, callbackTookSchedulerLock,
                    ordinaryQueueUnderLock, recoveryProjectionCount,
                    notifierDepth, stableNotifierVisits, notifiedCurrent,
                    stopRequested, accepting, newOwnershipDisabled, irqSynced,
                    workCanceled, racingEnqueue, residualRefs, rcuGrace, freed>>

RepublishWhileIrqPending ==
    /\ phase = "DuplicateKick"
    /\ phase' = "Republished2"
    /\ generation' = 2
    /\ desiredGeneration' = IF Fault = "NewestDesiredLost" THEN 1 ELSE 2
    /\ UNCHANGED <<repairedGeneration, rqLocked, irqsDisabled, irqDepth,
                    workDepth, workRunning, ownerDepth, dirtyDepth,
                    callbackRepaired, callbackTookSchedulerLock,
                    ordinaryQueueUnderLock, recoveryProjectionCount,
                    notifierDepth, stableNotifierVisits, notifiedCurrent,
                    stopRequested, accepting, newOwnershipDisabled, irqSynced,
                    workCanceled, racingEnqueue, residualRefs, rcuGrace, freed>>

UnlockRq ==
    /\ phase = "Republished2"
    /\ phase' = "Unlocked"
    /\ rqLocked' = FALSE
    /\ irqsDisabled' = FALSE
    /\ UNCHANGED <<generation, desiredGeneration, repairedGeneration,
                    irqDepth, workDepth, workRunning, ownerDepth, dirtyDepth,
                    callbackRepaired, callbackTookSchedulerLock,
                    ordinaryQueueUnderLock, recoveryProjectionCount,
                    notifierDepth, stableNotifierVisits, notifiedCurrent,
                    stopRequested, accepting, newOwnershipDisabled, irqSynced,
                    workCanceled, racingEnqueue, residualRefs, rcuGrace, freed>>

DispatchIrqToWork ==
    /\ phase = "Unlocked"
    /\ phase' = "IrqQueuedWork"
    /\ irqDepth' = 0
    /\ workDepth' = 1
    /\ callbackRepaired' = (Fault = "IrqCallbackRepairs")
    /\ callbackTookSchedulerLock' = (Fault = "IrqCallbackTakesSchedulerLock")
    /\ ordinaryQueueUnderLock' = (Fault = "OrdinaryQueueUnderSchedulerLock")
    /\ UNCHANGED <<generation, desiredGeneration, repairedGeneration,
                    rqLocked, irqsDisabled, workRunning, ownerDepth, dirtyDepth,
                    recoveryProjectionCount, notifierDepth,
                    stableNotifierVisits, notifiedCurrent, stopRequested,
                    accepting, newOwnershipDisabled, irqSynced, workCanceled,
                    racingEnqueue, residualRefs, rcuGrace, freed>>

StartWorker ==
    /\ phase = "IrqQueuedWork"
    /\ phase' = "WorkerRunning"
    /\ workDepth' = 0
    /\ workRunning' = TRUE
    /\ UNCHANGED <<generation, desiredGeneration, repairedGeneration,
                    rqLocked, irqsDisabled, irqDepth, ownerDepth, dirtyDepth,
                    callbackRepaired, callbackTookSchedulerLock,
                    ordinaryQueueUnderLock, recoveryProjectionCount,
                    notifierDepth, stableNotifierVisits, notifiedCurrent,
                    stopRequested, accepting, newOwnershipDisabled, irqSynced,
                    workCanceled, racingEnqueue, residualRefs, rcuGrace, freed>>

RecoverOneProjection ==
    /\ phase = "WorkerRunning"
    /\ phase' = "Recovered2"
    /\ repairedGeneration' =
          IF Fault = "MissingFinalGenerationRecheck" THEN 1 ELSE desiredGeneration
    /\ workRunning' = FALSE
    /\ ownerDepth' = 0
    /\ dirtyDepth' = 0
    /\ recoveryProjectionCount' =
          IF Fault = "MultipleProjectionQuantum" THEN 2 ELSE 1
    /\ UNCHANGED <<generation, desiredGeneration, rqLocked, irqsDisabled,
                    irqDepth, workDepth, callbackRepaired,
                    callbackTookSchedulerLock, ordinaryQueueUnderLock,
                    notifierDepth, stableNotifierVisits, notifiedCurrent,
                    stopRequested, accepting, newOwnershipDisabled, irqSynced,
                    workCanceled, racingEnqueue, residualRefs, rcuGrace, freed>>

PublishGeneration3 ==
    /\ phase = "Recovered2"
    /\ phase' = "Published3"
    /\ generation' = 3
    /\ notifierDepth' = IF Fault = "NotifierMultipleOwners" THEN 2 ELSE 1
    /\ UNCHANGED <<desiredGeneration, repairedGeneration, rqLocked,
                    irqsDisabled, irqDepth, workDepth, workRunning, ownerDepth,
                    dirtyDepth, callbackRepaired, callbackTookSchedulerLock,
                    ordinaryQueueUnderLock, recoveryProjectionCount,
                    stableNotifierVisits, notifiedCurrent, stopRequested,
                    accepting, newOwnershipDisabled, irqSynced, workCanceled,
                    racingEnqueue, residualRefs, rcuGrace, freed>>

OldPassVisitRq0 ==
    /\ phase = "Published3"
    /\ phase' = "OldVisit0"
    /\ notifiedCurrent' = {"rq0"}
    /\ UNCHANGED <<generation, desiredGeneration, repairedGeneration,
                    rqLocked, irqsDisabled, irqDepth, workDepth, workRunning,
                    ownerDepth, dirtyDepth, callbackRepaired,
                    callbackTookSchedulerLock, ordinaryQueueUnderLock,
                    recoveryProjectionCount, notifierDepth,
                    stableNotifierVisits, stopRequested, accepting,
                    newOwnershipDisabled, irqSynced, workCanceled,
                    racingEnqueue, residualRefs, rcuGrace, freed>>

FinalPublishGeneration4 ==
    /\ phase = "OldVisit0"
    /\ phase' = "Stable4"
    /\ generation' = 4
    /\ stableNotifierVisits' = 0
    /\ notifiedCurrent' = {}
    /\ stopRequested' = {}
    /\ UNCHANGED <<desiredGeneration, repairedGeneration, rqLocked,
                    irqsDisabled, irqDepth, workDepth, workRunning, ownerDepth,
                    dirtyDepth, callbackRepaired, callbackTookSchedulerLock,
                    ordinaryQueueUnderLock, recoveryProjectionCount,
                    notifierDepth, accepting, newOwnershipDisabled, irqSynced,
                    workCanceled, racingEnqueue, residualRefs, rcuGrace, freed>>

FinishOldPassRq1 ==
    /\ phase = "Stable4"
    /\ phase' = "OldTail1"
    /\ stableNotifierVisits' = 1
    /\ notifiedCurrent' = {"rq1"}
    /\ stopRequested' = {"rq1"}
    /\ UNCHANGED <<generation, desiredGeneration, repairedGeneration,
                    rqLocked, irqsDisabled, irqDepth, workDepth, workRunning,
                    ownerDepth, dirtyDepth, callbackRepaired,
                    callbackTookSchedulerLock, ordinaryQueueUnderLock,
                    recoveryProjectionCount, notifierDepth, accepting,
                    newOwnershipDisabled, irqSynced, workCanceled,
                    racingEnqueue, residualRefs, rcuGrace, freed>>

RestartVisitRq0 ==
    /\ phase = "OldTail1"
    /\ phase' = "Restart0"
    /\ stableNotifierVisits' = 2
    /\ notifiedCurrent' = notifiedCurrent \cup {"rq0"}
    /\ stopRequested' = stopRequested \cup {"rq0"}
    /\ UNCHANGED <<generation, desiredGeneration, repairedGeneration,
                    rqLocked, irqsDisabled, irqDepth, workDepth, workRunning,
                    ownerDepth, dirtyDepth, callbackRepaired,
                    callbackTookSchedulerLock, ordinaryQueueUnderLock,
                    recoveryProjectionCount, notifierDepth, accepting,
                    newOwnershipDisabled, irqSynced, workCanceled,
                    racingEnqueue, residualRefs, rcuGrace, freed>>

RestartVisitRq1 ==
    /\ phase = "Restart0"
    /\ phase' = "Restart1"
    /\ stableNotifierVisits' = 3
    /\ notifiedCurrent' = Rqs
    /\ stopRequested' = Rqs
    /\ notifierDepth' = 0
    /\ UNCHANGED <<generation, desiredGeneration, repairedGeneration,
                    rqLocked, irqsDisabled, irqDepth, workDepth, workRunning,
                    ownerDepth, dirtyDepth, callbackRepaired,
                    callbackTookSchedulerLock, ordinaryQueueUnderLock,
                    recoveryProjectionCount, accepting, newOwnershipDisabled,
                    irqSynced, workCanceled, racingEnqueue, residualRefs,
                    rcuGrace, freed>>

MarkOffline ==
    /\ phase = "Restart1"
    /\ phase' = "OfflineMarked"
    /\ accepting' = (Fault = "OfflineDoesNotClearAccepting")
    /\ newOwnershipDisabled' = TRUE
    /\ residualRefs' = 1
    /\ UNCHANGED <<generation, desiredGeneration, repairedGeneration,
                    rqLocked, irqsDisabled, irqDepth, workDepth, workRunning,
                    ownerDepth, dirtyDepth, callbackRepaired,
                    callbackTookSchedulerLock, ordinaryQueueUnderLock,
                    recoveryProjectionCount, notifierDepth,
                    stableNotifierVisits, notifiedCurrent, stopRequested,
                    irqSynced, workCanceled, racingEnqueue, rcuGrace, freed>>

SynchronizeIrqWork ==
    /\ phase = "OfflineMarked"
    /\ phase' = "IrqSynced"
    /\ irqSynced' = TRUE
    /\ UNCHANGED <<generation, desiredGeneration, repairedGeneration,
                    rqLocked, irqsDisabled, irqDepth, workDepth, workRunning,
                    ownerDepth, dirtyDepth, callbackRepaired,
                    callbackTookSchedulerLock, ordinaryQueueUnderLock,
                    recoveryProjectionCount, notifierDepth,
                    stableNotifierVisits, notifiedCurrent, stopRequested,
                    accepting, newOwnershipDisabled, workCanceled,
                    racingEnqueue, residualRefs, rcuGrace, freed>>

CancelRecoveryWork ==
    /\ phase = "IrqSynced"
    /\ phase' = "WorkCanceled"
    /\ workCanceled' = TRUE
    /\ racingEnqueue' = (Fault = "RacingEnqueueDuringCancel")
    /\ UNCHANGED <<generation, desiredGeneration, repairedGeneration,
                    rqLocked, irqsDisabled, irqDepth, workDepth, workRunning,
                    ownerDepth, dirtyDepth, callbackRepaired,
                    callbackTookSchedulerLock, ordinaryQueueUnderLock,
                    recoveryProjectionCount, notifierDepth,
                    stableNotifierVisits, notifiedCurrent, stopRequested,
                    accepting, newOwnershipDisabled, irqSynced, residualRefs,
                    rcuGrace, freed>>

DrainResidualReferences ==
    /\ phase = "WorkCanceled"
    /\ phase' = "RefsDrained"
    /\ residualRefs' = IF Fault = "ResidualRefsForgotten" THEN 1 ELSE 0
    /\ UNCHANGED <<generation, desiredGeneration, repairedGeneration,
                    rqLocked, irqsDisabled, irqDepth, workDepth, workRunning,
                    ownerDepth, dirtyDepth, callbackRepaired,
                    callbackTookSchedulerLock, ordinaryQueueUnderLock,
                    recoveryProjectionCount, notifierDepth,
                    stableNotifierVisits, notifiedCurrent, stopRequested,
                    accepting, newOwnershipDisabled, irqSynced, workCanceled,
                    racingEnqueue, rcuGrace, freed>>

WaitRcuGrace ==
    /\ phase = "RefsDrained"
    /\ phase' = "RcuDone"
    /\ rcuGrace' = (Fault # "MissingRcuGrace")
    /\ UNCHANGED <<generation, desiredGeneration, repairedGeneration,
                    rqLocked, irqsDisabled, irqDepth, workDepth, workRunning,
                    ownerDepth, dirtyDepth, callbackRepaired,
                    callbackTookSchedulerLock, ordinaryQueueUnderLock,
                    recoveryProjectionCount, notifierDepth,
                    stableNotifierVisits, notifiedCurrent, stopRequested,
                    accepting, newOwnershipDisabled, irqSynced, workCanceled,
                    racingEnqueue, residualRefs, freed>>

FreeAfterDrain ==
    /\ phase = "RcuDone"
    /\ phase' = "Done"
    /\ freed' = TRUE
    /\ UNCHANGED <<generation, desiredGeneration, repairedGeneration,
                    rqLocked, irqsDisabled, irqDepth, workDepth, workRunning,
                    ownerDepth, dirtyDepth, callbackRepaired,
                    callbackTookSchedulerLock, ordinaryQueueUnderLock,
                    recoveryProjectionCount, notifierDepth,
                    stableNotifierVisits, notifiedCurrent, stopRequested,
                    accepting, newOwnershipDisabled, irqSynced, workCanceled,
                    racingEnqueue, residualRefs, rcuGrace>>

Done == phase = "Done" /\ UNCHANGED vars

Next ==
    \/ RecordMismatchAndKick
    \/ DuplicateKick
    \/ RepublishWhileIrqPending
    \/ UnlockRq
    \/ DispatchIrqToWork
    \/ StartWorker
    \/ RecoverOneProjection
    \/ PublishGeneration3
    \/ OldPassVisitRq0
    \/ FinalPublishGeneration4
    \/ FinishOldPassRq1
    \/ RestartVisitRq0
    \/ RestartVisitRq1
    \/ MarkOffline
    \/ SynchronizeIrqWork
    \/ CancelRecoveryWork
    \/ DrainResidualReferences
    \/ WaitRcuGrace
    \/ FreeAfterDrain
    \/ Done

Spec ==
    /\ Init
    /\ [][Next]_vars
    /\ WF_vars(RecordMismatchAndKick)
    /\ WF_vars(DuplicateKick)
    /\ WF_vars(RepublishWhileIrqPending)
    /\ WF_vars(UnlockRq)
    /\ WF_vars(DispatchIrqToWork)
    /\ WF_vars(StartWorker)
    /\ WF_vars(RecoverOneProjection)
    /\ WF_vars(PublishGeneration3)
    /\ WF_vars(OldPassVisitRq0)
    /\ WF_vars(FinalPublishGeneration4)
    /\ WF_vars(FinishOldPassRq1)
    /\ WF_vars(RestartVisitRq0)
    /\ WF_vars(RestartVisitRq1)
    /\ WF_vars(MarkOffline)
    /\ WF_vars(SynchronizeIrqWork)
    /\ WF_vars(CancelRecoveryWork)
    /\ WF_vars(DrainResidualReferences)
    /\ WF_vars(WaitRcuGrace)
    /\ WF_vars(FreeAfterDrain)

TypeOK ==
    /\ phase \in Phases
    /\ generation \in 1..4
    /\ desiredGeneration \in 1..4
    /\ repairedGeneration \in 1..4
    /\ rqLocked \in BOOLEAN
    /\ irqsDisabled \in BOOLEAN
    /\ irqDepth \in 0..2
    /\ workDepth \in 0..1
    /\ workRunning \in BOOLEAN
    /\ ownerDepth \in 0..2
    /\ dirtyDepth \in 0..3
    /\ callbackRepaired \in BOOLEAN
    /\ callbackTookSchedulerLock \in BOOLEAN
    /\ ordinaryQueueUnderLock \in BOOLEAN
    /\ recoveryProjectionCount \in 0..2
    /\ notifierDepth \in 0..2
    /\ stableNotifierVisits \in 0..4
    /\ notifiedCurrent \subseteq Rqs
    /\ stopRequested \subseteq Rqs
    /\ accepting \in BOOLEAN
    /\ newOwnershipDisabled \in BOOLEAN
    /\ irqSynced \in BOOLEAN
    /\ workCanceled \in BOOLEAN
    /\ racingEnqueue \in BOOLEAN
    /\ residualRefs \in 0..1
    /\ rcuGrace \in BOOLEAN
    /\ freed \in BOOLEAN

StateSafety ==
    /\ rqLocked => irqsDisabled
    /\ irqDepth <= 1
    /\ ownerDepth <= 1
    /\ dirtyDepth <= BMax
    /\ (workDepth > 0 \/ workRunning) => ownerDepth = 1
    /\ ~callbackRepaired
    /\ ~callbackTookSchedulerLock
    /\ ~ordinaryQueueUnderLock
    /\ recoveryProjectionCount <= 1
    /\ notifierDepth <= 1
    /\ stableNotifierVisits <= 2 * Cardinality(Rqs)
    /\ phase \in {"Recovered2", "Published3", "OldVisit0", "Stable4",
                   "OldTail1", "Restart0", "Restart1", "OfflineMarked",
                   "IrqSynced", "WorkCanceled", "RefsDrained", "RcuDone",
                   "Done"} => repairedGeneration = 2
    /\ phase \in {"Restart1", "OfflineMarked", "IrqSynced", "WorkCanceled",
                   "RefsDrained", "RcuDone", "Done"} =>
          /\ notifiedCurrent = Rqs
          /\ stopRequested = Rqs
    /\ workCanceled =>
          /\ irqSynced
          /\ newOwnershipDisabled
          /\ ~racingEnqueue
    /\ freed =>
          /\ ~accepting
          /\ newOwnershipDisabled
          /\ irqSynced
          /\ workCanceled
          /\ residualRefs = 0
          /\ rcuGrace

PlanContract ==
    /\ R4InputBound
    /\ RejectedR3NotParent
    /\ FiniteAdmission
    /\ PrivateEnvelope
    /\ NoOrdinaryHotGrowth
    /\ ExactE2Scope
    /\ DefaultOff
    /\ NoE2Behavior
    /\ DualArchLayout
    /\ ExistingProbePreserved
    /\ BalanceCallbackRejected
    /\ TwoStageBridge
    /\ KickUnderRqLock
    /\ KickWithIrqsDisabled
    /\ OneIrqPerRq
    /\ IrqDuplicateCoalesces
    /\ IrqCallbackDispatchOnly
    /\ IrqCallbackNoSchedulerLock
    /\ IrqCallbackUnconditionalQueue
    /\ QueueFalseKeepsOwner
    /\ UnboundRecoveryWork
    /\ OneRecoveryOwner
    /\ DirtyDepthBounded
    /\ PublicationDoesNotGrowQueue
    /\ NewestDesiredWins
    /\ OneProjectionQuantum
    /\ FinalGenerationRecheck
    /\ RqThenOneMembership
    /\ OrdinaryQueueOutsideSchedulerLock
    /\ OneNotifierOwner
    /\ PublisherDoesNotWalk
    /\ OneNotifierVisitQuantum
    /\ CpumaskCursor
    /\ GenerationRestart
    /\ MembershipRestart
    /\ AdmissionHandshake
    /\ PublisherClearHandshake
    /\ NotifierLogicalBound
    /\ CurrentSeparate
    /\ ReschedUnderRqLock
    /\ ReschedNotReceipt
    /\ MigrationSingleContribution
    /\ OfflineStopsAdmission
    /\ HotplugStateOrder
    /\ SleepableDrainOutsideRq
    /\ IrqSyncBeforeCancel
    /\ StopEnqueueBeforeCancel
    /\ ResidualRefsPreserved
    /\ RcuBeforeFree
    /\ NoGenerationWrap
    /\ CompleteE3Matrix
    /\ CompleteE4Diagnostics
    /\ NoGlobalSettlementGate
    /\ NoContinuousPublishLiveness
    /\ NoWallClockClaim
    /\ NoLinuxSource
    /\ NoRuntimeClaim
    /\ NoProtectionClaim
    /\ NoPerformanceClaim
    /\ NoCostClaim

Safety == TypeOK /\ StateSafety /\ PlanContract

BridgeEventuallyRecoversNewest ==
    (phase = "Unlocked") ~> (repairedGeneration = 2)

StableNotifierEventuallyVisitsAll ==
    (phase = "Stable4") ~> (notifiedCurrent = Rqs /\ stopRequested = Rqs)

OfflineEventuallyDrains ==
    (phase = "OfflineMarked") ~> (phase = "Done" /\ freed)

=============================================================================
