---------- MODULE P5AR2MinimalSourceSketch ----------
EXTENDS Naturals

VARIABLES phase, sketch

vars == <<phase, sketch>>

BaseSketch ==
    [ priorPatchPlanPassed |-> FALSE,
      sourceBasisFresh |-> FALSE,
      noLinuxPatchApproved |-> FALSE,
      piggybackExistingEevdfAugmentation |-> FALSE,
      singleTimelineOnly |-> FALSE,
      separateEligibleTreeRejected |-> FALSE,
      minPickableLeafSentinel |-> FALSE,
      subtreeMinPickableAggregate |-> FALSE,
      eevdfPruningPreserved |-> FALSE,
      booleanSummaryRejected |-> FALSE,
      postFilterFallbackRejected |-> FALSE,
      unboundedScanRejected |-> FALSE,
      freshOnlyPickerProof |-> FALSE,
      staleRefreshingBlockedFailClosed |-> FALSE,
      currentEntitySeparate |-> FALSE,
      groupDescendantPropagationRequired |-> FALSE,
      leafInvalidationPlanned |-> FALSE,
      monitorReceiptPlaceholderPreserved |-> FALSE,
      generationEpochRefreshRequired |-> FALSE,
      budgetAffinityRefreshRequired |-> FALSE,
      noPickTimePolicyLookup |-> FALSE,
      noMonitorCallInPicker |-> FALSE,
      syntheticCommAuthorityRejected |-> FALSE,
      accountingSeparated |-> FALSE,
      crossPathBoundaryRecorded |-> FALSE,
      hotLayoutConditionalOnly |-> FALSE,
      objectLayoutPlanRequired |-> FALSE,
      disabledOverheadPlanRequired |-> FALSE,
      hotFunctionSizePlanRequired |-> FALSE,
      benchmarkPlanRequired |-> FALSE,
      negativeStaleSummaryTestsRequired |-> FALSE,
      qemuRuntimePlanRequired |-> FALSE,
      upstreamReplayRequired |-> FALSE,
      securityReviewRequired |-> FALSE,
      linuxPatchApproved |-> FALSE,
      accept0009To0012 |-> FALSE,
      runtimeDenialClaim |-> FALSE,
      completeCfsClaim |-> FALSE,
      hotLayoutChangeApproved |-> FALSE,
      publicAbi |-> FALSE,
      traceAbi |-> FALSE,
      exportedSymbol |-> FALSE,
      monitorClaim |-> FALSE,
      protectionClaim |-> FALSE,
      costClaim |-> FALSE,
      deploymentClaim |-> FALSE,
      datacenterClaim |-> FALSE ]

ReadySketch ==
    [ BaseSketch EXCEPT
        !.priorPatchPlanPassed = TRUE,
        !.sourceBasisFresh = TRUE,
        !.noLinuxPatchApproved = TRUE,
        !.piggybackExistingEevdfAugmentation = TRUE,
        !.singleTimelineOnly = TRUE,
        !.separateEligibleTreeRejected = TRUE,
        !.minPickableLeafSentinel = TRUE,
        !.subtreeMinPickableAggregate = TRUE,
        !.eevdfPruningPreserved = TRUE,
        !.booleanSummaryRejected = TRUE,
        !.postFilterFallbackRejected = TRUE,
        !.unboundedScanRejected = TRUE,
        !.freshOnlyPickerProof = TRUE,
        !.staleRefreshingBlockedFailClosed = TRUE,
        !.currentEntitySeparate = TRUE,
        !.groupDescendantPropagationRequired = TRUE,
        !.leafInvalidationPlanned = TRUE,
        !.monitorReceiptPlaceholderPreserved = TRUE,
        !.generationEpochRefreshRequired = TRUE,
        !.budgetAffinityRefreshRequired = TRUE,
        !.noPickTimePolicyLookup = TRUE,
        !.noMonitorCallInPicker = TRUE,
        !.syntheticCommAuthorityRejected = TRUE,
        !.accountingSeparated = TRUE,
        !.crossPathBoundaryRecorded = TRUE,
        !.hotLayoutConditionalOnly = TRUE,
        !.objectLayoutPlanRequired = TRUE,
        !.disabledOverheadPlanRequired = TRUE,
        !.hotFunctionSizePlanRequired = TRUE,
        !.benchmarkPlanRequired = TRUE,
        !.negativeStaleSummaryTestsRequired = TRUE,
        !.qemuRuntimePlanRequired = TRUE,
        !.upstreamReplayRequired = TRUE,
        !.securityReviewRequired = TRUE ]

Init ==
    /\ phase = "Start"
    /\ sketch = BaseSketch

RecordBasis ==
    /\ phase = "Start"
    /\ phase' = "BasisRecorded"
    /\ sketch' = [sketch EXCEPT
        !.priorPatchPlanPassed = TRUE,
        !.sourceBasisFresh = TRUE,
        !.noLinuxPatchApproved = TRUE]

RecordPlacement ==
    /\ phase = "BasisRecorded"
    /\ phase' = "PlacementRecorded"
    /\ sketch' = [sketch EXCEPT
        !.piggybackExistingEevdfAugmentation = TRUE,
        !.singleTimelineOnly = TRUE,
        !.separateEligibleTreeRejected = TRUE,
        !.minPickableLeafSentinel = TRUE,
        !.subtreeMinPickableAggregate = TRUE,
        !.eevdfPruningPreserved = TRUE,
        !.booleanSummaryRejected = TRUE,
        !.postFilterFallbackRejected = TRUE,
        !.unboundedScanRejected = TRUE]

RecordFreshness ==
    /\ phase = "PlacementRecorded"
    /\ phase' = "FreshnessRecorded"
    /\ sketch' = [sketch EXCEPT
        !.freshOnlyPickerProof = TRUE,
        !.staleRefreshingBlockedFailClosed = TRUE,
        !.currentEntitySeparate = TRUE,
        !.groupDescendantPropagationRequired = TRUE,
        !.leafInvalidationPlanned = TRUE,
        !.monitorReceiptPlaceholderPreserved = TRUE,
        !.generationEpochRefreshRequired = TRUE,
        !.budgetAffinityRefreshRequired = TRUE,
        !.noPickTimePolicyLookup = TRUE,
        !.noMonitorCallInPicker = TRUE,
        !.syntheticCommAuthorityRejected = TRUE,
        !.accountingSeparated = TRUE,
        !.crossPathBoundaryRecorded = TRUE]

RecordEvidence ==
    /\ phase = "FreshnessRecorded"
    /\ phase' = "SketchReady"
    /\ sketch' = [sketch EXCEPT
        !.hotLayoutConditionalOnly = TRUE,
        !.objectLayoutPlanRequired = TRUE,
        !.disabledOverheadPlanRequired = TRUE,
        !.hotFunctionSizePlanRequired = TRUE,
        !.benchmarkPlanRequired = TRUE,
        !.negativeStaleSummaryTestsRequired = TRUE,
        !.qemuRuntimePlanRequired = TRUE,
        !.upstreamReplayRequired = TRUE,
        !.securityReviewRequired = TRUE]

StutterDone ==
    /\ phase = "SketchReady"
    /\ UNCHANGED vars

Next ==
    \/ RecordBasis
    \/ RecordPlacement
    \/ RecordFreshness
    \/ RecordEvidence
    \/ StutterDone

SafeSpec == Init /\ [][Next]_vars

SetReady(s) ==
    /\ phase = "SketchReady"
    /\ sketch = s

UnsafeMissingPriorPatchPlanSpec ==
    /\ SetReady([ReadySketch EXCEPT !.priorPatchPlanPassed = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingSourceBasisSpec ==
    /\ SetReady([ReadySketch EXCEPT !.sourceBasisFresh = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeLinuxPatchApprovedSpec ==
    /\ SetReady([ReadySketch EXCEPT !.linuxPatchApproved = TRUE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingEevdfPiggybackSpec ==
    /\ SetReady([ReadySketch EXCEPT !.piggybackExistingEevdfAugmentation = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingSingleTimelineSpec ==
    /\ SetReady([ReadySketch EXCEPT !.singleTimelineOnly = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeSeparateTreeSpec ==
    /\ SetReady([ReadySketch EXCEPT !.separateEligibleTreeRejected = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingLeafSentinelSpec ==
    /\ SetReady([ReadySketch EXCEPT !.minPickableLeafSentinel = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingSubtreeAggregateSpec ==
    /\ SetReady([ReadySketch EXCEPT !.subtreeMinPickableAggregate = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingEevdfPruningSpec ==
    /\ SetReady([ReadySketch EXCEPT !.eevdfPruningPreserved = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeBooleanSummarySpec ==
    /\ SetReady([ReadySketch EXCEPT !.booleanSummaryRejected = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafePostFilterExtensionSpec ==
    /\ SetReady([ReadySketch EXCEPT !.postFilterFallbackRejected = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeUnboundedScanSpec ==
    /\ SetReady([ReadySketch EXCEPT !.unboundedScanRejected = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafePickerTrustsNonFreshSpec ==
    /\ SetReady([ReadySketch EXCEPT !.freshOnlyPickerProof = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingFailClosedSpec ==
    /\ SetReady([ReadySketch EXCEPT !.staleRefreshingBlockedFailClosed = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeCurrentTreeCollapseSpec ==
    /\ SetReady([ReadySketch EXCEPT !.currentEntitySeparate = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingGroupPropagationSpec ==
    /\ SetReady([ReadySketch EXCEPT !.groupDescendantPropagationRequired = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingLeafInvalidationSpec ==
    /\ SetReady([ReadySketch EXCEPT !.leafInvalidationPlanned = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingMonitorReceiptPlaceholderSpec ==
    /\ SetReady([ReadySketch EXCEPT !.monitorReceiptPlaceholderPreserved = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingGenerationEpochRefreshSpec ==
    /\ SetReady([ReadySketch EXCEPT !.generationEpochRefreshRequired = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingBudgetAffinityRefreshSpec ==
    /\ SetReady([ReadySketch EXCEPT !.budgetAffinityRefreshRequired = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafePickTimePolicyLookupSpec ==
    /\ SetReady([ReadySketch EXCEPT !.noPickTimePolicyLookup = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeMonitorCallInPickerSpec ==
    /\ SetReady([ReadySketch EXCEPT !.noMonitorCallInPicker = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeSyntheticCommAuthoritySpec ==
    /\ SetReady([ReadySketch EXCEPT !.syntheticCommAuthorityRejected = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingAccountingSeparationSpec ==
    /\ SetReady([ReadySketch EXCEPT !.accountingSeparated = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingCrossPathBoundarySpec ==
    /\ SetReady([ReadySketch EXCEPT !.crossPathBoundaryRecorded = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeHotLayoutUnconditionalSpec ==
    /\ SetReady([ReadySketch EXCEPT !.hotLayoutConditionalOnly = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingObjectLayoutPlanSpec ==
    /\ SetReady([ReadySketch EXCEPT !.objectLayoutPlanRequired = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingDisabledOverheadPlanSpec ==
    /\ SetReady([ReadySketch EXCEPT !.disabledOverheadPlanRequired = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingHotFunctionSizePlanSpec ==
    /\ SetReady([ReadySketch EXCEPT !.hotFunctionSizePlanRequired = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingNegativeTestsSpec ==
    /\ SetReady([ReadySketch EXCEPT !.negativeStaleSummaryTestsRequired = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeMissingUpstreamSecurityReviewSpec ==
    /\ SetReady([ReadySketch EXCEPT !.upstreamReplayRequired = FALSE])
    /\ [][UNCHANGED vars]_vars

UnsafeRuntimeProtectionCostDatacenterClaimSpec ==
    /\ SetReady([ReadySketch EXCEPT !.datacenterClaim = TRUE])
    /\ [][UNCHANGED vars]_vars

SketchRequirementsComplete ==
    /\ sketch.priorPatchPlanPassed
    /\ sketch.sourceBasisFresh
    /\ sketch.noLinuxPatchApproved
    /\ sketch.piggybackExistingEevdfAugmentation
    /\ sketch.singleTimelineOnly
    /\ sketch.separateEligibleTreeRejected
    /\ sketch.minPickableLeafSentinel
    /\ sketch.subtreeMinPickableAggregate
    /\ sketch.eevdfPruningPreserved
    /\ sketch.booleanSummaryRejected
    /\ sketch.postFilterFallbackRejected
    /\ sketch.unboundedScanRejected
    /\ sketch.freshOnlyPickerProof
    /\ sketch.staleRefreshingBlockedFailClosed
    /\ sketch.currentEntitySeparate
    /\ sketch.groupDescendantPropagationRequired
    /\ sketch.leafInvalidationPlanned
    /\ sketch.monitorReceiptPlaceholderPreserved
    /\ sketch.generationEpochRefreshRequired
    /\ sketch.budgetAffinityRefreshRequired
    /\ sketch.noPickTimePolicyLookup
    /\ sketch.noMonitorCallInPicker
    /\ sketch.syntheticCommAuthorityRejected
    /\ sketch.accountingSeparated
    /\ sketch.crossPathBoundaryRecorded
    /\ sketch.hotLayoutConditionalOnly
    /\ sketch.objectLayoutPlanRequired
    /\ sketch.disabledOverheadPlanRequired
    /\ sketch.hotFunctionSizePlanRequired
    /\ sketch.benchmarkPlanRequired
    /\ sketch.negativeStaleSummaryTestsRequired
    /\ sketch.qemuRuntimePlanRequired
    /\ sketch.upstreamReplayRequired
    /\ sketch.securityReviewRequired

ForbiddenClaimsClear ==
    /\ ~sketch.linuxPatchApproved
    /\ ~sketch.accept0009To0012
    /\ ~sketch.runtimeDenialClaim
    /\ ~sketch.completeCfsClaim
    /\ ~sketch.hotLayoutChangeApproved
    /\ ~sketch.publicAbi
    /\ ~sketch.traceAbi
    /\ ~sketch.exportedSymbol
    /\ ~sketch.monitorClaim
    /\ ~sketch.protectionClaim
    /\ ~sketch.costClaim
    /\ ~sketch.deploymentClaim
    /\ ~sketch.datacenterClaim

Safety ==
    phase = "SketchReady" => SketchRequirementsComplete /\ ForbiddenClaimsClear

=============================================================================
