---------- MODULE P5AScopeGate ----------

VARIABLE gate

vars == <<gate>>

Phase == {
    "P5AScopeRecorded",
    "BadNoDecomposition",
    "BadLinuxImplementationApproved",
    "BadBehaviorInP5A0",
    "BadRunDenyAtP4Hook",
    "BadDenyOnePickNextWithoutFairEligibility",
    "BadBroadMoveDenialWithoutStatusSettlement",
    "BadUnsupportedPathClaim",
    "BadMissingNegativeTests",
    "BadProtectionClaim",
    "BadCostOrDeploymentClaim"
}

GateFields == {
    "phase",
    "sourceChecked",
    "p5ReadinessRefreshed",
    "p5aScopeRecorded",
    "p5aDecomposed",
    "p5a0NoBehaviorOnly",
    "p5a0BehaviorChange",
    "linuxImplementationApproved",
    "behaviorChangeApproved",
    "runtimeDenialApproved",
    "runDenyAtCurrentP4Hook",
    "fairPickerEligibilityDesigned",
    "denyOnePickNextCfsApproved",
    "moveStatusPlumbingDesigned",
    "moveCallerSettlementDesigned",
    "broadMoveDenialApproved",
    "negativeTestsRequired",
    "negativeTestsMapped",
    "pathClassificationRequired",
    "unsupportedPathClaims",
    "claimLedgerRequired",
    "monitorCall",
    "monitorVerificationClaim",
    "productionProtectionClaim",
    "hypervisorGradeClaim",
    "costEfficiencyClaim",
    "deploymentReadinessClaim",
    "nonClaimsRecorded"
}

BaseGate == [
    phase |-> "P5AScopeRecorded",
    sourceChecked |-> TRUE,
    p5ReadinessRefreshed |-> TRUE,
    p5aScopeRecorded |-> TRUE,
    p5aDecomposed |-> TRUE,
    p5a0NoBehaviorOnly |-> TRUE,
    p5a0BehaviorChange |-> FALSE,
    linuxImplementationApproved |-> FALSE,
    behaviorChangeApproved |-> FALSE,
    runtimeDenialApproved |-> FALSE,
    runDenyAtCurrentP4Hook |-> FALSE,
    fairPickerEligibilityDesigned |-> FALSE,
    denyOnePickNextCfsApproved |-> FALSE,
    moveStatusPlumbingDesigned |-> FALSE,
    moveCallerSettlementDesigned |-> FALSE,
    broadMoveDenialApproved |-> FALSE,
    negativeTestsRequired |-> TRUE,
    negativeTestsMapped |-> FALSE,
    pathClassificationRequired |-> TRUE,
    unsupportedPathClaims |-> FALSE,
    claimLedgerRequired |-> TRUE,
    monitorCall |-> FALSE,
    monitorVerificationClaim |-> FALSE,
    productionProtectionClaim |-> FALSE,
    hypervisorGradeClaim |-> FALSE,
    costEfficiencyClaim |-> FALSE,
    deploymentReadinessClaim |-> FALSE,
    nonClaimsRecorded |-> TRUE
]

Init == gate = BaseGate

Spec == Init /\ [][UNCHANGED gate]_vars

UnsafeNoDecompositionSpec ==
    gate = [BaseGate EXCEPT !.phase = "BadNoDecomposition",
                            !.p5aDecomposed = FALSE]
    /\ [][UNCHANGED gate]_vars

UnsafeLinuxImplementationApprovedSpec ==
    gate = [BaseGate EXCEPT !.phase = "BadLinuxImplementationApproved",
                            !.linuxImplementationApproved = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeBehaviorInP5A0Spec ==
    gate = [BaseGate EXCEPT !.phase = "BadBehaviorInP5A0",
                            !.p5a0BehaviorChange = TRUE,
                            !.behaviorChangeApproved = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeRunDenyAtP4HookSpec ==
    gate = [BaseGate EXCEPT !.phase = "BadRunDenyAtP4Hook",
                            !.runDenyAtCurrentP4Hook = TRUE,
                            !.runtimeDenialApproved = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeDenyOnePickNextWithoutFairEligibilitySpec ==
    gate = [BaseGate EXCEPT !.phase = "BadDenyOnePickNextWithoutFairEligibility",
                            !.denyOnePickNextCfsApproved = TRUE,
                            !.runtimeDenialApproved = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeBroadMoveDenialWithoutStatusSettlementSpec ==
    gate = [BaseGate EXCEPT !.phase = "BadBroadMoveDenialWithoutStatusSettlement",
                            !.broadMoveDenialApproved = TRUE,
                            !.runtimeDenialApproved = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeUnsupportedPathClaimSpec ==
    gate = [BaseGate EXCEPT !.phase = "BadUnsupportedPathClaim",
                            !.unsupportedPathClaims = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeMissingNegativeTestsSpec ==
    gate = [BaseGate EXCEPT !.phase = "BadMissingNegativeTests",
                            !.negativeTestsRequired = FALSE,
                            !.negativeTestsMapped = FALSE,
                            !.behaviorChangeApproved = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeProtectionClaimSpec ==
    gate = [BaseGate EXCEPT !.phase = "BadProtectionClaim",
                            !.monitorCall = TRUE,
                            !.monitorVerificationClaim = TRUE,
                            !.productionProtectionClaim = TRUE,
                            !.hypervisorGradeClaim = TRUE]
    /\ [][UNCHANGED gate]_vars

UnsafeCostOrDeploymentClaimSpec ==
    gate = [BaseGate EXCEPT !.phase = "BadCostOrDeploymentClaim",
                            !.costEfficiencyClaim = TRUE,
                            !.deploymentReadinessClaim = TRUE]
    /\ [][UNCHANGED gate]_vars

BoolFieldOK(f) == gate[f] \in BOOLEAN

TypeOK ==
    /\ DOMAIN gate = GateFields
    /\ gate.phase \in Phase
    /\ \A f \in GateFields \ {"phase"}: BoolFieldOK(f)

ScopeRecordPreconditions ==
    /\ gate.sourceChecked
    /\ gate.p5ReadinessRefreshed
    /\ gate.p5aDecomposed
    /\ gate.p5a0NoBehaviorOnly
    /\ ~gate.p5a0BehaviorChange
    /\ gate.negativeTestsRequired
    /\ gate.pathClassificationRequired
    /\ gate.claimLedgerRequired
    /\ gate.nonClaimsRecorded

NoScopeRecordWithoutPreconditions ==
    gate.p5aScopeRecorded => ScopeRecordPreconditions

NoLinuxImplementationFromScopeProposal ==
    ~gate.linuxImplementationApproved

NoBehaviorChangeFromP5A0 ==
    /\ ~gate.p5a0BehaviorChange
    /\ ~gate.behaviorChangeApproved
    /\ ~gate.runtimeDenialApproved

NoCurrentP4HookAsRunDenial ==
    gate.runtimeDenialApproved => ~gate.runDenyAtCurrentP4Hook

NoDenyOnePickNextWithoutFairEligibility ==
    gate.denyOnePickNextCfsApproved => gate.fairPickerEligibilityDesigned

NoBroadMoveDenialWithoutSettlement ==
    gate.broadMoveDenialApproved =>
        /\ gate.moveStatusPlumbingDesigned
        /\ gate.moveCallerSettlementDesigned

NoUnsupportedPathClaim ==
    ~gate.unsupportedPathClaims

NoProtectionClaim ==
    /\ ~gate.monitorCall
    /\ ~gate.monitorVerificationClaim
    /\ ~gate.productionProtectionClaim
    /\ ~gate.hypervisorGradeClaim

NoCostOrDeploymentClaim ==
    /\ ~gate.costEfficiencyClaim
    /\ ~gate.deploymentReadinessClaim

Safety ==
    /\ TypeOK
    /\ NoScopeRecordWithoutPreconditions
    /\ NoLinuxImplementationFromScopeProposal
    /\ NoBehaviorChangeFromP5A0
    /\ NoCurrentP4HookAsRunDenial
    /\ NoDenyOnePickNextWithoutFairEligibility
    /\ NoBroadMoveDenialWithoutSettlement
    /\ NoUnsupportedPathClaim
    /\ NoProtectionClaim
    /\ NoCostOrDeploymentClaim

====
