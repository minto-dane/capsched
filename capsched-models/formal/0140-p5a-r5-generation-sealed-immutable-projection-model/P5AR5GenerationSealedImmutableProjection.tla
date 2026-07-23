---------- MODULE P5AR5GenerationSealedImmutableProjection ----------
EXTENDS Naturals, FiniteSets

CONSTANT Fault

Rqs == {"rq0", "rq1"}

ExactR4Result == Fault # "MissingR4Result"
ExactDoubleClosure == Fault # "MissingDoubleClosure"
ThresholdsImmutable == Fault # "ThresholdsRelaxed"
PublisherDoesNotScan == Fault # "PublicationScansRqs"
PublisherDoesNotTakeRqLock == Fault # "PublicationTakesRqLock"
PublisherDoesNotWait == Fault # "PublisherWaitsForViews"
NoGenerationReuse == Fault # "GenerationReuse"
SaturationBlocks == Fault # "SaturationDoesNotBlock"
MutableViewNeverTrusted == Fault # "MutableViewTrusted"
ExactGenerationFence == Fault # "GenerationMismatchTrusted"
ExactMembershipFence == Fault # "MembershipMismatchTrusted"
ExactSelectorFence == Fault # "SelectorMismatchTrusted"
SealedViewRequired == Fault # "UnsealedViewTrusted"
TaskLocalRecheck == Fault # "TaskLocalRecheckMissing"
NoFallbackAuthority == Fault # "FallbackAuthority"
BuildOutsideRqLock == Fault # "BuildUnderRqLock"
BuildStartEndFence == Fault # "BuildWithoutStartEndFence"
RacedBuildDiscarded == Fault # "RacedBuildNotDiscarded"
AllocationFailureBlocks == Fault # "AllocationFailureUsesOldView"
OneCompileOwner == Fault # "DuplicateCompileOwners"
NewestDesiredWins == Fault # "NewestDesiredGenerationLost"
QueueDepthIndependentOfPublications == Fault # "QueueDepthPerPublication"
InstallDoesNotScan == Fault # "InstallScansMembership"
InstallDoesNotAllocateOrWait == Fault # "InstallAllocatesOrWaits"
InstallUnderRqLock == Fault # "InstallWithoutRqLock"
InstallFinalDescriptorCheck == Fault # "InstallSkipsFinalDescriptor"
InstallRequiresReceipt == Fault # "InstallWithoutSealedReceipt"
RcuBeforeFree == Fault # "OldViewFreedBeforeRcu"
ExplicitViewReferences == Fault # "ViewReferencesMissing"
NoProjectionRepairNotifier == Fault # "ProjectionRepairNotifierRetained"
CurrentStopSeparate == Fault # "CurrentStopConflatedWithRepair"
CurrentStopObservation == Fault # "CurrentStopObservationMissing"
LinuxReschedNotReceipt == Fault # "LinuxReschedClaimedAsReceipt"
StableWindowAssumption == Fault # "StableWindowMissing"
WeakFairnessAssumption == Fault # "WeakFairnessMissing"
FiniteMembership == Fault # "UnboundedMembership"
NoContinuousPublishAvailabilityClaim ==
    Fault # "ContinuousPublishAvailabilityClaim"
NoGlobalSettlementDeadline == Fault # "GlobalSettlementDeadlineRestored"
EnqueueHandshake == Fault # "EnqueueHandshakeMissing"
MigrationSingleContribution == Fault # "MigrationDoubleContribution"
OfflineClearsAcceptingFirst == Fault # "OfflineAcceptingClearedLate"
OfflineWaitOutsideRqLock == Fault # "OfflineWaitUnderRqLock"
NoX86Timing == Fault # "X86TimingAuthorized"
NoR5Source == Fault # "R5SourceAuthorized"
NoRuntimeBehaviorClaim == Fault # "RuntimeBehaviorClaim"
NoBareMetalPerformanceClaim == Fault # "BareMetalPerformanceClaim"
NoProtectionClaim == Fault # "ProtectionClaim"
NoProductionClaim == Fault # "ProductionClaim"
NoDatacenterClaim == Fault # "DatacenterClaim"

VARIABLES
    phase,
    publishedGen,
    membershipSeq,
    eligible,
    desiredGen,
    viewGen,
    viewSeq,
    viewState,
    buildGen,
    buildSeq,
    buildState,
    ownerDepth,
    staleTrusted,
    installWork,
    publisherScans,
    publisherRqLocks,
    publisherWaits,
    stopRequested

vars == <<
    phase,
    publishedGen,
    membershipSeq,
    eligible,
    desiredGen,
    viewGen,
    viewSeq,
    viewState,
    buildGen,
    buildSeq,
    buildState,
    ownerDepth,
    staleTrusted,
    installWork,
    publisherScans,
    publisherRqLocks,
    publisherWaits,
    stopRequested
>>

Phases == {
    "Start", "Published2", "Demanded0", "Built0", "Installed0",
    "Demanded1", "Built1", "EligibleSettled", "Revoked3",
    "CurrentObserved", "RevokeDemanded0", "RevokeBuilt0",
    "Blocked0", "RevokeDemanded1", "RevokeBuilt1", "Done"
}

Init ==
    /\ phase = "Start"
    /\ publishedGen = 1
    /\ membershipSeq = 1
    /\ eligible = TRUE
    /\ desiredGen = [r \in Rqs |-> 1]
    /\ viewGen = [r \in Rqs |-> 1]
    /\ viewSeq = [r \in Rqs |-> 1]
    /\ viewState = [r \in Rqs |-> "Sealed"]
    /\ buildGen = [r \in Rqs |-> 1]
    /\ buildSeq = [r \in Rqs |-> 1]
    /\ buildState = [r \in Rqs |-> "Idle"]
    /\ ownerDepth = [r \in Rqs |-> 0]
    /\ staleTrusted = FALSE
    /\ installWork = [r \in Rqs |-> 0]
    /\ publisherScans = 0
    /\ publisherRqLocks = 0
    /\ publisherWaits = 0
    /\ stopRequested = {}

PublishEligible ==
    /\ phase = "Start"
    /\ phase' = "Published2"
    /\ publishedGen' = 2
    /\ membershipSeq' = 2
    /\ eligible' = TRUE
    /\ publisherScans' = IF Fault = "PublicationScansRqs" THEN 1 ELSE 0
    /\ publisherRqLocks' = IF Fault = "PublicationTakesRqLock" THEN 1 ELSE 0
    /\ publisherWaits' = IF Fault = "PublisherWaitsForViews" THEN 1 ELSE 0
    /\ UNCHANGED <<desiredGen, viewGen, viewSeq, viewState, buildGen,
                    buildSeq, buildState, ownerDepth, staleTrusted,
                    installWork, stopRequested>>

DemandRq0 ==
    /\ phase = "Published2"
    /\ phase' = "Demanded0"
    /\ desiredGen' = [desiredGen EXCEPT !["rq0"] = publishedGen]
    /\ ownerDepth' = [ownerDepth EXCEPT !["rq0"] =
          IF Fault = "DuplicateCompileOwners" THEN 2 ELSE 1]
    /\ staleTrusted' =
          (Fault \in {
              "MutableViewTrusted", "GenerationMismatchTrusted",
              "MembershipMismatchTrusted", "SelectorMismatchTrusted",
              "UnsealedViewTrusted", "TaskLocalRecheckMissing",
              "FallbackAuthority"
          })
    /\ UNCHANGED <<publishedGen, membershipSeq, eligible, viewGen, viewSeq,
                    viewState, buildGen, buildSeq, buildState, installWork,
                    publisherScans, publisherRqLocks, publisherWaits,
                    stopRequested>>

BuildRq0 ==
    /\ phase = "Demanded0"
    /\ phase' = "Built0"
    /\ buildGen' = [buildGen EXCEPT !["rq0"] =
          IF Fault = "NewestDesiredGenerationLost" THEN 1 ELSE publishedGen]
    /\ buildSeq' = [buildSeq EXCEPT !["rq0"] = membershipSeq]
    /\ buildState' = [buildState EXCEPT !["rq0"] =
          IF Fault = "InstallWithoutSealedReceipt" THEN "Building" ELSE "Sealed"]
    /\ UNCHANGED <<publishedGen, membershipSeq, eligible, desiredGen, viewGen,
                    viewSeq, viewState, ownerDepth, staleTrusted, installWork,
                    publisherScans, publisherRqLocks, publisherWaits,
                    stopRequested>>

InstallRq0 ==
    /\ phase = "Built0"
    /\ phase' = "Installed0"
    /\ viewGen' = [viewGen EXCEPT !["rq0"] = buildGen["rq0"]]
    /\ viewSeq' = [viewSeq EXCEPT !["rq0"] = buildSeq["rq0"]]
    /\ viewState' = [viewState EXCEPT !["rq0"] =
          IF buildState["rq0"] = "Sealed" /\
             buildGen["rq0"] = publishedGen /\
             buildSeq["rq0"] = membershipSeq
          THEN "Sealed" ELSE "Blocked"]
    /\ ownerDepth' = [ownerDepth EXCEPT !["rq0"] = 0]
    /\ installWork' = [installWork EXCEPT !["rq0"] =
          IF (Fault \in {"InstallScansMembership", "InstallAllocatesOrWaits"})
          THEN 2 ELSE 1]
    /\ UNCHANGED <<publishedGen, membershipSeq, eligible, desiredGen, buildGen,
                    buildSeq, buildState, staleTrusted, publisherScans,
                    publisherRqLocks, publisherWaits, stopRequested>>

DemandRq1 ==
    /\ phase = "Installed0"
    /\ phase' = "Demanded1"
    /\ desiredGen' = [desiredGen EXCEPT !["rq1"] = publishedGen]
    /\ ownerDepth' = [ownerDepth EXCEPT !["rq1"] = 1]
    /\ UNCHANGED <<publishedGen, membershipSeq, eligible, viewGen, viewSeq,
                    viewState, buildGen, buildSeq, buildState, staleTrusted,
                    installWork, publisherScans, publisherRqLocks,
                    publisherWaits, stopRequested>>

BuildRq1 ==
    /\ phase = "Demanded1"
    /\ phase' = "Built1"
    /\ buildGen' = [buildGen EXCEPT !["rq1"] = publishedGen]
    /\ buildSeq' = [buildSeq EXCEPT !["rq1"] = membershipSeq]
    /\ buildState' = [buildState EXCEPT !["rq1"] = "Sealed"]
    /\ UNCHANGED <<publishedGen, membershipSeq, eligible, desiredGen, viewGen,
                    viewSeq, viewState, ownerDepth, staleTrusted, installWork,
                    publisherScans, publisherRqLocks, publisherWaits,
                    stopRequested>>

InstallRq1 ==
    /\ phase = "Built1"
    /\ phase' = "EligibleSettled"
    /\ viewGen' = [viewGen EXCEPT !["rq1"] = buildGen["rq1"]]
    /\ viewSeq' = [viewSeq EXCEPT !["rq1"] = buildSeq["rq1"]]
    /\ viewState' = [viewState EXCEPT !["rq1"] = "Sealed"]
    /\ ownerDepth' = [ownerDepth EXCEPT !["rq1"] = 0]
    /\ installWork' = [installWork EXCEPT !["rq1"] = 1]
    /\ UNCHANGED <<publishedGen, membershipSeq, eligible, desiredGen, buildGen,
                    buildSeq, buildState, staleTrusted, publisherScans,
                    publisherRqLocks, publisherWaits, stopRequested>>

PublishRevoke ==
    /\ phase = "EligibleSettled"
    /\ phase' = "Revoked3"
    /\ publishedGen' = 3
    /\ eligible' = FALSE
    /\ UNCHANGED <<membershipSeq, desiredGen, viewGen, viewSeq, viewState,
                    buildGen, buildSeq, buildState, ownerDepth, staleTrusted,
                    installWork, publisherScans, publisherRqLocks,
                    publisherWaits, stopRequested>>

ObserveCurrentStop ==
    /\ phase = "Revoked3"
    /\ phase' = "CurrentObserved"
    /\ stopRequested' =
          IF (Fault \in {"CurrentStopConflatedWithRepair",
                         "CurrentStopObservationMissing"})
          THEN {} ELSE {"rq0"}
    /\ UNCHANGED <<publishedGen, membershipSeq, eligible, desiredGen, viewGen,
                    viewSeq, viewState, buildGen, buildSeq, buildState,
                    ownerDepth, staleTrusted, installWork, publisherScans,
                    publisherRqLocks, publisherWaits>>

DemandRevokeRq0 ==
    /\ phase = "CurrentObserved"
    /\ phase' = "RevokeDemanded0"
    /\ desiredGen' = [desiredGen EXCEPT !["rq0"] = publishedGen]
    /\ ownerDepth' = [ownerDepth EXCEPT !["rq0"] = 1]
    /\ UNCHANGED <<publishedGen, membershipSeq, eligible, viewGen, viewSeq,
                    viewState, buildGen, buildSeq, buildState, staleTrusted,
                    installWork, publisherScans, publisherRqLocks,
                    publisherWaits, stopRequested>>

BuildRevokeRq0 ==
    /\ phase = "RevokeDemanded0"
    /\ phase' = "RevokeBuilt0"
    /\ buildGen' = [buildGen EXCEPT !["rq0"] = publishedGen]
    /\ buildSeq' = [buildSeq EXCEPT !["rq0"] = membershipSeq]
    /\ buildState' = [buildState EXCEPT !["rq0"] = "Sealed"]
    /\ UNCHANGED <<publishedGen, membershipSeq, eligible, desiredGen, viewGen,
                    viewSeq, viewState, ownerDepth, staleTrusted, installWork,
                    publisherScans, publisherRqLocks, publisherWaits,
                    stopRequested>>

InstallBlockedRq0 ==
    /\ phase = "RevokeBuilt0"
    /\ phase' = "Blocked0"
    /\ viewGen' = [viewGen EXCEPT !["rq0"] = publishedGen]
    /\ viewSeq' = [viewSeq EXCEPT !["rq0"] = membershipSeq]
    /\ viewState' = [viewState EXCEPT !["rq0"] = "Blocked"]
    /\ ownerDepth' = [ownerDepth EXCEPT !["rq0"] = 0]
    /\ installWork' = [installWork EXCEPT !["rq0"] = 1]
    /\ UNCHANGED <<publishedGen, membershipSeq, eligible, desiredGen, buildGen,
                    buildSeq, buildState, staleTrusted, publisherScans,
                    publisherRqLocks, publisherWaits, stopRequested>>

DemandRevokeRq1 ==
    /\ phase = "Blocked0"
    /\ phase' = "RevokeDemanded1"
    /\ desiredGen' = [desiredGen EXCEPT !["rq1"] = publishedGen]
    /\ ownerDepth' = [ownerDepth EXCEPT !["rq1"] = 1]
    /\ UNCHANGED <<publishedGen, membershipSeq, eligible, viewGen, viewSeq,
                    viewState, buildGen, buildSeq, buildState, staleTrusted,
                    installWork, publisherScans, publisherRqLocks,
                    publisherWaits, stopRequested>>

BuildRevokeRq1 ==
    /\ phase = "RevokeDemanded1"
    /\ phase' = "RevokeBuilt1"
    /\ buildGen' = [buildGen EXCEPT !["rq1"] = publishedGen]
    /\ buildSeq' = [buildSeq EXCEPT !["rq1"] = membershipSeq]
    /\ buildState' = [buildState EXCEPT !["rq1"] = "Sealed"]
    /\ UNCHANGED <<publishedGen, membershipSeq, eligible, desiredGen, viewGen,
                    viewSeq, viewState, ownerDepth, staleTrusted, installWork,
                    publisherScans, publisherRqLocks, publisherWaits,
                    stopRequested>>

InstallBlockedRq1 ==
    /\ phase = "RevokeBuilt1"
    /\ phase' = "Done"
    /\ viewGen' = [viewGen EXCEPT !["rq1"] = publishedGen]
    /\ viewSeq' = [viewSeq EXCEPT !["rq1"] = membershipSeq]
    /\ viewState' = [viewState EXCEPT !["rq1"] = "Blocked"]
    /\ ownerDepth' = [ownerDepth EXCEPT !["rq1"] = 0]
    /\ installWork' = [installWork EXCEPT !["rq1"] = 1]
    /\ UNCHANGED <<publishedGen, membershipSeq, eligible, desiredGen, buildGen,
                    buildSeq, buildState, staleTrusted, publisherScans,
                    publisherRqLocks, publisherWaits, stopRequested>>

Next ==
    \/ PublishEligible
    \/ DemandRq0
    \/ BuildRq0
    \/ InstallRq0
    \/ DemandRq1
    \/ BuildRq1
    \/ InstallRq1
    \/ PublishRevoke
    \/ ObserveCurrentStop
    \/ DemandRevokeRq0
    \/ BuildRevokeRq0
    \/ InstallBlockedRq0
    \/ DemandRevokeRq1
    \/ BuildRevokeRq1
    \/ InstallBlockedRq1

Spec ==
    /\ Init
    /\ [][Next]_vars
    /\ WF_vars(PublishEligible)
    /\ WF_vars(DemandRq0)
    /\ WF_vars(BuildRq0)
    /\ WF_vars(InstallRq0)
    /\ WF_vars(DemandRq1)
    /\ WF_vars(BuildRq1)
    /\ WF_vars(InstallRq1)
    /\ WF_vars(PublishRevoke)
    /\ WF_vars(ObserveCurrentStop)
    /\ WF_vars(DemandRevokeRq0)
    /\ WF_vars(BuildRevokeRq0)
    /\ WF_vars(InstallBlockedRq0)
    /\ WF_vars(DemandRevokeRq1)
    /\ WF_vars(BuildRevokeRq1)
    /\ WF_vars(InstallBlockedRq1)

TypeOK ==
    /\ phase \in Phases
    /\ publishedGen \in 1..3
    /\ membershipSeq \in 1..2
    /\ eligible \in BOOLEAN
    /\ desiredGen \in [Rqs -> 1..3]
    /\ viewGen \in [Rqs -> 1..3]
    /\ viewSeq \in [Rqs -> 1..2]
    /\ viewState \in [Rqs -> {"Sealed", "Blocked"}]
    /\ buildGen \in [Rqs -> 1..3]
    /\ buildSeq \in [Rqs -> 1..2]
    /\ buildState \in [Rqs -> {"Idle", "Building", "Sealed"}]
    /\ ownerDepth \in [Rqs -> 0..2]
    /\ staleTrusted \in BOOLEAN
    /\ installWork \in [Rqs -> 0..2]
    /\ publisherScans \in 0..1
    /\ publisherRqLocks \in 0..1
    /\ publisherWaits \in 0..1
    /\ stopRequested \subseteq Rqs

Contract ==
    /\ ExactR4Result
    /\ ExactDoubleClosure
    /\ ThresholdsImmutable
    /\ PublisherDoesNotScan
    /\ PublisherDoesNotTakeRqLock
    /\ PublisherDoesNotWait
    /\ NoGenerationReuse
    /\ SaturationBlocks
    /\ MutableViewNeverTrusted
    /\ ExactGenerationFence
    /\ ExactMembershipFence
    /\ ExactSelectorFence
    /\ SealedViewRequired
    /\ TaskLocalRecheck
    /\ NoFallbackAuthority
    /\ BuildOutsideRqLock
    /\ BuildStartEndFence
    /\ RacedBuildDiscarded
    /\ AllocationFailureBlocks
    /\ OneCompileOwner
    /\ NewestDesiredWins
    /\ QueueDepthIndependentOfPublications
    /\ InstallDoesNotScan
    /\ InstallDoesNotAllocateOrWait
    /\ InstallUnderRqLock
    /\ InstallFinalDescriptorCheck
    /\ InstallRequiresReceipt
    /\ RcuBeforeFree
    /\ ExplicitViewReferences
    /\ NoProjectionRepairNotifier
    /\ CurrentStopSeparate
    /\ CurrentStopObservation
    /\ LinuxReschedNotReceipt
    /\ StableWindowAssumption
    /\ WeakFairnessAssumption
    /\ FiniteMembership
    /\ NoContinuousPublishAvailabilityClaim
    /\ NoGlobalSettlementDeadline
    /\ EnqueueHandshake
    /\ MigrationSingleContribution
    /\ OfflineClearsAcceptingFirst
    /\ OfflineWaitOutsideRqLock
    /\ NoX86Timing
    /\ NoR5Source
    /\ NoRuntimeBehaviorClaim
    /\ NoBareMetalPerformanceClaim
    /\ NoProtectionClaim
    /\ NoProductionClaim
    /\ NoDatacenterClaim

DynamicSafety ==
    /\ ~staleTrusted
    /\ publisherScans = 0
    /\ publisherRqLocks = 0
    /\ publisherWaits = 0
    /\ \A r \in Rqs : ownerDepth[r] <= 1 /\ installWork[r] <= 1
    /\ (phase = "EligibleSettled" =>
          eligible /\ publishedGen = 2 /\
          \A r \in Rqs :
              viewState[r] = "Sealed" /\
              viewGen[r] = publishedGen /\
              viewSeq[r] = membershipSeq)
    /\ (phase \in {
          "CurrentObserved", "RevokeDemanded0", "RevokeBuilt0", "Blocked0",
          "RevokeDemanded1", "RevokeBuilt1", "Done"
        } => "rq0" \in stopRequested)
    /\ (phase = "Done" =>
          ~eligible /\ publishedGen = 3 /\
          \A r \in Rqs :
              viewState[r] = "Blocked" /\
              viewGen[r] = publishedGen /\
              viewSeq[r] = membershipSeq /\
              ownerDepth[r] = 0)

Safety == DynamicSafety /\ (phase = "Done" => Contract)

StableEligibleDemandInstalls ==
    [](phase = "Published2" => <> (phase = "EligibleSettled"))

StableRevokedDemandBlocks ==
    [](phase = "Revoked3" => <> (phase = "Done"))

=============================================================================
