---------- MODULE P5AR2LayoutProbePatchPlan ----------
EXTENDS Naturals

VARIABLES phase, evidence

vars == <<phase, evidence>>

BaseEvidence ==
    [ priorEvidencePlanPassed |-> FALSE,
      sourceBasisFresh |-> FALSE,
      linuxPatchNotCreated |-> FALSE,
      patchSlot0013Reserved |-> FALSE,
      noBehaviorOnly |-> FALSE,
      allowedFilesBounded |-> FALSE,
      kconfigDefaultN |-> FALSE,
      mainConfigDoesNotSelectProbe |-> FALSE,
      probeNotBuiltInNormalConfigs |-> FALSE,
      schedEntityProbeRequired |-> FALSE,
      cfsRqProbeRequired |-> FALSE,
      rqProbeRequired |-> FALSE,
      taskStructProbeRequired |-> FALSE,
      configOffNormalBuildRequired |-> FALSE,
      configOnNormalBuildRequired |-> FALSE,
      probeOnBuildRequired |-> FALSE,
      symbolExtractionRequired |-> FALSE,
      objectAbsenceCheckRequired |-> FALSE,
      functionAbsenceCheckRequired |-> FALSE,
      sourceShapeCheckRequired |-> FALSE,
      upstreamReplayRequired |-> FALSE,
      securityReviewRequired |-> FALSE,
      noPublicAbi |-> FALSE,
      noTraceAbi |-> FALSE,
      noExportedSymbols |-> FALSE,
      noRuntimeCallsite |-> FALSE,
      noMonitorCall |-> FALSE,
      noPolicyLookup |-> FALSE,
      reject0012Acceptance |-> FALSE,
      costClaimRequiresBenchmark |-> FALSE,
      rejectProductionDatacenterClaims |-> FALSE,
      linuxPatchCreated |-> FALSE,
      behaviorChangeApproved |-> FALSE,
      wrongPatchSlot |-> FALSE,
      unboundedAllowedFiles |-> FALSE,
      kconfigDefaultY |-> FALSE,
      mainConfigSelectsProbe |-> FALSE,
      probeBuiltInNormalConfig |-> FALSE,
      publicAbi |-> FALSE,
      traceAbi |-> FALSE,
      exportedSymbol |-> FALSE,
      runtimeCallsiteAdded |-> FALSE,
      monitorCall |-> FALSE,
      policyLookup |-> FALSE,
      accept0012 |-> FALSE,
      costClaim |-> FALSE,
      productionClaim |-> FALSE,
      datacenterClaim |-> FALSE,
      hotFieldApproved |-> FALSE,
      runtimeDenialApproved |-> FALSE,
      protectionClaim |-> FALSE ]

ReadyEvidence ==
    [ BaseEvidence EXCEPT
        !.priorEvidencePlanPassed = TRUE,
        !.sourceBasisFresh = TRUE,
        !.linuxPatchNotCreated = TRUE,
        !.patchSlot0013Reserved = TRUE,
        !.noBehaviorOnly = TRUE,
        !.allowedFilesBounded = TRUE,
        !.kconfigDefaultN = TRUE,
        !.mainConfigDoesNotSelectProbe = TRUE,
        !.probeNotBuiltInNormalConfigs = TRUE,
        !.schedEntityProbeRequired = TRUE,
        !.cfsRqProbeRequired = TRUE,
        !.rqProbeRequired = TRUE,
        !.taskStructProbeRequired = TRUE,
        !.configOffNormalBuildRequired = TRUE,
        !.configOnNormalBuildRequired = TRUE,
        !.probeOnBuildRequired = TRUE,
        !.symbolExtractionRequired = TRUE,
        !.objectAbsenceCheckRequired = TRUE,
        !.functionAbsenceCheckRequired = TRUE,
        !.sourceShapeCheckRequired = TRUE,
        !.upstreamReplayRequired = TRUE,
        !.securityReviewRequired = TRUE,
        !.noPublicAbi = TRUE,
        !.noTraceAbi = TRUE,
        !.noExportedSymbols = TRUE,
        !.noRuntimeCallsite = TRUE,
        !.noMonitorCall = TRUE,
        !.noPolicyLookup = TRUE,
        !.reject0012Acceptance = TRUE,
        !.costClaimRequiresBenchmark = TRUE,
        !.rejectProductionDatacenterClaims = TRUE ]

Init ==
    /\ phase = "Start"
    /\ evidence = BaseEvidence

RecordBasis ==
    /\ phase = "Start"
    /\ phase' = "BasisRecorded"
    /\ evidence' = [evidence EXCEPT
        !.priorEvidencePlanPassed = TRUE,
        !.sourceBasisFresh = TRUE,
        !.linuxPatchNotCreated = TRUE,
        !.patchSlot0013Reserved = TRUE]

RecordPatchBoundary ==
    /\ phase = "BasisRecorded"
    /\ phase' = "PatchBoundaryRecorded"
    /\ evidence' = [evidence EXCEPT
        !.noBehaviorOnly = TRUE,
        !.allowedFilesBounded = TRUE,
        !.kconfigDefaultN = TRUE,
        !.mainConfigDoesNotSelectProbe = TRUE,
        !.probeNotBuiltInNormalConfigs = TRUE,
        !.noRuntimeCallsite = TRUE]

RecordProbeContract ==
    /\ phase = "PatchBoundaryRecorded"
    /\ phase' = "ProbeContractRecorded"
    /\ evidence' = [evidence EXCEPT
        !.schedEntityProbeRequired = TRUE,
        !.cfsRqProbeRequired = TRUE,
        !.rqProbeRequired = TRUE,
        !.taskStructProbeRequired = TRUE,
        !.configOffNormalBuildRequired = TRUE,
        !.configOnNormalBuildRequired = TRUE,
        !.probeOnBuildRequired = TRUE,
        !.symbolExtractionRequired = TRUE,
        !.objectAbsenceCheckRequired = TRUE,
        !.functionAbsenceCheckRequired = TRUE,
        !.sourceShapeCheckRequired = TRUE]

RecordClaimBoundary ==
    /\ phase = "ProbeContractRecorded"
    /\ phase' = "PatchPlanReady"
    /\ evidence' = [evidence EXCEPT
        !.upstreamReplayRequired = TRUE,
        !.securityReviewRequired = TRUE,
        !.noPublicAbi = TRUE,
        !.noTraceAbi = TRUE,
        !.noExportedSymbols = TRUE,
        !.noMonitorCall = TRUE,
        !.noPolicyLookup = TRUE,
        !.reject0012Acceptance = TRUE,
        !.costClaimRequiresBenchmark = TRUE,
        !.rejectProductionDatacenterClaims = TRUE]

StutterDone ==
    /\ phase = "PatchPlanReady"
    /\ UNCHANGED vars

Next ==
    \/ RecordBasis
    \/ RecordPatchBoundary
    \/ RecordProbeContract
    \/ RecordClaimBoundary
    \/ StutterDone

SafeSpec == Init /\ [][Next]_vars

SetReady(e) ==
    /\ phase = "PatchPlanReady"
    /\ evidence = e

UnsafeMissingPriorEvidencePlanSpec == SetReady([ReadyEvidence EXCEPT !.priorEvidencePlanPassed = FALSE]) /\ [][UNCHANGED vars]_vars
UnsafeMissingSourceBasisSpec == SetReady([ReadyEvidence EXCEPT !.sourceBasisFresh = FALSE]) /\ [][UNCHANGED vars]_vars
UnsafeLinuxPatchCreatedSpec == SetReady([ReadyEvidence EXCEPT !.linuxPatchCreated = TRUE]) /\ [][UNCHANGED vars]_vars
UnsafeBehaviorPatchAllowedSpec == SetReady([ReadyEvidence EXCEPT !.behaviorChangeApproved = TRUE]) /\ [][UNCHANGED vars]_vars
UnsafeWrongPatchSlotSpec == SetReady([ReadyEvidence EXCEPT !.wrongPatchSlot = TRUE]) /\ [][UNCHANGED vars]_vars
UnsafeUnboundedAllowedFilesSpec == SetReady([ReadyEvidence EXCEPT !.unboundedAllowedFiles = TRUE]) /\ [][UNCHANGED vars]_vars
UnsafeMissingKconfigDefaultNSpec == SetReady([ReadyEvidence EXCEPT !.kconfigDefaultN = FALSE]) /\ [][UNCHANGED vars]_vars
UnsafeMainConfigSelectsProbeSpec == SetReady([ReadyEvidence EXCEPT !.mainConfigSelectsProbe = TRUE]) /\ [][UNCHANGED vars]_vars
UnsafeProbeBuiltInNormalConfigSpec == SetReady([ReadyEvidence EXCEPT !.probeBuiltInNormalConfig = TRUE]) /\ [][UNCHANGED vars]_vars
UnsafeMissingSchedEntityProbeSpec == SetReady([ReadyEvidence EXCEPT !.schedEntityProbeRequired = FALSE]) /\ [][UNCHANGED vars]_vars
UnsafeMissingCfsRqProbeSpec == SetReady([ReadyEvidence EXCEPT !.cfsRqProbeRequired = FALSE]) /\ [][UNCHANGED vars]_vars
UnsafeMissingRqProbeSpec == SetReady([ReadyEvidence EXCEPT !.rqProbeRequired = FALSE]) /\ [][UNCHANGED vars]_vars
UnsafeMissingTaskStructProbeSpec == SetReady([ReadyEvidence EXCEPT !.taskStructProbeRequired = FALSE]) /\ [][UNCHANGED vars]_vars
UnsafeMissingConfigOffNormalBuildSpec == SetReady([ReadyEvidence EXCEPT !.configOffNormalBuildRequired = FALSE]) /\ [][UNCHANGED vars]_vars
UnsafeMissingConfigOnNormalBuildSpec == SetReady([ReadyEvidence EXCEPT !.configOnNormalBuildRequired = FALSE]) /\ [][UNCHANGED vars]_vars
UnsafeMissingProbeOnBuildSpec == SetReady([ReadyEvidence EXCEPT !.probeOnBuildRequired = FALSE]) /\ [][UNCHANGED vars]_vars
UnsafeMissingSymbolExtractionSpec == SetReady([ReadyEvidence EXCEPT !.symbolExtractionRequired = FALSE]) /\ [][UNCHANGED vars]_vars
UnsafeMissingObjectAbsenceCheckSpec == SetReady([ReadyEvidence EXCEPT !.objectAbsenceCheckRequired = FALSE]) /\ [][UNCHANGED vars]_vars
UnsafeMissingFunctionAbsenceCheckSpec == SetReady([ReadyEvidence EXCEPT !.functionAbsenceCheckRequired = FALSE]) /\ [][UNCHANGED vars]_vars
UnsafeMissingSourceShapeCheckSpec == SetReady([ReadyEvidence EXCEPT !.sourceShapeCheckRequired = FALSE]) /\ [][UNCHANGED vars]_vars
UnsafeMissingUpstreamReplaySpec == SetReady([ReadyEvidence EXCEPT !.upstreamReplayRequired = FALSE]) /\ [][UNCHANGED vars]_vars
UnsafeMissingSecurityReviewSpec == SetReady([ReadyEvidence EXCEPT !.securityReviewRequired = FALSE]) /\ [][UNCHANGED vars]_vars
UnsafePublicAbiOrTraceSpec == SetReady([ReadyEvidence EXCEPT !.publicAbi = TRUE]) /\ [][UNCHANGED vars]_vars
UnsafeExportedSymbolSpec == SetReady([ReadyEvidence EXCEPT !.exportedSymbol = TRUE]) /\ [][UNCHANGED vars]_vars
UnsafeRuntimeCallsiteAddedSpec == SetReady([ReadyEvidence EXCEPT !.runtimeCallsiteAdded = TRUE]) /\ [][UNCHANGED vars]_vars
UnsafeMonitorCallSpec == SetReady([ReadyEvidence EXCEPT !.monitorCall = TRUE]) /\ [][UNCHANGED vars]_vars
UnsafePolicyLookupSpec == SetReady([ReadyEvidence EXCEPT !.policyLookup = TRUE]) /\ [][UNCHANGED vars]_vars
UnsafeAccept0012Spec == SetReady([ReadyEvidence EXCEPT !.accept0012 = TRUE]) /\ [][UNCHANGED vars]_vars
UnsafeCostClaimWithoutBenchmarkSpec == SetReady([ReadyEvidence EXCEPT !.costClaim = TRUE]) /\ [][UNCHANGED vars]_vars
UnsafeProductionClaimFromProbeSpec == SetReady([ReadyEvidence EXCEPT !.productionClaim = TRUE]) /\ [][UNCHANGED vars]_vars
UnsafeDatacenterClaimFromProbeSpec == SetReady([ReadyEvidence EXCEPT !.datacenterClaim = TRUE]) /\ [][UNCHANGED vars]_vars

EvidenceRequirementsComplete ==
    /\ evidence.priorEvidencePlanPassed
    /\ evidence.sourceBasisFresh
    /\ evidence.linuxPatchNotCreated
    /\ evidence.patchSlot0013Reserved
    /\ evidence.noBehaviorOnly
    /\ evidence.allowedFilesBounded
    /\ evidence.kconfigDefaultN
    /\ evidence.mainConfigDoesNotSelectProbe
    /\ evidence.probeNotBuiltInNormalConfigs
    /\ evidence.schedEntityProbeRequired
    /\ evidence.cfsRqProbeRequired
    /\ evidence.rqProbeRequired
    /\ evidence.taskStructProbeRequired
    /\ evidence.configOffNormalBuildRequired
    /\ evidence.configOnNormalBuildRequired
    /\ evidence.probeOnBuildRequired
    /\ evidence.symbolExtractionRequired
    /\ evidence.objectAbsenceCheckRequired
    /\ evidence.functionAbsenceCheckRequired
    /\ evidence.sourceShapeCheckRequired
    /\ evidence.upstreamReplayRequired
    /\ evidence.securityReviewRequired
    /\ evidence.noPublicAbi
    /\ evidence.noTraceAbi
    /\ evidence.noExportedSymbols
    /\ evidence.noRuntimeCallsite
    /\ evidence.noMonitorCall
    /\ evidence.noPolicyLookup
    /\ evidence.reject0012Acceptance
    /\ evidence.costClaimRequiresBenchmark
    /\ evidence.rejectProductionDatacenterClaims

ForbiddenClaimsClear ==
    /\ ~evidence.linuxPatchCreated
    /\ ~evidence.behaviorChangeApproved
    /\ ~evidence.wrongPatchSlot
    /\ ~evidence.unboundedAllowedFiles
    /\ ~evidence.kconfigDefaultY
    /\ ~evidence.mainConfigSelectsProbe
    /\ ~evidence.probeBuiltInNormalConfig
    /\ ~evidence.publicAbi
    /\ ~evidence.traceAbi
    /\ ~evidence.exportedSymbol
    /\ ~evidence.runtimeCallsiteAdded
    /\ ~evidence.monitorCall
    /\ ~evidence.policyLookup
    /\ ~evidence.accept0012
    /\ ~evidence.costClaim
    /\ ~evidence.productionClaim
    /\ ~evidence.datacenterClaim
    /\ ~evidence.hotFieldApproved
    /\ ~evidence.runtimeDenialApproved
    /\ ~evidence.protectionClaim

Safety ==
    phase = "PatchPlanReady" => EvidenceRequirementsComplete /\ ForbiddenClaimsClear

=============================================================================
