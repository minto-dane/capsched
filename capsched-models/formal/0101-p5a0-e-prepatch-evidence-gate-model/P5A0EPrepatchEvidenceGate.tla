---------- MODULE P5A0EPrepatchEvidenceGate ----------

VARIABLE gate

vars == <<gate>>

Phase == {
    "Start",
    "EvidenceRecorded",
    "BadMissingFreshDrift",
    "BadMissingPlans",
    "BadScopedFreshnessAsGlobal",
    "BadPatchApproved",
    "BadP1WithoutFileAllowlist",
    "BadSchedulerTouchWithoutReopen",
    "BadNonAllowReachable",
    "BadSchedulerBranch",
    "BadFairPickerDenialClaim",
    "BadMoveSettlementClaim",
    "BadLayoutOrObjectImpact",
    "BadPublicAbiOrMonitor",
    "BadRuntimeCoverageOrMonitorClaim",
    "BadProtectionCostDatacenterClaim"
}

GateFields == {
    "phase",
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
    "p5a0ERecorded",
    "p5a0P1PatchApproved",
    "p5a0P2MoveStatusApproved",
    "behaviorChangeApproved",
    "runtimeDenialApproved",
    "nonAllowReachable",
    "schedulerBranchesOnValidation",
    "fairPickerIneligibility",
    "runHookDenyReady",
    "moveStatusSettlement",
    "configOffObjectImpact",
    "taskStructLayoutChange",
    "rqLayoutChange",
    "schedEntityLayoutChange",
    "cfsRqLayoutChange",
    "hotPathAllocation",
    "sleepOrBlockingCall",
    "publicAbi",
    "publicTracepointAbi",
    "exportedSymbol",
    "monitorCall",
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
    p5a0ERecorded |-> FALSE,
    p5a0P1PatchApproved |-> FALSE,
    p5a0P2MoveStatusApproved |-> FALSE,
    behaviorChangeApproved |-> FALSE,
    runtimeDenialApproved |-> FALSE,
    nonAllowReachable |-> FALSE,
    schedulerBranchesOnValidation |-> FALSE,
    fairPickerIneligibility |-> FALSE,
    runHookDenyReady |-> FALSE,
    moveStatusSettlement |-> FALSE,
    configOffObjectImpact |-> FALSE,
    taskStructLayoutChange |-> FALSE,
    rqLayoutChange |-> FALSE,
    schedEntityLayoutChange |-> FALSE,
    cfsRqLayoutChange |-> FALSE,
    hotPathAllocation |-> FALSE,
    sleepOrBlockingCall |-> FALSE,
    publicAbi |-> FALSE,
    publicTracepointAbi |-> FALSE,
    exportedSymbol |-> FALSE,
    monitorCall |-> FALSE,
    runtimeCoverageClaim |-> FALSE,
    monitorVerificationClaim |-> FALSE,
    productionProtectionClaim |-> FALSE,
    hypervisorGradeClaim |-> FALSE,
    costEfficiencyClaim |-> FALSE,
    deploymentReadinessClaim |-> FALSE,
    datacenterReadinessClaim |-> FALSE
]

EvidenceGate == [
    StartGate EXCEPT
        !.phase = "EvidenceRecorded",
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
        !.p5a0ERecorded = TRUE
]

Init == gate = StartGate

RecordEvidence == /\ gate = StartGate
                  /\ gate' = EvidenceGate

Next == RecordEvidence \/ UNCHANGED gate

Spec == Init /\ [][Next]_vars

UnsafeMissingFreshDriftSpec ==
    gate = [EvidenceGate EXCEPT !.phase = "BadMissingFreshDrift",
                                !.sourceDriftRun = FALSE,
                                !.candidateGroupsFresh = FALSE]
    /\ [][UNCHANGED gate]_vars

UnsafeMissingPlansSpec ==
    gate = [EvidenceGate EXCEPT !.phase = "BadMissingPlans",
                                !.patchQueuePlan = FALSE,
                                !.sourceCheckerPlan = FALSE,
                                !.buildQemuPlan = FALSE,
                                !.objectSymbolPlan = FALSE,
                                !.negativeHarnessPlan = FALSE,
                                !.claimLedgerRow = FALSE]
    /\ [][UNCHANGED gate]_vars

UnsafeScopedFreshnessAsGlobalSpec ==
    gate = [EvidenceGate EXCEPT !.phase = "BadScopedFreshnessAsGlobal",
                                !.candidateScopedFreshnessOnly = FALSE,
                                !.globalFreshnessClaim = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafePatchApprovedSpec ==
    gate = [EvidenceGate EXCEPT !.phase = "BadPatchApproved",
                                !.p5a0P1PatchApproved = TRUE,
                                !.behaviorChangeApproved = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeP1WithoutFileAllowlistSpec ==
    gate = [EvidenceGate EXCEPT !.phase = "BadP1WithoutFileAllowlist",
                                !.fileAllowlistRecorded = FALSE,
                                !.p5a0P1PatchApproved = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeSchedulerTouchWithoutReopenSpec ==
    gate = [EvidenceGate EXCEPT !.phase = "BadSchedulerTouchWithoutReopen",
                                !.schedulerTouchRequiresReopen = FALSE,
                                !.p5a0P2MoveStatusApproved = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeNonAllowReachableSpec ==
    gate = [EvidenceGate EXCEPT !.phase = "BadNonAllowReachable",
                                !.nonAllowReachable = TRUE,
                                !.runtimeDenialApproved = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeSchedulerBranchSpec ==
    gate = [EvidenceGate EXCEPT !.phase = "BadSchedulerBranch",
                                !.schedulerBranchesOnValidation = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeFairPickerDenialClaimSpec ==
    gate = [EvidenceGate EXCEPT !.phase = "BadFairPickerDenialClaim",
                                !.fairPickerIneligibility = TRUE,
                                !.runHookDenyReady = TRUE,
                                !.runtimeDenialApproved = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeMoveSettlementClaimSpec ==
    gate = [EvidenceGate EXCEPT !.phase = "BadMoveSettlementClaim",
                                !.moveStatusSettlement = TRUE,
                                !.p5a0P2MoveStatusApproved = TRUE,
                                !.runtimeDenialApproved = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeLayoutOrObjectImpactSpec ==
    gate = [EvidenceGate EXCEPT !.phase = "BadLayoutOrObjectImpact",
                                !.configOffObjectImpact = TRUE,
                                !.taskStructLayoutChange = TRUE,
                                !.rqLayoutChange = TRUE,
                                !.hotPathAllocation = TRUE,
                                !.exportedSymbol = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafePublicAbiOrMonitorSpec ==
    gate = [EvidenceGate EXCEPT !.phase = "BadPublicAbiOrMonitor",
                                !.publicAbi = TRUE,
                                !.publicTracepointAbi = TRUE,
                                !.monitorCall = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeRuntimeCoverageOrMonitorClaimSpec ==
    gate = [EvidenceGate EXCEPT !.phase = "BadRuntimeCoverageOrMonitorClaim",
                                !.runtimeCoverageClaim = TRUE,
                                !.monitorVerificationClaim = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeProtectionCostDatacenterClaimSpec ==
    gate = [EvidenceGate EXCEPT !.phase = "BadProtectionCostDatacenterClaim",
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

EvidencePreconditions ==
    /\ gate.sourceDriftRun
    /\ gate.candidateGroupsFresh
    /\ gate.nonCandidateStaleRecorded
    /\ gate.patchQueuePlan
    /\ gate.sourceCheckerPlan
    /\ gate.buildQemuPlan
    /\ gate.objectSymbolPlan
    /\ gate.negativeHarnessPlan
    /\ gate.claimLedgerRow
    /\ gate.explicitNonClaims
    /\ gate.exactPatchIdentity
    /\ gate.fileAllowlistRecorded
    /\ gate.schedulerTouchRequiresReopen

NoEvidenceRecordWithoutPreconditions ==
    gate.p5a0ERecorded => EvidencePreconditions

CandidateScopedIsNotGlobalFreshness ==
    /\ gate.candidateScopedFreshnessOnly
    /\ ~gate.globalFreshnessClaim

NoPatchApprovedFromEvidence ==
    /\ ~gate.p5a0P1PatchApproved
    /\ ~gate.p5a0P2MoveStatusApproved

NoBehaviorOrDenial ==
    /\ ~gate.behaviorChangeApproved
    /\ ~gate.runtimeDenialApproved
    /\ ~gate.nonAllowReachable
    /\ ~gate.schedulerBranchesOnValidation

SourceFactsKeepP5Blocked ==
    /\ ~gate.fairPickerIneligibility
    /\ ~gate.runHookDenyReady
    /\ ~gate.moveStatusSettlement

NoLayoutObjectOrHotPathImpact ==
    /\ ~gate.configOffObjectImpact
    /\ ~gate.taskStructLayoutChange
    /\ ~gate.rqLayoutChange
    /\ ~gate.schedEntityLayoutChange
    /\ ~gate.cfsRqLayoutChange
    /\ ~gate.hotPathAllocation
    /\ ~gate.sleepOrBlockingCall
    /\ ~gate.exportedSymbol

NoPublicOrMonitorSurface ==
    /\ ~gate.publicAbi
    /\ ~gate.publicTracepointAbi
    /\ ~gate.monitorCall

NoRuntimeMonitorProtectionCostClaim ==
    /\ ~gate.runtimeCoverageClaim
    /\ ~gate.monitorVerificationClaim
    /\ ~gate.productionProtectionClaim
    /\ ~gate.hypervisorGradeClaim
    /\ ~gate.costEfficiencyClaim
    /\ ~gate.deploymentReadinessClaim
    /\ ~gate.datacenterReadinessClaim

Safety ==
    /\ TypeOK
    /\ NoEvidenceRecordWithoutPreconditions
    /\ CandidateScopedIsNotGlobalFreshness
    /\ NoPatchApprovedFromEvidence
    /\ NoBehaviorOrDenial
    /\ SourceFactsKeepP5Blocked
    /\ NoLayoutObjectOrHotPathImpact
    /\ NoPublicOrMonitorSurface
    /\ NoRuntimeMonitorProtectionCostClaim

====
