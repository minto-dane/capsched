---------- MODULE P5AR2LayoutOverheadEvidencePlan ----------
EXTENDS Naturals

VARIABLES phase, evidence

vars == <<phase, evidence>>

BaseEvidence ==
    [ priorMinimalSourceSketchPassed |-> FALSE,
      sourceBasisFresh |-> FALSE,
      noLinuxPatchApproved |-> FALSE,
      hotStructuresEnumerated |-> FALSE,
      fieldNamesProvisional |-> FALSE,
      schedEntityLayoutProbeRequired |-> FALSE,
      cfsRqLayoutProbeRequired |-> FALSE,
      rqLayoutNoChangeCheckRequired |-> FALSE,
      taskStructBaselineProbeRequired |-> FALSE,
      configOffBuildRequired |-> FALSE,
      configOnSelectorDisabledBuildRequired |-> FALSE,
      configOnCandidateEnabledBuildRequired |-> FALSE,
      targetedFairCoreBuildRequired |-> FALSE,
      fullVmlinuxBuildRequired |-> FALSE,
      objectSizeDiffRequired |-> FALSE,
      functionSizeDiffRequired |-> FALSE,
      symbolDiffRequired |-> FALSE,
      hotPickerFunctionsListed |-> FALSE,
      updateCallbacksListed |-> FALSE,
      zeroDeltaRequiredForConfigOff |-> FALSE,
      explicitReviewForNonzeroHotDelta |-> FALSE,
      disabledOverheadClaimRequiresEvidence |-> FALSE,
      costClaimRequiresBenchmark |-> FALSE,
      runtimeClaimRequiresRuntimeTests |-> FALSE,
      negativeStaleSummaryTestsRequired |-> FALSE,
      qemuRuntimePlanRequired |-> FALSE,
      upstreamReplayRequired |-> FALSE,
      securityReviewRequired |-> FALSE,
      noPublicAbi |-> FALSE,
      noTraceAbi |-> FALSE,
      noExportedSymbols |-> FALSE,
      noPickerPolicyLookup |-> FALSE,
      noMonitorCallInPicker |-> FALSE,
      reject0012FallbackExtension |-> FALSE,
      rejectUnboundedScan |-> FALSE,
      rejectSyntheticCommAuthority |-> FALSE,
      linuxPatchApproved |-> FALSE,
      hotLayoutApproved |-> FALSE,
      disabledOverheadApproved |-> FALSE,
      accept0012 |-> FALSE,
      runtimeClaim |-> FALSE,
      protectionClaim |-> FALSE,
      costClaim |-> FALSE,
      datacenterClaim |-> FALSE,
      publicAbi |-> FALSE,
      traceAbi |-> FALSE,
      exportedSymbol |-> FALSE,
      monitorClaim |-> FALSE ]

ReadyEvidence ==
    [ BaseEvidence EXCEPT
        !.priorMinimalSourceSketchPassed = TRUE,
        !.sourceBasisFresh = TRUE,
        !.noLinuxPatchApproved = TRUE,
        !.hotStructuresEnumerated = TRUE,
        !.fieldNamesProvisional = TRUE,
        !.schedEntityLayoutProbeRequired = TRUE,
        !.cfsRqLayoutProbeRequired = TRUE,
        !.rqLayoutNoChangeCheckRequired = TRUE,
        !.taskStructBaselineProbeRequired = TRUE,
        !.configOffBuildRequired = TRUE,
        !.configOnSelectorDisabledBuildRequired = TRUE,
        !.configOnCandidateEnabledBuildRequired = TRUE,
        !.targetedFairCoreBuildRequired = TRUE,
        !.fullVmlinuxBuildRequired = TRUE,
        !.objectSizeDiffRequired = TRUE,
        !.functionSizeDiffRequired = TRUE,
        !.symbolDiffRequired = TRUE,
        !.hotPickerFunctionsListed = TRUE,
        !.updateCallbacksListed = TRUE,
        !.zeroDeltaRequiredForConfigOff = TRUE,
        !.explicitReviewForNonzeroHotDelta = TRUE,
        !.disabledOverheadClaimRequiresEvidence = TRUE,
        !.costClaimRequiresBenchmark = TRUE,
        !.runtimeClaimRequiresRuntimeTests = TRUE,
        !.negativeStaleSummaryTestsRequired = TRUE,
        !.qemuRuntimePlanRequired = TRUE,
        !.upstreamReplayRequired = TRUE,
        !.securityReviewRequired = TRUE,
        !.noPublicAbi = TRUE,
        !.noTraceAbi = TRUE,
        !.noExportedSymbols = TRUE,
        !.noPickerPolicyLookup = TRUE,
        !.noMonitorCallInPicker = TRUE,
        !.reject0012FallbackExtension = TRUE,
        !.rejectUnboundedScan = TRUE,
        !.rejectSyntheticCommAuthority = TRUE ]

Init ==
    /\ phase = "Start"
    /\ evidence = BaseEvidence

RecordBasis ==
    /\ phase = "Start"
    /\ phase' = "BasisRecorded"
    /\ evidence' = [evidence EXCEPT
        !.priorMinimalSourceSketchPassed = TRUE,
        !.sourceBasisFresh = TRUE,
        !.noLinuxPatchApproved = TRUE,
        !.hotStructuresEnumerated = TRUE,
        !.fieldNamesProvisional = TRUE]

RecordLayoutEvidence ==
    /\ phase = "BasisRecorded"
    /\ phase' = "LayoutEvidenceRecorded"
    /\ evidence' = [evidence EXCEPT
        !.schedEntityLayoutProbeRequired = TRUE,
        !.cfsRqLayoutProbeRequired = TRUE,
        !.rqLayoutNoChangeCheckRequired = TRUE,
        !.taskStructBaselineProbeRequired = TRUE,
        !.configOffBuildRequired = TRUE,
        !.configOnSelectorDisabledBuildRequired = TRUE,
        !.configOnCandidateEnabledBuildRequired = TRUE]

RecordObjectEvidence ==
    /\ phase = "LayoutEvidenceRecorded"
    /\ phase' = "ObjectEvidenceRecorded"
    /\ evidence' = [evidence EXCEPT
        !.targetedFairCoreBuildRequired = TRUE,
        !.fullVmlinuxBuildRequired = TRUE,
        !.objectSizeDiffRequired = TRUE,
        !.functionSizeDiffRequired = TRUE,
        !.symbolDiffRequired = TRUE,
        !.hotPickerFunctionsListed = TRUE,
        !.updateCallbacksListed = TRUE,
        !.zeroDeltaRequiredForConfigOff = TRUE,
        !.explicitReviewForNonzeroHotDelta = TRUE,
        !.disabledOverheadClaimRequiresEvidence = TRUE]

RecordAcceptanceEvidence ==
    /\ phase = "ObjectEvidenceRecorded"
    /\ phase' = "EvidencePlanReady"
    /\ evidence' = [evidence EXCEPT
        !.costClaimRequiresBenchmark = TRUE,
        !.runtimeClaimRequiresRuntimeTests = TRUE,
        !.negativeStaleSummaryTestsRequired = TRUE,
        !.qemuRuntimePlanRequired = TRUE,
        !.upstreamReplayRequired = TRUE,
        !.securityReviewRequired = TRUE,
        !.noPublicAbi = TRUE,
        !.noTraceAbi = TRUE,
        !.noExportedSymbols = TRUE,
        !.noPickerPolicyLookup = TRUE,
        !.noMonitorCallInPicker = TRUE,
        !.reject0012FallbackExtension = TRUE,
        !.rejectUnboundedScan = TRUE,
        !.rejectSyntheticCommAuthority = TRUE]

StutterDone ==
    /\ phase = "EvidencePlanReady"
    /\ UNCHANGED vars

Next ==
    \/ RecordBasis
    \/ RecordLayoutEvidence
    \/ RecordObjectEvidence
    \/ RecordAcceptanceEvidence
    \/ StutterDone

SafeSpec == Init /\ [][Next]_vars

SetReady(e) ==
    /\ phase = "EvidencePlanReady"
    /\ evidence = e

UnsafeMissingPriorSourceSketchSpec == SetReady([ReadyEvidence EXCEPT !.priorMinimalSourceSketchPassed = FALSE]) /\ [][UNCHANGED vars]_vars
UnsafeMissingSourceBasisSpec == SetReady([ReadyEvidence EXCEPT !.sourceBasisFresh = FALSE]) /\ [][UNCHANGED vars]_vars
UnsafeLinuxPatchApprovedSpec == SetReady([ReadyEvidence EXCEPT !.linuxPatchApproved = TRUE]) /\ [][UNCHANGED vars]_vars
UnsafeMissingHotStructuresSpec == SetReady([ReadyEvidence EXCEPT !.hotStructuresEnumerated = FALSE]) /\ [][UNCHANGED vars]_vars
UnsafeMissingProvisionalFieldNamesSpec == SetReady([ReadyEvidence EXCEPT !.fieldNamesProvisional = FALSE]) /\ [][UNCHANGED vars]_vars
UnsafeMissingSchedEntityProbeSpec == SetReady([ReadyEvidence EXCEPT !.schedEntityLayoutProbeRequired = FALSE]) /\ [][UNCHANGED vars]_vars
UnsafeMissingCfsRqProbeSpec == SetReady([ReadyEvidence EXCEPT !.cfsRqLayoutProbeRequired = FALSE]) /\ [][UNCHANGED vars]_vars
UnsafeMissingRqNoChangeCheckSpec == SetReady([ReadyEvidence EXCEPT !.rqLayoutNoChangeCheckRequired = FALSE]) /\ [][UNCHANGED vars]_vars
UnsafeMissingTaskStructBaselineProbeSpec == SetReady([ReadyEvidence EXCEPT !.taskStructBaselineProbeRequired = FALSE]) /\ [][UNCHANGED vars]_vars
UnsafeMissingConfigOffBuildSpec == SetReady([ReadyEvidence EXCEPT !.configOffBuildRequired = FALSE]) /\ [][UNCHANGED vars]_vars
UnsafeMissingConfigOnDisabledBuildSpec == SetReady([ReadyEvidence EXCEPT !.configOnSelectorDisabledBuildRequired = FALSE]) /\ [][UNCHANGED vars]_vars
UnsafeMissingConfigOnCandidateBuildSpec == SetReady([ReadyEvidence EXCEPT !.configOnCandidateEnabledBuildRequired = FALSE]) /\ [][UNCHANGED vars]_vars
UnsafeMissingTargetedBuildSpec == SetReady([ReadyEvidence EXCEPT !.targetedFairCoreBuildRequired = FALSE]) /\ [][UNCHANGED vars]_vars
UnsafeMissingFullBuildSpec == SetReady([ReadyEvidence EXCEPT !.fullVmlinuxBuildRequired = FALSE]) /\ [][UNCHANGED vars]_vars
UnsafeMissingObjectSizeDiffSpec == SetReady([ReadyEvidence EXCEPT !.objectSizeDiffRequired = FALSE]) /\ [][UNCHANGED vars]_vars
UnsafeMissingFunctionSizeDiffSpec == SetReady([ReadyEvidence EXCEPT !.functionSizeDiffRequired = FALSE]) /\ [][UNCHANGED vars]_vars
UnsafeMissingSymbolDiffSpec == SetReady([ReadyEvidence EXCEPT !.symbolDiffRequired = FALSE]) /\ [][UNCHANGED vars]_vars
UnsafeMissingHotPickerListSpec == SetReady([ReadyEvidence EXCEPT !.hotPickerFunctionsListed = FALSE]) /\ [][UNCHANGED vars]_vars
UnsafeMissingUpdateCallbackListSpec == SetReady([ReadyEvidence EXCEPT !.updateCallbacksListed = FALSE]) /\ [][UNCHANGED vars]_vars
UnsafeMissingZeroDeltaConfigOffRuleSpec == SetReady([ReadyEvidence EXCEPT !.zeroDeltaRequiredForConfigOff = FALSE]) /\ [][UNCHANGED vars]_vars
UnsafeMissingNonzeroHotDeltaReviewSpec == SetReady([ReadyEvidence EXCEPT !.explicitReviewForNonzeroHotDelta = FALSE]) /\ [][UNCHANGED vars]_vars
UnsafeDisabledOverheadClaimWithoutEvidenceSpec == SetReady([ReadyEvidence EXCEPT !.disabledOverheadClaimRequiresEvidence = FALSE]) /\ [][UNCHANGED vars]_vars
UnsafeCostClaimWithoutBenchmarkSpec == SetReady([ReadyEvidence EXCEPT !.costClaimRequiresBenchmark = FALSE]) /\ [][UNCHANGED vars]_vars
UnsafeRuntimeClaimWithoutRuntimeTestsSpec == SetReady([ReadyEvidence EXCEPT !.runtimeClaimRequiresRuntimeTests = FALSE]) /\ [][UNCHANGED vars]_vars
UnsafeMissingNegativeTestsSpec == SetReady([ReadyEvidence EXCEPT !.negativeStaleSummaryTestsRequired = FALSE]) /\ [][UNCHANGED vars]_vars
UnsafeMissingQemuPlanSpec == SetReady([ReadyEvidence EXCEPT !.qemuRuntimePlanRequired = FALSE]) /\ [][UNCHANGED vars]_vars
UnsafeMissingUpstreamReplaySpec == SetReady([ReadyEvidence EXCEPT !.upstreamReplayRequired = FALSE]) /\ [][UNCHANGED vars]_vars
UnsafeMissingSecurityReviewSpec == SetReady([ReadyEvidence EXCEPT !.securityReviewRequired = FALSE]) /\ [][UNCHANGED vars]_vars
UnsafePublicAbiOrExportSpec == SetReady([ReadyEvidence EXCEPT !.publicAbi = TRUE]) /\ [][UNCHANGED vars]_vars
UnsafePickerPolicyOrMonitorCallSpec == SetReady([ReadyEvidence EXCEPT !.noMonitorCallInPicker = FALSE]) /\ [][UNCHANGED vars]_vars
UnsafeAccept0012ExtensionSpec == SetReady([ReadyEvidence EXCEPT !.reject0012FallbackExtension = FALSE]) /\ [][UNCHANGED vars]_vars
UnsafeUnboundedScanSpec == SetReady([ReadyEvidence EXCEPT !.rejectUnboundedScan = FALSE]) /\ [][UNCHANGED vars]_vars
UnsafeSyntheticCommAuthoritySpec == SetReady([ReadyEvidence EXCEPT !.rejectSyntheticCommAuthority = FALSE]) /\ [][UNCHANGED vars]_vars
UnsafeHotLayoutApprovedBeforeEvidenceSpec == SetReady([ReadyEvidence EXCEPT !.hotLayoutApproved = TRUE]) /\ [][UNCHANGED vars]_vars
UnsafeDisabledOverheadApprovedBeforeEvidenceSpec == SetReady([ReadyEvidence EXCEPT !.disabledOverheadApproved = TRUE]) /\ [][UNCHANGED vars]_vars
UnsafeRuntimeProtectionCostDatacenterClaimSpec == SetReady([ReadyEvidence EXCEPT !.datacenterClaim = TRUE]) /\ [][UNCHANGED vars]_vars

EvidenceRequirementsComplete ==
    /\ evidence.priorMinimalSourceSketchPassed
    /\ evidence.sourceBasisFresh
    /\ evidence.noLinuxPatchApproved
    /\ evidence.hotStructuresEnumerated
    /\ evidence.fieldNamesProvisional
    /\ evidence.schedEntityLayoutProbeRequired
    /\ evidence.cfsRqLayoutProbeRequired
    /\ evidence.rqLayoutNoChangeCheckRequired
    /\ evidence.taskStructBaselineProbeRequired
    /\ evidence.configOffBuildRequired
    /\ evidence.configOnSelectorDisabledBuildRequired
    /\ evidence.configOnCandidateEnabledBuildRequired
    /\ evidence.targetedFairCoreBuildRequired
    /\ evidence.fullVmlinuxBuildRequired
    /\ evidence.objectSizeDiffRequired
    /\ evidence.functionSizeDiffRequired
    /\ evidence.symbolDiffRequired
    /\ evidence.hotPickerFunctionsListed
    /\ evidence.updateCallbacksListed
    /\ evidence.zeroDeltaRequiredForConfigOff
    /\ evidence.explicitReviewForNonzeroHotDelta
    /\ evidence.disabledOverheadClaimRequiresEvidence
    /\ evidence.costClaimRequiresBenchmark
    /\ evidence.runtimeClaimRequiresRuntimeTests
    /\ evidence.negativeStaleSummaryTestsRequired
    /\ evidence.qemuRuntimePlanRequired
    /\ evidence.upstreamReplayRequired
    /\ evidence.securityReviewRequired
    /\ evidence.noPublicAbi
    /\ evidence.noTraceAbi
    /\ evidence.noExportedSymbols
    /\ evidence.noPickerPolicyLookup
    /\ evidence.noMonitorCallInPicker
    /\ evidence.reject0012FallbackExtension
    /\ evidence.rejectUnboundedScan
    /\ evidence.rejectSyntheticCommAuthority

ForbiddenClaimsClear ==
    /\ ~evidence.linuxPatchApproved
    /\ ~evidence.hotLayoutApproved
    /\ ~evidence.disabledOverheadApproved
    /\ ~evidence.accept0012
    /\ ~evidence.runtimeClaim
    /\ ~evidence.protectionClaim
    /\ ~evidence.costClaim
    /\ ~evidence.datacenterClaim
    /\ ~evidence.publicAbi
    /\ ~evidence.traceAbi
    /\ ~evidence.exportedSymbol
    /\ ~evidence.monitorClaim

Safety ==
    phase = "EvidencePlanReady" => EvidenceRequirementsComplete /\ ForbiddenClaimsClear

=============================================================================
