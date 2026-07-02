---------- MODULE P5A0P1PatchPlanGate ----------

VARIABLE gate

vars == <<gate>>

Phase == {
    "Start",
    "P5A0P1PlanRecorded",
    "BadMissingEvidence",
    "BadMissingPlanRecord",
    "BadPatchApproved",
    "BadMissingPatchIdentity",
    "BadMissingFileAllowlist",
    "BadOutOfAllowlistDelta",
    "BadSchedulerTouchWithoutReopen",
    "BadUnclaimedDriftGroupTouch",
    "BadExternalLayoutOrRuntimeState",
    "BadLifecycleHelperChange",
    "BadNonStaticOrExportedSymbol",
    "BadBehaviorOrNonAllow",
    "BadSchedulerBranch",
    "BadRuntimeDenialFamily",
    "BadPublicAbiTraceOrMonitor",
    "BadLayoutOrHotPathImpact",
    "BadAllocationSleepLockRef",
    "BadQemuSmokeAsCoverage",
    "BadScopedFreshnessAsGlobal",
    "BadProtectionCostDatacenterClaim"
}

GateFields == {
    "phase",
    "p5a0ERecorded",
    "sourceDriftRun",
    "candidateGroupsFresh",
    "nonCandidateStaleRecorded",
    "candidateScopedFreshnessOnly",
    "globalFreshnessClaim",
    "patchQueuePlan",
    "sourceCheckerPlan",
    "buildQemuPlan",
    "objectSymbolPlan",
    "negativeHarnessPlan",
    "claimLedgerRow",
    "explicitNonClaims",
    "exactPatchIdentity",
    "fileAllowlistRecorded",
    "schedulerTouchRequiresReopen",
    "p5a0P1PlanRecorded",
    "p5a0P1PatchApproved",
    "linuxCodeApproved",
    "futurePatchQueueSlotRecorded",
    "futurePatchIs0008",
    "futurePatchDeltaScoped",
    "futurePatchLimitedToAllowlist",
    "futurePatchTouchesOnlySchedExecLeaseHeader",
    "futurePatchTouchesOnlySchedExecLeaseC",
    "futurePatchTouchesSchedulerControlFlow",
    "futurePatchTouchesLifecycleFile",
    "futurePatchTouchesUnclaimedDriftGroup",
    "per0008DeltaFootprintRequired",
    "upstreamReplayRequired",
    "mergeTreeRequired",
    "sourceOnlyContractShapePlan",
    "internalTypeShapesOnly",
    "opaqueHeaderTypesOnly",
    "privateLayoutsOnlyInExecLeaseC",
    "externalLayoutExposed",
    "runtimeConstructorAdded",
    "globalRuntimeStateAdded",
    "lifecycleHelperBodyChange",
    "nonStaticSymbolAdded",
    "exportedSymbol",
    "publicAbi",
    "publicTracepointAbi",
    "monitorCall",
    "monitorAbi",
    "behaviorChangeApproved",
    "runtimeDenialApproved",
    "nonAllowReachable",
    "schedulerBranchesOnValidation",
    "retryApproved",
    "failClosedApproved",
    "quarantineApproved",
    "deniedReceipt",
    "runtimeStatusPublication",
    "fairPickerIneligibility",
    "runHookDenyReady",
    "moveStatusSettlement",
    "taskStructLayoutChange",
    "schedExecTaskLayoutChange",
    "rqLayoutChange",
    "schedEntityLayoutChange",
    "cfsRqLayoutChange",
    "hotPathHelperBodyChange",
    "validationReturnChange",
    "validationResultConsumed",
    "hotPathAllocation",
    "sleepOrBlockingCall",
    "newLockOrRefcountTransfer",
    "staticKeyAdded",
    "printkAdded",
    "runtimeCoverageClaim",
    "monitorVerificationClaim",
    "productionProtectionClaim",
    "hypervisorGradeClaim",
    "costEfficiencyClaim",
    "deploymentReadinessClaim",
    "datacenterReadinessClaim"
}

StartGate == [
    phase |-> "Start",
    p5a0ERecorded |-> FALSE,
    sourceDriftRun |-> FALSE,
    candidateGroupsFresh |-> FALSE,
    nonCandidateStaleRecorded |-> FALSE,
    candidateScopedFreshnessOnly |-> TRUE,
    globalFreshnessClaim |-> FALSE,
    patchQueuePlan |-> FALSE,
    sourceCheckerPlan |-> FALSE,
    buildQemuPlan |-> FALSE,
    objectSymbolPlan |-> FALSE,
    negativeHarnessPlan |-> FALSE,
    claimLedgerRow |-> FALSE,
    explicitNonClaims |-> TRUE,
    exactPatchIdentity |-> FALSE,
    fileAllowlistRecorded |-> FALSE,
    schedulerTouchRequiresReopen |-> FALSE,
    p5a0P1PlanRecorded |-> FALSE,
    p5a0P1PatchApproved |-> FALSE,
    linuxCodeApproved |-> FALSE,
    futurePatchQueueSlotRecorded |-> FALSE,
    futurePatchIs0008 |-> FALSE,
    futurePatchDeltaScoped |-> FALSE,
    futurePatchLimitedToAllowlist |-> FALSE,
    futurePatchTouchesOnlySchedExecLeaseHeader |-> FALSE,
    futurePatchTouchesOnlySchedExecLeaseC |-> FALSE,
    futurePatchTouchesSchedulerControlFlow |-> FALSE,
    futurePatchTouchesLifecycleFile |-> FALSE,
    futurePatchTouchesUnclaimedDriftGroup |-> FALSE,
    per0008DeltaFootprintRequired |-> FALSE,
    upstreamReplayRequired |-> FALSE,
    mergeTreeRequired |-> FALSE,
    sourceOnlyContractShapePlan |-> FALSE,
    internalTypeShapesOnly |-> FALSE,
    opaqueHeaderTypesOnly |-> FALSE,
    privateLayoutsOnlyInExecLeaseC |-> FALSE,
    externalLayoutExposed |-> FALSE,
    runtimeConstructorAdded |-> FALSE,
    globalRuntimeStateAdded |-> FALSE,
    lifecycleHelperBodyChange |-> FALSE,
    nonStaticSymbolAdded |-> FALSE,
    exportedSymbol |-> FALSE,
    publicAbi |-> FALSE,
    publicTracepointAbi |-> FALSE,
    monitorCall |-> FALSE,
    monitorAbi |-> FALSE,
    behaviorChangeApproved |-> FALSE,
    runtimeDenialApproved |-> FALSE,
    nonAllowReachable |-> FALSE,
    schedulerBranchesOnValidation |-> FALSE,
    retryApproved |-> FALSE,
    failClosedApproved |-> FALSE,
    quarantineApproved |-> FALSE,
    deniedReceipt |-> FALSE,
    runtimeStatusPublication |-> FALSE,
    fairPickerIneligibility |-> FALSE,
    runHookDenyReady |-> FALSE,
    moveStatusSettlement |-> FALSE,
    taskStructLayoutChange |-> FALSE,
    schedExecTaskLayoutChange |-> FALSE,
    rqLayoutChange |-> FALSE,
    schedEntityLayoutChange |-> FALSE,
    cfsRqLayoutChange |-> FALSE,
    hotPathHelperBodyChange |-> FALSE,
    validationReturnChange |-> FALSE,
    validationResultConsumed |-> FALSE,
    hotPathAllocation |-> FALSE,
    sleepOrBlockingCall |-> FALSE,
    newLockOrRefcountTransfer |-> FALSE,
    staticKeyAdded |-> FALSE,
    printkAdded |-> FALSE,
    runtimeCoverageClaim |-> FALSE,
    monitorVerificationClaim |-> FALSE,
    productionProtectionClaim |-> FALSE,
    hypervisorGradeClaim |-> FALSE,
    costEfficiencyClaim |-> FALSE,
    deploymentReadinessClaim |-> FALSE,
    datacenterReadinessClaim |-> FALSE
]

PlanGate == [
    StartGate EXCEPT
        !.phase = "P5A0P1PlanRecorded",
        !.p5a0ERecorded = TRUE,
        !.sourceDriftRun = TRUE,
        !.candidateGroupsFresh = TRUE,
        !.nonCandidateStaleRecorded = TRUE,
        !.patchQueuePlan = TRUE,
        !.sourceCheckerPlan = TRUE,
        !.buildQemuPlan = TRUE,
        !.objectSymbolPlan = TRUE,
        !.negativeHarnessPlan = TRUE,
        !.claimLedgerRow = TRUE,
        !.exactPatchIdentity = TRUE,
        !.fileAllowlistRecorded = TRUE,
        !.schedulerTouchRequiresReopen = TRUE,
        !.p5a0P1PlanRecorded = TRUE,
        !.futurePatchQueueSlotRecorded = TRUE,
        !.futurePatchIs0008 = TRUE,
        !.futurePatchDeltaScoped = TRUE,
        !.futurePatchLimitedToAllowlist = TRUE,
        !.futurePatchTouchesOnlySchedExecLeaseHeader = TRUE,
        !.futurePatchTouchesOnlySchedExecLeaseC = TRUE,
        !.per0008DeltaFootprintRequired = TRUE,
        !.upstreamReplayRequired = TRUE,
        !.mergeTreeRequired = TRUE,
        !.sourceOnlyContractShapePlan = TRUE,
        !.internalTypeShapesOnly = TRUE,
        !.opaqueHeaderTypesOnly = TRUE,
        !.privateLayoutsOnlyInExecLeaseC = TRUE
]

Init == gate = StartGate

RecordPlan == /\ gate = StartGate
              /\ gate' = PlanGate

Next == RecordPlan \/ UNCHANGED gate

Spec == Init /\ [][Next]_vars /\ WF_vars(RecordPlan)

PlanRecordedEventually == <> (gate.phase = "P5A0P1PlanRecorded")

UnsafeMissingEvidenceSpec ==
    gate = [PlanGate EXCEPT !.phase = "BadMissingEvidence",
                             !.p5a0ERecorded = FALSE,
                             !.sourceDriftRun = FALSE,
                             !.candidateGroupsFresh = FALSE,
                             !.nonCandidateStaleRecorded = FALSE]
    /\ [][UNCHANGED gate]_vars

UnsafeMissingPlanRecordSpec ==
    gate = [PlanGate EXCEPT !.phase = "BadMissingPlanRecord",
                             !.p5a0P1PlanRecorded = FALSE]
    /\ [][UNCHANGED gate]_vars

UnsafePatchApprovedSpec ==
    gate = [PlanGate EXCEPT !.phase = "BadPatchApproved",
                             !.p5a0P1PatchApproved = TRUE,
                             !.linuxCodeApproved = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeMissingPatchIdentitySpec ==
    gate = [PlanGate EXCEPT !.phase = "BadMissingPatchIdentity",
                             !.exactPatchIdentity = FALSE,
                             !.futurePatchQueueSlotRecorded = FALSE,
                             !.futurePatchIs0008 = FALSE,
                             !.per0008DeltaFootprintRequired = FALSE]
    /\ [][UNCHANGED gate]_vars

UnsafeMissingFileAllowlistSpec ==
    gate = [PlanGate EXCEPT !.phase = "BadMissingFileAllowlist",
                             !.fileAllowlistRecorded = FALSE,
                             !.futurePatchLimitedToAllowlist = FALSE]
    /\ [][UNCHANGED gate]_vars

UnsafeOutOfAllowlistDeltaSpec ==
    gate = [PlanGate EXCEPT !.phase = "BadOutOfAllowlistDelta",
                             !.futurePatchLimitedToAllowlist = FALSE,
                             !.futurePatchTouchesLifecycleFile = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeSchedulerTouchWithoutReopenSpec ==
    gate = [PlanGate EXCEPT !.phase = "BadSchedulerTouchWithoutReopen",
                             !.schedulerTouchRequiresReopen = FALSE,
                             !.futurePatchTouchesSchedulerControlFlow = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeUnclaimedDriftGroupTouchSpec ==
    gate = [PlanGate EXCEPT !.phase = "BadUnclaimedDriftGroupTouch",
                             !.futurePatchTouchesUnclaimedDriftGroup = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeExternalLayoutOrRuntimeStateSpec ==
    gate = [PlanGate EXCEPT !.phase = "BadExternalLayoutOrRuntimeState",
                             !.externalLayoutExposed = TRUE,
                             !.runtimeConstructorAdded = TRUE,
                             !.globalRuntimeStateAdded = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeLifecycleHelperChangeSpec ==
    gate = [PlanGate EXCEPT !.phase = "BadLifecycleHelperChange",
                             !.lifecycleHelperBodyChange = TRUE,
                             !.behaviorChangeApproved = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeNonStaticOrExportedSymbolSpec ==
    gate = [PlanGate EXCEPT !.phase = "BadNonStaticOrExportedSymbol",
                             !.nonStaticSymbolAdded = TRUE,
                             !.exportedSymbol = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeBehaviorOrNonAllowSpec ==
    gate = [PlanGate EXCEPT !.phase = "BadBehaviorOrNonAllow",
                             !.behaviorChangeApproved = TRUE,
                             !.nonAllowReachable = TRUE,
                             !.validationReturnChange = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeSchedulerBranchSpec ==
    gate = [PlanGate EXCEPT !.phase = "BadSchedulerBranch",
                             !.schedulerBranchesOnValidation = TRUE,
                             !.validationResultConsumed = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeRuntimeDenialFamilySpec ==
    gate = [PlanGate EXCEPT !.phase = "BadRuntimeDenialFamily",
                             !.runtimeDenialApproved = TRUE,
                             !.retryApproved = TRUE,
                             !.failClosedApproved = TRUE,
                             !.quarantineApproved = TRUE,
                             !.deniedReceipt = TRUE,
                             !.runtimeStatusPublication = TRUE,
                             !.fairPickerIneligibility = TRUE,
                             !.runHookDenyReady = TRUE,
                             !.moveStatusSettlement = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafePublicAbiTraceOrMonitorSpec ==
    gate = [PlanGate EXCEPT !.phase = "BadPublicAbiTraceOrMonitor",
                             !.publicAbi = TRUE,
                             !.publicTracepointAbi = TRUE,
                             !.monitorCall = TRUE,
                             !.monitorAbi = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeLayoutOrHotPathImpactSpec ==
    gate = [PlanGate EXCEPT !.phase = "BadLayoutOrHotPathImpact",
                             !.taskStructLayoutChange = TRUE,
                             !.schedExecTaskLayoutChange = TRUE,
                             !.rqLayoutChange = TRUE,
                             !.schedEntityLayoutChange = TRUE,
                             !.cfsRqLayoutChange = TRUE,
                             !.hotPathHelperBodyChange = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeAllocationSleepLockRefSpec ==
    gate = [PlanGate EXCEPT !.phase = "BadAllocationSleepLockRef",
                             !.hotPathAllocation = TRUE,
                             !.sleepOrBlockingCall = TRUE,
                             !.newLockOrRefcountTransfer = TRUE,
                             !.staticKeyAdded = TRUE,
                             !.printkAdded = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeQemuSmokeAsCoverageSpec ==
    gate = [PlanGate EXCEPT !.phase = "BadQemuSmokeAsCoverage",
                             !.runtimeCoverageClaim = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeScopedFreshnessAsGlobalSpec ==
    gate = [PlanGate EXCEPT !.phase = "BadScopedFreshnessAsGlobal",
                             !.candidateScopedFreshnessOnly = FALSE,
                             !.globalFreshnessClaim = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeProtectionCostDatacenterClaimSpec ==
    gate = [PlanGate EXCEPT !.phase = "BadProtectionCostDatacenterClaim",
                             !.monitorVerificationClaim = TRUE,
                             !.productionProtectionClaim = TRUE,
                             !.hypervisorGradeClaim = TRUE,
                             !.costEfficiencyClaim = TRUE,
                             !.deploymentReadinessClaim = TRUE,
                             !.datacenterReadinessClaim = TRUE]
    /\ [][UNCHANGED gate]_vars

BoolFieldOK(f) == gate[f] \in BOOLEAN

TypeOK ==
    /\ DOMAIN gate = GateFields
    /\ gate.phase \in Phase
    /\ \A f \in GateFields \ {"phase"}: BoolFieldOK(f)

NonStartRequiresPlanRecord ==
    gate.phase # "Start" => gate.p5a0P1PlanRecorded

EvidencePreconditions ==
    /\ gate.p5a0ERecorded
    /\ gate.sourceDriftRun
    /\ gate.candidateGroupsFresh
    /\ gate.nonCandidateStaleRecorded
    /\ gate.candidateScopedFreshnessOnly
    /\ ~gate.globalFreshnessClaim
    /\ gate.patchQueuePlan
    /\ gate.sourceCheckerPlan
    /\ gate.buildQemuPlan
    /\ gate.objectSymbolPlan
    /\ gate.negativeHarnessPlan
    /\ gate.claimLedgerRow
    /\ gate.explicitNonClaims

PlanRecordPreconditions ==
    /\ EvidencePreconditions
    /\ gate.p5a0P1PlanRecorded
    /\ gate.exactPatchIdentity
    /\ gate.fileAllowlistRecorded
    /\ gate.schedulerTouchRequiresReopen
    /\ gate.futurePatchQueueSlotRecorded
    /\ gate.futurePatchIs0008
    /\ gate.futurePatchDeltaScoped
    /\ gate.futurePatchLimitedToAllowlist
    /\ gate.futurePatchTouchesOnlySchedExecLeaseHeader
    /\ gate.futurePatchTouchesOnlySchedExecLeaseC
    /\ gate.per0008DeltaFootprintRequired
    /\ gate.upstreamReplayRequired
    /\ gate.mergeTreeRequired
    /\ gate.sourceOnlyContractShapePlan
    /\ gate.internalTypeShapesOnly
    /\ gate.opaqueHeaderTypesOnly
    /\ gate.privateLayoutsOnlyInExecLeaseC

NoPlanWithoutEvidence ==
    gate.p5a0P1PlanRecorded => PlanRecordPreconditions

PlanDoesNotApprovePatch ==
    /\ ~gate.p5a0P1PatchApproved
    /\ ~gate.linuxCodeApproved

FuturePatchScopeIsAllowlisted ==
    gate.p5a0P1PlanRecorded =>
        /\ gate.futurePatchDeltaScoped
        /\ gate.futurePatchLimitedToAllowlist
        /\ ~gate.futurePatchTouchesSchedulerControlFlow
        /\ ~gate.futurePatchTouchesLifecycleFile
        /\ ~gate.futurePatchTouchesUnclaimedDriftGroup
        /\ gate.schedulerTouchRequiresReopen

SourceOnlyInternalShapes ==
    gate.p5a0P1PlanRecorded =>
        /\ gate.sourceOnlyContractShapePlan
        /\ gate.internalTypeShapesOnly
        /\ gate.opaqueHeaderTypesOnly
        /\ gate.privateLayoutsOnlyInExecLeaseC
        /\ ~gate.externalLayoutExposed
        /\ ~gate.runtimeConstructorAdded
        /\ ~gate.globalRuntimeStateAdded
        /\ ~gate.lifecycleHelperBodyChange
        /\ ~gate.nonStaticSymbolAdded
        /\ ~gate.exportedSymbol

NoBehaviorOrDenial ==
    /\ ~gate.behaviorChangeApproved
    /\ ~gate.runtimeDenialApproved
    /\ ~gate.nonAllowReachable
    /\ ~gate.schedulerBranchesOnValidation
    /\ ~gate.retryApproved
    /\ ~gate.failClosedApproved
    /\ ~gate.quarantineApproved
    /\ ~gate.deniedReceipt
    /\ ~gate.runtimeStatusPublication
    /\ ~gate.fairPickerIneligibility
    /\ ~gate.runHookDenyReady
    /\ ~gate.moveStatusSettlement
    /\ ~gate.validationReturnChange
    /\ ~gate.validationResultConsumed

NoLayoutOrHotPathImpact ==
    /\ ~gate.taskStructLayoutChange
    /\ ~gate.schedExecTaskLayoutChange
    /\ ~gate.rqLayoutChange
    /\ ~gate.schedEntityLayoutChange
    /\ ~gate.cfsRqLayoutChange
    /\ ~gate.hotPathHelperBodyChange
    /\ ~gate.hotPathAllocation
    /\ ~gate.sleepOrBlockingCall
    /\ ~gate.newLockOrRefcountTransfer
    /\ ~gate.staticKeyAdded
    /\ ~gate.printkAdded

NoPublicOrMonitorSurface ==
    /\ ~gate.publicAbi
    /\ ~gate.publicTracepointAbi
    /\ ~gate.monitorCall
    /\ ~gate.monitorAbi

ScopedFreshnessOnly ==
    /\ gate.candidateScopedFreshnessOnly
    /\ ~gate.globalFreshnessClaim

NoRuntimeOrProductionClaims ==
    /\ ~gate.runtimeCoverageClaim
    /\ ~gate.monitorVerificationClaim
    /\ ~gate.productionProtectionClaim
    /\ ~gate.hypervisorGradeClaim
    /\ ~gate.costEfficiencyClaim
    /\ ~gate.deploymentReadinessClaim
    /\ ~gate.datacenterReadinessClaim

Safety ==
    /\ TypeOK
    /\ NonStartRequiresPlanRecord
    /\ NoPlanWithoutEvidence
    /\ PlanDoesNotApprovePatch
    /\ FuturePatchScopeIsAllowlisted
    /\ SourceOnlyInternalShapes
    /\ NoBehaviorOrDenial
    /\ NoLayoutOrHotPathImpact
    /\ NoPublicOrMonitorSurface
    /\ ScopedFreshnessOnly
    /\ NoRuntimeOrProductionClaims

====
