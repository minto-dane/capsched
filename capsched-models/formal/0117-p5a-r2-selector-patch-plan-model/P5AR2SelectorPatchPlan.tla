---------- MODULE P5AR2SelectorPatchPlan ----------
EXTENDS Naturals

VARIABLES phase, plan

vars == <<phase, plan>>

BasePlan ==
    [ priorGatesPassed |-> FALSE,
      sourceBasisFresh |-> FALSE,
      patchQueueBoundaryRecorded |-> FALSE,
      candidateASelected |-> FALSE,
      candidateCConstraintPreserved |-> FALSE,
      eevdfMinPickableSummaryRequired |-> FALSE,
      booleanOnlySummaryRejected |-> FALSE,
      postFilterFallbackRejected |-> FALSE,
      noUnboundedScan |-> FALSE,
      freshnessSemanticsRequired |-> FALSE,
      invalidationMapRequired |-> FALSE,
      invalidationCoverageRequired |-> FALSE,
      failClosedSummaryStatesRequired |-> FALSE,
      groupNoFalsePositiveRequired |-> FALSE,
      groupNoSilentFalseNegativeRequired |-> FALSE,
      currentEntitySeparateRequired |-> FALSE,
      accountingSeparated |-> FALSE,
      crossPathSettlementRequired |-> FALSE,
      fileBoundaryMinimal |-> FALSE,
      hotLayoutEvidenceRequired |-> FALSE,
      disabledOverheadEvidenceRequired |-> FALSE,
      benchmarkPlanRequired |-> FALSE,
      negativeValidationPlanRequired |-> FALSE,
      qemuRuntimePlanRequired |-> FALSE,
      securityReviewRequired |-> FALSE,
      upstreamReplayRequired |-> FALSE,
      noPublicAbi |-> FALSE,
      noTraceAbi |-> FALSE,
      noExportedSymbols |-> FALSE,
      noPickerPolicyLookup |-> FALSE,
      noMonitorCallInPicker |-> FALSE,
      linuxPatchApproved |-> FALSE,
      accept0009To0012 |-> FALSE,
      runtimeDenialClaim |-> FALSE,
      completeCfsClaim |-> FALSE,
      hotLayoutChangeApproved |-> FALSE,
      publicAbi |-> FALSE,
      publicTraceAbi |-> FALSE,
      exportedSymbol |-> FALSE,
      monitorClaim |-> FALSE,
      protectionClaim |-> FALSE,
      costClaim |-> FALSE,
      deploymentClaim |-> FALSE,
      datacenterClaim |-> FALSE ]

ReadyPlan ==
    [ BasePlan EXCEPT
        !.priorGatesPassed = TRUE,
        !.sourceBasisFresh = TRUE,
        !.patchQueueBoundaryRecorded = TRUE,
        !.candidateASelected = TRUE,
        !.candidateCConstraintPreserved = TRUE,
        !.eevdfMinPickableSummaryRequired = TRUE,
        !.booleanOnlySummaryRejected = TRUE,
        !.postFilterFallbackRejected = TRUE,
        !.noUnboundedScan = TRUE,
        !.freshnessSemanticsRequired = TRUE,
        !.invalidationMapRequired = TRUE,
        !.invalidationCoverageRequired = TRUE,
        !.failClosedSummaryStatesRequired = TRUE,
        !.groupNoFalsePositiveRequired = TRUE,
        !.groupNoSilentFalseNegativeRequired = TRUE,
        !.currentEntitySeparateRequired = TRUE,
        !.accountingSeparated = TRUE,
        !.crossPathSettlementRequired = TRUE,
        !.fileBoundaryMinimal = TRUE,
        !.hotLayoutEvidenceRequired = TRUE,
        !.disabledOverheadEvidenceRequired = TRUE,
        !.benchmarkPlanRequired = TRUE,
        !.negativeValidationPlanRequired = TRUE,
        !.qemuRuntimePlanRequired = TRUE,
        !.securityReviewRequired = TRUE,
        !.upstreamReplayRequired = TRUE,
        !.noPublicAbi = TRUE,
        !.noTraceAbi = TRUE,
        !.noExportedSymbols = TRUE,
        !.noPickerPolicyLookup = TRUE,
        !.noMonitorCallInPicker = TRUE ]

Init ==
    /\ phase = "Start"
    /\ plan = BasePlan

RecordBasis ==
    /\ phase = "Start"
    /\ phase' = "BasisRecorded"
    /\ plan' = [plan EXCEPT
        !.priorGatesPassed = TRUE,
        !.sourceBasisFresh = TRUE,
        !.patchQueueBoundaryRecorded = TRUE]

RecordSelectorShape ==
    /\ phase = "BasisRecorded"
    /\ phase' = "SelectorShapeRecorded"
    /\ plan' = [plan EXCEPT
        !.candidateASelected = TRUE,
        !.candidateCConstraintPreserved = TRUE,
        !.eevdfMinPickableSummaryRequired = TRUE,
        !.booleanOnlySummaryRejected = TRUE,
        !.postFilterFallbackRejected = TRUE,
        !.noUnboundedScan = TRUE,
        !.fileBoundaryMinimal = TRUE,
        !.noPublicAbi = TRUE,
        !.noTraceAbi = TRUE,
        !.noExportedSymbols = TRUE]

RecordFreshnessRules ==
    /\ phase = "SelectorShapeRecorded"
    /\ phase' = "FreshnessRulesRecorded"
    /\ plan' = [plan EXCEPT
        !.freshnessSemanticsRequired = TRUE,
        !.invalidationMapRequired = TRUE,
        !.invalidationCoverageRequired = TRUE,
        !.failClosedSummaryStatesRequired = TRUE,
        !.groupNoFalsePositiveRequired = TRUE,
        !.groupNoSilentFalseNegativeRequired = TRUE,
        !.currentEntitySeparateRequired = TRUE,
        !.accountingSeparated = TRUE,
        !.crossPathSettlementRequired = TRUE,
        !.noPickerPolicyLookup = TRUE,
        !.noMonitorCallInPicker = TRUE]

RecordEvidenceRules ==
    /\ phase = "FreshnessRulesRecorded"
    /\ phase' = "PatchPlanReady"
    /\ plan' = [plan EXCEPT
        !.hotLayoutEvidenceRequired = TRUE,
        !.disabledOverheadEvidenceRequired = TRUE,
        !.benchmarkPlanRequired = TRUE,
        !.negativeValidationPlanRequired = TRUE,
        !.qemuRuntimePlanRequired = TRUE,
        !.securityReviewRequired = TRUE,
        !.upstreamReplayRequired = TRUE]

StutterDone ==
    /\ phase = "PatchPlanReady"
    /\ UNCHANGED vars

Next ==
    \/ RecordBasis
    \/ RecordSelectorShape
    \/ RecordFreshnessRules
    \/ RecordEvidenceRules
    \/ StutterDone

SafeSpec == Init /\ [][Next]_vars

SetReady(p) ==
    /\ phase = "PatchPlanReady"
    /\ plan = p

UnsafeMissingPriorGatesSpec ==
    /\ SetReady([ReadyPlan EXCEPT !.priorGatesPassed = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingSourceBasisSpec ==
    /\ SetReady([ReadyPlan EXCEPT !.sourceBasisFresh = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingPatchQueueBoundarySpec ==
    /\ SetReady([ReadyPlan EXCEPT !.patchQueueBoundaryRecorded = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingCandidateASpec ==
    /\ SetReady([ReadyPlan EXCEPT !.candidateASelected = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingCandidateCSpec ==
    /\ SetReady([ReadyPlan EXCEPT !.candidateCConstraintPreserved = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingEevdfMinPickableSpec ==
    /\ SetReady([ReadyPlan EXCEPT !.eevdfMinPickableSummaryRequired = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeBooleanOnlySummarySpec ==
    /\ SetReady([ReadyPlan EXCEPT !.booleanOnlySummaryRejected = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafePostFilterExtensionSpec ==
    /\ SetReady([ReadyPlan EXCEPT !.postFilterFallbackRejected = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeUnboundedScanSpec ==
    /\ SetReady([ReadyPlan EXCEPT !.noUnboundedScan = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingFreshnessSemanticsSpec ==
    /\ SetReady([ReadyPlan EXCEPT !.freshnessSemanticsRequired = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingInvalidationMapSpec ==
    /\ SetReady([ReadyPlan EXCEPT !.invalidationMapRequired = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingInvalidationCoverageSpec ==
    /\ SetReady([ReadyPlan EXCEPT !.invalidationCoverageRequired = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingFailClosedStatesSpec ==
    /\ SetReady([ReadyPlan EXCEPT !.failClosedSummaryStatesRequired = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeGroupFalsePositiveSpec ==
    /\ SetReady([ReadyPlan EXCEPT !.groupNoFalsePositiveRequired = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeGroupSilentFalseNegativeSpec ==
    /\ SetReady([ReadyPlan EXCEPT !.groupNoSilentFalseNegativeRequired = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeCurrentTreeCollapseSpec ==
    /\ SetReady([ReadyPlan EXCEPT !.currentEntitySeparateRequired = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingAccountingSeparationSpec ==
    /\ SetReady([ReadyPlan EXCEPT !.accountingSeparated = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingCrossPathSettlementSpec ==
    /\ SetReady([ReadyPlan EXCEPT !.crossPathSettlementRequired = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingFileBoundarySpec ==
    /\ SetReady([ReadyPlan EXCEPT !.fileBoundaryMinimal = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingHotLayoutEvidenceSpec ==
    /\ SetReady([ReadyPlan EXCEPT !.hotLayoutEvidenceRequired = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingDisabledOverheadEvidenceSpec ==
    /\ SetReady([ReadyPlan EXCEPT !.disabledOverheadEvidenceRequired = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingBenchmarkPlanSpec ==
    /\ SetReady([ReadyPlan EXCEPT !.benchmarkPlanRequired = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingNegativeValidationSpec ==
    /\ SetReady([ReadyPlan EXCEPT !.negativeValidationPlanRequired = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingQemuRuntimePlanSpec ==
    /\ SetReady([ReadyPlan EXCEPT !.qemuRuntimePlanRequired = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingSecurityReviewSpec ==
    /\ SetReady([ReadyPlan EXCEPT !.securityReviewRequired = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingUpstreamReplaySpec ==
    /\ SetReady([ReadyPlan EXCEPT !.upstreamReplayRequired = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafePublicAbiOrExportSpec ==
    /\ SetReady([ReadyPlan EXCEPT !.publicAbi = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafePickerPolicyOrMonitorCallSpec ==
    /\ SetReady([ReadyPlan EXCEPT !.noPickerPolicyLookup = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeLinuxPatchOr0012AcceptanceSpec ==
    /\ SetReady([ReadyPlan EXCEPT !.linuxPatchApproved = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafeRuntimeProtectionCostDatacenterClaimSpec ==
    /\ SetReady([ReadyPlan EXCEPT !.datacenterClaim = TRUE])
    /\ [][UNCHANGED vars]_vars

PlanRequirementsComplete ==
    /\ plan.priorGatesPassed
    /\ plan.sourceBasisFresh
    /\ plan.patchQueueBoundaryRecorded
    /\ plan.candidateASelected
    /\ plan.candidateCConstraintPreserved
    /\ plan.eevdfMinPickableSummaryRequired
    /\ plan.booleanOnlySummaryRejected
    /\ plan.postFilterFallbackRejected
    /\ plan.noUnboundedScan
    /\ plan.freshnessSemanticsRequired
    /\ plan.invalidationMapRequired
    /\ plan.invalidationCoverageRequired
    /\ plan.failClosedSummaryStatesRequired
    /\ plan.groupNoFalsePositiveRequired
    /\ plan.groupNoSilentFalseNegativeRequired
    /\ plan.currentEntitySeparateRequired
    /\ plan.accountingSeparated
    /\ plan.crossPathSettlementRequired
    /\ plan.fileBoundaryMinimal
    /\ plan.hotLayoutEvidenceRequired
    /\ plan.disabledOverheadEvidenceRequired
    /\ plan.benchmarkPlanRequired
    /\ plan.negativeValidationPlanRequired
    /\ plan.qemuRuntimePlanRequired
    /\ plan.securityReviewRequired
    /\ plan.upstreamReplayRequired
    /\ plan.noPublicAbi
    /\ plan.noTraceAbi
    /\ plan.noExportedSymbols
    /\ plan.noPickerPolicyLookup
    /\ plan.noMonitorCallInPicker

ForbiddenClaimsClear ==
    /\ ~plan.linuxPatchApproved
    /\ ~plan.accept0009To0012
    /\ ~plan.runtimeDenialClaim
    /\ ~plan.completeCfsClaim
    /\ ~plan.hotLayoutChangeApproved
    /\ ~plan.publicAbi
    /\ ~plan.publicTraceAbi
    /\ ~plan.exportedSymbol
    /\ ~plan.monitorClaim
    /\ ~plan.protectionClaim
    /\ ~plan.costClaim
    /\ ~plan.deploymentClaim
    /\ ~plan.datacenterClaim

Safety ==
    phase = "PatchPlanReady" => PlanRequirementsComplete /\ ForbiddenClaimsClear

=============================================================================
