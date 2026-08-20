---------- MODULE P5AR6E3CorrectnessConcurrencyEvidencePlan ----------
EXTENDS Naturals, Integers, FiniteSets

CONSTANT Fault

Domains == {"A", "B"}
NoDomain == "None"
Phases == {
    "Ready", "Observed", "Picked", "Accounted", "Revoked",
    "Reconciled", "Reallowed", "Neutral", "Migrated",
    "StopRequested", "StopObserved", "Offline", "Drained", "Done"
}

SafetyFaults == {
    "MissingE2ClosureBinding",
    "WrongFutureParent",
    "WrongTwoFileScope",
    "E2LayoutBlockChanged",
    "E2ProbeValuesChanged",
    "E3NotDefaultOff",
    "E3SelectedNormally",
    "DisabledArtifactPresent",
    "PublicSurfaceAdded",
    "LiveSchedulerAttachment",
    "ProductionHookCalled",
    "OracleSharesImplementationHelper",
    "OracleDoesNotEnumerate64",
    "OracleCheckpointMissing",
    "CaseReceiptMissing",
    "WrongUniqueNodeBound",
    "AggregateVisitOverflow",
    "CandidateVisitOverflow",
    "CompleteVisitOverflow",
    "LeafAncestorOverflow",
    "ReconcileOverflow",
    "LogarithmicMaskClaim",
    "StaleTreeVersion",
    "WrongSignedDivision",
    "UnstableTieBreak",
    "DeniedDomainSelected",
    "DeniedDomainService",
    "EqualWeightServiceViolation",
    "StableMaskStarvation",
    "ReallowNegativeLag",
    "ReallowCatchUpCredit",
    "PositiveDebtErased",
    "CgroupAuthority",
    "MixedDomainSubtree",
    "DuplicateDomainRoot",
    "RootLeasedTask",
    "AutogroupAccepted",
    "MissingFinalTaskCheck",
    "OldDescriptorFallback",
    "ForkBindingMutable",
    "ExecGenerationLate",
    "EnqueueWithoutRecheck",
    "ContributionDuplicated",
    "CgroupMoveChangesAuthority",
    "MigrationDoubleContribution",
    "MigrationNeutralMissing",
    "DestinationNotRechecked",
    "DestinationFailureRestoresSource",
    "OrdinaryRootFallback",
    "CurrentConflatedWithPicker",
    "CurrentRequestClaimedComplete",
    "OfflineKeepsAccepting",
    "OfflineKeepsVisibility",
    "SleepableDrainUnderLock",
    "OnlineAcceptsBeforeInit",
    "FreeWithContribution",
    "FreeWithReaderOrRef",
    "RcuGraceMissing",
    "GenerationWrapReused",
    "SlotIdentityReused",
    "AllocationUnderLock",
    "AllocationFailureResidue",
    "Slot65Accepted",
    "TimingSleepUsedAsProof",
    "RequiredCaseSkipped",
    "DiagnosticMatrixReduced",
    "WarningAccepted",
    "E4SourcePremature",
    "PrimaryLinuxChanged",
    "RuntimeClaim",
    "MonitorClaim",
    "FlatCfsClaim",
    "ProtectionClaim",
    "PerformanceClaim",
    "CostClaim",
    "DeploymentClaim",
    "MultiNodeClaim",
    "MultiClusterClaim",
    "DatacenterClaim"
}

VARIABLES phase, generation, observedGeneration, allowedDomains,
          selectedDomain, aggregateVisits, candidateVisits,
          reconcileVisits, ancestorVisits, leafVersion, summaryVersion,
          reallowLag, catchUpCredit, serviceA, serviceB, deniedService,
          sourceContribution, destinationContribution, currentDomain,
          stopRequest, stopObserved, accepting, visible, readers, refs,
          rcuGrace, freed

vars ==
    <<phase, generation, observedGeneration, allowedDomains,
      selectedDomain, aggregateVisits, candidateVisits,
      reconcileVisits, ancestorVisits, leafVersion, summaryVersion,
      reallowLag, catchUpCredit, serviceA, serviceB, deniedService,
      sourceContribution, destinationContribution, currentDomain,
      stopRequest, stopObserved, accepting, visible, readers, refs,
      rcuGrace, freed>>

Init ==
    /\ phase = "Ready"
    /\ generation = 1
    /\ observedGeneration =
        IF Fault = "MissingE2ClosureBinding" THEN 0 ELSE 1
    /\ allowedDomains = {"A"}
    /\ selectedDomain = NoDomain
    /\ aggregateVisits = 0
    /\ candidateVisits = 0
    /\ reconcileVisits = 0
    /\ ancestorVisits = 0
    /\ leafVersion = 1
    /\ summaryVersion = 1
    /\ reallowLag = 0
    /\ catchUpCredit = 0
    /\ serviceA = 0
    /\ serviceB = 0
    /\ deniedService = 0
    /\ sourceContribution = TRUE
    /\ destinationContribution = FALSE
    /\ currentDomain = "A"
    /\ stopRequest = FALSE
    /\ stopObserved = FALSE
    /\ accepting = TRUE
    /\ visible = TRUE
    /\ readers = 1
    /\ refs = 1
    /\ rcuGrace = FALSE
    /\ freed = FALSE

ObserveDescriptor ==
    /\ phase = "Ready"
    /\ phase' = "Observed"
    /\ observedGeneration' = generation
    /\ reconcileVisits' = 0
    /\ UNCHANGED <<generation, allowedDomains, selectedDomain,
                    aggregateVisits, candidateVisits, ancestorVisits,
                    leafVersion, summaryVersion, reallowLag, catchUpCredit,
                    serviceA, serviceB, deniedService, sourceContribution,
                    destinationContribution, currentDomain, stopRequest,
                    stopObserved, accepting, visible, readers, refs,
                    rcuGrace, freed>>

PickAllowed ==
    /\ phase = "Observed"
    /\ phase' = "Picked"
    /\ selectedDomain' =
        IF Fault = "MissingAllowedPickProgress" THEN NoDomain
        ELSE IF Fault = "DeniedDomainSelected" THEN "B"
        ELSE "A"
    /\ aggregateVisits' =
        IF Fault = "AggregateVisitOverflow" THEN 128 ELSE 127
    /\ candidateVisits' =
        IF Fault = "CandidateVisitOverflow" THEN 128 ELSE 127
    /\ ancestorVisits' =
        IF Fault = "LeafAncestorOverflow" THEN 7 ELSE 6
    /\ leafVersion' = 2
    /\ summaryVersion' =
        IF Fault = "StaleTreeVersion" THEN 1 ELSE 2
    /\ UNCHANGED <<generation, observedGeneration, allowedDomains,
                    reconcileVisits, reallowLag, catchUpCredit, serviceA,
                    serviceB, deniedService, sourceContribution,
                    destinationContribution, currentDomain, stopRequest,
                    stopObserved, accepting, visible, readers, refs,
                    rcuGrace, freed>>

AccountService ==
    /\ phase = "Picked"
    /\ phase' = "Accounted"
    /\ serviceA' = IF selectedDomain = "A" THEN 1 ELSE 0
    /\ serviceB' = IF selectedDomain = "B" THEN 1 ELSE 0
    /\ deniedService' =
        IF Fault = "DeniedDomainService" THEN 1 ELSE 0
    /\ UNCHANGED <<generation, observedGeneration, allowedDomains,
                    selectedDomain, aggregateVisits, candidateVisits,
                    reconcileVisits, ancestorVisits, leafVersion,
                    summaryVersion, reallowLag, catchUpCredit,
                    sourceContribution, destinationContribution,
                    currentDomain, stopRequest, stopObserved, accepting,
                    visible, readers, refs, rcuGrace, freed>>

PublishRevoke ==
    /\ phase = "Accounted"
    /\ phase' = "Revoked"
    /\ generation' = 2
    /\ allowedDomains' = {}
    /\ selectedDomain' = NoDomain
    /\ UNCHANGED <<observedGeneration, aggregateVisits, candidateVisits,
                    reconcileVisits, ancestorVisits, leafVersion,
                    summaryVersion, reallowLag, catchUpCredit, serviceA,
                    serviceB, deniedService, sourceContribution,
                    destinationContribution, currentDomain, stopRequest,
                    stopObserved, accepting, visible, readers, refs,
                    rcuGrace, freed>>

ReconcileRevocation ==
    /\ phase = "Revoked"
    /\ phase' = "Reconciled"
    /\ observedGeneration' = generation
    /\ reconcileVisits' =
        IF Fault = "ReconcileOverflow" THEN 65 ELSE 64
    /\ UNCHANGED <<generation, allowedDomains, selectedDomain,
                    aggregateVisits, candidateVisits, ancestorVisits,
                    leafVersion, summaryVersion, reallowLag, catchUpCredit,
                    serviceA, serviceB, deniedService, sourceContribution,
                    destinationContribution, currentDomain, stopRequest,
                    stopObserved, accepting, visible, readers, refs,
                    rcuGrace, freed>>

PublishReallow ==
    /\ phase = "Reconciled"
    /\ phase' = "Reallowed"
    /\ generation' = 3
    /\ observedGeneration' = 3
    /\ allowedDomains' = {"B"}
    /\ reallowLag' = IF Fault = "ReallowNegativeLag" THEN -1 ELSE 0
    /\ catchUpCredit' =
        IF Fault = "ReallowCatchUpCredit" THEN 1 ELSE 0
    /\ currentDomain' = "B"
    /\ UNCHANGED <<selectedDomain, aggregateVisits, candidateVisits,
                    reconcileVisits, ancestorVisits, leafVersion,
                    summaryVersion, serviceA, serviceB, deniedService,
                    sourceContribution, destinationContribution, stopRequest,
                    stopObserved, accepting, visible, readers, refs,
                    rcuGrace, freed>>

RemoveSource ==
    /\ phase = "Reallowed"
    /\ phase' = "Neutral"
    /\ sourceContribution' =
        IF Fault = "MigrationDoubleContribution" THEN TRUE ELSE FALSE
    /\ destinationContribution' =
        IF Fault = "MigrationDoubleContribution" THEN TRUE ELSE FALSE
    /\ UNCHANGED <<generation, observedGeneration, allowedDomains,
                    selectedDomain, aggregateVisits, candidateVisits,
                    reconcileVisits, ancestorVisits, leafVersion,
                    summaryVersion, reallowLag, catchUpCredit, serviceA,
                    serviceB, deniedService, currentDomain, stopRequest,
                    stopObserved, accepting, visible, readers, refs,
                    rcuGrace, freed>>

AddDestination ==
    /\ phase = "Neutral"
    /\ phase' = "Migrated"
    /\ sourceContribution' = FALSE
    /\ destinationContribution' = TRUE
    /\ UNCHANGED <<generation, observedGeneration, allowedDomains,
                    selectedDomain, aggregateVisits, candidateVisits,
                    reconcileVisits, ancestorVisits, leafVersion,
                    summaryVersion, reallowLag, catchUpCredit, serviceA,
                    serviceB, deniedService, currentDomain, stopRequest,
                    stopObserved, accepting, visible, readers, refs,
                    rcuGrace, freed>>

RequestCurrentStop ==
    /\ phase = "Migrated"
    /\ phase' = "StopRequested"
    /\ generation' = 4
    /\ observedGeneration' = 4
    /\ allowedDomains' = {}
    /\ stopRequest' = TRUE
    /\ UNCHANGED <<selectedDomain, aggregateVisits, candidateVisits,
                    reconcileVisits, ancestorVisits, leafVersion,
                    summaryVersion, reallowLag, catchUpCredit, serviceA,
                    serviceB, deniedService, sourceContribution,
                    destinationContribution, currentDomain, stopObserved,
                    accepting, visible, readers, refs, rcuGrace, freed>>

ObserveCurrentStop ==
    /\ phase = "StopRequested"
    /\ phase' = "StopObserved"
    /\ currentDomain' =
        IF Fault = "MissingRevokedCurrentProgress" THEN currentDomain
        ELSE NoDomain
    /\ stopObserved' = (Fault # "MissingRevokedCurrentProgress")
    /\ destinationContribution' =
        IF Fault = "MissingRevokedCurrentProgress"
        THEN destinationContribution ELSE FALSE
    /\ UNCHANGED <<generation, observedGeneration, allowedDomains,
                    selectedDomain, aggregateVisits, candidateVisits,
                    reconcileVisits, ancestorVisits, leafVersion,
                    summaryVersion, reallowLag, catchUpCredit, serviceA,
                    serviceB, deniedService, sourceContribution, stopRequest,
                    accepting, visible, readers, refs, rcuGrace, freed>>

RemoveVisibility ==
    /\ phase = "StopObserved"
    /\ phase' = "Offline"
    /\ accepting' = (Fault = "OfflineKeepsAccepting")
    /\ visible' = (Fault = "OfflineKeepsVisibility")
    /\ UNCHANGED <<generation, observedGeneration, allowedDomains,
                    selectedDomain, aggregateVisits, candidateVisits,
                    reconcileVisits, ancestorVisits, leafVersion,
                    summaryVersion, reallowLag, catchUpCredit, serviceA,
                    serviceB, deniedService, sourceContribution,
                    destinationContribution, currentDomain, stopRequest,
                    stopObserved, readers, refs, rcuGrace, freed>>

DrainReferences ==
    /\ phase = "Offline"
    /\ phase' = "Drained"
    /\ readers' =
        IF Fault = "MissingOfflineDrainProgress" THEN readers ELSE 0
    /\ refs' =
        IF Fault = "MissingOfflineDrainProgress" THEN refs ELSE 0
    /\ rcuGrace' = (Fault # "MissingOfflineDrainProgress")
    /\ UNCHANGED <<generation, observedGeneration, allowedDomains,
                    selectedDomain, aggregateVisits, candidateVisits,
                    reconcileVisits, ancestorVisits, leafVersion,
                    summaryVersion, reallowLag, catchUpCredit, serviceA,
                    serviceB, deniedService, sourceContribution,
                    destinationContribution, currentDomain, stopRequest,
                    stopObserved, accepting, visible, freed>>

FreeState ==
    /\ phase = "Drained"
    /\ phase' = "Done"
    /\ freed' = (Fault # "MissingOfflineDrainProgress")
    /\ UNCHANGED <<generation, observedGeneration, allowedDomains,
                    selectedDomain, aggregateVisits, candidateVisits,
                    reconcileVisits, ancestorVisits, leafVersion,
                    summaryVersion, reallowLag, catchUpCredit, serviceA,
                    serviceB, deniedService, sourceContribution,
                    destinationContribution, currentDomain, stopRequest,
                    stopObserved, accepting, visible, readers, refs,
                    rcuGrace>>

Next ==
    \/ ObserveDescriptor
    \/ PickAllowed
    \/ AccountService
    \/ PublishRevoke
    \/ ReconcileRevocation
    \/ PublishReallow
    \/ RemoveSource
    \/ AddDestination
    \/ RequestCurrentStop
    \/ ObserveCurrentStop
    \/ RemoveVisibility
    \/ DrainReferences
    \/ FreeState

Spec ==
    /\ Init
    /\ [][Next]_vars
    /\ WF_vars(ObserveDescriptor)
    /\ WF_vars(PickAllowed)
    /\ WF_vars(AccountService)
    /\ WF_vars(PublishRevoke)
    /\ WF_vars(ReconcileRevocation)
    /\ WF_vars(PublishReallow)
    /\ WF_vars(RemoveSource)
    /\ WF_vars(AddDestination)
    /\ WF_vars(RequestCurrentStop)
    /\ WF_vars(ObserveCurrentStop)
    /\ WF_vars(RemoveVisibility)
    /\ WF_vars(DrainReferences)
    /\ WF_vars(FreeState)

TypeOK ==
    /\ phase \in Phases
    /\ generation \in 1..4
    /\ observedGeneration \in 0..4
    /\ allowedDomains \subseteq Domains
    /\ selectedDomain \in Domains \union {NoDomain}
    /\ aggregateVisits \in 0..128
    /\ candidateVisits \in 0..128
    /\ reconcileVisits \in 0..65
    /\ ancestorVisits \in 0..7
    /\ leafVersion \in 1..2
    /\ summaryVersion \in 1..2
    /\ reallowLag \in -1..0
    /\ catchUpCredit \in 0..1
    /\ serviceA \in 0..1
    /\ serviceB \in 0..1
    /\ deniedService \in 0..1
    /\ sourceContribution \in BOOLEAN
    /\ destinationContribution \in BOOLEAN
    /\ currentDomain \in Domains \union {NoDomain}
    /\ stopRequest \in BOOLEAN
    /\ stopObserved \in BOOLEAN
    /\ accepting \in BOOLEAN
    /\ visible \in BOOLEAN
    /\ readers \in 0..1
    /\ refs \in 0..1
    /\ rcuGrace \in BOOLEAN
    /\ freed \in BOOLEAN

EvidenceSafety ==
    /\ Fault \notin SafetyFaults
    /\ observedGeneration <= generation
    /\ aggregateVisits <= 127
    /\ candidateVisits <= 127
    /\ aggregateVisits + candidateVisits <= 254
    /\ reconcileVisits <= 64
    /\ ancestorVisits <= 6
    /\ leafVersion = summaryVersion
    /\ (selectedDomain = NoDomain \/ selectedDomain \in allowedDomains)
    /\ deniedService = 0
    /\ reallowLag >= 0
    /\ catchUpCredit = 0
    /\ ~(sourceContribution /\ destinationContribution)
    /\ (phase = "Neutral" => ~sourceContribution /\ ~destinationContribution)
    /\ (phase \in {"Offline", "Drained", "Done"} =>
          ~accepting /\ ~visible)
    /\ (stopObserved => stopRequest)
    /\ (freed => readers = 0 /\ refs = 0 /\ rcuGrace)

AllowedPickProgress ==
    [](phase = "Observed" /\ "A" \in allowedDomains
       => <>(selectedDomain = "A"))

RevokedCurrentProgress ==
    [](phase = "StopRequested" /\ currentDomain # NoDomain
       => <>(currentDomain = NoDomain /\ stopObserved))

OfflineDrainProgress ==
    [](phase = "Offline"
       => <>(readers = 0 /\ refs = 0 /\ rcuGrace))

=============================================================================
