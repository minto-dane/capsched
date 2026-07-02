---------- MODULE ImplementationClaimLedgerGate ----------
EXTENDS Naturals

VARIABLE ledger

vars == <<ledger>>

Slice == {"P1", "P2", "P3", "P4", "P5", "H"}

Phase == {
    "LedgerChecked",
    "BadMissingLedger",
    "BadImplementationApprovalWithoutScope",
    "BadImplementationApprovalStaleDrift",
    "BadBehaviorChangeWithoutEvidence",
    "BadRuntimeDenialWithoutTrace",
    "BadRuntimeCoverageWithoutTrace",
    "BadMonitorVerifiedWithoutMonitor",
    "BadProductionWithoutMonitorEval",
    "BadHypervisorGradeFromP5",
    "BadCostEfficiencyWithoutEvaluation",
    "BadPublicAbiWithoutAbiGate",
    "BadModelOnlyProductionClaim",
    "BadCompatibilityAsProtection"
}

LedgerFields == {
    "phase",
    "slice",
    "claimLedgerPresent",
    "implementationScopeReopened",
    "upstreamDriftFresh",
    "modelEvidence",
    "compatibilityEvidence",
    "p5PathClassificationEvidence",
    "negativeDenialEvidence",
    "traceDeniedNotRunEvidence",
    "boundedRetryEvidence",
    "failClosedEvidence",
    "runtimeCoverageTraceEvidence",
    "monitorMemoryViewEvidence",
    "monitorRootBudgetEvidence",
    "monitorIommuEvidence",
    "monitorRevokeEvidence",
    "monitorEscapeEvalEvidence",
    "evaluationContractEvidence",
    "costBenchmarkEvidence",
    "abiReviewEvidence",
    "modelSupportClaim",
    "compatibilityClaim",
    "implementationApprovalClaim",
    "behaviorChangeClaim",
    "runtimeDenialClaim",
    "runtimeCoverageClaim",
    "monitorVerificationClaim",
    "productionProtectionClaim",
    "hypervisorGradeClaim",
    "costEfficiencyClaim",
    "publicAbiClaim"
}

BaseLedger == [
    phase |-> "LedgerChecked",
    slice |-> "P5",
    claimLedgerPresent |-> TRUE,
    implementationScopeReopened |-> FALSE,
    upstreamDriftFresh |-> TRUE,
    modelEvidence |-> TRUE,
    compatibilityEvidence |-> TRUE,
    p5PathClassificationEvidence |-> TRUE,
    negativeDenialEvidence |-> FALSE,
    traceDeniedNotRunEvidence |-> FALSE,
    boundedRetryEvidence |-> FALSE,
    failClosedEvidence |-> FALSE,
    runtimeCoverageTraceEvidence |-> FALSE,
    monitorMemoryViewEvidence |-> FALSE,
    monitorRootBudgetEvidence |-> FALSE,
    monitorIommuEvidence |-> FALSE,
    monitorRevokeEvidence |-> FALSE,
    monitorEscapeEvalEvidence |-> FALSE,
    evaluationContractEvidence |-> FALSE,
    costBenchmarkEvidence |-> FALSE,
    abiReviewEvidence |-> FALSE,
    modelSupportClaim |-> TRUE,
    compatibilityClaim |-> TRUE,
    implementationApprovalClaim |-> FALSE,
    behaviorChangeClaim |-> FALSE,
    runtimeDenialClaim |-> FALSE,
    runtimeCoverageClaim |-> FALSE,
    monitorVerificationClaim |-> FALSE,
    productionProtectionClaim |-> FALSE,
    hypervisorGradeClaim |-> FALSE,
    costEfficiencyClaim |-> FALSE,
    publicAbiClaim |-> FALSE
]

Init == ledger = BaseLedger

Spec == Init /\ [][UNCHANGED ledger]_vars

UnsafeMissingLedgerSpec ==
    ledger = [BaseLedger EXCEPT
        !.phase = "BadMissingLedger",
        !.claimLedgerPresent = FALSE]
    /\ [][UNCHANGED ledger]_vars

UnsafeImplementationApprovalWithoutScopeSpec ==
    ledger = [BaseLedger EXCEPT
        !.phase = "BadImplementationApprovalWithoutScope",
        !.implementationApprovalClaim = TRUE]
    /\ [][UNCHANGED ledger]_vars

UnsafeImplementationApprovalStaleDriftSpec ==
    ledger = [BaseLedger EXCEPT
        !.phase = "BadImplementationApprovalStaleDrift",
        !.implementationScopeReopened = TRUE,
        !.upstreamDriftFresh = FALSE,
        !.implementationApprovalClaim = TRUE]
    /\ [][UNCHANGED ledger]_vars

UnsafeBehaviorChangeWithoutEvidenceSpec ==
    ledger = [BaseLedger EXCEPT
        !.phase = "BadBehaviorChangeWithoutEvidence",
        !.implementationScopeReopened = TRUE,
        !.implementationApprovalClaim = TRUE,
        !.behaviorChangeClaim = TRUE]
    /\ [][UNCHANGED ledger]_vars

UnsafeRuntimeDenialWithoutTraceSpec ==
    ledger = [BaseLedger EXCEPT
        !.phase = "BadRuntimeDenialWithoutTrace",
        !.implementationScopeReopened = TRUE,
        !.implementationApprovalClaim = TRUE,
        !.behaviorChangeClaim = TRUE,
        !.negativeDenialEvidence = TRUE,
        !.boundedRetryEvidence = TRUE,
        !.failClosedEvidence = TRUE,
        !.runtimeDenialClaim = TRUE]
    /\ [][UNCHANGED ledger]_vars

UnsafeRuntimeCoverageWithoutTraceSpec ==
    ledger = [BaseLedger EXCEPT
        !.phase = "BadRuntimeCoverageWithoutTrace",
        !.runtimeCoverageClaim = TRUE]
    /\ [][UNCHANGED ledger]_vars

UnsafeMonitorVerifiedWithoutMonitorSpec ==
    ledger = [BaseLedger EXCEPT
        !.phase = "BadMonitorVerifiedWithoutMonitor",
        !.monitorVerificationClaim = TRUE]
    /\ [][UNCHANGED ledger]_vars

UnsafeProductionWithoutMonitorEvalSpec ==
    ledger = [BaseLedger EXCEPT
        !.phase = "BadProductionWithoutMonitorEval",
        !.productionProtectionClaim = TRUE]
    /\ [][UNCHANGED ledger]_vars

UnsafeHypervisorGradeFromP5Spec ==
    ledger = [BaseLedger EXCEPT
        !.phase = "BadHypervisorGradeFromP5",
        !.hypervisorGradeClaim = TRUE]
    /\ [][UNCHANGED ledger]_vars

UnsafeCostEfficiencyWithoutEvaluationSpec ==
    ledger = [BaseLedger EXCEPT
        !.phase = "BadCostEfficiencyWithoutEvaluation",
        !.costEfficiencyClaim = TRUE]
    /\ [][UNCHANGED ledger]_vars

UnsafePublicAbiWithoutAbiGateSpec ==
    ledger = [BaseLedger EXCEPT
        !.phase = "BadPublicAbiWithoutAbiGate",
        !.publicAbiClaim = TRUE]
    /\ [][UNCHANGED ledger]_vars

UnsafeModelOnlyProductionClaimSpec ==
    ledger = [BaseLedger EXCEPT
        !.phase = "BadModelOnlyProductionClaim",
        !.productionProtectionClaim = TRUE]
    /\ [][UNCHANGED ledger]_vars

UnsafeCompatibilityAsProtectionSpec ==
    ledger = [BaseLedger EXCEPT
        !.phase = "BadCompatibilityAsProtection",
        !.productionProtectionClaim = TRUE]
    /\ [][UNCHANGED ledger]_vars

BoolFieldOK(f) == ledger[f] \in BOOLEAN

TypeOK ==
    /\ DOMAIN ledger = LedgerFields
    /\ ledger.phase \in Phase
    /\ ledger.slice \in Slice
    /\ BoolFieldOK("claimLedgerPresent")
    /\ BoolFieldOK("implementationScopeReopened")
    /\ BoolFieldOK("upstreamDriftFresh")
    /\ BoolFieldOK("modelEvidence")
    /\ BoolFieldOK("compatibilityEvidence")
    /\ BoolFieldOK("p5PathClassificationEvidence")
    /\ BoolFieldOK("negativeDenialEvidence")
    /\ BoolFieldOK("traceDeniedNotRunEvidence")
    /\ BoolFieldOK("boundedRetryEvidence")
    /\ BoolFieldOK("failClosedEvidence")
    /\ BoolFieldOK("runtimeCoverageTraceEvidence")
    /\ BoolFieldOK("monitorMemoryViewEvidence")
    /\ BoolFieldOK("monitorRootBudgetEvidence")
    /\ BoolFieldOK("monitorIommuEvidence")
    /\ BoolFieldOK("monitorRevokeEvidence")
    /\ BoolFieldOK("monitorEscapeEvalEvidence")
    /\ BoolFieldOK("evaluationContractEvidence")
    /\ BoolFieldOK("costBenchmarkEvidence")
    /\ BoolFieldOK("abiReviewEvidence")
    /\ BoolFieldOK("modelSupportClaim")
    /\ BoolFieldOK("compatibilityClaim")
    /\ BoolFieldOK("implementationApprovalClaim")
    /\ BoolFieldOK("behaviorChangeClaim")
    /\ BoolFieldOK("runtimeDenialClaim")
    /\ BoolFieldOK("runtimeCoverageClaim")
    /\ BoolFieldOK("monitorVerificationClaim")
    /\ BoolFieldOK("productionProtectionClaim")
    /\ BoolFieldOK("hypervisorGradeClaim")
    /\ BoolFieldOK("costEfficiencyClaim")
    /\ BoolFieldOK("publicAbiClaim")

NoMissingLedger ==
    ledger.claimLedgerPresent

NoImplementationApprovalWithoutGate ==
    ledger.implementationApprovalClaim =>
        /\ ledger.claimLedgerPresent
        /\ ledger.implementationScopeReopened
        /\ ledger.upstreamDriftFresh

NoBehaviorChangeWithoutEvidence ==
    ledger.behaviorChangeClaim =>
        /\ ledger.implementationApprovalClaim
        /\ ledger.slice = "P5"
        /\ ledger.p5PathClassificationEvidence
        /\ ledger.negativeDenialEvidence
        /\ ledger.traceDeniedNotRunEvidence
        /\ ledger.boundedRetryEvidence
        /\ ledger.failClosedEvidence

NoRuntimeDenialWithoutEvidence ==
    ledger.runtimeDenialClaim =>
        /\ ledger.behaviorChangeClaim
        /\ ledger.negativeDenialEvidence
        /\ ledger.traceDeniedNotRunEvidence
        /\ ledger.boundedRetryEvidence
        /\ ledger.failClosedEvidence

NoRuntimeCoverageWithoutTrace ==
    ledger.runtimeCoverageClaim =>
        /\ ledger.runtimeCoverageTraceEvidence
        /\ ledger.p5PathClassificationEvidence

NoMonitorVerificationWithoutMonitorRoots ==
    ledger.monitorVerificationClaim =>
        /\ ledger.monitorMemoryViewEvidence
        /\ ledger.monitorRootBudgetEvidence
        /\ ledger.monitorIommuEvidence
        /\ ledger.monitorRevokeEvidence

NoProductionWithoutMonitorAndEval ==
    ledger.productionProtectionClaim =>
        /\ ledger.monitorVerificationClaim
        /\ ledger.runtimeCoverageTraceEvidence
        /\ ledger.monitorEscapeEvalEvidence

NoHypervisorGradeWithoutProduction ==
    ledger.hypervisorGradeClaim =>
        /\ ledger.productionProtectionClaim
        /\ ledger.monitorVerificationClaim
        /\ ledger.monitorMemoryViewEvidence
        /\ ledger.monitorRootBudgetEvidence
        /\ ledger.monitorIommuEvidence

NoCostEfficiencyWithoutEvaluation ==
    ledger.costEfficiencyClaim =>
        /\ ledger.productionProtectionClaim
        /\ ledger.evaluationContractEvidence
        /\ ledger.costBenchmarkEvidence

NoPublicAbiWithoutAbiGate ==
    ledger.publicAbiClaim =>
        /\ ledger.implementationScopeReopened
        /\ ledger.abiReviewEvidence

NoModelEvidenceAsImplementation ==
    (ledger.modelEvidence /\ ~ledger.implementationScopeReopened) =>
        /\ ~ledger.implementationApprovalClaim
        /\ ~ledger.behaviorChangeClaim
        /\ ~ledger.runtimeDenialClaim

NoModelEvidenceAsProtection ==
    ledger.modelEvidence =>
        /\ ~ledger.productionProtectionClaim
        /\ ~ledger.hypervisorGradeClaim
        /\ ~ledger.costEfficiencyClaim

NoCompatibilityEvidenceAsProtection ==
    ledger.compatibilityEvidence =>
        /\ ~ledger.productionProtectionClaim
        /\ ~ledger.hypervisorGradeClaim

Safety ==
    /\ TypeOK
    /\ NoMissingLedger
    /\ NoImplementationApprovalWithoutGate
    /\ NoBehaviorChangeWithoutEvidence
    /\ NoRuntimeDenialWithoutEvidence
    /\ NoRuntimeCoverageWithoutTrace
    /\ NoMonitorVerificationWithoutMonitorRoots
    /\ NoProductionWithoutMonitorAndEval
    /\ NoHypervisorGradeWithoutProduction
    /\ NoCostEfficiencyWithoutEvaluation
    /\ NoPublicAbiWithoutAbiGate
    /\ NoModelEvidenceAsImplementation
    /\ NoModelEvidenceAsProtection
    /\ NoCompatibilityEvidenceAsProtection

====
