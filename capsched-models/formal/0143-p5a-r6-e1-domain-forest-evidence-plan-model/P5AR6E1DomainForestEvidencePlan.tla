---------- MODULE P5AR6E1DomainForestEvidencePlan ----------
EXTENDS Naturals, FiniteSets

CONSTANT Fault

Domains == {"A", "B"}
NoDomain == "None"
Phases == {
    "Ready", "Mutated", "Picked", "Neutral", "Placed", "Revoked",
    "Stopped", "Offline", "Drained", "Done"
}

SafetyFaults == {
    "MissingR6InputBinding",
    "ImmutableSelectorRestored",
    "UnboundedAdmission",
    "WrongUniqueNodeBound",
    "MissingTwoPhaseQuery",
    "WrongQueryVisitBound",
    "LogarithmicQueryClaim",
    "AggregateIncludesDenied",
    "DeniedDomainSelected",
    "StaleTopSummary",
    "PublicationWalks",
    "UnboundedMaskReconcile",
    "ReallowNegativeLag",
    "VariableDomainWeight",
    "FlatCfsEquivalenceClaim",
    "CgroupAuthority",
    "MixedDomainSubtree",
    "RootLeasedTask",
    "AutogroupSupported",
    "MissingFinalTaskCheck",
    "MissingDescriptorAcquire",
    "MutableSlotMapping",
    "LateAllocation",
    "Slot65Accepted",
    "PrivateEnvelopeExceeded",
    "OrdinaryHotObjectGrowth",
    "WrongE2Scope",
    "E2AddsBehavior",
    "MissingDualArchLayout",
    "ExistingProbeChanged",
    "EnqueueWithoutReceipt",
    "MigrationDoubleContribution",
    "DestinationNotRechecked",
    "ForkBindingMutable",
    "ExecGenerationLate",
    "CurrentConflatedWithPicker",
    "OfflineKeepsAccepting",
    "SleepableDrainUnderRqLock",
    "MissingRcuGrace",
    "GenerationWrapReuse",
    "MissingE3Gate",
    "MissingE4Gate",
    "X86BeforeArm64",
    "RuntimeClaim",
    "ProtectionClaim",
    "PerformanceClaim",
    "CostClaim",
    "DeploymentClaim",
    "MultiClusterClaim",
    "DatacenterClaim"
}

VARIABLES phase, generation, receiptGeneration, allowedDomains,
          selectedDomain, leafVersion, summaryVersion, aggregateVisits,
          candidateVisits, reconcileVisits, sourceContribution,
          destinationContribution, currentDomain, accepting, refs,
          rcuGrace, freed

vars ==
    <<phase, generation, receiptGeneration, allowedDomains, selectedDomain,
      leafVersion, summaryVersion, aggregateVisits, candidateVisits,
      reconcileVisits, sourceContribution, destinationContribution,
      currentDomain, accepting, refs, rcuGrace, freed>>

Init ==
    /\ phase = "Ready"
    /\ generation = 1
    /\ receiptGeneration =
        IF Fault = "MissingDescriptorAcquire" THEN 0 ELSE 1
    /\ allowedDomains = {"A"}
    /\ selectedDomain = NoDomain
    /\ leafVersion = 1
    /\ summaryVersion = 1
    /\ aggregateVisits = 0
    /\ candidateVisits = 0
    /\ reconcileVisits = 0
    /\ sourceContribution = TRUE
    /\ destinationContribution = FALSE
    /\ currentDomain = "A"
    /\ accepting = TRUE
    /\ refs = 1
    /\ rcuGrace = FALSE
    /\ freed = FALSE

MutateLeaf ==
    /\ phase = "Ready"
    /\ phase' = "Mutated"
    /\ leafVersion' = 2
    /\ summaryVersion' = IF Fault = "StaleTopSummary" THEN 1 ELSE 2
    /\ UNCHANGED <<generation, receiptGeneration, allowedDomains,
                    selectedDomain, aggregateVisits, candidateVisits,
                    reconcileVisits, sourceContribution,
                    destinationContribution, currentDomain, accepting,
                    refs, rcuGrace, freed>>

PickAllowed ==
    /\ phase = "Mutated"
    /\ phase' = "Picked"
    /\ selectedDomain' =
        IF Fault = "DeniedDomainSelected" THEN "B"
        ELSE IF Fault = "MissingAllowedProgress" THEN NoDomain
        ELSE "A"
    /\ aggregateVisits' =
        IF Fault = "WrongQueryVisitBound" THEN 128 ELSE 127
    /\ candidateVisits' =
        IF Fault = "WrongQueryVisitBound" THEN 128 ELSE 127
    /\ reconcileVisits' =
        IF Fault = "UnboundedMaskReconcile" THEN 65 ELSE 64
    /\ UNCHANGED <<generation, receiptGeneration, allowedDomains,
                    leafVersion, summaryVersion, sourceContribution,
                    destinationContribution, currentDomain, accepting,
                    refs, rcuGrace, freed>>

RemoveSource ==
    /\ phase = "Picked"
    /\ phase' = "Neutral"
    /\ sourceContribution' =
        IF Fault = "MigrationDoubleContribution" THEN TRUE ELSE FALSE
    /\ destinationContribution' =
        IF Fault = "MigrationDoubleContribution" THEN TRUE ELSE FALSE
    /\ UNCHANGED <<generation, receiptGeneration, allowedDomains,
                    selectedDomain, leafVersion, summaryVersion,
                    aggregateVisits, candidateVisits, reconcileVisits,
                    currentDomain, accepting, refs, rcuGrace, freed>>

AddDestination ==
    /\ phase = "Neutral"
    /\ phase' = "Placed"
    /\ sourceContribution' = FALSE
    /\ destinationContribution' = TRUE
    /\ UNCHANGED <<generation, receiptGeneration, allowedDomains,
                    selectedDomain, leafVersion, summaryVersion,
                    aggregateVisits, candidateVisits, reconcileVisits,
                    currentDomain, accepting, refs, rcuGrace, freed>>

PublishRevoke ==
    /\ phase = "Placed"
    /\ phase' = "Revoked"
    /\ generation' = 2
    /\ receiptGeneration' =
        IF Fault = "MissingDescriptorAcquire" THEN 1 ELSE 2
    /\ allowedDomains' = {}
    /\ selectedDomain' = NoDomain
    /\ UNCHANGED <<leafVersion, summaryVersion, aggregateVisits,
                    candidateVisits, reconcileVisits, sourceContribution,
                    destinationContribution, currentDomain, accepting,
                    refs, rcuGrace, freed>>

ObserveCurrentStop ==
    /\ phase = "Revoked"
    /\ phase' = "Stopped"
    /\ currentDomain' =
        IF Fault = "MissingCurrentStop" THEN currentDomain ELSE NoDomain
    /\ destinationContribution' =
        IF Fault = "MissingCurrentStop" THEN destinationContribution
        ELSE FALSE
    /\ UNCHANGED <<generation, receiptGeneration, allowedDomains,
                    selectedDomain, leafVersion, summaryVersion,
                    aggregateVisits, candidateVisits, reconcileVisits,
                    sourceContribution, accepting, refs, rcuGrace, freed>>

RemoveVisibility ==
    /\ phase = "Stopped"
    /\ phase' = "Offline"
    /\ accepting' = (Fault = "OfflineKeepsAccepting")
    /\ UNCHANGED <<generation, receiptGeneration, allowedDomains,
                    selectedDomain, leafVersion, summaryVersion,
                    aggregateVisits, candidateVisits, reconcileVisits,
                    sourceContribution, destinationContribution,
                    currentDomain, refs, rcuGrace, freed>>

DrainReferences ==
    /\ phase = "Offline"
    /\ phase' = "Drained"
    /\ refs' = 0
    /\ rcuGrace' = (Fault # "MissingRcuGrace")
    /\ UNCHANGED <<generation, receiptGeneration, allowedDomains,
                    selectedDomain, leafVersion, summaryVersion,
                    aggregateVisits, candidateVisits, reconcileVisits,
                    sourceContribution, destinationContribution,
                    currentDomain, accepting, freed>>

FreeState ==
    /\ phase = "Drained"
    /\ phase' = "Done"
    /\ freed' = TRUE
    /\ UNCHANGED <<generation, receiptGeneration, allowedDomains,
                    selectedDomain, leafVersion, summaryVersion,
                    aggregateVisits, candidateVisits, reconcileVisits,
                    sourceContribution, destinationContribution,
                    currentDomain, accepting, refs, rcuGrace>>

Next ==
    \/ MutateLeaf
    \/ PickAllowed
    \/ RemoveSource
    \/ AddDestination
    \/ PublishRevoke
    \/ ObserveCurrentStop
    \/ RemoveVisibility
    \/ DrainReferences
    \/ FreeState

Spec ==
    /\ Init
    /\ [][Next]_vars
    /\ WF_vars(MutateLeaf)
    /\ WF_vars(PickAllowed)
    /\ WF_vars(RemoveSource)
    /\ WF_vars(AddDestination)
    /\ WF_vars(PublishRevoke)
    /\ WF_vars(ObserveCurrentStop)
    /\ WF_vars(RemoveVisibility)
    /\ WF_vars(DrainReferences)
    /\ WF_vars(FreeState)

TypeOK ==
    /\ phase \in Phases
    /\ generation \in 1..2
    /\ receiptGeneration \in 0..2
    /\ allowedDomains \subseteq Domains
    /\ selectedDomain \in Domains \union {NoDomain}
    /\ leafVersion \in 1..2
    /\ summaryVersion \in 1..2
    /\ aggregateVisits \in 0..128
    /\ candidateVisits \in 0..128
    /\ reconcileVisits \in 0..65
    /\ sourceContribution \in BOOLEAN
    /\ destinationContribution \in BOOLEAN
    /\ currentDomain \in Domains \union {NoDomain}
    /\ accepting \in BOOLEAN
    /\ refs \in 0..1
    /\ rcuGrace \in BOOLEAN
    /\ freed \in BOOLEAN

ArchitectureSafety ==
    /\ Fault \notin SafetyFaults
    /\ receiptGeneration = generation
    /\ leafVersion = summaryVersion
    /\ aggregateVisits <= 127
    /\ candidateVisits <= 127
    /\ aggregateVisits + candidateVisits <= 254
    /\ reconcileVisits <= 64
    /\ (selectedDomain = NoDomain \/ selectedDomain \in allowedDomains)
    /\ ~(sourceContribution /\ destinationContribution)
    /\ (phase \in {"Offline", "Drained", "Done"} => ~accepting)
    /\ (freed => refs = 0 /\ rcuGrace)

AllowedProgress ==
    [](phase = "Mutated" /\ "A" \in allowedDomains
       => <>(selectedDomain = "A"))

RevokedCurrentProgress ==
    [](phase = "Revoked" /\ currentDomain # NoDomain
       => <>(currentDomain = NoDomain))

=============================================================================
