---------- MODULE P5AR4GenerationFencedCoalescedPullRecovery ----------
EXTENDS Naturals, FiniteSets

CONSTANT Fault

Rqs == {"rq0", "rq1"}
BMax == 2

ExactR3Rejection == Fault # "MissingExactR3Rejection"
FanoutAvailabilityOnly == Fault # "FanoutRecastAsTrustAuthority"
R3ThresholdsImmutable == Fault # "R3ThresholdsReinterpreted"
PublicationCriticalSectionO1 == Fault # "PublicationCriticalSectionNotO1"
ReleaseGeneration == Fault # "MissingReleaseGeneration"
PublisherDoesNotScanRqMask == Fault # "PublisherScansRqMask"
PublisherDoesNotTakeRqLock == Fault # "PublisherTakesRqLock"
PublisherDoesNotWait == Fault # "PublisherWaitsForRecovery"
NoGenerationWrapReuse == Fault # "GenerationWrapReuse"
SaturationBlocks == Fault # "GenerationSaturationReuses"
OneBucketNotifier == Fault # "MultipleBucketNotifiers"
NotifierCoalesces == Fault # "NotifierDoesNotCoalesce"
PickerAcquireFence == Fault # "PickerSkipsAcquireFence"
PickerMismatchUntrusted == Fault # "PickerTrustsMismatch"
PickerO1 == Fault # "PickerNotO1"
PickerKickIdempotent == Fault # "PickerKickDuplicates"
PickerDoesNotRepair == Fault # "PickerRepairsProjection"
MappedPostLockDispatch == Fault # "QueueDispatchUnderUnmappedLock"
OneRqOwner == Fault # "MultipleRqOwners"
NewestDesiredWins == Fault # "NewestDesiredGenerationLost"
DirtyDepthIndependentOfPublications == Fault # "DirtyQueueGrowsPerPublication"
OneProjectionPerRqLock == Fault # "RecoveryUpdatesMultipleProjections"
FinalGenerationRecheck == Fault # "RecoverySkipsFinalRecheck"
RacedRecoveryRemainsDirty == Fault # "RacedRecoveryPublishesFresh"
NoSynchronousSettlement == Fault # "SynchronousSettlementRestored"
NoGlobalFreshSettlementGate == Fault # "GlobalFreshSettlementRequired"
StableWindowAssumption == Fault # "MissingStableWindowAssumption"
WeakFairnessAssumption == Fault # "MissingWeakFairnessAssumption"
FiniteActiveSet == Fault # "UnboundedActiveSet"
FiniteBucketAdmission == Fault # "UnboundedBucketAdmission"
NotificationLogicalBound == Fault # "NotificationLogicalBoundMissing"
RecoveryLogicalBound == Fault # "RecoveryLogicalBoundMissing"
NoWallClockClaim == Fault # "WallClockClaimFromLogicalBound"
NoContinuousPublishLivenessClaim ==
    Fault # "UnconditionalContinuousPublishLiveness"
CurrentSeparateFromPicker == Fault # "CurrentConflatedWithPickerFence"
ReschedUnderRqLock == Fault # "ReschedWithoutRqLock"
CurrentStopRequestLiveness == Fault # "CurrentStopRequestLivenessMissing"
MonitorReceiptNotLinuxResched == Fault # "LinuxReschedClaimedAsMonitorReceipt"
EnqueueHandshake == Fault # "MissingEnqueueHandshake"
MigrationSingleContribution == Fault # "MigrationDoubleContribution"
HotplugDrainComplete == Fault # "HotplugDrainIncomplete"
LifetimeRefsAndRcu == Fault # "LifetimeRefsOrRcuMissing"
NoLinuxSource == Fault # "LinuxSourceApproved"
NoRuntimeBehaviorClaim == Fault # "RuntimeBehaviorClaim"
NoProtectionClaim == Fault # "ProtectionClaim"
NoPerformanceClaim == Fault # "PerformanceClaim"
NoCostClaim == Fault # "CostClaim"

VARIABLES
    phase,
    publishedGen,
    eligible,
    projectionGen,
    projectionState,
    desiredGen,
    dirty,
    rqOwnerDepth,
    notifierDepth,
    notifierSteps,
    recoverySteps,
    staleTrusted,
    stopRequested,
    publisherWaited,
    publisherRqLocks,
    publisherRqScans

vars == <<
    phase,
    publishedGen,
    eligible,
    projectionGen,
    projectionState,
    desiredGen,
    dirty,
    rqOwnerDepth,
    notifierDepth,
    notifierSteps,
    recoverySteps,
    staleTrusted,
    stopRequested,
    publisherWaited,
    publisherRqLocks,
    publisherRqScans
>>

Phases == {
    "Start", "Published2", "Kicked2", "OldNotified0", "Stable3",
    "TailNotified1", "Notified0", "Repaired0", "Notified1",
    "EligibleSettled", "Revoked4", "CurrentNotified", "RevokeNotified",
    "Blocked0", "Done"
}

Init ==
    /\ phase = "Start"
    /\ publishedGen = 1
    /\ eligible = TRUE
    /\ projectionGen = [r \in Rqs |-> 1]
    /\ projectionState = [r \in Rqs |-> "Fresh"]
    /\ desiredGen = [r \in Rqs |-> 1]
    /\ dirty = {}
    /\ rqOwnerDepth = [r \in Rqs |-> 0]
    /\ notifierDepth = 0
    /\ notifierSteps = 0
    /\ recoverySteps = [r \in Rqs |-> 0]
    /\ staleTrusted = FALSE
    /\ stopRequested = {}
    /\ publisherWaited = 0
    /\ publisherRqLocks = 0
    /\ publisherRqScans = 0

PublishSecondGeneration ==
    /\ phase = "Start"
    /\ phase' = "Published2"
    /\ publishedGen' = 2
    /\ eligible' = TRUE
    /\ notifierDepth' = IF Fault = "MultipleBucketNotifiers" THEN 2 ELSE 1
    /\ publisherWaited' = IF Fault = "PublisherWaitsForRecovery" THEN 1 ELSE 0
    /\ publisherRqLocks' = IF Fault = "PublisherTakesRqLock" THEN 1 ELSE 0
    /\ publisherRqScans' = IF Fault = "PublisherScansRqMask" THEN 1 ELSE 0
    /\ UNCHANGED <<projectionGen, projectionState, desiredGen, dirty,
                    rqOwnerDepth, notifierSteps, recoverySteps, staleTrusted,
                    stopRequested>>

PickerFindsMismatch ==
    /\ phase = "Published2"
    /\ phase' = "Kicked2"
    /\ desiredGen' = [desiredGen EXCEPT !["rq0"] = publishedGen]
    /\ dirty' = dirty \cup {"rq0"}
    /\ rqOwnerDepth' = [rqOwnerDepth EXCEPT
          !["rq0"] = IF (Fault = "PickerKickDuplicates" \/
                          Fault = "MultipleRqOwners") THEN 2 ELSE 1]
    /\ staleTrusted' = (Fault = "PickerSkipsAcquireFence" \/
                         Fault = "PickerTrustsMismatch")
    /\ UNCHANGED <<publishedGen, eligible, projectionGen, projectionState,
                    notifierDepth, notifierSteps, recoverySteps, stopRequested,
                    publisherWaited, publisherRqLocks, publisherRqScans>>

NotifyOldGenerationRq0 ==
    /\ phase = "Kicked2"
    /\ phase' = "OldNotified0"
    /\ desiredGen' = [desiredGen EXCEPT !["rq0"] = publishedGen]
    /\ dirty' = dirty \cup {"rq0"}
    /\ rqOwnerDepth' = [rqOwnerDepth EXCEPT !["rq0"] = 1]
    /\ notifierSteps' = notifierSteps + 1
    /\ UNCHANGED <<publishedGen, eligible, projectionGen, projectionState,
                    notifierDepth, recoverySteps, staleTrusted, stopRequested,
                    publisherWaited, publisherRqLocks, publisherRqScans>>

RepublishNewestGeneration ==
    /\ phase = "OldNotified0"
    /\ phase' = "Stable3"
    /\ publishedGen' = 3
    /\ eligible' = TRUE
    /\ desiredGen' = [desiredGen EXCEPT
          !["rq0"] = IF Fault = "NewestDesiredGenerationLost" THEN 2 ELSE 3]
    /\ notifierDepth' =
          IF Fault = "NotifierDoesNotCoalesce" THEN notifierDepth + 1 ELSE 1
    /\ notifierSteps' = 0
    /\ recoverySteps' = [r \in Rqs |-> 0]
    /\ staleTrusted' = FALSE
    /\ UNCHANGED <<projectionGen, projectionState, dirty, rqOwnerDepth,
                    stopRequested, publisherWaited, publisherRqLocks,
                    publisherRqScans>>

FinishOldPassRq1 ==
    /\ phase = "Stable3"
    /\ phase' = "TailNotified1"
    /\ desiredGen' = [desiredGen EXCEPT !["rq1"] = publishedGen]
    /\ dirty' = dirty \cup {"rq1"}
    /\ rqOwnerDepth' = [rqOwnerDepth EXCEPT !["rq1"] = 1]
    /\ notifierSteps' = notifierSteps + 1
    /\ UNCHANGED <<publishedGen, eligible, projectionGen, projectionState,
                    notifierDepth, recoverySteps, staleTrusted, stopRequested,
                    publisherWaited, publisherRqLocks, publisherRqScans>>

RestartNotifyRq0 ==
    /\ phase = "TailNotified1"
    /\ phase' = "Notified0"
    /\ desiredGen' = [desiredGen EXCEPT !["rq0"] = publishedGen]
    /\ dirty' = dirty \cup {"rq0"}
    /\ rqOwnerDepth' = [rqOwnerDepth EXCEPT !["rq0"] = 1]
    /\ notifierSteps' = notifierSteps + 1
    /\ UNCHANGED <<publishedGen, eligible, projectionGen, projectionState,
                    notifierDepth, recoverySteps, staleTrusted, stopRequested,
                    publisherWaited, publisherRqLocks, publisherRqScans>>

RepairRq0 ==
    /\ phase = "Notified0"
    /\ phase' = "Repaired0"
    /\ projectionGen' = [projectionGen EXCEPT
          !["rq0"] = IF (Fault = "RecoverySkipsFinalRecheck" \/
                          Fault = "RacedRecoveryPublishesFresh")
                       THEN 2 ELSE publishedGen]
    /\ projectionState' = [projectionState EXCEPT !["rq0"] = "Fresh"]
    /\ dirty' = dirty \ {"rq0"}
    /\ rqOwnerDepth' = [rqOwnerDepth EXCEPT !["rq0"] = 0]
    /\ recoverySteps' = [recoverySteps EXCEPT !["rq0"] = @ + 1]
    /\ UNCHANGED <<publishedGen, eligible, desiredGen, notifierDepth,
                    notifierSteps, staleTrusted, stopRequested, publisherWaited,
                    publisherRqLocks, publisherRqScans>>

RestartVisitRq1 ==
    /\ phase = "Repaired0"
    /\ phase' = "Notified1"
    /\ desiredGen' = [desiredGen EXCEPT !["rq1"] = publishedGen]
    /\ dirty' = dirty \cup {"rq1"}
    /\ rqOwnerDepth' = [rqOwnerDepth EXCEPT !["rq1"] = 1]
    /\ notifierDepth' = 0
    /\ notifierSteps' = notifierSteps + 1
    /\ UNCHANGED <<publishedGen, eligible, projectionGen, projectionState,
                    recoverySteps, staleTrusted, stopRequested, publisherWaited,
                    publisherRqLocks, publisherRqScans>>

RepairRq1 ==
    /\ phase = "Notified1"
    /\ phase' = "EligibleSettled"
    /\ projectionGen' = [projectionGen EXCEPT !["rq1"] = publishedGen]
    /\ projectionState' = [projectionState EXCEPT !["rq1"] = "Fresh"]
    /\ dirty' = dirty \ {"rq1"}
    /\ rqOwnerDepth' = [rqOwnerDepth EXCEPT !["rq1"] = 0]
    /\ recoverySteps' = [recoverySteps EXCEPT !["rq1"] = @ + 1]
    /\ UNCHANGED <<publishedGen, eligible, desiredGen, notifierDepth,
                    notifierSteps, staleTrusted, stopRequested, publisherWaited,
                    publisherRqLocks, publisherRqScans>>

PublishRevoke ==
    /\ phase = "EligibleSettled"
    /\ phase' = "Revoked4"
    /\ publishedGen' = 4
    /\ eligible' = FALSE
    /\ notifierDepth' = 1
    /\ notifierSteps' = 0
    /\ recoverySteps' = [r \in Rqs |-> 0]
    /\ stopRequested' = {}
    /\ UNCHANGED <<projectionGen, projectionState, desiredGen, dirty,
                    rqOwnerDepth, staleTrusted, publisherWaited,
                    publisherRqLocks, publisherRqScans>>

NotifyCurrentRq0 ==
    /\ phase = "Revoked4"
    /\ phase' = "CurrentNotified"
    /\ desiredGen' = [desiredGen EXCEPT !["rq0"] = publishedGen]
    /\ dirty' = dirty \cup {"rq0"}
    /\ rqOwnerDepth' = [rqOwnerDepth EXCEPT !["rq0"] = 1]
    /\ notifierSteps' = notifierSteps + 1
    /\ stopRequested' =
          IF Fault = "CurrentStopRequestLivenessMissing"
          THEN stopRequested ELSE stopRequested \cup {"rq0"}
    /\ UNCHANGED <<publishedGen, eligible, projectionGen, projectionState,
                    notifierDepth, recoverySteps, staleTrusted, publisherWaited,
                    publisherRqLocks, publisherRqScans>>

NotifyRevokedRq1 ==
    /\ phase = "CurrentNotified"
    /\ phase' = "RevokeNotified"
    /\ desiredGen' = [desiredGen EXCEPT !["rq1"] = publishedGen]
    /\ dirty' = dirty \cup {"rq1"}
    /\ rqOwnerDepth' = [rqOwnerDepth EXCEPT !["rq1"] = 1]
    /\ notifierDepth' = 0
    /\ notifierSteps' = notifierSteps + 1
    /\ UNCHANGED <<publishedGen, eligible, projectionGen, projectionState,
                    recoverySteps, staleTrusted, stopRequested, publisherWaited,
                    publisherRqLocks, publisherRqScans>>

BlockRq0 ==
    /\ phase = "RevokeNotified"
    /\ phase' = "Blocked0"
    /\ projectionGen' = [projectionGen EXCEPT !["rq0"] = publishedGen]
    /\ projectionState' = [projectionState EXCEPT !["rq0"] = "Blocked"]
    /\ dirty' = dirty \ {"rq0"}
    /\ rqOwnerDepth' = [rqOwnerDepth EXCEPT !["rq0"] = 0]
    /\ recoverySteps' = [recoverySteps EXCEPT !["rq0"] = @ + 1]
    /\ UNCHANGED <<publishedGen, eligible, desiredGen, notifierDepth,
                    notifierSteps, staleTrusted, stopRequested, publisherWaited,
                    publisherRqLocks, publisherRqScans>>

BlockRq1 ==
    /\ phase = "Blocked0"
    /\ phase' = "Done"
    /\ projectionGen' = [projectionGen EXCEPT !["rq1"] = publishedGen]
    /\ projectionState' = [projectionState EXCEPT !["rq1"] = "Blocked"]
    /\ dirty' = dirty \ {"rq1"}
    /\ rqOwnerDepth' = [rqOwnerDepth EXCEPT !["rq1"] = 0]
    /\ recoverySteps' = [recoverySteps EXCEPT !["rq1"] = @ + 1]
    /\ UNCHANGED <<publishedGen, eligible, desiredGen, notifierDepth,
                    notifierSteps, staleTrusted, stopRequested, publisherWaited,
                    publisherRqLocks, publisherRqScans>>

Done == phase = "Done" /\ UNCHANGED vars

Next ==
    \/ PublishSecondGeneration
    \/ PickerFindsMismatch
    \/ NotifyOldGenerationRq0
    \/ RepublishNewestGeneration
    \/ FinishOldPassRq1
    \/ RestartNotifyRq0
    \/ RepairRq0
    \/ RestartVisitRq1
    \/ RepairRq1
    \/ PublishRevoke
    \/ NotifyCurrentRq0
    \/ NotifyRevokedRq1
    \/ BlockRq0
    \/ BlockRq1
    \/ Done

Spec ==
    /\ Init
    /\ [][Next]_vars
    /\ WF_vars(PublishSecondGeneration)
    /\ WF_vars(PickerFindsMismatch)
    /\ WF_vars(NotifyOldGenerationRq0)
    /\ WF_vars(RepublishNewestGeneration)
    /\ WF_vars(FinishOldPassRq1)
    /\ WF_vars(RestartNotifyRq0)
    /\ WF_vars(RepairRq0)
    /\ WF_vars(RestartVisitRq1)
    /\ WF_vars(RepairRq1)
    /\ WF_vars(PublishRevoke)
    /\ WF_vars(NotifyCurrentRq0)
    /\ WF_vars(NotifyRevokedRq1)
    /\ WF_vars(BlockRq0)
    /\ WF_vars(BlockRq1)

TypeOK ==
    /\ phase \in Phases
    /\ publishedGen \in 1..4
    /\ eligible \in BOOLEAN
    /\ projectionGen \in [Rqs -> 1..4]
    /\ projectionState \in [Rqs -> {"Fresh", "Blocked"}]
    /\ desiredGen \in [Rqs -> 1..4]
    /\ dirty \subseteq Rqs
    /\ rqOwnerDepth \in [Rqs -> 0..2]
    /\ notifierDepth \in 0..2
    /\ notifierSteps \in 0..4
    /\ recoverySteps \in [Rqs -> 0..BMax]
    /\ staleTrusted \in BOOLEAN
    /\ stopRequested \subseteq Rqs
    /\ publisherWaited \in 0..1
    /\ publisherRqLocks \in 0..1
    /\ publisherRqScans \in 0..1

Contract ==
    /\ ExactR3Rejection
    /\ FanoutAvailabilityOnly
    /\ R3ThresholdsImmutable
    /\ PublicationCriticalSectionO1
    /\ ReleaseGeneration
    /\ PublisherDoesNotScanRqMask
    /\ PublisherDoesNotTakeRqLock
    /\ PublisherDoesNotWait
    /\ NoGenerationWrapReuse
    /\ SaturationBlocks
    /\ OneBucketNotifier
    /\ NotifierCoalesces
    /\ PickerAcquireFence
    /\ PickerMismatchUntrusted
    /\ PickerO1
    /\ PickerKickIdempotent
    /\ PickerDoesNotRepair
    /\ MappedPostLockDispatch
    /\ OneRqOwner
    /\ NewestDesiredWins
    /\ DirtyDepthIndependentOfPublications
    /\ OneProjectionPerRqLock
    /\ FinalGenerationRecheck
    /\ RacedRecoveryRemainsDirty
    /\ NoSynchronousSettlement
    /\ NoGlobalFreshSettlementGate
    /\ StableWindowAssumption
    /\ WeakFairnessAssumption
    /\ FiniteActiveSet
    /\ FiniteBucketAdmission
    /\ NotificationLogicalBound
    /\ RecoveryLogicalBound
    /\ NoWallClockClaim
    /\ NoContinuousPublishLivenessClaim
    /\ CurrentSeparateFromPicker
    /\ ReschedUnderRqLock
    /\ CurrentStopRequestLiveness
    /\ MonitorReceiptNotLinuxResched
    /\ EnqueueHandshake
    /\ MigrationSingleContribution
    /\ HotplugDrainComplete
    /\ LifetimeRefsAndRcu
    /\ NoLinuxSource
    /\ NoRuntimeBehaviorClaim
    /\ NoProtectionClaim
    /\ NoPerformanceClaim
    /\ NoCostClaim

QueueBounds ==
    /\ notifierDepth <= 1
    /\ \A r \in Rqs : rqOwnerDepth[r] <= 1
    /\ Cardinality(dirty) <= BMax

PublisherBound ==
    /\ publisherWaited = 0
    /\ publisherRqLocks = 0
    /\ publisherRqScans = 0

LogicalWorkBounds ==
    /\ notifierSteps <= 2 * Cardinality(Rqs)
    /\ \A r \in Rqs : recoverySteps[r] <= BMax

EligibleSettlementSound ==
    phase = "EligibleSettled" =>
        eligible /\ publishedGen = 3 /\
        \A r \in Rqs :
            projectionState[r] = "Fresh" /\ projectionGen[r] = publishedGen

CurrentRequestSound ==
    phase \in {"CurrentNotified", "RevokeNotified", "Blocked0", "Done"} =>
        "rq0" \in stopRequested

RevokedSettlementSound ==
    phase = "Done" =>
        ~eligible /\ publishedGen = 4 /\ dirty = {} /\
        \A r \in Rqs :
            projectionState[r] = "Blocked" /\
            projectionGen[r] = publishedGen /\ rqOwnerDepth[r] = 0

DynamicSafety ==
    /\ ~staleTrusted
    /\ QueueBounds
    /\ PublisherBound
    /\ LogicalWorkBounds
    /\ EligibleSettlementSound
    /\ CurrentRequestSound
    /\ RevokedSettlementSound

Safety == DynamicSafety /\ (phase = "Done" => Contract)

EligibleStableRecovery ==
    [](phase = "Stable3" => <> (phase = "EligibleSettled"))

RevokedStableRecovery ==
    [](phase = "Revoked4" => <> (phase = "Done"))

=============================================================================
