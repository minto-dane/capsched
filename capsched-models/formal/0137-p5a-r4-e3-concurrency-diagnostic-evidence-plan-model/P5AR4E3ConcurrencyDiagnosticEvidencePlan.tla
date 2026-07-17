---------- MODULE P5AR4E3ConcurrencyDiagnosticEvidencePlan ----------
EXTENDS Naturals, FiniteSets

CONSTANT Fault

Rqs == {"rq0", "rq1"}
NotifierVisitLimit == 2 * Cardinality(Rqs)

E2ClosureBound == Fault # "MissingE2ClosureBinding"
ExactFutureParent == Fault # "WrongFutureParent"
ExactTwoFileScope == Fault # "WrongTwoFileScope"
E2LayoutPreserved == Fault # "E2LayoutBlockChanged"
E2ProbeValuesPreserved == Fault # "E2ProbeValuesChanged"
E3DefaultOff == Fault # "E3NotDefaultOff"
E3NotSelectedNormally == Fault # "E3SelectedNormally"
DisabledArtifactsAbsent == Fault # "DisabledArtifactPresent"
NoPublicSurface == Fault # "PublicSurfaceAdded"
NoLiveSchedulerAttachment == Fault # "LiveSchedulerAttachment"
NoProductionHook == Fault # "ProductionHookCalled"
OracleIndependent == Fault # "OracleSharesImplementationHelper"
OracleEveryCheckpoint == Fault # "OracleCheckpointMissing"
EveryCaseReceipt == Fault # "CaseReceiptMissing"
FiniteCapacity == Fault # "CapacityExceeded"
PreRunnableSlot == Fault # "SlotAfterContribution"
NoAllocationUnderLock == Fault # "AllocationUnderLock"
AllocationFailureClean == Fault # "AllocationFailureLeaks"
AllocationRetry == Fault # "AllocationRetryMissing"
UnboundRecoveryWork == Fault # "CpuBoundRecoveryWork"
RqThenOneMembership == Fault # "WrongRecoveryLockOrder"
PublisherDoesNotWalk == Fault # "PublisherWalksMembership"
PublisherQueuesAfterUnlock == Fault # "PublisherQueuesUnderLock"
CpumaskCursor == Fault # "NonCpumaskCursor"
ReschedNotMonitorReceipt == Fault # "ReschedClaimedAsMonitorReceipt"
NoTimingSleepProof == Fault # "TimingSleepUsedAsProof"
NoRequiredCaseSkipped == Fault # "RequiredCaseSkipped"
CompleteDiagnosticMatrix == Fault # "DiagnosticMatrixReduced"
NoWarningAccepted == Fault # "WarningAccepted"
NoWallClockLiveness == Fault # "WallClockLivenessClaim"
NoLinuxSourceApproval == Fault # "LinuxSourceApproved"
NoRuntimeClaim == Fault # "RuntimeClaim"
NoProtectionClaim == Fault # "ProtectionClaim"
NoPerformanceClaim == Fault # "PerformanceClaim"
NoDeploymentClaim == Fault # "DeploymentClaim"
NoDatacenterClaim == Fault # "DatacenterClaim"

VARIABLES
    phase,
    generation,
    desiredGeneration,
    observedGeneration,
    rqLocked,
    irqsDisabled,
    irqDepth,
    workDepth,
    workRunning,
    recoveryOwnerDepth,
    dirtyDepth,
    dirtyReference,
    dirtyUnique,
    callbackQueuedWork,
    callbackRepaired,
    callbackTookSchedulerLock,
    recoveryProjectionCount,
    requeueUnderSchedulerLock,
    finalInsertCovered,
    notifierOwnerDepth,
    notifierVisits,
    notifierVisitQuantum,
    generationRestarted,
    membershipRestarted,
    ownerClearRaceCovered,
    lateAdmissionCovered,
    stableMembershipCovered,
    currentRequestSequence,
    currentObservedSequence,
    completionClaimedEarly,
    sourceContribution,
    destinationContribution,
    neutralObserved,
    destinationFailureRestoredSource,
    initializedBeforeAccepting,
    accepting,
    queueingEnabled,
    sleepableDrainUnderLock,
    irqSynced,
    workCanceled,
    racingEnqueue,
    retiring,
    retirementNewOwner,
    unpublished,
    residualReferences,
    rcuGrace,
    generationWrapped,
    freed

vars == <<
    phase,
    generation,
    desiredGeneration,
    observedGeneration,
    rqLocked,
    irqsDisabled,
    irqDepth,
    workDepth,
    workRunning,
    recoveryOwnerDepth,
    dirtyDepth,
    dirtyReference,
    dirtyUnique,
    callbackQueuedWork,
    callbackRepaired,
    callbackTookSchedulerLock,
    recoveryProjectionCount,
    requeueUnderSchedulerLock,
    finalInsertCovered,
    notifierOwnerDepth,
    notifierVisits,
    notifierVisitQuantum,
    generationRestarted,
    membershipRestarted,
    ownerClearRaceCovered,
    lateAdmissionCovered,
    stableMembershipCovered,
    currentRequestSequence,
    currentObservedSequence,
    completionClaimedEarly,
    sourceContribution,
    destinationContribution,
    neutralObserved,
    destinationFailureRestoredSource,
    initializedBeforeAccepting,
    accepting,
    queueingEnabled,
    sleepableDrainUnderLock,
    irqSynced,
    workCanceled,
    racingEnqueue,
    retiring,
    retirementNewOwner,
    unpublished,
    residualReferences,
    rcuGrace,
    generationWrapped,
    freed
>>

Phases == {
    "Start", "LockedKick", "DuplicateKick", "Republished2", "Unlocked",
    "IrqDispatched", "WorkRunning", "Recovered2", "FinalInsertRace",
    "Requeued", "RecoveredNewest", "Published4", "OldVisit0",
    "Republished5", "OldTail1", "Restart0", "LateAdmission", "Restart1",
    "CurrentRequested", "CurrentObserved", "MigrationRemoved",
    "MigrationNeutral", "MigrationAdded", "OfflineMarked", "IrqSynced",
    "WorkCanceled", "RefsDrained", "RcuDone", "Done"
}

Init ==
    /\ phase = "Start"
    /\ generation = 1
    /\ desiredGeneration = 1
    /\ observedGeneration = 1
    /\ rqLocked = FALSE
    /\ irqsDisabled = FALSE
    /\ irqDepth = 0
    /\ workDepth = 0
    /\ workRunning = FALSE
    /\ recoveryOwnerDepth = 0
    /\ dirtyDepth = 0
    /\ dirtyReference = 0
    /\ dirtyUnique = TRUE
    /\ callbackQueuedWork = FALSE
    /\ callbackRepaired = FALSE
    /\ callbackTookSchedulerLock = FALSE
    /\ recoveryProjectionCount = 0
    /\ requeueUnderSchedulerLock = FALSE
    /\ finalInsertCovered = FALSE
    /\ notifierOwnerDepth = 0
    /\ notifierVisits = 0
    /\ notifierVisitQuantum = 0
    /\ generationRestarted = FALSE
    /\ membershipRestarted = FALSE
    /\ ownerClearRaceCovered = FALSE
    /\ lateAdmissionCovered = FALSE
    /\ stableMembershipCovered = FALSE
    /\ currentRequestSequence = 0
    /\ currentObservedSequence = 0
    /\ completionClaimedEarly = FALSE
    /\ sourceContribution = 1
    /\ destinationContribution = 0
    /\ neutralObserved = FALSE
    /\ destinationFailureRestoredSource = FALSE
    /\ initializedBeforeAccepting = (Fault # "OnlineAcceptsBeforeInit")
    /\ accepting = TRUE
    /\ queueingEnabled = TRUE
    /\ sleepableDrainUnderLock = FALSE
    /\ irqSynced = FALSE
    /\ workCanceled = FALSE
    /\ racingEnqueue = FALSE
    /\ retiring = FALSE
    /\ retirementNewOwner = FALSE
    /\ unpublished = FALSE
    /\ residualReferences = 0
    /\ rcuGrace = FALSE
    /\ generationWrapped = FALSE
    /\ freed = FALSE

RecordMismatchAndKick ==
    /\ phase = "Start"
    /\ phase' = "LockedKick"
    /\ rqLocked' = (Fault # "KickWithoutRqLock")
    /\ irqsDisabled' = (Fault # "KickWithIrqsEnabled")
    /\ irqDepth' = IF Fault = "MultipleIrqPerRq" THEN 2 ELSE 1
    /\ recoveryOwnerDepth' =
          IF Fault = "MultipleRecoveryOwners" THEN 2 ELSE 1
    /\ dirtyDepth' = IF Fault = "DirtyDepthExceedsBMax" THEN 2 ELSE 1
    /\ dirtyReference' = 1
    /\ dirtyUnique' = (Fault # "DirtyNodeDuplicated")
    /\ UNCHANGED <<generation, desiredGeneration, observedGeneration,
                    workDepth, workRunning, callbackQueuedWork,
                    callbackRepaired, callbackTookSchedulerLock,
                    recoveryProjectionCount, requeueUnderSchedulerLock,
                    finalInsertCovered, notifierOwnerDepth, notifierVisits,
                    notifierVisitQuantum, generationRestarted,
                    membershipRestarted, ownerClearRaceCovered,
                    lateAdmissionCovered, stableMembershipCovered,
                    currentRequestSequence, currentObservedSequence,
                    completionClaimedEarly, sourceContribution,
                    destinationContribution, neutralObserved,
                    destinationFailureRestoredSource,
                    initializedBeforeAccepting, accepting, queueingEnabled,
                    sleepableDrainUnderLock, irqSynced, workCanceled,
                    racingEnqueue, retiring, retirementNewOwner, unpublished,
                    residualReferences, rcuGrace, generationWrapped, freed>>

CoalesceDuplicateKick ==
    /\ phase = "LockedKick"
    /\ phase' = "DuplicateKick"
    /\ dirtyDepth' =
          IF Fault = "DuplicateKickGrowsDirty" THEN 2 ELSE dirtyDepth
    /\ UNCHANGED <<generation, desiredGeneration, observedGeneration,
                    rqLocked, irqsDisabled, irqDepth, workDepth, workRunning,
                    recoveryOwnerDepth, dirtyReference, dirtyUnique,
                    callbackQueuedWork, callbackRepaired,
                    callbackTookSchedulerLock, recoveryProjectionCount,
                    requeueUnderSchedulerLock, finalInsertCovered,
                    notifierOwnerDepth, notifierVisits,
                    notifierVisitQuantum, generationRestarted,
                    membershipRestarted, ownerClearRaceCovered,
                    lateAdmissionCovered, stableMembershipCovered,
                    currentRequestSequence, currentObservedSequence,
                    completionClaimedEarly, sourceContribution,
                    destinationContribution, neutralObserved,
                    destinationFailureRestoredSource,
                    initializedBeforeAccepting, accepting, queueingEnabled,
                    sleepableDrainUnderLock, irqSynced, workCanceled,
                    racingEnqueue, retiring, retirementNewOwner, unpublished,
                    residualReferences, rcuGrace, generationWrapped, freed>>

RepublishWhileIrqPending ==
    /\ phase = "DuplicateKick"
    /\ phase' = "Republished2"
    /\ generation' = 2
    /\ desiredGeneration' = IF Fault = "NewestDesiredLost" THEN 1 ELSE 2
    /\ UNCHANGED <<observedGeneration, rqLocked, irqsDisabled, irqDepth,
                    workDepth, workRunning, recoveryOwnerDepth, dirtyDepth,
                    dirtyReference, dirtyUnique, callbackQueuedWork,
                    callbackRepaired, callbackTookSchedulerLock,
                    recoveryProjectionCount, requeueUnderSchedulerLock,
                    finalInsertCovered, notifierOwnerDepth, notifierVisits,
                    notifierVisitQuantum, generationRestarted,
                    membershipRestarted, ownerClearRaceCovered,
                    lateAdmissionCovered, stableMembershipCovered,
                    currentRequestSequence, currentObservedSequence,
                    completionClaimedEarly, sourceContribution,
                    destinationContribution, neutralObserved,
                    destinationFailureRestoredSource,
                    initializedBeforeAccepting, accepting, queueingEnabled,
                    sleepableDrainUnderLock, irqSynced, workCanceled,
                    racingEnqueue, retiring, retirementNewOwner, unpublished,
                    residualReferences, rcuGrace, generationWrapped, freed>>

UnlockRq ==
    /\ phase = "Republished2"
    /\ phase' = "Unlocked"
    /\ rqLocked' = FALSE
    /\ irqsDisabled' = FALSE
    /\ UNCHANGED <<generation, desiredGeneration, observedGeneration,
                    irqDepth, workDepth, workRunning, recoveryOwnerDepth,
                    dirtyDepth, dirtyReference, dirtyUnique,
                    callbackQueuedWork, callbackRepaired,
                    callbackTookSchedulerLock, recoveryProjectionCount,
                    requeueUnderSchedulerLock, finalInsertCovered,
                    notifierOwnerDepth, notifierVisits,
                    notifierVisitQuantum, generationRestarted,
                    membershipRestarted, ownerClearRaceCovered,
                    lateAdmissionCovered, stableMembershipCovered,
                    currentRequestSequence, currentObservedSequence,
                    completionClaimedEarly, sourceContribution,
                    destinationContribution, neutralObserved,
                    destinationFailureRestoredSource,
                    initializedBeforeAccepting, accepting, queueingEnabled,
                    sleepableDrainUnderLock, irqSynced, workCanceled,
                    racingEnqueue, retiring, retirementNewOwner, unpublished,
                    residualReferences, rcuGrace, generationWrapped, freed>>

DispatchIrqToWork ==
    /\ phase = "Unlocked"
    /\ phase' = "IrqDispatched"
    /\ irqDepth' = 0
    /\ callbackQueuedWork' = (Fault # "IrqCallbackDoesNotQueue")
    /\ callbackRepaired' = (Fault = "IrqCallbackRepairs")
    /\ callbackTookSchedulerLock' =
          (Fault = "IrqCallbackTakesSchedulerLock")
    /\ workDepth' = IF Fault = "IrqCallbackDoesNotQueue" THEN 0 ELSE 1
    /\ recoveryOwnerDepth' =
          IF Fault = "QueueFalseWithoutOwner" THEN 0 ELSE recoveryOwnerDepth
    /\ dirtyReference' =
          IF Fault = "QueueFalseDropsDirtyRef" THEN 0 ELSE dirtyReference
    /\ UNCHANGED <<generation, desiredGeneration, observedGeneration,
                    rqLocked, irqsDisabled, workRunning, dirtyDepth,
                    dirtyUnique, recoveryProjectionCount,
                    requeueUnderSchedulerLock, finalInsertCovered,
                    notifierOwnerDepth, notifierVisits,
                    notifierVisitQuantum, generationRestarted,
                    membershipRestarted, ownerClearRaceCovered,
                    lateAdmissionCovered, stableMembershipCovered,
                    currentRequestSequence, currentObservedSequence,
                    completionClaimedEarly, sourceContribution,
                    destinationContribution, neutralObserved,
                    destinationFailureRestoredSource,
                    initializedBeforeAccepting, accepting, queueingEnabled,
                    sleepableDrainUnderLock, irqSynced, workCanceled,
                    racingEnqueue, retiring, retirementNewOwner, unpublished,
                    residualReferences, rcuGrace, generationWrapped, freed>>

StartRecoveryWorker ==
    /\ phase = "IrqDispatched"
    /\ phase' = "WorkRunning"
    /\ workDepth' = 0
    /\ workRunning' = TRUE
    /\ UNCHANGED <<generation, desiredGeneration, observedGeneration,
                    rqLocked, irqsDisabled, irqDepth, recoveryOwnerDepth,
                    dirtyDepth, dirtyReference, dirtyUnique,
                    callbackQueuedWork, callbackRepaired,
                    callbackTookSchedulerLock, recoveryProjectionCount,
                    requeueUnderSchedulerLock, finalInsertCovered,
                    notifierOwnerDepth, notifierVisits,
                    notifierVisitQuantum, generationRestarted,
                    membershipRestarted, ownerClearRaceCovered,
                    lateAdmissionCovered, stableMembershipCovered,
                    currentRequestSequence, currentObservedSequence,
                    completionClaimedEarly, sourceContribution,
                    destinationContribution, neutralObserved,
                    destinationFailureRestoredSource,
                    initializedBeforeAccepting, accepting, queueingEnabled,
                    sleepableDrainUnderLock, irqSynced, workCanceled,
                    racingEnqueue, retiring, retirementNewOwner, unpublished,
                    residualReferences, rcuGrace, generationWrapped, freed>>

RecoverOneProjection ==
    /\ phase = "WorkRunning"
    /\ phase' = "Recovered2"
    /\ observedGeneration' =
          IF Fault = "FinalGenerationRecheckMissing" THEN 1 ELSE 2
    /\ workRunning' = FALSE
    /\ recoveryOwnerDepth' = 0
    /\ dirtyDepth' = 0
    /\ dirtyReference' = 0
    /\ recoveryProjectionCount' =
          IF Fault = "MultipleProjectionQuantum" THEN 2 ELSE 1
    /\ UNCHANGED <<generation, desiredGeneration, rqLocked, irqsDisabled,
                    irqDepth, workDepth, dirtyUnique, callbackQueuedWork,
                    callbackRepaired, callbackTookSchedulerLock,
                    requeueUnderSchedulerLock, finalInsertCovered,
                    notifierOwnerDepth, notifierVisits,
                    notifierVisitQuantum, generationRestarted,
                    membershipRestarted, ownerClearRaceCovered,
                    lateAdmissionCovered, stableMembershipCovered,
                    currentRequestSequence, currentObservedSequence,
                    completionClaimedEarly, sourceContribution,
                    destinationContribution, neutralObserved,
                    destinationFailureRestoredSource,
                    initializedBeforeAccepting, accepting, queueingEnabled,
                    sleepableDrainUnderLock, irqSynced, workCanceled,
                    racingEnqueue, retiring, retirementNewOwner, unpublished,
                    residualReferences, rcuGrace, generationWrapped, freed>>

InsertRacingFinalEmptyCheck ==
    /\ phase = "Recovered2"
    /\ phase' = "FinalInsertRace"
    /\ generation' = 3
    /\ desiredGeneration' = 3
    /\ finalInsertCovered' = (Fault # "FinalEmptyInsertLost")
    /\ dirtyDepth' = IF Fault = "FinalEmptyInsertLost" THEN 0 ELSE 1
    /\ dirtyReference' = IF Fault = "FinalEmptyInsertLost" THEN 0 ELSE 1
    /\ irqDepth' = IF Fault = "FinalEmptyInsertLost" THEN 0 ELSE 1
    /\ recoveryOwnerDepth' = IF Fault = "FinalEmptyInsertLost" THEN 0 ELSE 1
    /\ UNCHANGED <<observedGeneration, rqLocked, irqsDisabled, workDepth,
                    workRunning, dirtyUnique, callbackQueuedWork,
                    callbackRepaired, callbackTookSchedulerLock,
                    recoveryProjectionCount, requeueUnderSchedulerLock,
                    notifierOwnerDepth, notifierVisits,
                    notifierVisitQuantum, generationRestarted,
                    membershipRestarted, ownerClearRaceCovered,
                    lateAdmissionCovered, stableMembershipCovered,
                    currentRequestSequence, currentObservedSequence,
                    completionClaimedEarly, sourceContribution,
                    destinationContribution, neutralObserved,
                    destinationFailureRestoredSource,
                    initializedBeforeAccepting, accepting, queueingEnabled,
                    sleepableDrainUnderLock, irqSynced, workCanceled,
                    racingEnqueue, retiring, retirementNewOwner, unpublished,
                    residualReferences, rcuGrace, generationWrapped, freed>>

DispatchSelfRequeue ==
    /\ phase = "FinalInsertRace"
    /\ phase' = "Requeued"
    /\ irqDepth' = 0
    /\ workDepth' = 1
    /\ requeueUnderSchedulerLock' =
          (Fault = "RequeueUnderSchedulerLock")
    /\ UNCHANGED <<generation, desiredGeneration, observedGeneration,
                    rqLocked, irqsDisabled, workRunning,
                    recoveryOwnerDepth, dirtyDepth, dirtyReference,
                    dirtyUnique, callbackQueuedWork, callbackRepaired,
                    callbackTookSchedulerLock, recoveryProjectionCount,
                    finalInsertCovered, notifierOwnerDepth, notifierVisits,
                    notifierVisitQuantum, generationRestarted,
                    membershipRestarted, ownerClearRaceCovered,
                    lateAdmissionCovered, stableMembershipCovered,
                    currentRequestSequence, currentObservedSequence,
                    completionClaimedEarly, sourceContribution,
                    destinationContribution, neutralObserved,
                    destinationFailureRestoredSource,
                    initializedBeforeAccepting, accepting, queueingEnabled,
                    sleepableDrainUnderLock, irqSynced, workCanceled,
                    racingEnqueue, retiring, retirementNewOwner, unpublished,
                    residualReferences, rcuGrace, generationWrapped, freed>>

RecoverNewest ==
    /\ phase = "Requeued"
    /\ phase' = "RecoveredNewest"
    /\ observedGeneration' = 3
    /\ workDepth' = 0
    /\ recoveryOwnerDepth' = 0
    /\ dirtyDepth' = 0
    /\ dirtyReference' = 0
    /\ UNCHANGED <<generation, desiredGeneration, rqLocked, irqsDisabled,
                    irqDepth, workRunning, dirtyUnique, callbackQueuedWork,
                    callbackRepaired, callbackTookSchedulerLock,
                    recoveryProjectionCount, requeueUnderSchedulerLock,
                    finalInsertCovered, notifierOwnerDepth, notifierVisits,
                    notifierVisitQuantum, generationRestarted,
                    membershipRestarted, ownerClearRaceCovered,
                    lateAdmissionCovered, stableMembershipCovered,
                    currentRequestSequence, currentObservedSequence,
                    completionClaimedEarly, sourceContribution,
                    destinationContribution, neutralObserved,
                    destinationFailureRestoredSource,
                    initializedBeforeAccepting, accepting, queueingEnabled,
                    sleepableDrainUnderLock, irqSynced, workCanceled,
                    racingEnqueue, retiring, retirementNewOwner, unpublished,
                    residualReferences, rcuGrace, generationWrapped, freed>>

PublishGeneration4 ==
    /\ phase = "RecoveredNewest"
    /\ phase' = "Published4"
    /\ generation' = 4
    /\ notifierOwnerDepth' =
          IF Fault = "MultipleNotifierOwners" THEN 2 ELSE 1
    /\ UNCHANGED <<desiredGeneration, observedGeneration, rqLocked,
                    irqsDisabled, irqDepth, workDepth, workRunning,
                    recoveryOwnerDepth, dirtyDepth, dirtyReference,
                    dirtyUnique, callbackQueuedWork, callbackRepaired,
                    callbackTookSchedulerLock, recoveryProjectionCount,
                    requeueUnderSchedulerLock, finalInsertCovered,
                    notifierVisits, notifierVisitQuantum,
                    generationRestarted, membershipRestarted,
                    ownerClearRaceCovered, lateAdmissionCovered,
                    stableMembershipCovered, currentRequestSequence,
                    currentObservedSequence, completionClaimedEarly,
                    sourceContribution, destinationContribution,
                    neutralObserved, destinationFailureRestoredSource,
                    initializedBeforeAccepting, accepting, queueingEnabled,
                    sleepableDrainUnderLock, irqSynced, workCanceled,
                    racingEnqueue, retiring, retirementNewOwner, unpublished,
                    residualReferences, rcuGrace, generationWrapped, freed>>

OldPassVisitRq0 ==
    /\ phase = "Published4"
    /\ phase' = "OldVisit0"
    /\ notifierVisits' = 1
    /\ notifierVisitQuantum' =
          IF Fault = "MultiVisitNotifierQuantum" THEN 2 ELSE 1
    /\ UNCHANGED <<generation, desiredGeneration, observedGeneration,
                    rqLocked, irqsDisabled, irqDepth, workDepth, workRunning,
                    recoveryOwnerDepth, dirtyDepth, dirtyReference,
                    dirtyUnique, callbackQueuedWork, callbackRepaired,
                    callbackTookSchedulerLock, recoveryProjectionCount,
                    requeueUnderSchedulerLock, finalInsertCovered,
                    notifierOwnerDepth, generationRestarted,
                    membershipRestarted, ownerClearRaceCovered,
                    lateAdmissionCovered, stableMembershipCovered,
                    currentRequestSequence, currentObservedSequence,
                    completionClaimedEarly, sourceContribution,
                    destinationContribution, neutralObserved,
                    destinationFailureRestoredSource,
                    initializedBeforeAccepting, accepting, queueingEnabled,
                    sleepableDrainUnderLock, irqSynced, workCanceled,
                    racingEnqueue, retiring, retirementNewOwner, unpublished,
                    residualReferences, rcuGrace, generationWrapped, freed>>

FinalRepublishGeneration5 ==
    /\ phase = "OldVisit0"
    /\ phase' = "Republished5"
    /\ generation' = 5
    /\ generationRestarted' = (Fault # "GenerationRestartMissing")
    /\ UNCHANGED <<desiredGeneration, observedGeneration, rqLocked,
                    irqsDisabled, irqDepth, workDepth, workRunning,
                    recoveryOwnerDepth, dirtyDepth, dirtyReference,
                    dirtyUnique, callbackQueuedWork, callbackRepaired,
                    callbackTookSchedulerLock, recoveryProjectionCount,
                    requeueUnderSchedulerLock, finalInsertCovered,
                    notifierOwnerDepth, notifierVisits,
                    notifierVisitQuantum, membershipRestarted,
                    ownerClearRaceCovered, lateAdmissionCovered,
                    stableMembershipCovered, currentRequestSequence,
                    currentObservedSequence, completionClaimedEarly,
                    sourceContribution, destinationContribution,
                    neutralObserved, destinationFailureRestoredSource,
                    initializedBeforeAccepting, accepting, queueingEnabled,
                    sleepableDrainUnderLock, irqSynced, workCanceled,
                    racingEnqueue, retiring, retirementNewOwner, unpublished,
                    residualReferences, rcuGrace, generationWrapped, freed>>

FinishOldTailAfterMembershipChange ==
    /\ phase = "Republished5"
    /\ phase' = "OldTail1"
    /\ notifierVisits' = 2
    /\ notifierVisitQuantum' = 1
    /\ membershipRestarted' = (Fault # "MembershipRestartMissing")
    /\ UNCHANGED <<generation, desiredGeneration, observedGeneration,
                    rqLocked, irqsDisabled, irqDepth, workDepth, workRunning,
                    recoveryOwnerDepth, dirtyDepth, dirtyReference,
                    dirtyUnique, callbackQueuedWork, callbackRepaired,
                    callbackTookSchedulerLock, recoveryProjectionCount,
                    requeueUnderSchedulerLock, finalInsertCovered,
                    notifierOwnerDepth, generationRestarted,
                    ownerClearRaceCovered, lateAdmissionCovered,
                    stableMembershipCovered, currentRequestSequence,
                    currentObservedSequence, completionClaimedEarly,
                    sourceContribution, destinationContribution,
                    neutralObserved, destinationFailureRestoredSource,
                    initializedBeforeAccepting, accepting, queueingEnabled,
                    sleepableDrainUnderLock, irqSynced, workCanceled,
                    racingEnqueue, retiring, retirementNewOwner, unpublished,
                    residualReferences, rcuGrace, generationWrapped, freed>>

RestartVisitRq0 ==
    /\ phase = "OldTail1"
    /\ phase' = "Restart0"
    /\ notifierVisits' = 3
    /\ UNCHANGED <<generation, desiredGeneration, observedGeneration,
                    rqLocked, irqsDisabled, irqDepth, workDepth, workRunning,
                    recoveryOwnerDepth, dirtyDepth, dirtyReference,
                    dirtyUnique, callbackQueuedWork, callbackRepaired,
                    callbackTookSchedulerLock, recoveryProjectionCount,
                    requeueUnderSchedulerLock, finalInsertCovered,
                    notifierOwnerDepth, notifierVisitQuantum,
                    generationRestarted, membershipRestarted,
                    ownerClearRaceCovered, lateAdmissionCovered,
                    stableMembershipCovered, currentRequestSequence,
                    currentObservedSequence, completionClaimedEarly,
                    sourceContribution, destinationContribution,
                    neutralObserved, destinationFailureRestoredSource,
                    initializedBeforeAccepting, accepting, queueingEnabled,
                    sleepableDrainUnderLock, irqSynced, workCanceled,
                    racingEnqueue, retiring, retirementNewOwner, unpublished,
                    residualReferences, rcuGrace, generationWrapped, freed>>

AdmitAfterCursor ==
    /\ phase = "Restart0"
    /\ phase' = "LateAdmission"
    /\ lateAdmissionCovered' = (Fault # "LateAdmissionKickMissing")
    /\ UNCHANGED <<generation, desiredGeneration, observedGeneration,
                    rqLocked, irqsDisabled, irqDepth, workDepth, workRunning,
                    recoveryOwnerDepth, dirtyDepth, dirtyReference,
                    dirtyUnique, callbackQueuedWork, callbackRepaired,
                    callbackTookSchedulerLock, recoveryProjectionCount,
                    requeueUnderSchedulerLock, finalInsertCovered,
                    notifierOwnerDepth, notifierVisits,
                    notifierVisitQuantum, generationRestarted,
                    membershipRestarted, ownerClearRaceCovered,
                    stableMembershipCovered, currentRequestSequence,
                    currentObservedSequence, completionClaimedEarly,
                    sourceContribution, destinationContribution,
                    neutralObserved, destinationFailureRestoredSource,
                    initializedBeforeAccepting, accepting, queueingEnabled,
                    sleepableDrainUnderLock, irqSynced, workCanceled,
                    racingEnqueue, retiring, retirementNewOwner, unpublished,
                    residualReferences, rcuGrace, generationWrapped, freed>>

FinishNewestPass ==
    /\ phase = "LateAdmission"
    /\ phase' = "Restart1"
    /\ notifierVisits' =
          IF Fault = "NotifierBoundExceeded" THEN 5 ELSE 4
    /\ notifierOwnerDepth' = 0
    /\ ownerClearRaceCovered' = (Fault # "OwnerClearRaceLost")
    /\ stableMembershipCovered' = TRUE
    /\ UNCHANGED <<generation, desiredGeneration, observedGeneration,
                    rqLocked, irqsDisabled, irqDepth, workDepth, workRunning,
                    recoveryOwnerDepth, dirtyDepth, dirtyReference,
                    dirtyUnique, callbackQueuedWork, callbackRepaired,
                    callbackTookSchedulerLock, recoveryProjectionCount,
                    requeueUnderSchedulerLock, finalInsertCovered,
                    notifierVisitQuantum, generationRestarted,
                    membershipRestarted, lateAdmissionCovered,
                    currentRequestSequence, currentObservedSequence,
                    completionClaimedEarly, sourceContribution,
                    destinationContribution, neutralObserved,
                    destinationFailureRestoredSource,
                    initializedBeforeAccepting, accepting, queueingEnabled,
                    sleepableDrainUnderLock, irqSynced, workCanceled,
                    racingEnqueue, retiring, retirementNewOwner, unpublished,
                    residualReferences, rcuGrace, generationWrapped, freed>>

RequestCurrentStop ==
    /\ phase = "Restart1"
    /\ phase' = "CurrentRequested"
    /\ currentRequestSequence' = 1
    /\ currentObservedSequence' =
          IF Fault = "CurrentRequestConflatedWithCompletion" THEN 1 ELSE 0
    /\ completionClaimedEarly' =
          (Fault = "CurrentRequestConflatedWithCompletion")
    /\ UNCHANGED <<generation, desiredGeneration, observedGeneration,
                    rqLocked, irqsDisabled, irqDepth, workDepth, workRunning,
                    recoveryOwnerDepth, dirtyDepth, dirtyReference,
                    dirtyUnique, callbackQueuedWork, callbackRepaired,
                    callbackTookSchedulerLock, recoveryProjectionCount,
                    requeueUnderSchedulerLock, finalInsertCovered,
                    notifierOwnerDepth, notifierVisits,
                    notifierVisitQuantum, generationRestarted,
                    membershipRestarted, ownerClearRaceCovered,
                    lateAdmissionCovered, stableMembershipCovered,
                    sourceContribution, destinationContribution,
                    neutralObserved, destinationFailureRestoredSource,
                    initializedBeforeAccepting, accepting, queueingEnabled,
                    sleepableDrainUnderLock, irqSynced, workCanceled,
                    racingEnqueue, retiring, retirementNewOwner, unpublished,
                    residualReferences, rcuGrace, generationWrapped, freed>>

ObserveSchedulerTransition ==
    /\ phase = "CurrentRequested"
    /\ phase' = "CurrentObserved"
    /\ currentObservedSequence' =
          IF Fault = "CurrentObservationMissing" THEN 0 ELSE 1
    /\ UNCHANGED <<generation, desiredGeneration, observedGeneration,
                    rqLocked, irqsDisabled, irqDepth, workDepth, workRunning,
                    recoveryOwnerDepth, dirtyDepth, dirtyReference,
                    dirtyUnique, callbackQueuedWork, callbackRepaired,
                    callbackTookSchedulerLock, recoveryProjectionCount,
                    requeueUnderSchedulerLock, finalInsertCovered,
                    notifierOwnerDepth, notifierVisits,
                    notifierVisitQuantum, generationRestarted,
                    membershipRestarted, ownerClearRaceCovered,
                    lateAdmissionCovered, stableMembershipCovered,
                    currentRequestSequence, completionClaimedEarly,
                    sourceContribution, destinationContribution,
                    neutralObserved, destinationFailureRestoredSource,
                    initializedBeforeAccepting, accepting, queueingEnabled,
                    sleepableDrainUnderLock, irqSynced, workCanceled,
                    racingEnqueue, retiring, retirementNewOwner, unpublished,
                    residualReferences, rcuGrace, generationWrapped, freed>>

RemoveSourceContribution ==
    /\ phase = "CurrentObserved"
    /\ phase' = "MigrationRemoved"
    /\ sourceContribution' = 0
    /\ UNCHANGED <<generation, desiredGeneration, observedGeneration,
                    rqLocked, irqsDisabled, irqDepth, workDepth, workRunning,
                    recoveryOwnerDepth, dirtyDepth, dirtyReference,
                    dirtyUnique, callbackQueuedWork, callbackRepaired,
                    callbackTookSchedulerLock, recoveryProjectionCount,
                    requeueUnderSchedulerLock, finalInsertCovered,
                    notifierOwnerDepth, notifierVisits,
                    notifierVisitQuantum, generationRestarted,
                    membershipRestarted, ownerClearRaceCovered,
                    lateAdmissionCovered, stableMembershipCovered,
                    currentRequestSequence, currentObservedSequence,
                    completionClaimedEarly, destinationContribution,
                    neutralObserved, destinationFailureRestoredSource,
                    initializedBeforeAccepting, accepting, queueingEnabled,
                    sleepableDrainUnderLock, irqSynced, workCanceled,
                    racingEnqueue, retiring, retirementNewOwner, unpublished,
                    residualReferences, rcuGrace, generationWrapped, freed>>

ExposeNeutralMigrationState ==
    /\ phase = "MigrationRemoved"
    /\ phase' = "MigrationNeutral"
    /\ neutralObserved' = (Fault # "MigrationNeutralStateMissing")
    /\ UNCHANGED <<generation, desiredGeneration, observedGeneration,
                    rqLocked, irqsDisabled, irqDepth, workDepth, workRunning,
                    recoveryOwnerDepth, dirtyDepth, dirtyReference,
                    dirtyUnique, callbackQueuedWork, callbackRepaired,
                    callbackTookSchedulerLock, recoveryProjectionCount,
                    requeueUnderSchedulerLock, finalInsertCovered,
                    notifierOwnerDepth, notifierVisits,
                    notifierVisitQuantum, generationRestarted,
                    membershipRestarted, ownerClearRaceCovered,
                    lateAdmissionCovered, stableMembershipCovered,
                    currentRequestSequence, currentObservedSequence,
                    completionClaimedEarly, sourceContribution,
                    destinationContribution,
                    destinationFailureRestoredSource,
                    initializedBeforeAccepting, accepting, queueingEnabled,
                    sleepableDrainUnderLock, irqSynced, workCanceled,
                    racingEnqueue, retiring, retirementNewOwner, unpublished,
                    residualReferences, rcuGrace, generationWrapped, freed>>

AddDestinationContribution ==
    /\ phase = "MigrationNeutral"
    /\ phase' = "MigrationAdded"
    /\ sourceContribution' =
          IF Fault = "MigrationDoubleContribution" THEN 1 ELSE 0
    /\ destinationContribution' = 1
    /\ destinationFailureRestoredSource' =
          (Fault = "DestinationFailureRestoresSource")
    /\ UNCHANGED <<generation, desiredGeneration, observedGeneration,
                    rqLocked, irqsDisabled, irqDepth, workDepth, workRunning,
                    recoveryOwnerDepth, dirtyDepth, dirtyReference,
                    dirtyUnique, callbackQueuedWork, callbackRepaired,
                    callbackTookSchedulerLock, recoveryProjectionCount,
                    requeueUnderSchedulerLock, finalInsertCovered,
                    notifierOwnerDepth, notifierVisits,
                    notifierVisitQuantum, generationRestarted,
                    membershipRestarted, ownerClearRaceCovered,
                    lateAdmissionCovered, stableMembershipCovered,
                    currentRequestSequence, currentObservedSequence,
                    completionClaimedEarly, neutralObserved,
                    initializedBeforeAccepting, accepting, queueingEnabled,
                    sleepableDrainUnderLock, irqSynced, workCanceled,
                    racingEnqueue, retiring, retirementNewOwner, unpublished,
                    residualReferences, rcuGrace, generationWrapped, freed>>

MarkOfflineAndRetiring ==
    /\ phase = "MigrationAdded"
    /\ phase' = "OfflineMarked"
    /\ accepting' = (Fault = "OfflineAcceptingNotCleared")
    /\ queueingEnabled' =
          (Fault = "OfflineQueueingNotDisabled")
    /\ retiring' = TRUE
    /\ retirementNewOwner' = (Fault = "RetirementAllowsNewOwner")
    /\ unpublished' = (Fault # "UnpublishAfterDrain")
    /\ residualReferences' = 1
    /\ generationWrapped' = (Fault = "GenerationWrapReused")
    /\ UNCHANGED <<generation, desiredGeneration, observedGeneration,
                    rqLocked, irqsDisabled, irqDepth, workDepth, workRunning,
                    recoveryOwnerDepth, dirtyDepth, dirtyReference,
                    dirtyUnique, callbackQueuedWork, callbackRepaired,
                    callbackTookSchedulerLock, recoveryProjectionCount,
                    requeueUnderSchedulerLock, finalInsertCovered,
                    notifierOwnerDepth, notifierVisits,
                    notifierVisitQuantum, generationRestarted,
                    membershipRestarted, ownerClearRaceCovered,
                    lateAdmissionCovered, stableMembershipCovered,
                    currentRequestSequence, currentObservedSequence,
                    completionClaimedEarly, sourceContribution,
                    destinationContribution, neutralObserved,
                    destinationFailureRestoredSource,
                    initializedBeforeAccepting, sleepableDrainUnderLock,
                    irqSynced, workCanceled, racingEnqueue, rcuGrace, freed>>

SynchronizeIrqWork ==
    /\ phase = "OfflineMarked"
    /\ phase' = "IrqSynced"
    /\ irqSynced' = (Fault # "IrqSyncAfterCancel")
    /\ sleepableDrainUnderLock' = (Fault = "SleepableDrainUnderLock")
    /\ UNCHANGED <<generation, desiredGeneration, observedGeneration,
                    rqLocked, irqsDisabled, irqDepth, workDepth, workRunning,
                    recoveryOwnerDepth, dirtyDepth, dirtyReference,
                    dirtyUnique, callbackQueuedWork, callbackRepaired,
                    callbackTookSchedulerLock, recoveryProjectionCount,
                    requeueUnderSchedulerLock, finalInsertCovered,
                    notifierOwnerDepth, notifierVisits,
                    notifierVisitQuantum, generationRestarted,
                    membershipRestarted, ownerClearRaceCovered,
                    lateAdmissionCovered, stableMembershipCovered,
                    currentRequestSequence, currentObservedSequence,
                    completionClaimedEarly, sourceContribution,
                    destinationContribution, neutralObserved,
                    destinationFailureRestoredSource,
                    initializedBeforeAccepting, accepting, queueingEnabled,
                    workCanceled, racingEnqueue, retiring,
                    retirementNewOwner, unpublished, residualReferences,
                    rcuGrace, generationWrapped, freed>>

CancelRecoveryWork ==
    /\ phase = "IrqSynced"
    /\ phase' = "WorkCanceled"
    /\ workCanceled' = TRUE
    /\ racingEnqueue' = (Fault = "RacingEnqueueDuringCancel")
    /\ UNCHANGED <<generation, desiredGeneration, observedGeneration,
                    rqLocked, irqsDisabled, irqDepth, workDepth, workRunning,
                    recoveryOwnerDepth, dirtyDepth, dirtyReference,
                    dirtyUnique, callbackQueuedWork, callbackRepaired,
                    callbackTookSchedulerLock, recoveryProjectionCount,
                    requeueUnderSchedulerLock, finalInsertCovered,
                    notifierOwnerDepth, notifierVisits,
                    notifierVisitQuantum, generationRestarted,
                    membershipRestarted, ownerClearRaceCovered,
                    lateAdmissionCovered, stableMembershipCovered,
                    currentRequestSequence, currentObservedSequence,
                    completionClaimedEarly, sourceContribution,
                    destinationContribution, neutralObserved,
                    destinationFailureRestoredSource,
                    initializedBeforeAccepting, accepting, queueingEnabled,
                    sleepableDrainUnderLock, irqSynced, retiring,
                    retirementNewOwner, unpublished, residualReferences,
                    rcuGrace, generationWrapped, freed>>

DrainReferences ==
    /\ phase = "WorkCanceled"
    /\ phase' = "RefsDrained"
    /\ residualReferences' =
          IF Fault = "RefLeakBeforeFree" THEN 1 ELSE 0
    /\ UNCHANGED <<generation, desiredGeneration, observedGeneration,
                    rqLocked, irqsDisabled, irqDepth, workDepth, workRunning,
                    recoveryOwnerDepth, dirtyDepth, dirtyReference,
                    dirtyUnique, callbackQueuedWork, callbackRepaired,
                    callbackTookSchedulerLock, recoveryProjectionCount,
                    requeueUnderSchedulerLock, finalInsertCovered,
                    notifierOwnerDepth, notifierVisits,
                    notifierVisitQuantum, generationRestarted,
                    membershipRestarted, ownerClearRaceCovered,
                    lateAdmissionCovered, stableMembershipCovered,
                    currentRequestSequence, currentObservedSequence,
                    completionClaimedEarly, sourceContribution,
                    destinationContribution, neutralObserved,
                    destinationFailureRestoredSource,
                    initializedBeforeAccepting, accepting, queueingEnabled,
                    sleepableDrainUnderLock, irqSynced, workCanceled,
                    racingEnqueue, retiring, retirementNewOwner, unpublished,
                    rcuGrace, generationWrapped, freed>>

WaitRcuGrace ==
    /\ phase = "RefsDrained"
    /\ phase' = "RcuDone"
    /\ rcuGrace' = (Fault # "RcuGraceMissing")
    /\ UNCHANGED <<generation, desiredGeneration, observedGeneration,
                    rqLocked, irqsDisabled, irqDepth, workDepth, workRunning,
                    recoveryOwnerDepth, dirtyDepth, dirtyReference,
                    dirtyUnique, callbackQueuedWork, callbackRepaired,
                    callbackTookSchedulerLock, recoveryProjectionCount,
                    requeueUnderSchedulerLock, finalInsertCovered,
                    notifierOwnerDepth, notifierVisits,
                    notifierVisitQuantum, generationRestarted,
                    membershipRestarted, ownerClearRaceCovered,
                    lateAdmissionCovered, stableMembershipCovered,
                    currentRequestSequence, currentObservedSequence,
                    completionClaimedEarly, sourceContribution,
                    destinationContribution, neutralObserved,
                    destinationFailureRestoredSource,
                    initializedBeforeAccepting, accepting, queueingEnabled,
                    sleepableDrainUnderLock, irqSynced, workCanceled,
                    racingEnqueue, retiring, retirementNewOwner, unpublished,
                    residualReferences, generationWrapped, freed>>

FreeAfterDrain ==
    /\ phase = "RcuDone"
    /\ phase' = "Done"
    /\ freed' = TRUE
    /\ UNCHANGED <<generation, desiredGeneration, observedGeneration,
                    rqLocked, irqsDisabled, irqDepth, workDepth, workRunning,
                    recoveryOwnerDepth, dirtyDepth, dirtyReference,
                    dirtyUnique, callbackQueuedWork, callbackRepaired,
                    callbackTookSchedulerLock, recoveryProjectionCount,
                    requeueUnderSchedulerLock, finalInsertCovered,
                    notifierOwnerDepth, notifierVisits,
                    notifierVisitQuantum, generationRestarted,
                    membershipRestarted, ownerClearRaceCovered,
                    lateAdmissionCovered, stableMembershipCovered,
                    currentRequestSequence, currentObservedSequence,
                    completionClaimedEarly, sourceContribution,
                    destinationContribution, neutralObserved,
                    destinationFailureRestoredSource,
                    initializedBeforeAccepting, accepting, queueingEnabled,
                    sleepableDrainUnderLock, irqSynced, workCanceled,
                    racingEnqueue, retiring, retirementNewOwner, unpublished,
                    residualReferences, rcuGrace, generationWrapped>>

Done == phase = "Done" /\ UNCHANGED vars

Next ==
    \/ RecordMismatchAndKick
    \/ CoalesceDuplicateKick
    \/ RepublishWhileIrqPending
    \/ UnlockRq
    \/ DispatchIrqToWork
    \/ StartRecoveryWorker
    \/ RecoverOneProjection
    \/ InsertRacingFinalEmptyCheck
    \/ DispatchSelfRequeue
    \/ RecoverNewest
    \/ PublishGeneration4
    \/ OldPassVisitRq0
    \/ FinalRepublishGeneration5
    \/ FinishOldTailAfterMembershipChange
    \/ RestartVisitRq0
    \/ AdmitAfterCursor
    \/ FinishNewestPass
    \/ RequestCurrentStop
    \/ ObserveSchedulerTransition
    \/ RemoveSourceContribution
    \/ ExposeNeutralMigrationState
    \/ AddDestinationContribution
    \/ MarkOfflineAndRetiring
    \/ SynchronizeIrqWork
    \/ CancelRecoveryWork
    \/ DrainReferences
    \/ WaitRcuGrace
    \/ FreeAfterDrain
    \/ Done

Spec ==
    /\ Init
    /\ [][Next]_vars
    /\ WF_vars(RecordMismatchAndKick)
    /\ WF_vars(CoalesceDuplicateKick)
    /\ WF_vars(RepublishWhileIrqPending)
    /\ WF_vars(UnlockRq)
    /\ WF_vars(DispatchIrqToWork)
    /\ WF_vars(StartRecoveryWorker)
    /\ WF_vars(RecoverOneProjection)
    /\ WF_vars(InsertRacingFinalEmptyCheck)
    /\ WF_vars(DispatchSelfRequeue)
    /\ WF_vars(RecoverNewest)
    /\ WF_vars(PublishGeneration4)
    /\ WF_vars(OldPassVisitRq0)
    /\ WF_vars(FinalRepublishGeneration5)
    /\ WF_vars(FinishOldTailAfterMembershipChange)
    /\ WF_vars(RestartVisitRq0)
    /\ WF_vars(AdmitAfterCursor)
    /\ WF_vars(FinishNewestPass)
    /\ WF_vars(RequestCurrentStop)
    /\ WF_vars(ObserveSchedulerTransition)
    /\ WF_vars(RemoveSourceContribution)
    /\ WF_vars(ExposeNeutralMigrationState)
    /\ WF_vars(AddDestinationContribution)
    /\ WF_vars(MarkOfflineAndRetiring)
    /\ WF_vars(SynchronizeIrqWork)
    /\ WF_vars(CancelRecoveryWork)
    /\ WF_vars(DrainReferences)
    /\ WF_vars(WaitRcuGrace)
    /\ WF_vars(FreeAfterDrain)

TypeOK ==
    /\ phase \in Phases
    /\ generation \in 1..5
    /\ desiredGeneration \in 1..5
    /\ observedGeneration \in 1..5
    /\ rqLocked \in BOOLEAN
    /\ irqsDisabled \in BOOLEAN
    /\ irqDepth \in 0..2
    /\ workDepth \in 0..1
    /\ workRunning \in BOOLEAN
    /\ recoveryOwnerDepth \in 0..2
    /\ dirtyDepth \in 0..2
    /\ dirtyReference \in 0..1
    /\ dirtyUnique \in BOOLEAN
    /\ callbackQueuedWork \in BOOLEAN
    /\ callbackRepaired \in BOOLEAN
    /\ callbackTookSchedulerLock \in BOOLEAN
    /\ recoveryProjectionCount \in 0..2
    /\ requeueUnderSchedulerLock \in BOOLEAN
    /\ finalInsertCovered \in BOOLEAN
    /\ notifierOwnerDepth \in 0..2
    /\ notifierVisits \in 0..5
    /\ notifierVisitQuantum \in 0..2
    /\ generationRestarted \in BOOLEAN
    /\ membershipRestarted \in BOOLEAN
    /\ ownerClearRaceCovered \in BOOLEAN
    /\ lateAdmissionCovered \in BOOLEAN
    /\ stableMembershipCovered \in BOOLEAN
    /\ currentRequestSequence \in 0..1
    /\ currentObservedSequence \in 0..1
    /\ completionClaimedEarly \in BOOLEAN
    /\ sourceContribution \in 0..1
    /\ destinationContribution \in 0..1
    /\ neutralObserved \in BOOLEAN
    /\ destinationFailureRestoredSource \in BOOLEAN
    /\ initializedBeforeAccepting \in BOOLEAN
    /\ accepting \in BOOLEAN
    /\ queueingEnabled \in BOOLEAN
    /\ sleepableDrainUnderLock \in BOOLEAN
    /\ irqSynced \in BOOLEAN
    /\ workCanceled \in BOOLEAN
    /\ racingEnqueue \in BOOLEAN
    /\ retiring \in BOOLEAN
    /\ retirementNewOwner \in BOOLEAN
    /\ unpublished \in BOOLEAN
    /\ residualReferences \in 0..1
    /\ rcuGrace \in BOOLEAN
    /\ generationWrapped \in BOOLEAN
    /\ freed \in BOOLEAN

LockedKickPhases == {"LockedKick", "DuplicateKick", "Republished2"}
AfterGeneration2Publish == {
    "Republished2", "Unlocked", "IrqDispatched", "WorkRunning",
    "Recovered2"
}
AfterFirstRecovery == {
    "Recovered2", "FinalInsertRace", "Requeued", "RecoveredNewest",
    "Published4", "OldVisit0", "Republished5", "OldTail1", "Restart0",
    "LateAdmission", "Restart1", "CurrentRequested", "CurrentObserved",
    "MigrationRemoved", "MigrationNeutral", "MigrationAdded",
    "OfflineMarked", "IrqSynced", "WorkCanceled", "RefsDrained",
    "RcuDone", "Done"
}
AfterNewestRecovery == {
    "RecoveredNewest", "Published4", "OldVisit0", "Republished5",
    "OldTail1", "Restart0", "LateAdmission", "Restart1",
    "CurrentRequested", "CurrentObserved", "MigrationRemoved",
    "MigrationNeutral", "MigrationAdded", "OfflineMarked", "IrqSynced",
    "WorkCanceled", "RefsDrained", "RcuDone", "Done"
}
AfterOldTail == {
    "OldTail1", "Restart0", "LateAdmission", "Restart1",
    "CurrentRequested", "CurrentObserved", "MigrationRemoved",
    "MigrationNeutral", "MigrationAdded", "OfflineMarked", "IrqSynced",
    "WorkCanceled", "RefsDrained", "RcuDone", "Done"
}
AfterRestart == {
    "Restart1", "CurrentRequested", "CurrentObserved", "MigrationRemoved",
    "MigrationNeutral", "MigrationAdded", "OfflineMarked", "IrqSynced",
    "WorkCanceled", "RefsDrained", "RcuDone", "Done"
}
AfterCurrentObserved == {
    "CurrentObserved", "MigrationRemoved", "MigrationNeutral",
    "MigrationAdded", "OfflineMarked", "IrqSynced", "WorkCanceled",
    "RefsDrained", "RcuDone", "Done"
}
AfterMigrationAdded == {
    "MigrationAdded", "OfflineMarked", "IrqSynced", "WorkCanceled",
    "RefsDrained", "RcuDone", "Done"
}
AfterOffline == {
    "OfflineMarked", "IrqSynced", "WorkCanceled", "RefsDrained",
    "RcuDone", "Done"
}

StateSafety ==
    /\ phase \in LockedKickPhases => rqLocked /\ irqsDisabled
    /\ rqLocked => irqsDisabled
    /\ irqDepth <= 1
    /\ recoveryOwnerDepth <= 1
    /\ dirtyDepth <= 1
    /\ dirtyUnique
    /\ dirtyDepth > 0 => dirtyReference = 1
    /\ (workDepth > 0 \/ workRunning) => recoveryOwnerDepth = 1
    /\ phase \in {"IrqDispatched", "WorkRunning"} => callbackQueuedWork
    /\ ~callbackRepaired
    /\ ~callbackTookSchedulerLock
    /\ recoveryProjectionCount <= 1
    /\ ~requeueUnderSchedulerLock
    /\ phase \in {"FinalInsertRace", "Requeued"} => finalInsertCovered
    /\ phase \in AfterGeneration2Publish => desiredGeneration = 2
    /\ phase \in AfterFirstRecovery => observedGeneration >= 2
    /\ phase \in AfterNewestRecovery => observedGeneration = 3
    /\ notifierOwnerDepth <= 1
    /\ notifierVisitQuantum <= 1
    /\ notifierVisits <= NotifierVisitLimit
    /\ phase \in AfterOldTail => generationRestarted /\ membershipRestarted
    /\ phase \in AfterRestart =>
          /\ ownerClearRaceCovered
          /\ lateAdmissionCovered
          /\ stableMembershipCovered
    /\ ~completionClaimedEarly
    /\ phase \in AfterCurrentObserved =>
          currentObservedSequence = currentRequestSequence
    /\ sourceContribution + destinationContribution <= 1
    /\ phase \in AfterMigrationAdded => neutralObserved
    /\ ~destinationFailureRestoredSource
    /\ initializedBeforeAccepting
    /\ phase \in AfterOffline => ~accepting /\ ~queueingEnabled
    /\ ~sleepableDrainUnderLock
    /\ workCanceled => irqSynced /\ ~racingEnqueue
    /\ retiring => ~retirementNewOwner
    /\ phase \in {"RefsDrained", "RcuDone", "Done"} => unpublished
    /\ ~generationWrapped
    /\ freed =>
          /\ retiring
          /\ unpublished
          /\ irqSynced
          /\ workCanceled
          /\ residualReferences = 0
          /\ rcuGrace

PlanContract ==
    /\ E2ClosureBound
    /\ ExactFutureParent
    /\ ExactTwoFileScope
    /\ E2LayoutPreserved
    /\ E2ProbeValuesPreserved
    /\ E3DefaultOff
    /\ E3NotSelectedNormally
    /\ DisabledArtifactsAbsent
    /\ NoPublicSurface
    /\ NoLiveSchedulerAttachment
    /\ NoProductionHook
    /\ OracleIndependent
    /\ OracleEveryCheckpoint
    /\ EveryCaseReceipt
    /\ FiniteCapacity
    /\ PreRunnableSlot
    /\ NoAllocationUnderLock
    /\ AllocationFailureClean
    /\ AllocationRetry
    /\ UnboundRecoveryWork
    /\ RqThenOneMembership
    /\ PublisherDoesNotWalk
    /\ PublisherQueuesAfterUnlock
    /\ CpumaskCursor
    /\ ReschedNotMonitorReceipt
    /\ NoTimingSleepProof
    /\ NoRequiredCaseSkipped
    /\ CompleteDiagnosticMatrix
    /\ NoWarningAccepted
    /\ NoWallClockLiveness
    /\ NoLinuxSourceApproval
    /\ NoRuntimeClaim
    /\ NoProtectionClaim
    /\ NoPerformanceClaim
    /\ NoDeploymentClaim
    /\ NoDatacenterClaim

Safety == TypeOK /\ StateSafety /\ PlanContract

BridgeEventuallyRecoversNewest ==
    (phase = "Unlocked") ~> (observedGeneration = 3)

StableNotifierEventuallyCoversMembership ==
    (phase = "Republished5") ~>
      (stableMembershipCovered /\ lateAdmissionCovered)

CurrentRequestEventuallyObserved ==
    (phase = "CurrentRequested") ~>
      (currentObservedSequence = currentRequestSequence)

OfflineEventuallyDrains ==
    (phase = "OfflineMarked") ~> (phase = "Done" /\ freed)

=============================================================================
