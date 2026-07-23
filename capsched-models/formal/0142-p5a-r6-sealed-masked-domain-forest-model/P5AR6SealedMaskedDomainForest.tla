---------- MODULE P5AR6SealedMaskedDomainForest ----------
EXTENDS Naturals, FiniteSets

CONSTANT Fault

Domains == {"A", "B"}
NoDomain == "None"

VARIABLES phase, publishedGeneration, receiptGeneration, receiptSealed,
          slotMapFrozen, allowedDomains, runnableDomains, queueVersion,
          summaryVersion, selectedDomain, currentDomain, currentStopObserved,
          publicationWork, topDepth, cgroupAuthority, taskSlotVerified,
          selectorVisitBound, allocationReady, flatTreeFallback,
          r6SourceApproved, productionClaim

vars ==
    <<phase, publishedGeneration, receiptGeneration, receiptSealed,
      slotMapFrozen, allowedDomains, runnableDomains, queueVersion,
      summaryVersion, selectedDomain, currentDomain, currentStopObserved,
      publicationWork, topDepth, cgroupAuthority, taskSlotVerified,
      selectorVisitBound, allocationReady, flatTreeFallback,
      r6SourceApproved, productionClaim>>

Init ==
    /\ phase = "Ready"
    /\ publishedGeneration = 1
    /\ receiptGeneration = IF Fault = "GenerationMismatch" THEN 0 ELSE 1
    /\ receiptSealed = (Fault # "UnsealedReceipt")
    /\ slotMapFrozen = (Fault # "MutableSlotMap")
    /\ allowedDomains = {"A"}
    /\ runnableDomains = Domains
    /\ queueVersion = 1
    /\ summaryVersion = 1
    /\ selectedDomain = NoDomain
    /\ currentDomain = "A"
    /\ currentStopObserved = FALSE
    /\ publicationWork = IF Fault = "VariablePublicationWork" THEN 64 ELSE 1
    /\ topDepth = IF Fault = "UnboundedTopSelector" THEN 65 ELSE 6
    /\ cgroupAuthority = (Fault = "CgroupAuthority")
    /\ taskSlotVerified = (Fault # "UnverifiedTaskSlot")
    /\ selectorVisitBound =
        IF Fault = "UnboundedTopSelector" THEN 129 ELSE 127
    /\ allocationReady = (Fault # "LateAllocation")
    /\ flatTreeFallback = (Fault = "FlatTreeFallback")
    /\ r6SourceApproved = (Fault = "PrematureR6Source")
    /\ productionClaim = (Fault = "ProductionOverclaim")

DynamicMutation ==
    /\ phase = "Ready"
    /\ phase' = "Mutated"
    /\ queueVersion' = 2
    /\ summaryVersion' = IF Fault = "StaleSummary" THEN 1 ELSE 2
    /\ UNCHANGED <<publishedGeneration, receiptGeneration, receiptSealed,
                    slotMapFrozen, allowedDomains, runnableDomains,
                    selectedDomain, currentDomain, currentStopObserved,
                    publicationWork, topDepth, cgroupAuthority,
                    taskSlotVerified, selectorVisitBound, allocationReady,
                    flatTreeFallback,
                    r6SourceApproved, productionClaim>>

PickAllowed ==
    /\ phase = "Mutated"
    /\ phase' = "Picked"
    /\ selectedDomain' =
        IF Fault = "DeniedBranchVisible" THEN "B"
        ELSE IF Fault = "MissingAllowedProgress" THEN NoDomain
        ELSE "A"
    /\ UNCHANGED <<publishedGeneration, receiptGeneration, receiptSealed,
                    slotMapFrozen, allowedDomains, runnableDomains,
                    queueVersion, summaryVersion, currentDomain,
                    currentStopObserved, publicationWork, topDepth,
                    cgroupAuthority, taskSlotVerified, selectorVisitBound,
                    allocationReady,
                    flatTreeFallback, r6SourceApproved, productionClaim>>

PublishRevoke ==
    /\ phase = "Picked"
    /\ phase' = "Revoked"
    /\ publishedGeneration' = 2
    /\ receiptGeneration' = IF Fault = "GenerationMismatch" THEN 1 ELSE 2
    /\ allowedDomains' = {}
    /\ selectedDomain' = NoDomain
    /\ UNCHANGED <<receiptSealed, slotMapFrozen, runnableDomains,
                    queueVersion, summaryVersion, currentDomain,
                    currentStopObserved, publicationWork, topDepth,
                    cgroupAuthority, taskSlotVerified, selectorVisitBound,
                    allocationReady,
                    flatTreeFallback, r6SourceApproved, productionClaim>>

ObserveCurrentStop ==
    /\ phase = "Revoked"
    /\ phase' = "Done"
    /\ currentDomain' =
        IF Fault = "MissingCurrentStop" THEN currentDomain ELSE NoDomain
    /\ currentStopObserved' = (Fault # "MissingCurrentStop")
    /\ UNCHANGED <<publishedGeneration, receiptGeneration, receiptSealed,
                    slotMapFrozen, allowedDomains, runnableDomains,
                    queueVersion, summaryVersion, selectedDomain,
                    publicationWork, topDepth, cgroupAuthority,
                    taskSlotVerified, selectorVisitBound, allocationReady,
                    flatTreeFallback,
                    r6SourceApproved, productionClaim>>

Next ==
    \/ DynamicMutation
    \/ PickAllowed
    \/ PublishRevoke
    \/ ObserveCurrentStop

Spec ==
    /\ Init
    /\ [][Next]_vars
    /\ WF_vars(DynamicMutation)
    /\ WF_vars(PickAllowed)
    /\ WF_vars(PublishRevoke)
    /\ WF_vars(ObserveCurrentStop)

TypeOK ==
    /\ phase \in {"Ready", "Mutated", "Picked", "Revoked", "Done"}
    /\ publishedGeneration \in 1..2
    /\ receiptGeneration \in 0..2
    /\ receiptSealed \in BOOLEAN
    /\ slotMapFrozen \in BOOLEAN
    /\ allowedDomains \subseteq Domains
    /\ runnableDomains \subseteq Domains
    /\ queueVersion \in 1..2
    /\ summaryVersion \in 1..2
    /\ selectedDomain \in Domains \union {NoDomain}
    /\ currentDomain \in Domains \union {NoDomain}
    /\ currentStopObserved \in BOOLEAN
    /\ publicationWork \in {1, 64}
    /\ topDepth \in {6, 65}
    /\ cgroupAuthority \in BOOLEAN
    /\ taskSlotVerified \in BOOLEAN
    /\ selectorVisitBound \in {127, 129}
    /\ allocationReady \in BOOLEAN
    /\ flatTreeFallback \in BOOLEAN
    /\ r6SourceApproved \in BOOLEAN
    /\ productionClaim \in BOOLEAN

ArchitectureSafety ==
    /\ receiptSealed
    /\ receiptGeneration = publishedGeneration
    /\ slotMapFrozen
    /\ publicationWork = 1
    /\ topDepth = 6
    /\ selectorVisitBound = 127
    /\ ~cgroupAuthority
    /\ taskSlotVerified
    /\ allocationReady
    /\ ~flatTreeFallback
    /\ queueVersion = summaryVersion
    /\ (selectedDomain = NoDomain \/ selectedDomain \in allowedDomains)
    /\ ~r6SourceApproved
    /\ ~productionClaim

AllowedProgress ==
    [](phase = "Mutated" /\ "A" \in runnableDomains /\ "A" \in allowedDomains
       => <>(selectedDomain = "A"))

RevokedCurrentProgress ==
    [](phase = "Revoked" /\ currentDomain # NoDomain
       => <>(currentDomain = NoDomain))

=============================================================================
