---------- MODULE P5AROrdinaryCfsPatchPlan ----------
EXTENDS Naturals

VARIABLES
    phase,
    priorGatesComplete,
    ordinaryCfsOnlyScope,
    fileBoundary,
    preSettlePickerIntegration,
    hierarchySettlementRequired,
    crossPathExclusionRequired,
    boundedAttemptCarrier,
    negativeValidationRequired,
    buildObjectQemuRequired,
    sourceDriftRequired,
    securityReviewRequired,
    behaviorPatchDraftAllowed,
    runtimeDenialApproved,
    cfsDenyRepickApproved,
    publicAbi,
    monitorCall,
    hotLayoutWithoutEvidence,
    protectionClaim,
    costClaim

vars == <<phase, priorGatesComplete, ordinaryCfsOnlyScope, fileBoundary,
          preSettlePickerIntegration, hierarchySettlementRequired,
          crossPathExclusionRequired, boundedAttemptCarrier,
          negativeValidationRequired, buildObjectQemuRequired,
          sourceDriftRequired, securityReviewRequired,
          behaviorPatchDraftAllowed, runtimeDenialApproved,
          cfsDenyRepickApproved, publicAbi, monitorCall,
          hotLayoutWithoutEvidence, protectionClaim, costClaim>>

Base ==
    [ phase |-> "Start",
      priorGatesComplete |-> FALSE,
      ordinaryCfsOnlyScope |-> FALSE,
      fileBoundary |-> FALSE,
      preSettlePickerIntegration |-> FALSE,
      hierarchySettlementRequired |-> FALSE,
      crossPathExclusionRequired |-> FALSE,
      boundedAttemptCarrier |-> FALSE,
      negativeValidationRequired |-> FALSE,
      buildObjectQemuRequired |-> FALSE,
      sourceDriftRequired |-> FALSE,
      securityReviewRequired |-> FALSE,
      behaviorPatchDraftAllowed |-> FALSE,
      runtimeDenialApproved |-> FALSE,
      cfsDenyRepickApproved |-> FALSE,
      publicAbi |-> FALSE,
      monitorCall |-> FALSE,
      hotLayoutWithoutEvidence |-> FALSE,
      protectionClaim |-> FALSE,
      costClaim |-> FALSE ]

SetState(s) ==
    /\ phase = s.phase
    /\ priorGatesComplete = s.priorGatesComplete
    /\ ordinaryCfsOnlyScope = s.ordinaryCfsOnlyScope
    /\ fileBoundary = s.fileBoundary
    /\ preSettlePickerIntegration = s.preSettlePickerIntegration
    /\ hierarchySettlementRequired = s.hierarchySettlementRequired
    /\ crossPathExclusionRequired = s.crossPathExclusionRequired
    /\ boundedAttemptCarrier = s.boundedAttemptCarrier
    /\ negativeValidationRequired = s.negativeValidationRequired
    /\ buildObjectQemuRequired = s.buildObjectQemuRequired
    /\ sourceDriftRequired = s.sourceDriftRequired
    /\ securityReviewRequired = s.securityReviewRequired
    /\ behaviorPatchDraftAllowed = s.behaviorPatchDraftAllowed
    /\ runtimeDenialApproved = s.runtimeDenialApproved
    /\ cfsDenyRepickApproved = s.cfsDenyRepickApproved
    /\ publicAbi = s.publicAbi
    /\ monitorCall = s.monitorCall
    /\ hotLayoutWithoutEvidence = s.hotLayoutWithoutEvidence
    /\ protectionClaim = s.protectionClaim
    /\ costClaim = s.costClaim

Init == SetState(Base)

RecordPriorAndScope ==
    /\ phase = "Start"
    /\ priorGatesComplete' = TRUE
    /\ ordinaryCfsOnlyScope' = TRUE
    /\ fileBoundary' = TRUE
    /\ phase' = "PriorAndScopeRecorded"
    /\ UNCHANGED <<preSettlePickerIntegration, hierarchySettlementRequired,
                    crossPathExclusionRequired, boundedAttemptCarrier,
                    negativeValidationRequired, buildObjectQemuRequired,
                    sourceDriftRequired, securityReviewRequired,
                    behaviorPatchDraftAllowed, runtimeDenialApproved,
                    cfsDenyRepickApproved, publicAbi, monitorCall,
                    hotLayoutWithoutEvidence, protectionClaim, costClaim>>

RecordDesignRequirements ==
    /\ phase = "PriorAndScopeRecorded"
    /\ preSettlePickerIntegration' = TRUE
    /\ hierarchySettlementRequired' = TRUE
    /\ crossPathExclusionRequired' = TRUE
    /\ boundedAttemptCarrier' = TRUE
    /\ negativeValidationRequired' = TRUE
    /\ phase' = "DesignRequirementsRecorded"
    /\ UNCHANGED <<priorGatesComplete, ordinaryCfsOnlyScope, fileBoundary,
                    buildObjectQemuRequired, sourceDriftRequired,
                    securityReviewRequired, behaviorPatchDraftAllowed,
                    runtimeDenialApproved, cfsDenyRepickApproved, publicAbi,
                    monitorCall, hotLayoutWithoutEvidence, protectionClaim,
                    costClaim>>

RecordAcceptanceValidation ==
    /\ phase = "DesignRequirementsRecorded"
    /\ buildObjectQemuRequired' = TRUE
    /\ sourceDriftRequired' = TRUE
    /\ securityReviewRequired' = TRUE
    /\ phase' = "AcceptanceValidationRecorded"
    /\ UNCHANGED <<priorGatesComplete, ordinaryCfsOnlyScope, fileBoundary,
                    preSettlePickerIntegration, hierarchySettlementRequired,
                    crossPathExclusionRequired, boundedAttemptCarrier,
                    negativeValidationRequired, behaviorPatchDraftAllowed,
                    runtimeDenialApproved, cfsDenyRepickApproved, publicAbi,
                    monitorCall, hotLayoutWithoutEvidence, protectionClaim,
                    costClaim>>

AllowPatchDraft ==
    /\ phase = "AcceptanceValidationRecorded"
    /\ behaviorPatchDraftAllowed' = TRUE
    /\ phase' = "PatchDraftReady"
    /\ UNCHANGED <<priorGatesComplete, ordinaryCfsOnlyScope, fileBoundary,
                    preSettlePickerIntegration, hierarchySettlementRequired,
                    crossPathExclusionRequired, boundedAttemptCarrier,
                    negativeValidationRequired, buildObjectQemuRequired,
                    sourceDriftRequired, securityReviewRequired,
                    runtimeDenialApproved, cfsDenyRepickApproved, publicAbi,
                    monitorCall, hotLayoutWithoutEvidence, protectionClaim,
                    costClaim>>

StutterDone ==
    /\ phase = "PatchDraftReady"
    /\ UNCHANGED vars

Next ==
    \/ RecordPriorAndScope
    \/ RecordDesignRequirements
    \/ RecordAcceptanceValidation
    \/ AllowPatchDraft
    \/ StutterDone

SafeSpec == Init /\ [][Next]_vars

UnsafeMissingPriorGatesSpec ==
    /\ SetState([Base EXCEPT !.phase = "PatchDraftReady",
                             !.behaviorPatchDraftAllowed = TRUE,
                             !.ordinaryCfsOnlyScope = TRUE,
                             !.fileBoundary = TRUE,
                             !.preSettlePickerIntegration = TRUE,
                             !.hierarchySettlementRequired = TRUE,
                             !.crossPathExclusionRequired = TRUE,
                             !.boundedAttemptCarrier = TRUE,
                             !.negativeValidationRequired = TRUE,
                             !.buildObjectQemuRequired = TRUE,
                             !.sourceDriftRequired = TRUE,
                             !.securityReviewRequired = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingOrdinaryScopeSpec ==
    /\ SetState([Base EXCEPT !.phase = "PatchDraftReady",
                             !.behaviorPatchDraftAllowed = TRUE,
                             !.priorGatesComplete = TRUE,
                             !.fileBoundary = TRUE,
                             !.preSettlePickerIntegration = TRUE,
                             !.hierarchySettlementRequired = TRUE,
                             !.crossPathExclusionRequired = TRUE,
                             !.boundedAttemptCarrier = TRUE,
                             !.negativeValidationRequired = TRUE,
                             !.buildObjectQemuRequired = TRUE,
                             !.sourceDriftRequired = TRUE,
                             !.securityReviewRequired = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingFileBoundarySpec ==
    /\ SetState([Base EXCEPT !.phase = "PatchDraftReady",
                             !.behaviorPatchDraftAllowed = TRUE,
                             !.priorGatesComplete = TRUE,
                             !.ordinaryCfsOnlyScope = TRUE,
                             !.preSettlePickerIntegration = TRUE,
                             !.hierarchySettlementRequired = TRUE,
                             !.crossPathExclusionRequired = TRUE,
                             !.boundedAttemptCarrier = TRUE,
                             !.negativeValidationRequired = TRUE,
                             !.buildObjectQemuRequired = TRUE,
                             !.sourceDriftRequired = TRUE,
                             !.securityReviewRequired = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingPreSettleSpec ==
    /\ SetState([Base EXCEPT !.phase = "PatchDraftReady",
                             !.behaviorPatchDraftAllowed = TRUE,
                             !.priorGatesComplete = TRUE,
                             !.ordinaryCfsOnlyScope = TRUE,
                             !.fileBoundary = TRUE,
                             !.hierarchySettlementRequired = TRUE,
                             !.crossPathExclusionRequired = TRUE,
                             !.boundedAttemptCarrier = TRUE,
                             !.negativeValidationRequired = TRUE,
                             !.buildObjectQemuRequired = TRUE,
                             !.sourceDriftRequired = TRUE,
                             !.securityReviewRequired = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingHierarchySpec ==
    /\ SetState([Base EXCEPT !.phase = "PatchDraftReady",
                             !.behaviorPatchDraftAllowed = TRUE,
                             !.priorGatesComplete = TRUE,
                             !.ordinaryCfsOnlyScope = TRUE,
                             !.fileBoundary = TRUE,
                             !.preSettlePickerIntegration = TRUE,
                             !.crossPathExclusionRequired = TRUE,
                             !.boundedAttemptCarrier = TRUE,
                             !.negativeValidationRequired = TRUE,
                             !.buildObjectQemuRequired = TRUE,
                             !.sourceDriftRequired = TRUE,
                             !.securityReviewRequired = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingCrossPathSpec ==
    /\ SetState([Base EXCEPT !.phase = "PatchDraftReady",
                             !.behaviorPatchDraftAllowed = TRUE,
                             !.priorGatesComplete = TRUE,
                             !.ordinaryCfsOnlyScope = TRUE,
                             !.fileBoundary = TRUE,
                             !.preSettlePickerIntegration = TRUE,
                             !.hierarchySettlementRequired = TRUE,
                             !.boundedAttemptCarrier = TRUE,
                             !.negativeValidationRequired = TRUE,
                             !.buildObjectQemuRequired = TRUE,
                             !.sourceDriftRequired = TRUE,
                             !.securityReviewRequired = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingBoundedCarrierSpec ==
    /\ SetState([Base EXCEPT !.phase = "PatchDraftReady",
                             !.behaviorPatchDraftAllowed = TRUE,
                             !.priorGatesComplete = TRUE,
                             !.ordinaryCfsOnlyScope = TRUE,
                             !.fileBoundary = TRUE,
                             !.preSettlePickerIntegration = TRUE,
                             !.hierarchySettlementRequired = TRUE,
                             !.crossPathExclusionRequired = TRUE,
                             !.negativeValidationRequired = TRUE,
                             !.buildObjectQemuRequired = TRUE,
                             !.sourceDriftRequired = TRUE,
                             !.securityReviewRequired = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingNegativeValidationSpec ==
    /\ SetState([Base EXCEPT !.phase = "PatchDraftReady",
                             !.behaviorPatchDraftAllowed = TRUE,
                             !.priorGatesComplete = TRUE,
                             !.ordinaryCfsOnlyScope = TRUE,
                             !.fileBoundary = TRUE,
                             !.preSettlePickerIntegration = TRUE,
                             !.hierarchySettlementRequired = TRUE,
                             !.crossPathExclusionRequired = TRUE,
                             !.boundedAttemptCarrier = TRUE,
                             !.buildObjectQemuRequired = TRUE,
                             !.sourceDriftRequired = TRUE,
                             !.securityReviewRequired = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingBuildObjectQemuSpec ==
    /\ SetState([Base EXCEPT !.phase = "PatchDraftReady",
                             !.behaviorPatchDraftAllowed = TRUE,
                             !.priorGatesComplete = TRUE,
                             !.ordinaryCfsOnlyScope = TRUE,
                             !.fileBoundary = TRUE,
                             !.preSettlePickerIntegration = TRUE,
                             !.hierarchySettlementRequired = TRUE,
                             !.crossPathExclusionRequired = TRUE,
                             !.boundedAttemptCarrier = TRUE,
                             !.negativeValidationRequired = TRUE,
                             !.sourceDriftRequired = TRUE,
                             !.securityReviewRequired = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingDriftSpec ==
    /\ SetState([Base EXCEPT !.phase = "PatchDraftReady",
                             !.behaviorPatchDraftAllowed = TRUE,
                             !.priorGatesComplete = TRUE,
                             !.ordinaryCfsOnlyScope = TRUE,
                             !.fileBoundary = TRUE,
                             !.preSettlePickerIntegration = TRUE,
                             !.hierarchySettlementRequired = TRUE,
                             !.crossPathExclusionRequired = TRUE,
                             !.boundedAttemptCarrier = TRUE,
                             !.negativeValidationRequired = TRUE,
                             !.buildObjectQemuRequired = TRUE,
                             !.securityReviewRequired = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingSecuritySpec ==
    /\ SetState([Base EXCEPT !.phase = "PatchDraftReady",
                             !.behaviorPatchDraftAllowed = TRUE,
                             !.priorGatesComplete = TRUE,
                             !.ordinaryCfsOnlyScope = TRUE,
                             !.fileBoundary = TRUE,
                             !.preSettlePickerIntegration = TRUE,
                             !.hierarchySettlementRequired = TRUE,
                             !.crossPathExclusionRequired = TRUE,
                             !.boundedAttemptCarrier = TRUE,
                             !.negativeValidationRequired = TRUE,
                             !.buildObjectQemuRequired = TRUE,
                             !.sourceDriftRequired = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafePublicAbiSpec ==
    /\ SetState([Base EXCEPT !.phase = "PatchDraftReady",
                             !.priorGatesComplete = TRUE,
                             !.ordinaryCfsOnlyScope = TRUE,
                             !.fileBoundary = TRUE,
                             !.preSettlePickerIntegration = TRUE,
                             !.hierarchySettlementRequired = TRUE,
                             !.crossPathExclusionRequired = TRUE,
                             !.boundedAttemptCarrier = TRUE,
                             !.negativeValidationRequired = TRUE,
                             !.buildObjectQemuRequired = TRUE,
                             !.sourceDriftRequired = TRUE,
                             !.securityReviewRequired = TRUE,
                             !.behaviorPatchDraftAllowed = TRUE,
                             !.publicAbi = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafeMonitorCallSpec ==
    /\ SetState([Base EXCEPT !.phase = "PatchDraftReady",
                             !.priorGatesComplete = TRUE,
                             !.ordinaryCfsOnlyScope = TRUE,
                             !.fileBoundary = TRUE,
                             !.preSettlePickerIntegration = TRUE,
                             !.hierarchySettlementRequired = TRUE,
                             !.crossPathExclusionRequired = TRUE,
                             !.boundedAttemptCarrier = TRUE,
                             !.negativeValidationRequired = TRUE,
                             !.buildObjectQemuRequired = TRUE,
                             !.sourceDriftRequired = TRUE,
                             !.securityReviewRequired = TRUE,
                             !.behaviorPatchDraftAllowed = TRUE,
                             !.monitorCall = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafeHotLayoutSpec ==
    /\ SetState([Base EXCEPT !.phase = "PatchDraftReady",
                             !.priorGatesComplete = TRUE,
                             !.ordinaryCfsOnlyScope = TRUE,
                             !.fileBoundary = TRUE,
                             !.preSettlePickerIntegration = TRUE,
                             !.hierarchySettlementRequired = TRUE,
                             !.crossPathExclusionRequired = TRUE,
                             !.boundedAttemptCarrier = TRUE,
                             !.negativeValidationRequired = TRUE,
                             !.buildObjectQemuRequired = TRUE,
                             !.sourceDriftRequired = TRUE,
                             !.securityReviewRequired = TRUE,
                             !.behaviorPatchDraftAllowed = TRUE,
                             !.hotLayoutWithoutEvidence = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafeRuntimeApprovalSpec ==
    /\ SetState([Base EXCEPT !.phase = "PatchDraftReady",
                             !.priorGatesComplete = TRUE,
                             !.ordinaryCfsOnlyScope = TRUE,
                             !.fileBoundary = TRUE,
                             !.preSettlePickerIntegration = TRUE,
                             !.hierarchySettlementRequired = TRUE,
                             !.crossPathExclusionRequired = TRUE,
                             !.boundedAttemptCarrier = TRUE,
                             !.negativeValidationRequired = TRUE,
                             !.buildObjectQemuRequired = TRUE,
                             !.sourceDriftRequired = TRUE,
                             !.securityReviewRequired = TRUE,
                             !.behaviorPatchDraftAllowed = TRUE,
                             !.runtimeDenialApproved = TRUE,
                             !.cfsDenyRepickApproved = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafeProtectionCostClaimSpec ==
    /\ SetState([Base EXCEPT !.phase = "PatchDraftReady",
                             !.priorGatesComplete = TRUE,
                             !.ordinaryCfsOnlyScope = TRUE,
                             !.fileBoundary = TRUE,
                             !.preSettlePickerIntegration = TRUE,
                             !.hierarchySettlementRequired = TRUE,
                             !.crossPathExclusionRequired = TRUE,
                             !.boundedAttemptCarrier = TRUE,
                             !.negativeValidationRequired = TRUE,
                             !.buildObjectQemuRequired = TRUE,
                             !.sourceDriftRequired = TRUE,
                             !.securityReviewRequired = TRUE,
                             !.behaviorPatchDraftAllowed = TRUE,
                             !.protectionClaim = TRUE,
                             !.costClaim = TRUE])
    /\ [][UNCHANGED vars]_vars

PatchDraftPreconditions ==
    behaviorPatchDraftAllowed =>
        /\ priorGatesComplete
        /\ ordinaryCfsOnlyScope
        /\ fileBoundary
        /\ preSettlePickerIntegration
        /\ hierarchySettlementRequired
        /\ crossPathExclusionRequired
        /\ boundedAttemptCarrier
        /\ negativeValidationRequired
        /\ buildObjectQemuRequired
        /\ sourceDriftRequired
        /\ securityReviewRequired

NonClaims ==
    /\ ~runtimeDenialApproved
    /\ ~cfsDenyRepickApproved
    /\ ~publicAbi
    /\ ~monitorCall
    /\ ~hotLayoutWithoutEvidence
    /\ ~protectionClaim
    /\ ~costClaim

Safety ==
    /\ PatchDraftPreconditions
    /\ NonClaims

=============================================================================
